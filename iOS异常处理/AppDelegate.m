//
//  AppDelegate.m
//  iOS异常处理
//
//  Created by KSY-iOS on 17/7/31.
//  Copyright © 2017年 dingxiankun. All rights reserved.
//

/*
 Crash分为两种，
 一种是由EXC_BAD_ACCESS引起的，原因是访问了不属于本进程的内存地址，有可能是访问已被释放的内存；
 另一种是未被捕获的Objective-C异常（NSException），导致程序向自身发送了SIGABRT信号而崩溃。
 其实对于未捕获的Objective-C异常，我们是有办法将它记录下来的，如果日志记录得当，能够解决绝大部分崩溃的问题。这里对于UI线程与后台线程分别说明
 */

#import "AppDelegate.h"
#import "UncaughtExceptionHandler.h"



@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    //signal(SIGPIPE, SIG_IGN);
    [UncaughtExceptionHandler InstallUncaughtExceptionHandler];//捕获内存访问错误,处理Signal
    
    return YES;
}





@end
