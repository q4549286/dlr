// Filename: EchoKeTiDetailExtractor_Fixed.x

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static BOOL g_isExtractingKeTiDetail = NO;
static void (^g_completionHandler)(NSString *result);

// 递归查找子视图的辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}


// =========================================================================
// 2. 核心功能实现 (UIViewController 分类)
// =========================================================================

// 先声明分类，让 %hook 能看到这些方法
@interface UIViewController (EchoKeTiDetailExtractor)
- (void)runTestExtraction;
- (void)startKeTiDetailExtractionWithCompletion:(void (^)(NSString *result))completion;
@end


// =========================================================================
// 3. Logos Hooks
// =========================================================================

%hook UIViewController

// 核心Hook：拦截弹窗呈现
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeTiDetail) {
        NSString *vcClassName = NSStringFromClass([vc class]);
        // 这是一个通用的判断，通常摘要视图的类名会包含特定关键字
        // 或者我们可以检查弹窗是否有标题，这增加了捕获的准确性
        if ([vcClassName containsString:@"摘要視圖"] || (vc.title && vc.title.length > 0)) {
            NSLog(@"[KeTiExtractor-Hook] 成功捕获到目标弹窗: %@", vc);
            
            vc.view.alpha = 0.0f; // 隐藏弹窗，避免闪烁
            
            // 创建一个新的 completion block 来执行我们的提取逻辑
            void (^newCompletion)(void) = ^{
                if (completion) completion(); // 先执行原始的 completion (如果有)

                // 从弹窗视图中提取所有UILabel的文本
                NSMutableArray<UILabel *> *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], vc.view, labels);
                
                // 按Y坐标排序，确保文本顺序正确
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                }];
                
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in labels) {
                    if (label.text.length > 0) {
                        // 将多行文本合并为一行，并移除首尾空格
                        NSString *cleanedText = [[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [textParts addObject:cleanedText];
                    }
                }
                NSString *extractedText = [textParts componentsJoinedByString:@"\n"];
                
                // 在所有操作完成后，关闭弹窗并调用我们的回调函数
                [vc dismissViewControllerAnimated:NO completion:^{
                    NSLog(@"[KeTiExtractor-Hook] 弹窗已关闭，准备回调。");
                    g_isExtractingKeTiDetail = NO;
                    if (g_completionHandler) {
                        g_completionHandler(extractedText);
                        g_completionHandler = nil; // 清理，防止重复调用
                    }
                }];
            };
            
            %orig(vc, NO, newCompletion); // 使用我们自己的completion block，并且无动画
            return; // 拦截成功，直接返回
        }
    }
    
    // 如果没有被拦截，则执行原始的 presentViewController 调用
    %orig(vc, flag, completion);
}

// 在主视图控制器加载时添加一个测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 延迟执行，确保 window 已经存在
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:889900]) return; // 防止重复添加

            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 90, 150, 40);
            testButton.tag = 889900;
            [testButton setTitle:@"提取课体详情(Test)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.58 green:0.42 blue:0.84 alpha:1.0]; // Amethyst
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            testButton.layer.shadowColor = [UIColor blackColor].CGColor;
            testButton.layer.shadowOffset = CGSizeMake(0, 1);
            testButton.layer.shadowOpacity = 0.3;
            [testButton addTarget:self action:@selector(runTestExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// =========================================================================
// 使用 %new 关键字将新的方法实现添加到 UIViewController 类中
// 这解决了 " %new found outside of hook " 的编译错误
// =========================================================================

%new
- (void)runTestExtraction {
    NSLog(@"[KeTiExtractor] 测试按钮被点击，开始执行提取流程。");
    
    // 创建一个简单的加载提示
    UIView *hud = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 150, 50)];
    hud.center = self.view.center;
    hud.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
    hud.layer.cornerRadius = 10;
    hud.tag = 889901;
    UILabel *hudLabel = [[UILabel alloc] initWithFrame:hud.bounds];
    hudLabel.text = @"提取中...";
    hudLabel.textColor = [UIColor whiteColor];
    hudLabel.textAlignment = NSTextAlignmentCenter;
    [hud addSubview:hudLabel];
    [self.view addSubview:hud];

    [self startKeTiDetailExtractionWithCompletion:^(NSString *result) {
        // 移除加载提示
        [[self.view viewWithTag:889901] removeFromSuperview];

        NSLog(@"[KeTiExtractor] 提取流程完成，结果: \n---\n%@\n---", result);
        
        // 将结果复制到剪贴板
        [UIPasteboard generalPasteboard].string = result;
        
        // 显示成功提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取成功"
                                                                       message:@"课体详情已复制到剪贴板！"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }];
}

%new
- (void)startKeTiDetailExtractionWithCompletion:(void (^)(NSString *result))completion {
    if (g_isExtractingKeTiDetail) {
        NSLog(@"[KeTiExtractor-Start] 警告: 提取任务已在进行中，本次请求被忽略。");
        if (completion) {
             // 移除加载提示
            [[self.view viewWithTag:889901] removeFromSuperview];
        }
        return;
    }

    // 1. 找到课体视图
    Class keTiViewClass = NSClassFromString(@"六壬大占.課體視圖");
    if (!keTiViewClass) {
        if (completion) completion(@"[错误] 找不到 '六壬大占.課體視圖' 类。");
        return;
    }
    
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(keTiViewClass, self.view, targetViews);
    if (targetViews.count == 0) {
        if (completion) completion(@"[错误] 未找到课体视图实例。");
        return;
    }
    UIView *keTiView = targetViews.firstObject;
    NSLog(@"[KeTiExtractor-Start] 成功找到课体视图: %@", keTiView);

    // 2. 查找并确认手势
    UIGestureRecognizer *gestureToTrigger = keTiView.gestureRecognizers.firstObject;
    if (!gestureToTrigger) {
        if (completion) completion(@"[错误] 课体视图上没有找到任何手势。");
        return;
    }
    NSLog(@"[KeTiExtractor-Start] 成功找到手势: %@", gestureToTrigger);

    // 3. !! 关键步骤：使用您通过监控器找到的Action名 !!
    SEL actionToPerform = NSSelectorFromString(@"顯示課體摘要WithSender:");
    
    if ([self respondsToSelector:actionToPerform]) {
        NSLog(@"[KeTiExtractor-Start] 确认控制器响应方法 '%@'，准备触发...", NSStringFromSelector(actionToPerform));
        
        // 设置全局状态和回调
        g_isExtractingKeTiDetail = YES;
        g_completionHandler = [completion copy];
        
        // 4. 执行方法，触发弹窗
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
        NSLog(@"[KeTiExtractor-Start] 方法已调用，等待弹窗被Hook拦截...");

    } else {
        NSString *errorMsg = [NSString stringWithFormat:@"[错误] 控制器不响应方法 '%@'", NSStringFromSelector(actionToToPerform)];
        NSLog(@"[KeTiExtractor-Start] %@", errorMsg);
        if (completion) completion(errorMsg);
    }
}

%end
