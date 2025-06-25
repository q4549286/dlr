// Filename: UltimateShotgunMonitor_v12.3_FinalFixed.x

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
        NSLog(@"[ShotgunMonitor-v12.3] %@", message);
    });
}

// UIViewController 分类接口
@interface UIViewController (ShotgunMonitorUI)
- (void)setupShotgunMonitorPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
@end

// ========================================================
// 核心Hook：广撒网，Hook所有可疑方法
// ========================================================
%hook 六壬大占.ViewController

// *** FIX: Corrected ALL method signatures AGAIN, with extreme care ***

- (void)切換時間模式WithSender:(id)sender {
    PanelLog(@"方法被调用: 切換時間模式WithSender:");
    %orig;
}
- (void)切換行年神煞WithSender:(id)sender {
    PanelLog(@"方法被调用: 切換行年神煞WithSender:");
    %orig;
}
- (void)切換旬日:(id)sender { // *** FIX: Assuming this one also needs a sender ***
    PanelLog(@"方法被调用: 切換旬日:");
    %orig;
}
- (void)切換晝夜功能 {
    PanelLog(@"方法被调用: 切換晝夜功能");
    %orig;
}
- (void)切回自然晝夜WithSender:(id)sender {
    PanelLog(@"方法被调用: 切回自然晝夜WithSender:");
    %orig;
}
- (void)時間流逝With定時器:(id)timer {
    PanelLog(@"方法被调用: 時間流逝With定時器:");
    %orig;
}

- (void)顯示參數設置 {
    PanelLog(@"方法被调用: 顯示參數設置");
    %orig;
}
- (void)顯示法訣總覽 {
    PanelLog(@"方法被调用: 顯示法訣總覽");
    %orig;
}
- (void)顯示方法總覽 {
    PanelLog(@"方法被调用: 顯示方法總覽");
    %orig;
}
- (void)顯示格局總覽 {
    PanelLog(@"方法被调用: 顯示格局總覽");
    %orig;
}
- (void)顯示九宗門概覽 {
    PanelLog(@"方法被调用: 顯示九宗門概覽");
    %orig;
}
- (void)顯示課傳天將摘要WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示課傳天將摘要WithSender:");
    %orig;
}
- (void)顯示課傳摘要WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示課傳摘要WithSender:");
    %orig;
}
- (void)顯示門類選擇 {
    PanelLog(@"方法被调用: 顯示門類選擇");
    %orig;
}
- (void)顯示七政信息WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示七政信息WithSender:");
    %orig;
}
- (void)顯示起課選擇 {
    PanelLog(@"方法被调用: 顯示起課選擇");
    %orig;
}
- (void)顯示三宮時信息WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示三宮時信息WithSender:");
    %orig;
}
- (void)顯示神煞WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示神煞WithSender:");
    %orig;
}
- (void)顯示時間選擇 {
    PanelLog(@"方法被调用: 顯示時間選擇");
    %orig;
}
- (void)顯示天地盤觸摸WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示天地盤觸摸WithSender:");
    %orig;
}
- (void)顯示天地盤長時觸摸WithSender:(id)sender {
    PanelLog(@"方法被调用: 顯示天地盤長時觸摸WithSender:");
    %orig;
}
- (void)顯示新增行年視圖 {
    PanelLog(@"方法被调用: 顯示新增行年視圖");
    %orig;
}
- (void)顯示行年總表視圖 {
    PanelLog(@"方法被调用: 顯示行年總表視圖");
    %orig;
}
- (void)顯示占案存課 {
    PanelLog(@"方法被调用: 顯示占案存課");
    %orig;
}

%end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupShotgunMonitorPanel];
        });
    }
}

%new
- (void)setupShotgunMonitorPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:121212]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 300, 250)];
    panelView.tag = 121212;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    panelView.layer.cornerRadius = 10;
    panelView.layer.borderColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.5 alpha:1.0].CGColor;
    panelView.layer.borderWidth = 1.5;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 300, 20)];
    titleLabel.text = @"广撒网监控器 v12.3";
    titleLabel.textColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.5 alpha:1.0];
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
