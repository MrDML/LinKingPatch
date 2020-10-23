//
//  LKViewController.m
//  LinKingPatch
//
//  Created by dml1630@163.com on 10/23/2020.
//  Copyright (c) 2020 dml1630@163.com. All rights reserved.
//

#import "LKViewController.h"
#import <LinKingPatch/LinKingPatch.h>
#define DOWNLOADPATCH @"https://commcdn.chiji-h5.com/flycar/web/content.json"
@interface LKViewController ()

@end

@implementation LKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[LEPatchManager shared] compressionAndMoveDir:^{
        
        NSLog(@"----->%@",[[LEPatchManager shared] getCacheRootFilePath]);
        
        [[LEPatchManager shared] downloadPatchFileWithURL:DOWNLOADPATCH complete:^(NSError * _Nonnull error) {
            if (error == nil) {
                [[LEPatchManager shared] startUpdateResources:^(float progress) {
                    NSLog(@"下载进度---->%lf",progress);
                } downloadComplete:^(NSError * _Nonnull error) {
                    NSLog(@"====更新完成====");
                     
                    [self finishHandler];
                   
                }];
            }

        }];
    }];

}

- (void)finishHandler{
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"更新完成，请退出游戏，重新进入。" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        exit(0);
    }];
    
    [alertVC addAction:action];
    
    UIViewController *rootViewController = [UIApplication sharedApplication].windows.lastObject.rootViewController;
    
    [rootViewController presentViewController:alertVC animated:YES completion:nil];
}



- (void)generateContentJson{
        [[LEPatchManager shared] generateContentJsonWithServer:@"https://commcdn.chiji-h5.com/flycar" version:@"0.0.2" savePath:@"/Users/duan/Desktop/Work/down/patch/web"];
}

@end

