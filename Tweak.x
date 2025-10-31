#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 伪造手势类 (保持不变)
// =========================================================================
@interface EchoFakeGestureRecognizer : UIGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end

@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    return self.fakeLocation;
}
@end

// =========================================================================
// 2. 全局变量、UI与辅助函数
// =========================================================================
static UIView *g_debuggerView = nil;
static UITextView *g_logTextView = nil;

// 辅助函数 (保持不变)
static id GetIvarValueSafely(id, NSString *);
static void LogToScreen(NSString *, ...);

// =========================================================================
// 3. 核心Hook与调试逻辑
// =========================================================================

// 全局变量，用于在Hook之间传递信息
static BOOL g_isPerformingFakeClick = NO;

%hook 六壬大占_ViewController 
// 注意：如果类名包含中文，Theos可能需要这样写。如果编译失败，请尝试 "LiuRenDaZhan.ViewController" 等其他可能的名称

// 【核心】Hook目标方法
- (void)顯示天地盤觸摸WithSender:(UIGestureRecognizer *)sender {
    LogToScreen(@"\n--- HOOK TRIGGERED ---");
    LogToScreen(@"方法 '顯示天地盤觸摸WithSender:' 被调用!");
    
    // 检查调用者
    if (g_isPerformingFakeClick) {
        LogToScreen(@"[INFO] 本次调用由我们的 Tweak 发起。");
    } else {
        LogToScreen(@"[INFO] 本次调用由用户手动点击触发。");
    }
    
    // 打印参数信息
    LogToScreen(@"[PARAM] sender 对象: <%p>", sender);
    LogToScreen(@"[PARAM] sender 类名: %@", NSStringFromClass([sender class]));
    
    // 尝试获取坐标并打印
    @try {
        CGPoint location = [sender locationInView:self.view];
        LogToScreen(@"[PARAM] 点击坐标 (in self.view): {%.1f, %.1f}", location.x, location.y);
    } @catch (NSException *exception) {
        LogToScreen(@"[ERROR] 获取坐标时发生异常: %@", exception.reason);
    }
    
    LogToScreen(@"[EXECUTION] 即将调用原始方法 (%orig)...");
    
    // 调用原始实现
    %orig(sender); 
    
    LogToScreen(@"[EXECUTION] 原始方法 (%orig) 调用完毕。");
    LogToScreen(@"--- HOOK FINISHED ---");
}

%end // %hook 结束


@interface UIViewController (EchoDebugger)
- (void)startDebugTest;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([self.view.window viewWithTag:666777]) return;
            UIButton *debuggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            debuggerButton.frame = CGRectMake(self.view.bounds.size.width - 150, 45, 140, 36);
            debuggerButton.tag = 666777;
            [debuggerButton setTitle:@"Hook调试" forState:UIControlStateNormal];
            debuggerButton.backgroundColor = [UIColor systemOrangeColor];
            [debuggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            debuggerButton.layer.cornerRadius = 18;
            [debuggerButton addTarget:self action:@selector(startDebugTest) forControlEvents:UIControlEventTouchUpInside];
            [self.view.window addSubview:debuggerButton];
        });
    }
}

%new
- (void)startDebugTest {
    if (g_debuggerView) {
        [g_debuggerView removeFromSuperview];
        g_debuggerView = nil; g_logTextView = nil;
        return;
    }
    
    // 创建UI...
    g_debuggerView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 300)];
    g_debuggerView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_debuggerView.layer.cornerRadius = 15;
    g_debuggerView.layer.borderColor = [UIColor orangeColor].CGColor;
    g_debuggerView.layer.borderWidth = 1.0;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_debuggerView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor]; g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11]; g_logTextView.editable = NO; g_logTextView.text = @"";
    [g_debuggerView addSubview:g_logTextView];
    [self.view.window addSubview:g_debuggerView];

    LogToScreen(@"[DEBUG MODE] 开始调试...");

    // 1. 定位 ViewController 和 天地盘视图
    UIViewController *vc = self;
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    __block UIView *plateView = nil;
    void (^__block __weak weak_findViewRecursive)(UIView *);
    void (^findViewRecursive)(UIView *);
    weak_findViewRecursive = findViewRecursive = ^(UIView *view) {
        if (plateView) return; 
        if ([view isKindOfClass:plateViewClass]) { plateView = view; return; }
        for (UIView *subview in view.subviews) { weak_findViewRecursive(subview); }
    };
    findViewRecursive(self.view.window);
    
    if (!plateView) {
        LogToScreen(@"[CRITICAL] 找不到天地盘视图实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例。");

    // 2. 准备一个测试坐标 (就用视图中心点)
    CGPoint testPosition = CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds));
    LogToScreen(@"[INFO] 准备使用测试坐标: {%.1f, %.1f}", testPosition.x, testPosition.y);
    
    // 3. 创建伪造手势
    EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
    fakeGesture.fakeLocation = testPosition;
    
    // 4. 设置标志位并执行调用
    LogToScreen(@"[ACTION] 即将通过 performSelector 调用目标方法...");
    g_isPerformingFakeClick = YES;
    
    SEL clickSelector = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [vc performSelector:clickSelector withObject:fakeGesture];
    #pragma clang diagnostic pop
    
    g_isPerformingFakeClick = NO;
    LogToScreen(@"[ACTION] performSelector 调用已返回。");
}

%end


// =========================================================================
// 4. 初始化
// =========================================================================
%ctor {
    @autoreleasepool {
        NSLog(@"[EchoUltimateHookDebugger] 终极Hook调试脚本已加载。");
    }
}


// =========================================================================
// 5. 辅助函数实现 (放在文件末尾)
// =========================================================================
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarNameStr = [NSString stringWithUTF8String:name];
            if ([ivarNameStr hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}
