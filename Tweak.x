#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V2] " format), ##__VA_ARGS__)

// =========================================================================
// Section: 【V3 方案精准测试】直接从数据模型提取“法诀”字符串
// =========================================================================

// 用于标记我们的测试任务是否正在进行
static BOOL g_isTestTaskRunning = NO;

@interface UIViewController (BiFaExtraction_Test)
- (void)copyBiFaOnlyButtonTapped_TestAction;
@end


%hook UIViewController

// 在主界面添加一个“只复制法诀”的测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            NSInteger buttonTag = 445566; 
            if (!keyWindow || [keyWindow viewWithTag:buttonTag]) { return; } // 防止重复添加
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45 + 40, 90, 36);
            testButton.tag = buttonTag;
            [testButton setTitle:@"测试复制法诀" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
            testButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.1 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(copyBiFaOnlyButtonTapped_TestAction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            EchoLog(@"测试按钮已添加");
        });
    }
}

// 拦截弹窗的核心逻辑
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (!g_isTestTaskRunning) {
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
    
    if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
        EchoLog(@"成功拦截到目标控制器: %@", vcClassName);
        
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            id biFaData = [viewControllerToPresent valueForKey:@"法訣列"];
            NSString *resultText = @"";
            
            if (biFaData && [biFaData isKindOfClass:[NSString class]]) {
                resultText = (NSString *)biFaData;
                EchoLog(@"成功从数据模型获取到法诀字符串，长度: %lu", (unsigned long)resultText.length);
            } else {
                NSString *errorMsg = [NSString stringWithFormat:@"提取失败：'法訣列' 数据类型不符或为空。实际类型: %@", [biFaData class]];
                EchoLog(@"%@", errorMsg);
                resultText = errorMsg;
            }

            [UIPasteboard generalPasteboard].string = resultText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"法诀提取测试 (精准版)"
                                                                           message:resultText
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                g_isTestTaskRunning = NO;
                EchoLog(@"测试任务结束。");
            }]];
            
            // =========================================================
            //  ↓↓↓ 这里是修改后的代码 ↓↓↓
            // =========================================================
            UIWindow *window = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
                    if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                        window = windowScene.windows.firstObject;
                        break;
                    }
                }
            } else {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                window = [[UIApplication sharedApplication] keyWindow];
                #pragma clang diagnostic pop
            }
            if (!window) { // Fallback
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                window = [[UIApplication sharedApplication] keyWindow];
                #pragma clang diagnostic pop
            }
            // =========================================================
            //  ↑↑↑ 这里是修改后的代码 ↑↑↑
            // =========================================================
            
            [window.rootViewController presentViewController:alert animated:YES completion:nil];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        
        %orig(viewControllerToPresent, flag, completion);
        return;
    }

    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)copyBiFaOnlyButtonTapped_TestAction {
    EchoLog(@"测试按钮被点击，开始执行测试任务...");
    
    g_isTestTaskRunning = YES;
    
    SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
    if ([self respondsToSelector:selectorBiFa]) {
        EchoLog(@"正在调用 '顯示法訣總覽' 方法...");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selectorBiFa withObject:nil];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误：在 %@ 上未找到方法 '顯示法訣總覽'", [self class]);
        g_isTestTaskRunning = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败"
                                                                       message:@"无法找到App内部的法诀显示方法。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

%end
