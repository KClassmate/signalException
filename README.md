# signalException
# iOS异常处理-signal信号
开发iOS应用
一种是由EXC_BAD_ACCESS引起的，原因是访问了不属于本进程的内存地址，有可能是访问已被释放的内存；
另一种是未被捕获的Objective-C异常（NSException），导致程序向自身发送了SIGABRT信号而崩溃。
其实对于未捕获的Objective-C异常，我们是有办法将它记录下来的，如果日志记录得当，能够解决绝大部分崩溃的问题。

首先，如果你没有处理这个信号，app 会直接 crash!!!
1.在全局范围内忽略这个信号，这个方法是全局通用的，所有的 SIGPIPE 信号都将被忽略

```
signal(SIGPIPE, SIG_IGN);
```
2.socket忽略这个信号

```
int value = 1;
setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &value, sizeof(value));
```
以上都是忽略signal信号，先面说说怎么收集signal信号
3.Crash收集
首先定义一个UncaughtExceptionHandler类，用来捕获处理所有的崩溃信息
```
当应用发生错误而产生上述Signal后，就将会进入我们自定义的回调函数MySignalHandler。为了得到崩溃时的现场信息
+ (void) InstallUncaughtExceptionHandler
{
    NSSetUncaughtExceptionHandler(&UncaughtExceptionHandlers); //系统异常捕获（越界）
    //信号量截断
    signal(SIGABRT, MySignalHandler);
    signal(SIGILL, MySignalHandler);
    signal(SIGSEGV, MySignalHandler);
    signal(SIGFPE, MySignalHandler);
    signal(SIGBUS, MySignalHandler);
    signal(SIGPIPE, MySignalHandler);
}
```

```
/Signal处理方法
void MySignalHandler(int signal)
{
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);//自动增加一个32位的值
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:@"SigCrash" forKey:UncaughtExceptionHandlerFileKey];
    
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:) withObject:
     [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason: [NSString stringWithFormat:NSLocalizedString(@"Signal %d was raised.\n"
                                                                                                                                     @"%@", nil),
                                                                                         signal, getAppInfo()] userInfo:userInfo]
     waitUntilDone:YES];
    
}
```

```
//NSSetUncaughtExceptionHandler捕获异常的调用方法
//利用 NSSetUncaughtExceptionHandler，当程序异常退出的时候，可以先进行处理，然后做一些自定义的动作
void UncaughtExceptionHandlers(NSException *exception) {
    
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum)
    {
        return;
    }
    
    NSArray *callStack = [UncaughtExceptionHandler backtrace];
    NSMutableDictionary *userInfo =
    [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [userInfo setObject:@"OCCrash" forKey:UncaughtExceptionHandlerFileKey];
    
    
    [[[UncaughtExceptionHandler alloc] init]
     performSelectorOnMainThread:@selector(handleException:)
     withObject:
     [NSException
      exceptionWithName:[exception name]
      reason:[exception reason]
      userInfo:userInfo]
     waitUntilDone:YES];
    
}
```

```
//异常处理方法
- (void)handleException:(NSException *)exception
{
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"程序出现问题啦" message:@"崩溃信息" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
    [alertView show];
    alertView = nil;
    
    //当接收到异常处理消息时，让程序开始runloop，防止程序死亡
    while (!dismissed) {
        for (NSString *mode in (__bridge NSArray *)allModes)
        {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    //当点击弹出视图的Cancel按钮哦,isDimissed ＝ YES,上边的循环跳出
    CFRelease(allModes);

    
    NSDictionary *userInfo=[exception userInfo];
    [self saveCreash:exception file:[userInfo objectForKey:UncaughtExceptionHandlerFileKey]];
    
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName])
    {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    }
    else
    {
        [exception raise];
    }
}
```

```
- (void)saveCreash:(NSException *)exception file:(NSString *)file
{
    NSArray *stackArray = [exception callStackSymbols];// 异常的堆栈信息
    NSString *reason = [exception reason];// 出现异常的原因
    NSString *name = [exception name];// 异常名称
    
    //或者直接用代码，输入这个崩溃信息，以便在console中进一步分析错误原因
    NSLog(@"CRASH: %@", exception);
    NSLog(@"Stack Trace: %@", [exception callStackSymbols]);
    
    
    NSString * _libPath  = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:file];
    
    //    NSString *_libPath=[NSHomeDirectory() stringByAppendingPathComponent:file];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:_libPath]){
        [[NSFileManager defaultManager] createDirectoryAtPath:_libPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSDate* dat = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval a=[dat timeIntervalSince1970];
    NSString *timeString = [NSString stringWithFormat:@"%f", a];
    
    NSString * savePath = [_libPath stringByAppendingFormat:@"/error%@.log",timeString];
    
    NSString *exceptionInfo = [NSString stringWithFormat:@"Exception reason：%@\nException name：%@\nException stack：%@",name, reason, stackArray];
    
    BOOL sucess = [exceptionInfo writeToFile:savePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSLog(@"保存崩溃日志 sucess:%d,%@",sucess,savePath);
}
```


