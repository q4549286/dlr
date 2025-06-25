// Filename: UltimateGlobalMonitor_v8.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) { if (!g_logView) return; va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]; NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text]; if (newText.length > 5000) { newText = [newText substringToIndex:5000]; } g_logView.text = newText; NSLog(@"[GlobalMonitor-v8] %@", message); }); }

// UIViewController 分类接口
@interface UIViewController (GlobalMonitorUI)
- (void)setupGlobalMonitorPanel;
@end

%hook UIWindow

// 这是全局事件的入口，绝对会被调用
- (void)sendEvent:(UIEvent *)event {
    // 首先，必须调用原始方法，否则整个App都无法响应触摸
    %orig;

    // 我们只关心触摸事件
    if (event.type == UIEventTypeTouches) {
        // 获取事件中的所有触摸点
        NSSet<UITouch *> *touches = [event allTouches];
        if (touches.count > 0) {
            UITouch *touch = [touches anyObject];

            // 我们只在手指抬起（触摸结束）时进行分析
            if (touch.phase == UITouchPhaseEnded) {
                // 获取触摸点在窗口中的坐标
                CGPoint location = [touch locationInView:self];
                
                // 使用 hitTest 找出这个坐标上最顶层的视图
                UIView *hitView = [self hitTest:location withEvent:event];
                
                if (hitView) {
                    NSMutableString *responderChain = [NSMutableString string];
                    UIResponder *responder = hitView;
                    while(responder) {
                        [responderChain appendFormat:@" -> %@", NSStringFromClass([responder class])];
                        responder = [responder nextResponder];
                    }

                    PanelLog(@"--- TOUCH ENDED ---\n- Clicked View: %@\n- View's Frame: %@\n- Responder Chain:%@\n--------------------",
                             NSStringFromClass([hitView class]),
                             NSStringFromCGRect(hitView.frame),
                             responderChain);
                }
            }
        }
    }
}

%end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupGlobalMonitorPanel];
        });
    }
}

%new
- (void)setupGlobalMonitorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:888999]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 250)];
    panelView.tag = 888999;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor systemYellowColor].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"全局点击监控器 v8";
    titleLabel.textColor = [UIColor systemYellowColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 280, 200)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES;
    g_logView.text = @"监控已自动开始。\n请在App界面上随意点击，本窗口会实时显示您点击到的最顶层视图及其响应链。";
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
