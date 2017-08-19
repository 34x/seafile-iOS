//
//  SeafUpDownloadViewController.m
//  seafilePro
//
//  Created by three on 2017/7/29.
//  Copyright © 2017年 Seafile. All rights reserved.
//

#import "SeafSyncInfoViewController.h"
#import "SeafSyncInfoCell.h"
#import "Debug.h"
#import "SeafDataTaskManager.h"
#import "SeafFile.h"
#import "SeafPhoto.h"

static NSString *cellIdentifier = @"SeafSyncInfoCell";

@interface SeafSyncInfoViewController ()<SeafDentryDelegate>

@property (nonatomic, strong) NSMutableArray *fileArray;
@property (nonatomic, strong) NSMutableArray *downloadingArray;

@end

@implementation SeafSyncInfoViewController

- (NSMutableArray *)fileArray {
    if (!_fileArray) {
        _fileArray = [NSMutableArray array];
    }
    return _fileArray;
}

- (NSMutableArray *)downloadingArray {
    if (!_downloadingArray) {
        _downloadingArray = [NSMutableArray array];
    }
    return _downloadingArray;
}

- (instancetype)initWithType:(DETAILTYPE)type {
    self = [super init];
    if (self) {
        self.detailType = type;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 50.0;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerNib:[UINib nibWithNibName:@"SeafSyncInfoCell" bundle:nil]
         forCellReuseIdentifier:cellIdentifier];
    
    if([self respondsToSelector:@selector(edgesForExtendedLayout)])
        self.edgesForExtendedLayout = UIRectEdgeAll;

    if (self.detailType == DOWNLOAD_DETAIL) {
        self.navigationItem.title = @"正在下载";
    } else {
        self.navigationItem.title = @"正在上传";
    }
    
    [self addToFileArray];

    WS(weakSelf);
    SeafDataTaskManager.sharedObject.trySyncBlock = ^{
        @autoreleasepool {
            [weakSelf addToFileArray];
        }
    };

    SeafDataTaskManager.sharedObject.finishBlock = ^(SeafFile *file) {
        [weakSelf.downloadingArray removeObject:file];
        [weakSelf.fileArray addObject:file];
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.tableView reloadData];
        });
    };
}

- (void)addToFileArray {
    if (SeafDataTaskManager.sharedObject.fileTasks.count > 0) {
        for (SeafFile *file in SeafDataTaskManager.sharedObject.fileTasks) {
            if (file.state != SEAF_DENTRY_SUCCESS || file.state != SEAF_DENTRY_FAILURE) {
                if (![self.downloadingArray containsObject:file]) {
                    [self.downloadingArray addObject:file];
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
            });
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return self.downloadingArray.count;
    } else {
        return self.fileArray.count;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 24;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSString *text = nil;
    if (section == 0) {
        text = @"正在下载";
    } else {
        text = @"下载完成";
    }
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 3, tableView.bounds.size.width - 10, 18)];
    label.font = [UIFont systemFontOfSize:12];
    label.text = text;
    label.textColor = [UIColor darkTextColor];
    label.backgroundColor = [UIColor clearColor];
    [headerView setBackgroundColor:[UIColor colorWithRed:246/255.0 green:246/255.0 blue:250/255.0 alpha:1.0]];
    [headerView addSubview:label];
    return headerView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SeafSyncInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    if (self.detailType == DOWNLOAD_DETAIL) {
        if (indexPath.section == 0) {
            SeafFile *sfile = self.downloadingArray[indexPath.row];
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell showCellWithSFile:sfile];
            });
        } else {
            SeafFile *sfile = self.fileArray[indexPath.row];
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell showCellWithSFile:sfile];
            });
        }
    }
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
