#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-v4] " format), ##__VA_ARGS__)

// =========================================================================
// 全局变量，用于在不同hook方法间传递状态
// =========================================================================
static BOOL g_isTestingNianMing = NO; // 标记我们是否正在进行年命测试
static NSMutableString *g_capturedNianMingText = nil; // 用于存储抓取到的文本

// =========================================================================
// 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 测试专用 Hook
// =========================================================================

@interface UIViewController (DelegateTestAddon)
- (void)performFullNianMingTest;
@end

%hook UIViewController

// 在主界面加载时，添加我们的“测试按钮”
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            
            NSInteger testButtonTag = 999003;
            if ([keyWindow viewWithTag:testButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 200, 45, 90, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试完整流程" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor orangeColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            
            [testButton addTarget:self action:@selector(performFullNianMingTest) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:testButton];
            EchoLog(@"完整流程测试按钮已添加。");
        });
    }
}

// 拦截所有视图控制器的呈现
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 只有在我们的测试进行时，才执行拦截逻辑
    if (g_isTestingNianMing) {
        
        // --- 步骤2: 拦截操作表 (UIAlertController) ---
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:@"年命摘要"]) {
                    targetAction = action;
                    break;
                }
            }

            if (targetAction) {
                EchoLog(@"已拦截到 '年命摘要' 操作表，将自动点击。");
                // 安全地获取并执行按钮的handler，这将触发“年命摘要”视图的呈现
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) {
                    ((void (^)(UIAlertAction *))handler)(targetAction);
                }
                // 关键：不调用 %orig，从而阻止操作表的实际显示
                return; 
            }
        }
        
        // --- 步骤3: 拦截年命摘要视图 ---
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"年命摘要視圖"]) {
            EchoLog(@"已拦截到 '年命摘要視圖'，开始提取文本。");
            
            g_capturedNianMingText = [NSMutableString string];
            
            // 提取标题
            if (viewControllerToPresent.title) {
                [g_capturedNianMingText appendFormat:@"%@\n", viewControllerToPresent.title];
            }
            
            // 提取内容 (可能是UILabel或UITextView)
            NSMutableArray *textualViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIView class], viewControllerToPresent.view, textualViews);
            
            [textualViews filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
                return [evaluatedObject respondsToSelector:@selector(text)];
            }]];
            [textualViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
            }];
            
            for (UIView *view in textualViews) {
                NSString *text = [view valueForKey:@"text"];
                if (text && text.length > 0 && ![g_capturedNianMingText containsString:text]) {
                    [g_capturedNianMingText appendFormat:@"%@\n", text];
                }
            }
            
            EchoLog(@"文本提取完成:\n%@", g_capturedNianMingText);
            
            // 关键：关闭这个视图，然后不调用%orig，实现无感抓取
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        }
    }
    
    // 如果不是在测试，或者拦截的不是目标视图，则正常显示
    %orig(viewControllerToPresent, flag, completion);
}

// 我们的主测试函数
%new
- (void)performFullNianMingTest {
    EchoLog(@"--- 开始年命提取完整流程测试 ---");
    
    // --- 步骤1: 模拟点击 'A' 单元格 ---
    g_isTestingNianMing = YES; // 启动测试标记
    g_capturedNianMingText = nil; // 清空上次的结果
    
    // (这部分代码来自上一个成功的测试脚本)
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    for (UICollectionView *cv in collectionViews) {
        if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) {
            targetCollectionView = cv;
            break;
        }
    }
    if (!targetCollectionView || !targetCollectionView.delegate) {
        EchoLog(@"测试中止: 未找到目标CollectionView或其delegate。");
        g_isTestingNianMing = NO;
        return;
    }
    id delegate = targetCollectionView.delegate;
    NSIndexPath *targetIndexPath = [targetCollectionView indexPathForCell:targetCollectionView.visibleCells.firstObject];
    if (!targetIndexPath) {
        EchoLog(@"测试中止: 未找到目标IndexPath。");
        g_isTestingNianMing = NO;
        return;
    }
    SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
    if ([delegate respondsToSelector:selector]) {
        EchoLog(@"正在调用代理方法，触发操作表...");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
            code; \
            _Pragma("clang diagnostic pop")
        SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:selector withObject:targetCollectionView withObject:targetIndexPath];);
    } else {
         EchoLog(@"测试中止: delegate不响应点击方法。");
         g_isTestingNianMing = NO;
         return;
    }

    // --- 步骤4: 验证结果 ---
    // 等待一小段时间，让上述的拦截、提取、关闭流程完成
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        EchoLog(@"流程执行完毕，准备显示结果。");
        
        NSString *resultTitle;
        NSString *resultMessage;
        
        if (g_capturedNianMingText && g_capturedNianMingText.length > 0) {
            resultTitle = @"提取成功！";
            resultMessage = g_capturedNianMingText;
        } else {
            resultTitle = @"提取失败";
            resultMessage = @"未能抓取到年命摘要的文本。请检查日志。";
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:resultTitle message:resultMessage preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        
        g_isTestingNianMing = NO; // 关闭测试标记
    });
}

%end
