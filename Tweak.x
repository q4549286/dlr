#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================

#pragma mark - Constants & Global State
static const NSInteger kEchoMonitorPanelTag = 112233;
static const NSInteger kEchoMonitorButtonTag = 445566;

static UIView *g_monitorPanelView = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isMonitoringPaused = NO;
static CGPoint g_panStartPoint; // 用于拖动

// 复用原框架的颜色和辅助函数
#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_CARD_BG          [UIColor colorWithWhite:0.2 alpha:0.95]
#define ECHO_COLOR_LOG_TOUCH        [UIColor whiteColor]
#define ECHO_COLOR_LOG_DETAIL       [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_IMPORTANT    [UIColor cyanColor]

static void LogMessage(UIColor *color, NSString *format, ...);
static UIWindow* GetFrontmostWindow();

// =========================================================================
// 2. UI创建与管理
// =========================================================================
@interface UIViewController (EchoMonitor)
- (void)createOrShowMonitorPanel;
- (void)handleMonitorButtonTap:(UIButton *)sender;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    
    // 只在主界面控制器上加载
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:kEchoMonitorButtonTag]) return;

            UIButton *monitorButton = [UIButton buttonWithType:UIButtonTypeSystem];
            monitorButton.frame = CGRectMake(10, 45, 120, 36); // 放在左上角
            monitorButton.tag = kEchoMonitorButtonTag;
            [monitorButton setTitle:@"触摸监控" forState:UIControlStateNormal];
            monitorButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            monitorButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0]; // 醒目的红色
            [monitorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            monitorButton.layer.cornerRadius = 18;
            monitorButton.layer.shadowColor = [UIColor blackColor].CGColor;
            monitorButton.layer.shadowOffset = CGSizeMake(0, 2);
            monitorButton.layer.shadowOpacity = 0.4;
            [monitorButton addTarget:self action:@selector(createOrShowMonitorPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:monitorButton];
        });
    }
}

%new
- (void)createOrShowMonitorPanel {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) return;

    if (g_monitorPanelView) {
        [UIView animateWithDuration:0.3 animations:^{
            g_monitorPanelView.alpha = 0;
        } completion:^(BOOL finished) {
            [g_monitorPanelView removeFromSuperview];
            g_monitorPanelView = nil;
            g_logTextView = nil;
        }];
        return;
    }

    // 创建一个更小的、可拖动的面板
    CGFloat panelWidth = keyWindow.bounds.size.width - 20;
    CGFloat panelHeight = 350;
    g_monitorPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, panelWidth, panelHeight)];
    g_monitorPanelView.tag = kEchoMonitorPanelTag;
    g_monitorPanelView.layer.cornerRadius = 16;
    g_monitorPanelView.clipsToBounds = YES;
    g_monitorPanelView.layer.borderColor = [UIColor grayColor].CGColor;
    g_monitorPanelView.layer.borderWidth = 0.5;

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_monitorPanelView.bounds;
    [g_monitorPanelView addSubview:blurView];

    // 添加拖动手势
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [g_monitorPanelView addGestureRecognizer:panGesture];

    // 内容视图
    UIView *contentView = blurView.contentView;
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, panelWidth, 20)];
    titleLabel.text = @"触摸事件监控";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];

    // 控制按钮
    CGFloat buttonWidth = (panelWidth - 40) / 3;
    
    UIButton *pauseButton = [UIButton buttonWithType:UIButtonTypeSystem];
    pauseButton.frame = CGRectMake(10, 40, buttonWidth, 30);
    [pauseButton setTitle:@"暂停" forState:UIControlStateNormal];
    [pauseButton setTitle:@"继续" forState:UIControlStateSelected];
    pauseButton.tag = 101; // Pause/Resume
    [pauseButton addTarget:self action:@selector(handleMonitorButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:pauseButton];

    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(20 + buttonWidth, 40, buttonWidth, 30);
    [clearButton setTitle:@"清空日志" forState:UIControlStateNormal];
    clearButton.tag = 102; // Clear
    [clearButton addTarget:self action:@selector(handleMonitorButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:clearButton];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(30 + 2 * buttonWidth, 40, buttonWidth, 30);
    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    closeButton.tag = 103; // Close
    [closeButton addTarget:self action:@selector(handleMonitorButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:closeButton];

    // 日志窗口
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 80, panelWidth - 20, panelHeight - 90)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logTextView.editable = NO;
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.text = @"[监控核心]：已启动，等待触摸事件...\n";
    [contentView addSubview:g_logTextView];

    // 动画显示
    g_monitorPanelView.alpha = 0;
    [keyWindow addSubview:g_monitorPanelView];
    [UIView animateWithDuration:0.3 animations:^{
        g_monitorPanelView.alpha = 1.0;
    }];
}

%new
- (void)handleMonitorButtonTap:(UIButton *)sender {
    switch (sender.tag) {
        case 101: // Pause/Resume
            g_isMonitoringPaused = !g_isMonitoringPaused;
            sender.selected = g_isMonitoringPaused;
            LogMessage(ECHO_COLOR_LOG_IMPORTANT, @"[系统] 监控已 %@。", g_isMonitoringPaused ? @"暂停" : @"继续");
            break;
        case 102: // Clear
            g_logTextView.text = @"";
            break;
        case 103: // Close
            [self createOrShowMonitorPanel];
            break;
    }
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIWindow *keyWindow = GetFrontmostWindow();
    UIView *panel = recognizer.view;

    if (recognizer.state == UIGestureRecognizerStateBegan) {
        g_panStartPoint = [recognizer locationInView:keyWindow];
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint newPoint = [recognizer locationInView:keyWindow];
        CGFloat dx = newPoint.x - g_panStartPoint.x;
        CGFloat dy = newPoint.y - g_panStartPoint.y;
        
        CGPoint newCenter = CGPointMake(panel.center.x + dx, panel.center.y + dy);
        panel.center = newCenter;
        
        g_panStartPoint = newPoint;
    }
}

%end

// =========================================================================
// 3. 核心监控Hook
// =========================================================================

static void logViewDetails(UIView *view, int depth);
static void logResponderChain(UIResponder *responder);

%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    // 立即调用原始方法，确保不影响App功能
    %orig(event);

    // 如果监控暂停或面板不存在，则不记录
    if (g_isMonitoringPaused || !g_monitorPanelView) {
        return;
    }

    // 只关心触摸事件
    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        UITouch *touch = [touches anyObject];

        // 只在触摸开始时记录详细信息，避免日志刷屏
        if (touch.phase == UITouchPhaseBegan) {
            
            // 1. 记录触摸基本信息
            LogMessage(ECHO_COLOR_LOG_TOUCH, @"\n--- 触摸开始 (Touch Began) ---");
            
            // 2. 获取并记录被触摸的视图
            UIView *touchedView = touch.view;
            if (touchedView) {
                logViewDetails(touchedView, 0);

                // 3. 记录响应者链
                LogMessage(ECHO_COLOR_LOG_DETAIL, @"  响应者链 (Responder Chain):");
                logResponderChain(touchedView);

            } else {
                LogMessage(ECHO_COLOR_LOG_DETAIL, @"  未命中任何特定视图。");
            }
        } else if (touch.phase == UITouchPhaseEnded) {
             LogMessage(ECHO_COLOR_LOG_TOUCH, @"--- 触摸结束 (Touch Ended) ---");
        }
    }
}

%end

// =========================================================================
// 4. 日志与辅助函数
// =========================================================================

static void logViewDetails(UIView *view, int depth) {
    if (!view) return;

    NSMutableString *indent = [NSMutableString string];
    for (int i = 0; i < depth; i++) {
        [indent appendString:@"  "];
    }

    // 记录视图类名和基本信息
    NSString *className = NSStringFromClass([view class]);
    LogMessage(ECHO_COLOR_LOG_DETAIL, @"%@-> 命中视图: [%@]", indent, className);
    
    // 尝试获取文本内容
    NSString *content = nil;
    if ([view isKindOfClass:[UILabel class]]) {
        content = ((UILabel *)view).text;
    } else if ([view isKindOfClass:[UIButton class]]) {
        content = ((UIButton *)view).titleLabel.text;
    }
    if (content) {
        LogMessage(ECHO_COLOR_LOG_DETAIL, @"%@   - 内容: \"%@\"", indent, content);
    }
    
    // **核心：记录手势识别器**
    if (view.gestureRecognizers.count > 0) {
        LogMessage(ECHO_COLOR_LOG_IMPORTANT, @"%@   - 发现手势识别器 [%lu个]:", indent, (unsigned long)view.gestureRecognizers.count);
        for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
            LogMessage(ECHO_COLOR_LOG_IMPORTANT, @"%@     * %@", indent, NSStringFromClass([gesture class]));
        }
    }
}

static void logResponderChain(UIResponder *responder) {
    int i = 0;
    while (responder) {
        LogMessage(ECHO_COLOR_LOG_DETAIL, @"    [%d] %@", i, NSStringFromClass([responder class]));
        responder = [responder nextResponder];
        i++;
    }
}

static void LogMessage(UIColor *color, NSString *format, ...) {
    if (!g_logTextView) return;
    
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@]", [formatter stringFromDate:[NSDate date]]];
        
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ %@\n", logPrefix, message]];
        
        // 设置默认颜色
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        
        // 时间戳用灰色
        [logLine addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:NSMakeRange(0, logPrefix.length)];
        
        [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [existingText appendAttributedString:logLine];
        
        g_logTextView.attributedText = existingText;
        
        // 自动滚动到底部
        if (existingText.length > 0) {
            NSRange bottom = NSMakeRange(existingText.length - 1, 1);
            [g_logTextView scrollRangeToVisible:bottom];
        }
    });
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
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

// =========================================================================
// 5. 初始化
// =========================================================================

%ctor {
    @autoreleasepool {
        NSLog(@"[EchoMonitor] 触摸监控脚本已加载。");
    }
}
