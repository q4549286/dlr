#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 侦探日志模块
// =========================================================================
static UITextView *g_detectiveLogView = nil;

static void DetectiveLog(NSString *format, ...) {
    if (!g_detectiveLogView) return;
    va_list args;
    va_start(args, format);
    NSString *logMessage = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", logMessage, g_detectiveLogView.text];
        g_detectiveLogView.text = newText;
    });
}

// 拖动手势的处理方法
static void handlePan(UIPanGestureRecognizer *pan) {
    UIView *logView = pan.view;
    CGPoint translation = [pan translationInView:logView.superview];
    logView.center = CGPointMake(logView.center.x + translation.x, logView.center.y + translation.y);
    [pan setTranslation:CGPointZero inView:logView.superview];
}

// =========================================================================
// 2. 注入侦探模块
// =========================================================================
%hook UIViewController
// 【【【最终的、正确的时机修正】】】
// 我们不再使用viewDidLoad，而是使用viewDidAppear:
// 这个方法保证了self.view.window是可用的。
- (void)viewDidAppear:(BOOL)animated {
    %orig; // 总是先调用原始实现
    
    // 我们希望日志视图只在主窗口中创建一次
    if (!g_detectiveLogView && self.view.window) {
        UIWindow *window = self.view.window;
        g_detectiveLogView = [[UITextView alloc] initWithFrame:CGRectMake(10, window.bounds.size.height - 210, window.bounds.size.width - 20, 200)];
        g_detectiveLogView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        g_detectiveLogView.textColor = [UIColor systemGreenColor];
        g_detectiveLogView.font = [UIFont fontWithName:@"Menlo" size:10];
        g_detectiveLogView.editable = NO;
        g_detectiveLogView.layer.borderColor = [UIColor greenColor].CGColor;
        g_detectiveLogView.layer.borderWidth = 1;
        g_detectiveLogView.layer.cornerRadius = 8;
        g_detectiveLogView.userInteractionEnabled = YES;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [g_detectiveLogView addGestureRecognizer:pan];
        
        [window addSubview:g_detectiveLogView];
        DetectiveLog(@"侦探模块已加载。正在监听手势设置...");
    }
}
// 为UIViewController添加拖动处理方法
%new
- (void)handlePan:(UIPanGestureRecognizer *)pan {
    handlePan(pan);
}
%end


// =========================================================================
// 3. 核心侦探逻辑：Hook手势设置
// =========================================================================
%hook UIGestureRecognizer
- (void)addTarget:(id)target action:(SEL)action {
    %orig(target, action);

    NSString *targetClassName = NSStringFromClass([target class]);
    NSString *actionString = NSStringFromSelector(action);

    // 为了减少干扰，我们只显示那些看起来像是自定义方法的目标
    if ([actionString containsString:@":"]) {
         DetectiveLog(@"[发现目标] Gesture: %@ -> Target: %@ -> Action: %@", NSStringFromClass(self.class), targetClassName, actionString);
    }
}
%end
