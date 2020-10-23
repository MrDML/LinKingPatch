//
//  WHC_DownloadObject.m
//  WHC_FileDownloadDemo
//
//  Created by 吴海超 on 15/11/27.
//  Copyright © 2015年 吴海超. All rights reserved.
//

#import "WHC_DownloadObject.h"
#import <CommonCrypto/CommonDigest.h>
const static double k1MB = 1024 * 1024;

@implementation WHC_DownloadObject

- (instancetype)init {
    self = [super init];
    if (self) {
        _downloadSpeed = @"0KB/s";
        _downloadState = WHCNone;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:_etag forKey:@"etag"];
    [aCoder encodeObject:_fileName forKey:@"fileName"];
    [aCoder encodeObject:_downloadPath forKey:@"downloadPath"];
    [aCoder encodeInt64:_totalLenght forKey:@"totalLenght"];
    [aCoder encodeInt64:_currentDownloadLenght forKey:@"currentDownloadLenght"];
}
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        _etag = [aDecoder decodeObjectForKey:@"fileName"];
        _downloadSpeed = @"0KB/s";
        _fileName = [aDecoder decodeObjectForKey:@"fileName"];
        _downloadPath = [aDecoder decodeObjectForKey:@"downloadPath"];
        _currentDownloadLenght = [aDecoder decodeInt64ForKey:@"currentDownloadLenght"];
        _totalLenght = [aDecoder decodeInt64ForKey:@"totalLenght"];
        _downloadState = _totalLenght != 0 ? (self.currentDownloadLenght == self.totalLenght ? WHCDownloadCompleted : WHCDownloadCanceled) : WHCNone;
    }
    return self;
}

+ (NSString *)cacheDirectory {
    return [NSString stringWithFormat:@"%@/Library/Caches/LEDownloadObjectCache/",NSHomeDirectory()];
}

+ (NSString *)cachePlistDirectory {
    return [NSString stringWithFormat:@"%@/Library/Caches/LECachePlistDirectory/",NSHomeDirectory()];
}

+ (NSString *)cachePlistPath {
    return [NSString stringWithFormat:@"%@LEDownloadCache.plist",[WHC_DownloadObject cachePlistDirectory]];
}

+ (NSString *)resourcesDirectory {
    return [NSString stringWithFormat:@"%@/Library/Caches/LEUpdateResources/",NSHomeDirectory()];
}

+ (WHC_DownloadObject *)readDiskCache:(NSString *)downloadPath {
    
//    NSLog(@"downloadPath---->%@",downloadPath);
    
    WHC_DownloadObject *object = [NSKeyedUnarchiver unarchiveObjectWithFile:[WHC_DownloadObject getCachedFileName:downloadPath]];
    
//    NSLog(@"object = %@",object);
    return object;
}

+ (BOOL)existLocalSavePath:(NSString *)downloadPath {
    NSFileManager * fm = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    return [fm fileExistsAtPath:[WHC_DownloadObject getCachedFileName:downloadPath] isDirectory:&isDirectory];
}

+ (NSArray *)readDiskAllCache {
    NSMutableArray * downloadObjectArr = [NSMutableArray array];
    NSMutableDictionary * cacheDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[WHC_DownloadObject cachePlistPath]];
    if (cacheDictionary != nil) {
        NSArray * allKeys = [cacheDictionary allKeys];
        for (NSString * path in allKeys) {
            [downloadObjectArr addObject:[WHC_DownloadObject readDiskCache:path]];
        }
    }
    return downloadObjectArr;
}

+ (NSArray *)readDownloadedFileCount{
    
      
   NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self resourcesDirectory] error:nil];
    
    return array;
}

+ (NSString *)getCachedFileName:(NSString *)name {
    NSMutableString * cachedFileName = [NSMutableString string];
    if (name != nil) {
        const char * cStr = name.UTF8String;
        unsigned char buffer[CC_MD5_DIGEST_LENGTH];
        memset(buffer, 0x00, CC_MD5_DIGEST_LENGTH);
        CC_MD5(cStr, (CC_LONG)(strlen(cStr)), buffer);
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [cachedFileName appendFormat:@"%02x",buffer[i]];
        }
        NSString *str1 = [NSString stringWithFormat:@"%@%@",[WHC_DownloadObject cacheDirectory],cachedFileName];
        return str1;
    }
    NSString *str2 = [NSString stringWithFormat:@"%@WHC",[WHC_DownloadObject cacheDirectory]];
    return str2;
}

- (float)downloadProcessValue {
    return (double)_currentDownloadLenght / ((double)_totalLenght == 0 ? 1 : _totalLenght);
}

- (NSString *)currentDownloadLenghtToString {
    return [NSString stringWithFormat:@"%.1fMB",(double)_currentDownloadLenght / k1MB];
}

- (NSString *)totalLenghtToString {
    return [NSString stringWithFormat:@"%.1fMB",(double)_totalLenght / k1MB];
}

- (NSString *)downloadProcessText {
    return [NSString stringWithFormat:@"%@/%@",self.totalLenghtToString , self.currentDownloadLenghtToString];
}

- (void)createCacheDirectory:(NSString *)path {
    NSFileManager * fm = [NSFileManager defaultManager];
    BOOL isDirectory = YES;
    if (![fm fileExistsAtPath:path isDirectory:&isDirectory]) {
        [fm createDirectoryAtPath:path
      withIntermediateDirectories:YES
                       attributes:@{NSFileProtectionKey:NSFileProtectionNone} error:nil];
    }
}

- (void)writeDiskCache {
    if (_downloadPath != nil) {
        [self createCacheDirectory:[WHC_DownloadObject cacheDirectory]];
//        NSLog(@"save---fileName = %@",_fileName);
        [NSKeyedArchiver archiveRootObject:self
                                    toFile:[WHC_DownloadObject getCachedFileName:_fileName]];//_downloadPath
        [self createCacheDirectory:[WHC_DownloadObject cachePlistDirectory]];
        NSMutableDictionary * cacheDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[WHC_DownloadObject cachePlistPath]];
        if (cacheDictionary == nil) {
            cacheDictionary = [NSMutableDictionary dictionary];
        }
        [cacheDictionary setObject:@"WHC" forKey:_fileName];//_downloadPath
        [cacheDictionary writeToFile:[WHC_DownloadObject cachePlistPath] atomically:YES];
    }
}

- (void)removeFromDisk {
    NSFileManager * fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:[WHC_DownloadObject getCachedFileName:_fileName]]) {//_downloadPath
        [fm removeItemAtPath:[WHC_DownloadObject getCachedFileName:_fileName] error:nil];//_downloadPath
        NSMutableDictionary * cacheDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:[WHC_DownloadObject cachePlistPath]];
        if (cacheDictionary != nil) {
            [cacheDictionary removeObjectForKey:_fileName];//_downloadPath
            [cacheDictionary writeToFile:[WHC_DownloadObject cachePlistPath] atomically:YES];
        }
        if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@%@",[WHC_DownloadObject resourcesDirectory],_fileName]]) {
            [fm removeItemAtPath:[NSString stringWithFormat:@"%@%@",[WHC_DownloadObject resourcesDirectory],_fileName] error:nil];
        }
    }
}

@end
