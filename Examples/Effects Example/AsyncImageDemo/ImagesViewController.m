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
	
	//get image URLs
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Images" ofType:@"plist"];
    NSArray *imagePaths = [NSArray arrayWithContentsOfFile:plistPath];
    
    //remote image URLs
    NSMutableArray *URLs = [NSMutableArray array];
    for (NSString *path in imagePaths)
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
    
#define IMAGE_VIEW_TAG 99
	
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil)
    {
        //create new cell
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		
		//add AsyncImageView to cell
		AsyncImageView *imageView = [[AsyncImageView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 44.0f, 44.0f)];
		imageView.contentMode = UIViewContentModeScaleAspectFill;
		imageView.clipsToBounds = YES;
		imageView.tag = IMAGE_VIEW_TAG;
		[cell addSubview:imageView];
		[imageView release];
		
		//common settings
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
		cell.indentationWidth = 44.0f;
		cell.indentationLevel = 1;
    }
    
	//get image view
	AsyncImageView *imageView = (AsyncImageView *)[cell viewWithTag:IMAGE_VIEW_TAG];
	
    //cancel loading previous image for cell
    [[AsyncImageLoader sharedLoader] cancelLoadingImagesForTarget:imageView];
    
    //load the image
    imageView.imageURL = [imageURLs objectAtIndex:indexPath.row];
        
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
