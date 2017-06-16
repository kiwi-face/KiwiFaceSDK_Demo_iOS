//
//  ViewController.m
//  KiwifaceRecordingDemo
//
//  Created by zhaoyichao on 2017/2/4.
//  Copyright © 2017年 kiwiFaceSDK. All rights reserved.
//

#import "ViewController.h"
#import "KWVideoShowViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (IBAction)openVideoBtnOnTap:(id)sender
{
    KWVideoShowViewController *kwVideoVC = [KWVideoShowViewController new];
    [self presentViewController:kwVideoVC animated:YES completion:^{
        
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
