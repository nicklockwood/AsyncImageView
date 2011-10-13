Purpose
--------------

AsyncImageView is a simple category on UIImageView for loading and displaying images asynchronously on iOS so that they do not lock up the UI. AsyncImageView works with URLs so it can be used with either local or remote files.

Loaded/downloaded images are cached in memory and are automatically cleaned up in the event of a memory warning. The AsyncImageView operates independently of the UIImage cache but by default any images located in the root of the application bundle will be stored in the UIImage cache instead, avoiding any duplication of cached images.

The library can can be used to load and cache images independently of a UIImageView as it provides direct access to the underlying loading and caching classes.


Installation
--------------

To use the AsyncImageView in an app, just drag the AsyncImageView class files into your project.


Categories
------------

The basic interface of AsyncImageView is a category that extends UIImageView with the following property:

	@property (nonatomic, retain) NSURL *imageURL;
	
Upon setting this property, AsyncImageView will begin loading/downloading the specified image on a background thread. Once the image file has loaded, the UIImageView's image property will be set to the resultant image. If you set this property again while the previous image is still loading then the images will be queued for loading in the order in which they were set.

This means that you can, for example, set a UIImageView to load a small thumbnail image and then immediately set it to load a larger image and the thumbnail image will still be loaded and set before the larger image loads.

If you access this property it will return the most recent image URL set for the UIImageView, which may not be the next one to be loaded if several image URLs have been queued on that image view. If you wish to cancel the previously loading image, use the `-cancelLoadingURL:target:` method on the AsyncImageLoader class, passing the UIImageView instance as the target (see below).


Classes
------------

AsyncImageView provides two singleton classes for advanced users:

	- AsyncImageCache
	- AsyncImageLoader
	
AsyncImageCache stores a dictionary of loaded/downloaded images by URL. It can be used to individually manipulate or remove cached images, and can be subclassed to add features not currently supported by the library (e.g. disk caching).

AsyncImageLoader manages the loading/downloading and queueing of image requests. Set properties of the shared loader instance to control loading behaviour, or call its loading methods directly to preload images off-screen.


AsyncImageCache methods
-------------------------

AsyncImageCache has the following property:

	@property (nonatomic, assign) BOOL useImageNamed;
	
By default, AsyncImageCache will redirect any requests for images located in root of the application bundle to the UIImage imageNamed cache. This avoids duplication of images, but means you lose the ability to individually remove these images from cache. Set this property to NO to store all loaded images in the AsyncImageCache instead (this won't affect images loaded using the UIImage `imageNamed:` method).

AsyncImageCache has the following methods:

	+ (AsyncImageCache *)sharedCache;

Returns a shared, singleton instance of the cache. This method is not thread safe and should only be called on the main thread.

	- (UIImage *)imageForURL:(NSURL *)URL;

Returns the cached image for a given URL, or nil if there is no cached image for that URL.

	- (void)setImage:(UIImage *)image forURL:(NSURL *)URL;

Sets or replaces the cached image for a given URL. Note that replacing a cached image will not update the image for UIImageViews that are already using it.

	- (void)removeImageForURL:(NSURL *)URL;
	
This removes a stored image from the cache. If an image for that URL was not already in the cache, this does nothing. This method does not check to see if any views are retaining the image, so removing an image and then subsequently re-loading it may result in duplicate copies of the image in memory.
	
	- (void)clearCache;

This method clears the cache and is called automatically when a low memory warning occurs. The method does not merely remove all the cached images, it checks to see which ones are in use and only removes images that are not currently being retained by other objects. This avoids duplicate copies of images building up if there are frequent low-memory warnings.


AsyncImageLoader notifications
-------------------------------

The AsyncImageLoader can generate the following notifications:

	AsyncImageLoadDidFinish
	
This fires when an image has been loaded. The notification object contains the target object that loaded the image file (e.g. the UIImageView) and the userInfo dictionary contains the following keys:

- AsyncImageImageKey

The UIImage that was loaded.

- AsyncImageURLKey

The NSURL that the image was loaded from.

- AsyncImageCacheKey

The AsyncImageCache that the image was stored in.

	AsyncImageLoadDidFail
	
This fires when an image did not load due to an error. The notification object contains the target object that attempted to load the image file (e.g. the UIImageView) and the userInfo dictionary contains the following keys:

- AsyncImageErrorKey

The NSError generated by the underlying URLConnection.

- AsyncImageURLKey

The NSURL that the image failed to load from.


AsyncImageLoader properties
----------------------------

AsyncImageLoader has the following properties:

	@property (nonatomic, retain) AsyncImageCache *cache;

The cache to be used for image load requests. You can change this value at any time and it will affect all subsequent load requests until it is changed again. By default this is set to `[AsyncImageCache sharedCache]`. Set this to nil to disable caching completely, or you can set it to a new AsyncImageCache instance or subclass for fine-grained cache control.

	@property (nonatomic, assign) NSUInteger concurrentLoads;

The number of images to load concurrently. Images are loaded on background threads but loading too many concurrently can choke the CPU. This defaults to 2;
	
	@property (nonatomic, assign) NSTimeInterval loadingTimeout;

The loading timeout, in seconds. This defaults to 60, which should be more than enough for loading locally stored images, but may be too short for downloading large images over 3G.

	@property (nonatomic, assign) BOOL decompressImages;

iOS defers decompression of loaded images until the last possible moment, which is usually the point at which they are displayed. This is efficient in terms of memory usage, but can have a negative impact on performance when you are streaming images on the fly, such as when you want to display them in a UITableView or carousel. The `decompressImages` option (enabled by default) decompresses loaded images on a background thread by pre-drawing them into a 1 pixel context (see http://www.cocoanetics.com/2011/10/avoiding-image-decompression-sickness/ for more information). Set this property to NO to disable this behaviour.


AsyncImageLoader methods
-------------------------

AsyncImageLoader has the following methods:

	- (void)loadImageWithURL:(NSURL *)URL target:(id)target success:(SEL)success failure:(SEL)failure;
	
This queues an image for download. If the queue is empty and the image is already in cache, this will trigger the success action immediately.

The target is retained by the AsyncImageLoader, however the loader will monitor to see if the target is being retained by any other objects, and will release it and terminate the file load if it is not. The target can be nil, in which case the load will still happen as normal and can completion can be detected using the `AsyncImageLoadDidFinish` and `AsyncImageLoadDidFail` notifications. 
	
	- (void)loadImageWithURL:(NSURL *)URL target:(id)target action:(SEL)action;
	
Works the same as above, except the action will only be called if the loading is successfull. Failure can still be detected using `AsyncImageLoadDidFail` notification.

	- (void)loadImageWithURL:(NSURL *)URL;
	
Works the same as above, but no target or actions are specified. Use `AsyncImageLoadDidFinish` and `AsyncImageLoadDidFail` to detect when the loading is complete.
	
	- (void)cancelLoadingURL:(NSURL *)URL target:(id)target action:(SEL)action;
	
This cancels loading the image with the specified URL for the specified target and action.
	
	- (void)cancelLoadingURL:(NSURL *)URL target:(id)target;
	
This cancels loading the image with the specified URL for any actions on the specified target;
	
	- (void)cancelLoadingURL:(NSURL *)URL;
	
This cancels loading the image with the specified URL.
	
	- (NSURL *)URLForTarget:(id)target action:(SEL)action;
	
This returns the most recent image URL set for the given target and action, which may not be the next one to be loaded if several image URLs have been queued on that target.


Usage
--------

To load or download an image, simply point the imageURL property at the desired image.

If you want to display a placeholder image in the meantime, just manually set the image property of the UIImageView to your placeholder image and it will be overwritten once the image specified by the URL has loaded.

If you want to load a smaller thumbnail image while the main image loads, just set the thumbnail URL first, then the full image URL. AsyncImageLoader will ensure that the images are loaded in the correct order. If the larger image is already cached, or loads first for some reason, the thumbnail image loading will be cancelled.

To detect when the image has finished loading, you can use NSNotificationCenter in conjunction with the `AsyncImageLoadDidFinish` notification, or you can use KVO (Key-Value Observation) to set up an observer on the UIImageView's image property. When the image has finished loading, the image will be set, and with KVO you can detect this and react accordingly.

By default, all loaded images are cached, and if the app loads a large number of images, the cache will keep building up until a memory warning is triggered. You can avoid memory warnings by manually removing items from the cache according to your own maintenance logic. You can also disable caching either universally or for specific images by setting the shared AsyncImageLoader's cache property to nil before loading an image (set it back to `[AsyncImageCache sharedInstance]` to re-enable caching afterwards).