#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (带屏幕日志功能)
// =========================================================================
static UITextView *g_screenLogger = nil;

#define EchoLog(format, ...) \
    do { \
        NSString *logMessage = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
        NSLog(@"[KeChuan-Test-Truth-V7-Delay] %@", logMessage); \
        if (g_screenLogger) { \
            dispatch_async(dispatch_get_main_queue(), ^{ \
                NSString *newText = [NSString stringWithFormat:@"%@\n- %@", g_screenLogger.text, logMessage]; \
                if (newText.length > 2000) { \
                    newText = [newText substringFromIndex:newText.length - 2000]; \
                } \
                g_screenLogger.text = newText; \
                [g_screenLogger scrollRangeToVisible:NSMakeRange(g_screenLogger.text.length - 1, 1)]; \
            }); \
        } \
    } while (0)

static NSInteger const TestButtonTag = 556690;
static NSInteger const LoggerViewTag = 778899;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

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
            [testButton setTitle:@"测试课传(V7延迟)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemPurpleColor]; // 改成紫色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            if ([keyWindow viewWithTag:LoggerViewTag]) { [[keyWindow viewWithTag:LoggerViewTag] removeFromSuperview]; }
            UITextView *logger = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 170, 150)];
            logger.tag = LoggerViewTag;
            logger.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
            logger.textColor = [UIColor systemPurpleColor];
            logger.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            logger.editable = NO;
            logger.layer.borderColor = [UIColor systemPurpleColor].CGColor;
            logger.layer.borderWidth = 1.0;
            logger.layer.cornerRadius = 5;
            g_screenLogger = logger;
            [keyWindow addSubview:g_screenLogger];
            EchoLog(@"屏幕日志已启动.");
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            NSString *expectedTitle = @"未知项目";
            if (g_capturedKeChuanDetailArray.count < g_keChuanTitleQueue.count) {
                expectedTitle = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
            }
            EchoLog(@"捕获弹窗: %@\n预期来源: %@", vcClassName, expectedTitle);
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
                    if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                EchoLog(@"内容已提取, 即将关闭弹窗.");
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 【【【V7核心修改】】】
                    // 增加一个更长的延迟，给UIPopoverPresentationController足够的时间来清理状态
                    CGFloat delay = 0.5; // 从0.5秒开始尝试，如果还不行可以增加到0.8或1.0
                    EchoLog(@"弹窗已关闭. 延迟 %.1f 秒后触发下一个任务...", delay);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                         [self processKeChuanQueue_Truth];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// performKeChuanDetailExtractionTest_Truth 和 processKeChuanQueue_Truth 保持和V6一致
%new
- (void)performKeChuanDetailExtractionTest_Truth {
    g_screenLogger.text = @""; // 清空日志
    EchoLog(@"开始V7延迟测试...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanContainers = [NSMutableArray array];
    if (sanChuanContainerClass) { FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, sanChuanContainers); }
    if (sanChuanContainers.count > 0) {
        UIView *sanChuanContainer = sanChuanContainers.firstObject;
        EchoLog(@"找到三传容器: <%@: %p>", [sanChuanContainer class], sanChuanContainer);
        Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
        NSMutableArray *allChuanViews = [NSMutableArray array];
        if (chuanViewClass) {
            for (UIView *subview in sanChuanContainer.subviews) {
                if ([subview isKindOfClass:chuanViewClass]) { [allChuanViews addObject:subview]; }
            }
        }
        EchoLog(@"在三传容器中找到 %lu 个'傳視圖'", (unsigned long)allChuanViews.count);
        [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            CGPoint p1 = [v1.superview convertPoint:v1.frame.origin toView:self.view];
            CGPoint p2 = [v2.superview convertPoint:v2.frame.origin toView:self.view];
            return [@(p1.y) compare:@(p2.y)];
        }];
        EchoLog(@"'傳視圖'已按绝对Y坐标排序.");
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < allChuanViews.count; i++) {
            if (i >= rowTitles.count) break;
            UIView *chuanView = allChuanViews[i];
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count - 2];
                UILabel *tianjiangLabel = labels[labels.count - 1];
                NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text];
                [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"title": dizhiTitle}];
                [g_keChuanTitleQueue addObject:dizhiTitle];
                NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text];
                [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"title": tianjiangTitle}];
                [g_keChuanTitleQueue addObject:tianjiangTitle];
                EchoLog(@"已添加任务: %@", dizhiTitle);
                EchoLog(@"已添加任务: %@", tianjiangTitle);
            }
        }
    } else {
        EchoLog(@"错误：未找到三传容器!");
    }
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未构建任何任务队列.");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    EchoLog(@"队列构建完成，共%lu项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"所有任务完成! 生成结果.");
        g_isExtractingKeChuanDetail = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_screenLogger.text = @"测试完成。请检查剪贴板。";
        });
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        return;
    }
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    UIView *itemToClick = task[@"item"];
    NSString *title = task[@"title"];
    EchoLog(@"处理任务: %@\n将点击: <%@: %p>", title, [itemToClick class], itemToClick);
    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([title containsString:@"天将"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未找到点击方法! 跳过.");
        [self processKeChuanQueue_Truth];
    }
}
%end
