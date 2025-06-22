#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// 辅助函数：递归查找当前显示的顶层 ViewController
static UIViewController* getTopMostViewController() {
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
    
    UIViewController *topViewController = window.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    return topViewController;
}


@interface UIViewController (BiFaExtraction_Debug)
- (void)debug_readBiFaData;
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
            if ([keyWindow viewWithTag:buttonTag]) { return; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45 + 40, 90, 36);
            testButton.tag = buttonTag;
            [testButton setTitle:@"读取已打开法诀" forState:UIControlStateNormal]; // 按钮文字改了
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:11];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.2 alpha:1.0]; // 按钮颜色改成绿色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            // 按钮点击事件改成了新的调试方法
            [testButton addTarget:self action:@selector(debug_readBiFaData) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            EchoLog(@"调试按钮已添加");
        });
    }
}

// 我们暂时不 hook presentViewController，以避免崩溃
// - (void)presentViewController... { ... }

%new
- (void)debug_readBiFaData {
    EchoLog(@"开始执行'读取已打开法诀'调试任务...");

    // 1. 手动点击App的“法诀”按钮，让它弹出来

    // 2. 点击我们绿色的“读取已打开法诀”按钮
    
    // 3. 找到当前屏幕最上方的 ViewController
    UIViewController *topVC = getTopMostViewController();
    
    NSString *vcClassName = NSStringFromClass([topVC class]);
    EchoLog(@"当前顶层控制器是: %@", vcClassName);
    
    // 4. 检查它是不是我们想要的控制器
    if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
        EchoLog(@"成功找到目标控制器，准备读取数据...");
        
        NSString *resultText = @"";
        @try {
            // 尝试用 KVC 读取数据
            id biFaData = [topVC valueForKey:@"法訣列"];
            
            if (biFaData && [biFaData isKindOfClass:[NSString class]]) {
                resultText = (NSString *)biFaData;
                EchoLog(@"成功读取到法诀字符串，长度: %lu", (unsigned long)resultText.length);
            } else {
                resultText = [NSString stringWithFormat:@"读取成功，但数据类型不符或为空。实际类型: %@", [biFaData class]];
                EchoLog(@"%@", resultText);
            }
        } @catch (NSException *exception) {
            EchoLog(@"!!! 读取数据时发生异常: %@", exception);
            resultText = [NSString stringWithFormat:@"读取时发生异常: %@", exception.reason];
        }

        // 5. 显示结果
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"调试读取结果"
                                                                       message:resultText
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } else {
        EchoLog(@"顶层控制器不是目标控制器。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"操作提示"
                                                                       message:@"请先手动点击App内的“法诀”按钮，让法诀列表显示出来，然后再点击这个绿色按钮。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

%end
