#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 辅助函数
// =========================================================================
// 强化版 Ivar 打印，能处理更多类型
static void PrintObjectDetails(id obj, NSString *prefix) {
    if (!obj) {
        NSLog(@"%@: (null)", prefix);
        return;
    }
    
    unsigned int count;
    Ivar *ivars = class_copyIvarList([obj class], &count);
    NSLog(@"%@: <%@: %p>", prefix, NSStringFromClass([obj class]), obj);
    
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        NSString *ivarName = [NSString stringWithUTF8String:name];
        
        @try {
            id value = object_getIvar(obj, ivar);
            // 尝试打印对象的描述，而不是仅仅是地址
            if (type[0] == '@' || type[0] == '#') {
                NSLog(@"  %@ -> %@ = %@", prefix, ivarName, value);
            } else {
                // 对于非对象类型，我们可以尝试用 NSValue 包装
                NSValue *nsValue = [NSValue valueWithBytes:(__bridge void *)obj + ivar_getOffset(ivar) objCType:type];
                NSLog(@"  %@ -> %@ = %@", prefix, ivarName, nsValue);
            }
        } @catch (NSException *exception) {
            NSLog(@"  %@ -> %@ = <Could not read value>", prefix, ivarName);
        }
    }
    free(ivars);
}


// =========================================================================
// 核心 Hook
// =========================================================================
static void (*Original_ViewController_顯示天地盤觸摸WithSender)(id, SEL, id);

static void Tweak_ViewController_顯示天地盤觸摸WithSender(id self, SEL _cmd, id sender) {
    NSLog(@"[Sender侦察兵] ==================== 真实点击事件捕获 ====================");
    
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        
        NSLog(@"[Sender侦察兵] *** Gesture Recognizer 概览 ***");
        NSLog(@"[Sender侦察兵] Class: %@", NSStringFromClass([gesture class]));
        NSLog(@"[Sender侦察兵] State: %ld", (long)gesture.state);
        NSLog(@"[Sender侦察兵] View: %@", gesture.view);
        NSLog(@"[Sender侦察兵] Number of touches: %lu", (unsigned long)gesture.numberOfTouches);
        NSLog(@"[Sender侦察兵] Location in view: %@", NSStringFromCGPoint([gesture locationInView:gesture.view]));
        
        // 深入挖掘内部结构
        NSLog(@"[Sender侦察兵] *** Gesture Recognizer 内部 Ivars ***");
        PrintObjectDetails(gesture, @"[Sender侦察兵]");
        
        // 检查手势关联的 touches
        NSSet *touches = [gesture valueForKey:@"touches"];
        if (touches && [touches isKindOfClass:[NSSet class]]) {
            NSLog(@"[Sender侦察兵] *** Touches Set (%lu touches) ***", (unsigned long)touches.count);
            for (UITouch *touch in touches) {
                PrintObjectDetails(touch, @"[Sender侦察兵] Touch");
            }
        }
    } else {
        NSLog(@"[Sender侦察兵] Sender is not a UIGestureRecognizer: %@", sender);
    }
    
    NSLog(@"[Sender侦察兵] ==================== 捕获结束，调用原始方法 ====================");

    // 调用原始方法，确保 App 正常工作
    Original_ViewController_顯示天地盤觸摸WithSender(self, _cmd, sender);
}

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_顯示天地盤觸摸WithSender, (IMP *)&Original_ViewController_顯示天地盤觸摸WithSender);
             NSLog(@"[Sender侦察兵] 已加载。请手动点击天地盘以触发日志。");
        } else {
             NSLog(@"[Sender侦察兵] 错误: 找不到 ViewController 类。");
        }
    }
}
