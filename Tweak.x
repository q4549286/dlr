#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-SuperScout] " format), ##__VA_ARGS__)

%hook 六壬大占_天地盤視圖類

// 当一个无法识别的消息被发送给这个对象时，这个方法会被调用
- (id)forwardingTargetForSelector:(SEL)aSelector {
    EchoLog(@"forwardingTargetForSelector: %s", sel_getName(aSelector));
    return %orig;
}

// 如果上一个方法返回nil，这个方法会被调用
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    EchoLog(@"methodSignatureForSelector: %s", sel_getName(aSelector));
    return %orig;
}

// 最后，这个方法会被调用来处理消息
- (void)forwardInvocation:(NSInvocation *)anInvocation {
    EchoLog(@"!!!!!! forwardInvocation: CAPTURED ACTION !!!!!!");
    EchoLog(@"Selector: %s", sel_getName([anInvocation selector]));
    
    // 打印所有参数
    for (int i = 2; i < [[anInvocation methodSignature] numberOfArguments]; i++) {
        const char *argType = [[anInvocation methodSignature] getArgumentTypeAtIndex:i];
        id arg;
        [anInvocation getArgument:&arg atIndex:i];
        EchoLog(@"Argument %d (type %s): %@", i - 2, argType, arg);
    }
    
    %orig;
}

%end
