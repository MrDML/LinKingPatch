//
//  LKViewController.m
//  LinKingPatch
//
//  Created by dml1630@163.com on 10/23/2020.
//  Copyright (c) 2020 dml1630@163.com. All rights reserved.
//

#import "LKViewController.h"
#import <LinKingPatch/LinKingPatch.h>

@interface LKViewController ()

@end

@implementation LKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"======>%@",NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask, YES));
//    [self generateContentJson];
    // 压缩移动文件
    
    [[LEPatchManager shared] compressionAndMoveDir:^{
        
        
        [[LEPatchManager shared] downloadPatchFile:^(NSError * _Nonnull error) {
            if (error == nil) {
                [[LEPatchManager shared] startUpdateResources:^(float progress) {
                    NSLog(@"下载进度---->%lf",progress);
                } downloadComplete:^(NSError * _Nonnull error) {
                    NSLog(@"====更新完成====");
                }];
            }
        }];
    }];

}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void)compressionAndMoveDir{
    
    [[LEPatchManager shared] compressionAndMoveDir];
}


- (void)generateContentJson{
        [[LEPatchManager shared] generateContentJsonWithServer:@"https://commcdn.chiji-h5.com/flycar" version:@"0.0.2" savePath:@"/Users/duan/Desktop/Work/down/patch/web"];
}

@end
