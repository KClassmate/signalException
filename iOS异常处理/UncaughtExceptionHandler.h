//
//  UncaughtExceptionHandler.h
//  iOS异常处理
//
//  Created by KSY-iOS on 17/7/31.
//  Copyright © 2017年 dingxiankun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UncaughtExceptionHandler : NSObject
{
    BOOL dismissed;
}

+ (void)InstallUncaughtExceptionHandler;

@end
