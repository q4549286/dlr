#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 辅助函数
// =========================================================================
// 终极强化版 Ivar 打印函数，更安全，信息更全
static void PrintSafeObjectDescription(id obj, NSString *prefix) {
    if (!obj) {
        NSLog(@"%@: (null)", prefix);
        return;
    }

    NSLog(@"%@: <%@: %p>", prefix, NSStringFromClass([obj class]), obj);

    unsigned int count;
    Ivar *ivars = class_copyIvarList([obj class], &count);

    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        if (name == NULL || type == NULL) continue;

        NSString *ivarName = [NSString stringWithUTF8String:name];
        
        // 尝试用 KVC 读取，这是最安全的方式
        @try {
            id value = [obj valueForKey:ivarName];
            NSLog(@"  %@ -> %@ (KVC) = %@", prefix, ivarName, value);
        } @catch (NSException *exception) {
            // 如果 KVC 失败 (例如非 KVC-compliant)，我们尝试用更底层的方式
            @try {
                 if (type[0] == '@' || type[0] == '#') { // 对象类型
                    id value = object_getIvar(obj, ivar);
                    NSLog(@"  %@ -> %@ (ivar) = %@", prefix, ivarName, value);
                } else { // C 基本类型
                    NSLog(@"  %@ -> %@ = <primitive type>", prefix, ivarName);
                }
            } @catch (NSException *innerException) {
                 NSLog(@"  %@ -> %@ = <ivar read failed>", prefix, ivarName);
            }
        }
    }
    free(ivars);
}


// =========================================================================
// 核心 Hook
// =========================================================================
static void (*Original_ViewController_顯示天地盤觸摸WithSender)(id, SEL, id);

static void Tweak_ViewController_顯示天地盤觸摸WithSender(id self, SEL _cmd, id sender) {
    NSLog(@"[最终答案侦察兵] ==================== 真实点击事件捕获 ====================");
    
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        
        NSLog(@"[最终答案侦察兵] *** GESTURE PUBLIC PROPERTIES ***");
        NSLog(@"[最终答案侦察兵] Class: %@", NSStringFromClass([gesture class]));
        NSLog(@"[最终答案侦察兵] State: %ld", (long)gesture.state);
        NSLog(@"[最终答案侦察兵] View: <%@: %p>", NSStringFromClass([gesture.view class]), gesture.view);
        
        NSLog(@"[最终答案侦察兵] *** GESTURE DEEP DIVE ***");
        PrintSafeObjectDescription(gesture, @"[最终答案侦察兵] Gesture");
        
        // 我们从之前的日志知道 touches 是一个数组，所以用更安全的方式访问
        @try {
            id touchesCollection = [gesture valueForKey:@"touches"];
            NSLog(@"[最终答案侦察兵] touches collection class: %@", NSStringFromClass([touchesCollection class]));

            if (touchesCollection && ([touchesCollection isKindOfClass:[NSSet class]] || [touchesCollection isKindOfClass:[NSArray class]])) {
                NSLog(@"[最终答案侦察兵] *** TOUCHES DEEP DIVE ***");
                for (UITouch *touch in touchesCollection) {
                    PrintSafeObjectDescription(touch, @"[最终答案侦察兵] Touch");
                }
            }
        } @catch (NSException *e) {
             NSLog(@"[最终答案侦察兵] 获取 touches 失败: %@", e.reason);
        }

    } else {
        NSLog(@"[最终答案侦察兵] Sender is not a UIGestureRecognizer: %@", sender);
    }
    
    NSLog(@"[最终答案侦察兵] ======================= 捕获结束 =======================");

    // 调用原始方法，确保 App 正常工作
    Original_ViewController_顯示天地盤觸摸WithSender(self, _cmd, sender);
}

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_顯示天地盤觸摸WithSender, (IMP *)&Original_ViewController_顯示天地盤觸摸WithSender);
             NSLog(@"[最终答案侦察兵] 已加载。请手动点击天地盘以触发日志。");
        } else {
             NSLog(@"[最终答案侦察兵] 错误: 找不到 ViewController 类。");
        }
    }
}
