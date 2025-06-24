#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// [侦探日志模块代码与上一版相同，保持不变]
static UITextView *g_detectiveLogView = nil;
static void DetectiveLog(NSString *format, ...) { if (!g_detectiveLogView) return; va_list args; va_start(args, format); NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *currentText = g_detectiveLogView.text; NSString *newText = [NSString stringWithFormat:@"%@\n%@", logMessage, currentText]; if (newText.length > 2000) { newText = [newText substringToIndex:2000]; } g_detectiveLogView.text = newText; }); }
static void handlePan(UIPanGestureRecognizer *pan) { UIView *logView = pan.view; CGPoint translation = [pan translationInView:logView.superview]; logView.center = CGPointMake(logView.center.x + translation.x, logView.center.y + translation.y); [pan setTranslation:CGPointZero inView:logView.superview]; }

// [注入侦探模块代码与上一版相同，保持不变]
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated { %orig; if (!g_detectiveLogView && self.view.window) { UIWindow *window = self.view.window; g_detectiveLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, window.bounds.size.height - 210, window.bounds.size.width - 20, 200)]; g_detectiveLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8]; g_detectiveLogView.textColor = [UIColor systemGreenColor]; g_detectiveLogView.font = [UIFont fontWithName:@"Menlo" size:10]; g_detectiveLogView.editable = NO; g_detectiveLogView.layer.borderColor = [UIColor greenColor].CGColor; g_detectiveLogView.layer.borderWidth = 1; g_detectiveLogView.layer.cornerRadius = 8; g_detectiveLogView.userInteractionEnabled = YES; UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)]; [g_detectiveLogView addGestureRecognizer:pan]; [window addSubview:g_detectiveLogView]; DetectiveLog(@"消防水管已开启。正在无差别记录所有事件..."); } }
%new
- (void)handlePan:(UIPanGestureRecognizer *)pan { handlePan(pan); }
%end

// =========================================================================
// 3. 终极消防水管逻辑：无差别记录
// =========================================================================

// --- 水管 #1: 记录所有手势 ---
%hook UIGestureRecognizer
- (void)addTarget:(id)target action:(SEL)action {
    %orig(target, action);
    // 【【【最终的、无过滤修正】】】
    DetectiveLog(@"[手势] Target: <%@: %p> -> Action: %@", NSStringFromClass([target class]), target, NSStringFromSelector(action));
}
%end

// --- 水管 #2: 记录所有控件事件 ---
%hook UIControl
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)controlEvents {
    %orig(target, action, controlEvents);
    // 【【【最终的、无过滤修正】】】
    DetectiveLog(@"[控件] Target: <%@: %p> -> Action: %@", NSStringFromClass([target class]), target, NSStringFromSelector(action));
}
%end

// --- 水管 #3: 记录所有触摸事件 ---
%hook UIView
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    // 【【【最终的、无过滤修正】】】
    DetectiveLog(@"[触摸] 触摸开始于 <%@: %p>", NSStringFromClass(self.class), self);
}
%end
