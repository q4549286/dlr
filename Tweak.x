////// Filename: TimeExtractor_for_LRDZ_v2.5.xm
// 描述: 时间选择器独立提取脚本 v2.5 (导航控制器修复版)
// 作者: AI
// 功能:
//  - [CRITICAL FIX] 修复了因目标VC被UINavigationController包装而导致的拦截逻辑失效问题。
//  - 现在会检查被呈现的VC，如果是UINavigationController，则会进一步检查其内部的根VC。
//  - 这是针对“界面正常打开但无后续反应”问题的最终解决方案。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数 (无变化)
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240819;
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
// 2. 核心Hook：拦截并解析弹窗 (关键逻辑修正)
// =========================================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    // 检查是否是我们触发的提取任务
    if (g_isExtractingTimeInfo) {
        // 为了调试，先打印一下弹出的到底是什么类
        NSLog(@"[TimeExtractor] 正在呈现VC: %@", NSStringFromClass([vcToPresent class]));

        // **关键修正开始**
        // 我们的目标内容VC，可能就是vcToPresent本身，也可能在它内部
        UIViewController *contentVC = nil;

        // 判断vcToPresent是不是一个导航控制器
        if ([vcToPresent isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)vcToPresent;
            // 如果是，那么我们的目标就是它管理的第一个VC
            if (nav.viewControllers.count > 0) {
                contentVC = nav.viewControllers.firstObject;
                NSLog(@"[TimeExtractor] 这是一个UINavigationController, 目标内容VC是: %@", NSStringFromClass([contentVC class]));
            }
        } else {
            // 如果不是导航控制器，那么目标就是它自己
            contentVC = vcToPresent;
        }

        // 现在，我们用 contentVC 来判断是不是我们想要的“時間選擇視圖”
        if (contentVC && [NSStringFromClass([contentVC class]) containsString:@"時間選擇視圖"]) {
            // **关键修正结束**

            NSLog(@"[TimeExtractor] 成功匹配到目标VC，开始提取...");
            // 匹配成功！执行静默提取
            g_isExtractingTimeInfo = NO; // 重置标志
            vcToPresent.view.alpha = 0.0f;
            animated = NO;

            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                // 注意：这里要从 contentVC.view 中查找
                UIView *targetView = contentVC.view; 
                NSMutableArray *textViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UITextView class], targetView, textViews);

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
                
                // 关键：关闭的是原始的 vcToPresent (也就是那个UINavigationController)
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            };

            Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
            return;
        }
    }
    
    // 如果不是我们的任务，或者不匹配，就走原始流程
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 3. UI注入与事件处理 (无变化)
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
            [extractButton setTitle:@"时间提取(v2.5)" forState:UIControlStateNormal];
            extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            extractButton.backgroundColor = [UIColor systemOrangeColor];
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
// 4. 构造函数 (无变化)
// =========================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
    }
}
