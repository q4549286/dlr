// Filename: EchoGestureMonitor.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL g_isMonitoring = NO;
static UITextView *g_monitorLogView = nil;
static UIView *g_monitorPanelView = nil;

// --- 辅助函数：记录日志 ---
static void MonitorLog(NSString *format, ...) {
    if (!g_monitorLogView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", message, g_monitorLogView.text];
        if (newText.length > 2000) { // 防止日志过长
            newText = [newText substringToIndex:2000];
        }
        g_monitorLogView.text = newText;
        NSLog(@"[GestureMonitor] %@", message);
    });
}

// --- 核心Hook：拦截手势添加 ---
%hook UIGestureRecognizer
- (void)addTarget:(id)target action:(SEL)action {
    %orig;
    if (g_isMonitoring && self.view) {
        MonitorLog(@"--- Event Detected ---\nView: %@\nTarget: %@\nAction: %@\n--------------------",
                   NSStringFromClass([self.view class]),
                   NSStringFromClass([target class]),
                   NSStringFromSelector(action));
    }
}
%end

// --- UI控制 ---
@interface UIViewController (EchoMonitorControl)
- (void)setupMonitorWindow;
- (void)toggleMonitoring:(UIButton *)sender;
- (void)handlePan:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupMonitorWindow];
        });
    }
}
%end

%new
@implementation UIViewController (EchoMonitorControl)

- (void)setupMonitorWindow {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:778899]) return;

    g_monitorPanelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 250, 200)];
    g_monitorPanelView.tag = 778899;
    g_monitorPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_monitorPanelView.layer.cornerRadius = 10;
    g_monitorPanelView.layer.borderColor = [UIColor cyanColor].CGColor;
    g_monitorPanelView.layer.borderWidth = 1.0;
    g_monitorPanelView.clipsToBounds = YES;

    // 拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [g_monitorPanelView addGestureRecognizer:pan];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 250, 20)];
    titleLabel.text = @"手势监控器";
    titleLabel.textColor = [UIColor cyanColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [g_monitorPanelView addSubview:titleLabel];
    
    // 控制按钮
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(10, 30, 230, 30);
    [button setTitle:@"开始监控" forState:UIControlStateNormal];
    [button addTarget:self action:@selector(toggleMonitoring:) forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    button.layer.cornerRadius = 5;
    [g_monitorPanelView addSubview:button];

    // 日志视图
    g_monitorLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, 70, 230, 120)];
    g_monitorLogView.backgroundColor = [UIColor blackColor];
    g_monitorLogView.textColor = [UIColor greenColor];
    g_monitorLogView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_monitorLogView.editable = NO;
    g_monitorLogView.text = @"点击'开始监控'后,触摸屏幕元素。";
    [g_monitorPanelView addSubview:g_monitorLogView];

    [keyWindow addSubview:g_monitorPanelView];
}

- (void)toggleMonitoring:(UIButton *)sender {
    g_isMonitoring = !g_isMonitoring;
    if (g_isMonitoring) {
        [sender setTitle:@"停止监控" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor redColor];
        g_monitorLogView.text = @"监控已开始...\n";
    } else {
        [sender setTitle:@"开始监控" forState:UIControlStateNormal];
        sender.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.2 alpha:1.0];
    }
}

- (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:g_monitorPanelView.superview];
    g_monitorPanelView.center = CGPointMake(g_monitorPanelView.center.x + translation.x, g_monitorPanelView.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:g_monitorPanelView.superview];
}

@end
%end
