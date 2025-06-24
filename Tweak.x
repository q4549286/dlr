#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (添加了新的调试变量)
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Debug-V5] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;
static NSString *g_currentTaskTitleForDebug = nil; // 新增：用于调试，记录当前任务标题

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- viewDidLoad 保持不变 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"调试课传(V5)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemRedColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 【调试增强】presentViewController ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            
            // 【调试日志】
            EchoLog(@"--- [INTERCEPT] 拦截到弹窗 ---");
            EchoLog(@"弹窗类名: %@", vcClassName);
            EchoLog(@"当前任务标题: %@", g_currentTaskTitleForDebug ?: @"未知");
            
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                
                // 【调试日志】
                EchoLog(@"提取到的内容: %@", [fullDetail stringByReplacingOccurrencesOfString:@"\n" withString:@" "]);
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                     EchoLog(@"弹窗已关闭，准备处理下一个任务...");
                    [self processKeChuanQueue_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- 【调试增强】performKeChuanDetailExtractionTest_Truth ---
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"\n\n=============================================");
    EchoLog(@"开始执行 [课传详情] V5 调试版");
    EchoLog(@"=============================================");

    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    g_currentTaskTitleForDebug = nil;

    // --- Part A: 采用精简策略，直接处理三传的容器视图 ---
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containerViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containerViews);

        if (containerViews.count > 0) {
            UIView *sanChuanContainer = containerViews.firstObject;
            EchoLog(@"[BUILD QUEUE] 找到三传容器: %@, Frame: %@", sanChuanContainer, NSStringFromCGRect(sanChuanContainer.frame));
            
            NSMutableArray *chuanViews = [sanChuanContainer.subviews mutableCopy];
            [chuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
            }];
            
            NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
            for (NSUInteger i = 0; i < chuanViews.count; i++) {
                if (i >= rowTitles.count) break;
                
                UIView *chuanView = chuanViews[i];
                EchoLog(@"[BUILD QUEUE] 处理容器子视图 %lu: %@, 相对Y: %f", (unsigned long)i, chuanView, chuanView.frame.origin.y);

                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                if (labels.count >= 2) {
                    UILabel *dizhiLabel = labels[labels.count - 2];
                    UILabel *tianjiangLabel = labels[labels.count - 1];
                    
                    NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text];
                    NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text];
                    
                    // 【调试日志】
                    CGPoint dizhiAbsPos = [dizhiLabel.superview convertPoint:dizhiLabel.frame.origin toView:self.view.window];
                    CGPoint tianjiangAbsPos = [tianjiangLabel.superview convertPoint:tianjiangLabel.frame.origin toView:self.view.window];

                    EchoLog(@"[BUILD QUEUE]   - 添加任务: '%@', Label指针: %p, 绝对坐标: %@", dizhiTitle, dizhiLabel, NSStringFromCGPoint(dizhiAbsPos));
                    EchoLog(@"[BUILD QUEUE]   - 添加任务: '%@', Label指针: %p, 绝对坐标: %@", tianjiangTitle, tianjiangLabel, NSStringFromCGPoint(tianjiangAbsPos));
                    
                    [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi", @"title_debug": dizhiTitle}];
                    [g_keChuanTitleQueue addObject:dizhiTitle];
                    
                    [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang", @"title_debug": tianjiangTitle}];
                    [g_keChuanTitleQueue addObject:tianjiangTitle];
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"[ERROR] 测试失败: 未能构建任何课传点击任务。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    EchoLog(@"--- 任务队列构建完成，共 %lu 个任务。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// --- 【调试增强】processKeChuanQueue_Truth ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"=============================================");
        EchoLog(@"所有任务处理完毕，生成最终结果...");
        EchoLog(@"=============================================");
        // (结果生成部分不变)
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"调试完成" message:@"所有详情已提取并复制到剪贴板。请查看Xcode日志。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    UILabel *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];
    g_currentTaskTitleForDebug = task[@"title_debug"]; // 更新全局调试标题
    
    EchoLog(@"---");
    EchoLog(@"[PROCESS] 正在处理任务: %@", g_currentTaskTitleForDebug);
    EchoLog(@"[PROCESS] 目标Label文本: '%@', 指针: %p", itemToClick.text, itemToClick);
    EchoLog(@"[PROCESS] 目标Label绝对坐标: %@", NSStringFromCGPoint([itemToClick.superview convertPoint:itemToClick.frame.origin toView:self.view.window]));

    // 【调试高亮】
    CALayer *originalLayer = itemToClick.layer;
    UIColor *originalBorderColor = [UIColor colorWithCGColor:originalLayer.borderColor];
    CGFloat originalBorderWidth = originalLayer.borderWidth;
    originalLayer.borderColor = [UIColor redColor].CGColor;
    originalLayer.borderWidth = 2.0f;
    
    // 延迟执行点击，让你能看到高亮
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 恢复原始样式
        originalLayer.borderColor = originalBorderColor.CGColor;
        originalLayer.borderWidth = originalBorderWidth;

        SEL actionToPerform = nil;
        if ([itemType isEqualToString:@"dizhi"]) {
            actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        } else if ([itemType isEqualToString:@"tianjiang"]) {
            actionToTDDDDDDPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        }

        if (actionToPerform && [self respondsToSelector:actionToPerform]) {
            EchoLog(@"[PROCESS] 执行点击动作: %@", NSStringFromSelector(actionToPerform));
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:actionToPerform withObject:itemToClick];
            #pragma clang diagnostic pop
        } else {
            EchoLog(@"[ERROR] 未能为 %@ 找到并执行对应的点击方法。将跳过并处理下一个。", itemType);
            [self processKeChuanQueue_Truth];
        }
    });
}
%end
