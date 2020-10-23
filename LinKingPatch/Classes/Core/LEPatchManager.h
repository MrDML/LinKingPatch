//
//  LEPatchManager.h
//  patch
//
//  Created by leon on 2020/10/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LEPatchManager : NSObject
@property (nonatomic,copy) void(^downloadProgress)(float progress);
+ (instancetype)shared;
- (void)downloadPatchFile:(void(^)(NSError*error))complete;
/// 开始更新资源
- (void)startUpdateResources;
- (void)startUpdateResources:(void(^)(float progress))progress downloadComplete:(void(^)(NSError *error))complete;
/// 生成content.json 文件
/// @param serverURL 服务器地址
/// @param version 版本号
/// @param savePath 保存路径
- (void)generateContentJsonWithServer:(NSString *)serverURL version:(NSString *)version savePath:(NSString *)savePath;
/// 移动资源到沙盒
- (void)compressionAndMoveDir;

- (void)compressionAndMoveDir:(void(^)(void))unZipComplete;

@end

NS_ASSUME_NONNULL_END
