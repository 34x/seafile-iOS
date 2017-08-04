//
//  SeafSyncInfoCell.m
//  seafilePro
//
//  Created by three on 2017/8/1.
//  Copyright © 2017年 Seafile. All rights reserved.
//

#import "SeafSyncInfoCell.h"
#import "Debug.h"
#import "FileSizeFormatter.h"

@interface SeafSyncInfoCell ()

@end

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

-(void)showCellWithSFile:(SeafFile *)sfile
{
    sfile.delegate = self;
    
    self.nameLabel.text = sfile.name;
    self.pathLabel.text = sfile.dirPath;
    self.iconView.image = sfile.icon;
    self.sizeLabel.text = sfile.detailText;
    
    CGFloat scale = sfile.icon.size.height/sfile.icon.size.width;
    CGSize itemSize = CGSizeMake(40, scale * 40);
    UIGraphicsBeginImageContext(itemSize);
    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
    [self.iconView.image drawInRect:imageRect];
    self.iconView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (sfile.state == SEAF_DENTRY_LOADING) {
        self.progressView.hidden = NO;
    } else {
        self.progressView.hidden = YES;
    }
    
    if (sfile.progress.fractionCompleted == 1.0) {
        self.progressView.hidden = YES;
    } else {
        self.progressView.hidden = NO;
        self.progressView.progress = sfile.progress.fractionCompleted;
        self.statusLabel.text = @"";
    }
}

-(void)showCellWithUploadFile:(SeafUploadFile *)ufile
{
    self.nameLabel.text = ufile.name;
    self.pathLabel.text = ufile.lpath;
    self.iconView.image = ufile.icon;
    self.sizeLabel.text = [FileSizeFormatter stringFromLongLong:ufile.filesize];
    
    CGFloat scale = ufile.icon.size.height/ufile.icon.size.width;
    CGSize itemSize = CGSizeMake(40, scale * 40);
    UIGraphicsBeginImageContext(itemSize);
    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
    [self.iconView.image drawInRect:imageRect];
    self.iconView.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    if (ufile.uploading) {
        self.progressView.hidden = NO;
    } else {
        self.progressView.hidden = YES;
    }
    @weakify(self);
    ufile.progressBlock = ^(SeafUploadFile *file, int progress) {
        @strongify(self);
        self.progressView.progress = progress/100.00;
    };
    
    ufile.completionBlock = ^(BOOL success, SeafUploadFile *file, NSString *oid) {
        @strongify(self);
        if (success) {
            self.progressView.hidden = YES;
            self.statusLabel.text = @"已完成";
        } else {
            self.progressView.hidden = NO;
            self.statusLabel.text = @"上传中";
        }
    };
}

#pragma mark - SeafDentryDelegate
- (void)download:(SeafBase *)entry progress:(float)progress
{
    Debug(@"%f", progress);
    if (entry.state == SEAF_DENTRY_LOADING) {
        if (progress) {
            self.progressView.hidden = NO;
            [self.progressView setProgress:progress];
        }
    }
}

- (void)download:(SeafBase *)entry complete:(BOOL)updated
{
    if (updated) {
        self.progressView.hidden = YES;
        self.statusLabel.text = @"已完成";
    }
}

- (void)download:(SeafBase *)entry failed:(NSError *)error
{
    if (error) {
        self.progressView.hidden = YES;
        self.statusLabel.text = @"下载失败";
    }

}


-(void)awakeFromNib
{
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
