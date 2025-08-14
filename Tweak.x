////// Filename: TimeExtractor_Final.xm
// 描述: 六壬大占App - 时间选择器独立提取脚本 (最终版)
// 目标: 保证编译通过，实现核心提取功能。
// 依据: 根据用户提供的FLEX截图，确认目标控件为UITextView，文本位于其text属性中。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kTimeExtractorButtonTag = 20240815;
static BOOL g_isExtractingTimeInfo = NO;

// 辅助函数：递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
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
    if (g_isExtractingTimeInfo && [NSStringFromClass([vcToPresent class]) containsString:@"時間選擇視圖"]) {
        g_isExtractingTimeInfo = NO;
        
        vcToPresent.view.alpha = 0.0f;
        animated = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }

            // --- 核心提取逻辑 ---
            UIView *contentView = vcToPresent.view;
            NSMutableArray *textViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UITextView class], contentView, textViews);
            
            NSString *finalResult = @"[错误] 未找到任何UITextView。";

            if (textViews.count > 0) {
                UITextView *mainTextView = textViews.firstObject;
                finalResult = mainTextView.text;
            }
            
            // --- 显示结果 ---
            dispatch_async(dispatch_get_main_queue(), ^{
                UIAlertController *resultAlert = [UIAlertController alertControllerWithTitle:@"时间信息提取结果"
                                                                                       message:finalResult
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    [UIPasteboard generalPasteboard].string = finalResult;
                }];
                
                UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
                
                [resultAlert addAction:copyAction];
                [resultAlert addAction:closeAction];
                
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

%hook 六壬大占.ViewController

- (void)viewDidLoad {
    %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow || [keyWindow viewWithTag:kTimeExtractorButtonTag]) {
            return;
        }
        
        UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // 确保按钮位置不会与其他按钮重叠
        extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 36 + 10 + 36 + 10, 140, 36);
        extractButton.tag = kTimeExtractorButtonTag;
        [extractButton setTitle:@"提取时间" forState:UIControlStateNormal];
        extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        extractButton.backgroundColor = [UIColor systemGreenColor];
        [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        extractButton.layer.cornerRadius = 18;
        
        [extractButton addTarget:self action:@selector(handleTimeExtractTap) forControlEvents:UIControlEventTouchUpInside];
        
        [keyWindow addSubview:extractButton];
    });
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
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"错误" message:@"无法调用'顯示時間選擇'方法。" preferredStyle:UIAlertControllerStyleAlert];
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
        %init(六壬大占_ViewController);
        NSLog(@"[TimeExtractor_Final] 脚本已加载。");
    }
}
