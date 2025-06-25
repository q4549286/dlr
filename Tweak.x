// Filename: UltimateActionMonitor_v10.x

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
        NSLog(@"[ActionMonitor-v10] %@", message);
    });
}

// UIViewController 分类接口
@interface UIViewController (ActionMonitorUI)
- (void)setupActionMonitorPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

// ========================================================
// 核心Hook：拦截事件派发的总出口
// ========================================================
%hook UIApplication

- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event {
    // 监控我们的信息
    PanelLog(@"--- ACTION SENT ---\n- Action: %@\n- Target: %@ (%@)\n- Sender: %@ (%@)\n--------------------",
             NSStringFromSelector(action),
             target,
             NSStringFromClass([target class]),
             sender,
             NSStringFromClass([sender class]));

    // 调用原始方法，否则所有按钮和手势都会失效
    return %orig;
}

%end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupActionMonitorPanel];
        });
    }
}

%new
- (void)setupActionMonitorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:101010]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 250)];
    panelView.tag = 101010;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor systemPinkColor].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"全局Action监控器 v10";
    titleLabel.textColor = [UIColor systemPinkColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 280, 200)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES;
    g_logView.text = @"监控已自动开始。\n请点击App界面上的任何可交互元素 (如'课体'、按钮等)，本窗口会实时显示被调用的函数名(Action)。";
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
