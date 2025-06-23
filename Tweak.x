#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量，用于在不同方法间传递状态
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
// 辅助函数: 安全地获取实例变量的值
// =========================================================================
static id GetIvarValueSafely(id object, NSString *ivarName) {
    if (!object || !ivarName) return nil;
    Ivar ivar = class_getInstanceVariable([object class], [ivarName UTF8String]);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    // Fallback for Swift lazy properties, which have a mangled name
    NSString *mangledName = [NSString stringWithFormat:@"$%@", ivarName];
    ivar = class_getInstanceVariable([object class], [mangledName UTF8String]);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    // Final fallback for another common Swift mangling
    mangledName = [NSString stringWithFormat:@"$_lazy_storage_$_%@", ivarName];
    ivar = class_getInstanceVariable([object class], [mangledName UTF8String]);
     if (ivar) {
        return object_getIvar(object, ivar);
    }
    EchoLog(@"无法找到名为 '%@' 的 Ivar", ivarName);
    return nil;
}


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
// 2. 拦截弹窗，这是我们的核心逻辑
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

    // 延迟以确保VC内部懒加载变量已初始化
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        // --- 只处理我们目标中的“格局总览”视图控制器 ---
        if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
            
            // 已确认的数据源信息
            NSString *arrayIvarName = @"格局列"; // 使用去掉`$_lazy_storage_$_`的名字
            NSString *titleKey = @"標題";
            NSString *detailKey = @"解";
            
            // 直接从VC的ivar中获取数据源数组
            id dataSource = GetIvarValueSafely(viewControllerToPresent, arrayIvarName);

            if (dataSource && [dataSource isKindOfClass:[NSArray class]]) {
                NSMutableArray *textParts = [NSMutableArray array];
                for (id item in (NSArray *)dataSource) {
                    // 从每个item对象中提取标题和详情
                    // 使用KVC (valueForKey) 比直接访问ivar更健壮
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
                    EchoLog(@"[新版] 成功通过直接访问数据源提取 [格局] 内容 (%lu条)", (unsigned long)textParts.count);
                } else {
                    g_testExtractedData[@"格局"] = @"提取成功，但内容为空。";
                }
            } else {
                 g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，无法找到或访问数据源 '%@'。", arrayIvarName];
                 EchoLog(@"[新版] 提取 [格局] 失败，数据源格式不符合预期。");
            }
        } else {
             // 如果拦截到了非目标的VC，也记录下来
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
        g_testExtractedData = nil;
        return;
    }
    
    // 使用一个后台线程来管理整个流程，防止UI卡顿
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // 在主线程触发点击，因为UI操作必须在主线程
        dispatch_sync(dispatch_get_main_queue(), ^{
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:selectorGeJu withObject:nil];
            #pragma clang diagnostic pop
        });
        
        // 等待一段时间，让 presentViewController hook 有足够的时间执行
        [NSThread sleepForTimeInterval:0.5]; 
        
        // 回到主线程来显示结果
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *resultText = g_testExtractedData[@"格局"];
            if (!resultText || resultText.length == 0) {
                resultText = @"提取失败，未捕获到任何内容。请检查日志。";
            }
            
            EchoLog(@"--- 测试完成，准备显示结果 ---");

            // 将结果复制到剪贴板
            [UIPasteboard generalPasteboard].string = resultText;

            // 显示一个Alert来展示结果
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取测试结果"
                                                                           message:resultText
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                // 重置全局变量，为下一次测试做准备
                g_testExtractedData = nil;
            }];
        });
    });
}

%end
