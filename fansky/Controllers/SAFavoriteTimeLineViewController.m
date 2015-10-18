//
//  SAFavoriteTimeLineViewController.m
//  fansky
//
//  Created by Zzy on 10/18/15.
//  Copyright © 2015 Zzy. All rights reserved.
//

#import "SAFavoriteTimeLineViewController.h"
#import "SAMessageDisplayUtils.h"
#import "SADataManager+Status.h"
#import "SAAPIService.h"
#import "SAStatusViewController.h"
#import "SAUserViewController.h"
#import "SATimeLineCell.h"
#import "SATimeLinePhotoCell.h"
#import "SAComposeViewController.h"
#import "SAStatus+CoreDataProperties.h"
#import "SAUser+CoreDataProperties.h"
#import "SAPhoto+CoreDataProperties.h"
#import <DTCoreText/DTCoreText.h>
#import <URBMediaFocusViewController/URBMediaFocusViewController.h>

@interface SAFavoriteTimeLineViewController () <SATimeLineCellDelegate, SATimeLinePhotoCellDelegate>

@property (strong, nonatomic) NSArray *favoriteTimeLineList;
@property (nonatomic) NSUInteger page;
@property (copy, nonatomic) NSString *selectedStatusID;
@property (copy, nonatomic) NSString *selectedUserID;
@property (nonatomic, getter = isCellRegistered) BOOL cellRegistered;
@property (strong, nonatomic) URBMediaFocusViewController *imageViewController;

@end

@implementation SAFavoriteTimeLineViewController

static NSString *const ENTITY_NAME = @"SAStatus";
static NSUInteger FAVORITE_TIME_LINE_COUNT = 40;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self updateInterface];
    
    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];
    [self.tableView setEditing:NO animated:NO];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [SAMessageDisplayUtils dismiss];
}

- (void)refreshData
{
    [self updateDataWithRefresh:YES];
}

- (void)updateDataWithRefresh:(BOOL)refresh
{
    if (!self.favoriteTimeLineList) {
        self.favoriteTimeLineList = [[NSArray alloc] init];
    }
    if (!refresh) {
        self.page++;
    } else {
        self.page = 1;
    }
    void (^success)(id data) = ^(id data) {
        NSArray *originalList = (NSArray *)data;
        __block NSMutableArray *tempFavoriteTimeLineList = [[NSMutableArray alloc] init];
        [originalList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            SAStatus *status = [[SADataManager sharedManager] statusWithObject:obj localUsers:nil type:SAStatusTypeFavoriteStatus];
            [tempFavoriteTimeLineList addObject:status];
        }];
        if (self.page > 1) {
            NSMutableArray *existList = [self.favoriteTimeLineList mutableCopy];
            [existList addObjectsFromArray:tempFavoriteTimeLineList];
            self.favoriteTimeLineList = [existList copy];
        } else {
            self.favoriteTimeLineList = [tempFavoriteTimeLineList copy];
        }
        [self.tableView reloadData];
        [SAMessageDisplayUtils dismiss];
    };
    void (^failure)(NSString *error) = ^(NSString *error) {
        [SAMessageDisplayUtils showErrorWithMessage:error];
    };
    
    [SAMessageDisplayUtils showProgressWithMessage:@"正在刷新"];
    [[SAAPIService sharedSingleton] userFavoriteTimeLineWithUserID:self.userID count:FAVORITE_TIME_LINE_COUNT page:self.page success:success failure:failure];
}

- (void)updateInterface
{
    self.clearsSelectionOnViewWillAppear = YES;
    self.tableView.tableFooterView = [UIView new];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
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
    [self performSegueWithIdentifier:@"FavoriteTimeLineToUserSegue" sender:nil];
}

- (void)timeLineCell:(SATimeLineCell *)timeLineCell contentURLTouchUp:(id)sender
{
    NSURL *url = timeLineCell.selectedURL;
    if ([url.host isEqualToString:@"fanfou.com"]) {
        self.selectedUserID = url.lastPathComponent;
        [self performSegueWithIdentifier:@"FavoriteTimeLineToUserSegue" sender:nil];
    } else if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - SATimeLinePhotoCellDelegate

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell avatarImageViewTouchUp:(id)sender
{
    self.selectedUserID = timeLineCell.status.user.userID;
    [self performSegueWithIdentifier:@"FavoriteTimeLineToUserSegue" sender:nil];
}

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell contentImageViewTouchUp:(id)sender
{
    if (!self.imageViewController){
        self.imageViewController = [[URBMediaFocusViewController alloc] init];
        self.imageViewController.shouldDismissOnImageTap = YES;
    }
    NSURL *imageURL = [NSURL URLWithString:timeLineCell.status.photo.largeURL];
    [self.imageViewController showImageFromURL:imageURL fromView:self.view];
}

- (void)timeLinePhotoCell:(SATimeLinePhotoCell *)timeLineCell contentURLTouchUp:(id)sender
{
    NSURL *url = timeLineCell.selectedURL;
    if ([url.host isEqualToString:@"fanfou.com"]) {
        self.selectedUserID = url.lastPathComponent;
        [self performSegueWithIdentifier:@"FavoriteTimeLineToUserSegue" sender:nil];
    } else if ([url.scheme isEqualToString:@"http"] || [url.scheme isEqualToString:@"https"]) {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.favoriteTimeLineList.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SAStatus *status = [self.favoriteTimeLineList objectAtIndex:indexPath.row];
    UIColor *linkColor = [UIColor colorWithRed:85 / 255.0 green:172 / 255.0 blue:238 / 255.0 alpha:1];
    
    NSDictionary *optionDictionary = @{DTDefaultFontName: @"HelveticaNeue-Light",
                                       DTDefaultFontSize: @(16),
                                       DTDefaultLinkColor: linkColor,
                                       DTDefaultLinkHighlightColor: linkColor,
                                       DTDefaultLinkDecoration: @(NO),
                                       DTDefaultLineHeightMultiplier: @(1.8)};
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithHTMLData:[status.text dataUsingEncoding:NSUnicodeStringEncoding] options:optionDictionary documentAttributes:nil];
    
    DTCoreTextLayouter *layouter = [[DTCoreTextLayouter alloc] initWithAttributedString:attributedString];
    
    CGFloat width = self.tableView.frame.size.width - 86;
    CGRect maxRect = CGRectMake(0, 0, width, CGFLOAT_HEIGHT_UNKNOWN);
    NSRange entireString = NSMakeRange(0, attributedString.length);
    DTCoreTextLayoutFrame *layoutFrame = [layouter layoutFrameWithRect:maxRect range:entireString];
    CGFloat offset = 62;
    if (status.photo.imageURL) {
        offset = width / 2 + 16 + 10 + 46;
    }
    return layoutFrame.frame.size.height + offset;
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
    SAStatus *status = [self.favoriteTimeLineList objectAtIndex:indexPath.row];
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
    SAStatus *status = [self.favoriteTimeLineList objectAtIndex:indexPath.row];
    self.selectedStatusID = status.statusID;
    [self performSegueWithIdentifier:@"FavoriteTimeLineToStatusSegue" sender:nil];
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SAStatus *status = [self.favoriteTimeLineList objectAtIndex:indexPath.row];
    UITableViewRowAction *repostAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"转发" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        SAComposeViewController *composeViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SAComposeViewController"];
        composeViewController.repostStatusID = status.statusID;
        [self presentViewController:composeViewController animated:YES completion:nil];
    }];
    repostAction.backgroundColor = [UIColor colorWithRed:85 / 255.0 green:172 / 255.0 blue:238 / 255.0 alpha:1];
    UITableViewRowAction *replyAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"回复" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath) {
        SAComposeViewController *composeViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"SAComposeViewController"];
        composeViewController.replyToStatusID = status.statusID;
        [self presentViewController:composeViewController animated:YES completion:nil];
    }];
    replyAction.backgroundColor = [UIColor lightGrayColor];
    return @[repostAction, replyAction];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    if (fabs(scrollView.contentSize.height - scrollView.frame.size.height - scrollView.contentOffset.y) < scrollView.contentSize.height * 0.3) {
        [self updateDataWithRefresh:NO];
    }
}

#pragma mark - ARSegmentControllerDelegate

- (NSString *)segmentTitle
{
    return @"收藏";
}

- (UIScrollView *)streachScrollView
{
    return self.tableView;
}

@end