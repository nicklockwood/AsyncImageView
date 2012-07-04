//
//  SettingsViewController.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 18/10/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "SettingsViewController.h"
#import "AsyncImageView.h"


@implementation SettingsViewController

@synthesize cacheEnabledSwitch;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cacheEnabledSwitch.on = ([AsyncImageLoader sharedLoader].cache != nil);
}

- (IBAction)toggleCache:(UISwitch *)sender
{
    [AsyncImageLoader sharedLoader].cache = (sender.on)? [AsyncImageLoader defaultCache]: nil;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    self.cacheEnabledSwitch = nil;
}

- (void)dealloc
{
    [cacheEnabledSwitch release];
    [super dealloc];
}

@end
