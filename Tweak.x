#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 全局变量与辅助函数 (大部分与之前相同)
// =========================================================================
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isSimulatingClick = NO; // <<<< 新增状态旗标

static void PrintAllIVars(id object, NSString *prefix) {
    unsigned int count;
    Ivar *ivars = class_copyIvarList([object class], &count);
    NSLog(@"[%@] --- Dumping IVars for %@ <%p> ---", prefix, NSStringFromClass([object class]), object);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        NSString *ivarName = [NSString stringWithUTF8String:name];
        NSString *ivarType = [NSString stringWithUTF8String:type];
        
        @try {
            id value = object_getIvar(object, ivar);
            NSLog(@"[%@] Ivar: %@ (%@) = %@", prefix, ivarName, ivarType, value);
        } @catch (NSException *exception) {
            NSLog(@"[%@] Ivar: %@ (%@) = <Could not read value>", prefix, ivarName, ivarType);
        }
    }
    NSLog(@"[%@] --- End of IVars Dump ---", prefix);
    free(ivars);
}


// =========================================================================
// 核心 Hook
// =========================================================================
@interface UIViewController (EchoTDP)
- (void)createOrShowPanel;
- (void)simulateClickAction;
@end

// Hook 目标方法，用于侦察
%hook UIViewController
- (void)顯示天地盤觸摸WithSender:(UIGestureRecognizer *)sender {
    if (g_isSimulatingClick) {
        PrintAllIVars(self, @"VC偵察兵-模拟点击");
    } else {
        PrintAllIVars(self, @"VC偵察兵-真实点击");
    }
    %orig; // 让原始逻辑继续执行
}

// 添加UI的 Hook
- (void)viewDidLoad {
    %orig;
    Class c = NSClassFromString(@"六壬大占.ViewController");
    if (c && [self isKindOfClass:c]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
            UIWindow* keyWindow = [[UIApplication sharedApplication] keyWindow];
            if (!keyWindow || [keyWindow viewWithTag:556699]) return;
            UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
            b.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            b.tag = 556699;
            [b setTitle:@"推衍天地盘详情" forState:UIControlStateNormal];
            b.backgroundColor = [UIColor blueColor];
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
    
    // 这里我们只执行一次模拟点击，用于触发日志
    SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    if ([self respondsToSelector:action]) {
        // 创建一个空的手势对象，仅用于传递
        UITapGestureRecognizer *fakeGesture = [[UITapGestureRecognizer alloc] init];
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:action withObject:fakeGesture];
        #pragma clang diagnostic pop
    }
    
    // 延时后重置旗标
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_isSimulatingClick = NO;
    });
}
%end


%ctor {
    NSLog(@"[VC偵察兵] 已加载。");
}
