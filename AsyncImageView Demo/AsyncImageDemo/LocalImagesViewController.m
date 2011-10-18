//
//  LocalImagesViewController.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 17/10/2011.
//  Copyright (c) 2011 Charcoal Design. All rights reserved.
//

#import "LocalImagesViewController.h"

@implementation LocalImagesViewController

- (void)awakeFromNib
{
    //get image URLs
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"];
    NSDictionary *imagePaths = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    
    //local image URLs
    NSMutableArray *URLs = [NSMutableArray array];
    for (NSString *path in [imagePaths objectForKey:@"Local"])
    {
        NSString *fullPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:path];
        [URLs addObject:[NSURL fileURLWithPath:fullPath]];
    }
    self.imageURLs = URLs;
}

@end
