//
//  SeafBackgroundTaskManager.m
//  Pods
//
//  Created by Wei W on 4/9/17.
//
//

#import "SeafDataTaskManager.h"
#import "SeafDir.h"
#import "Debug.h"
#import "SeafFile.h"

@interface SeafDataTaskManager()

@property NSUserDefaults *storage;

@property (retain) NSMutableArray *uTasks;
@property (retain) NSMutableArray *uploadingTasks;

@property (nonatomic, assign) NSInteger uploadingCount;
@property (nonatomic, assign) NSInteger activeUploadingCount;

@property (nonatomic, assign) NSInteger fileDownloadingCount;
@property (nonatomic, assign) NSInteger activeFileDownloadingCount;
@property (nonatomic, assign) NSInteger activeThumbDownloadingCount;

@property unsigned long failedNum;

@property NSTimer *taskTimer;

@end

@implementation SeafDataTaskManager

-(NSMutableArray *)fileQueuedTasks {
    if (!_fileQueuedTasks) {
        _fileQueuedTasks = [NSMutableArray array];
    }
    return _fileQueuedTasks;
}

- (NSMutableArray *)fileTasks {
    if (!_fileTasks) {
        _fileTasks = [NSMutableArray array];
    }
    return _fileTasks;
}

- (NSMutableArray *)thumbTasks {
    if (!_thumbTasks) {
        _thumbTasks = [NSMutableArray array];
    }
    return _thumbTasks;
}

- (NSMutableArray *)thumbQueuedTasks {
    if (!_thumbQueuedTasks) {
        _thumbQueuedTasks = [NSMutableArray array];
    }
    return _thumbQueuedTasks;
}

- (NSMutableArray *)avatarTasks {
    if (!_avatarTasks) {
        _avatarTasks = [NSMutableArray array];
    }
    return _avatarTasks;
}

+ (SeafDataTaskManager *)sharedObject
{
    static SeafDataTaskManager *object = nil;
    if (!object) {
        object = [SeafDataTaskManager new];
    }
    return object;
}

- (id)init
{
    if (self = [super init]) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];

        _uTasks = [NSMutableArray new];
        _uploadingTasks = [NSMutableArray new];
        
        self.fileDownloadingCount = 0;
        self.activeFileDownloadingCount = 0;
        self.activeThumbDownloadingCount = 0;
        [self startTimer];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cacheCleared:) name:@"clearCache" object:nil];
    }
    return self;
}

#pragma mark- upload
- (void)addBackgroundUploadTask:(SeafUploadFile *)file
{
    [file resetFailedAttempt];
    @synchronized (self.uTasks) {
        if (![self.uTasks containsObject:file] && ![self.uploadingTasks containsObject:file]) {
            [self.uTasks addObject:file];
        } else
            Warning("upload task file %@ already exist", file.lpath);
    }
    [self performSelectorInBackground:@selector(tryUpload) withObject:file];
}

- (void)tryUpload
{
    Debug("tryUpload uploading:%ld left:%ld", (long)self.uploadingTasks.count, (long)self.uTasks.count);
    if (self.uTasks.count == 0) return;
    NSMutableArray *todo = [[NSMutableArray alloc] init];
    @synchronized (self.uTasks) {
        NSMutableArray *arr = [self.uTasks mutableCopy];
        for (SeafUploadFile *file in arr) {
            if (self.uploadingTasks.count + todo.count + self.failedNum >= 3) break;
            Debug("ufile %@ canUpload:%d, uploaded:%d", file.lpath, file.canUpload, file.uploaded);
            if (!file.canUpload) continue;
            [self.uTasks removeObject:file];
            if (!file.uploaded) {
                [todo addObject:file];
            }
        }
    }
    double delayInMs = 400.0;
    NSInteger uploadingCount = self.uploadingTasks.count;
    for (int i = 0; i < todo.count; i++) {
        SeafUploadFile *file = [todo objectAtIndex:i];
        if (!file.udir) continue;
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (i+uploadingCount) * delayInMs * NSEC_PER_MSEC);
        dispatch_after(popTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^(void){
            [file doUpload];
        });
        
        @synchronized (self.uploadingTasks) {
            [self.uploadingTasks addObject:file];
        }
    }
}

- (void)finishUpload:(SeafUploadFile *)file result:(BOOL)result
{
    Debug("upload %ld, result=%d, file=%@, udir=%@", (long)self.uploadingTasks.count, result, file.lpath, file.udir.path);
    @synchronized (self.uploadingTasks) {
        [self.uploadingTasks removeObject:file];
        if ([file isKindOfClass:[SeafUploadFile class]]) {
            self.uploadingCount -= 1;
            if (self.trySyncBlock) {
                self.trySyncBlock();
            }
        }
    }
    
    if (result) {
        self.failedNum = 0;
    } else {
        self.failedNum ++;
        if (!file.removed) {
            [self.uTasks addObject:file];
        } else
            Debug("Upload file %@ removed.", file.name);
        if (self.failedNum >= 3) {
            [self performSelector:@selector(tryUpload) withObject:nil afterDelay:10.0];
            self.failedNum = 2;
            return;
        }
    }
    [self performSelector:@selector(tick:) withObject:_taskTimer afterDelay:0.1];
    if (self.trySyncBlock) {
        self.trySyncBlock();
    }
}

- (unsigned long)backgroundUploadingNum
{
    return self.uploadingTasks.count + self.uTasks.count;
}

- (void)removeBackgroundUploadTask:(SeafUploadFile *)file
{
    @synchronized (self.uTasks) {
        [self.uTasks removeObject:file];
    }
    
    @synchronized (self.uploadingTasks) {
        [self.uploadingTasks removeObject:file];
    }
}

- (void)cancelAutoSyncTasks:(SeafConnection *)conn
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    @synchronized (self.uTasks) {
        for (SeafUploadFile *ufile in self.uTasks) {
            if (ufile.autoSync && ufile.udir->connection == conn) {
                [arr addObject:ufile];
            }
        }
    }
    @synchronized (self.uploadingTasks) {
        for (SeafUploadFile *ufile in self.uploadingTasks) {
            if (ufile.autoSync && ufile.udir->connection == conn) {
                [arr addObject:ufile];
            }
        }
    }
    Debug("clear %ld photos", (long)arr.count);
    for (SeafUploadFile *ufile in arr) {
        [conn removeUploadfile:ufile];
    }
}

- (void)cancelAutoSyncVideoTasks:(SeafConnection *)conn
{
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    @synchronized (self.uTasks) {
        for (SeafUploadFile *ufile in self.uTasks) {
            if (ufile.autoSync && ufile.udir->connection == conn && !ufile.isImageFile) {
                [arr addObject:ufile];
            }
        }
    }
    @synchronized (self.uploadingTasks) {
        for (SeafUploadFile *ufile in self.uploadingTasks) {
            if (ufile.autoSync && ufile.udir->connection == conn && !ufile.isImageFile) {
                [arr addObject:ufile];
            }
        }
    }
    for (SeafUploadFile *ufile in arr) {
        Debug("Remove autosync video file: %@, %@", ufile.lpath, ufile.assetURL);
        [conn removeUploadfile:ufile];
    }
}

- (void)tick:(NSTimer *)timer
{
    if (![[AFNetworkReachabilityManager sharedManager] isReachable]) {
        return;
    }
    if (self.uTasks.count > 0)
        [self tryUpload];
}

- (void)startTimer
{
    Debug("Start timer.");
    [self tick:nil];
    _taskTimer = [NSTimer scheduledTimerWithTimeInterval:5*60
                                                      target:self
                                                    selector:@selector(tick:)
                                                    userInfo:nil
                                                     repeats:YES];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        [self tick:_taskTimer];
    }];
}

- (void)noException:(void (^)())block
{
    @try {
        block();
    }
    @catch (NSException *exception) {
        Warning("Failed to run block:%@", block);
    } @finally {
    }

}

- (void)assetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock
{
    [self.assetsLibrary assetForURL:assetURL
                        resultBlock:^(ALAsset *asset) {
                            // Success #1
                            if (asset){
                                [self noException:^{
                                    resultBlock(asset);
                                }];
                                // No luck, try another way
                            } else {
                                // Search in the Photo Stream Album
                                [self.assetsLibrary enumerateGroupsWithTypes:ALAssetsGroupPhotoStream
                                                                  usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                                                      [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                                                          if([result.defaultRepresentation.url isEqual:assetURL]) {
                                                                              [self noException:^{
                                                                                  resultBlock(asset);
                                                                              }];
                                                                              *stop = YES;
                                                                          }
                                                                      }];
                                                                  }
                                                                failureBlock:^(NSError *error) {
                                                                    [self noException:^{
                                                                        failureBlock(error);
                                                                    }];
                                                                }];
                            }
                        } failureBlock:^(NSError *error) {
                            [self noException:^{
                                failureBlock(error);
                            }];
                        }];
}

#pragma mark- download file
-(void)addFileDownloadTask:(SeafFile *)file {
    @synchronized (self.fileTasks) {
        if (![self.fileTasks containsObject:file]) {
            [self.fileTasks addObject:file];
            self.fileDownloadingCount += 1;
            [self tryDownLoadFile];
            Debug("Added file task %@: %ld", file.name, (unsigned long)self.fileTasks.count);
        }
    }
}

- (void)tryDownLoadFile {
    if (self.fileTasks.count == 0) return;
    for (SeafFile *file in self.fileTasks) {
        if (![self.fileQueuedTasks containsObject:file] && file.state == SEAF_DENTRY_INIT) {
            [self.fileQueuedTasks addObject:file];
        }
    }
    [self startNextTask];
}

-(void)finishFileDownload:(SeafFile<SeafDownloadDelegate> *)file result:(BOOL)result {
    if ([self.fileQueuedTasks containsObject:file]) {
        if (self.trySyncBlock) {
            self.trySyncBlock();
        }
        Debug("finish file task %@: %ld", file.name, (unsigned long)self.fileDownloadingCount);
        if (result) {
            [self.fileQueuedTasks removeObject:file];
            if (self.fileDownloadingCount > 0) {
                self.fileDownloadingCount -= 1;
            }
        }
        if (self.activeFileDownloadingCount > 0) {
            self.activeFileDownloadingCount -= 1;
        }
        [self startNextTask];
        
    }
}

- (void)startNextTask {
    if (self.trySyncBlock) {
        self.trySyncBlock();
    }
    if ([self isActiveDownloadingFileCountBelowMaximumLimit]) {
        SeafFile *file = [self dequeueTask];
        if (file) {
            self.activeFileDownloadingCount += 1;
            [file download];
            Debug("downloading file task %@: %ld", file.name, (unsigned long)self.fileQueuedTasks.count);
        }
    }
}

- (SeafFile *)dequeueTask{
    SeafFile *task = nil;
    task = [self.fileQueuedTasks firstObject];
    return task;
}

- (NSInteger)downloadingNum
{
    return self.fileDownloadingCount;
}

- (BOOL)isActiveDownloadingFileCountBelowMaximumLimit {
    return self.activeFileDownloadingCount < 6;
}

#pragma mark- download thumb
- (void)addThumbDownloadTask:(SeafThumb *)thumb {
    @synchronized (self.thumbTasks) {
        if (![self.thumbTasks containsObject:thumb]) {
            [self.thumbTasks addObject:thumb];
            Debug("Added thumb task %@: %ld", thumb.name, (unsigned long)self.thumbTasks.count);
            [self tryDownloadThumb];
        }
    }
}

- (void)tryDownloadThumb {
    if (self.thumbTasks.count == 0) return;
    for (SeafThumb *thumb in self.thumbTasks) {
        if (![self.thumbQueuedTasks containsObject:thumb]) {
            [self.thumbQueuedTasks addObject:thumb];
        }
    }
    [self startNextThumbTask];
}

- (void)startNextThumbTask {
    if ([self isActiveDownloadingThumbCountBelowMaximumLimit]) {
        SeafThumb *thumb = [self dequeueThumb];
        if (thumb) {
            self.activeThumbDownloadingCount += 1;
            [thumb download];
        }
    }
}

- (SeafThumb *)dequeueThumb{
    SeafThumb *task = nil;
    task = [self.thumbQueuedTasks firstObject];
    return task;
}

-(void)finishThumbDownload:(SeafThumb<SeafDownloadDelegate> *)thumb result:(BOOL)result {
    if ([self.thumbQueuedTasks containsObject:thumb]) {
        if (result) {
            [self.thumbQueuedTasks removeObject:thumb];
        }
        self.activeThumbDownloadingCount -= 1;
        [self startNextThumbTask];
    }
}

- (BOOL)isActiveDownloadingThumbCountBelowMaximumLimit {
    return self.activeThumbDownloadingCount < 6;
}


- (void)addAvatarDownloadTask:(SeafUserAvatar *)avatar {
    if (![self.avatarTasks containsObject:avatar]) {
        [self.avatarTasks addObject:avatar];
        [avatar download];
    }
    
}

-(void)finishAvatarDownloadTask:(SeafAvatar *)avatar result:(BOOL)result
{
    if (result) {
        [self.avatarTasks removeObject:avatar];
    } else {
        [avatar download];
    }
}

- (void)removeBackgroundDownloadTask:(id<SeafDownloadDelegate>)task
{
    if ([task isKindOfClass:[SeafFile class]]) {
        [self.fileTasks removeObject:task];
        [self.fileQueuedTasks removeObject:task];
    } else if ([task isKindOfClass:[SeafThumb class]]) {
        [self.fileTasks removeObject:task];
        [self.fileQueuedTasks removeObject:task];
    } else if ([task isKindOfClass:[SeafAvatar class]]) {
        [self.avatarTasks removeObject:task];
    }
}

- (void)cacheCleared:(NSNotification*)notification{
    [self.fileTasks removeAllObjects];
    [self.fileQueuedTasks removeAllObjects];
    [self.thumbTasks removeAllObjects];
    [self.thumbQueuedTasks removeAllObjects];
    [self.avatarTasks removeAllObjects];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
