#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================
#pragma mark - Constants & Colors
#define ECHO_COLOR_MAIN_BLUE    [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL    [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_SUCCESS      [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_LOG_TASK     [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO     [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN     [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR    [UIColor redColor]

static const NSInteger kEchoControlButtonTag = 556699;
static const NSInteger kEchoMainPanelTag = 778899;
static const NSInteger kButtonTag_ExtractShenSha = 101;
static const NSInteger kButtonTag_ClosePanel = 998;

#pragma mark - Global State
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;

#pragma mark - Helper Functions
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeTask, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };

static void LogMessage(EchoLogType type, NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeTask:    color = ECHO_COLOR_LOG_TASK; break;
            case EchoLogTypeSuccess: color = ECHO_COLOR_SUCCESS; break;
            case EchoLogTypeWarning: color = ECHO_COLOR_LOG_WARN; break;
            case EchoLogError:       color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeInfo:
            default:                 color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText];
        g_logTextView.attributedText = logLine;
        NSLog(@"[EchoShenShaTest] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
        #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

// =========================================================================
// 2. 接口声明与核心 Hook
// =========================================================================
@interface UIViewController (EchoShenShaTest)
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (NSString *)extractShenShaInfo_Final;
@end

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSMutableString *s = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSMutableAttributedString *s = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
%end

%hook UIViewController

- (void)viewDidLoad { /* ... unchanged ... */ } // 省略未修改的代码
%new - (void)createOrShowMainControlPanel { /* ... unchanged ... */ } // 省略未修改的代码

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    switch (sender.tag) {
        case kButtonTag_ExtractShenSha: {
            LogMessage(EchoLogTypeTask, @"[任务] 开始最终版全量提取...");
            NSString *shenShaResult = [self extractShenShaInfo_Final];
            if (shenShaResult && shenShaResult.length > 0) {
                 NSString *finalReport = [NSString stringWithFormat:@"// 神煞详情 (最终全量版)\n%@", shenShaResult];
                 [self presentAIActionSheetWithReport:finalReport];
            } else { LogMessage(EchoLogTypeWarning, @"[结果] 神煞信息为空或提取失败。"); }
            break;
        }
        case kButtonTag_ClosePanel: [self createOrShowMainControlPanel]; break;
    }
}
%new - (void)presentAIActionSheetWithReport:(NSString *)report { /* ... unchanged ... */ } // 省略未修改的代码


// =========================================================================
// 3. 核心提取函数 (最终完美版 - 支持多 Section)
// =========================================================================
%new
- (NSString *)extractShenShaInfo_Final {
    // 1. 定位神煞主容器视图
    Class shenShaViewClass = NSClassFromString(@"六壬大占.神煞行年視圖"); // 直接使用已确认的类名
    if (!shenShaViewClass) {
        LogMessage(EchoLogError, @"[神煞] 错误: 找不到类 '六壬大占.神煞行年視圖'。");
        return @"[神煞提取失败: 找不到视图类]";
    }

    NSMutableArray *shenShaViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(shenShaViewClass, self.view, shenShaViews);
    if (shenShaViews.count == 0) {
        LogMessage(EchoLogTypeWarning, @"[神煞] 未在当前界面找到神煞主容器实例。");
        return @"";
    }
    UIView *containerView = shenShaViews.firstObject;

    // 2. 找到唯一的 UICollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews);
    if (collectionViews.count == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 在主容器内找不到 UICollectionView。");
        return @"[神煞提取失败: 找不到集合视图]";
    }
    UICollectionView *collectionView = collectionViews.firstObject;
    
    // 3. 【核心改动】处理多 Section
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
    NSInteger numberOfSections = collectionView.numberOfSections;

    if (!dataSource || numberOfSections == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 无数据源或 Section 数量为0。");
        return @"[神煞提取失败: 无数据]";
    }
    
    LogMessage(EchoLogTypeInfo, @"[神煞] 发现 %ld 个 Section，开始完整遍历...", (long)numberOfSections);

    // 4. 智能查找所有分类标题
    NSMutableArray *allLabelsInContainer = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], containerView, allLabelsInContainer);
    NSMutableArray *titleLabels = [NSMutableArray array];
    for (UILabel *label in allLabelsInContainer) {
        BOOL isInCell = NO; UIView *superview = label.superview;
        while (superview && superview != containerView) {
            if ([superview isKindOfClass:[UICollectionViewCell class]]) { isInCell = YES; break; }
            superview = superview.superview;
        }
        if (!isInCell) { [titleLabels addObject:label]; }
    }
    [titleLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
    }];

    // 5. 遍历所有 Section 和 Item
    NSMutableString *finalResultString = [NSMutableString string];
    for (NSInteger section = 0; section < numberOfSections; section++) {
        NSInteger totalItemsInSection = [dataSource collectionView:collectionView numberOfItemsInSection:section];
        if (totalItemsInSection == 0) continue;

        NSString *categoryTitle = (section < titleLabels.count) ? ((UILabel *)titleLabels[section]).text : [NSString stringWithFormat:@"分类 %ld", (long)section + 1];
        categoryTitle = [categoryTitle stringByReplacingOccurrencesOfString:@":" withString:@""];
        [finalResultString appendFormat:@"\n// %@\n", categoryTitle];

        NSMutableArray<NSDictionary *> *cellDataList = [NSMutableArray array];
        for (NSInteger item = 0; item < totalItemsInSection; item++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
            UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
            if (!cell || !attributes) continue;

            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
            
            NSMutableArray *textParts = [NSMutableArray array];
            for (UILabel *label in labels) { if (label.text.length > 0) [textParts addObject:label.text]; }
            
            [cellDataList addObject:@{@"textParts": textParts, @"frame": [NSValue valueWithCGRect:attributes.frame]}];
        }
        
        // 【注意】这里排序只在 Section 内部进行，因为不同 Section 的坐标可能是重叠的
        [cellDataList sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            CGRect f1 = [o1[@"frame"] CGRectValue], f2 = [o2[@"frame"] CGRectValue];
            if (roundf(f1.origin.y) < roundf(f2.origin.y)) return NSOrderedAscending;
            if (roundf(f1.origin.y) > roundf(f2.origin.y)) return NSOrderedDescending;
            return [@(f1.origin.x) compare:@(f2.origin.x)];
        }];

        NSMutableString *categoryContent = [NSMutableString string];
        CGFloat lastY = -1.0; BOOL isFirstInRow = YES;
        for (NSDictionary *cellData in cellDataList) {
            CGRect frame = [cellData[@"frame"] CGRectValue];
            NSArray *textParts = cellData[@"textParts"];
            if (textParts.count == 0) continue;

            if (lastY >= 0 && roundf(frame.origin.y) > roundf(lastY)) {
                [categoryContent appendString:@"\n"]; isFirstInRow = YES;
            }
            if (!isFirstInRow) { [categoryContent appendString:@" |"]; }

            if (textParts.count == 1) {
                [categoryContent appendFormat:@"%@:", textParts.firstObject];
            } else if (textParts.count >= 2) {
                [categoryContent appendFormat:@" %@(%@)", textParts[0], textParts[1]];
            }
            lastY = frame.origin.y; isFirstInRow = NO;
        }
        [finalResultString appendString:categoryContent];
        [finalResultString appendString:@"\n"];
    }

    LogMessage(EchoLogTypeSuccess, @"[神煞] 所有 %ld 个 Section 完整提取成功！", (long)numberOfSections);
    return [finalResultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

%end

%ctor {
    NSLog(@"[EchoShenShaTest v_final_multisection] 已加载。");
}

