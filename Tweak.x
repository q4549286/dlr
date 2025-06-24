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
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", g_detectiveLogView.text, logMessage];
        g_detectiveLogView.text = newText;
        if (newText.length > 0) [g_detectiveLogView scrollRangeToVisible:NSMakeRange(newText.length - 1, 1)];
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
- (void)viewDidLoad {
    %orig;
    
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
        g_detectiveLogView.userInteractionEnabled = YES; // 允许交互
        
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
    %orig(target, action); // 先让原始方法执行

    NSString *targetClassName = NSStringFromClass([target class]);
    NSString *actionString = NSStringFromSelector(action);

    // 为了减少干扰，我们只显示那些看起来像是自定义方法的目标
    // (系统方法通常不包含冒号，或者目标是系统内部类)
    if ([actionString containsString:@":"]) {
         DetectiveLog(@"[发现目标] Gesture: %@ -> Target: %@ -> Action: %@", NSStringFromClass(self.class), targetClassName, actionString);
    }
}
%end
