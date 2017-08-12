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

@property (nonatomic, strong) NSMutableArray *flieArray;

@end

@implementation SeafSyncInfoViewController

-(NSMutableArray *)flieArray {
    if (!_flieArray) {
        _flieArray = [NSMutableArray array];
    }
    return _flieArray;
}

-(instancetype)initWithType:(DETAILTYPE)type {
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
}

- (void)addToFileArray {
    for (SeafFile *file in SeafDataTaskManager.sharedObject.fileTasks) {
        if (![self.flieArray containsObject:file]) {
            [self.flieArray addObject:file];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.tableView reloadData];
                
            });
        }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.flieArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SeafSyncInfoCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    
    if (self.detailType == DOWNLOAD_DETAIL) {
        SeafFile *sfile = self.flieArray[indexPath.row];
        dispatch_async(dispatch_get_main_queue(), ^{
            [cell showCellWithSFile:sfile];
        });
    }
    return cell;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
