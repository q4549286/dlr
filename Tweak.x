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
        NSLog(@"[KeChuan-Test-Truth-V12-Final] %@", logMessage); \
        if (g_screenLogger) { \
            dispatch_async(dispatch_get_main_queue(), ^{ \
                NSString *newText = [NSString stringWithFormat:@"%@\n- %@", g_screenLogger.text, logMessage]; \
                if (newText.length > 2000) { newText = [newText substringFromIndex:newText.length - 2000]; } \
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

// --- viewDidLoad: 创建按钮和日志窗口 ---
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
            [testButton setTitle:@"课传提取(最终版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.6 alpha:1.0]; // 品红色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            
            if ([keyWindow viewWithTag:LoggerViewTag]) { [[keyWindow viewWithTag:LoggerViewTag] removeFromSuperview]; }
            UITextView *logger = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 170, 150)];
            logger.tag = LoggerViewTag;
            logger.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
            logger.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.8 alpha:1.0]; // 亮粉色
            logger.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            logger.editable = NO;
            logger.layer.borderColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.6 alpha:1.0].CGColor;
            logger.layer.borderWidth = 1.0;
            logger.layer.cornerRadius = 5;
            g_screenLogger = logger;
            [keyWindow addSubview:g_screenLogger];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            NSString *expectedTitle = @"未知项目";
            if (g_capturedKeChuanDetailArray.count < g_keChuanTitleQueue.count) {
                expectedTitle = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
            }
            EchoLog(@"捕获弹窗 for [%@]", expectedTitle);
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
                EchoLog(@"内容已提取, 关闭弹窗.");
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
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
// --- performKeChuanDetailExtractionTest_Truth: 构建任务队列 ---
- (void)performKeChuanDetailExtractionTest_Truth {
    g_screenLogger.text = @"";
    EchoLog(@"开始V12最终测试...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    NSInteger itemIndex = 0; // 总索引

    // 三传识别
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *sanChuanContainers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, sanChuanContainers);
        if (sanChuanContainers.count > 0) {
            UIView *sanChuanContainer = sanChuanContainers.firstObject;
            Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
            if (chuanViewClass) {
                NSMutableArray *allChuanViews = [NSMutableArray array];
                for (UIView *subview in sanChuanContainer.subviews) {
                    if ([subview isKindOfClass:chuanViewClass]) { [allChuanViews addObject:subview]; }
                }
                [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                    CGPoint p1 = [v1.superview convertPoint:v1.frame.origin toView:self.view];
                    CGPoint p2 = [v2.superview convertPoint:v2.frame.origin toView:self.view];
                    return [@(p1.y) compare:@(p2.y)];
                }];
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
                        [g_keChuanWorkQueue addObject:@{@"title": dizhiTitle, @"index": @(itemIndex++)}];
                        [g_keChuanTitleQueue addObject:dizhiTitle];
                        NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text];
                        [g_keChuanWorkQueue addObject:@{@"title": tianjiangTitle, @"index": @(itemIndex++)}];
                        [g_keChuanTitleQueue addObject:tianjiangTitle];
                    }
                }
            }
        }
    }
    
    // 四课识别
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], siKeContainer, allLabels);
            NSMutableDictionary *cols = [NSMutableDictionary dictionary];
            for (UILabel *label in allLabels) {
                NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                if (!cols[key]) { cols[key] = [NSMutableArray array]; }
                [cols[key] addObject:label];
            }
            if (cols.allKeys.count == 4) {
                NSArray *sortedKeys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                NSArray *colTitles = @[@"第四课", @"第三课", @"第二课", @"第一课"];
                for (NSUInteger i = 0; i < sortedKeys.count; i++) {
                    NSMutableArray *colLabels = cols[sortedKeys[i]];
                    [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    if (colLabels.count >= 2) {
                        // 四课的索引是继续往上加的
                        NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支(%@)", colTitles[i], ((UILabel*)colLabels[1]).text];
                        [g_keChuanWorkQueue addObject:@{@"title": dizhiTitle, @"index": @(itemIndex++)}];
                        [g_keChuanTitleQueue addObject:dizhiTitle];
                        NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将(%@)", colTitles[i], ((UILabel*)colLabels[0]).text];
                        [g_keChuanWorkQueue addObject:@{@"title": tianjiangTitle, @"index": @(itemIndex++)}];
                        [g_keChuanTitleQueue addObject:tianjiangTitle];
                    }
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) { EchoLog(@"测试失败: 未构建任何任务."); g_isExtractingKeChuanDetail = NO; return; }
    EchoLog(@"队列构建完成,共%lu项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 注入Ivar并调用显示方法 ---
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"所有任务完成! 生成结果.");
        g_isExtractingKeChuanDetail = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ g_screenLogger.text = @"测试完成。请检查剪贴板。"; });
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
    
    NSString *title = task[@"title"];
    NSInteger itemIndex = [task[@"index"] integerValue];

    EchoLog(@"处理任务: %@ (索引 %ld)", title, (long)itemIndex);

    // 1. 【核心】尝试设置一个假想的ivar来更新App内部状态
    const char *ivarNameToTry = "_selectedIndex"; // 这是一个非常通用的命名，我们以此作为最后尝试
    Ivar ivar = class_getInstanceVariable([self class], ivarNameToTry);
    
    if (ivar) {
        const char *type = ivar_getTypeEncoding(ivar);
        // 确保ivar类型是NSInteger, long, int等整数类型
        if (strcmp(type, @encode(NSInteger)) == 0 || strcmp(type, @encode(long)) == 0 || strcmp(type, @encode(int)) == 0) {
            EchoLog(@"找到整数Ivar '%s'!", ivarNameToTry);
            object_setIvar(self, ivar, (id)(uintptr_t)itemIndex); // 更安全的设置方式
            EchoLog(@"已设置Ivar '%s' 的值为 %ld", ivarNameToTry, (long)itemIndex);
        } else {
            EchoLog(@"警告: Ivar '%s' 类型为 %s, 不是整数类型!", ivarNameToTry, type);
        }
    } else {
        EchoLog(@"警告: 未找到Ivar '%s'. 此次调用可能失败.", ivarNameToTry);
    }

    // 2. 调用显示方法
    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([title containsString:@"天将"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        EchoLog(@"将在 self 上调用 %@", NSStringFromSelector(actionToPerform));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:nil];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未找到显示方法! 跳过.");
        [self processKeChuanQueue_Truth];
    }
}
%end
