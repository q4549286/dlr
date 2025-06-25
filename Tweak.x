// Filename: UltimateDelegateMonitor_v11.1_Fixed.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle];
        NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text];
        if (newText.length > 5000) { newText = [newText substringToIndex:5000]; }
        g_logView.text = newText;
        NSLog(@"[DelegateMonitor-v11.1] %@", message);
    });
}

// UIViewController 分类接口
@interface UIViewController (DelegateMonitorUI)
- (void)setupDelegateMonitorPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end


// ========================================================
// 核心Hook：拦截手势代理方法
// 我们Hook的是 `六壬大占.ViewController` 自身
// ========================================================
%hook 六壬大占.ViewController

// *** FIX: Corrected the code by placing the logic inside the method implementation ***
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 首先，调用原始方法，确保功能正常
    BOOL shouldReceive = %orig;

    // 获取触摸点和被触摸的视图
    UIView *touchedView = touch.view;
    CGPoint location = [touch locationInView:touch.window];
    
    // 打印所有信息
    PanelLog(@"--- GESTURE DELEGATE CALLED (shouldReceiveTouch) ---\n- Gesture: %@\n- On View: %@\n- Touched View: %@\n- Touch Location: %@\n- Delegate Method Result: %s\n--------------------",
             NSStringFromClass([gestureRecognizer class]),
             NSStringFromClass([gestureRecognizer.view class]),
             NSStringFromClass([touchedView class]),
             NSStringFromCGPoint(location),
             shouldReceive ? "YES" : "NO");

    return shouldReceive;
}

// 可选：Hook另一个常见的代理方法
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    BOOL shouldBegin = %orig;
    PanelLog(@"--- GESTURE DELEGATE CALLED (shouldBegin) ---\n- Gesture: %@ on %@\n- Delegate Method Result: %s\n--------------------",
             NSStringFromClass([gestureRecognizer class]),
             NSStringFromClass([gestureRecognizer.view class]),
             shouldBegin ? "YES" : "NO");
    return shouldBegin;
}

%end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupDelegateMonitorPanel];
        });
    }
}

%new
- (void)setupDelegateMonitorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:111111]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 250)];
    panelView.tag = 111111;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.8 alpha:1.0].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"手势代理监控器 v11.1";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.8 alpha:1.0];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 280, 200)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES;
    g_logView.text = @"监控已自动开始。\n请点击App界面上的“课体”区域，本窗口会显示手势代理方法的调用情况。";
    [panelView addSubview:g_logView];

    [keyWindow addSubview:panelView];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panelView addGestureRecognizer:pan];
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%end
