//
//  KiwiRootViewController.m
//  KiwiFaceKitDemo
//
//  Created by zhaoyichao on 2017/2/3.
//  Copyright © 2017年 0dayZh. All rights reserved.
//

#import "KWRootViewController.h"
#import "KWVideoShowViewController.h"

@interface KWRootViewController ()

@end

@implementation KWRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    UIImageView *imageView = [[UIImageView alloc] init];
    CGFloat width = ScreenWidth_KW / 3;
    imageView.frame = CGRectMake((ScreenWidth_KW - width) / 2, ScreenHeight_KW - 2 * width - 50, width, width / 1.176);
    imageView.image = [UIImage imageNamed:@"logo"];

    UIButton *btnTest = [[UIButton alloc] init];
    btnTest.frame =
            CGRectMake((ScreenWidth_KW - ScreenWidth_KW / 3) / 2, ScreenHeight_KW - ScreenWidth_KW / 3 - 50, ScreenWidth_KW / 3, ScreenWidth_KW / 3);
    [btnTest setImage:[UIImage imageNamed:@"enterVideo_sys"] forState:UIControlStateNormal];

    [btnTest addTarget:self action:@selector(testOnTap:) forControlEvents:UIControlEventTouchUpInside];

    UIImageView *backImg = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth_KW, ScreenHeight_KW)];
    [backImg setImage:[UIImage imageNamed:@"entranceBackground_sys"]];

    backImg.userInteractionEnabled = YES;

    [backImg addSubview:btnTest];
    [backImg addSubview:imageView];

    [self.view addSubview:backImg];

    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)testOnTap:(UIButton *)sender {


    KWVideoShowViewController *plView = [[KWVideoShowViewController alloc] init];
    plView.modelPath = nil;

    [self presentViewController:plView animated:YES completion:nil];
}


@end
