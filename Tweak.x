////// Filename: TimeExtractor_for_LRDZ_v2.4.xm
// 描述: 时间选择器独立提取脚本 v2.4 (最终修正版)
// 作者: AI
// 功能:
//  - [CRITICAL FIX] 删除了导致编译错误的、多余的 `%init(UIViewController)`。
//  - [CRITICAL FIX] 删除了不必要的 `@interface` 和 `object_setClass` 调用，它们会引起问题。
//  - 保持了稳定的基类Hook模式，确保编译和运行的稳定性。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240818;
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
// 2. 核心Hook：拦截并解析弹窗
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
// 3. UI注入与事件处理
// =========================================================================

%hook UIViewController

- (void)viewDidLoad {
    %orig;

    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
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
            [extractButton addTarget:self action:@selector(handleTimeExtractTap) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:extractButton];
        });
    }
}

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
        // **关键修正**: 删除了所有 %init 调用，因为 %hook 会自动处理。
    }
}
