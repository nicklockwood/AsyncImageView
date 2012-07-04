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