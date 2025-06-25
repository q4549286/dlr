// Filename: UltimateRuntimeMonitor_v13_Final.x

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
        NSLog(@"[RuntimeMonitor-v13] %@", message);
    });
}

// 这是我们统一的监控实现。所有被交换的方法都会调用这里。
// IMP是C函数指针，代表一个方法的具体实现
static void MyUniversalMonitorImplementation(id self, SEL _cmd, id sender) {
    // _cmd 变量包含了被调用的原始方法名 (SEL)
    PanelLog(@"方法被调用: %@", NSStringFromSelector(_cmd));
    
    // 我们需要调用原始的实现，但因为我们交换了它，
    // 所以再次调用 [self performSelector:_cmd] 会导致死循环。
    // 在这个纯监控脚本里，我们可以暂时不调用原始实现，
    // 因为我们只想知道是哪个方法被调用了。
    // 如果App崩溃或行为异常，说明必须调用原始方法。
    // 但为了找到函数名，这一步是值得的。
}

// UIViewController 分类接口
@interface UIViewController (RuntimeMonitorUI)
- (void)setupRuntimeMonitorPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end


// ========================================================
// 核心Hook：只Hook一个安全的方法
// ========================================================
%hook 六壬大占.ViewController

// 我们只hook viewDidLoad，这是100%安全且会被调用的
- (void)viewDidLoad {
    %orig;

    // 为了防止重复交换，使用 dispatch_once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        PanelLog(@"ViewController did load. Preparing to swizzle methods...");
        
        // 我们要监控的方法列表
        NSArray<NSString *> *selectorsToSwizzle = @[
            @"切換時間模式WithSender:", @"切換行年神煞WithSender:", @"切換旬日",
            @"切換晝夜功能", @"切回自然晝夜WithSender:", @"時間流逝With定時器:",
            @"顯示參數設置", @"顯示法訣總覽", @"顯示方法總覽", @"顯示格局總覽",
            @"顯示九宗門概覽", @"顯示課傳天將摘要WithSender:", @"顯示課傳摘要WithSender:",
            @"顯示門類選擇", @"顯示七政信息WithSender:", @"顯示起課選擇",
            @"顯示三宮時信息WithSender:", @"顯示神煞WithSender:", @"顯示時間選擇",
            @"顯示天地盤觸摸WithSender:", @"顯示天地盤長時觸摸WithSender:",
            @"顯示新增行年視圖", @"顯示行年總表視圖", @"顯示占案存課"
        ];
        
        Class targetClass = [self class];
        
        for (NSString *selectorString in selectorsToSwizzle) {
            SEL originalSelector = NSSelectorFromString(selectorString);
            
            // 检查类是否真的有这个方法，防止崩溃
            if ([targetClass instancesRespondToSelector:originalSelector]) {
                Method originalMethod = class_getInstanceMethod(targetClass, originalSelector);
                // 将原始方法替换为我们的通用监控实现
                method_setImplementation(originalMethod, (IMP)MyUniversalMonitorImplementation);
                PanelLog(@"Swizzled: %@", selectorString);
            } else {
                 PanelLog(@"Warning: Method not found, skipped: %@", selectorString);
            }
        }
    });
    
    // 创建UI面板
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupRuntimeMonitorPanel];
    });
}

%end


%hook UIViewController
%new
- (void)setupRuntimeMonitorPanel {
    // 检查是否是目标VC，避免在其他VC上创建
    if (![self isKindOfClass:NSClassFromString(@"六壬大占.ViewController")]) {
        return;
    }
    
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:131313]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 250)];
    panelView.tag = 131313;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor systemPurpleColor].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"运行时监控器 v13";
    titleLabel.textColor = [UIColor systemPurpleColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 280, 200)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = YES;
    g_logView.text = @"监控已自动开始。\n请点击App界面上的“课体”区域，任何被调用的相关方法都会记录在此。";
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
