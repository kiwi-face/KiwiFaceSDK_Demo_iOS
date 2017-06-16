//
//  KWColorFilterManager.m
//  KiwiFaceKitDemo
//
//  Created by zhaoyichao on 2017/3/4.
//  Copyright © 2017年 0dayZh. All rights reserved.
//

#import "KWColorFilterManager.h"

@implementation KWColorFilterManager
{
    NSString *_colorFilterPath;
    dispatch_queue_t _ioQueue;
    
    NSMutableArray * _colorFilterNames;
    NSMutableArray *colorFilter_json;
}

+ (instancetype)sharedManager
{
    static id _colorfiltersManager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _colorfiltersManager = [KWColorFilterManager new];
    });
    
    return _colorfiltersManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _ioQueue = dispatch_queue_create("com.sobrr.colorfilters", DISPATCH_QUEUE_SERIAL);
        _colorFilterPath = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"filter"];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:_colorFilterPath isDirectory:NULL]) {
            NSLog(@"filter folder do not exist");
        }
    }
    return self;
}


/**
 Asynchronous mode reads all the colorfilter information from the file
 
 @param completion Read the callback after completion
 */
- (void)loadColorFiltersWithCompletion:(void(^)(NSMutableArray<KWColorFilter *> *colorFilters))completion
{
    dispatch_async(_ioQueue, ^{
        
        if ([self getColorsFilterFromJson]){
            
            completion(colorFilter_json);
            
        }
        
    });
}

- (BOOL)getColorsFilterFromJson
{
    BOOL isLoadSuccess = NO;
    
    // Read the config file in the resource directory
    NSString *configPath = [[NSBundle mainBundle].bundlePath stringByAppendingPathComponent:@"filters.json"];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:configPath isDirectory:NULL]) {
        NSLog(@"The general configuration file for the filter in the resource directory does not exist");
        return isLoadSuccess;
    }
    
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfFile:configPath];
    NSDictionary *oldDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || !oldDict) {
        NSLog(@"Resource directory under the general configuration file to read the filters failed:%@",error);
        return isLoadSuccess;
    }
    
    
    NSArray *dirArr = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_colorFilterPath error:NULL];
    
    NSArray *newArr = [oldDict objectForKey:@"filters"];
    
    colorFilter_json = [NSMutableArray arrayWithCapacity:newArr.count];
    
    //遍历json返回sticker数组
    for (NSDictionary *itemDict in newArr) {
        
        NSString *dir = [NSString stringWithFormat:@"%@/%@/",_colorFilterPath,[itemDict valueForKey:@"dir"]];
        
        if ([[itemDict valueForKey:@"category"]isEqual:@"inner"]) {
            GPUImageOutput<GPUImageInput, KWRenderProtocol> *shaderFilter;
            
            NSString *cs = [itemDict valueForKey:@"name"];

            
            Class shaderClass = NSClassFromString(cs);

            shaderFilter = [[shaderClass alloc] init];
            
            if (shaderFilter) {
                [colorFilter_json addObject:shaderFilter];
            }
            
        }else if ([[itemDict valueForKey:@"category"]isEqual:@"default"]){
            KWColorFilter *colorFilter = [[KWColorFilter alloc] initWithDir:dir];
            colorFilter.colorFilterDir = dir;
            colorFilter.colorFilterName = [itemDict valueForKey:@"name"];
            
            if (colorFilter) {
                [colorFilter_json addObject:colorFilter];
            }
        }
    }
    
    isLoadSuccess = YES;
    return isLoadSuccess;
}



- (NSString *)getColorFilterPath
{
    return _colorFilterPath;
}

@end
