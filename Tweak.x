#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V8-Stable] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
// 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// -------------------------------------------------------------------------
// 【新增】一个专门用于安全获取Ivar值的辅助函数
// -------------------------------------------------------------------------
static id GetIvarValueFromObject(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        // 使用 object_getIvar 直接从内存读取，这是最安全的方式
        return object_getIvar(object, ivar);
    }
    return nil;
}

// =========================================================================
//  Hook UIViewController
// =========================================================================
%hook UIViewController

// -------------------------------------------------------------------------
// 1. 添加测试按钮
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
            [testButton setTitle:@"格局提取(V8)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemTealColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(testGeJuExtractionTapped_V8) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// -------------------------------------------------------------------------
// 2. 拦截弹窗【防闪退版】
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig(viewControllerToPresent, flag, completion);

    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
            EchoLog(@"[V8] 拦截到格局VC，准备进行防闪退UI解析...");

            Class cellClass = NSClassFromString(@"六壬大占.格局單元");
            if (!cellClass) {
                g_testExtractedData[@"格局"] = @"提取失败: 找不到'六壬大占.格局單元'类。";
                // dismiss, 以免卡住
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                return;
            }

            NSMutableArray *cells = [NSMutableArray array];
            FindSubviewsOfClassRecursive(cellClass, viewControllerToPresent.view, cells);
            
            [cells sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
                return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
            }];
            
            if (cells.count > 0) {
                NSMutableArray *textParts = [NSMutableArray array];
                for (id cell in cells) {
                    // --- 【核心修改】 ---
                    // 使用 object_getIvar 的安全辅助函数，替代 valueForKey:
                    id titleObj = GetIvarValueFromObject(cell, "標題");
                    id detailObj = GetIvarValueFromObject(cell, "解");

                    // 确保取出的值是NSString
                    NSString *title = [titleObj isKindOfClass:[NSString class]] ? titleObj : @"";
                    NSString *detail = [detailObj isKindOfClass:[NSString class]] ? detailObj : @"";

                    if (title.length > 0 || detail.length > 0) {
                        [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                    }
                }
                
                if (textParts.count > 0) {
                    g_testExtractedData[@"格局"] = [textParts componentsJoinedByString:@"\n"];
                    EchoLog(@"[V8] 防闪退解析成功! 提取了 %lu 个Cell。", (unsigned long)cells.count);
                } else {
                    g_testExtractedData[@"格局"] = @"防闪退解析成功，但未能从Cell中提取到有效文本。";
                }
            } else {
                 g_testExtractedData[@"格局"] = @"防闪退解析失败: 未能在VC中找到任何'六壬大占.格局單元'。";
            }
        } else {
             g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，拦截到了错误的VC: %@", vcClassName];
        }

        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });
}

// -------------------------------------------------------------------------
// 3. 按钮点击事件
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped_V8 {
    EchoLog(@"--- V8: 开始触发格局弹窗 ---");
    g_testExtractedData = [NSMutableDictionary dictionary];

    SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
    if (![self respondsToSelector:selectorGeJu]) {
        // ... 错误处理
        return;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selectorGeJu withObject:nil];
    #pragma clang diagnostic pop

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *resultText = g_testExtractedData[@"格局"] ?: @"提取失败，未捕获到任何内容。";
        
        [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取(V8)结果"
                                                                       message:resultText
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        // 确保在主VC上弹出Alert
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:^{
            g_testExtractedData = nil;
        }];
    });
}

%end
