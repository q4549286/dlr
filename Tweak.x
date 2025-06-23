#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-V4-Test] " format), ##__VA_ARGS__)

@interface UIViewController (BiFaExtraction_V4)
- (void)final_copyBiFaData_testAction;
@end

%hook UIViewController

// 在主界面添加一个“最终方案”的测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            NSInteger buttonTag = 778899; // 使用新的 tag
            if (!keyWindow || [keyWindow viewWithTag:buttonTag]) { return; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45 + 40, 90, 36);
            testButton.tag = buttonTag;
            [testButton setTitle:@"测试最终方案" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
            // 使用一个全新的颜色，比如紫色
            testButton.backgroundColor = [UIColor colorWithRed:0.5 green:0.2 blue:0.8 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(final_copyBiFaData_testAction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            EchoLog(@"V4 测试按钮已添加");
        });
    }
}

// 这次我们不再需要 hook presentViewController 了

%new
- (void)final_copyBiFaData_testAction {
    EchoLog(@"开始执行 V4 最终方案测试...");
    
    // 1. 获取目标 ViewController 的类
    Class targetVCClass = NSClassFromString(@"六壬大占.格局總覽視圖");
    if (!targetVCClass) {
        EchoLog(@"错误：找不到'六壬大占.格局總覽視圖'类。");
        // 弹窗提示错误
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败" message:@"找不到目标控制器类。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // 2. 在内存中创建这个类的实例
    // 我们需要将主VC(`self`)作为某些依赖项传入，这是一种常见的模式
    // 该控制器可能需要一个初始化方法，比如 initWithCoder: 或者其他自定义的
    // 我们先尝试最简单的 alloc/init，如果崩溃，再研究它的初始化方法
    UIViewController *dataVC = nil;
    NSString *resultText = @"";
    
    @try {
        EchoLog(@"正在内存中创建 '%@' 的实例...", NSStringFromClass(targetVCClass));
        dataVC = [[targetVCClass alloc] init];
        
        // 关键步骤：访问懒加载属性来触发数据计算
        // 这一步是核心，如果崩溃，问题就出在这里
        EchoLog(@"正在访问 '法訣列' 属性...");
        id biFaData = [dataVC valueForKey:@"法訣列"];
        
        if (biFaData && [biFaData isKindOfClass:[NSString class]]) {
            resultText = (NSString *)biFaData;
            EchoLog(@"成功从内存实例中获取到法诀字符串，长度: %lu", (unsigned long)resultText.length);
        } else {
            resultText = [NSString stringWithFormat:@"数据类型不符或为空。实际类型: %@", [biFaData class]];
            EchoLog(@"%@", resultText);
        }

    } @catch (NSException *exception) {
        EchoLog(@"!!! 在内存中操作实例时发生异常: %@", exception);
        resultText = [NSString stringWithFormat:@"操作时发生异常: %@", exception.reason];
    } @finally {
        // 无论成功与否，我们都不再需要这个实例了
        dataVC = nil; 
    }

    // 3. 显示结果
    [UIPasteboard generalPasteboard].string = resultText;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"V4 方案测试结果"
                                                                   message:resultText
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
