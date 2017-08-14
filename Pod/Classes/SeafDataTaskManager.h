//
//  SeafBackgroundTaskManager.h
//  Pods
//
//  Created by Wei W on 4/9/17.
//
//

#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>

#import "SeafPreView.h"
#import "SeafConnection.h"
#import "SeafUploadFile.h"
#import "SeafFile.h"
#import "SeafThumb.h"
#import "SeafAvatar.h"

typedef void(^SyncBlock)();
typedef void(^DownLoadFinshBlock)(SeafFile *file);
// Manager for background download/upload tasks, retry if failed.
@interface SeafDataTaskManager : NSObject

@property (readonly) ALAssetsLibrary *assetsLibrary;

@property (nonatomic, strong) NSMutableArray *fileTasks;
@property (nonatomic, strong) NSMutableArray *fileQueuedTasks;
@property (nonatomic, strong) NSMutableArray *fileDownloadingTasks;
@property (nonatomic, strong) NSMutableArray *thumbTasks;
@property (nonatomic, strong) NSMutableArray *thumbQueuedTasks;
@property (nonatomic, strong) NSMutableArray *avatarTasks;

@property (nonatomic, copy) SyncBlock trySyncBlock;
@property (nonatomic, copy) DownLoadFinshBlock finishBlock;

+ (SeafDataTaskManager *)sharedObject;

- (void)startTimer;

- (void)addBackgroundUploadTask:(SeafUploadFile *)file;
- (void)finishUpload:(SeafUploadFile *)file result:(BOOL)result;
- (void)removeBackgroundUploadTask:(SeafUploadFile *)file;
- (unsigned long)backgroundUploadingNum;

- (void)cancelAutoSyncTasks:(SeafConnection *)conn;
- (void)cancelAutoSyncVideoTasks:(SeafConnection *)conn;

- (void)assetForURL:(NSURL *)assetURL resultBlock:(ALAssetsLibraryAssetForURLResultBlock)resultBlock failureBlock:(ALAssetsLibraryAccessFailureBlock)failureBlock;

- (void)addFileDownloadTask:(SeafFile*)file;
- (void)finishFileDownload:(SeafFile<SeafDownloadDelegate>*)file result:(BOOL)result;
- (NSInteger)downloadingNum;

- (void)addThumbDownloadTask:(SeafThumb*)thumb;
- (void)finishThumbDownload:(SeafThumb<SeafDownloadDelegate> *)thumb result:(BOOL)result;

- (void)removeBackgroundDownloadTask:(id<SeafDownloadDelegate>)task;

- (void)addAvatarDownloadTask:(SeafAvatar*)avatar;
- (void)finishAvatarDownloadTask:(SeafAvatar*)avatar result:(BOOL)result;

@end
