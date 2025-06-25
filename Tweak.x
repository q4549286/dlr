// Filename: InfoHunter_v1.2 (编译修复版)
// 修复了宏定义和ARC内存管理导致的编译错误。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =================================================================
// 1. 全局变量与辅助函数
// =================================================================

static UITextView *g_logView = nil; // 日志窗口

// 统一日志函数
static void LogMessage(NSString *format, ...) {
    if (!g_logView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logView.text];
        NSLog(@"[InfoHunter] %@", message);
    });
}


// =================================================================
// 2. 核心监控逻辑 (Hooks)
// =================================================================

// --- 监控 #1: 拦截所有弹窗 (保持不变) ---
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    LogMessage(@"[‼️ 关键发现 ‼️] 正在弹出一个新窗口。");
    LogMessage(@"[关键] 新窗口的类名是: %@", NSStringFromClass([vcToPresent class]));
    LogMessage(@"---------------------------------");
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// --- 监控 #2: 确认点击事件的触发方法 (保持不变) ---
static void (*Original_collectionView_didSelectItemAtIndexPath)(id, SEL, UICollectionView *, NSIndexPath *);
static void Tweak_collectionView_didSelectItemAtIndexPath(id self, SEL _cmd, UICollectionView *collectionView, NSIndexPath *indexPath) {
    LogMessage(@"[事件] collectionView:didSelectItemAtIndexPath: 被触发 (Item: %ld)", (long)indexPath.item);
    Original_collectionView_didSelectItemAtIndexPath(self, _cmd, collectionView, indexPath);
}

// --- 监控 #3: 全面拦截所有可疑的“显示”方法 (核心升级！已移除宏) ---
// 为每个方法编写完整的hook，避免宏带来的编译问题。

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
// 3. UI界面 和 启动逻辑
// =================================================================

@interface UIViewController (InfoHunter)
- (void)setupHunterPanel;
- (void)closeHunterPanel;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupHunterPanel];
        });
    }
}

%new
- (void)setupHunterPanel {
    UIWindow *keyWindow = self.view.window;
    if (!keyWindow || [keyWindow viewWithTag:998811]) return;

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(20, 100, 350, 400)];
    panel.tag = 998811;
    panel.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.92];
    panel.layer.cornerRadius = 12;
    panel.layer.borderColor = [UIColor systemBlueColor].CGColor; // 修复版用蓝色
    panel.layer.borderWidth = 1.5;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 350, 20)];
    titleLabel.text = @"方法嗅探器 v1.2";
    titleLabel.textColor = [UIColor systemBlueColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [panel addSubview:titleLabel];
    
    g_logView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, panel.bounds.size.width - 20, panel.bounds.size.height - 60)];
    g_logView.backgroundColor = [UIColor blackColor];
    g_logView.textColor = [UIColor systemBlueColor];
    g_logView.font = [UIFont fontWithName:@"Menlo" size:11];
    g_logView.editable = NO;
    g_logView.layer.cornerRadius = 5;
    g_logView.text = @"方法嗅探器已就绪。\n\n请手动点击'课体'，然后观察日志，寻找 [⭐️ 方法命中! ⭐️] 这条记录。";
    [panel addSubview:g_logView];

    // 修复ARC错误：直接创建，不要调用 retain
    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.frame = CGRectMake(panel.bounds.size.width - 50, 5, 40, 40);
    [closeButton setTitle:@"X" forState:UIControlStateNormal];
    [closeButton.titleLabel setFont:[UIFont boldSystemFontOfSize:20]];
    [closeButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
    [closeButton addTarget:self action:@selector(closeHunterPanel) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:closeButton];
}

%new
- (void)closeHunterPanel {
    UIView *panel = [self.view.window viewWithTag:998811];
    if (panel) {
        [panel removeFromSuperview];
    }
    g_logView = nil;
}

%end


// =================================================================
// 4. 构造函数，应用所有监控
// =================================================================

%ctor {
    @autoreleasepool {
        Class vcClass = NSClassFromString(@"六壬大占.ViewController");
        if (vcClass) {
            MSHookMessageEx(vcClass, @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
            MSHookMessageEx(vcClass, @selector(collectionView:didSelectItemAtIndexPath:), (IMP)&Tweak_collectionView_didSelectItemAtIndexPath, (IMP *)&Original_collectionView_didSelectItemAtIndexPath);
            
            // 应用所有“显示”方法的hook
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
