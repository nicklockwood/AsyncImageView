//
//  AsyncImageView.m
//
//  Version 1.1
//
//  Created by Nick Lockwood on 03/04/2011.
//  Copyright 2011 Charcoal Design. All rights reserved.
//
//  Get the latest version of AsyncImageView from either of these locations:
//
//  http://charcoaldesign.co.uk/source/cocoa#asyncimageview
//  https://github.com/demosthenese/AsyncImageView
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


@interface AsyncImageCache ()

@property (nonatomic, retain) NSMutableDictionary *cache;

@end


@implementation AsyncImageCache

@synthesize cache;

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
    return [cache objectForKey:URL];
}

- (void)setImage:(UIImage *)image forURL:(NSURL *)URL
{
    if (image != nil)
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


NSString *const AsyncImageLoadDidFinish = @"AsyncImageLoadDidFinish";
NSString *const AsyncImageLoadDidFail = @"AsyncImageLoadDidFail";
NSString *const AsyncImageTargetReleased = @"AsyncImageTargetReleased";


@interface AsyncImageConnection : NSObject

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSMutableData *data;
@property (nonatomic, retain) NSURL *URL;
@property (nonatomic, retain) id target;
@property (nonatomic, assign) SEL success;
@property (nonatomic, assign) SEL failure;

+ (AsyncImageConnection *)connectionWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure;
- (AsyncImageConnection *)initWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure;

- (BOOL)isLoading;
- (void)start;
- (void)cancel;

@end


@implementation AsyncImageConnection

@synthesize connection;
@synthesize data;
@synthesize URL;
@synthesize target;
@synthesize success;
@synthesize failure;

+ (AsyncImageConnection *)connectionWithURL:(NSURL *)URL target:(id)target success:(SEL)_success failure:(SEL)_failure
{
    return [[[self alloc] initWithURL:URL target:target success:_success failure:_failure] autorelease];
}

- (AsyncImageConnection *)initWithURL:(NSURL *)_URL target:(id)_target success:(SEL)_success failure:(SEL)_failure
{
    if ((self = [self init]))
    {
        self.URL = _URL;
        self.target = _target;
        self.success = _success;
        self.failure = _failure;
    }
    return self;
}

- (void)cacheImage:(UIImage *)image
{
    [[AsyncImageCache sharedCache] setImage:image forURL:URL];
    [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFinish object:URL];
}

- (void)processData:(NSData *)_data
{
    UIImage *image = [[UIImage alloc] initWithData:_data];
    [self performSelectorOnMainThread:@selector(cacheImage:) withObject:image waitUntilDone:YES];
    [image release];
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
    if ([[AsyncImageCache sharedCache] imageForURL:URL])
    {
        [self cancel];
        [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFinish object:URL];
        return;
    }
    
    //add data
    [data appendData:_data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self performSelectorInBackground:@selector(processData:) withObject:data];
    self.connection = nil;
    self.data = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.connection = nil;
    self.data = nil;
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:error forKey:@"error"];
    [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFail
                                                        object:URL
                                                      userInfo:userInfo];
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
    if ([[AsyncImageCache sharedCache] imageForURL:URL])
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFinish object:URL];
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

@synthesize connections;
@synthesize concurrentLoads;
@synthesize loadingTimeout;

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
        concurrentLoads = 2;
        loadingTimeout = 60;
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
    NSURL *URL = [notification object];
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
            UIImage *image = [[AsyncImageCache sharedCache] imageForURL:URL];
            if (image != nil)
                [connection.target performSelector:connection.success withObject:image withObject:URL];
            
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
    NSURL *URL = [notification object];
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
                NSError *error = [[notification userInfo] objectForKey:@"error"];
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
    [connections addObject:[AsyncImageConnection connectionWithURL:URL target:target success:success failure:failure]];
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

- (void)cancelLoadingURLForTarget:(id)target
{
    for (int i = [connections count] - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = [connections objectAtIndex:i];
        if (connection.target == target)
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
	[connections release];
	[super dealloc];
}

@end


@implementation UIImageView(AsyncImageView)

- (void)setImageURL:(NSURL *)imageURL
{
    [[AsyncImageLoader sharedLoader] cancelLoadingURLForTarget:self];
	[[AsyncImageLoader sharedLoader] loadImageWithURL:imageURL target:self action:@selector(setImage:)];
}

- (NSURL *)imageURL
{
	return [[AsyncImageLoader sharedLoader] URLForTarget:self action:@selector(setImage:)];
}

@end
