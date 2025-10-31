#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、辅助函数、方法声明与日志
// =========================================================================

static UIView *g_probePanelView = nil;
static UITextView *g_probeLogTextView = nil;
static UIView *g_probeSelectorView = nil; // 用于捕获点击的透明覆盖层
static BOOL g_isProbeSelectorActive = NO;

// <<<<<<<<<<<<<<<< 核心修正点 1：为新方法提供 @interface 声明 >>>>>>>>>>>>>>>>
@interface UIViewController (EchoProbe)
- (void)showProbePanel;
- (void)closeProbePanel;
- (void)clearProbeLog:(id)sender;
- (void)toggleProbeSelectorMode:(id)sender;
- (void)handleProbeTap:(UITapGestureRecognizer *)gesture;
- (void)probeView:(UIView *)tappedView;
@end


static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    // ... (此函数不变)
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

static UIWindow* GetFrontmostWindow() {
    // ... (此函数不变)
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

static void ProbeLog(NSString *format, ...) {
    // ... (此函数不变) ...
    if (!g_probeLogTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"HH:mm:ss.SSS"];
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newLogLine = [NSString stringWithFormat:@"[%@] %@\n", timestamp, message];
        g_probeLogTextView.text = [g_probeLogTextView.text stringByAppendingString:newLogLine];
        NSRange range = NSMakeRange(g_probeLogTextView.text.length - 1, 1);
        [g_probeLogTextView scrollRangeToVisible:range];
    });
}


// =========================================================================
// 2. Tweak 核心逻辑
// =========================================================================

// <<<<<<<<<<<<<<<< 核心修正点 2：将 runTheProbe: 也声明在 @interface 中 (已完成) >>>>>>>>>>>>>>>>
// (为了代码整洁，将 runTheProbe: 声明也加入上面的 Category 中)

%hook UIViewController

// --- 核心侦查逻辑 ---

%new
- (void)probeView:(UIView *)tappedView {
    // ... (此函数实现不变) ...
    ProbeLog(@"\n\n[PROBE] ====== 实时侦查报告 ====== ");
    if (!tappedView) {
        ProbeLog(@"[PROBE] ❌ 未点击到任何有效视图。");
        ProbeLog(@"[PROBE] ===========================");
        return;
    }
    ProbeLog(@"[PROBE] 🎯 目标视图已锁定。开始向上追溯层级...");
    int depth = 0;
    UIView *currentView = tappedView;
    while (currentView) {
        NSMutableString *indent = [NSMutableString string];
        for (int i = 0; i < depth; i++) { [indent appendString:@"  "]; }
        ProbeLog(@"%@↓ [%d] <%@: %p>", indent, depth, [currentView class], currentView);
        ProbeLog(@"%@   - Frame: %@", indent, NSStringFromCGRect(currentView.frame));
        if ([currentView isKindOfClass:[UILabel class]]) {
            ProbeLog(@"%@   - Text: \"%@\"", indent, ((UILabel *)currentView).text);
        }
        if (currentView.gestureRecognizers.count > 0) {
            ProbeLog(@"%@   - ‼️ 发现手势 (%lu个):", indent, (unsigned long)currentView.gestureRecognizers.count);
            for (UIGestureRecognizer *gesture in currentView.gestureRecognizers) {
                ProbeLog(@"%@     - <%@>", indent, [gesture class]);
                NSArray *targets = GetIvarValueSafely(gesture, @"_targets");
                if (targets && targets.count > 0) {
                    for (id targetActionPair in targets) {
                        id target = [targetActionPair valueForKey:@"target"];
                        SEL action = NSSelectorFromString([targetActionPair valueForKey:@"action"]);
                        ProbeLog(@"%@       - Target: <%@: %p>", indent, [target class], target);
                        ProbeLog(@"%@       - Action: %@", indent, NSStringFromSelector(action));
                    }
                } else {
                    ProbeLog(@"%@       - (无法获取手势目标)", indent);
                }
            }
        }
        currentView = currentView.superview;
        depth++;
    }
    ProbeLog(@"[PROBE] ====== 报告结束 ====== ");
}

// --- 视图选择器模式的控制方法 ---

%new
- (void)handleProbeTap:(UITapGestureRecognizer *)gesture {
    // ... (此函数实现不变) ...
    UIWindow *keyWindow = GetFrontmostWindow();
    CGPoint location = [gesture locationInView:keyWindow];
    g_probePanelView.hidden = YES;
    g_probeSelectorView.hidden = YES;
    UIView *tappedView = [keyWindow hitTest:location withEvent:nil];
    g_probePanelView.hidden = NO;
    g_probeSelectorView.hidden = NO;
    [self probeView:tappedView];
    [self toggleProbeSelectorMode:gesture.view];
}

%new
- (void)toggleProbeSelectorMode:(id)sender {
    // ... (此函数实现不变) ...
    g_isProbeSelectorActive = !g_isProbeSelectorActive;
    UIWindow *keyWindow = GetFrontmostWindow();
    UIButton *button = (UIButton *)sender; // 注意：sender 可能是 nil
    if (g_isProbeSelectorActive) {
        if (!g_probeSelectorView) {
            g_probeSelectorView = [[UIView alloc] initWithFrame:keyWindow.bounds];
            g_probeSelectorView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.2];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleProbeTap:)];
            [g_probeSelectorView addGestureRecognizer:tap];
        }
        [keyWindow addSubview:g_probeSelectorView];
        [keyWindow bringSubviewToFront:g_probePanelView];
        if (button) [button setTitle:@"取消选择" forState:UIControlStateNormal];
        ProbeLog(@"[PROBE] 🔍 已进入视图选择模式。请点击屏幕上任意元素进行侦查。");
    } else {
        if (g_probeSelectorView) {
            [g_probeSelectorView removeFromSuperview];
            g_probeSelectorView = nil;
        }
        if (button) [button setTitle:@"选择视图" forState:UIControlStateNormal];
        ProbeLog(@"[PROBE] 🛑 已退出视图选择模式。");
    }
}


// --- 面板UI的创建与销毁 ---

%new
- (void)showProbePanel {
    // ... (此函数实现不变) ...
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow || g_probePanelView) return;
    g_probePanelView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, keyWindow.bounds.size.width, keyWindow.bounds.size.height * 0.6)];
    g_probePanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_probePanelView.layer.borderColor = [UIColor cyanColor].CGColor;
    g_probePanelView.layer.borderWidth = 1.0;
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, g_probePanelView.bounds.size.width, 30)];
    titleLabel.text = @"Echo 实时侦查面板";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_probePanelView addSubview:titleLabel];
    g_probeLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, g_probePanelView.bounds.size.width - 20, g_probePanelView.bounds.size.height - 110)];
    g_probeLogTextView.backgroundColor = [UIColor blackColor];
    g_probeLogTextView.textColor = [UIColor greenColor];
    g_probeLogTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_probeLogTextView.editable = NO;
    g_probeLogTextView.text = @"日志窗口已就绪...\n";
    [g_probePanelView addSubview:g_probeLogTextView];
    CGFloat buttonWidth = (g_probePanelView.bounds.size.width - 40) / 3.0;
    CGFloat buttonY = g_probePanelView.bounds.size.height - 50;
    UIButton *selectButton = [UIButton buttonWithType:UIButtonTypeSystem];
    selectButton.frame = CGRectMake(10, buttonY, buttonWidth, 40);
    [selectButton setTitle:@"选择视图" forState:UIControlStateNormal];
    [selectButton addTarget:self action:@selector(toggleProbeSelectorMode:) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:selectButton];
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(20 + buttonWidth, buttonY, buttonWidth, 40);
    [clearButton setTitle:@"清空日志" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearProbeLog:) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:clearButton];
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(30 + buttonWidth * 2, buttonY, buttonWidth, 40);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeProbePanel) forControlEvents:UIControlEventTouchUpInside];
    [g_probePanelView addSubview:closeButton];
    [keyWindow addSubview:g_probePanelView];
}

%new
- (void)clearProbeLog:(id)sender { if (g_probeLogTextView) { g_probeLogTextView.text = @""; } }

%new
- (void)closeProbePanel {
    if (g_isProbeSelectorActive) { [self toggleProbeSelectorMode:nil]; }
    if (g_probePanelView) {
        [g_probePanelView removeFromSuperview];
        g_probePanelView = nil;
        g_probeLogTextView = nil;
    }
}

// --- Hook viewDidLoad 来添加我们的侦查按钮 ---
- (void)viewDidLoad {
    %orig;
    
    if ([self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:888888]) return;
            UIButton *probeTriggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            probeTriggerButton.frame = CGRectMake(10, 45, 80, 36);
            probeTriggerButton.tag = 888888;
            [probeTriggerButton setTitle:@"侦查" forState:UIControlStateNormal];
            probeTriggerButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [probeTriggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            probeTriggerButton.layer.cornerRadius = 18;
            [probeTriggerButton addTarget:self action:@selector(showProbePanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:probeTriggerButton];
        });
    }
}

%end

%ctor {
    NSLog(@"[EchoProbe] 实时侦查脚本已加载。");
}
