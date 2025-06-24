#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingByCoordinate = NO;
static NSMutableArray<NSString *> *g_capturedDetails = nil;
static NSMutableArray<NSString *> *g_pointTitles = nil;
static int g_currentPointIndex = 0;
static UIAlertController *g_progressAlert = nil;

// 辅助函数：提取UILabel文本
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 【【【终极核心修正】】】 直接找到手势并调用其绑定的方法
static BOOL SimulateTapAtPoint(CGPoint point) {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                keyWindow = scene.windows.firstObject;
                break;
            }
        }
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        keyWindow = [[UIApplication sharedApplication] keyWindow];
        #pragma clang diagnostic pop
    }
    if (!keyWindow) return NO;

    // 1. 找到坐标下的目标视图
    UIView *targetView = [keyWindow hitTest:point withEvent:nil];
    if (!targetView) {
        NSLog(@"[坐标提取] 错误: 在坐标 (%.1f, %.1f) 处未找到任何视图。", point.x, point.y);
        return NO;
    }
    
    // 2. 遍历视图上的所有手势识别器
    for (UIGestureRecognizer *recognizer in targetView.gestureRecognizers) {
        // 3. 锁定那个点击手势
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            // 4. 用KVC黑魔法获取手势绑定的 target 和 action
            // 这是最可靠的方式，直接执行App原本的点击逻辑
            NSArray *targets = [recognizer valueForKey:@"_targets"];
            if (targets.count > 0) {
                id targetContainer = targets.firstObject;
                id target = [targetContainer valueForKey:@"_target"];
                SEL action = NSSelectorFromString([targetContainer valueForKey:@"_action"]);

                if (target && [target respondsToSelector:action]) {
                    NSLog(@"[坐标提取] 成功找到目标方法，正在执行...");
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    [target performSelector:action withObject:recognizer];
                    #pragma clang diagnostic pop
                    return YES; // 成功执行，返回YES
                }
            }
        }
    }

    NSLog(@"[坐标提取] 错误: 在目标视图上未找到可执行的Tap手势。");
    return NO; // 未找到或执行失败，返回NO
}


// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (CoordinateExtractor)
- (void)startCoordinateExtraction_Truth;
- (void)processNextCoordinateClick_Truth;
- (void)showProgressAlert_Truth;
- (void)updateProgress_Truth;
- (void)dismissProgressAlertAndFinalize_Truth;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 556699;
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            
            UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 50);
            extractButton.tag = buttonTag;
            extractButton.titleLabel.numberOfLines = 2;
            extractButton.titleLabel.textAlignment = NSTextAlignmentCenter;
            [extractButton setTitle:@"一键提取\n(终极稳定版)" forState:UIControlStateNormal];
            extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            extractButton.backgroundColor = [UIColor systemGreenColor];
            [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractButton.layer.cornerRadius = 8;
            [extractButton addTarget:self action:@selector(startCoordinateExtraction_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:extractButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingByCoordinate) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1 = roundf(o1.frame.origin.y); CGFloat y2 = roundf(o2.frame.origin.y);
                    if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedDetails addObject:fullDetail];
                [self updateProgress_Truth];
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processNextCoordinateClick_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)startCoordinateExtraction_Truth {
    if (g_isExtractingByCoordinate) return;
    g_isExtractingByCoordinate = YES;
    g_capturedDetails = [NSMutableArray array];
    g_currentPointIndex = 0;
    g_pointTitles = [@[
        @"初传 - 地支", @"初传 - 天将", @"中传 - 地支", @"中传 - 天将", @"末传 - 地支", @"末传 - 天将",
        @"第一课 - 天将", @"第一课 - 天盘地支", @"第一课 - 地盘地支",
        @"第二课 - 天将", @"第二课 - 天盘地支", @"第二课 - 地盘地支",
        @"第三课 - 天将", @"第三课 - 天盘地支", @"第三课 - 地盘地支",
        @"第四课 - 天将", @"第四课 - 天盘地支", @"第四课 - 地盘地支"
    ] mutableCopy];
    [self showProgressAlert_Truth];
    [self processNextCoordinateClick_Truth];
}

%new
- (void)processNextCoordinateClick_Truth {
    NSArray<NSValue *> *coordinates = @[
        [NSValue valueWithCGPoint:CGPointMake(267.67, 153.00)], [NSValue valueWithCGPoint:CGPointMake(307.00, 141.33)],
        [NSValue valueWithCGPoint:CGPointMake(270.33, 216.00)], [NSValue valueWithCGPoint:CGPointMake(307.33, 219.00)],
        [NSValue valueWithCGPoint:CGPointMake(268.00, 298.33)], [NSValue valueWithCGPoint:CGPointMake(312.00, 293.00)],
        [NSValue valueWithCGPoint:CGPointMake(302.33, 341.33)], [NSValue valueWithCGPoint:CGPointMake(299.00, 381.67)],
        [NSValue valueWithCGPoint:CGPointMake(305.00, 415.33)], [NSValue valueWithCGPoint:CGPointMake(245.33, 343.00)],
        [NSValue valueWithCGPoint:CGPointMake(250.33, 373.67)], [NSValue valueWithCGPoint:CGPointMake(248.33, 412.00)],
        [NSValue valueWithCGPoint:CGPointMake(192.00, 346.33)], [NSValue valueWithCGPoint:CGPointMake(185.33, 373.67)],
        [NSValue valueWithCGPoint:CGPointMake(188.33, 410.67)], [NSValue valueWithCGPoint:CGPointMake(135.67, 346.00)],
        [NSValue valueWithCGPoint:CGPointMake(140.00, 375.33)], [NSValue valueWithCGPoint:CGPointMake(138.00, 407.00)],
    ];

    if (g_currentPointIndex >= coordinates.count) {
        [self dismissProgressAlertAndFinalize_Truth];
        return;
    }
    
    // 我们不再需要复杂的超时逻辑了，因为现在是同步调用
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGPoint pointToTap = [coordinates[g_currentPointIndex] CGPointValue];
        
        BOOL success = SimulateTapAtPoint(pointToTap);
        
        g_currentPointIndex++;

        // 如果模拟点击失败 (没有找到手势)，我们直接记录失败并继续下一个
        if (!success) {
            NSLog(@"[坐标提取] 点 #%d 模拟点击失败，自动跳过。", g_currentPointIndex - 1);
            [g_capturedDetails addObject:@"[此项点击模拟失败]"];
            [self updateProgress_Truth];
            [self processNextCoordinateClick_Truth]; // 立即处理下一个
        }
        // 如果成功，我们什么都不做，等待 presentViewController 的 hook 来驱动下一个
    });
}

%new
- (void)showProgressAlert_Truth {
    g_progressAlert = [UIAlertController alertControllerWithTitle:@"正在提取..." message:@"进度: 0 / 18" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:g_progressAlert animated:YES completion:nil];
}

%new
- (void)updateProgress_Truth {
    if (g_progressAlert) {
        g_progressAlert.message = [NSString stringWithFormat:@"进度: %lu / 18", (unsigned long)g_capturedDetails.count];
    }
}

%new
- (void)dismissProgressAlertAndFinalize_Truth {
    if (g_progressAlert) {
        [g_progressAlert dismissViewControllerAnimated:YES completion:nil];
        g_progressAlert = nil;
    }
    NSMutableString *resultStr = [NSMutableString string];
    for (NSUInteger i = 0; i < g_pointTitles.count; i++) {
        NSString *title = g_pointTitles[i];
        NSString *detail = (i < g_capturedDetails.count) ? g_capturedDetails[i] : @"[信息提取失败]";
        [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
    }
    if (resultStr.length > 0) {
        [UIPasteboard generalPasteboard].string = resultStr;
        NSString *message = [NSString stringWithFormat:@"提取完成！\n共处理 %lu 个点，结果已复制到剪贴板。", (unsigned long)g_capturedDetails.count];
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"操作成功" message:message preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
    }
    g_isExtractingByCoordinate = NO;
    g_capturedDetails = nil;
    g_pointTitles = nil;
}

%end
