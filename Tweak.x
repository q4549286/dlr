// Filename: UltimateGlobalMonitor_v10 (全面监控版)
// 终极版！监控你日志中列出的所有可疑方法。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) { if (!g_logView) return; va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]; NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text]; if (newText.length > 10000) { newText = [newText substringToIndex:10000]; } g_logView.text = newText; NSLog(@"[GlobalMonitor-v10] %@", message); }); }

// UIViewController 分类接口 (保持不变)
@interface UIViewController (GlobalMonitorUI)
- (void)setupGlobalMonitorPanel;
@end

// 原始的事件监控 (保持不变)
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    %orig;
    if (event.type == UIEventTypeTouches) {
        NSSet<UITouch *> *touches = [event allTouches];
        if (touches.count > 0 && [touches anyObject].phase == UITouchPhaseEnded) {
            UITouch *touch = [touches anyObject];
            UIView *hitView = [touch.view hitTest:[touch locationInView:touch.view] withEvent:event];
            if (hitView) {
                // ... 省略响应链日志以保持界面整洁 ...
            }
        }
    }
}
%end


// =================================================================
// ==================== 全面方法拦截陷阱 ==========================
// =================================================================

%hook @"六壬大占.ViewController"

// --- 已有的核心陷阱 ---
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PanelLog(@"[‼️‼️ 列表项点击 ‼️‼️]\n- collectionView:didSelectItemAtIndexPath:\n- Section: %ld, Item: %ld", (long)indexPath.section, (long)indexPath.item);
    %orig;
}

// --- 根据你的完整列表，新增所有可疑方法的陷阱 ---

- (void)切換時間模式WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 切換時間模式WithSender:");
    %orig(sender);
}

- (void)切換行年神煞WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 切換行年神煞WithSender:");
    %orig(sender);
}

- (void)切換旬日 {
    PanelLog(@"[‼️ 方法命中 ‼️] 切換旬日");
    %orig;
}

- (void)切換晝夜功能 {
    PanelLog(@"[‼️ 方法命中 ‼️] 切換晝夜功能");
    %orig;
}

- (void)切回自然晝夜WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 切回自然晝夜WithSender:");
    %orig(sender);
}

- (void)時間流逝With定時器:(id)timer {
    PanelLog(@"[‼️ 方法命中 ‼️] 時間流逝With定時器:");
    %orig(timer);
}

- (void)顯示參數設置 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示參數設置");
    %orig;
}

- (void)顯示法訣總覽 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示法訣總覽");
    %orig;
}

- (void)顯示方法總覽 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示方法總覽");
    %orig;
}

- (void)顯示格局總覽 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示格局總覽");
    %orig;
}

- (void)顯示九宗門概覽 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示九宗門概覽");
    %orig;
}

- (void)顯示課傳天將摘要WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示課傳天將摘要WithSender:");
    %orig(sender);
}

- (void)顯示課傳摘要WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示課傳摘要WithSender:");
    %orig(sender);
}

- (void)顯示門類選擇 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示門類選擇");
    %orig;
}

- (void)顯示七政信息WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示七政信息WithSender:");
    %orig(sender);
}

- (void)顯示起課選擇 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示起課選擇");
    %orig;
}

- (void)顯示三宮時信息WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示三宮時信息WithSender:");
    %orig(sender);
}

- (void)顯示神煞WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示神煞WithSender:");
    %orig(sender);
}

- (void)顯示時間選擇 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示時間選擇");
    %orig;
}

- (void)顯示天地盤觸摸WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示天地盤觸摸WithSender:");
    %orig(sender);
}

- (void)顯示天地盤長時觸摸WithSender:(id)sender {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示天地盤長時觸摸WithSender:");
    %orig(sender);
}

- (void)顯示新增行年視圖 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示新增行年視圖");
    %orig;
}

- (void)顯示行年總表視圖 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示行年總表視圖");
    %orig;
}

- (void)顯示占案存課 {
    PanelLog(@"[‼️ 方法命中 ‼️] 顯示占案存課");
    %orig;
}

%end


// =================================================================
// ==================== UI部分 (升级到v10) =======================
// =================================================================

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
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (!keyWindow || [keyWindow viewWithTag:888999]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 370, 400)]; // 面板加大
    panelView.tag = 888999;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    panelView.layer.cornerRadius = 14;
    panelView.layer.borderColor = [UIColor systemRedColor].CGColor; // 终极版用红色
    panelView.layer.borderWidth = 1.5;
    panelView.clipsToBounds = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 370, 20)];
    titleLabel.text = @"全局监控器 v10 - 全面监控";
    titleLabel.textColor = [UIColor systemRedColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 350, 350)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logView.editable = NO; 
    g_logView.text = @"v10已启动：全面监控模式！\n请在App上进行任何操作，下方将显示所有命中的方法调用。";
    g_logView.layer.cornerRadius = 5;
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
