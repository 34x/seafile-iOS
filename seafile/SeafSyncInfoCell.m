//
//  SeafSyncInfoCell.m
//  seafilePro
//
//  Created by three on 2017/8/1.
//  Copyright © 2017年 Seafile. All rights reserved.
//

#import "SeafSyncInfoCell.h"

@implementation SeafSyncInfoCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
