Purpose
--------------

AsyncImageView is a simple class for loading and displaying images asynchronously on iOS so that they do not lock up the UI. AsyncImageView works with URLs so it can be used with either local or remote files. Note however that AsyncImageView does not currently implement any form of caching or de-duplication of images, so it is up to the application to ensure that multiple instances of the same image are not loaded unnecessarily.


Installation
--------------

To use the AsyncImageView in an app, just drag the class files into your project.


Properties
------------

Besides the standard UIImageView properties that it inherits, AsyncImageView has only one new property:

	@property (nonatomic, retain) NSURL *imageURL;
	
Upon setting this property, AsyncImageView will begin loading/downloading the specified image on a background thread. Once the image file has loaded, the AsyncImageView image property will be set to the resultant image.


Usage
--------

To load or download an image, simply point the imageURL property at the desired image.

If you want to display a placeholder image in the meantime, just manually set the image property to your placeholder image and it will be overwritten once the image specified by the URL has loaded.

To detect when the image has finished loading, you can use KVO (Key-Value Observation) to set up an observer on the image property. When the image has finished loading, the image will be set, and with KVO you can detect this and react accordingly.