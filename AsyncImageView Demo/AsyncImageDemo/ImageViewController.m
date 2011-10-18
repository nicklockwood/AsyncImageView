//
//  ImageViewController.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 17/10/2011.
//  Copyright (c) 2011 Charcoal Design. All rights reserved.
//

#import "ImageViewController.h"

@implementation ImageViewController

@synthesize imageView;

- (void)dealloc
{
    [imageView release];
    [super dealloc];
}

@end
