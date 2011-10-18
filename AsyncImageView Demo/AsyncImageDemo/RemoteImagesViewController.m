//
//  RemoteImagesViewController.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 17/10/2011.
//  Copyright (c) 2011 Charcoal Design. All rights reserved.
//

#import "RemoteImagesViewController.h"

@implementation RemoteImagesViewController

- (void)awakeFromNib
{
    //get image URLs
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"];
    NSDictionary *imagePaths = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    
    //remote image URLs
    NSMutableArray *URLs = [NSMutableArray array];
    for (NSString *path in [imagePaths objectForKey:@"Remote"])
    {
        NSURL *URL = [NSURL URLWithString:path];
        if (URL)
        {
            [URLs addObject:URL];
        }
        else
        {
            NSLog(@"'%@' is not a valid URL", path);
        }
    }
    self.imageURLs = URLs;
}

@end
