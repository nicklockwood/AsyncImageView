//
//  AsyncImageView.m
//
//  Version 1.2.1
//
//  Created by Nick Lockwood on 03/04/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//
//  Get the latest version of AsyncImageView from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#asyncimageview
//  https://github.com/nicklockwood/AsyncImageView
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

#import "AsyncImageView.h"


NSString *const AsyncImageLoadDidFinish = @"AsyncImageLoadDidFinish";
NSString *const AsyncImageLoadDidFail = @"AsyncImageLoadDidFail";
NSString *const AsyncImageTargetReleased = @"AsyncImageTargetReleased";

NSString *const AsyncImageImageKey = @"image";
NSString *const AsyncImageURLKey = @"URL";
NSString *const AsyncImageCacheKey = @"cache";
NSString *const AsyncImageErrorKey = @"error";


@interface AsyncImageCache ()

@property (nonatomic, retain) NSMutableDictionary *cache;

@end


@implementation AsyncImageCache

@synthesize cache;
@synthesize useImageNamed;

+ (AsyncImageCache *)sharedCache
{
    static AsyncImageCache *sharedInstance = nil;
    if (sharedInstance == nil)
    {
        sharedInstance = [[self alloc] init];
    }
    return sharedInstance;
}

- (id)init
{
    if ((self = [super init]))
    {
		useImageNamed = YES;
        cache = [[NSMutableDictionary alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(clearCache)
													 name:UIApplicationDidReceiveMemoryWarningNotification
												   object:nil];
    }
    return self;
}

- (UIImage *)imageForURL:(NSURL *)URL
{
	if (useImageNamed && [URL isFileURL])
	{
		NSString *path = [URL path];
		NSString *imageName = [path lastPathComponent];
		NSString *directory = [path stringByDeletingLastPathComponent];
		if ([[[NSBundle mainBundle] resourcePath] isEqualToString:directory])
		{
			return [UIImage imageNamed:imageName];
		}
	}
    return [cache objectForKey:URL];
}

- (void)setImage:(UIImage *)image forURL:(NSURL *)URL
{
    if (useImageNamed && [URL isFileURL])
    {
        NSString *path = [URL path];
        NSString *directory = [path stringByDeletingLastPathComponent];
        if ([[[NSBundle mainBundle] resourcePath] isEqualToString:directory])
        {
            //do not store in cache
            return;
        }
    }
    [cache setObject:image forKey:URL];
}

- (void)removeImageForURL:(NSURL *)URL
{
    [cache removeObjectForKey:URL];
}

- (void)clearCache
{
    //remove objects that aren't in use
    for (NSURL *URL in [cache allKeys])
    {
        UIImage *image = [cache objectForKey:URL];
        if ([image retainCount] == 1)
        {
            [cache removeObjectForKey:URL];
        }
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [cache release];
    [super dealloc];
}

@end


@interface AsyncImageConnection : NSObject

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, retain) AsyncImageCache *cache;
@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL success;
@property (nonatomic, assign) SEL failure;
@property (nonatomic, assign) BOOL decompressImage;

+ (AsyncImageConnection *)connectionWithURL:(NSURL *)URL
                                      cache:(AsyncImageCache *)cache
									 target:(id)target
									success:(SEL)success
									failure:(SEL)failure
							decompressImage:(BOOL)decompressImage;

- (AsyncImageConnection *)initWithURL:(NSURL *)URL
                                cache:(AsyncImageCache *)cache
							   target:(id)target
							  success:(SEL)success
							  failure:(SEL)failure
					  decompressImage:(BOOL)decompressImage;

- (BOOL)isLoading;
- (void)start;
- (void)cancel;

@end


@implementation AsyncImageConnection

@synthesize connection;
@synthesize data;
@synthesize URL;
@synthesize cache;
@synthesize target;
@synthesize success;
@synthesize failure;
@synthesize decompressImage;

+ (AsyncImageConnection *)connectionWithURL:(NSURL *)URL
                                      cache:(AsyncImageCache *)_cache
									 target:(id)target
									success:(SEL)_success
									failure:(SEL)_failure
							decompressImage:(BOOL)_decompressImage
{
    return [[[self alloc] initWithURL:URL
                                cache:_cache
							   target:target
							  success:_success
							  failure:_failure
					  decompressImage:_decompressImage] autorelease];
}

- (AsyncImageConnection *)initWithURL:(NSURL *)_URL
                                cache:(AsyncImageCache *)_cache
							   target:(id)_target
							  success:(SEL)_success
							  failure:(SEL)_failure
					  decompressImage:(BOOL)_decompressImage
{
    if ((self = [self init]))
    {
        self.URL = _URL;
        self.cache = _cache;
        self.target = _target;
        self.success = _success;
        self.failure = _failure;
		self.decompressImage = _decompressImage;
    }
    return self;
}

- (void)loadFailedWithError:(NSError *)error
{
    [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFail
                                                        object:target
                                                      userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                URL, AsyncImageURLKey,
                                                                error, AsyncImageErrorKey,
                                                                nil]];
}

- (void)cacheImage:(UIImage *)image
{
    [cache setImage:image forURL:URL];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     image, AsyncImageImageKey,
                                     URL, AsyncImageURLKey,
                                     nil];
    if (cache)
    {
        [userInfo setObject:cache forKey:AsyncImageCacheKey];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFinish
                                                        object:target
                                                      userInfo:[[userInfo copy] autorelease]];
}

- (void)decompressImageInBackground:(UIImage *)image
{
	if (decompressImage)
	{
		//force image decompression
		UIGraphicsBeginImageContext(CGSizeMake(1, 1));
		[image drawAtPoint:CGPointZero];
		UIGraphicsEndImageContext();
	}
	
	//add to cache (may be cached already but it doesn't matter)
	[self performSelectorOnMainThread:@selector(cacheImage:) withObject:image waitUntilDone:YES];
}

- (void)processDataInBackground:(NSData *)_data
{
    UIImage *image = [[UIImage alloc] initWithData:_data];
    if (image)
    {
        [self decompressImageInBackground:image];
        [image release];
    }
    else
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSError *error = [NSError errorWithDomain:@"AsyncImageLoader" code:0 userInfo:[NSDictionary dictionaryWithObject:@"Invalid image data" forKey:NSLocalizedDescriptionKey]];
        [self performSelectorOnMainThread:@selector(loadFailedWithError:) withObject:error waitUntilDone:YES];
        [pool drain];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)_data
{
    //check for released target
    if ([target retainCount] == 1)
    {
        [self cancel];
        [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageTargetReleased object:target];
        return;
    }
    
    //check for cached image
	UIImage *image = [cache imageForURL:URL];
    if (image)
    {
        [self cancel];
        [self performSelectorInBackground:@selector(decompressImageInBackground:) withObject:image];
        return;
    }
    
    //add data
    [data appendData:_data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self performSelectorInBackground:@selector(processDataInBackground:) withObject:data];
    self.connection = nil;
    self.data = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.connection = nil;
    self.data = nil;
    [self loadFailedWithError:error];
}

- (BOOL)isLoading
{
    return connection != nil;
}

- (void)start
{
    if (connection)
    {
        //cancel existing connections
        [connection cancel];
    }
    
    //check for released target
    if ([target retainCount] == 1)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageTargetReleased object:target];
        return;
    }
    
    //check for cached image
	UIImage *image = [cache imageForURL:URL];
    if (image)
    {
        [self performSelectorInBackground:@selector(decompressImageInBackground:) withObject:image];
        return;
    }
    
    //begin load
    NSURLRequest *request = [NSURLRequest requestWithURL:URL
                                             cachePolicy:NSURLCacheStorageNotAllowed
                                         timeoutInterval:[AsyncImageLoader sharedLoader].loadingTimeout];
    
    connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [connection start];
}

- (void)cancel
{
    [connection cancel];
    self.connection = nil;
    self.data = nil;
}

- (void)dealloc
{
    [connection release];
    [data release];
    [URL release];
    [target release];
    [super dealloc];
}

@end


@interface AsyncImageLoader ()

@property (nonatomic, retain) NSMutableArray *connections;

@end


@implementation AsyncImageLoader

@synthesize cache;
@synthesize connections;
@synthesize concurrentLoads;
@synthesize loadingTimeout;
@synthesize decompressImages;

+ (AsyncImageLoader *)sharedLoader
{
	static AsyncImageLoader *sharedInstance = nil;
	if (sharedInstance == nil)
	{
		sharedInstance = [[self alloc] init];
	}
	return sharedInstance;
}

- (AsyncImageLoader *)init
{
	if ((self = [super init]))
	{
        cache = [[AsyncImageCache sharedCache] retain];
        concurrentLoads = 2;
        loadingTimeout = 60;
		decompressImages = YES;
		connections = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(imageLoaded:)
													 name:AsyncImageLoadDidFinish
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(imageFailed:)
													 name:AsyncImageLoadDidFail
												   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(targetReleased:)
													 name:AsyncImageTargetReleased
												   object:nil];
	}
	return self;
}

- (void)updateQueue
{
    //remove released targets
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.target retainCount] == 1)
        {
            [connections removeObjectAtIndex:i];
        }
    }
    
    //start connections
    for (int i = 0; i < MIN(concurrentLoads, [connections count]); i++)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if (![connection isLoading])
        {
            [connection start];
        }
    }
}

- (void)imageLoaded:(NSNotification *)notification
{  
    //complete connections for URL
    NSURL *URL = [notification.userInfo objectForKey:AsyncImageURLKey];
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.URL isEqual:URL])
        {
            //cancel earlier connections for same target/action
            for (int j = i - 1; j >= 0; j--)
            {
                AsyncImageConnection *earlier = [connections objectAtIndex:j];
                if (earlier.target == connection.target &&
                    earlier.success == connection.success)
                {
                    [earlier cancel];
                    [connections removeObjectAtIndex:j];
                    i--;
                }
            }
            
            //cancel connection (in case it's a duplicate)
            [connection cancel];
            
            //perform action
			UIImage *image = [notification.userInfo objectForKey:AsyncImageImageKey];
			[connection.target performSelector:connection.success withObject:image withObject:connection.URL];

            //remove from queue
            [connections removeObjectAtIndex:i];
        }
    }
    
    //update the queue
    [self updateQueue];
}

- (void)imageFailed:(NSNotification *)notification
{
    //remove connections for URL
    NSURL *URL = [notification.userInfo objectForKey:AsyncImageURLKey];
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.URL isEqual:URL])
        {
            //cancel connection (in case it's a duplicate)
            [connection cancel];
            
            //perform failure action
            if (connection.failure)
            {
                NSError *error = [notification.userInfo objectForKey:AsyncImageErrorKey];
                [connection.target performSelector:connection.failure withObject:error withObject:URL];
            }
            
            //remove from queue
            [connections removeObjectAtIndex:i];
        }
    }
    
    //update the queue
    [self updateQueue];
}

- (void)targetReleased:(NSNotification *)notification
{
    //remove connections for URL
    id target = [notification object];
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if (connection.target == target)
        {
            //cancel connection
            [connection cancel];
            [connections removeObjectAtIndex:i];
        }
    }
    
    //update the queue
    [self updateQueue];
}

- (void)loadImageWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure
{
    //create new connection
    [connections addObject:[AsyncImageConnection connectionWithURL:URL
                                                             cache:cache
															target:target
														   success:success
														   failure:failure
												   decompressImage:decompressImages]];
    [self updateQueue];
}

- (void)loadImageWithURL:(NSURL *)URL target:(id)target action:(SEL)action
{
    [self loadImageWithURL:URL target:target success:action failure:NULL];
}

- (void)loadImageWithURL:(NSURL *)URL
{
    [self loadImageWithURL:URL target:nil success:NULL failure:NULL];
}

- (void)cancelLoadingURL:(NSURL *)URL target:(id)target action:(SEL)action
{
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.URL isEqual:URL] && connection.target == target && connection.success == action)
        {
            [connection cancel];
            [connections removeObjectAtIndex:i];
        }
    }
}

- (void)cancelLoadingURL:(NSURL *)URL target:(id)target
{
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.URL isEqual:URL] && connection.target == target)
        {
            [connection cancel];
            [connections removeObjectAtIndex:i];
        }
    }
}

- (void)cancelLoadingURL:(NSURL *)URL
{
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if ([connection.URL isEqual:URL])
        {
            [connection cancel];
            [connections removeObjectAtIndex:i];
        }
    }
}

- (NSURL *)URLForTarget:(id)target action:(SEL)action
{
    //return the most recent image URL assigned to the target
    //this is not neccesarily the next image that will be assigned
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if (connection.target == target && connection.success == action)
        {
            return connection.URL;
        }
    }
    return nil;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    [cache release];
	[connections release];
	[super dealloc];
}

@end


@implementation UIImageView(AsyncImageView)

- (void)setImageURL:(NSURL *)imageURL
{
	[[AsyncImageLoader sharedLoader] loadImageWithURL:imageURL target:self action:@selector(setImage:)];
}

- (NSURL *)imageURL
{
	return [[AsyncImageLoader sharedLoader] URLForTarget:self action:@selector(setImage:)];
}

@end
