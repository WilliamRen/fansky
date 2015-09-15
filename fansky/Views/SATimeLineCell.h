//
//  SATimeLineCell.h
//  fansky
//
//  Created by Zzy on 6/23/15.
//  Copyright (c) 2015 Zzy. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SAStatus;
@class SATimeLineCell;

@protocol SATimeLineCellDelegate <NSObject>

- (void)timeLineCell:(SATimeLineCell *)timeLineCell avatarImageViewTouchUp:(id)sender;

@end

@interface SATimeLineCell : UITableViewCell

@property (weak, nonatomic) id<SATimeLineCellDelegate> delegate;
@property (strong, nonatomic) SAStatus *status;

- (void)configWithStatus:(SAStatus *)status;

@end
