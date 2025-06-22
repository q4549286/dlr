#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// =========================================================================
// Section: 【V3 方案独立测试】直接从数据模型提取“法诀”
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
            // 按钮的 Tag，使用一个唯一的值
            NSInteger buttonTag = 445566; 
            if (!keyWindow || [keyWindow viewWithTag:buttonTag]) { return; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            // 放在“复制到AI”按钮的下方
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45 + 40, 90, 36);
            testButton.tag = buttonTag;
            [testButton setTitle:@"测试复制法诀" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:12];
            testButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.1 alpha:1.0]; // 橙色以区分
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
    // 如果不是我们的测试任务在执行，就正常处理
    if (!g_isTestTaskRunning) {
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
    
    // 检查是否是我们期望拦截的控制器
    if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
        EchoLog(@"成功拦截到目标控制器: %@", vcClassName);
        
        // 阻止弹窗显示
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        
        // 延迟一小段时间确保 ViewController 的内容已经加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 使用 KVC (Key-Value Coding) 访问 Swift 的 '法訣列' 属性
            // 这会自动触发懒加载，获取到数据
            id biFaData = [viewControllerToPresent valueForKey:@"法訣列"];

            NSString *resultText = @"";
            
            if (biFaData && [biFaData isKindOfClass:[NSArray class]]) {
                NSArray *biFaArray = (NSArray *)biFaData;
                EchoLog(@"成功从数据模型获取到 %lu 条法诀记录", (unsigned long)biFaArray.count);
                
                NSMutableArray *textParts = [NSMutableArray array];
                
                // 遍历数据源，拼接成最终文本
                for (id item in biFaArray) {
                    // 根据我们的情报，item 是一个自定义对象
                    // 我们猜测它有 '標題' 和 '解釋' 这两个属性
                    NSString *title = [item valueForKey:@"標題"];
                    NSString *explanation = [item valueForKey:@"解釋"];
                    
                    if (title && explanation) {
                        [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, explanation]];
                    } else {
                        // 如果上面的猜测不正确，提供一个备用方案
                        [textParts addObject:[NSString stringWithFormat:@"[未解析项]: %@", [item description]]];
                    }
                }
                resultText = [textParts componentsJoinedByString:@"\n"];
                
            } else {
                EchoLog(@"提取失败：'法訣列' 数据为空或类型不符 (%@)", [biFaData class]);
                resultText = @"法诀提取失败：未能从数据模型中找到有效数据。";
            }

            // 将结果复制到剪贴板并显示
            [UIPasteboard generalPasteboard].string = resultText;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"法诀提取测试成功"
                                                                           message:resultText
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 任务结束，重置标志位
                g_isTestTaskRunning = NO;
                EchoLog(@"测试任务结束。");
            }]];
            
            // 找到最顶层的控制器来弹出提示框
            UIWindow *window = [[UIApplication sharedApplication] keyWindow];
            [window.rootViewController presentViewController:alert animated:YES completion:nil];

            // 关闭被我们拦截的、不可见的控制器
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        
        // 即使我们已经处理了，仍然需要调用原始方法，否则可能导致问题
        %orig(viewControllerToPresent, flag, completion);
        return;
    }

    // 如果弹出的不是我们想拦截的控制器，就正常显示
    %orig(viewControllerToPresent, flag, completion);
}


%new
- (void)copyBiFaOnlyButtonTapped_TestAction {
    EchoLog(@"测试按钮被点击，开始执行测试任务...");
    
    // 1. 设置标志位，告诉我们的 hook 开始工作
    g_isTestTaskRunning = YES;
    
    // 2. 找到并执行 App 原本的“显示法诀”方法
    SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
    if ([self respondsToSelector:selectorBiFa]) {
        EchoLog(@"正在调用 '顯示法訣總覽' 方法...");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selectorBiFa withObject:nil];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误：在 %@ 上未找到方法 '顯示法訣總覽'", [self class]);
        // 如果找不到方法，要重置标志位
        g_isTestTaskRunning = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试失败"
                                                                       message:@"无法找到App内部的法诀显示方法。"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

%end
