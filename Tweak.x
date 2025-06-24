#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// [侦探日志模块代码与上一版相同，保持不变]
static UITextView *g_detectiveLogView = nil;
static void DetectiveLog(NSString *format, ...) { if (!g_detectiveLogView) return; va_list args; va_start(args, format); NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *newText = [NSString stringWithFormat:@"%@\n%@", logMessage, g_detectiveLogView.text]; g_detectiveLogView.text = newText; }); }
static void handlePan(UIPanGestureRecognizer *pan) { UIView *logView = pan.view; CGPoint translation = [pan translationInView:logView.superview]; logView.center = CGPointMake(logView.center.x + translation.x, logView.center.y + translation.y); [pan setTranslation:CGPointZero inView:logView.superview]; }

// [注入侦探模块代码与上一版相同，保持不变]
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated { %orig; if (!g_detectiveLogView && self.view.window) { UIWindow *window = self.view.window; g_detectiveLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, window.bounds.size.height - 210, window.bounds.size.width - 20, 200)]; g_detectiveLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8]; g_detectiveLogView.textColor = [UIColor systemGreenColor]; g_detectiveLogView.font = [UIFont fontWithName:@"Menlo" size:10]; g_detectiveLogView.editable = NO; g_detectiveLogView.layer.borderColor = [UIColor greenColor].CGColor; g_detectiveLogView.layer.borderWidth = 1; g_detectiveLogView.layer.cornerRadius = 8; g_detectiveLogView.userInteractionEnabled = YES; UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]; [g_detectiveLogView addGestureRecognizer:pan]; [window addSubview:g_detectiveLogView]; DetectiveLog(@"万能侦探已加载。请点击课盘项目..."); } }
%new
- (void)handlePan:(UIPanGestureRecognizer *)pan { handlePan(pan); }
%end

// =========================================================================
// 3. 终极侦探逻辑：地毯式搜索
// =========================================================================

// --- 侦探 #1: 监听标准手势 ---
%hook UIGestureRecognizer
- (void)addTarget:(id)target action:(SEL)action {
    %orig(target, action);
    DetectiveLog(@"[手势] Target: %@ -> Action: %@", NSStringFromClass([target class]), NSStringFromSelector(action));
}
%end

// --- 侦探 #2: 监听控件事件 ---
%hook UIControl
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    %orig(target, action, controlEvents);
    DetectiveLog(@"[控件] Target: %@ -> Action: %@", NSStringFromClass([target class]), NSStringFromSelector(action));
}
%end

// --- 侦探 #3: 监听最底层的触摸事件 ---
%hook UIView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    DetectiveLog(@"[触摸] 一个触摸事件在 %@ 上开始", NSStringFromClass(self.class));
}
%end
