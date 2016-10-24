//
//  UncaughtExceptionHandler.m
//  崩溃日志捕获
//
//  Created by MrWu on 2016/10/24.
//  Copyright © 2016年 TTYL. All rights reserved.
//

#import "UncaughtExceptionHandler.h"
#import <libkern/OSAtomic.h>
#import <stdatomic.h>
#import <execinfo.h>
#import <UIKit/UIKit.h>

NSString *const UncaughtExcepitonHandleSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString *const UncaughtExcepitonHandleSignalExceptionKey = @"UncaughtExceptionHandlerSignalExceptionKey";
NSString *const UncaughtExcepitonHandleSignalAddressKey = @"uncaughtExcepitonHandleSignalAddressKey";

volatile int32_t UncaughtExcepitonCount = 0;
const int32_t UncaughtExceptionMaximum = 10;

const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

@implementation UncaughtExceptionHandler

+ (NSArray *)backTrace {
    void *callstack[128];
    
    int frames = backtrace(callstack, 128);
    //该函数用于获取当前线程的调用堆栈,获取的信息将会被存放在buffer中,它是一个指针列表。参数 size 用来指定buffer中可以保存多少个void* 元素。函数返回值是实际获取的指针个数,最大不超过size大小
    
    //在buffer中的指针实际是从堆栈中获取的返回地址,每一个堆栈框架有一个返回地址
    
    //注意:某些编译器的优化选项对获取正确的调用堆栈有干扰,另外内联函数没有堆栈框架;删除框架指针也会导致无法正确解析堆栈内容
    
    char **strs = backtrace_symbols(callstack, frames);
//    backtrace_symbols将从backtrace函数获取的信息转化为一个字符串数组. 参数buffer应该是从backtrace函数获取的指针数组,size是该数组中的元素个数(backtrace的返回值)
//    
//    函数返回值是一个指向字符串数组的指针,它的大小同buffer相同.每个字符串包含了一个相对于buffer中对应元素的可打印信息.它包括函数名，函数的偏移地址,和实际的返回地址
//    
//    现在,只有使用ELF二进制格式的程序才能获取函数名称和偏移地址.在其他系统,只有16进制的返回地址能被获取.另外,你可能需要传递相应的符号给链接器,以能支持函数名功能(比如,在使用GNU ld链接器的系统中,你需要传递(-rdynamic)， -rdynamic可用来通知链接器将所有符号添加到动态符号表中，如果你的链接器支持-rdynamic的话，建议将其加上！)
//    
//    该函数的返回值是通过malloc函数申请的空间,因此调用者必须使用free函数来释放指针.
//    
//    注意:如果不能为字符串获取足够的空间函数的返回值将会为NULL
    int i;
    
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount;
         i < UncaughtExceptionHandlerReportAddressCount;
         i ++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    
    return backtrace.copy;
}

//- (void)alert {
//    
//}

- (void)volatileAndSaveCritialApplicationData {
    //一些重要数据储存
}

- (void)handleException:(NSException *)exception {
    [self volatileAndSaveCritialApplicationData];
    //
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"抱歉程序出错" message:[NSString stringWithFormat:                                                                                        @"如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开\n\n异常原因如下:\n%@\n%@",[exception reason],[exception userInfo]] preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *alertContinue = [UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    UIAlertAction *alertCancel = [UIAlertAction actionWithTitle:@"退出" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertController addAction:alertContinue];
    [alertController addAction:alertCancel];
    
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    
    while (!dismiss) {
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    CFRelease(allModes);
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    if ([[exception name] isEqualToString:UncaughtExcepitonHandleSignalExceptionKey]) {
        kill(getpid(), [[[exception userInfo] valueForKey:UncaughtExcepitonHandleSignalExceptionKey] intValue]);
    }else {
        [exception raise];
    }
}




@end

void handleException(NSException *exception) {
//    atomic_fetch_add(<#object#>, <#operand#>)
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExcepitonCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    NSArray *callStack = [UncaughtExceptionHandler backTrace]; //类方法
    
    NSMutableDictionary *userinfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userinfo setObject:callStack forKey:UncaughtExcepitonHandleSignalAddressKey];
    
    [[[UncaughtExceptionHandler alloc] init] performSelectorOnMainThread:@selector(handleException:) withObject:[NSException exceptionWithName:[exception name] reason:[exception name] userInfo:[exception userInfo]] waitUntilDone:YES];
}

void signalHandler(int signal) {
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExcepitonCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    
    NSMutableDictionary *userinfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExcepitonHandleSignalExceptionKey];
    
    [[[UncaughtExceptionHandler alloc] init] performSelectorOnMainThread:@selector(handleException:) withObject:[NSException exceptionWithName:UncaughtExcepitonHandleSignalExceptionName reason:[NSString stringWithFormat:@"signal %d was raised",signal] userInfo: userinfo] waitUntilDone:YES];
    
}

void installUncaughtExceptionHandler(void) {
    NSSetUncaughtExceptionHandler(&handleException);
    signal(SIGABRT, signalHandler);
    signal(SIGILL, signalHandler);
    signal(SIGSEGV, signalHandler);
    signal(SIGFPE, signalHandler);
    signal(SIGBUS, signalHandler);
    signal(SIGPIPE, signalHandler);
/*    函数说明 ： 　　signal()会依参数signum 指定的信号编号来设置该信号的处理函数。当指定的信号到达时就会跳转到参数handler指定的函数执行。当一个信号的信号处理函数执行时，　　如果进程又接收到了该信号，该信号会自动被储存而不会中断信号处理函数的执行，直到信号处理函数执行完毕再重新调用相应的处理函数。但是如果在信号处理函数执行时进程收到了其它类型的信号，该函数的执行就会被中断。
    返回值： 返回先前的信号处理函数指针，如果有错误则返回SIG_ERR(-1)。
    附加说明 ：在信号发生跳转到自定的handler处理函数执行后，系统会自动将此处理函数换回原来系统预设的处理方式，如果要改变此操作请改用sigaction()。
    下面的情况可以产生Signal：
    1. 按下CTRL+C产生SIGINT
    2. 硬件中断，如除0，非法内存访问（SIGSEV）等等
    3. Kill函数可以对进程发送Signal
    4. Kill命令。实际上是对Kill函数的一个包装
    5. 软件中断。如当Alarm Clock超时（SIGURG），当Reader中止之后又向管道写数据（SIGPIPE），等等
    　
    2 Signals:
    Signal	Description
    SIGABRT	由调用abort函数产生，进程非正常退出
    SIGALRM	用alarm函数设置的timer超时或setitimer函数设置的interval timer超时
    SIGBUS	某种特定的硬件异常，通常由内存访问引起
    SIGCHLD	进程Terminate或Stop的时候，SIGCHLD会发送给它的父进程。缺省情况下该Signal会被忽略
    SIGCONT	当被stop的进程恢复运行的时候，自动发送
    SIGEMT	和实现相关的硬件异常
    SIGFPE	数学相关的异常，如被0除，浮点溢出，等等
    SIGHUP	发送给具有Terminal的Controlling Process，当terminal被disconnect时候发送
    SIGILL	非法指令异常
    SIGINFO	BSD signal。由Status Key产生，通常是CTRL+T。发送给所有Foreground Group的进程
    SIGINT	由Interrupt Key产生，通常是CTRL+C或者DELETE。发送给所有ForeGround Group的进程
    SIGIO	异步IO事件
    SIGIOT	实现相关的硬件异常，一般对应SIGABRT
    SIGKILL	无法处理和忽略。中止某个进程
    SIGPIPE	在reader中止之后写Pipe的时候发送
    SIGPOLL	当某个事件发送给Pollable Device的时候发送
    SIGQUIT	输入Quit Key的时候（CTRL+\）发送给所有Foreground Group的进程
    SIGSEGV	非法内存访问
    SIGSTOP	中止进程。无法处理和忽略。
    SIGSYS	非法系统调用
    SIGTERM	请求中止进程，kill命令缺省发送
    SIGTRAP	实现相关的硬件异常。一般是调试异常
    SIGTSTP	Suspend Key，一般是Ctrl+Z。发送给所有Foreground Group的进程
    SIGTTIN	当Background Group的进程尝试读取Terminal的时候发送
    SIGTTOU	当Background Group的进程尝试写Terminal的时候发送
    SIGURG	当out-of-band data接收的时候可能发送
    SIGUSR1	用户自定义signal 1
    SIGUSR2	用户自定义signal 2
    SIGVTALRM	setitimer函数设置的Virtual Interval Timer超时的时候
    SIGWINCH	当Terminal的窗口大小改变的时候，发送给Foreground Group的所有进程
    SIGXCPU	当CPU时间限制超时的时候
    SIGXFSZ	进程超过文件大小限制
    SIGXRES	Solaris专用，进程超过资源限制的时候发送
    　　1、不要使用低级的或者STDIO.H的IO函数　　2、不要使用对操作　　3、不要进行系统调用 　　4、不是浮点信号的时候不要用longjmp 　　5、singal函数是由ISO C定义的。因为ISO C不涉及多进程，进程组以及终端I/O等，所以他对信号的定义非常含糊，以至于对UNIX系统而言几乎毫无用处。　　备注：因为singal的语义于现实有关，所以最好使用sigaction函数替代本函数。
 */
}

