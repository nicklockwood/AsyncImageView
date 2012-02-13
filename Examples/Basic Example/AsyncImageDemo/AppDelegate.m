//
//  AppDelegate.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 17/10/2011.
//  Copyright (c) 2011 Charcoal Design. All rights reserved.
//

#import "AppDelegate.h"


@implementation AppDelegate

@synthesize window;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [window makeKeyAndVisible];
    return YES;
}

- (void)dealloc
{
    [window release];
    [super dealloc];
}

@end
