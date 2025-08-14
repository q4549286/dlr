////// Filename: TimeExtractor_for_LRDZ_v2.xm
// 描述: 六壬大占App - 时间选择器独立提取脚本 v2.0 (精准版)
// 作者: AI (Based on FLEX analysis)
// 功能:
//  - 根据FLEX分析，确认文本内容位于一个UITextView内。
//  - 新脚本会精确查找UITextView并提取其.text属性。
//  - 点击主界面的“时间提取”按钮，静默调用并解析时间选择弹窗。
//  - 将提取的完整时间信息通过结果弹窗显示，并提供复制功能。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240814; // 新的Tag
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
// 2. 核心Hook：拦截并解析弹窗
// =========================================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    // 检查是否是我们触发的，并且弹窗类型是否正确
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        
        NSLog(@"[TimeExtractor_v2] 成功拦截到'時間選擇視圖'。");
        g_isExtractingTimeInfo = NO;
        
        vcToPresent.view.alpha = 0.0f;
        animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- 精准数据提取逻辑 ---
            UIView *contentView = vcToPresent.view;
            
            // 1. 查找弹窗内的所有 UITextView
            NSMutableArray *textViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITextView class], contentView, textViews);
            
            NSString *finalResult = @"[错误] 未在弹窗中找到UITextView。";

            if (textViews.count > 0) {
                // 通常只有一个主要的TextView，我们取第一个
                UITextView *mainTextView = textViews.firstObject;
                
                // 2. 直接从UITextView的text属性获取所有文本
                finalResult = mainTextView.text;
                NSLog(@"[TimeExtractor_v2] 成功从UITextView提取文本:\n%@", finalResult);
            } else {
                NSLog(@"[TimeExtractor_v2] %@", finalResult);
            }
            
            // 3. 显示结果弹窗
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果"
                                                                                       message:finalResult
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = finalResult;
                    NSLog(@"[TimeExtractor_v2] 结果已复制到剪贴板。");
                }];
                
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
                
                [resultAlert addAction:copyAction];
                [resultAlert addAction:closeAction];
                
                // 从 self (也就是 ViewController) 来呈现结果弹窗
                [self presentViewController:resultAlert animated:YES completion:nil];
            });

            // 4. 关闭后台的、不可见的时间选择器
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
        };

        Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
        return;
    }

    // 如果不是我们想要拦截的弹窗，就执行原始逻辑
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 3. UI注入与事件处理
// =========================================================================

%hook 六壬大占.ViewController

- (void)viewDidLoad {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) {
            return;
        }
        
        UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
        extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10, 140, 36);
        extractButton.tag = kTimeExtractorButtonTag;
        [extractButton setTitle:@"时间提取(v2)" forState:UIControlStateNormal];
        extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        extractButton.backgroundColor = [UIColor colorWithRed:0.8, 0.4, 0.0, 1.0]; // 使用橙色以示区分
        [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractButton.layer.cornerRadius = 18;
        
        [extractButton addTarget:self action:@selector(handleTimeExtractTapV2) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:extractButton];
        NSLog(@"[TimeExtractor_v2] “时间提取(v2)”按钮已添加。");
    });
}

// 新增方法：处理按钮点击
%new
- (void)handleTimeExtractTapV2 {
    NSLog(@"[TimeExtractor_v2] “时间提取(v2)”按钮被点击。");
    g_isExtractingTimeInfo = YES;
    
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    
    if ([self respondsToSelector:showTimePickerSelector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showTimePickerSelector];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[TimeExtractor_v2] 错误: 找不到 '顯示時間選擇' 方法。");
        g_isExtractingTimeInfo = NO;
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"错误" message:@"无法调用时间选择器功能。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
    }
}

%end

// =========================================================================
// 4. 构造函数：应用所有Hook
// =========================================================================

%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        %init(六壬大占_ViewController);
        NSLog(@"[TimeExtractor_v2] 精准提取脚本已加载。");
    }
}
