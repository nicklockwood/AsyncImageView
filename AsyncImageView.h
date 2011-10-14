//
//  AsyncImageView.h
//
//  Version 1.2.2
//
//  Created by Nick Lockwood on 03/04/2011.
//  Copyright 2010 Charcoal Design. All rights reserved.
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

#import <UIKit/UIKit.h>


extern NSString *const AsyncImageLoadDidFinish;
extern NSString *const AsyncImageLoadDidFail;

extern NSString *const AsyncImageImageKey;
extern NSString *const AsyncImageURLKey;
extern NSString *const AsyncImageCacheKey;
extern NSString *const AsyncImageErrorKey;


@interface AsyncImageCache : NSObject

+ (AsyncImageCache *)sharedCache;

@property (nonatomic, assign) BOOL useImageNamed;

- (UIImage *)imageForURL:(NSURL *)URL;
- (void)setImage:(UIImage *)image forURL:(NSURL *)URL;
- (void)removeImageForURL:(NSURL *)URL;
- (void)clearCache;

@end


@interface AsyncImageLoader : NSObject

+ (AsyncImageLoader *)sharedLoader;

@property (nonatomic, retain) AsyncImageCache *cache;
@property (nonatomic, assign) NSUInteger concurrentLoads;
@property (nonatomic, assign) NSTimeInterval loadingTimeout;
@property (nonatomic, assign) BOOL decompressImages;

- (void)loadImageWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure;
- (void)loadImageWithURL:(NSURL *)URL target:(id)target action:(SEL)action;
- (void)loadImageWithURL:(NSURL *)URL;
- (void)cancelLoadingURL:(NSURL *)URL target:(id)target action:(SEL)action;
- (void)cancelLoadingURL:(NSURL *)URL target:(id)target;
- (void)cancelLoadingURL:(NSURL *)URL;
- (NSURL *)URLForTarget:(id)target action:(SEL)action;

@end


@interface UIImageView(AsyncImageView)

@property (nonatomic, retain) NSURL *imageURL;

@end
