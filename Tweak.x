////////// Filename: Echo_AnalysisEngine_v15.1_FinalSyntaxFix.xm
// 描述: Echo 六壬解析引擎 v15.1 (最终语法修正版)。此版本修复了v15.0中因缺少`%end`导致的致命编译错误。
//       - [CRITICAL FIX] 将所有新增的方法正确放置于`%hook UIViewController`块内，并添加了缺失的`%end`。
//       - [FINAL] 这是所有功能、UI和无感提取机制的最终稳定版本，是功能与体验的完美结合。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、宏定义与辅助函数
// =========================================================================

#pragma mark - Global State & Flags
static UITextView *g_logTextView = nil;
static UIView *g_mainControlPanelView = nil;
static NSString *g_s2_baseTextCacheForPowerMode = nil;
static BOOL g_s1_isExtracting = NO;
static NSString *g_s1_currentTaskType = nil;
static BOOL g_s1_shouldIncludeXiangJie = NO;
static NSMutableArray *g_s1_keTi_workQueue = nil;
static NSMutableArray *g_s1_keTi_resultsArray = nil;
static UICollectionView *g_s1_keTi_targetCV = nil;
static BOOL g_s2_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_s2_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_s2_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_s2_keChuanTitleQueue = nil;
static NSString *g_s2_finalResultFromKeChuan = nil;
static void (^g_s2_keChuan_completion_handler)(void) = nil;
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;
static BOOL g_isHijacking = NO;

static NSString * const CustomFooterText = @"\n\n"
"// 由 Echo 六壬解析引擎呈现\n"
"// 数据为系统性参考，决策需审慎。";

#define SafeString(str) (str ?: @"")

#pragma mark - Helper Functions
typedef NS_ENUM(NSInteger, EchoLogType) {
    EchoLogTypeInfo,
    EchoLogTypeTask,
    EchoLogTypeSuccess,
    EchoLogTypeWarning,
    EchoLogError
};

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
            case EchoLogTypeTask:       color = [UIColor whiteColor]; break;
            case EchoLogTypeSuccess:    color = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]; break;
            case EchoLogTypeWarning:    color = [UIColor orangeColor]; break;
            case EchoLogError:          color = [UIColor redColor]; break;
            case EchoLogTypeInfo:
            default:                    color = [UIColor lightGrayColor]; break;
        }
        
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        if (g_logTextView.font) {
            [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        }

        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText];
        g_logTextView.attributedText = logLine;

        NSLog(@"[Echo解析引擎] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static UIWindow* GetFrontmostWindow() { UIWindow *frontmostWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } } if (frontmostWindow) break; } } } if (!frontmostWindow) { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
    frontmostWindow = [UIApplication sharedApplication].keyWindow; \
    _Pragma("clang diagnostic pop") \
    } return frontmostWindow; }

// =========================================================================
// 2. 接口声明、UI微调与核心Hook
// =========================================================================

@interface UIViewController (EchoAnalysisEngine)
- (void)createOrShowMainControlPanel; - (void)handleMasterButtonTap:(UIButton *)sender; - (void)showProgressHUD:(NSString *)text; - (void)updateProgressHUD:(NSString *)text; - (void)hideProgressHUD; - (void)copyLogAndClose;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include; - (void)processKeTiWorkQueue_S1;
- (void)executeSimpleExtraction; - (void)executeCompositeExtraction; - (void)extractSinglePopupInfoWithTaskName:(NSString*)taskName;
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion; - (void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion; - (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion; - (void)processKeChuanQueue_Truth_S2;
- (NSString *)formatDataFromOffscreenView:(UIView *)contentView forDataType:(NSString *)dataType;
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView; - (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator; - (NSString *)extractTianDiPanInfo_V18; - (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix; - (NSString *)GetStringFromLayer:(id)layer;
@end

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie);

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isHijacking) {
        LogMessage(EchoLogTypeInfo, @"[无感模式] 拦截到弹窗: %@，已阻止。", NSStringFromClass([vcToPresent class]));
        return;
    }

    if (g_s1_isExtracting) { if ([NSStringFromClass([vcToPresent class]) containsString:@"課體概覽視圖"]) { vcToPresent.view.alpha = 0.0f; animated = NO; void (^extractionCompletion)(void) = ^{ if (completion) { completion(); } NSString *extractedText = extractDataFromSplitView_S1(vcToPresent.view, g_s1_shouldIncludeXiangJie); if ([g_s1_currentTaskType isEqualToString:@"KeTi"]) { [g_s1_keTi_resultsArray addObject:extractedText]; LogMessage(EchoLogTypeSuccess, @"[解析] 成功处理“课体范式”第 %lu 项...", (unsigned long)g_s1_keTi_resultsArray.count); [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeTiWorkQueue_S1]; }); }]; } else if ([g_s1_currentTaskType isEqualToString:@"JiuZongMen"]) { LogMessage(EchoLogTypeSuccess, @"[解析] 成功处理“九宗门结构”..."); [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"// 九宗门结构\n\n%@", extractedText]; [self showEchoNotificationWithTitle:@"专项分析完成" message:@"九宗门结构已同步至剪贴板"]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; [vcToPresent dismissViewControllerAnimated:NO completion:nil]; } }; Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion); return; } }
    else if (g_s2_isExtractingKeChuanDetail) { NSString *vcClassName = NSStringFromClass([vcToPresent class]); if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) { vcToPresent.view.alpha = 0.0f; animated = NO; void (^newCompletion)(void) = ^{ if (completion) { completion(); } UIView *contentView = vcToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray<NSString *> *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } [g_s2_capturedKeChuanDetailArray addObject:[textParts componentsJoinedByString:@"\n"]]; LogMessage(EchoLogTypeSuccess, @"[课传] 成功捕获内容 (共 %lu 条)", (unsigned long)g_s2_capturedKeChuanDetailArray.count); [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeChuanQueue_Truth_S2]; }); }]; }; Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion); return; } }
    else if (g_isExtractingNianming) { NSString *vcClassName = NSStringFromClass([vcToPresent class]); if ([vcClassName containsString:@"年命摘要視圖"] || [vcClassName containsString:@"年命格局視圖"]) { vcToPresent.view.alpha = 0.0f; animated = NO; __weak typeof(self) weakSelf = self; if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) { UIView *contentView = vcToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } } [g_capturedZhaiYaoArray addObject:[[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; [vcToPresent dismissViewControllerAnimated:NO completion:nil]; return; } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) { void (^newCompletion)(void) = ^{ if (completion) { completion(); } dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; UIView *contentView = vcToPresent.view; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return; [g_capturedGeJuArray addObject:[strongSelf2 formatNianmingGejuFromView:contentView]]; [vcToPresent dismissViewControllerAnimated:NO completion:nil]; }); }); }; Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion); return; } } }
    
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 3. UI, 任务分发与核心逻辑实现
// =========================================================================

%hook UIViewController

- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; NSInteger controlButtonTag = 556699; if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; } UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem]; controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36); controlButton.tag = controlButtonTag;
    [controlButton setTitle:@"Echo 解析" forState:UIControlStateNormal];
    controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    controlButton.backgroundColor = [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0];
    [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; controlButton.layer.cornerRadius = 18; controlButton.layer.shadowColor = [UIColor blackColor].CGColor; controlButton.layer.shadowOffset = CGSizeMake(0, 2); controlButton.layer.shadowOpacity = 0.4; controlButton.layer.shadowRadius = 3; [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside]; [keyWindow addSubview:controlButton]; }); } }

%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    NSInteger panelTag = 778899;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) { [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; }]; return; }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds]; g_mainControlPanelView.tag = panelTag; g_mainControlPanelView.backgroundColor = [UIColor clearColor];
    if (@available(iOS 8.0, *)) {
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blurView.frame = g_mainControlPanelView.bounds; [g_mainControlPanelView addSubview:blurView];
    } else {
        g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    }
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 80)]; [g_mainControlPanelView addSubview:contentView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, contentView.bounds.size.width, 40)];
    titleLabel.text = @"Echo 六壬解析引擎 v15.1";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter; [contentView addSubview:titleLabel];
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, contentView.bounds.size.width, contentView.bounds.size.height - 120)]; [contentView addSubview:scrollView];

    CGFloat currentY = 15;
    UIButton* (^createButton)(NSString*, NSInteger, UIColor*) = ^(NSString* title, NSInteger tag, UIColor* color) { UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem]; [btn setTitle:title forState:UIControlStateNormal]; btn.tag = tag; btn.backgroundColor = color; [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; btn.titleLabel.font = [UIFont boldSystemFontOfSize:15]; btn.titleLabel.adjustsFontSizeToFitWidth = YES; btn.titleLabel.minimumScaleFactor = 0.8; btn.layer.cornerRadius = 10; return btn; };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) { UILabel *label = [[UILabel alloc] init]; label.text = title; label.font = [UIFont boldSystemFontOfSize:18]; label.textColor = [UIColor lightGrayColor]; return label; };
    
    UILabel *sec1Title = createSectionTitle(@"核心解析");
    sec1Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22); [scrollView addSubview:sec1Title]; currentY += 35;
    UIButton *easyModeBtn = createButton(@"标准报告", 101, [UIColor colorWithRed:0.1 green:0.53 blue:0.53 alpha:1.0]);
    easyModeBtn.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 48); [scrollView addSubview:easyModeBtn]; currentY += 58;
    UIButton *powerModeBtn = createButton(@"深度解构", 102, [UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0]);
    powerModeBtn.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 48); [scrollView addSubview:powerModeBtn]; currentY += 70;
    
    UILabel *sec2Title = createSectionTitle(@"专项分析");
    sec2Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22); [scrollView addSubview:sec2Title]; currentY += 35;
    NSArray *coreButtons = @[ @{@"title": @"课体范式 (详)", @"tag": @(201)}, @{@"title": @"课体范式 (简)", @"tag": @(202)}, @{@"title": @"九宗门结构 (详)", @"tag": @(203)}, @{@"title": @"九宗门结构 (简)", @"tag": @(204)}, @{@"title": @"课传流注", @"tag": @(301)}, @{@"title": @"行年参数", @"tag": @(302)} ];
    CGFloat btnWidth = (scrollView.bounds.size.width - 45) / 2.0;
    for (int i=0; i<coreButtons.count; i++) { NSDictionary *config = coreButtons[i]; UIButton *btn = createButton(config[@"title"], [config[@"tag"] integerValue], [UIColor colorWithWhite:0.35 alpha:1.0]); btn.frame = CGRectMake(15 + (i % 2) * (btnWidth + 15), currentY + (i / 2) * 58, btnWidth, 46); [scrollView addSubview:btn]; }
    currentY += ((coreButtons.count + 1) / 2) * 58 + 20;
    
    UILabel *sec3Title = createSectionTitle(@"格局资料库");
    sec3Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22); [scrollView addSubview:sec3Title]; currentY += 35;
    NSArray *auxButtons = @[ @{@"title": @"毕法要诀", @"tag": @(303)}, @{@"title": @"格局要览", @"tag": @(304)}, @{@"title": @"十八方法", @"tag": @(305)} ];
    btnWidth = (scrollView.bounds.size.width - 45) / 3.0;
    for (int i=0; i<auxButtons.count; i++) { NSDictionary *config = auxButtons[i]; UIButton *btn = createButton(config[@"title"], [config[@"tag"] integerValue], [UIColor colorWithWhite:0.5 alpha:1.0]); btn.frame = CGRectMake(15 + i * (btnWidth + 7.5), currentY, btnWidth, 46); [scrollView addSubview:btn]; }
    currentY += 56;

    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY);
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, contentView.bounds.size.height - 230, contentView.bounds.size.width, 170)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8;
    NSMutableAttributedString *initLog = [[NSMutableAttributedString alloc] initWithString:@"[Echo引擎]：就绪。\n"];
    [initLog addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, initLog.length)];
    if (g_logTextView.font) {
        [initLog addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, initLog.length)];
    }
    g_logTextView.attributedText = initLog;
    [contentView addSubview:g_logTextView];
    
    UIButton *copyButton = createButton(@"复制日志并关闭", 999, [UIColor darkGrayColor]);
    copyButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, contentView.bounds.size.width - 30, 40); [contentView addSubview:copyButton];
    g_mainControlPanelView.alpha = 0; [keyWindow addSubview:g_mainControlPanelView]; [UIView animateWithDuration:0.4 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)copyLogAndClose { if (g_logTextView && g_logTextView.text.length > 0) { [UIPasteboard generalPasteboard].string = g_logTextView.text; LogMessage(EchoLogTypeTask, @"日志内容已同步至剪贴板。"); } [self handleMasterButtonTap:nil]; }
%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    if (!sender) { if (g_mainControlPanelView) { [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; }]; } return; }
    if (g_s1_isExtracting || g_s2_isExtractingKeChuanDetail || g_isExtractingNianming || g_isHijacking) { LogMessage(EchoLogError, @"[错误] 当前有任务在后台运行，请等待完成后重试。"); return; }
    switch (sender.tag) {
        case 999: [self copyLogAndClose]; break;
        case 101: [self executeSimpleExtraction]; break;
        case 102: [self executeCompositeExtraction]; break;
        case 201: [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:YES]; break;
        case 202: [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:NO]; break;
        case 203: [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES]; break;
        case 204: [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:NO]; break;
        case 301: [self startExtraction_Truth_S2_WithCompletion:^{ [self showEchoNotificationWithTitle:@"分析完成" message:@"课传流注已同步至剪贴板。"]; }]; break;
        case 302: [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) { [self hideProgressHUD]; [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"// 行年参数\n\n%@", nianmingText]; [self showEchoNotificationWithTitle:@"分析完成" message:@"行年参数已同步至剪贴板。"]; }]; break;
        case 303: [self extractSinglePopupInfoWithTaskName:@"毕法要诀"]; break;
        case 304: [self extractSinglePopupInfoWithTaskName:@"格局要览"]; break;
        case 305: [self extractSinglePopupInfoWithTaskName:@"十八方法"]; break;
        default: break;
    }
}
%new
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    NSInteger progressViewTag = 556677;
    UIView *existing = [keyWindow viewWithTag:progressViewTag];
    if(existing) [existing removeFromSuperview];
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)];
    progressView.center = keyWindow.center;
    progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    progressView.layer.cornerRadius = 10;
    progressView.tag = progressViewTag;
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor];
    
    spinner.center = CGPointMake(110, 50);
    [spinner startAnimating];
    [progressView addSubview:spinner];
    
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)];
    progressLabel.textColor = [UIColor whiteColor];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.font = [UIFont systemFontOfSize:14];
    progressLabel.adjustsFontSizeToFitWidth = YES;
    progressLabel.text = text;
    [progressView addSubview:progressLabel];
    
    [keyWindow addSubview:progressView];
}
%new
- (void)updateProgressHUD:(NSString *)text { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; UIView *progressView = [keyWindow viewWithTag:556677]; if (progressView) { for (UIView *subview in progressView.subviews) { if ([subview isKindOfClass:[UILabel class]]) { ((UILabel *)subview).text = text; break; } } } }
%new
- (void)hideProgressHUD { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; UIView *progressView = [keyWindow viewWithTag:556677]; if (progressView) { [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }]; } }

%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) return;

    CGFloat topPadding = 0;
    if (@available(iOS 11.0, *)) { topPadding = keyWindow.safeAreaInsets.top; }
    topPadding = topPadding > 0 ? topPadding : 20;

    CGFloat bannerWidth = keyWindow.bounds.size.width - 32;
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, -100, bannerWidth, 60)];
    bannerView.layer.cornerRadius = 12;
    bannerView.clipsToBounds = YES;
    
    if (@available(iOS 8.0, *)) {
        UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]];
        blurEffectView.frame = bannerView.bounds;
        [bannerView addSubview:blurEffectView];
    } else {
        bannerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    }

    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, 20, 20)];
    iconLabel.text = @"✓";
    iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
    iconLabel.font = [UIFont boldSystemFontOfSize:16];
    [bannerView addSubview:iconLabel];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, bannerWidth - 55, 20)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    if (@available(iOS 13.0, *)) { titleLabel.textColor = [UIColor labelColor]; } else { titleLabel.textColor = [UIColor blackColor];}
    [bannerView addSubview:titleLabel];

    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, bannerWidth - 55, 16)];
    messageLabel.text = message;
    messageLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 13.0, *)) { messageLabel.textColor = [UIColor secondaryLabelColor]; } else { messageLabel.textColor = [UIColor darkGrayColor]; }
    [bannerView addSubview:messageLabel];
    
    [keyWindow addSubview:bannerView];

    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        bannerView.frame = CGRectMake(16, topPadding, bannerWidth, 60);
    } completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            bannerView.alpha = 0;
            bannerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [bannerView removeFromSuperview];
        }];
    });
}

#pragma mark - Extraction Logic & Launchers
%new
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include { g_s1_isExtracting = YES; g_s1_currentTaskType = taskType; g_s1_shouldIncludeXiangJie = include; LogMessage(EchoLogTypeTask, @"[任务启动] 模式: %@ (详情: %@)", taskType, include ? @"开启" : @"关闭"); if ([taskType isEqualToString:@"KeTi"]) { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) { LogMessage(EchoLogError, @"[错误] 无法找到主窗口。"); g_s1_isExtracting = NO; return; } Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元"); if (!keTiCellClass) { LogMessage(EchoLogError, @"[错误] 无法找到 '課體單元' 类。"); g_s1_isExtracting = NO; return; } NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs); for (UICollectionView *cv in allCVs) { for (id cell in cv.visibleCells) { if ([cell isKindOfClass:keTiCellClass]) { g_s1_keTi_targetCV = cv; break; } } if(g_s1_keTi_targetCV) break; } if (!g_s1_keTi_targetCV) { LogMessage(EchoLogError, @"[错误] 无法找到包含“课体”的UICollectionView。"); g_s1_isExtracting = NO; return; } g_s1_keTi_workQueue = [NSMutableArray array]; g_s1_keTi_resultsArray = [NSMutableArray array]; NSInteger totalItems = [g_s1_keTi_targetCV.dataSource collectionView:g_s1_keTi_targetCV numberOfItemsInSection:0]; for (NSInteger i = 0; i < totalItems; i++) { [g_s1_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; } if (g_s1_keTi_workQueue.count == 0) { LogMessage(EchoLogTypeWarning, @"[警告] 未找到任何“课体”单元来创建任务队列。"); g_s1_isExtracting = NO; return; } LogMessage(EchoLogTypeInfo, @"[解析] 发现 %lu 个“课体范式”单元，开始处理...", (unsigned long)g_s1_keTi_workQueue.count); [self processKeTiWorkQueue_S1]; } else if ([taskType isEqualToString:@"JiuZongMen"]) { SEL selector = NSSelectorFromString(@"顯示九宗門概覽"); if ([self respondsToSelector:selector]) { LogMessage(EchoLogTypeInfo, @"[调用] 正在请求“九宗门”数据..."); SUPPRESS_LEAK_WARNING([self performSelector:selector]); } else { LogMessage(EchoLogError, @"[错误] 当前视图无法响应 '顯示九宗門概覽'。"); g_s1_isExtracting = NO; } } }
%new
- (void)processKeTiWorkQueue_S1 { if (g_s1_keTi_workQueue.count == 0) { LogMessage(EchoLogTypeTask, @"[完成] 所有 %lu 项“课体范式”处理完毕。", (unsigned long)g_s1_keTi_resultsArray.count); NSMutableString *finalResult = [NSMutableString string]; for (NSUInteger i = 0; i < g_s1_keTi_resultsArray.count; i++) { NSString *itemText = g_s1_keTi_resultsArray[i]; NSArray *lines = [itemText componentsSeparatedByString:@"\n"]; NSString *itemTitle = (lines.count > 0 && [lines[0] containsString:@"课"]) ? lines[0] : [NSString stringWithFormat:@"未知课体 %lu", (unsigned long)i+1]; NSRange titleRange = [itemText rangeOfString:itemTitle]; NSString *content = (titleRange.location != NSNotFound) ? [itemText stringByReplacingCharactersInRange:titleRange withString:@""] : itemText; content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; [finalResult appendFormat:@"// %@\n\n%@\n\n\n", itemTitle, content]; } [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; [self showEchoNotificationWithTitle:@"批量分析完成" message:@"课体范式已全部同步。"]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_keTi_targetCV = nil; g_s1_keTi_workQueue = nil; g_s1_keTi_resultsArray = nil; return; } NSIndexPath *indexPath = g_s1_keTi_workQueue.firstObject; [g_s1_keTi_workQueue removeObjectAtIndex:0]; LogMessage(EchoLogTypeInfo, @"[解析] 正在处理“课体范式” %lu/%lu...", (unsigned long)(g_s1_keTi_resultsArray.count + 1), (unsigned long)(g_s1_keTi_resultsArray.count + g_s1_keTi_workQueue.count + 1)); id delegate = g_s1_keTi_targetCV.delegate; if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [delegate collectionView:g_s1_keTi_targetCV didSelectItemAtIndexPath:indexPath]; } else { LogMessage(EchoLogError, @"[错误] 无法触发单元点击事件。"); [self processKeTiWorkQueue_S1]; } }
%new
- (void)executeSimpleExtraction { LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 标准报告"); [self showProgressHUD:@"正在生成标准报告..."]; g_isHijacking = YES; [self extractKePanInfoWithCompletion:^(NSString *kePanText) { [self updateProgressHUD:@"正在分析行年参数..."]; [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) { g_isHijacking = NO; [self hideProgressHUD]; NSString *finalCombinedText; if (nianmingText && nianmingText.length > 0) { finalCombinedText = [NSString stringWithFormat:@"%@\n\n// 行年参数\n\n%@%@", kePanText, nianmingText, CustomFooterText]; } else { finalCombinedText = [NSString stringWithFormat:@"%@%@", kePanText, CustomFooterText]; } [UIPasteboard generalPasteboard].string = [finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; 
    [self showEchoNotificationWithTitle:@"生成完毕" message:@"标准报告已同步至剪贴板。"];
    LogMessage(EchoLogTypeTask, @"[完成] “标准报告”任务已完成。"); }]; }]; }
%new
- (void)executeCompositeExtraction { LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 深度解构"); [self showProgressHUD:@"步骤 1/3: 解析基础盘面..."]; g_isHijacking = YES; [self extractKePanInfoWithCompletion:^(NSString *kePanText) { g_s2_baseTextCacheForPowerMode = kePanText; LogMessage(EchoLogTypeSuccess, @"[解构] 基础盘面解析完成。"); [self updateProgressHUD:@"步骤 2/3: 推演课传流注..."]; [self startExtraction_Truth_S2_WithCompletion:^{ LogMessage(EchoLogTypeSuccess, @"[解构] 课传流注推演完成。"); [self updateProgressHUD:@"步骤 3/3: 分析行年参数..."]; [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) { g_isHijacking = NO; [self hideProgressHUD]; LogMessage(EchoLogTypeSuccess, @"[解构] 行年参数分析完成。"); NSMutableString *finalResult = [g_s2_baseTextCacheForPowerMode mutableCopy]; if (g_s2_finalResultFromKeChuan.length > 0) { [finalResult appendFormat:@"\n\n// 课传流注\n\n%@", g_s2_finalResultFromKeChuan]; } if (nianmingText.length > 0) { NSString *formattedNianming = [nianmingText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; [finalResult appendFormat:@"\n\n// 行年参数\n\n%@", formattedNianming]; } [finalResult appendString:CustomFooterText]; [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self showEchoNotificationWithTitle:@"解构完成" message:@"深度解构报告已合并并同步。"];
    LogMessage(EchoLogTypeTask, @"--- [完成] “深度解构”任务已全部完成 ---"); g_s2_baseTextCacheForPowerMode = nil; g_s2_finalResultFromKeChuan = nil; }]; }]; }]; }
%new
- (void)extractSinglePopupInfoWithTaskName:(NSString*)taskName {
    LogMessage(EchoLogTypeTask, @"[专项分析] 任务启动: %@", taskName);
    [self showProgressHUD:[NSString stringWithFormat:@"正在分析: %@", taskName]];
    g_isHijacking = YES;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        g_extractedData = [NSMutableDictionary new];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if ([taskName isEqualToString:@"毕法要诀"]) {
                SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示法訣總覽")]);
            } else if ([taskName isEqualToString:@"格局要览"]) {
                SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示格局總覽")]);
            } else if ([taskName isEqualToString:@"十八方法"]) {
                SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示方法總覽")]);
            }
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_isHijacking = NO;
            [self hideProgressHUD];
            
            NSString *result = g_extractedData[taskName];
            if (result.length > 0) {
                NSString *cleanResult = [result stringByReplacingOccurrencesOfString:@"通类门→" withString:@""];
                cleanResult = [cleanResult stringByReplacingOccurrencesOfString:@"通類門→" withString:@""];
                [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"// %@\n\n%@", taskName, [cleanResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                [self showEchoNotificationWithTitle:@"分析完成" message:[NSString stringWithFormat:@"%@ 已同步至剪贴板。", taskName]];
            } else {
                LogMessage(EchoLogTypeWarning, @"[警告] %@ 分析失败或无内容。", taskName);
            }
            g_extractedData = nil;
        });
    });
}
%new
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion { if (g_s2_isExtractingKeChuanDetail) { LogMessage(EchoLogError, @"[错误] 课传推演任务已在进行中。"); return; } LogMessage(EchoLogTypeTask, @"[任务启动] 开始推演“课传流注”..."); [self showProgressHUD:@"正在推演课传流注..."]; g_s2_isExtractingKeChuanDetail = YES; g_s2_keChuan_completion_handler = completion; g_s2_capturedKeChuanDetailArray = [NSMutableArray array]; g_s2_keChuanWorkQueue = [NSMutableArray array]; g_s2_keChuanTitleQueue = [NSMutableArray array]; Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳"); if (!keChuanContainerIvar) { LogMessage(EchoLogError, @"[错误] 无法定位核心组件'課傳'。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; [self hideProgressHUD]; return; } id keChuanContainer = object_getIvar(self, keChuanContainerIvar); if (!keChuanContainer) { LogMessage(EchoLogError, @"[错误] 核心组件'課傳'未初始化。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; [self hideProgressHUD]; return; } Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖"); NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults); if (sanChuanResults.count > 0) { UIView *sanChuanContainer = sanChuanResults.firstObject; const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"}; for (int i = 0; ivarNames[i] != NULL; ++i) { Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue; UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(labels.count >= 2) { UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1]; if (dizhiLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"taskType": @"diZhi"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]]; } if (tianjiangLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"taskType": @"tianJiang"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]]; } } } } Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖"); NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults); if (siKeResults.count > 0) { UIView *siKeContainer = siKeResults.firstObject; NSDictionary *keDefs[] = { @{@"t": @"第一课", @"x": @"日", @"s": @"日上", @"j": @"日上天將"}, @{@"t": @"第二课", @"x": @"日上", @"s": @"日陰", @"j": @"日陰天將"}, @{@"t": @"第三课", @"x": @"辰", @"s": @"辰上", @"j": @"辰上天將"}, @{@"t": @"第四课", @"x": @"辰上", @"s": @"辰陰", @"j": @"辰陰天將"}}; void (^addTask)(const char*, NSString*, NSString*) = ^(const char* iName, NSString* fTitle, NSString* tType) { if (!iName) return; Ivar ivar = class_getInstanceVariable(siKeContainerClass, iName); if (ivar) { UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar); if (label.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"taskType": tType} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", fTitle, label.text]]; } } }; for (int i = 0; i < 4; ++i) { NSDictionary *d = keDefs[i]; addTask([d[@"x"] UTF8String], [NSString stringWithFormat:@"%@ - 下神", d[@"t"]], @"diZhi"); addTask([d[@"s"] UTF8String], [NSString stringWithFormat:@"%@ - 上神", d[@"t"]], @"diZhi"); addTask([d[@"j"] UTF8String], [NSString stringWithFormat:@"%@ - 天将", d[@"t"]], @"tianJiang"); } } if (g_s2_keChuanWorkQueue.count == 0) { LogMessage(EchoLogTypeWarning, @"[课传] 任务队列为空，未找到可交互元素。"); g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; g_s2_finalResultFromKeChuan = @""; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; return; } LogMessage(EchoLogTypeInfo, @"[课传] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_s2_keChuanWorkQueue.count); [self processKeChuanQueue_Truth_S2]; }
%new
- (void)processKeChuanQueue_Truth_S2 { if (!g_s2_isExtractingKeChuanDetail || g_s2_keChuanWorkQueue.count == 0) { if (g_s2_isExtractingKeChuanDetail) { LogMessage(EchoLogTypeTask, @"[完成] “课传流注”全部处理完毕。"); NSMutableString *resultStr = [NSMutableString string]; if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) { for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) { [resultStr appendFormat:@"// %@\n%@\n\n", g_s2_keChuanTitleQueue[i], g_s2_capturedKeChuanDetailArray[i]]; } g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (!g_s2_keChuan_completion_handler) { [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"// 课传流注\n\n%@", g_s2_finalResultFromKeChuan]; [self showEchoNotificationWithTitle:@"分析完成" message:@"课传流注已同步至剪贴板。"]; } } else { g_s2_finalResultFromKeChuan = @"[错误: 课传流注解析数量不匹配]"; LogMessage(EchoLogError, @"%@", g_s2_finalResultFromKeChuan); } } g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; if (g_s2_keChuan_completion_handler) { g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; } return; } NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject; [g_s2_keChuanWorkQueue removeObjectAtIndex:0]; NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count]; LogMessage(EchoLogTypeInfo, @"[课传] 正在处理: %@", title); [self updateProgressHUD:[NSString stringWithFormat:@"推演课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]]; SEL action = [task[@"taskType"] isEqualToString:@"tianJiang"] ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:"); if ([self respondsToSelector:action]) { SUPPRESS_LEAK_WARNING([self performSelector:action withObject:task[@"gesture"]]); } else { LogMessage(EchoLogError, @"[错误] 方法 %@ 不存在。", NSStringFromSelector(action)); [g_s2_capturedKeChuanDetailArray addObject:@"[解析失败: 方法不存在]"]; [self processKeChuanQueue_Truth_S2]; } }
%new
- (void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion {
    g_extractedData = [NSMutableDictionary dictionary]; g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "]; g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""]; g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "]; g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "]; g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "]; g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "]; g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18]; NSMutableString *siKe = [NSMutableString string]; Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖"); if(siKeViewClass){ NSMutableArray *siKeViews=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews); if(siKeViews.count > 0){ UIView *container=siKeViews.firstObject; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels); if(labels.count >= 12){ NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label]; } if (cols.allKeys.count == 4) { NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }]; NSMutableArray *c1=cols[keys[0]],*c2=cols[keys[1]],*c3=cols[keys[2]],*c4=cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSString *k1s=((UILabel*)c4[0]).text,*k1t=((UILabel*)c4[1]).text,*k1d=((UILabel*)c4[2]).text; NSString *k2s=((UILabel*)c3[0]).text,*k2t=((UILabel*)c3[1]).text,*k2d=((UILabel*)c3[2]).text; NSString *k3s=((UILabel*)c2[0]).text,*k3t=((UILabel*)c2[1]).text,*k3d=((UILabel*)c2[2]).text; NSString *k4s=((UILabel*)c1[0]).text,*k4t=((UILabel*)c1[1]).text,*k4d=((UILabel*)c1[2]).text; siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)]; } } } } g_extractedData[@"四课"] = siKe;
    NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); if(sanChuanViewClass){ NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray array]; for(NSUInteger i = 0; i < scViews.count; i++){ UIView *v = scViews[i]; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(labels.count >= 3){ NSString *lq=((UILabel*)labels.firstObject).text, *tj=((UILabel*)labels.lastObject).text, *dz=((UILabel*)[labels objectAtIndex:labels.count-2]).text; NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for(UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count-3)]){ if(l.text.length > 0) [ssParts addObject:l.text]; } } NSString *ss = [ssParts componentsJoinedByString:@" "]; NSMutableString *line = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [line appendFormat:@" (%@)", ss]; } [lines addObject:[NSString stringWithFormat:@"%@ %@", (i < titles.count) ? titles[i] : @"", line]]; } } sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy]; } g_extractedData[@"三传"] = sanChuan;
    
    SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示法訣總覽")]);
    SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示格局總覽")]);
    SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示方法總覽")]);
    SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示七政信息WithSender:") withObject:nil]);
            
    NSString *biFa = g_extractedData[@"毕法要诀"]?:@"", *geJu = g_extractedData[@"格局要览"]?:@"", *fangFa = g_extractedData[@"十八方法"]?:@"";
    if(biFa.length>0) biFa=[NSString stringWithFormat:@"\n// 毕法要诀\n%@", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"\n\n// 格局要览\n%@", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"\n\n// 十八方法\n%@", fangFa];
    NSString *qiZheng = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"\n\n// 七政四余\n%@", g_extractedData[@"七政四余"]] : @"";
    NSString *tianDiPan = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";
    NSString *finalText = [NSString stringWithFormat:@"// 盘面总览\n%@\n月将: %@ | 空亡: %@\n昼夜: %@ | 课体: %@\n九宗门: %@\n\n// 天地盘\n%@\n// 四课\n%@\n\n// 三传\n%@%@%@%@%@", SafeString(g_extractedData[@"时间块"]), SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]), SafeString(g_extractedData[@"九宗门"]), tianDiPan, SafeString(g_extractedData[@"四课"]), SafeString(g_extractedData[@"三传"]), biFa, geJu, fangFa, qiZheng];
    
    if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
}
%new
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion { g_isExtractingNianming = YES; g_capturedZhaiYaoArray = [NSMutableArray array]; g_capturedGeJuArray = [NSMutableArray array]; UICollectionView *targetCV = nil; Class unitClass = NSClassFromString(@"六壬大占.行年單元"); NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs); for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { LogMessage(EchoLogTypeWarning, @"[行年] 未找到行年单元，跳过分析。"); g_isExtractingNianming = NO; g_extractedData = nil; if (completion) { completion(@""); } return; }
    NSMutableArray *allUnitCells = [NSMutableArray array]; for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } } [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { LogMessage(EchoLogTypeWarning, @"[行年] 行年单元数量为0，跳过分析。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    NSMutableArray *workQueue = [NSMutableArray array]; for (NSUInteger i = 0; i < allUnitCells.count; i++) { UICollectionViewCell *cell = allUnitCells[i]; [workQueue addObject:@{@"type": @"年命摘要", @"cell": cell, @"index": @(i)}]; [workQueue addObject:@{@"type": @"格局方法", @"cell": cell, @"index": @(i)}]; } __weak typeof(self) weakSelf = self; __block void (^processQueue)(void); processQueue = [^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf || workQueue.count == 0) { LogMessage(EchoLogTypeTask, @"[行年] 所有参数分析完毕。"); NSMutableString *resultStr = [NSMutableString string]; NSUInteger personCount = allUnitCells.count; for (NSUInteger i = 0; i < personCount; i++) { NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[摘要未获取]"; NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局未获取]"; [resultStr appendFormat:@"// 参数 %lu\n", (unsigned long)i+1]; [resultStr appendString:@"摘要: "]; [resultStr appendString:zhaiYao]; [resultStr appendString:@"\n格局: "]; [resultStr appendString:geJu]; if (i < personCount - 1) { [resultStr appendString:@"\n\n"]; } } g_isExtractingNianming = NO; if (completion) { completion(resultStr); } processQueue = nil; return; } NSDictionary *item = workQueue.firstObject; [workQueue removeObjectAtIndex:0]; NSString *type = item[@"type"]; UICollectionViewCell *cell = item[@"cell"]; NSInteger index = [item[@"index"] integerValue]; LogMessage(EchoLogTypeInfo, @"[行年] 正在处理参数 %ld 的 [%@]", (long)index + 1, type); g_currentItemToExtract = type; id delegate = targetCV.delegate; NSIndexPath *indexPath = [targetCV indexPathForCell:cell]; if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath]; } dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ processQueue(); }); } copy]; processQueue(); }
%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
%new
- (NSString *)GetStringFromLayer:(id)layer { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
%new
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView { Class cellClass = NSClassFromString(@"六壬大占.格局單元"); if (!cellClass) return @""; NSMutableArray *cells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, contentView, cells); [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }]; NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array]; for (UIView *cell in cells) { NSMutableArray *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell); if (labelsInCell.count > 0) { UILabel *titleLabel = labelsInCell[0]; NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; NSMutableString *contentString = [NSMutableString string]; if (labelsInCell.count > 1) { for (NSUInteger i = 1; i < labelsInCell.count; i++) { [contentString appendString:((UILabel *)labelsInCell[i]).text]; } } NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content]; if (![formattedPairs containsObject:pair]) { [formattedPairs addObject:pair]; } } } return [formattedPairs componentsJoinedByString:@" | "]; }
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator { Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { LogMessage(EchoLogError, @"[错误] 类名 '%@' 未找到。", className); return @""; } NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews); if (targetViews.count == 0) return @""; UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } } return [textParts componentsJoinedByString:separator]; }
%new
- (NSString *)extractTianDiPanInfo_V18 { @try { Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类"; UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow"; NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例"; UIView *plateView = plateViews.firstObject; id diGongDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"], tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"], tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"]; if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典"; NSArray *diGongLayers=[diGongDict allValues], *tianShenLayers=[tianShenDict allValues], *tianJiangLayers=[tianJiangDict allValues]; if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配"; NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil]; void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = [layer presentationLayer] ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; CGFloat dx = pos.x - center.x; CGFloat dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": [self GetStringFromLayer:layer], @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } }; processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang"); NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary]; for (NSDictionary *info in allLayerInfos) { BOOL foundGroup = NO; for (NSNumber *angleKey in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angleKey floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angleKey] addObject:info]; foundGroup=YES; break; } } if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];} } NSMutableArray *palaceData = [NSMutableArray array]; for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count != 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }]; } if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整"; NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"]; [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }]; NSMutableString *result = [NSMutableString string]; for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@) ", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; } }

// [FIXED] 所有新方法都被正确地移动到了%hook块内部
%new
- (NSString *)formatDataFromOffscreenView:(UIView *)contentView forDataType:(NSString *)dataType {
    NSMutableArray *textParts = [NSMutableArray array];
    if ([dataType isEqualToString:@"七政四余"]) {
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
        [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        for (UILabel *label in allLabels) {
            if (label.text.length > 0) [textParts addObject:label.text];
        }
        return [textParts componentsJoinedByString:@"\n"];
    } else {
        NSMutableArray *stackViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);
        [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
        for (UIStackView *stackView in stackViews) {
            NSArray *arrangedSubviews = stackView.arrangedSubviews;
            if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                UILabel *titleLabel = arrangedSubviews[0];
                NSString *rawTitle = titleLabel.text ?: @"";
                rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""];
                rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""];
                rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""];
                rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                NSMutableArray *descParts = [NSMutableArray array];
                if (arrangedSubviews.count > 1) {
                    for (NSUInteger i = 1; i < arrangedSubviews.count; i++) {
                        if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) {
                            [descParts addObject:((UILabel *)arrangedSubviews[i]).text];
                        }
                    }
                }
                NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
            }
        }
        return [textParts componentsJoinedByString:@"\n"];
    }
}

- (void)顯示法訣總覽 {
    if (g_isHijacking) {
        LogMessage(EchoLogTypeInfo, @"[劫持] 正在后台提取“毕法要诀”...");
        UIViewController *vc = [[NSClassFromString(@"六壬大占.法訣總覽視圖") alloc] init];
        [vc view]; 
        g_extractedData[@"毕法要诀"] = [self formatDataFromOffscreenView:vc.view forDataType:@"毕法要诀"];
    } else {
        %orig;
    }
}
- (void)顯示格局總覽 {
    if (g_isHijacking) {
        LogMessage(EchoLogTypeInfo, @"[劫持] 正在后台提取“格局要览”...");
        UIViewController *vc = [[NSClassFromString(@"六壬大占.格局總覽視圖") alloc] init];
        [vc view];
        g_extractedData[@"格局要览"] = [self formatDataFromOffscreenView:vc.view forDataType:@"格局要览"];
    } else {
        %orig;
    }
}
- (void)顯示方法總覽 {
    if (g_isHijacking) {
        LogMessage(EchoLogTypeInfo, @"[劫持] 正在后台提取“十八方法”...");
        UIViewController *vc = [[NSClassFromString(@"六壬大占.方法總覽視圖") alloc] init];
        [vc view];
        g_extractedData[@"十八方法"] = [self formatDataFromOffscreenView:vc.view forDataType:@"十八方法"];
    } else {
        %orig;
    }
}
- (void)顯示七政信息WithSender:(id)sender {
     if (g_isHijacking) {
        LogMessage(EchoLogTypeInfo, @"[劫持] 正在后台提取“七政四余”...");
        UIViewController *vc = [[NSClassFromString(@"六壬大占.七政信息視圖") alloc] init];
        [vc view];
        g_extractedData[@"七政四余"] = [self formatDataFromOffscreenView:vc.view forDataType:@"七政四余"];
    } else {
        %orig;
    }
}

%end // [FIXED] 添加了缺失的 %end

// =========================================================================
// 4. S1 提取函数定义
// =========================================================================
static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie) { if (!rootView) return @"[错误: 根视图为空]"; NSMutableString *finalResult = [NSMutableString string]; NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews); if (stackViews.count > 0) { UIStackView *mainStackView = stackViews.firstObject; NSMutableArray *blocks = [NSMutableArray array]; NSMutableDictionary *currentBlock = nil; for (UIView *subview in mainStackView.arrangedSubviews) { if (![subview isKindOfClass:[UILabel class]]) continue; UILabel *label = (UILabel *)subview; NSString *text = label.text; if (!text || text.length == 0) continue; BOOL isTitle = (label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0; if (isTitle) { if (currentBlock) [blocks addObject:currentBlock]; currentBlock = [NSMutableDictionary dictionaryWithDictionary:@{@"title": text, @"content": [NSMutableString string]}]; } else { if (currentBlock) { NSMutableString *content = currentBlock[@"content"]; if (content.length > 0) [content appendString:@" "]; [content appendString:text]; } } } if (currentBlock) [blocks addObject:currentBlock]; for (NSDictionary *block in blocks) { NSString *title = block[@"title"]; NSString *content = [block[@"content"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (content.length > 0) { [finalResult appendFormat:@"%@\n%@\n\n", title, content]; } else { [finalResult appendFormat:@"%@\n\n", title]; } } } if (includeXiangJie) { Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView"); if (tableViewClass) { NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, rootView, tableViews); if (tableViews.count > 0) { NSMutableArray *xiangJieLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], tableViews.firstObject, xiangJieLabels); if (xiangJieLabels.count > 0) { [finalResult appendString:@"// 详解内容\n\n"]; for (NSUInteger i = 0; i < xiangJieLabels.count; i += 2) { UILabel *titleLabel = xiangJieLabels[i]; if (i + 1 >= xiangJieLabels.count && [titleLabel.text isEqualToString:@"详解"]) continue; if (i + 1 < xiangJieLabels.count) { [finalResult appendFormat:@"%@→%@\n\n", titleLabel.text, ((UILabel*)xiangJieLabels[i+1]).text]; } else { [finalResult appendFormat:@"%@→\n\n", titleLabel.text]; } } } } } } return [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

// =========================================================================
// 5. 构造函数
// =========================================================================
%ctor { @autoreleasepool { MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController); NSLog(@"[Echo解析引擎] v15.1 (FinalSyntaxFix) 已加载。"); } }
