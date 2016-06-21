//
//  AsyncImageView.m
//
//  Version 1.6
//
//  Created by Nick Lockwood on 03/04/2011.
//  Copyright (c) 2011 Charcoal Design
//
//  Distributed under the permissive zlib License
//  Get the latest version from here:
//
//  https://github.com/nicklockwood/AsyncImageView
//
//  This software is provided 'as-is', without any express or implied warranty.
//  In no event will the authors be held liable for any damages arising from the
//  use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software in a
//  product, an acknowledgment in the product documentation would be appreciated
//  but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//


#import "AsyncImageView.h"
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wgnu"


#import <Availability.h>
#if !__has_feature(objc_arc)
#error This class requires automatic reference counting
#endif


NSString *const AsyncImageLoaderErrorDomain = @"AsyncImageLoader";

NSString *const AsyncImageLoadDidFinish = @"AsyncImageLoadDidFinish";
NSString *const AsyncImageLoadDidFail = @"AsyncImageLoadDidFail";

NSString *const AsyncImageImageKey = @"image";
NSString *const AsyncImageURLKey = @"URL";
NSString *const AsyncImageCacheKey = @"cache";
NSString *const AsyncImageErrorKey = @"error";


@interface AsyncImageConnection : NSObject

@property (nonatomic, strong, readonly) NSURL *URL;
@property (nonatomic, strong, readonly) NSCache *cache;
@property (nonatomic, strong, readonly) id target;
@property (nonatomic, assign, readonly) SEL success;
@property (nonatomic, assign, readonly) SEL failure;
@property (nonatomic, readonly) UIImage *cachedImage;

@property (nonatomic, copy) dispatch_block_t cancellationToken;
@property (nonatomic, getter = isLoading) BOOL loading;
@property (atomic, getter = isCancelled) BOOL cancelled;

- (AsyncImageConnection *)initWithURL:(NSURL *)URL
                                cache:(NSCache *)cache
							   target:(id)target
							  success:(SEL)success
							  failure:(SEL)failure;

- (void)start;
- (void)cancel;

@end


@implementation AsyncImageConnection

- (AsyncImageConnection *)initWithURL:(NSURL *)URL
                                cache:(NSCache *)cache
							   target:(id)target
							  success:(SEL)success
							  failure:(SEL)failure
{
    if ((self = [self init]))
    {
        _URL = URL;
        _cache = cache;
        _target = target;
        _success = success;
        _failure = failure;
    }
    return self;
}

- (UIImage *)cachedImage
{
    UIImage *image = [self.cache objectForKey:self.URL];
    if (!image && self.URL.fileURL)
	{
		NSString *path = self.URL.absoluteURL.path;
        NSString *resourcePath = [NSBundle mainBundle].resourcePath;
		if ([path hasPrefix:resourcePath])
		{
            path = [path substringFromIndex:resourcePath.length];
            if ([path hasPrefix:@"/"])
            {
                path = [path substringFromIndex:1];
            }
            image = [UIImage imageNamed:path];
            if (image)
            {
                [self.cache setObject:image forKey:self.URL];
            }
		}
	}
    return image;
}

- (void)loadFailedWithError:(NSError *)error
{
	self.loading = NO;
	self.cancelled = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFail
                                                        object:self.target
                                                      userInfo:@{AsyncImageURLKey: self.URL,
                                                                 AsyncImageErrorKey: error}];
}

- (void)postImage:(UIImage *)image
{
    if (!self.cancelled)
    {
        NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                         image, AsyncImageImageKey,
                                         self.URL, AsyncImageURLKey,
                                         nil];
        if (self.cache)
        {
            userInfo[AsyncImageCacheKey] = self.cache;
        }

        self.loading = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:AsyncImageLoadDidFinish
                                                            object:self.target
                                                          userInfo:[userInfo copy]];
    }
    else
    {
        self.loading = NO;
        self.cancelled = NO;
    }
}

- (void)processDataInBackground:(NSData *)data
{
    if (!self.cancelled)
    {
        UIImage *image;
        @synchronized ([self class])
        {
            CGImageSourceRef imageSourceRef = CGImageSourceCreateWithData((CFDataRef)data, NULL);
            if (imageSourceRef)
            {
                CFDictionaryRef imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSourceRef, 0, NULL);
                if (imageProperties)
                {
                    NSNumber *width = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelWidth);
                    NSNumber *height = CFDictionaryGetValue(imageProperties, kCGImagePropertyPixelHeight);
                    CFRelease(imageProperties);

                    double maxSize = MAX(width.doubleValue, height.doubleValue);
                    NSDictionary *options = @{(__bridge id)kCGImageSourceShouldAllowFloat: @YES,
                                              (__bridge id)kCGImageSourceCreateThumbnailWithTransform: @YES,
                                              (__bridge id)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                                              (__bridge id)kCGImageSourceThumbnailMaxPixelSize: @(maxSize)};
                    CGImageRef imageRef = CGImageSourceCreateThumbnailAtIndex(imageSourceRef, 0,
                                                                              (__bridge CFDictionaryRef)options);
                    if (imageRef)
                    {
                        //infer scale from filename
                        CGFloat scale = 1.0;
                        NSString *path = self.URL.lastPathComponent.stringByDeletingPathExtension;
                        if ([path hasSuffix:@"@2x"]) {
                            scale = 2.0;
                        } else if ([path hasSuffix:@"@3x"]) {
                            scale = 3.0;
                        }
                        image = [UIImage imageWithCGImage:imageRef scale:scale orientation:UIImageOrientationUp];
                        CGImageRelease(imageRef);

                        //add to cache (may be cached already but it doesn't matter)
                        if (image && self.URL)
                        {
                            [self.cache setObject:image forKey:self.URL];
                        }

                        // post image
                        [self performSelectorOnMainThread:@selector(postImage:)
                                               withObject:image
                                            waitUntilDone:NO];
                    }
                }
                CFRelease(imageSourceRef);
            }
        }
        if (!image)
        {
            @autoreleasepool
            {
                NSError *error = [NSError errorWithDomain:AsyncImageLoaderErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey: @"Invalid image data"}];
                [self performSelectorOnMainThread:@selector(loadFailedWithError:) withObject:error waitUntilDone:NO];
            }
        }
    }
    else
    {
        //clean up
        [self performSelectorOnMainThread:@selector(postImage:)
                               withObject:nil
                            waitUntilDone:NO];
    }
}

- (void)loadDataInBackground
{
    if (!self.cancelled)
    {
        NSError *error;
        NSData *data = [NSData dataWithContentsOfURL:self.URL options:NSDataReadingMappedIfSafe error:&error];
        if (data)
        {
            [self processDataInBackground:data];
        }
        else
        {
            [self performSelectorOnMainThread:@selector(loadFailedWithError:) withObject:error waitUntilDone:NO];
        }
    }
}

- (void)start
{
    if (self.loading && !self.cancelled)
    {
        return;
    }
	
	//begin loading
	self.loading = YES;
	self.cancelled = NO;
    
    //check for nil URL
    if (self.URL == nil)
    {
        [self postImage:nil];
        return;
    }
    
    //check for cached image
	UIImage *image = self.cachedImage;
    if (image)
    {
        //post image
        [self performSelectorOnMainThread:@selector(postImage:) withObject:image waitUntilDone:NO];
        return;
    }

    //check if local image
    if (self.URL.fileURL)
    {
        [self performSelectorInBackground:@selector(loadDataInBackground) withObject:nil];
        return;
    }

    //begin load
    NSURLRequest *request = [NSURLRequest requestWithURL:self.URL
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:[AsyncImageLoader sharedLoader].loadingTimeout];

    __weak AsyncImageConnection *weakSelf = self;
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, __unused NSURLResponse * _Nullable response, NSError * _Nullable error) {

        AsyncImageConnection *strongSelf = weakSelf;
        if (!strongSelf || strongSelf.cancelled)
        {
            return;
        }
        if (error)
        {
            [strongSelf performSelectorOnMainThread:@selector(loadFailedWithError:) withObject:error waitUntilDone:NO];
        }
        else
        {
            [strongSelf performSelectorInBackground:@selector(processDataInBackground:) withObject:data];
        }
    }];

    [task resume];

    self.cancellationToken = ^{ [task cancel]; };
}

- (void)cancel
{
	self.cancelled = YES;
    if (self.cancellationToken)
    {
        self.cancellationToken();
    }
    self.cancellationToken = nil;
}

@end


@interface AsyncImageLoader ()

@property (nonatomic, strong) NSMutableArray<AsyncImageConnection *> *connections;

@end


@implementation AsyncImageLoader

+ (AsyncImageLoader *)sharedLoader
{
	static AsyncImageLoader *sharedInstance = nil;
	if (sharedInstance == nil)
	{
		sharedInstance = [[self alloc] init];
	}
	return sharedInstance;
}

+ (NSCache *)defaultCache
{
    static NSCache *sharedCache = nil;
	if (sharedCache == nil)
	{
		sharedCache = [[NSCache alloc] init];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(__unused NSNotification *note) {
            
            [sharedCache removeAllObjects];
        }];
	}
	return sharedCache;
}

- (instancetype)init
{
	if ((self = [super init]))
	{
        self.cache = [[self class] defaultCache];
        _concurrentLoads = 4;
        _loadingTimeout = 60.0;
		_connections = [[NSMutableArray alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(imageLoaded:)
													 name:AsyncImageLoadDidFinish
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(imageFailed:)
													 name:AsyncImageLoadDidFail
												   object:nil];
	}
	return self;
}

- (void)updateQueue
{
    //start connections
    NSUInteger count = 0;
    for (AsyncImageConnection *connection in self.connections)
    {
        if (!connection.loading)
        {
            if (connection.cachedImage)
            {
                [connection start];
            }
            else if (count < self.concurrentLoads)
            {
                count ++;
                [connection start];
            }
        }
    }
}

- (void)imageLoaded:(NSNotification *)notification
{  
    //complete connections for URL
    NSURL *URL = (notification.userInfo)[AsyncImageURLKey];
    for (NSInteger i = (NSInteger)self.connections.count - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = self.connections[(NSUInteger)i];
        if (connection.URL == URL || [connection.URL isEqual:URL])
        {
            //cancel earlier connections for same target/action
            for (NSInteger j = i - 1; j >= 0; j--)
            {
                AsyncImageConnection *earlier = self.connections[(NSUInteger)j];
                if (earlier.target == connection.target &&
                    earlier.success == connection.success)
                {
                    [earlier cancel];
                    [self.connections removeObjectAtIndex:(NSUInteger)j];
                    i--;
                }
            }
            
            //cancel connection (in case it's a duplicate)
            [connection cancel];
            
            //perform action
			UIImage *image = (notification.userInfo)[AsyncImageImageKey];
            ((void (*)(id, SEL, id, id))objc_msgSend)(connection.target, connection.success, image, connection.URL);
            
            //remove from queue
            [self.connections removeObjectAtIndex:(NSUInteger)i];
        }
    }
    
    //update the queue
    [self updateQueue];
}

- (void)imageFailed:(NSNotification *)notification
{
    //remove connections for URL
    NSURL *URL = (notification.userInfo)[AsyncImageURLKey];
    for (NSInteger i = (NSInteger)self.connections.count - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = self.connections[(NSUInteger)i];
        if ([connection.URL isEqual:URL])
        {
            //cancel connection (in case it's a duplicate)
            [connection cancel];
            
            //perform failure action
            if (connection.failure)
            {
                NSError *error = (notification.userInfo)[AsyncImageErrorKey];
                ((void (*)(id, SEL, id, id))objc_msgSend)(connection.target, connection.failure, error, URL);
            }
            
            //remove from queue
            [self.connections removeObjectAtIndex:(NSUInteger)i];
        }
    }
    
    //update the queue
    [self updateQueue];
}

- (void)loadImageWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure
{
    //check cache
    UIImage *image = [self.cache objectForKey:URL];
    if (image)
    {
        [self cancelLoadingImagesForTarget:self action:success];
        if (success)
        {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                ((void (*)(id, SEL, id, id))objc_msgSend)(target, success, image, URL);
            });
        }
        return;
    }

    //cancel loading previous URL if new URL is nil or is a local file and last URL wasn't
    if (!URL || (URL.fileURL && ![self URLForTarget:URL action:success].fileURL)) {
        [self cancelLoadingImagesForTarget:self action:success];
    }
    
    //create new connection
    AsyncImageConnection *connection = [[AsyncImageConnection alloc] initWithURL:URL
                                                                           cache:self.cache
                                                                          target:target
                                                                         success:success
                                                                         failure:failure];
    BOOL added = NO;
    for (NSUInteger i = 0, count = self.connections.count; i < count; i++)
    {
        AsyncImageConnection *existingConnection = self.connections[i];
        if (!existingConnection.loading)
        {
            [self.connections insertObject:connection atIndex:i];
            added = YES;
            break;
        }
    }
    if (!added)
    {
        [self.connections addObject:connection];
    }
    
    [self updateQueue];
}

- (void)loadImageWithURL:(NSURL *)URL target:(id)target action:(SEL)action
{
    [self loadImageWithURL:URL target:target success:action failure:nil];
}

- (void)loadImageWithURL:(NSURL *)URL
{
    [self loadImageWithURL:URL target:nil success:nil failure:nil];
}

- (void)cancelLoadingURL:(NSURL *)URL target:(id)target action:(SEL)action
{
    for (NSInteger i = (NSInteger)self.connections.count - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = self.connections[(NSUInteger)i];
        if ((!URL || [connection.URL isEqual:URL]) &&
            (!target || connection.target == target) &&
            (!action || connection.success == action))
        {
            [connection cancel];
            [self.connections removeObjectAtIndex:(NSUInteger)i];
        }
    }
}

- (void)cancelLoadingURL:(NSURL *)URL target:(id)target
{
    [self cancelLoadingURL:URL target:target action:NULL];
}

- (void)cancelLoadingURL:(NSURL *)URL
{
    [self cancelLoadingURL:URL target:nil];
}

- (void)cancelLoadingImagesForTarget:(id)target action:(SEL)action
{
    [self cancelLoadingURL:nil target:target action:action];
}

- (void)cancelLoadingImagesForTarget:(id)target
{
    [self cancelLoadingURL:nil target:target action:NULL];
}

- (NSURL *)URLForTarget:(id)target action:(SEL)action
{
    for (NSInteger i = (NSInteger)self.connections.count - 1; i >= 0; i--)
    {
        AsyncImageConnection *connection = self.connections[(NSUInteger)i];
        if (connection.target == target && (!action || connection.success == action))
        {
            return connection.URL;
        }
    }
    return nil;
}

- (NSURL *)URLForTarget:(id)target
{
    return [self URLForTarget:target action:NULL];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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


@interface AsyncImageView ()

@property (nonatomic, strong) UIActivityIndicatorView *activityView;

@end


@implementation AsyncImageView

- (void)setUp
{
	self.showActivityIndicator = (self.image == nil);
	self.activityIndicatorStyle = UIActivityIndicatorViewStyleWhite;
    self.activityIndicatorColor = [UIColor lightGrayColor];
	self.crossfadeDuration = 0.4;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame]))
    {
        [self setUp];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if ((self = [super initWithCoder:aDecoder]))
    {
        [self setUp];
    }
    return self;
}

- (void)setImageURL:(NSURL *)imageURL
{
    UIImage *image = [[AsyncImageLoader sharedLoader].cache objectForKey:imageURL];
    if (image)
    {
        self.image = image;
        return;
    }
    super.imageURL = imageURL;
    if (self.showActivityIndicator && !self.image && imageURL)
    {
        if (self.activityView == nil)
        {
            self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:self.activityIndicatorStyle];
            self.activityView.color = self.activityIndicatorColor;
            self.activityView.hidesWhenStopped = YES;
            self.activityView.center = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
            self.activityView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
            [self addSubview:self.activityView];
        }
        [self.activityView startAnimating];
    }
}

- (void)setActivityIndicatorStyle:(UIActivityIndicatorViewStyle)style
{
	_activityIndicatorStyle = style;
	[self.activityView removeFromSuperview];
	self.activityView = nil;
}

- (void)setActivityIndicatorColor:(UIColor *)activityIndicatorColor
{
    _activityIndicatorColor = activityIndicatorColor;
    self.activityView.color = activityIndicatorColor;
}

- (void)setImage:(UIImage *)image
{
    if (image != self.image && self.crossfadeDuration > 0)
    {
        CATransition *animation = [CATransition animation];
        animation.type = kCATransitionFade;
        animation.duration = self.crossfadeDuration;
        [self.layer addAnimation:animation forKey:nil];
    }
    super.image = image;
    [self.activityView stopAnimating];
}

- (void)dealloc
{
    [[AsyncImageLoader sharedLoader] cancelLoadingURL:self.imageURL target:self];
}

@end
