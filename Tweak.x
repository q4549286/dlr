// Filename: UltimateGlobalMonitor_v10.3 (iOS 13+ Compatible)
// Fixed the deprecated 'keyWindow' call to ensure compatibility with iOS 13 and newer.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h> // Required for MSHookMessageEx

// 全局UI变量
static UITextView *g_logView = nil;

// 统一日志输出
static void PanelLog(NSString *format, ...) { if (!g_logView) return; va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args); dispatch_async(dispatch_get_main_queue(), ^{ NSString *timestamp = [NSDateFormatter localizedStringFromDate:[NSDate date] dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]; NSString *newText = [NSString stringWithFormat:@"[%@] %@\n%@", timestamp, message, g_logView.text]; if (newText.length > 10000) { newText = [newText substringToIndex:10000]; } g_logView.text = newText; NSLog(@"[GlobalMonitor-v10.3] %@", message); }); }

// UIViewController 分类接口 (保持不变)
@interface UIViewController (GlobalMonitorUI)
- (void)setupGlobalMonitorPanel;
@end

// =================================================================
// ============== Low-Level C-Style Hook Implementations ===========
// =================================================================

// For: - (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
static void (*Original_collectionView_didSelectItemAtIndexPath)(id, SEL, UICollectionView *, NSIndexPath *);
static void Tweak_collectionView_didSelectItemAtIndexPath(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath) {
    PanelLog(@"[‼️‼️ 列表项点击 ‼️‼️]\n- collectionView:didSelectItemAtIndexPath:\n- Section: %ld, Item: %ld", (long)indexPath.section, (long)indexPath.item);
    Original_collectionView_didSelectItemAtIndexPath(self, _cmd, collectionView, indexPath);
}

// --- The rest of the C-style hooks remain exactly the same ---

#define DECLARE_HOOK(name, ret, ...) \
    static ret (*Original_##name)(id, SEL, ##__VA_ARGS__); \
    static ret Tweak_##name(id self, SEL _cmd, ##__VA_ARGS__)

DECLARE_HOOK(切換時間模式WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 切換時間模式WithSender:"); Original_切換時間模式WithSender(self, _cmd, sender); }
DECLARE_HOOK(切換行年神煞WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 切換行年神煞WithSender:"); Original_切換行年神煞WithSender(self, _cmd, sender); }
DECLARE_HOOK(切換旬日, void) { PanelLog(@"[‼️ 方法命中 ‼️] 切換旬日"); Original_切換旬日(self, _cmd); }
DECLARE_HOOK(切換晝夜功能, void) { PanelLog(@"[‼️ 方法命中 ‼️] 切換晝夜功能"); Original_切換晝夜功能(self, _cmd); }
DECLARE_HOOK(切回自然晝夜WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 切回自然晝夜WithSender:"); Original_切回自然晝夜WithSender(self, _cmd, sender); }
DECLARE_HOOK(時間流逝With定時器, void, id timer) { PanelLog(@"[‼️ 方法命中 ‼️] 時間流逝With定時器:"); Original_時間流逝With定時器(self, _cmd, timer); }
DECLARE_HOOK(顯示參數設置, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示參數設置"); Original_顯示參數設置(self, _cmd); }
DECLARE_HOOK(顯示法訣總覽, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示法訣總覽"); Original_顯示法訣總覽(self, _cmd); }
DECLARE_HOOK(顯示方法總覽, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示方法總覽"); Original_顯示方法總覽(self, _cmd); }
DECLARE_HOOK(顯示格局總覽, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示格局總覽"); Original_顯示格局總覽(self, _cmd); }
DECLARE_HOOK(顯示九宗門概覽, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示九宗門概覽"); Original_顯示九宗門概覽(self, _cmd); }
DECLARE_HOOK(顯示課傳天將摘要WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示課傳天將摘要WithSender:"); Original_顯示課傳天將摘要WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示課傳摘要WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示課傳摘要WithSender:"); Original_顯示課傳摘要WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示門類選擇, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示門類選擇"); Original_顯示門類選擇(self, _cmd); }
DECLARE_HOOK(顯示七政信息WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示七政信息WithSender:"); Original_顯示七政信息WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示起課選擇, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示起課選擇"); Original_顯示起課選擇(self, _cmd); }
DECLARE_HOOK(顯示三宮時信息WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示三宮時信息WithSender:"); Original_顯示三宮時信息WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示神煞WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示神煞WithSender:"); Original_顯示神煞WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示時間選擇, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示時間選擇"); Original_顯示時間選擇(self, _cmd); }
DECLARE_HOOK(顯示天地盤觸摸WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示天地盤觸摸WithSender:"); Original_顯示天地盤觸摸WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示天地盤長時觸摸WithSender, void, id sender) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示天地盤長時觸摸WithSender:"); Original_顯示天地盤長時觸摸WithSender(self, _cmd, sender); }
DECLARE_HOOK(顯示新增行年視圖, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示新增行年視圖"); Original_顯示新增行年視圖(self, _cmd); }
DECLARE_HOOK(顯示行年總表視圖, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示行年總表視圖"); Original_顯示行年總表視圖(self, _cmd); }
DECLARE_HOOK(顯示占案存課, void) { PanelLog(@"[‼️ 方法命中 ‼️] 顯示占案存課"); Original_顯示占案存課(self, _cmd); }


// =================================================================
// ============== UI部分 和 构造函数 ==============
// =================================================================

// 构造函数：当tweak加载时自动运行
%ctor {
    @autoreleasepool {
        Class targetClass = NSClassFromString(@"六壬大占.ViewController");
        if (targetClass) {
            #define APPLY_HOOK(name, selectorStr) \
                MSHookMessageEx(targetClass, @selector(selectorStr), (IMP)&Tweak_##name, (IMP *)&Original_##name)
            
            // ... All APPLY_HOOK calls remain the same ...
            APPLY_HOOK(collectionView_didSelectItemAtIndexPath, collectionView:didSelectItemAtIndexPath:);
            APPLY_HOOK(切換時間模式WithSender, 切換時間模式WithSender:);
            APPLY_HOOK(切換行年神煞WithSender, 切換行年神煞WithSender:);
            APPLY_HOOK(切換旬日, 切換旬日);
            APPLY_HOOK(切換晝夜功能, 切換晝夜功能);
            APPLY_HOOK(切回自然晝夜WithSender, 切回自然晝夜WithSender:);
            APPLY_HOOK(時間流逝With定時器, 時間流逝With定時器:);
            APPLY_HOOK(顯示參數設置, 顯示參數設置);
            APPLY_HOOK(顯示法訣總覽, 顯示法訣總覽);
            APPLY_HOOK(顯示方法總覽, 顯示方法總覽);
            APPLY_HOOK(顯示格局總覽, 顯示格局總覽);
            APPLY_HOOK(顯示九宗門概覽, 顯示九宗門概覽);
            APPLY_HOOK(顯示課傳天將摘要WithSender, 顯示課傳天將摘要WithSender:);
            APPLY_HOOK(顯示課傳摘要WithSender, 顯示課傳摘要WithSender:);
            APPLY_HOOK(顯示門類選擇, 顯示門類選擇);
            APPLY_HOOK(顯示七政信息WithSender, 顯示七政信息WithSender:);
            APPLY_HOOK(顯示起課選擇, 顯示起課選擇);
            APPLY_HOOK(顯示三宮時信息WithSender, 顯示三宮時信息WithSender:);
            APPLY_HOOK(顯示神煞WithSender, 顯示神煞WithSender:);
            APPLY_HOOK(顯示時間選擇, 顯示時間選擇);
            APPLY_HOOK(顯示天地盤觸摸WithSender, 顯示天地盤觸摸WithSender:);
            APPLY_HOOK(顯示天地盤長時觸摸WithSender, 顯示天地盤長時觸摸WithSender:);
            APPLY_HOOK(顯示新增行年視圖, 顯示新增行年視圖);
            APPLY_HOOK(顯示行年總表視圖, 顯示行年總表視圖);
            APPLY_HOOK(顯示占案存課, 顯示占案存課);
        }
    }
}


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
    // === MODERN, SCENE-AWARE WAY TO GET THE KEY WINDOW ===
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                // In a multi-window app, you might want to find the one that is key
                // For a single-window app, the first active one is usually correct.
                keyWindow = windowScene.windows.firstObject;
                break;
            }
        }
    } else {
        // Fallback for older iOS versions
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    // =======================================================
    
    if (!keyWindow || [keyWindow viewWithTag:888999]) return;

    UIView *panelView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, 370, 400)];
    panelView.tag = 888999;
    panelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    panelView.layer.cornerRadius = 14;
    panelView.layer.borderColor = [UIColor systemTealColor].CGColor; // iOS 13+ compatible version gets Teal
    panelView.layer.borderWidth = 1.5;
    panelView.clipsToBounds = YES;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, 370, 20)];
    titleLabel.text = @"全局监控器 v10.3";
    titleLabel.textColor = [UIColor systemTealColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panelView addSubview:titleLabel];

    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 40, 350, 350)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor whiteColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logView.editable = NO; 
    g_logView.text = @"v10.3已启动：已修复iOS 13+兼容性问题。\n编译现在应该可以成功了！";
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


// We still need the original UIWindow hook to be processed by Logos
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
