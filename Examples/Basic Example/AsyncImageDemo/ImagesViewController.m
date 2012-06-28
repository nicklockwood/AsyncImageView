//
//  ImagesViewController.m
//  AsyncImageDemo
//
//  Created by Nick Lockwood on 17/10/2011.
//  Copyright (c) 2011 Charcoal Design. All rights reserved.
//

#import "ImagesViewController.h"
#import "ImageViewController.h"
#import "AsyncImageView.h"


@implementation ImagesViewController

@synthesize imageURLs;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //set title
    self.navigationItem.title = self.navigationController.tabBarItem.title;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    //unload view to demonstrate caching
    self.view = nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [imageURLs count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        //create new cell
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
        
        //common settings
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.frame = CGRectMake(0.0f, 0.0f, 44.0f, 44.0f);
        cell.imageView.clipsToBounds = YES;
    }
    else
    {
        //cancel loading previous image for cell
        [[AsyncImageLoader sharedLoader] cancelLoadingImagesForTarget:cell.imageView];
    }
    
    //set placeholder image or cell won't update when image is loaded
    cell.imageView.image = [UIImage imageNamed:@"Placeholder.png"];
    
    //load the image
    cell.imageView.imageURL = [imageURLs objectAtIndex:indexPath.row];
    
    //display image path
    cell.textLabel.text = [[[imageURLs objectAtIndex:indexPath.row] path] lastPathComponent];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    ImageViewController *viewController = [[ImageViewController alloc] initWithNibName:@"ImageViewController" bundle:nil];
    [viewController view]; // load view
    viewController.imageView.imageURL = [imageURLs objectAtIndex:indexPath.row];
    viewController.title = [[[imageURLs objectAtIndex:indexPath.row] path] lastPathComponent];
    [self.navigationController pushViewController:viewController animated:YES];
    [viewController release];
}

- (void)dealloc
{
    [imageURLs release];
    [super dealloc];
}

@end
