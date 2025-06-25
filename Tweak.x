// Filename: UltimateProbe_v11.2_Final.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局UI变量 & 辅助函数
// =========================================================================

static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) {
    if (!g_logView) return;
    
    // 修正了之前版本中缺失的变量参数处理逻辑
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        g_logView.text = [NSString stringWithFormat:@"%@\n%@", message, g_logView.text];
        if (g_logView.text.length > 2000) {
            g_logView.text = [g_logView.text substringToIndex:2000];
        }
    });
}

// =========================================================================
// 2. UIViewController 分类接口
// =========================================================================
@interface UIViewController (ProbeUI)
- (void)setupProbePanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end


// =========================================================================
// 3. 核心Hook：拦截最底层的 UIWindow sendEvent
// =========================================================================
%hook UIWindow

- (void)sendEvent:(UIEvent *)event {
    // 只要有事件进来，就在日志打印一个点
    // 我们把PanelLog放在原始函数调用之前，确保第一时间看到反应
    PanelLog(@".");

    // 调用原始方法，否则App会卡死
    %orig;

    // 为了避免日志刷屏太快，我们只在触摸结束时打印详细信息
    if (event.type == UIEventTypeTouches) {
        UITouch *touch = [event.allTouches anyObject];
        if (touch.phase == UITouchPhaseEnded) {
            CGPoint location = [touch locationInView:self];
            UIView *hitView = [self hitTest:location withEvent:event];
            PanelLog(@"--- TOUCH ENDED on: %@ ---", NSStringFromClass([hitView class]));
        }
    }
}

%end


// =========================================================================
// 4. UIViewController Hook 与新方法实现
// =========================================================================
%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupProbePanel];
        });
    }
}

%new
- (void)setupProbePanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:111111]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 250, 200)];
    panelView.tag = 111111;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor magentaColor].CGColor;
    panelView.layer.borderWidth = 2.0;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 250, 20)];
    titleLabel.text = @"终极探针 v11.2";
    titleLabel.textColor = [UIColor magentaColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 35, 230, 155)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logView.editable = NO;
    g_logView.text = @"监控已开始。\n请在屏幕上随意滑动或点击。\n如果Hook成功，本窗口会疯狂刷屏 '.'";
    [panelView addSubview:g_logView];

    [keyWindow addSubview:panelView];
    
    // 修正了之前版本中的拼写错误
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
