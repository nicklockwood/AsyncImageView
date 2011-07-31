Version 1.1

- AsyncImageView is now a category on UIImageView instead of a standalone class, making it easier to use with existing code or classes.
- Now uses asynchronous NSURLConnections for loading, allowing image loading to be cancelled partway through.
- Loaded images are now cached in memory, and de-duplication is handled automatically.
- Added public AsyncImageCache and AsyncImageLoader classes, for fine-grained control over loading and caching.

Version 1.0

- Initial release