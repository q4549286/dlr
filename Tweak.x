#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数 (无变动)
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

static UIWindow* GetFrontmostWindow() { /* ... 无变动 ... */ }

// ... UIViewController (EchoShenShaTest) 接口声明 (无变动) ...
@interface UIViewController (EchoShenShaTest)
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (NSString *)extractShenShaInfo_Complete;
@end

// ... Hook (无变动) ...
%hook UILabel /* ... */ %end
%hook UIViewController /* ... */ %end

// ... 面板创建和按钮点击处理 (无变动) ...
// createOrShowMainControlPanel, handleMasterButtonTap, presentAIActionSheetWithReport

// =========================================================================
// 3. 核心提取函数 (最终修正版 - 严格限定搜索范围)
// =========================================================================
%new
- (NSString *)extractShenShaInfo_Complete {
    // 1. 【关键修正】第一步：精确找到神煞主容器视图
    NSArray *possibleClassNames = @[@"六壬大占.神煞行年視圖", @"六壬大占.行年神煞視圖", @"六壬大占.神煞視圖"];
    Class shenShaContainerClass = nil;
    for (NSString *className in possibleClassNames) {
        shenShaContainerClass = NSClassFromString(className);
        if (shenShaContainerClass) {
            LogMessage(EchoLogTypeInfo, @"[神煞] 成功匹配到主容器类: %@", className);
            break;
        }
    }
    if (!shenShaContainerClass) {
        LogMessage(EchoLogError, @"[神煞] 错误: 找不到神煞主容器视图。");
        return @"[神煞提取失败: 找不到容器类]";
    }

    NSMutableArray *shenShaContainers = [NSMutableArray array];
    FindSubviewsOfClassRecursive(shenShaContainerClass, self.view, shenShaContainers);
    if (shenShaContainers.count == 0) {
        LogMessage(EchoLogTypeWarning, @"[神煞] 未在当前界面找到神煞主容器实例。");
        return @"";
    }
    UIView *containerView = shenShaContainers.firstObject;
    LogMessage(EchoLogTypeInfo, @"[神煞] 已定位到主容器实例: %@", containerView);

    // 2. 【关键修正】第二步：只在神煞主容器内部查找 UICollectionView
    NSMutableArray<UICollectionView *> *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews);
    
    if (collectionViews.count == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 在神煞主容器内找不到任何 UICollectionView。");
        return @"[神煞提取失败: 在容器内找不到集合视图]";
    }
    
    UICollectionView *collectionView = collectionViews.firstObject;
    LogMessage(EchoLogTypeInfo, @"[神煞] 已精确定位到神煞专用的 UICollectionView: %@", collectionView);

    // 3. 获取数据源和 Section 总数
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
    if (!dataSource) {
        LogMessage(EchoLogError, @"[神煞] 错误: UICollectionView 没有数据源。");
        return @"[神煞提取失败: 找不到数据源]";
    }
    
    NSInteger totalSections = 1;
    if ([dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
        totalSections = [dataSource numberOfSectionsInCollectionView:collectionView];
    }
    LogMessage(EchoLogTypeInfo, @"[神煞] 神煞专用 CollectionView 包含 %ld 个 Section，开始全量提取...", (long)totalSections);

    // 4. 【新逻辑】智能匹配标题
    // 标题 UILabel 应该也在 containerView 内，但不在 collectionView 内
    NSMutableArray *allLabelsInContainer = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], containerView, allLabelsInContainer);
    NSMutableArray *titleLabels = [NSMutableArray array];
    for(UILabel *label in allLabelsInContainer) {
        if (![label.superview isKindOfClass:[UICollectionViewCell class]] && label.frame.origin.x < 50) { // 简单判断，标题一般在左侧
            [titleLabels addObject:label];
        }
    }
    [titleLabels sortUsingComparator:^NSComparisonResult(UILabel* obj1, UILabel* obj2) {
        return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
    }];


    // 5. 遍历所有 Section 和 Item
    NSMutableString *finalResultString = [NSMutableString string];
    for (NSInteger section = 0; section < totalSections; section++) {
        // 添加标题
        if (section < titleLabels.count) {
            NSString *title = [((UILabel *)titleLabels[section]).text stringByReplacingOccurrencesOfString:@":" withString:@""];
            [finalResultString appendFormat:@"\n// %@\n", title];
        } else {
            [finalResultString appendFormat:@"\n// 神煞分类 %ld\n", (long)section + 1];
        }

        NSInteger totalItemsInSection = [dataSource collectionView:collectionView numberOfItemsInSection:section];
        if(totalItemsInSection == 0) continue;
        
        // 提取当前 section 的所有单元格数据
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

        // 排序并格式化当前 section 的内容
        [cellDataList sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            CGRect f1 = [o1[@"frame"] CGRectValue], f2 = [o2[@"frame"] CGRectValue];
            if (roundf(f1.origin.y) < roundf(f2.origin.y)) return NSOrderedAscending;
            if (roundf(f1.origin.y) > roundf(f2.origin.y)) return NSOrderedDescending;
            return [@(f1.origin.x) compare:@(f2.origin.x)];
        }];
        
        NSMutableString *sectionContent = [NSMutableString string];
        CGFloat lastY = -1.0;
        for (NSDictionary *cellData in cellDataList) {
            CGRect frame = [cellData[@"frame"] CGRectValue];
            NSArray *textParts = cellData[@"textParts"];
            if (textParts.count == 0) continue;

            if (lastY >= 0 && roundf(frame.origin.y) > roundf(lastY)) { [sectionContent appendString:@"\n"]; }
            if (sectionContent.length > 0 && ![sectionContent hasSuffix:@"\n"]) { [sectionContent appendString:@" |"]; }

            if (textParts.count == 1) { [sectionContent appendFormat:@"%@:", textParts.firstObject]; }
            else if (textParts.count >= 2) { [sectionContent appendFormat:@" %@(%@)", textParts[0], textParts[1]]; }
            
            lastY = frame.origin.y;
        }
        [finalResultString appendString:sectionContent];
        [finalResultString appendString:@"\n"];
    }
    
    LogMessage(EchoLogTypeSuccess, @"[神煞] 所有 Section 完整提取成功！");
    return [finalResultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

%end

// ... %ctor (无变动) ...

%ctor {
    NSLog(@"[EchoShenShaTest v_final] 多 Section 提取脚本已加载。");
}

