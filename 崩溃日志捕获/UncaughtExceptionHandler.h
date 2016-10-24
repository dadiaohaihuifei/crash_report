//
//  UncaughtExceptionHandler.h
//  崩溃日志捕获
//
//  Created by MrWu on 2016/10/24.
//  Copyright © 2016年 TTYL. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UncaughtExceptionHandler : NSObject {
    BOOL dismiss;
}

@end

void handleException(NSException *exception);

void signalHandler(int signal);

void installUncaughtExceptionHandler(void);
