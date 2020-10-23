//
//  LEPatchManager.h
//  patch
//
//  Created by leon on 2020/10/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LEPatchManager : NSObject

/// 下载进度回调
@property (nonatomic,copy) void(^downloadProgress)(float progress);
/// 获取实例
+ (instancetype)shared;

/// 下载服务端补丁文件
/// @param sourceURL 远程地址
/// @param complete 下载回调
- (void)downloadPatchFileWithURL:(NSString *)sourceURL complete:(void(^)(NSError*error))complete;

/// 开始热更新
/// @param progress 更新进度
/// @param complete 更新是否完成
- (void)startUpdateResources:(void(^)(float progress))progress downloadComplete:(void(^)(NSError *error))complete;

/// 递归目录生成目下所有文件信息到补丁文件(content.json)
/// @param serverURL 远程服务根路径
/// @param version 版本号 例如 0.0.1 每次热更新需要版本号新增1
/// @param savePath 生成conten.json 保存的路径
- (void)generateContentJsonWithServer:(NSString *)serverURL version:(NSString *)version savePath:(NSString *)savePath;

/// 将项目中的资源文件压缩移动到沙盒
/// @param unZipComplete 完成回调
- (void)compressionAndMoveDir:(void(^)(void))unZipComplete;

/// 获取缓存目录的根目录
- (NSString *)getCacheRootFilePath;

@end

NS_ASSUME_NONNULL_END
