//
//  FXCache.m
//
//  Version 1.0 beta
//
//  Created by Nick Lockwood on 13/08/2012.
//  Copyright (c) 2013 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/FXCache
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "FXCache.h"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


static dispatch_queue_t savingQueue;
static dispatch_queue_t loadingQueue;


@interface FXCacheItem : NSObject <NSCoding>

@property (nonatomic, copy) NSString *filename;
@property (nonatomic, strong) NSDate *created;
@property (nonatomic, assign) NSUInteger cost;
@property (nonatomic, assign) long long size;

@end


@implementation FXCacheItem

+ (instancetype)itemWithFilename:(NSString *)filename cost:(NSUInteger)cost
{
    FXCacheItem *item = [[self alloc] init];
    item.filename = filename;
    item.created = [NSDate date];
    item.cost = cost;
    return item;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super init])
    {
        _filename = [aDecoder decodeObjectForKey:@"filename"];
        _created = [aDecoder decodeObjectForKey:@"created"];
        _cost = [[aDecoder decodeObjectForKey:@"cost"] integerValue];
        _size = [[aDecoder decodeObjectForKey:@"size"] longLongValue];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    [aCoder encodeObject:_filename forKey:@"filename"];
    [aCoder encodeObject:_created forKey:@"created"];
    [aCoder encodeObject:@(_cost) forKey:@"cost"];
    [aCoder encodeObject:@(_size) forKey:@"size"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: 0x%x name=%@ created=%@ cost=%i size=%lld>", [self class], (uint)self, _filename, _created, _cost, _size];
}

@end


@interface FXCache () <NSCacheDelegate>

@property (nonatomic, strong) NSMutableDictionary *manifest;
@property (nonatomic, strong) NSMutableDictionary *unsavedObjects;
@property (nonatomic, assign) long long totalByteLimit;
@property (nonatomic, assign) NSTimeInterval maxAgeLimit;
@property (nonatomic, assign) dispatch_semaphore_t semaphore;


@end


@implementation FXCache

+ (void)initialize
{
    savingQueue = dispatch_queue_create("com.charcoaldesign.FXCache.saving", NULL);
    loadingQueue = dispatch_queue_create("com.charcoaldesign.FXCache.loading", NULL);
}

- (id)init
{
    if ((self = [super init]))
    {
        
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveToDisk) name:UIApplicationDidEnterBackgroundNotification object:nil];
        
#else
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveToDisk) name:NSApplicationWillResignActiveNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveToDisk) name:NSApplicationWillTerminateNotification object:nil];
        
#endif
        
        //setup
        _semaphore = dispatch_semaphore_create(0);
        _manifest = [NSMutableDictionary dictionary];
        _unsavedObjects = [NSMutableDictionary dictionary];
        
        //load manifest
        [self loadManifest];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    dispatch_release(_semaphore);
}

- (NSString *)manifestKey
{
    NSString *name = [[self name] length]? [@"." stringByAppendingString:[self name]]: @"";
    return [NSString stringWithFormat:@"FXCache%@.manifest", name];
}

- (NSString *)newFilename
{
    CFUUIDRef uuid = CFUUIDCreate(NULL);
    CFStringRef identifier = CFUUIDCreateString(NULL, uuid);
    CFRelease(uuid);
    return CFBridgingRelease(identifier);
}

- (NSString *)pathForFile:(NSString *)file
{
    @synchronized(self)
    {
        static NSString *path = nil;
        if (!path)
        {
            //cache folder
            path = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
            
#ifndef __IPHONE_OS_VERSION_MAX_ALLOWED
            
            //append application bundle ID on Mac OS
            NSString *identifier = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleIdentifierKey];
            path = [path stringByAppendingPathComponent:identifier];
            
#endif
            //create the folder if it doesn't exist
            if (![[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                [[NSFileManager defaultManager] createDirectoryAtPath:path
                                          withIntermediateDirectories:YES attributes:nil error:NULL];
            }
        }
        return [path stringByAppendingPathComponent:file];
    }
}

- (void)loadManifest
{
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:[self manifestKey]];
    NSDictionary *dict = data? [NSKeyedUnarchiver unarchiveObjectWithData:data]: nil;
    [_manifest setDictionary:dict];
}

- (void)saveManifest
{
    //no locking
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:_manifest];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:[self manifestKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)saveToDisk
{
    dispatch_semaphore_signal(_semaphore);
    [self saveManifest];
    for (FXCacheItem *item in [_manifest allValues])
    {
        id object = _unsavedObjects[item.filename];
        if (object)
        {
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object];
            [data writeToFile:[self pathForFile:item.filename] atomically:YES];
            item.size = [data length];
        }
    }
    [self saveManifest];
    [_unsavedObjects removeAllObjects];
    dispatch_semaphore_signal(_semaphore);
}

- (void)setName:(NSString *)n
{
    [self saveToDisk];
    [super setName:n];
    [self loadManifest];
    [super removeAllObjects];
}

- (BOOL)containsObjectForKey:(id)key
{
    dispatch_semaphore_signal(_semaphore);
    FXCacheItem *item = _manifest[key];
    if (item)
    {
        if (!_maxAgeLimit || -[item.created timeIntervalSinceNow] < _maxAgeLimit)
        {
            if ([super objectForKey:key])
            {
                return YES;
            }
            else if ([[NSFileManager defaultManager] fileExistsAtPath:[self pathForFile:item.filename]])
            {
                return YES;
            }
        }
        [_manifest removeObjectForKey:key];
    }
    dispatch_semaphore_signal(_semaphore);
    return NO;
}

- (BOOL)containsObjectForKeyInMemory:(id)key
{
    dispatch_semaphore_signal(_semaphore);
    FXCacheItem *item = _manifest[key];
    if (item)
    {
        if (!_maxAgeLimit || -[item.created timeIntervalSinceNow] < _maxAgeLimit)
        {
            return [super objectForKey:key] != nil;
        }
        [_manifest removeObjectForKey:key];
    }
    dispatch_semaphore_signal(_semaphore);
    return NO;
}

- (id)objectForKey:(id)key
{
    id object = nil;
    dispatch_semaphore_signal(_semaphore);
    FXCacheItem *item = _manifest[key];
    if (item)
    {
        if (!_maxAgeLimit || -[item.created timeIntervalSinceNow] < _maxAgeLimit)
        {
            object = [super objectForKey:key];
            if (!object)
            {
                object = _unsavedObjects[item.filename];
            }
            if (!object)
            {
                NSData *data = [NSData dataWithContentsOfFile:[self pathForFile:item.filename]];
                if (data)
                {
                    object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
                    if (object)
                    {
                        if (!item.size)
                        {
                            item.size = [data length];
                            [self saveManifest];
                        }
                        [super setObject:object forKey:key cost:item.cost];
                    }
                }
            }
        }
        if (!object)
        {
            [super removeObjectForKey:key];
            [_manifest removeObjectForKey:key];
            [self saveManifest];
        }
    }
    dispatch_semaphore_signal(_semaphore);
    return object;
}

- (id)objectForKeyedSubscript:(id)key
{
    return [self objectForKey:key];
}

- (void)getObjectForKey:(id)key block:(void(^)(id object))block
{
    id object = nil;
    dispatch_semaphore_signal(_semaphore);
    FXCacheItem *item = _manifest[key];
    if (item)
    {
        if (!_maxAgeLimit || -[item.created timeIntervalSinceNow] < _maxAgeLimit)
        {
            object = [super objectForKey:key];
            if (!object)
            {
                object = _unsavedObjects[item.filename];
            }
            if (!object)
            {
                dispatch_async(loadingQueue, ^{
                    
                    block([self objectForKey:key]);
                });
                return;
            }
        }
        if (!object)
        {
            [super removeObjectForKey:key];
            [_manifest removeObjectForKey:key];
            [self saveManifest];
        }
    }
    dispatch_semaphore_signal(_semaphore);
    block(object);
}

- (void)setObject:(id)obj forKey:(id)key
{
    [self setObject:obj forKey:key cost:0];
}

- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g
{
    [super setObject:obj forKey:key cost:g];
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    FXCacheItem *item = _manifest[key];
    if (!item)
    {
        item = [FXCacheItem itemWithFilename:[self newFilename] cost:g];
        _manifest[key] = item;
    }
    else
    {
        item.cost = g;
        item.created = [NSDate date];
    }
    _unsavedObjects[item.filename] = obj;
    dispatch_semaphore_signal(_semaphore);
    
    dispatch_async(savingQueue, ^{
        
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        
        //check if total bytes exceeded
        if (_totalByteLimit)
        {
            long long total = [[[_manifest allValues] valueForKeyPath:@"@sum.size"] longLongValue];
            if (total > _totalByteLimit)
            {
                NSArray *keys = [[_manifest allKeys] sortedArrayUsingComparator:^NSComparisonResult(id key1, id key2) {
                    
                    return [[_manifest[key2] created] compare:[_manifest[key1] created]];
                }];
                
                //remove items, oldest first
                for (id _key in keys)
                {
                    if (![_key isEqual:key])
                    {
                        FXCacheItem *item = _manifest[_key];
                        total -= item.size;
                        [super removeObjectForKey:_key];
                        [[NSFileManager defaultManager] removeItemAtPath:[self pathForFile:item.filename] error:NULL];
                        [_manifest removeObjectForKey:_key];
                        if (total <= _totalByteLimit)
                        {
                            break;
                        }
                    }
                }
                [self saveManifest];
            }
        }
        
        //save data
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:obj];
        [data writeToFile:[self pathForFile:item.filename] atomically:YES];
        [_unsavedObjects removeObjectForKey:item.filename];
        item.size = [data length];
        [self saveManifest];
        
        dispatch_semaphore_signal(_semaphore);
    });
}

- (void)setObject:(id)obj forKeyedSubscript:(id<NSCopying>)key
{
    [self setObject:obj forKey:key];
}

- (void)removeObjectForKey:(id)key
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    NSString *filename = [_manifest[key] filename];
    if (filename)
    {
        [[NSFileManager defaultManager] removeItemAtPath:[self pathForFile:filename] error:NULL];
        [_manifest removeObjectForKey:key];
        [self saveManifest];
    }
    dispatch_semaphore_signal(_semaphore);
    [super removeObjectForKey:key];
}

- (void)removeAllObjects
{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    for (FXCacheItem *item in [_manifest allValues])
    {
        NSString *filename = item.filename;
        [[NSFileManager defaultManager] removeItemAtPath:[self pathForFile:filename] error:NULL];
    }
    dispatch_semaphore_signal(_semaphore);
    [super removeAllObjects];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: 0x%x name=%@ countLimit=%i totalCostLimit=%i totalByteLimit=%lld>", [self class], (uint)self, [self name], [self countLimit], [self totalCostLimit], [self totalByteLimit]];
}

@end
