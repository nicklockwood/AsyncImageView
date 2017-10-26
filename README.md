***************
WARNING: THIS PROJECT IS DEPRECATED
====================================
It will not receive any future updates or bug fixes. If you are using it, please migrate to another solution.
***************


Purpose
--------------

AsyncImageView includes both a simple category on UIImageView for loading and displaying images asynchronously on iOS so that they do not lock up the UI, and a UIImageView subclass for more advanced features. AsyncImageView works with URLs so it can be used with either local or remote files.

Loaded/downloaded images are cached in memory and are automatically cleaned up in the event of a memory warning. The AsyncImageView operates independently of the UIImage cache, but by default any images located in the root of the application bundle will be stored in the UIImage cache instead, avoiding any duplication of cached images.

The library can also be used to load and cache images independently of a UIImageView as it provides direct access to the underlying loading and caching classes.


Supported OS & SDK Versions
-----------------------------

* Supported build target - iOS 9.3 (Xcode 7.3, Apple LLVM compiler 7.1)
* Earliest supported deployment target - iOS 7.0
* Earliest compatible deployment target - iOS 4.3

NOTE: 'Supported' means that the library has been tested with this version. 'Compatible' means that the library should work on this iOS version (i.e. it doesn't rely on any unavailable SDK features) but is no longer being tested for compatibility and may require tweaking or bug fixes to run correctly.


ARC Compatibility
------------------

As of version 1.5, AsyncImageView requires ARC. If you wish to use AsyncImageView in a non-ARC project, just add the -fobjc-arc compiler flag to the AsyncImageView.m file. To do this, go to the Build Phases tab in your target settings, open the Compile Sources group, double-click AsyncImageView.m in the list and type -fobjc-arc into the popover.

If you wish to convert your whole project to ARC, comment out the #error line in AsyncImageView.m, then run the Edit > Refactor > Convert to Objective-C ARC... tool in Xcode and make sure all files that you wish to use ARC for (including AsyncImageView.m) are checked.


Thread Safety
--------------

AsyncImageView uses threading internally, but none of the AsyncImageView external interfaces are thread safe, and you should not call any methods or set any properties on any of the AsyncImageView classes except on the main thread.


Installation
--------------

To use the AsyncImageView in an app, just drag the AsyncImageView class files into your project.


Usage
--------

You can use the AsyncImageView class exactly as you would use a UIImageView. If you want to use it in Interface Builder, drag a regular UImageView or media image into your view as normal, then change its class to AsyncImageView in the inspector.

For cases where you cannot use an AsyncImageView, such as the embedded imageView of a UIButton or UITableView, the UIImageView category means that you can still set the imageURL property on the imageView to load the image in the background. You will not get the advanced features of the AsyncImageView class this way however (such as the loading spinner), unless you re-implement them yourself.

To load or download an image, set the imageURL property to the URL of the desired image. This can be a remote URL or a local file URL that points to the application's bundle or documents folder.

If you want to display a placeholder image in the meantime, just manually set the image property of the UIImageView to your placeholder image and it will be overwritten once the image specified by the URL has loaded.

If you want to asynchronously load a smaller thumbnail image while the main image loads, just set the thumbnail URL first, then the full image URL. AsyncImageLoader will ensure that the images are loaded in the correct order. If the larger image is already cached, or loads first for some reason, the thumbnail image loading will be cancelled.

To detect when the image has finished loading, you can use NSNotificationCenter in conjunction with the `AsyncImageLoadDidFinish` notification, or you can use KVO (Key-Value Observation) to set up an observer on the UIImageView's image property. When the image has finished loading, the image will be set, and with KVO you can detect this and react accordingly.

By default, all loaded images are cached, and if the app loads a large number of images, the cache will keep building up until a memory warning is triggered. You can avoid memory warnings by manually removing items from the cache according to your own maintenance logic. You can also disable caching either universally or for specific images by setting the shared AsyncImageLoader's cache property to `nil` before loading an image (set it back to `[AsyncImageLoader sharedInstance]` to re-enable caching afterwards).


Release Notes
----------------

Version 1.6

- Now requires iOS 7 or later
- Updated internal networking stack to use NSURLSession
- Added fast path for local files
- Fixed warnings on latest Xcode
- Moved documentation into the header file
- Added nullability annotations
- Added activityIndicatorColor
- Now supports loading @3x images

Version 1.5.1

- Fixed accidental recursion
- Fixed mismatched selector

Version 1.5

- Now works correctly on ARM64
- Now requires ARC (see README for details)
- Loaded images are now decompressed prior to drawing to avoid stutter
- Spinner no longer shows if nil URL is set
- Removed redundant crossfadeImages property
- Now conforms to -Weverything warning level
- Added podspec

Version 1.4

- Loading queue is now LIFO (Last-In, First-Out) for better performance
- Removed AsyncImageCache class (replaced with ordinary NSCache)
- Fixed some bugs when checking for duplicate items in UIImage cache
- AsyncImageView no longer requires QuartzCore framework

Version 1.3

- Added additional effects options to AsyncImageView
- Added additional AsyncImageLoader methods
- Fixed broken example
- Added Effects example
- AsyncImageView now fades in the first time image is set
- Fixed memory leak in AsyncImageView
- Update ARC Helper
- Added new AsyncImageView class with loading spinner and crossfade effect.
- Fixed crash when setting a nil imageURL.
- Fixed crash when image fails to load.
- Now requires the QuartzCore framework.
- Now requires iOS 4.x

Version 1.2.3

- Improved queuing behaviour so cached images aren't blocked from appearing by slow loading images in the queue.
- Added example project.

Version 1.2.2

- Fixed crash when accessing imageURL that has already been released.
- Fixed some thread concurrency issues

Version 1.2.1

- Fixed crash when attempting to load a corrupt image, or a URL that isn't a valid image file.

Version 1.2

- Images are now automatically decompressed on a background thread after loading before being displayed. This reduces stuttering when displaying the images in a scrolling view such as a UITableView or carousel.
- Images located in the root of the application bundle will now be stored in the UIImage imageNamed cache instead of in the AsyncImageCache by default. This avoids duplication of images loaded via different mechanisms.
- It is now possible to disable caching, or use multiple different caches for different images.

Version 1.1

- AsyncImageView is now a category on UIImageView instead of a standalone class, making it easier to use with existing code or classes.
- Now uses asynchronous NSURLConnections for loading, allowing image loading to be cancelled partway through.
- Loaded images are now cached in memory, and de-duplication is handled automatically.
- Added public AsyncImageCache and AsyncImageLoader classes, for fine-grained control over loading and caching.

Version 1.0

- Initial release
