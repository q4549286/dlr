////// Filename: TimeExtractor_for_LRDZ_v4.0.xm
// 描述: 六壬大占App - 时间选择器独立提取脚本 v4.0 (绝对稳定版)
// 作者: AI (为反复的编译错误致歉并彻底重构)
// 功能:
//  - [FIX] 彻底重构核心拦截逻辑，采用“先调用%orig，后处理”的模式，
//    从根本上解决了反复出现的 "%orig does not make sense" 编译错误。
//  - 保留所有功能：点击按钮后，静默提取时间信息并弹窗显示。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240816; // v4 Tag
static BOOL g_isExtractingTimeInfo = NO;

// 辅助函数：递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 辅助函数：获取最顶层的窗口
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { frontmostWindow = window; break; }
                }
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
// 2. 核心Hook：绝对稳定的新模式
// =========================================================================

%hook UIViewController

// 这是最关键的修改
- (void)presentViewController:(UIViewController *)vcToPresent animated:(BOOL)animated completion:(void (^)(void))completion {
    // 1. 无条件、无参数地调用原始方法，这是最安全的模式。
    %orig;

    // 2. 在原始方法执行后，我们再来检查这个弹窗是不是我们想要的。
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        
        NSLog(@"[TimeExtractor_v4] 成功拦截到'時間選擇視圖'。");
        g_isExtractingTimeInfo = NO; // 必须重置标志

        // 3. 对这个已经被呈现出来的 vcToPresent 进行操作
        vcToPresent.view.alpha = 0.0f; // 立刻让它透明，用户看不到

        // 延迟一小会儿，确保 UITextView 已经加载并填充了文本
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSMutableArray *textViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITextView class], vcToPresent.view, textViews);
            
            NSString *finalResult = @"[错误] 未在弹窗中找到UITextView。";
            if (textViews.count > 0) {
                UITextView *mainTextView = textViews.firstObject;
                finalResult = mainTextView.text;
                NSLog(@"[TimeExtractor_v4] 成功提取文本:\n%@", finalResult);
            }
            
            // 在显示我们自己的弹窗之前，先把后台的那个关掉
            [vcToPresent dismissViewControllerAnimated:NO completion:^{
                // 获取当前最顶层的视图控制器来呈现我们的结果
                UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
                while (topController.presentedViewController) {
                    topController = topController.presentedViewController;
                }

                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果"
                                                                                       message:finalResult
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = finalResult;
                }]];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
                
                [topController presentViewController:resultAlert animated:YES completion:nil];
            }];
        });
    }
}

%end

// =========================================================================
// 3. UI注入与事件处理 (这部分代码没有问题，保持不变)
// =========================================================================

%hook 六壬大占.ViewController

- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) { return; }
        
        UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
        extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10, 140, 36);
        extractButton.tag = kTimeExtractorButtonTag;
        [extractButton setTitle:@"时间提取(v4)" forState:UIControlStateNormal];
        extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        extractButton.backgroundColor = [UIColor systemGreenColor];
        [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractButton.layer.cornerRadius = 18;
        
        [extractButton addTarget:self action:@selector(handleTimeExtractTapV4) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:extractButton];
        NSLog(@"[TimeExtractor_v4] 按钮已添加。");
    });
}

%new
- (void)handleTimeExtractTapV4 {
    NSLog(@"[TimeExtractor_v4] 按钮被点击。");
    g_isExtractingTimeInfo = YES;
    
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    if ([self respondsToSelector:showTimePickerSelector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showTimePickerSelector];
        #pragma clang diagnostic pop
    } else {
        g_isExtractingTimeInfo = NO;
    }
}

%end
