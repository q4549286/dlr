#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V4] " format), ##__VA_ARGS__)

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
// 2. 拦截弹窗 (无变化)
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    EchoLog(@"拦截到弹窗: %@", NSStringFromClass([viewControllerToPresent class]));
    viewControllerToPresent.view.alpha = 0.0f;
    flag = NO;

    NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
    
    if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
        SEL getterSelector = NSSelectorFromString(@"格局列");
        NSString *titleKey = @"標題";
        NSString *detailKey = @"解";

        id dataSource = nil;
        if ([viewControllerToPresent respondsToSelector:getterSelector]) {
            EchoLog(@"VC 响应 getter '%@'，准备调用...", NSStringFromSelector(getterSelector));
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            dataSource = [viewControllerToPresent performSelector:getterSelector];
            #pragma clang diagnostic pop
            EchoLog(@"Getter 调用完毕，返回的数据: %@", dataSource);
        } else {
            EchoLog(@"致命错误: VC不响应getter '%@'。", NSStringFromSelector(getterSelector));
        }
        
        if (dataSource && [dataSource isKindOfClass:[NSArray class]]) {
            NSMutableArray *textParts = [NSMutableArray array];
            for (id item in (NSArray *)dataSource) {
                id titleObj = [item valueForKey:titleKey]; 
                id detailObj = [item valueForKey:detailKey];
                NSString *title = [titleObj isKindOfClass:[NSString class]] ? titleObj : @"";
                NSString *detail = [detailObj isKindOfClass:[NSString class]] ? detailObj : @"";
                if (title.length > 0 || detail.length > 0) {
                    [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                }
            }
            if (textParts.count > 0) {
                g_testExtractedData[@"格局"] = [textParts componentsJoinedByString:@"\n"];
                EchoLog(@"[V4-Fix] 提取成功! 共 %lu 条格局。", (unsigned long)textParts.count);
            } else {
                g_testExtractedData[@"格局"] = @"提取成功，但数据源数组内容为空。";
            }
        } else {
             NSString *errorMsg = [NSString stringWithFormat:@"提取失败。Getter '%@' 返回的值不是有效的NSArray或为nil。实际值: %@", NSStringFromSelector(getterSelector), dataSource];
             g_testExtractedData[@"格局"] = errorMsg;
             EchoLog(@"%@", errorMsg);
        }
    } else {
         g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，拦截到了错误的VC: %@", vcClassName];
    }
    
    [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    %orig(viewControllerToPresent, flag, completion);
}

// -------------------------------------------------------------------------
// 3. 按钮点击事件 【已修复编译错误】
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped {
    EchoLog(@"--- 开始执行格局提取测试 ---");
    g_testExtractedData = [NSMutableDictionary dictionary];

    SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
    if (![self respondsToSelector:selectorGeJu]) {
        EchoLog(@"错误: 当前VC不响应'顯示格局總覽'方法。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"当前VC无法调用'顯示格局總覽'" preferredStyle:UIAlertControllerStyleAlert];
        // --- 【编译错误修复点 1】---
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_testExtractedData = nil;
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_sync(dispatch_get_main_queue(), ^{
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:selectorGeJu withObject:nil];
            #pragma clang diagnostic pop
        });
        
        [NSThread sleepForTimeInterval:0.2]; 
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *resultText = g_testExtractedData[@"格局"];
            if (!resultText || resultText.length == 0) {
                resultText = @"提取失败，未捕获到任何内容。请检查日志。";
            }
            
            EchoLog(@"--- 测试完成，准备显示结果 ---");
            [UIPasteboard generalPasteboard].string = resultText;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取测试结果"
                                                                           message:resultText
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            // --- 【编译错误修复点 2】---
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                g_testExtractedData = nil;
            }];
        });
    });
}

%end
