////// Filename: TimeExtractor_for_LRDZ_v3.0.xm
// 描述: 六壬大占App - 时间选择器独立提取脚本 v3.0 (稳定重构版)
// 作者: AI (修复编译错误)
// 功能:
//  - [FIX] 重构了核心拦截逻辑，使用更稳定、更直接的 %hook UIViewController 方式，
//    彻底解决了反复出现的 "%orig does not make sense" 编译错误。
//  - 保留所有v2版本的功能：精确查找UITextView并提取其文本。
//  - 点击按钮后，静默提取时间信息并弹窗显示。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240815; // v3 Tag
static BOOL g_isExtractingTimeInfo = NO;

// 辅助函数：递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
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
// 2. 核心Hook：更稳定、更直接的拦截方式
// =========================================================================

// 直接 Hook UIViewController 的方法，而不是使用 MSHookMessageEx
%hook UIViewController

- (void)presentViewController:(UIViewController *)vcToPresent animated:(BOOL)animated completion:(void (^)(void))completion {
    // 检查是否是我们触发的，并且弹窗类型是否正确
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        
        NSLog(@"[TimeExtractor_v3] 成功拦截到'時間選擇視圖'。");
        g_isExtractingTimeInfo = NO; // 重置标志

        // 创建我们的提取回调
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            UIView *contentView = vcToPresent.view;
            NSMutableArray *textViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITextView class], contentView, textViews);
            
            NSString *finalResult = @"[错误] 未在弹窗中找到UITextView。";
            if (textViews.count > 0) {
                UITextView *mainTextView = textViews.firstObject;
                finalResult = mainTextView.text;
                NSLog(@"[TimeExtractor_v3] 成功从UITextView提取文本:\n%@", finalResult);
            } else {
                NSLog(@"[TimeExtractor_v3] %@", finalResult);
            }
            
            // 显示结果弹窗
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果"
                                                                                       message:finalResult
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = finalResult;
                }]];
                [resultAlert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
                
                // 从 self (也就是当前的 UIViewController) 来呈现结果弹窗
                [self presentViewController:resultAlert animated:YES completion:nil];
            });

            // 关闭后台的、不可见的时间选择器
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
        };

        // 因为我们在一个 %hook 块内部，所以我们使用 %orig 来调用原始方法。
        // 我们让弹窗在后台处理，用户不可见
        %orig(vcToPresent, NO, extractionCompletion);
        return;
    }

    // 如果不是我们想要拦截的弹窗，就正常调用原始方法
    %orig;
}

%end


// =========================================================================
// 3. UI注入与事件处理
// =========================================================================

%hook 六壬大占.ViewController

- (void)viewDidLoad {
    // **重要**: %orig 必须在 %hook 块内的方法里使用，代表“调用原始实现”
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) {
            return;
        }
        
        UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
        extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10, 140, 36);
        extractButton.tag = kTimeExtractorButtonTag;
        [extractButton setTitle:@"时间提取(v3)" forState:UIControlStateNormal];
        extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        extractButton.backgroundColor = [UIColor systemIndigoColor]; // 换个颜色
        [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractButton.layer.cornerRadius = 18;
        
        [extractButton addTarget:self action:@selector(handleTimeExtractTapV3) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:extractButton];
        NSLog(@"[TimeExtractor_v3] “时间提取(v3)”按钮已添加。");
    });
}

// 新增方法：处理按钮点击
%new
- (void)handleTimeExtractTapV3 {
    NSLog(@"[TimeExtractor_v3] “时间提取(v3)”按钮被点击。");
    g_isExtractingTimeInfo = YES;
    
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    
    if ([self respondsToSelector:showTimePickerSelector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showTimePickerSelector];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[TimeExtractor_v3] 错误: 找不到 '顯示時間選擇' 方法。");
        g_isExtractingTimeInfo = NO;
    }
}

%end
