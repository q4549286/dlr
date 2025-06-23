#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V5-FINAL] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
//  Hook UIViewController
// =========================================================================
%hook UIViewController

// -------------------------------------------------------------------------
// 1. 添加测试按钮 (无变化)
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        if ([self.view.window viewWithTag:45678]) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(10, 45, 120, 36);
            testButton.tag = 45678;
            [testButton setTitle:@"测试格局提取" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(testGeJuExtractionTapped) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// -------------------------------------------------------------------------
// 2. 拦截弹窗【最终修正：调整%orig时机】
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 【核心修改】先调用原始方法，确保系统流程不被打乱
    %orig(viewControllerToPresent, flag, completion);

    // 如果不是我们的测试任务在执行，则直接返回
    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    EchoLog(@"拦截到弹窗: %@", NSStringFromClass([viewControllerToPresent class]));
    
    // 因为%orig已经执行，VC已经在视图层级中，我们现在可以安全操作
    // 无需再修改 alpha 和 flag，因为我们是在它呈现后立即处理
    
    NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
    
    if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
        SEL getterSelector = NSSelectorFromString(@"格局列");
        id dataSource = nil;
        if ([viewControllerToPresent respondsToSelector:getterSelector]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            dataSource = [viewControllerToPresent performSelector:getterSelector];
            #pragma clang diagnostic pop
        }
        
        if (dataSource && [dataSource isKindOfClass:[NSArray class]]) {
            NSMutableArray *textParts = [NSMutableArray array];
            for (id item in (NSArray *)dataSource) {
                NSString *title = [item valueForKey:@"標題"] ?: @"";
                NSString *detail = [item valueForKey:@"解"] ?: @"";
                if (title.length > 0 || detail.length > 0) {
                    [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                }
            }
            if (textParts.count > 0) {
                g_testExtractedData[@"格局"] = [textParts componentsJoinedByString:@"\n"];
                EchoLog(@"[V5-FINAL] 提取成功! 共 %lu 条格局。", (unsigned long)textParts.count);
            } else {
                g_testExtractedData[@"格局"] = @"提取成功，但数据源为空。";
            }
        } else {
             g_testExtractedData[@"格局"] = @"提取失败: Getter调用失败或返回无效数据。";
        }
    } else {
         g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败: 拦截到错误的VC: %@", vcClassName];
    }
    
    // 提取完毕后，把这个VC给dismiss掉，实现“无感”效果
    // 延迟一小下确保dismiss不会和present冲突
    dispatch_async(dispatch_get_main_queue(), ^{
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });
}

// -------------------------------------------------------------------------
// 3. 按钮点击事件【简化线程逻辑】
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped {
    EchoLog(@"--- 开始执行格局提取测试 ---");
    g_testExtractedData = [NSMutableDictionary dictionary];

    SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
    if (![self respondsToSelector:selectorGeJu]) {
        // ... (错误处理不变)
        return;
    }
    
    // 直接在主线程操作，因为我们的hook已经是异步处理了，这样更直接
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selectorGeJu withObject:nil];
    #pragma clang diagnostic pop

    // 延迟一段时间来等待我们的hook执行完毕并填充数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *resultText = g_testExtractedData[@"格局"];
        if (!resultText || resultText.length == 0) {
            resultText = @"提取失败，未捕获到任何内容。";
        }
        
        EchoLog(@"--- 测试完成，准备显示结果 ---");
        [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取测试结果"
                                                                       message:resultText
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alert animated:YES completion:^{
            g_testExtractedData = nil;
        }];
    });
}

%end
