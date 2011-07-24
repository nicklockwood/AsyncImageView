//
//  AsyncImageView.m
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


@implementation AsyncImageView

@synthesize imageURL;

- (void)downloadImageURLInBackground:(NSURL *)_imageURL
{
    AsyncImageView *selfReference = [self retain];
    @synchronized ([self class])
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSData *data = [[NSData alloc] initWithContentsOfURL:_imageURL];
        UIImage *image = [[UIImage alloc] initWithData:data];
        if ([_imageURL isEqual:imageURL])
        {
            [self performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
        }
        [image release];
        [data release];
        [pool release];
    }
    [selfReference release];
}

- (void)setImageURL:(NSURL *)_imageURL
{
    if (imageURL != _imageURL)
    {
        [imageURL release];
        imageURL = [_imageURL retain];
        [self performSelectorInBackground:@selector(downloadImageURLInBackground:)
                           withObject:imageURL];
    }
}

- (void)dealloc
{
	[imageURL release];
	[super dealloc];
}

@end
