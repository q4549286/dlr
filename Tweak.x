// Filename: EchoUltimateMonitor_v5.1_Fixed.x

#import <UIKit/UIKit.h>
#import <substrate.h> // 引入 Substrate 核心头文件
#import <objc/runtime.h>

// =========================================================================
// 1. 全局UI元素
// =========================================================================

static UITextView *g_logView = nil;
static UIView *g_panelView = nil;

// =========================================================================
// 2. 辅助函数
// =========================================================================

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
        NSLog(@"[EchoMonitor-v5.1] %@", message);
    });
}

// =========================================================================
// 3. 核心Hook逻辑 (C语言 + Substrate)
// =========================================================================

// 这是我们原始的 addTarget:action: 方法的指针
static void (*original_UIGestureRecognizer_addTarget_action)(id, SEL, id, SEL);

// 这是我们新的、用来替换原始方法的实现
static void new_UIGestureRecognizer_addTarget_action(id self, SEL _cmd, id target, SEL action) {
    // 首先，调用原始的方法，保证App功能正常
    original_UIGestureRecognizer_addTarget_action(self, _cmd, target, action);

    // 然后，执行我们的监控逻辑
    UIGestureRecognizer *gesture = (UIGestureRecognizer *)self;
    
    // 在主线程更新UI，避免多线程问题
    dispatch_async(dispatch_get_main_queue(), ^{
        PanelLog(@"--- GESTURE ADDED ---\n- Gesture: %@\n- On View: %@\n- Target: %@\n- Action: %@\n--------------------",
                 [gesture class],
                 [gesture.view class], // 获取手势所在的视图
                 [target class],
                 NSStringFromSelector(action));
    });
}

// =========================================================================
// 4. UIViewController 分类接口 (声明新方法)
// =========================================================================
@interface UIViewController (EchoMonitorUI)
- (void)setupMonitorPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

// =========================================================================
// 5. Logos Hooks and %new Implementation
// =========================================================================

%hook UIViewController

// 注入一个 viewDidLoad 来创建我们的UI
- (void)viewDidLoad {
    %orig;
    // 确保只在主ViewController上创建一次
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupMonitorPanel];
        });
    }
}

// *** FIX: Moved implementation inside the %hook block and marked with %new ***
%new
- (void)setupMonitorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:555666]) return;

    g_panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 350)];
    g_panelView.tag = 555666;
    g_panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.85];
    g_panelView.layer.cornerRadius = 10;
    g_panelView.layer.borderColor = [UIColor redColor].CGColor;
    g_panelView.layer.borderWidth = 1.0;
    g_panelView.clipsToBounds = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [g_panelView addGestureRecognizer:pan];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 300, 20)];
    titleLabel.text = @"手势监控器 v5.1";
    titleLabel.textColor = [UIColor redColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 35, 280, 305)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES; // 允许复制
    g_logView.text = @"监控已自动开始。\nApp启动过程中的所有手势添加都将记录在此处。\n请向上滚动日志，寻找与'課體視圖'相关的信息。";
    g_logView.layer.cornerRadius = 5;
    [g_panelView addSubview:g_logView];

    [keyWindow addSubview:g_panelView];
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    CGPoint translation = [recognizer translationInView:g_panelView.superview];
    g_panelView.center = CGPointMake(g_panelView.center.x + translation.x, g_panelView.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:g_panelView.superview];
}

%end // End of %hook UIViewController

// =========================================================================
// 6. Constructor 构造函数，确保最早执行Hook
// =========================================================================
%ctor {
    // 在这里，我们使用 Cydia Substrate 的核心函数进行Hook
    // 这样能确保在App的任何代码执行前就完成Hook
    MSHookMessageEx(
        [UIGestureRecognizer class], // 目标类
        @selector(addTarget:action:), // 目标方法
        (IMP)&new_UIGestureRecognizer_addTarget_action, // 我们新的实现
        (IMP*)&original_UIGestureRecognizer_addTarget_action // 用来保存原始实现的指针
    );
    
    // 可以在这里加一个NSLog来确认ctor是否被执行
    NSLog(@"[EchoMonitor-v5.1] Constructor executed, UIGestureRecognizer is now hooked at the earliest stage.");
}
