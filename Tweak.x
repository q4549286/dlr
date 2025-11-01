#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#define LOG_PREFIX @"[EchoSniffer] "
#define LogInspect(format, ...) NSLog(LOG_PREFIX @"INSPECTING >>> " format, ##__VA_ARGS__)

// =========================================================================
// 1. 定义我们的嗅探函数
// =========================================================================

// 这是指向原始方法实现的指针
static void (*Original_ViewController_displayTianDiPanTouch)(id self, SEL _cmd, id sender);

// 这是我们自己的嗅探实现
static void Tweak_ViewController_displayTianDiPanTouch(id self, SEL _cmd, id sender) {
    
    LogInspect(@"================== CAPTURED A REAL TOUCH EVENT! ==================");
    
    // --- 探测 Sender 的基本信息 ---
    if (sender) {
        LogInspect(@"Sender Class: %@", NSStringFromClass([sender class]));
        LogInspect(@"Sender Description: %@", [sender description]);
    } else {
        LogInspect(@"Sender is nil!");
    }
    
    // --- 深入探测 Sender 的属性 (如果它响应的话) ---
    // 探测是否是 CALayer
    if ([sender isKindOfClass:[CALayer class]]) {
        CALayer *layer = (CALayer *)sender;
        LogInspect(@"It's a CALayer!");
        LogInspect(@"  - Layer Name: %@", [layer name]); // 看看它到底有没有 name
        LogInspect(@"  - Layer Contents: %@", [layer contents]);
        LogInspect(@"  - Layer Delegate: %@", [layer delegate]);
    }
    
    // 探测是否是手势识别器
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *gesture = (UIGestureRecognizer *)sender;
        LogInspect(@"It's a UIGestureRecognizer!");
        LogInspect(@"  - Gesture State: %ld", (long)gesture.state);
        if ([gesture respondsToSelector:@selector(locationInView:)]) {
            CGPoint location = [gesture locationInView:gesture.view];
            LogInspect(@"  - Gesture Location in its own view: (%.2f, %.2f)", location.x, location.y);
        }
    }
    
    // 探测是否是触摸事件
    if ([sender isKindOfClass:[UITouch class]]) {
        UITouch *touch = (UITouch *)sender;
        LogInspect(@"It's a UITouch!");
        CGPoint location = [touch locationInView:touch.window];
        LogInspect(@"  - Touch Location in window: (%.2f, %.2f)", location.x, location.y);
        LogInspect(@"  - Touch Phase: %ld", (long)touch.phase);
    }
    
    // 探测是否是字符串
    if ([sender isKindOfClass:[NSString class]]) {
        LogInspect(@"It's an NSString with value: '%@'", (NSString *)sender);
    }
    
    // --- 尝试打印所有Ivars (如果存在) ---
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([sender class], &ivarCount);
    if (ivars && ivarCount > 0) {
        LogInspect(@"--- Dumping Ivars for Sender's Class (%@) ---", NSStringFromClass([sender class]));
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name) {
                NSString *ivarName = [NSString stringWithUTF8String:name];
                @try {
                    id value = object_getIvar(sender, ivar);
                    LogInspect(@"  - Ivar '%@': %@", ivarName, value);
                } @catch (NSException *exception) {
                    LogInspect(@"  - Ivar '%@': (Could not get value)", ivarName);
                }
            }
        }
        free(ivars);
    }
    
    LogInspect(@"================== END OF INSPECTION ==================");
    
    // --- 安全调用原始方法，确保App正常运行 ---
    if (Original_ViewController_displayTianDiPanTouch) {
        Original_ViewController_displayTianDiPanTouch(self, _cmd, sender);
    }
}


// =========================================================================
// 2. 在 %ctor 中应用 Hook
// =========================================================================

%ctor {
    @autoreleasepool {
        // 解码Swift混淆后的类名
        const char *mangledClassName = "_TtC12å…­å£¬å¤§å 14ViewController";
        Class vcClass = objc_getClass(mangledClassName);

        if (!vcClass) {
            // 如果上面的解码失败，尝试另一种可能的解码方式 (虽然不太可能)
            vcClass = NSClassFromString(@"六壬大占.ViewController");
        }

        if (vcClass) {
            SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
            Method originalMethod = class_getInstanceMethod(vcClass, originalSelector);

            if (originalMethod) {
                // 使用 MSHookMessageEx 来挂钩，并保存原始实现
                MSHookMessageEx(vcClass, originalSelector, (IMP)&Tweak_ViewController_displayTianDiPanTouch, (IMP *)&Original_ViewController_displayTianDiPanTouch);
                NSLog(LOG_PREFIX @"SUCCESS: Hooked '顯示天地盤觸摸WithSender:' successfully!");
            } else {
                NSLog(LOG_PREFIX @"ERROR: Could not find method '顯示天地盤觸摸WithSender:' on class %@.", NSStringFromClass(vcClass));
            }
        } else {
            NSLog(LOG_PREFIX @"ERROR: Could not find class 'ViewController'. Hook failed.");
        }
    }
}
