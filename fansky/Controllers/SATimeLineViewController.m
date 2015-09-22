
//
//  TimeLineViewController.m
//  fansky
//
//  Created by Zzy on 6/17/15.
//  Copyright (c) 2015 Zzy. All rights reserved.
//

#import "SATimeLineViewController.h"
#import "SADataManager+User.h"
#import "SATimeLineCell.h"
#import "SAUser+CoreDataProperties.h"
#import "SAStatus+CoreDataProperties.h"
#import "SAPhoto.h"
#import "SAAPIService.h"
#import "SADataManager+Status.h"
#import "SAStatusViewController.h"
#import "SAUserViewController.h"
#import "SAMessageDisplayUtils.h"
#import "SATimeLinePhotoCell.h"
#import <URBMediaFocusViewController/URBMediaFocusViewController.h>

@interface SATimeLineViewController () <NSFetchedResultsControllerDelegate, SATimeLineCellDelegate, SATimeLinePhotoCellDelegate>

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (copy, nonatomic) NSString *selectedStatusID;
@property (copy, nonatomic) NSString *selectedUserID;
@property (nonatomic, getter = isCellRegistered) BOOL cellRegistered;
@property (strong, nonatomic) URBMediaFocusViewController *imageViewController;

@end

@implementation SATimeLineViewController

static NSString *const ENTITY_NAME = @"SAStatus";

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateInterface];
    
    [self refreshData];
    
    [self fetchedResultsController];
}

- (void)refreshData
{
    [self updateDataWithRefresh:YES];
}

- (void)updateDataWithRefresh:(BOOL)refresh
{
    NSString *maxID = nil;
    if (!refresh) {
        SAStatus *lastStatus = self.fetchedResultsController.fetchedObjects.lastObject;
        if (lastStatus) {
            maxID = lastStatus.statusID;
        }
    }
    [SAMessageDisplayUtils showActivityIndicatorWithMessage:@"正在刷新"];
    if (!self.userID) {
        SAUser *currentUser = [SADataManager sharedManager].currentUser;
        [[SAAPIService sharedSingleton] timeLineWithUserID:currentUser.userID sinceID:nil maxID:maxID count:20 success:^(id data) {
            [[SADataManager sharedManager] insertOrUpdateStatusWithObjects:data type:SAStatusTypeTimeLine];
            [SAMessageDisplayUtils showSuccessWithMessage:@"刷新完成"];
            [self.refreshControl endRefreshing];
        } failure:^(NSString *error) {
            [SAMessageDisplayUtils showErrorWithMessage:error];
            [self.refreshControl endRefreshing];
        }];
    } else {
        [[SAAPIService sharedSingleton] userTimeLineWithUserID:self.userID sinceID:nil maxID:maxID count:20 success:^(id data) {
            [[SADataManager sharedManager] insertOrUpdateStatusWithObjects:data type:SAStatusTypeUserStatus];
            [SAMessageDisplayUtils showSuccessWithMessage:@"刷新完成"];
            [self.refreshControl endRefreshing];
        } failure:^(NSString *error) {
            [SAMessageDisplayUtils showErrorWithMessage:error];
            [self.refreshControl endRefreshing];
        }];
    }
}

- (void)updateInterface
{
    [self.refreshControl addTarget:self action:@selector(refreshData) forControlEvents:UIControlEventValueChanged];
    self.clearsSelectionOnViewWillAppear = YES;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 140;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        SADataManager *manager = [SADataManager sharedManager];
        
        NSSortDescriptor *createdAtSortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"createdAt" ascending:NO];
        NSArray *sortArray = [[NSArray alloc] initWithObjects: createdAtSortDescriptor, nil];
        
        SAUser *currentUser = [SADataManager sharedManager].currentUser;
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:ENTITY_NAME];
        NSString *userID;
        SAStatusTypes type;
        if (self.userID) {
            userID = self.userID;
            type = SAStatusTypeUserStatus;
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"user.userID = %@ AND (type | %d) = type", userID, type];
        } else {
            userID = currentUser.userID;
            type = SAStatusTypeTimeLine;
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"localUser.userID = %@ AND (type | %d) = type", userID, type];
        }
        fetchRequest.sortDescriptors = sortArray;
        fetchRequest.returnsObjectsAsFaults = NO;
        fetchRequest.fetchBatchSize = 6;
        
        NSString *cacheName = [NSString stringWithFormat:@"user-%@-type-%zd", userID, type];
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:manager.managedObjectContext sectionNameKeyPath:nil cacheName:cacheName];
        _fetchedResultsController.delegate = self;
        [_fetchedResultsController performFetch:nil];
    }
    return _fetchedResultsController;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.destinationViewController isKindOfClass:[SAStatusViewController class]]) {
        SAStatusViewController *statusViewController = (SAStatusViewController *)segue.destinationViewController;
        statusViewController.statusID = self.selectedStatusID;
    } else if ([segue.destinationViewController isKindOfClass:[SAUserViewController class]]) {
        SAUserViewController *userViewController = (SAUserViewController *)segue.destinationViewController;
        userViewController.userID = self.selectedUserID;
    }
}

#pragma mark - SATimeLineCellDelegate

- (void)timeLineCell:(SATimeLineCell *)timeLineCell avatarImageViewTouchUp:(id)sender
{
    self.selectedUserID = timeLineCell.status.user.userID;
    [self performSegueWithIdentifier:@"TimeLineToUserSegue" sender:nil];
}

- (void)timeLineCell:(SATimeLineCell *)timeLineCell contentURLTouchUp:(id)sender
{
    NSURL *url = timeLineCell.selectedURL;
    if ([url.host isEqualToString:@"fanfou.com"]) {
        self.selectedUserID = url.lastPathComponent;
        [self performSegueWithIdentifier:@"TimeLineToUserSegue" sender:nil];
    } else if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - SATimeLinePhotoCellDelegate

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell avatarImageViewTouchUp:(id)sender
{
    self.selectedUserID = timeLineCell.status.user.userID;
    [self performSegueWithIdentifier:@"TimeLineToUserSegue" sender:nil];
}

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell contentImageViewTouchUp:(id)sender
{
    if (!self.imageViewController){
        self.imageViewController = [[URBMediaFocusViewController alloc] init];
    }
    NSURL *imageURL = [NSURL URLWithString:timeLineCell.status.photo.largeURL];
    [self.imageViewController showImageFromURL:imageURL fromView:self.view];
}

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell contentURLTouchUp:(id)sender
{
    NSURL *url = timeLineCell.selectedURL;
    if ([url.host isEqualToString:@"fanfou.com"]) {
        self.selectedUserID = url.lastPathComponent;
        [self performSegueWithIdentifier:@"TimeLineToUserSegue" sender:nil];
    } else if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    if (type == NSFetchedResultsChangeInsert) {
        [self.tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    @try {
        [self.tableView beginUpdates];
    }
    @catch (NSException *exception) {
        
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    @try {
        [self.tableView endUpdates];
    }
    @catch (NSException *exception) {
        
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfItems = [[self.fetchedResultsController.sections objectAtIndex:section] numberOfObjects];
    return numberOfItems;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *const cellName = @"SATimeLineCell";
    static NSString *const photoCellName = @"SATimeLinePhotoCell";
    if (!self.isCellRegistered) {
        [tableView registerNib:[UINib nibWithNibName:cellName bundle:nil] forCellReuseIdentifier:cellName];
        [tableView registerNib:[UINib nibWithNibName:photoCellName bundle:nil] forCellReuseIdentifier:photoCellName];
        self.cellRegistered = YES;
    }
    SAStatus *status = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (status.photo.imageURL) {
        SATimeLinePhotoCell *cell = [tableView dequeueReusableCellWithIdentifier:photoCellName forIndexPath:indexPath];
        [cell configWithStatus:status];
        cell.delegate = self;
        return cell;
    }
    SATimeLineCell *cell = [tableView dequeueReusableCellWithIdentifier:cellName forIndexPath:indexPath];
    [cell configWithStatus:status];
    cell.delegate = self;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SAStatus *status = [self.fetchedResultsController objectAtIndexPath:indexPath];
    self.selectedStatusID = status.statusID;
    [self performSegueWithIdentifier:@"TimeLineToStatusSegue" sender:nil];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([cell isKindOfClass:[SATimeLineCell class]]) {
        SATimeLineCell *timeLineCell = (SATimeLineCell *)cell;
        [timeLineCell loadAllImages];
    } else if ([cell isKindOfClass:[SATimeLinePhotoCell class]]) {
        SATimeLinePhotoCell *timeLinePhotoCell = (SATimeLinePhotoCell *)cell;
        [timeLinePhotoCell loadAllImages];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (fabs(scrollView.contentSize.height - scrollView.frame.size.height - scrollView.contentOffset.y) < 1.f) {
        [self updateDataWithRefresh:NO];
    }
}

#pragma mark - ARSegmentControllerDelegate

- (NSString *)segmentTitle
{
    return @"时间线";
}

- (UIScrollView *)streachScrollView
{
    return self.tableView;
}

@end
