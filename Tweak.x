////// Filename: TimeExtractor_for_LRDZ_v2.3.xm
// 描述: 时间选择器独立提取脚本 v2.3 (回归正确模式)
// 作者: AI (Final fix based on user's working script)
// 功能:
//  - [CRITICAL FIX] 采用用户原始脚本中已验证成功的Hook模式：
//      - Hook 通用的 `UIViewController`。
//      - 在 `viewDidLoad` 内部通过 `isKindOfClass` 判断是否为目标VC。
//      - 这彻底解决了所有因直接Hook Swift类名导致的编译错误。
//  - 核心提取逻辑不变。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240817;
static BOOL g_isExtractingTimeInfo = NO;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

// =========================================================================
// 2. 核心Hook：拦截并解析弹窗 (无变化)
// =========================================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        g_isExtractingTimeInfo = NO;
        vcToPresent.view.alpha = 0.0f;
        animated = NO;
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }
            UIView *contentView = vcToPresent.view;
            NSMutableArray *textViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITextView class], contentView, textViews);
            NSString *finalResult = @"[错误] 未在弹窗中找到UITextView。";
            if (textViews.count > 0) {
                finalResult = ((UITextView *)textViews.firstObject).text;
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果" message:finalResult preferredStyle:UIAlertControllerStyleAlert];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { [UIPasteboard generalPasteboard].string = finalResult; }]];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
                // 关键：从 self (即弹窗的 presentingViewController) 来呈现结果
                [self presentViewController:resultAlert animated:YES completion:nil];
            });
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
        };
        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
        return;
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 3. UI注入与事件处理 (采用您的成功模式)
// =========================================================================

// 在 `UIViewController` 中声明新方法，以便所有子类都可以潜在地使用它
// 这样可以确保在 addTarget 时，编译器知道这个方法的存在
@interface UIViewController (TimeExtractor)
- (void)handleTimeExtractTap;
@end

%hook UIViewController

// **关键修改**: Hook 通用基类 UIViewController
- (void)viewDidLoad {
    %orig; // 调用原始 viewDidLoad

    // **关键修改**: 使用运行时判断来定位目标 ViewController
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        
        // 使用 self (即 ViewController 实例) 来定义新方法
        // 这是为了让 handleTimeExtractTap 能访问到 self
        object_setClass(self, [self class]); // 确保 self 的 class 是可修改的

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) {
                return;
            }
            UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10, 140, 36);
            extractButton.tag = kTimeExtractorButtonTag;
            [extractButton setTitle:@"时间提取(Final)" forState:UIControlStateNormal];
            extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            extractButton.backgroundColor = [UIColor systemGreenColor];
            [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractButton.layer.cornerRadius = 18;
            // self 在这里就是 `六壬大占.ViewController` 的实例，可以安全地添加 target
            [extractButton addTarget:self action:@selector(handleTimeExtractTap) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:extractButton];
        });
    }
}

// 新增方法的实现
%new
- (void)handleTimeExtractTap {
    g_isExtractingTimeInfo = YES;
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    if ([self respondsToSelector:showTimePickerSelector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showTimePickerSelector];
        #pragma clang diagnostic pop
    } else {
        g_isExtractingTimeInfo = NO;
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"错误" message:@"无法调用时间选择器功能。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

%end

// =========================================================================
// 4. 构造函数
// =========================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        // 不再需要 %init(六壬大占_ViewController)，因为我们 hook 了它的基类
        %init(UIViewController);
        NSLog(@"[TimeExtractor_v2.3] 已加载，采用稳定的基类Hook模式。");
    }
}
