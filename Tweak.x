#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 全局变量与辅助函数
// =========================================================================
static BOOL g_isSimulatingClick = NO;

// <<<< 核心修复点 3: 恢复 GetFrontmostWindow 辅助函数 >>>>
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { frontmostWindow = window; break; }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

static void PrintAllIVars(id object, NSString *prefix) {
    if (!object) {
        NSLog(@"[%@] Error: Object to dump is nil.", prefix);
        return;
    }
    unsigned int count;
    // <<<< 核心修复点 1 & 2: 修正函数名 >>>>
    Ivar *ivars = class_copyIvarList([object class], &count);
    NSLog(@"[%@] --- Dumping IVars for %@ <%p> ---", prefix, NSStringFromClass([object class]), object);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        NSString *ivarName = [NSString stringWithUTF8String:name];
        NSString *ivarType = [NSString stringWithUTF8String:type];
        
        @try {
            if (type[0] == '@' || type[0] == '#') {
                 id value = object_getIvar(object, ivar);
                 NSLog(@"[%@] Ivar: %@ (%@) = %@", prefix, ivarName, ivarType, value);
            } else {
                 NSLog(@"[%@] Ivar: %@ (%@) = <Non-Object Type>", prefix, ivarName, ivarType);
            }
        } @catch (NSException *exception) {
            NSLog(@"[%@] Ivar: %@ (%@) = <Could not read value>", prefix, ivarName, ivarType);
        }
    }
    NSLog(@"[%@] --- End of IVars Dump ---", prefix);
    free(ivars);
}

// =========================================================================
// 核心 Hook 逻辑 (C-style)
// =========================================================================
static void (*Original_ViewController_顯示天地盤觸摸WithSender)(id, SEL, id);

static void Tweak_ViewController_顯示天地盤觸摸WithSender(id self, SEL _cmd, id sender) {
    if (g_isSimulatingClick) {
        PrintAllIVars(self, @"VC偵察兵-模拟点击");
    } else {
        PrintAllIVars(self, @"VC偵察兵-真实点击");
    }
    Original_ViewController_顯示天地盤觸摸WithSender(self, _cmd, sender);
}


// =========================================================================
// UIViewController Category and Hook
// =========================================================================
@interface UIViewController (EchoTDP)
- (void)createOrShowPanel;
- (void)simulateClickAction;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class c = NSClassFromString(@"六壬大占.ViewController");
    if (c && [self isKindOfClass:c]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            // <<<< 核心修复点 3: 使用新的辅助函数 >>>>
            UIWindow* keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:556699]) return;
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            b.tag = 556699;
            [b setTitle:@"侦察兵" forState:UIControlStateNormal];
            b.backgroundColor = [UIColor redColor];
            [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            b.layer.cornerRadius = 18;
            [b addTarget:self action:@selector(simulateClickAction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:b];
        });
    }
}

%new
- (void)simulateClickAction {
    g_isSimulatingClick = YES;
    NSLog(@"[VC偵察兵] 准备触发模拟点击...");
    
    SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if ([self respondsToSelector:action]) {
        UITapGestureRecognizer *fakeGesture = [[UITapGestureRecognizer alloc] init];
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:action withObject:fakeGesture];
        #pragma clang diagnostic pop
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_isSimulatingClick = NO;
        NSLog(@"[VC偵察兵] 模拟点击状态已重置。");
    });
}

%end


%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
             SEL originalSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
             MSHookMessageEx(vcClass, originalSelector, (IMP)Tweak_ViewController_顯示天地盤觸摸WithSender, (IMP *)&Original_ViewController_顯示天地盤觸摸WithSender);
             NSLog(@"[VC偵察兵] 已成功 Hook 目标方法。");
        } else {
             NSLog(@"[VC偵察兵] 错误: 找不到 ViewController 类。");
        }
    }
}
