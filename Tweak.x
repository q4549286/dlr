// Filename: JiuZongMen_Hunter_v1.0
// 专门用于侦测“九宗门”相关信息（方法名、弹窗类名）的脚本。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static UITextView *g_logView_JZM = nil; // 使用带后缀的独立全局变量

// 统一日志函数
static void LogMessage_JZM(NSString *format, ...) {
    if (!g_logView_JZM) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        g_logView_JZM.text = [NSString stringWithFormat:@"%@%@\n%@", logPrefix, message, g_logView_JZM.text];
        NSLog(@"[JiuZongMen_Hunter] %@", message);
    });
}


// =================================================================
// 2. 核心监控逻辑 (Hooks)
// =================================================================

// --- 监控 #1: 拦截所有弹窗，找出它的类名 ---
static void (*Original_presentViewController_JZM)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController_JZM(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    LogMessage_JZM(@"[‼️ 关键发现 ‼️] 正在弹出一个新窗口。");
    LogMessage_JZM(@"[关键] 新窗口的类名是: %@", NSStringFromClass([vcToPresent class]));
    LogMessage_JZM(@"---------------------------------");
    Original_presentViewController_JZM(self, _cmd, vcToPresent, animated, completion);
}

// --- 监控 #2: 拦截我们猜测的目标方法 ---
static void (*Original_顯示九宗門概覽)(id, SEL);
static void Tweak_顯示九宗門概覽(id self, SEL _cmd) {
    LogMessage_JZM(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示九宗門概覽");
    Original_顯示九宗門概覽(self, _cmd);
}


// =================================================================
// 3. UI界面 和 启动逻辑
// =================================================================

@interface UIViewController (JiuZongMenHunter)
- (void)setupJiuZongMenHunterPanel;
- (void)handlePanelPan_JZM:(UIPanGestureRecognizer *)recognizer;
@end

%hook UIViewController

// 我们在原来的 viewDidLoad hook 里增加一个新的调用
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 延迟执行，确保UI已加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupJiuZongMenHunterPanel];
        });
    }
}

%new
- (void)setupJiuZongMenHunterPanel {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) { keyWindow = scene.windows.firstObject; break; }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow || [keyWindow viewWithTag:998822]) return;

    // 将侦测窗口放在右下角，避免遮挡
    CGFloat panelWidth = 320;
    CGFloat panelHeight = 250;
    CGFloat xPos = keyWindow.bounds.size.width - panelWidth - 20;
    CGFloat yPos = keyWindow.bounds.size.height - panelHeight - 40;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, panelWidth, panelHeight)];
    panel.tag = 998822;
    panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    panel.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemCyanColor].CGColor;
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, panelWidth, 20)];
    titleLabel.text = @"九宗门侦测器 v1.0";
    titleLabel.textColor = [UIColor systemCyanColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];
    
    g_logView_JZM = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, panelWidth - 20, panelHeight - 60)];
    g_logView_JZM.backgroundColor = [UIColor blackColor];
    g_logView_JZM.textColor = [UIColor systemCyanColor];
    g_logView_JZM.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView_JZM.editable = NO;
    g_logView_JZM.layer.cornerRadius = 5;
    g_logView_JZM.text = @"侦测器已就绪。\n\n请手动点击App中的“九宗门”，然后观察本窗口的输出。";
    [panel addSubview:g_logView_JZM];
    
    // 增加拖动手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan_JZM:)];
    [panel addGestureRecognizer:pan];
    
    [keyWindow addSubview:panel];
}

%new
- (void)handlePanelPan_JZM:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%end


// =================================================================
// 4. 构造函数，应用所有监控
// =================================================================

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            // 拦截弹窗方法
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController_JZM, (IMP *)&Original_presentViewController_JZM);
            
            // 拦截我们猜测的“显示九宗门”方法
            MSHookMessageEx(vcClass, @selector(顯示九宗門概覽), (IMP)&Tweak_顯示九宗門概覽, (IMP *)&Original_顯示九宗門概覽);
            
            NSLog(@"[JiuZongMen_Hunter] 九宗门侦测器已准备就绪。");
        }
    }
}
