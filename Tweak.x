#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V2] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量，用于在不同方法间传递状态
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
//  Hook UIViewController 来添加按钮和实现提取逻辑
// =========================================================================
%hook UIViewController

// -------------------------------------------------------------------------
// 1. 在主界面添加一个测试按钮
// -------------------------------------------------------------------------
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 确保按钮不重复添加
        if ([self.view.window viewWithTag:45678]) {
            return;
        }

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
// 2. 拦截弹窗，这是我们的核心逻辑【已修正】
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 如果不是我们的测试任务在执行，则正常处理
    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    EchoLog(@"拦截到弹窗: %@", NSStringFromClass([viewControllerToPresent class]));

    // 无感处理：隐藏弹窗，取消动画
    viewControllerToPresent.view.alpha = 0.0f;
    flag = NO;

    // 将延迟时间从0.1秒增加到0.2秒，给懒加载更充分的时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
            
            // --- 【核心修改】 ---
            // 直接使用Flex里看到的、最原始的、最精确的懒加载变量名
            NSString *preciseIvarName = @"$_lazy_storage_$_格局列";
            NSString *titleKey = @"標題";
            NSString *detailKey = @"解";
            
            // 使用 class_getInstanceVariable 来获取 Ivar，这是最底层的访问方式
            Ivar ivar = class_getInstanceVariable([viewControllerToPresent class], [preciseIvarName UTF8String]);
            
            id dataSource = nil;
            if (ivar) {
                // 如果能找到ivar，就用 object_getIvar 来获取它的值
                dataSource = object_getIvar(viewControllerToPresent, ivar);
                EchoLog(@"成功通过精确名称 '%@' 找到Ivar。", preciseIvarName);
            } else {
                 EchoLog(@"致命错误: 无法在类 %@ 中找到名为 '%@' 的Ivar。", vcClassName, preciseIvarName);
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
                    EchoLog(@"[修正版] 提取成功! 共 %lu 条格局。", (unsigned long)textParts.count);
                } else {
                    g_testExtractedData[@"格局"] = @"提取成功，但数据源数组内容为空。";
                }
            } else {
                 NSString *errorMsg = [NSString stringWithFormat:@"提取失败。Ivar '%@' 的值不是有效的NSArray或为nil。实际值: %@", preciseIvarName, dataSource];
                 g_testExtractedData[@"格局"] = errorMsg;
                 EchoLog(@"%@", errorMsg);
            }
        } else {
             g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，拦截到了错误的VC: %@", vcClassName];
        }
        
        // 处理完毕后，静默关闭这个弹窗
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });

    // 必须调用原始方法，否则App可能卡住
    %orig(viewControllerToPresent, flag, completion);
}


// -------------------------------------------------------------------------
// 3. 按钮的点击事件
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped {
    EchoLog(@"--- 开始执行格局提取测试 ---");
    g_testExtractedData = [NSMutableDictionary dictionary];

    SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
    if (![self respondsToSelector:selectorGeJu]) {
        EchoLog(@"错误: 当前ViewController不响应'顯示格局總覽'方法。");
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"当前VC无法调用'顯示格局總覽'" preferredStyle:UIAlertControllerStyleAlert];
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
        
        [NSThread sleepForTimeInterval:0.5]; 
        
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
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                g_testExtractedData = nil;
            }];
        });
    });
}

%end
