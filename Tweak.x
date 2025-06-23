#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V7-Stable] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量
// =========================================================================
static NSMutableDictionary *g_testExtractedData = nil;

// =========================================================================
// 辅助函数: 递归查找指定类的所有子视图
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
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
            [testButton setTitle:@"格局提取(V7)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor systemOrangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(testGeJuExtractionTapped_V7) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// -------------------------------------------------------------------------
// 2. 拦截弹窗【智能UI解析版】
// -------------------------------------------------------------------------
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 先调用原始方法，确保UI准备就绪
    %orig(viewControllerToPresent, flag, completion);

    if (g_testExtractedData == nil || [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        return;
    }
    
    // 延迟到下一个RunLoop，确保Cell都已经加载并显示
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([vcClassName isEqualToString:@"六壬大占.格局總覽視圖"]) {
            EchoLog(@"[V7] 拦截到格局VC，准备进行智能UI解析...");

            Class cellClass = NSClassFromString(@"六壬大占.格局單元");
            if (!cellClass) {
                g_testExtractedData[@"格局"] = @"提取失败: 找不到'六壬大占.格局單元'类。";
                return;
            }

            NSMutableArray *cells = [NSMutableArray array];
            FindSubviewsOfClassRecursive(cellClass, viewControllerToPresent.view, cells);
            
            // 按Y坐标排序，确保顺序正确
            [cells sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
                return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
            }];
            
            if (cells.count > 0) {
                NSMutableArray *textParts = [NSMutableArray array];
                for (UIView *cell in cells) {
                    // 我们直接从Cell的ivar中取值，而不是从它的子UILabel中取
                    NSString *title = [cell valueForKey:@"標題"] ?: @"";
                    NSString *detail = [cell valueForKey:@"解"] ?: @"";

                    if (title.length > 0 || detail.length > 0) {
                        [textParts addObject:[NSString stringWithFormat:@"%@: %@", title, detail]];
                    }
                }
                
                if (textParts.count > 0) {
                    g_testExtractedData[@"格局"] = [textParts componentsJoinedByString:@"\n"];
                    EchoLog(@"[V7] 智能UI解析成功! 提取了 %lu 个Cell。", (unsigned long)cells.count);
                } else {
                    g_testExtractedData[@"格局"] = @"智能UI解析成功，但未能从Cell中提取到有效文本。";
                }
            } else {
                 g_testExtractedData[@"格局"] = @"智能UI解析失败: 未能在VC中找到任何'六壬大占.格局單元'。";
            }
        } else {
             // 如果拦截到了非目标的VC，也记录下来
             g_testExtractedData[@"格局"] = [NSString stringWithFormat:@"提取失败，拦截到了错误的VC: %@", vcClassName];
        }

        // 提取完毕，关闭弹窗
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });
}

// -------------------------------------------------------------------------
// 3. 按钮点击事件
// -------------------------------------------------------------------------
%new
- (void)testGeJuExtractionTapped_V7 {
    EchoLog(@"--- V7: 开始触发格局弹窗 ---");
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

    // 延迟等待hook执行完毕
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *resultText = g_testExtractedData[@"格局"] ?: @"提取失败，未捕获到任何内容。";
        
        [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"格局提取(V7)结果"
                                                                       message:resultText
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alert animated:YES completion:^{
            g_testExtractedData = nil;
        }];
    });
}

%end
