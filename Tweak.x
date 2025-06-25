// Filename: UltimateMonitor_v7.x

#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) { if (!g_logView) return; va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]; NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text]; if (newText.length > 5000) { newText = [newText substringToIndex:5000]; } g_logView.text = newText; NSLog(@"[UltimateMonitor-v7] %@", message); }); }

// 核心Hook逻辑 (C语言 + Substrate)
static void (*original_UIGestureRecognizer_addTarget_action)(id, SEL, id, SEL);

static void new_UIGestureRecognizer_addTarget_action(id self, SEL _cmd, id target, SEL action) {
    original_UIGestureRecognizer_addTarget_action(self, _cmd, target, action);
    UIGestureRecognizer *gesture = (UIGestureRecognizer *)self;
    dispatch_async(dispatch_get_main_queue(), ^{
        // 我们只关心添加到 “課傳視圖” 上的手势
        if ([gesture.view isKindOfClass:NSClassFromString(@"六壬大占.課傳視圖")]) {
            PanelLog(@"--- TARGET GESTURE ADDED ---\n- Gesture: %@\n- On View: %@ (父视图)\n- Target: %@\n- Action: %@\n--------------------", [gesture class], [gesture.view class], [target class], NSStringFromSelector(action));
        }
    });
}

// UIViewController 分类接口
@interface UIViewController (UltimateMonitorUI)
- (void)setupUltimatePanel;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupUltimatePanel];
        });
    }
}

// 在这里实现新方法，修复之前的编译错误
%new
- (void)setupUltimatePanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:777888]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 200)];
    panelView.tag = 777888;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor systemIndigoColor].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"终极监控器 v7";
    titleLabel.textColor = [UIColor systemIndigoColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 280, 150)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES;
    g_logView.text = @"监控已自动开始。\n请点击App界面上的“课体”区域，然后在本窗口查看被触发的函数名。";
    [panelView addSubview:g_logView];

    [keyWindow addSubview:panelView];
    
    // 增加拖动手势
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

// Constructor 构造函数，确保最早执行Hook
%ctor {
    MSHookMessageEx(
        [UIGestureRecognizer class],
        @selector(addTarget:action:),
        (IMP)&new_UIGestureRecognizer_addTarget_action,
        (IMP*)&original_UIGestureRecognizer_addTarget_action
    );
    NSLog(@"[UltimateMonitor-v7] Constructor hook is active.");
}
