//
//  LEPatchManager.m
//  patch
//
//  Created by leon on 2020/10/19.
//

#import "LEPatchManager.h"
#import <CommonCrypto/CommonDigest.h>
#import <SSZipArchive/SSZipArchive.h>
#import "WHC_HttpManager.h"
#import "UIButton+WHC_HttpButton.h"
#import "UIImageView+WHC_HttpImageView.h"
#import "WHC_DownloadObject.h"
//首先声明一个宏定义
#define FileHashDefaultChunkSizeForReadingData 1024*8
CFStringRef FileMD5HashCreateWithPath(CFStringRef filePath,
                                       size_t chunkSizeForReadingData) {
    
    // Declare needed variables
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    
    // Get the file URL
    CFURLRef fileURL =
    CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                  (CFStringRef)filePath,
                                  kCFURLPOSIXPathStyle,
                                  (Boolean)false);
    if (!fileURL) goto done;
    
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    if (!readStream) goto done;
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    if (!didSucceed) goto done;
    
    // Initialize the hash object
    CC_MD5_CTX hashObject;
    CC_MD5_Init(&hashObject);
    
    // Make sure chunkSizeForReadingData is valid
    if (!chunkSizeForReadingData) {
        chunkSizeForReadingData = FileHashDefaultChunkSizeForReadingData;
    }
    
    // Feed the data to the hash object
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,
                                                  (UInt8 *)buffer,
                                                  (CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_MD5_Update(&hashObject,(const void *)buffer,(CC_LONG)readBytesCount);
    }
    
    // Check if the read operation succeeded
    didSucceed = !hasMoreData;
    
    // Compute the hash digest
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &hashObject);
    
    // Abort if the read operation failed
    if (!didSucceed) goto done;
    
    // Compute the string result
    char hash[2 * sizeof(digest) + 1];
    for (size_t i = 0; i < sizeof(digest); ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    result = CFStringCreateWithCString(kCFAllocatorDefault,
                                       (const char *)hash,
                                       kCFStringEncodingUTF8);
    
done:
    
    if (readStream) {
        CFReadStreamClose(readStream);
        CFRelease(readStream);
    }
    if (fileURL) {
        CFRelease(fileURL);
    }
    return result;
}



static LEPatchManager *_instance = nil;


#define LOCALROOTNAME @"web"
#define SERVERROOTNAME @"web"
#define JSONNAME @"content.json"
#define CACHEROOT @"com.linKing.www"
@interface LEPatchManager ()<SSZipArchiveDelegate>{
    dispatch_source_t timer;
}



@property (nonatomic, strong) NSMutableArray<NSDictionary *>*downloads;

@property (nonatomic, strong)  NSArray *downloadResources;

@property (nonatomic,copy) void(^downloadFileProgress)(float progress);

@property (nonatomic,copy) void(^downloadComplete)(NSError *error);

@property (nonatomic, copy) void(^unZipComplete)(void);

@end


@implementation LEPatchManager


+ (instancetype)shared{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[LEPatchManager alloc] init];
       
       
    });
    return _instance;
}


- (void)startTime{
    
    timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        if (self.downloadProgress) {
            if ([self progress] >= 1.0) {
                dispatch_cancel(self->timer);
            }
            self.downloadProgress([self progress]);
        }
    });
    dispatch_resume(timer);
}

- (void)downloadPatchFile:(void(^)(NSError*error))complete{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://commcdn.chiji-h5.com/flycar/web/content.json"]];
    // 文件将要移动到的指定目录
    [[[NSURLSession sharedSession] downloadTaskWithRequest:request completionHandler:^(NSURL * _Nullable location, NSURLResponse * _Nullable response, NSError * _Nullable error) {

        NSString *newFilePath = [[self getCacheRootFilePath:CACHEROOT] stringByAppendingPathComponent:response.suggestedFilename];
        
        // 如果存在先移除
        if ([[NSFileManager defaultManager] fileExistsAtPath:newFilePath]) {
            [[NSFileManager defaultManager] removeItemAtPath:newFilePath error:nil];
        }
        
        if (location.path != nil) {
            [[NSFileManager defaultManager] moveItemAtPath:location.path toPath:newFilePath error:nil];

        }
        if(complete){
            complete(error);
        }
        
    }] resume];

}

/// 生成content.json 文件
/// @param serverURL 服务器地址
/// @param version 版本号
/// @param savePath 保存路径
- (void)generateContentJsonWithServer:(NSString *)serverURL version:(NSString *)version savePath:(NSString *)savePath{
    
   NSDictionary * dict =  [[LEPatchManager shared] allFiles:serverURL version:version];
   
   NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
   
   NSString *json = [[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"\r\n" withString:@""];
   
    NSString *path = [savePath stringByAppendingPathComponent:JSONNAME];
    // [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"content.json"];
   
   NSError *error = nil;
   
   if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil]) {
       
       [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
   }
   
   [json writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error];
 
}


// ============================= 补丁相关方法-START =============================


/// 获取本地content.json路径
- (NSString *)getLocalPatchJsonPath{
    NSString *lingkingPath = [self getCacheRootFilePath:CACHEROOT];
    NSString *contentPath =[lingkingPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@",LOCALROOTNAME,JSONNAME]];
    return contentPath;
}
/// 获取本地内容对象
- (NSDictionary *)getLocalPatchObject{
    NSString *path = [self getLocalPatchJsonPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSMutableDictionary *res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return res;
}

/// 获取本地所有文件集合
- (NSArray<NSDictionary *>*)getLocalAllFiles{
    NSDictionary *res = [self getLocalPatchObject];
    NSArray<NSDictionary *>*files = res[@"resources"];
    return  files;
}


/// 获取本地补丁文件版本
- (NSString *)getLocalPatchFileVersion{
    NSDictionary *res = [self getLocalPatchObject];
    NSString *version = res[@"version"];
    return  version;
}


/// 获取服务路径
- (NSString *)getServerPath{
    NSDictionary *res = [self getLocalPatchObject];
    NSString *serverPath = res[@"serverPath"];
    return  serverPath;
}


/// 获取服务路径
- (NSString *)getRootPath{
    NSDictionary *res = [self getLocalPatchObject];
    NSString *serverPath = res[@"rootPath"];
    return  serverPath;
}


/// 获取远程content.json路径
- (NSString *)getServerPatchJsonPath{
    NSString *lingkingPath = [self getCacheRootFilePath:CACHEROOT];
    NSString *contentPath =[lingkingPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@",JSONNAME]];
    return contentPath;
}


/// 获取远程内容对象
- (NSDictionary *)getServerPatchObject{
    NSString *path = [self getServerPatchJsonPath];
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSMutableDictionary *res = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
    return res;
}


/// 获取远程补丁文件版本
- (NSString *)getServerPatchFileVersion{
    NSDictionary *res = [self getServerPatchObject];
    NSString *version = res[@"version"];
    return  version;
}

/// 获取服务所有文件集合
- (NSArray<NSDictionary *>*)getServerAllFiles{
    NSDictionary *res = [self getServerPatchObject];
    NSArray<NSDictionary *>*files = res[@"resources"];
    return  files;
}

/// 是否需要更新
- (BOOL)isUpdateVersion{
    
    NSString *localVersion = [self getLocalPatchFileVersion];
    NSString *serverVersion = [self getServerPatchFileVersion];
    
    NSArray *localArray = [localVersion componentsSeparatedByString:@"."];
    NSArray *serverArray = [serverVersion componentsSeparatedByString:@"."];
    
    for (int i = 0; i < serverArray.count; i++) {
        if ([serverArray[i] integerValue] > [localArray[i] integerValue]) {
            // 更新
            return YES;
            break;
        }
    }
    return  false;
}



/// 获取下载资源如果没有资源下载将返回空集合，如果有资源下载将返回需要下载的文件集合
- (NSArray <NSDictionary *>*)getDoloadResources{
    
    if(![self isUpdateVersion]){
        return nil;
    }

    NSArray *files_server = [self getServerAllFiles];
    NSArray *files_local = [self getLocalAllFiles];
    
    NSMutableArray <NSDictionary *>*downloads = [NSMutableArray array];
    
    // 如果服务端的总资源文件大于本地的那么所有文件重新加载
    if (files_server.count > files_local.count) {
        return  files_server;
    }

    // 对比文件
    for (int i = 0; i < files_server.count; i++) {
        
        NSDictionary *fileInfo_server = files_server[i];
        NSDictionary *fileInfo_local = files_local[i];
        
        NSString *sign_server = fileInfo_server[@"sign"];
        NSString *sign_local = fileInfo_local[@"sign"];
        
        if (![sign_server isEqualToString:sign_local]) {
            // 添加到需要下载的资源中
            [downloads addObject:fileInfo_server];
        }

    }

    return  downloads;

}
                  
                  
- (void)compressionAndMoveDir:(void(^)(void))unZipComplete{
    
    self.unZipComplete = unZipComplete;
    
    NSString *rootDir = [[NSBundle mainBundle] pathForResource:LOCALROOTNAME ofType:nil];
    // 文件路径
    NSString *lingkingPath = [self getCacheRootFilePath:CACHEROOT];
     // 初始化压缩
    NSString *webFilePAth =[lingkingPath stringByAppendingPathComponent:LOCALROOTNAME];
    if (![[NSFileManager defaultManager] fileExistsAtPath:webFilePAth]) { // 如果不存在web路径在进行压缩
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
           [self ssZipArchiveWithFolder:rootDir withFilePath:lingkingPath];
           [self uSSZipArchiveFilePath:lingkingPath];
            
        });
    
    }

}
                  
                  
/// 压缩移动目录
- (void)compressionAndMoveDir{
    NSString *rootDir = [[NSBundle mainBundle] pathForResource:LOCALROOTNAME ofType:nil];
    // 文件路径
    NSString *lingkingPath = [self getCacheRootFilePath:CACHEROOT];
     // 初始化压缩
    NSString *webFilePAth =[lingkingPath stringByAppendingPathComponent:LOCALROOTNAME];
    if (![[NSFileManager defaultManager] fileExistsAtPath:webFilePAth]) { // 如果不存在web路径在进行压缩
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
           [self ssZipArchiveWithFolder:rootDir withFilePath:lingkingPath];
           [self uSSZipArchiveFilePath:lingkingPath];
            
        });
    
    }
}

/// 获取根Cache目录文件夹
/// @param path path description
- (NSString *)getCacheRootFilePath:(NSString *)path{
    NSString *documentPath  =  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    NSString *filePath =  [documentPath stringByAppendingPathComponent:path];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) { // 存在就返回
        return filePath;
    }else{ // 不存在就创建
      return [self createDirectory:path];
    }
}

/// 创建文件夹
/// @param dir <#dir description#>
- (NSString *)createDirectory:(NSString *)dir{
    
    NSString *documentPath  =  [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    // @"com.lingKing.www"
    NSString  *filePath = [documentPath stringByAppendingPathComponent:dir];
      
    NSFileManager *fileManager = [NSFileManager defaultManager];
      
      if (![fileManager fileExistsAtPath:filePath]) {
          
        [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:nil];
          
          return filePath;
          
      }
    return nil;
}

// ============================= 补丁相关方法-END =============================


// ============================= 下载资源-START =============================


- (void)startUpdateResources:(void(^)(float progress))progress downloadComplete:(void(^)(NSError *error))complete {
        
    self.downloadProgress = progress;
    self.downloadComplete  = complete;
       // 在开始下载前先判断是否存在相关下载的文件夹如果存在全部删除
       // 如果一次性更新完成说明，会自动将这些文件夹删除，如果没有被删除说明还有未下载成功的文件，先删除重新下载，之前下载成功的文件已经覆盖
       
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject resourcesDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject resourcesDirectory] error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject cachePlistDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cachePlistDirectory] error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject cacheDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cacheDirectory] error:nil];
    }
    

        //    //  获取需要下载的资源
        NSArray *downloadResources = [[LEPatchManager shared] getDoloadResources];

        self.downloadResources = downloadResources;
        for (NSDictionary *dict in downloadResources) {

            NSString *path = dict[@"path"];
            NSString *name = dict[@"name"];
            NSString *url = [NSString stringWithFormat:@"%@%@/%@",[LEPatchManager shared].getServerPath,[LEPatchManager shared].getRootPath,path];
            NSLog(@"url ==>%@",url);
            
            if (![self isDownloadSuccess:name]) {
                // 开始下载
                [self download:url fileName:name];
            }
        }
}


- (void)startUpdateResources{
        
       // 在开始下载前先判断是否存在相关下载的文件夹如果存在全部删除
       // 如果一次性更新完成说明，会自动将这些文件夹删除，如果没有被删除说明还有未下载成功的文件，先删除重新下载，之前下载成功的文件已经覆盖
       
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject resourcesDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject resourcesDirectory] error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject cachePlistDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cachePlistDirectory] error:nil];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:[WHC_DownloadObject cacheDirectory] isDirectory:nil]) {
        [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cacheDirectory] error:nil];
    }
    

        //    //  获取需要下载的资源
        NSArray *downloadResources = [[LEPatchManager shared] getDoloadResources];

        self.downloadResources = downloadResources;
        for (NSDictionary *dict in downloadResources) {

            NSString *path = dict[@"path"];
            NSString *name = dict[@"name"];
            NSString *url = [NSString stringWithFormat:@"%@%@/%@",[LEPatchManager shared].getServerPath,[LEPatchManager shared].getRootPath,path];
            NSLog(@"url ==>%@",url);
            
            if (![self isDownloadSuccess:name]) {
                // 开始下载
                [self download:url fileName:name];
            }
        }
}




- (BOOL)isDownloadSuccess:(NSString *)fileName{
    // 过滤已经下载成功
    NSArray *array = [NSMutableArray arrayWithArray:[WHC_DownloadObject readDiskAllCache]];
    NSMutableArray *fileNames = [NSMutableArray array];
    BOOL res = NO;
    for (WHC_DownloadObject * downloadObject in array) {
        
        if (downloadObject.downloadState == WHCDownloadCompleted) {
             NSArray *array = [downloadObject.fileName componentsSeparatedByString:@"."];
             NSString *suffix = array.lastObject;
             NSString *name = [downloadObject.fileName substringToIndex:downloadObject.fileName.length - (suffix.length + 1)];
            
            [fileNames addObject:name];

        }
    }
    
    if ([fileNames containsObject:fileName]) {
        res = YES;
    }
    
    return res;
}


- (CGFloat)progress{
    
    NSArray *totalDownload = self.downloadResources;
    NSArray *currentDownload = [NSMutableArray arrayWithArray:[WHC_DownloadObject readDiskAllCache]];
    
    CGFloat p = currentDownload.count * 1.0 / (totalDownload.count);
    
    NSLog(@"totalDownload = %@",totalDownload);
    NSLog(@"currentDownload = %@",currentDownload);
    NSLog(@"progress----->%lf",p);
    if (self.downloadProgress) {
        self.downloadProgress(p);
    }
    if(self.downloadFileProgress){
        self.downloadFileProgress(p);
    }
        
    return p;
}

- (void)download:(NSString *)downloadServer fileName:(NSString *)fileName{
    
    __weak typeof(self) weakSelf = self;
    WHC_DownloadOperation * downloadTask = nil;
    downloadTask = [[WHC_HttpManager shared] download:downloadServer savePath:[WHC_DownloadObject resourcesDirectory] saveFileName:fileName response:^(WHC_BaseOperation * _Nullable operation, NSError * _Nullable error, BOOL isOK) {
        if (isOK) {
            
            WHC_DownloadOperation * downloadOperation = (WHC_DownloadOperation*)operation;
            WHC_DownloadObject * downloadObject = [WHC_DownloadObject readDiskCache:downloadOperation.saveFileName];
            if (downloadObject == nil) {
                NSLog(@"已经添加到下载队列");
                downloadObject = [WHC_DownloadObject new];
            }
            downloadObject.fileName = downloadOperation.saveFileName;
            downloadObject.downloadPath = downloadOperation.strUrl;
            downloadObject.downloadState = WHCDownloading;
            downloadObject.currentDownloadLenght = downloadOperation.recvDataLenght;
            downloadObject.totalLenght = downloadOperation.fileTotalLenght;
            [downloadObject writeDiskCache];
        }else {
            
            [weakSelf errorHandle:(WHC_DownloadOperation *)operation error:error];
            
        }
        } process:^(WHC_BaseOperation * _Nullable operation, uint64_t recvLength, uint64_t totalLength, NSString * _Nullable speed) {
            WHC_DownloadOperation * downloadOperation = (WHC_DownloadOperation*)operation;
           // NSLog(@"index = %ld  recvLength = %llu totalLength = %llu speed = %@", (long)%ld  recvLength = %llu totalLength = %llu speed = %@", (long)downloadOperation.index,recvLength , totalLength , speed);

        } didFinished:^(WHC_BaseOperation * _Nullable operation, NSData * _Nullable data, NSError * _Nullable error, BOOL isSuccess) {
            if (isSuccess) {
                NSLog(@"=====下载成功=====");
                [weakSelf saveDownloadStateOperation:(WHC_DownloadOperation *)operation];

            }else {
                 [weakSelf errorHandle:(WHC_DownloadOperation *)operation error:error];
                if (error != nil &&
                    error.code == WHCCancelDownloadError) {
                    [weakSelf saveDownloadStateOperation:(WHC_DownloadOperation *)operation];
                }
            }
        }];
    
//    if (downloadTask.requestStatus == WHCHttpRequestNone) {
//        if (![[WHC_HttpManager shared] waitingDownload]) {
//            return;
//        }
//        WHC_DownloadObject * downloadObject = [WHC_DownloadObject readDiskCache:downloadTask.saveFileName];
//        if (downloadObject == nil) {
//            NSLog(@"==已经添加到下载队列==");
//            downloadObject = [WHC_DownloadObject new];
//            downloadObject.fileName = fileName;
//            downloadObject.downloadPath = downloadServer;
//            downloadObject.downloadState = WHCDownloadWaitting;
//            downloadObject.currentDownloadLenght = 0;
//            downloadObject.totalLenght = 0;
//            [downloadObject writeDiskCache];
//        }
//    }
}


- (void)saveDownloadStateOperation:(WHC_DownloadOperation *)operation {


    WHC_DownloadOperation * downloadOperation = (WHC_DownloadOperation*)operation;
    WHC_DownloadObject * downloadObject = [WHC_DownloadObject readDiskCache:downloadOperation.saveFileName];
    downloadObject.fileName = downloadOperation.saveFileName;
    downloadObject.downloadPath = downloadOperation.strUrl;
    downloadObject.downloadState = WHCDownloading;
    downloadObject.currentDownloadLenght = downloadOperation.recvDataLenght;
    downloadObject.totalLenght = downloadOperation.fileTotalLenght;
    [downloadObject writeDiskCache];
    
    [self moveNewResourcesToDir:downloadObject];
    
  
}

- (void)moveNewResourcesToDir:(WHC_DownloadObject *)downloadObject{
    float progress = 0;
    // 获取所有文件信息
    NSMutableArray *localFiles =  [NSMutableArray arrayWithArray:[self getLocalAllFiles]];
    // 获取项目根路径
    NSString *rootPath = [[self getCacheRootFilePath:CACHEROOT] stringByAppendingPathComponent:LOCALROOTNAME];
    NSString *path = nil;
    int index = -1;
        
    // 寻找下载的资源索引
    for (int i = 0; i < localFiles.count; i++) {
        NSDictionary *info = localFiles[i];
        NSString *suffix = info[@"suffix"];
        NSString *name = info[@"name"];
        NSString *fullName = [NSString stringWithFormat:@"%@.%@",name,suffix];
        
        if ([fullName isEqualToString:downloadObject.fileName]) {
            index = i;
            path = info[@"path"];
            break;
        }
    }
    // content.json 文件不进行覆盖,出该文件其他文件需要覆盖
    if (![downloadObject.fileName isEqualToString:JSONNAME]) {

        // 原路径
        NSString *originPath = [NSString stringWithFormat:@"%@%@",[WHC_DownloadObject resourcesDirectory],downloadObject.fileName];

        // 目标路径
        NSString *toPath = [rootPath stringByAppendingPathComponent:path];
        NSError *error = nil;
        
        // 将在下载好的文件移动到目标路径中
        if ([[NSFileManager defaultManager] fileExistsAtPath:toPath]) {
            [[NSFileManager defaultManager] removeItemAtPath:toPath error:nil];
        }
        
        [[NSFileManager defaultManager] copyItemAtPath:originPath toPath:toPath error:&error];
        if (error != nil) {
            NSLog(@"复制失败= %@",error.localizedDescription);
            return;
        }

        
   
    }else{
        NSLog(@"==content.json 文件不进行覆盖==");
    }
    
        if (index < 0 ) {
            return;
        }
        
        // 写入json部分
        // 从服务中获取的content.json 中获取最新的文件信息
        NSArray *serverFiles = [self getServerAllFiles];
        NSString *serverVersion = [self getServerPatchFileVersion];
        // 获取对应下标最新文件信息
        NSDictionary *newFileInfo = serverFiles[index];
        // 用最新的文件替换将本地集合中之前的文件信息
        [localFiles replaceObjectAtIndex:index withObject:newFileInfo];
        
        // 将文件信息重新写入json
        NSDictionary *patchDict = [self getLocalPatchObject];
        // 将资源重新写入
        [patchDict setValue:localFiles forKey:@"resources"];
        
         progress = [self progress];
        
        
        if (progress == 1.0) {
            [patchDict setValue:serverVersion forKey:@"version"];
            NSLog(@"下载完成");
        }

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:patchDict options:NSJSONWritingPrettyPrinted error:nil];
        
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        // 将最新的json重新写入沙盒
        [jsonString writeToFile:[rootPath stringByAppendingPathComponent:JSONNAME] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
 
        if (progress == 1.0) {
            // 取消定时
            
            if(self.downloadComplete){
                self.downloadComplete(nil);
            }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 删除下载目录
                [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject resourcesDirectory] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cachePlistDirectory] error:nil];
                [[NSFileManager defaultManager] removeItemAtPath:[WHC_DownloadObject cacheDirectory] error:nil];

                UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"更新完成，请退出游戏，重新进入。" preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    exit(0);
                }];
                
                [alertVC addAction:action];
                
                UIViewController *rootViewController = [UIApplication sharedApplication].windows.lastObject.rootViewController;
                
                [rootViewController presentViewController:alertVC animated:YES completion:nil];

            });

        }
    
}
    
                  

- (void)errorHandle:(WHC_DownloadOperation *)operation error:(NSError *)error {
    // 取消定时
    dispatch_cancel(timer);
    NSString * errInfo = error.userInfo[NSLocalizedDescriptionKey];
    if ([errInfo containsString:@"404"]) {
        NSLog(@"该文件不存在");
        WHC_DownloadObject * downloadObject = [WHC_DownloadObject readDiskCache:operation.saveFileName];
        if (downloadObject != nil) {
            [downloadObject removeFromDisk];
        }
    }else {
        if ([errInfo containsString:@"已经在下载中"]) {
            NSLog(@"已经在下载中");
        }else {
            NSLog(@"下载失败");
            WHC_DownloadObject * downloadObject = [WHC_DownloadObject readDiskCache:operation.saveFileName];
            if (downloadObject != nil) {
                [downloadObject removeFromDisk];
            }
        }
    }
    if(self.downloadComplete){
        self.downloadComplete(error);
    }

}

// ============================= 下载资源-END =============================


#pragma mark -- 压缩
- (BOOL)ssZipArchiveWithFolder:(NSString *)folderPath withFilePath:(NSString *)filePath {

      NSString*documentPath_FilePath = filePath;
      //zip压缩包保存路径 @"web.zip"
       NSString *path = [documentPath_FilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip",LOCALROOTNAME]];
     //创建不带密码zip压缩包
       BOOL isSuccess = [SSZipArchive createZipFileAtPath:path withContentsOfDirectory:folderPath ];

       NSLog(@"path--->%@",path);
       return isSuccess;
}


#pragma mark -- 解压缩
- (BOOL)uSSZipArchiveFilePath:(NSString *)filePath{

    NSString*documentPath_FilePath = filePath;
    // 解压目标路径
     NSString *destinationPath = [documentPath_FilePath stringByAppendingPathComponent:LOCALROOTNAME];
    // zip压缩包的路径
    NSString *path = [documentPath_FilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip",LOCALROOTNAME]];

     BOOL isSuccess =  [SSZipArchive unzipFileAtPath:path toDestination:destinationPath delegate:self];
    
    
     return isSuccess;

}
                  

- (void)zipArchiveWillUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo{
    

    
}
- (void)zipArchiveDidUnzipArchiveAtPath:(NSString *)path zipInfo:(unz_global_info)zipInfo unzippedPath:(NSString *)unzippedPath{
   
}
- (void)zipArchiveWillUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo{

}
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath fileInfo:(unz_file_info)fileInfo{
  
}
- (void)zipArchiveDidUnzipFileAtIndex:(NSInteger)fileIndex totalFiles:(NSInteger)totalFiles archivePath:(NSString *)archivePath unzippedFilePath:(NSString *)unzippedFilePath{
   
}

// 该方法一直灰内调用
- (void)zipArchiveProgressEvent:(unsigned long long)loaded total:(unsigned long long)total{
    if (loaded == total) {
        if (self.unZipComplete) {
            self.unZipComplete();
        }
    }

}


/// 递归目录下所有文件生成文件集合信息
/// @param serverURL serverURL description 服务器地址
/// @param version version description 版本号
- (NSDictionary *)allFiles:(NSString *)serverURL version:(NSString *)version{
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *rootDir = [[NSBundle mainBundle] pathForResource:LOCALROOTNAME ofType:nil];
    
    NSMutableArray *dirs = [NSMutableArray array];
    

    NSMutableArray *filesInfo = [NSMutableArray array];
    
    NSMutableDictionary *resDict = [NSMutableDictionary dictionary];
    
    [dirs addObject:rootDir];
    
       
    while ([dirs count]) {
        
        NSString *dir = [dirs firstObject];
        [dirs removeObjectAtIndex:0];
        
        // 加载目录下所有文件
       NSArray *fileNames =  [fileManager contentsOfDirectoryAtPath:dir error:nil];
        
        for (NSString *fileName in fileNames) {
            
            NSString * path = [dir stringByAppendingPathComponent:fileName];
            BOOL isDir = NO;
            if ([fileManager fileExistsAtPath:path isDirectory:&isDir]) {
                if (isDir) { //目录
                    [dirs addObject:path];
                }else{ // 文件
                    if ([fileName rangeOfString:@"."].location != NSNotFound){
                       NSArray *array = [fileName componentsSeparatedByString:@"."];
                        NSMutableDictionary *fileInfo = [NSMutableDictionary dictionary];
                        NSString *suffix = array.lastObject;
                        NSString *name = [fileName substringToIndex:fileName.length - (suffix.length + 1)];

                        [fileInfo setObject:name forKey:@"name"];
                        [fileInfo setObject:suffix forKey:@"suffix"];
                        
                        if ([path rangeOfString:[NSString stringWithFormat:@"%@/",LOCALROOTNAME]].location != NSNotFound) {
                            NSArray *filePaths =  [path componentsSeparatedByString:[NSString stringWithFormat:@"%@/",LOCALROOTNAME]];
//                            NSString *tmpPath  = [NSString stringWithFormat:@"%@%@",SERVERROOTNAME,filePaths.lastObject];
                            [fileInfo setObject:filePaths.lastObject forKey:@"path"];
                        }

                       NSString *sign = [self md5HashOfPath:path];
                        
                        [fileInfo setObject:sign forKey:@"sign"];
    
                        [filesInfo addObject:fileInfo];

                    }else{
                        NSLog(@"-->%@",path);
                    }
                }
            }
            
        }

    }
    
    [resDict setObject:SERVERROOTNAME forKey:@"rootPath"];
    [resDict setObject:filesInfo forKey:@"resources"];
    // @"https://commcdn.chiji-h5.com/flycar/v6/"
    [resDict setObject:serverURL forKey:@"serverPath"];
    [resDict setObject:version forKey:@"version"];
    return resDict;
}








#pragma mark -- MD5 文件内容

/// 第二种方式计算大文件MD5
- (NSString*)getBigfileMD5:(NSString*)path
{
    
    NSString *sign =  (__bridge_transfer NSString *)FileMD5HashCreateWithPath((__bridge CFStringRef)path, FileHashDefaultChunkSizeForReadingData);
    
   // NSLog(@"--->%@",sign);
    return sign;
}

- (NSString *)md5HashOfPath:(NSString *)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:path isDirectory:nil]) {
        
        NSData *data = [NSData dataWithContentsOfFile:path];
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);

        NSMutableString *output =  [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
        
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [output appendFormat:@"%02x",digest[i]];
        }
        //NSLog(@"output == %@",output);
        return  output;
        
    }else{
        return  @"";
    }
}


@end

