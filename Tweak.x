// Filename: InfoHunter_v1.4 (窗口可拖动版)
// 将窗口移到右下角，并增加了拖动功能，解决了遮挡问题。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static UITextView *g_logView = nil; // 日志窗口

// 统一日志函数
static void LogMessage(NSString *format, ...) {
    NSString *message;
    va_list args;
    va_start(args, format);
    message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    // 打印到Xcode控制台，用于诊断
    NSLog(@"[InfoHunter-Diag] %@", message);

    if (!g_logView) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logView.text];
    });
}


// =================================================================
// 2. 核心监控逻辑 (Hooks) - (保持不变)
// =================================================================

// --- 监控 #1: 拦截所有弹窗 ---
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    LogMessage(@"[‼️ 关键发现 ‼️] 正在弹出一个新窗口。");
    LogMessage(@"[关键] 新窗口的类名是: %@", NSStringFromClass([vcToPresent class]));
    LogMessage(@"---------------------------------");
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// --- 监控 #2: 确认点击事件的触发方法 ---
static void (*Original_collectionView_didSelectItemAtIndexPath)(id, SEL, UICollectionView *, NSIndexPath *);
static void Tweak_collectionView_didSelectItemAtIndexPath(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath) {
    LogMessage(@"[事件] collectionView:didSelectItemAtIndexPath: 被触发 (Item: %ld)", (long)indexPath.item);
    Original_collectionView_didSelectItemAtIndexPath(self, _cmd, collectionView, indexPath);
}

// --- 监控 #3: 全面拦截所有可疑的“显示”方法 ---
static void (*Original_顯示課傳天將摘要WithSender)(id, SEL, id);
static void Tweak_顯示課傳天將摘要WithSender(id self, SEL _cmd, id sender) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示課傳天將摘要WithSender:");
    Original_顯示課傳天將摘要WithSender(self, _cmd, sender);
}

static void (*Original_顯示課傳摘要WithSender)(id, SEL, id);
static void Tweak_顯示課傳摘要WithSender(id self, SEL _cmd, id sender) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示課傳摘要WithSender:");
    Original_顯示課傳摘要WithSender(self, _cmd, sender);
}

static void (*Original_顯示法訣總覽)(id, SEL);
static void Tweak_顯示法訣總覽(id self, SEL _cmd) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示法訣總覽");
    Original_顯示法訣總覽(self, _cmd);
}

static void (*Original_顯示格局總覽)(id, SEL);
static void Tweak_顯示格局總覽(id self, SEL _cmd) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示格局總覽");
    Original_顯示格局總覽(self, _cmd);
}

static void (*Original_顯示方法總覽)(id, SEL);
static void Tweak_顯示方法總覽(id self, SEL _cmd) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示方法總覽");
    Original_顯示方法總覽(self, _cmd);
}

static void (*Original_顯示七政信息WithSender)(id, SEL, id);
static void Tweak_顯示七政信息WithSender(id self, SEL _cmd, id sender) {
    LogMessage(@"[⭐️ 方法命中! ⭐️] 调用的方法是: 顯示七政信息WithSender:");
    Original_顯示七政信息WithSender(self, _cmd, sender);
}


// =================================================================
// 3. UI界面 和 启动逻辑 (核心修复)
// =================================================================

@interface UIViewController (InfoHunter)
- (void)setupHunterPanel;
- (void)closeHunterPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer; // 新增拖动方法
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (!targetClass) {
        NSLog(@"[InfoHunter-Diag] 致命错误: 找不到 '六壬大占.ViewController' 这个类。");
        return;
    }

    if ([self isKindOfClass:targetClass]) {
        NSLog(@"[InfoHunter-Diag] 成功进入目标ViewController: %@", self);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupHunterPanel];
        });
    }
}

%new
- (void)setupHunterPanel {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = windowScene.windows.firstObject;
                break;
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }

    if (!keyWindow) {
        NSLog(@"[InfoHunter-Diag] UI创建失败: 找不到可用的 keyWindow。");
        return;
    }
    
    if ([keyWindow viewWithTag:998811]) {
        return;
    }
    
    NSLog(@"[InfoHunter-Diag] 成功找到 keyWindow，正在创建UI面板...");

    // --- 核心修改：调整窗口大小和位置到右下角 ---
    CGFloat panelWidth = 320;
    CGFloat panelHeight = 250;
    CGFloat xPos = keyWindow.bounds.size.width - panelWidth - 20; // 离右边20
    CGFloat yPos = keyWindow.bounds.size.height - panelHeight - 40; // 离下边40
    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(xPos, yPos, panelWidth, panelHeight)];
    panel.tag = 998811;
    panel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    panel.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemPurpleColor].CGColor; // 可拖动版用紫色
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, panelWidth, 20)];
    titleLabel.text = @"方法嗅探器 v1.4";
    titleLabel.textColor = [UIColor systemPurpleColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, panelWidth - 20, panelHeight - 60)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor systemPurpleColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"UI位置已调整！\n\n1. 请点击'课体'。\n2. 观察日志中的[⭐️方法命中]。\n3. 你可以按住此窗口进行拖动。";
    [panel addSubview:g_logView];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(panelWidth - 50, 5, 40, 40);
    [closeButton setTitle:@"X" forState:UIControlStateNormal];
    [closeButton.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
    [closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeHunterPanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeButton];
    
    // --- 新增：为面板增加拖动手势 ---
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [panel addGestureRecognizer:pan];
    
    [keyWindow addSubview:panel];
    NSLog(@"[InfoHunter-Diag] UI面板已成功添加到窗口。");
}

%new
- (void)closeHunterPanel {
    UIView *panel = [self.view.window viewWithTag:998811];
    if (panel) {
        [panel removeFromSuperview];
    }
    g_logView = nil;
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%end


// =================================================================
// 4. 构造函数，应用所有监控 (保持不变)
// =================================================================

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            MSHookMessageEx(vcClass, @selector(collectionView:didSelectItemAtIndexPath:), (IMP)&Tweak_collectionView_didSelectItemAtIndexPath, (IMP *)&Original_collectionView_didSelectItemAtIndexPath);
            
            #define APPLY_HOOK(name, selectorStr) MSHookMessageEx(vcClass, @selector(selectorStr), (IMP)&Tweak_##name, (IMP *)&Original_##name)
            
            APPLY_HOOK(顯示課傳天將摘要WithSender, 顯示課傳天將摘要WithSender:);
            APPLY_HOOK(顯示課傳摘要WithSender, 顯示課傳摘要WithSender:);
            APPLY_HOOK(顯示法訣總覽, 顯示法訣總覽);
            APPLY_HOOK(顯示格局總覽, 顯示格局總覽);
            APPLY_HOOK(顯示方法總覽, 顯示方法總覽);
            APPLY_HOOK(顯示七政信息WithSender, 顯示七政信息WithSender:);
        }
    }
}
