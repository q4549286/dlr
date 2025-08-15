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

// 【新增】指定要提取的 Section 标题
static NSString *kTargetSectionTitle = @"支煞"; // 【请在这里输入您要提取的Section的标题文本】

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
- (NSString *)extractShenShaInfo_Targeted;
@end

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSMutableString *s = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSMutableAttributedString *s = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)s.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(s); }
%end


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview];
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"Echo 神煞测试" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; return;
    }
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    if (@available(iOS 8.0, *)) {
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blurView.frame = g_mainControlPanelView.bounds; [g_mainControlPanelView addSubview:blurView];
    } else { g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9]; }
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 80)];
    [g_mainControlPanelView addSubview:contentView];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, contentView.bounds.size.width, 30)];
    titleLabel.text = @"Echo 神煞提取 (定Section)"; titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor whiteColor]; titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    
    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [extractButton setTitle:@"提取指定神煞信息" forState:UIControlStateNormal];
    extractButton.tag = kButtonTag_ExtractShenSha; extractButton.backgroundColor = ECHO_COLOR_MAIN_TEAL;
    [extractButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:18]; extractButton.layer.cornerRadius = 12;
    extractButton.frame = CGRectMake(15, 80, contentView.bounds.size.width - 30, 50);
    [contentView addSubview:extractButton];

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, 150, contentView.bounds.size.width, contentView.bounds.size.height - 210)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7]; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8; g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.text = @"[EchoShenShaTest]: 就绪。\n"; [contentView addSubview:g_logTextView];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [closeButton setTitle:@"关闭面板" forState:UIControlStateNormal]; closeButton.tag = kButtonTag_ClosePanel;
    closeButton.backgroundColor = ECHO_COLOR_ACTION_CLOSE;
    [closeButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    closeButton.layer.cornerRadius = 10; closeButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, contentView.bounds.size.width - 30, 40);
    [contentView addSubview:closeButton];

    g_mainControlPanelView.alpha = 0; [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    switch (sender.tag) {
        case kButtonTag_ExtractShenSha: {
            LogMessage(EchoLogTypeTask, @"[任务] 开始提取指定神煞信息...");
            NSString *shenShaResult = [self extractShenShaInfo_Targeted];
            if (shenShaResult && shenShaResult.length > 0) {
                 NSString *finalReport = [NSString stringWithFormat:@"// 神煞详情 (指定Section)\n%@", shenShaResult];
                 [self presentAIActionSheetWithReport:finalReport];
            } else { LogMessage(EchoLogTypeWarning, @"[结果] 神煞信息为空或提取失败。"); }
            break;
        }
        case kButtonTag_ClosePanel: [self createOrShowMainControlPanel]; break;
    }
}

%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) { LogMessage(EchoLogError, @"报告为空，无法执行后续操作。"); return; }
    [UIPasteboard generalPasteboard].string = report; 
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"神煞提取结果" message:@"内容已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"确认 (已复制)" style:UIAlertActionStyleDefault handler:nil];
    [actionSheet addAction:copyAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    if (actionSheet.popoverPresentationController) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height, 1.0, 1.0);
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}


// =========================================================================
// 3. 核心提取函数 (最终版 - 指定Section)
// =========================================================================

%new
- (NSString *)extractShenShaInfo_Targeted {
    // 0. 【重要】请务必在这里设置您要提取的 Section 标题
    NSString *targetSectionTitle = kTargetSectionTitle;
    if (!targetSectionTitle || targetSectionTitle.length == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 尚未设置目标 Section 的标题 (请修改 kTargetSectionTitle)。");
        return @"[神煞提取失败: 尚未设置目标Section标题]";
    }
    LogMessage(EchoLogTypeInfo, @"[神煞] 目标 Section 标题: %@", targetSectionTitle);

    // 1. 定位神煞容器视图的类
    NSArray *possibleClassNames = @[@"六壬大占.行年神煞視圖", @"六壬大占.神煞行年視圖", @"六壬大占.神煞視圖"];
    Class shenShaViewClass = nil;
    for (NSString *className in possibleClassNames) {
        shenShaViewClass = NSClassFromString(className);
        if (shenShaViewClass) { LogMessage(EchoLogTypeInfo, @"[神煞] 成功匹配到类: %@", className); break; }
    }
    if (!shenShaViewClass) {
        LogMessage(EchoLogError, @"[神煞] 错误: 找不到神煞容器视图。");
        return @"[神煞提取失败: 找不到视图类]";
    }

    // 2. 找到神煞容器视图实例
    NSMutableArray *shenShaViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(shenShaViewClass, self.view, shenShaViews);
    if (shenShaViews.count == 0) {
        LogMessage(EchoLogTypeWarning, @"[神煞] 未在当前界面找到神煞视图实例。");
        return @"";
    }
    UIView *containerView = shenShaViews.firstObject;

    // 3. 找到 UICollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews);
    if (collectionViews.count == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 在神煞视图内找不到 UICollectionView。");
        return @"[神煞提取失败: 找不到集合视图]";
    }
    UICollectionView *collectionView = collectionViews.firstObject;
    
    // 4. 获取数据源
    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
    if (!dataSource) {
        LogMessage(EchoLogError, @"[神煞] 错误: UICollectionView 没有数据源 (dataSource)。");
        return @"[神煞提取失败: 找不到数据源]";
    }
    
    NSInteger totalItems = [dataSource collectionView:collectionView numberOfItemsInSection:0];
    if (totalItems == 0) {
        LogMessage(EchoLogTypeInfo, @"[神煞] 信息为空 (数据源返回0项)。");
        return @"";
    }
    
    LogMessage(EchoLogTypeInfo, @"[神煞] 发现总计 %ld 个神煞单元，开始全量提取...", (long)totalItems);

    // 5. 遍历所有单元格，寻找目标 Section 的起始位置
    NSInteger startIndex = -1;
    for (NSInteger i = 0; i < totalItems; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
        
        // 查找 Cell 内部的 UILabel, 看看有没有 Section 标题
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);

        //如果该Cell包含标题Label
        for(UILabel* label in labels) {
            if ([label.text isEqualToString:targetSectionTitle]) {
                startIndex = i;
                LogMessage(EchoLogTypeInfo, @"[神煞] 找到目标 Section 的起始索引: %ld", (long)startIndex);
                break;
            }
        }
        if (startIndex >= 0) break; // 找到起始位置，退出循环
    }

    if (startIndex == -1) {
        LogMessage(EchoLogError, @"[神煞] 错误: 没有找到标题为 '%@' 的 Section。", targetSectionTitle);
        return [NSString stringWithFormat:@"[神煞提取失败: 找不到目标Section (标题: %@)]", targetSectionTitle];
    }

    // 6. 从目标 Section 的起始位置开始，提取数据
    NSMutableString *resultString = [NSMutableString string];
    CGFloat lastY = -1.0;
    BOOL isFirstInRow = YES;

    for (NSInteger i = startIndex; i < totalItems; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0];
        UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
        UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
        
        if (!cell || !attributes) continue;

        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
        [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
            return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
        }];

        NSMutableArray *textParts = [NSMutableArray array];
        for (UILabel *label in labels) {
            if (label.text.length > 0) {
                [textParts addObject:label.text];
            }
        }
        
        if (textParts.count == 0) continue;

        CGRect frame = attributes.frame;
        if (lastY >= 0 && roundf(frame.origin.y) > roundf(lastY)) {
            [resultString appendString:@"\n"];
            isFirstInRow = YES;
        }

        if (!isFirstInRow) {
             [resultString appendString:@" |"];
        }

        if (textParts.count == 1) {
            [resultString appendFormat:@"%@:", textParts.firstObject];
        } else if (textParts.count >= 2) {
            [resultString appendFormat:@" %@(%@)", textParts[0], textParts[1]];
        }
        
        lastY = frame.origin.y;
        isFirstInRow = NO;
    }
    
    LogMessage(EchoLogTypeSuccess, @"[神煞] 成功提取指定 Section 的信息，共 %lu 条记录。", (unsigned long)(totalItems - startIndex));
    return [resultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

%end

%ctor {
    NSLog(@"[EchoShenShaTest v_targeted] 定目标Section测试脚本已加载。");
}

