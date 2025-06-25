/////// Filename: EchoAI_Ultimate_v7.2_Final.xm
// 描述: EchoAI终极整合版 v7.2 (最终修复版)。此版本修复了v7.1的所有编译错误。
//       - [FIX] 彻底修正了多行宏`SUPPRESS_LEAK_WARNING`的语法。
//       - [FIX] 将`GetIvarValueSafely`和`GetStringFromLayer`函数移回正确的%hook作用域内，解决了未声明的函数调用错误。
//       - [UI/UX] 保留了全新的Prestige UI。
//       - [RELIABILITY] 保留了基于类名的可靠弹窗识别机制。
//       - [COMPLETENESS] 保留了七政四余在综合模式中的完整提取。

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

// Script 1 (CombinedExtractor) Globals
static BOOL g_s1_isExtracting = NO;
static NSString *g_s1_currentTaskType = nil;
static BOOL g_s1_shouldIncludeXiangJie = NO;
static NSMutableArray *g_s1_keTi_workQueue = nil;
static NSMutableArray *g_s1_keTi_resultsArray = nil;
static UICollectionView *g_s1_keTi_targetCV = nil;

// Script 2 (EchoAI) Globals
static BOOL g_s2_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_s2_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_s2_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_s2_keChuanTitleQueue = nil;
static NSString *g_s2_finalResultFromKeChuan = nil;
static void (^g_s2_keChuan_completion_handler)(void) = nil;

static NSMutableDictionary *g_s2_extractedData = nil;
static BOOL g_s2_isExtractingNianming = NO;
static NSString *g_s2_currentItemToExtract = nil;
static NSMutableArray *g_s2_capturedZhaiYaoArray = nil;
static NSMutableArray *g_s2_capturedGeJuArray = nil;

static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果由 EchoAI_Ultimate_v7.2 生成，仅供参考。\n"
"2. 请结合实际情况与专业知识进行最终判断。\n"
"3. [可在此处添加您的个人Prompt或更多说明]";

#pragma mark - Helper Functions

static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args; va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        g_logTextView.text = [NSString stringWithFormat:@"%@%@\n%@", logPrefix, message, g_logTextView.text];
        NSLog(@"[EchoAI-Ultimate-v7.2] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                // For apps with multiple windows, this is a more robust way
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
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
// 2. 接口声明与核心Hook
// =========================================================================

@interface UIViewController (EchoAIUltimatePowerhouse)
// UI Methods
- (void)createOrShowMainControlPanel; - (void)handleMasterButtonTap:(UIButton *)sender;
- (void)showProgressHUD:(NSString *)text; - (void)updateProgressHUD:(NSString *)text; - (void)hideProgressHUD;
- (void)copyLogAndClose;
// S1 Task Launchers
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include;
- (void)processKeTiWorkQueue_S1;
// S2 Task Launchers
- (void)executeSimpleExtraction; - (void)executeCompositeExtraction;
- (void)extractSinglePopupInfoWithTaskName:(NSString*)taskName selectorName:(NSString*)selectorName;
// S2 Core Logic Methods
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion;
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion;
- (void)extractKePanInfo_S2_WithCompletion:(void (^)(NSString *kePanText))completion;
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion;
- (void)processKeChuanQueue_Truth_S2;
// S2 Helper Methods
- (NSString *)formatNianmingGejuFromView_S2:(UIView *)contentView;
- (NSString *)extractTextFromFirstViewOfClassName_S2:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_S2;
@end

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie);

// --- 统一的 presentViewController 拦截器 ---
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    
    // 逻辑分支 1: 脚本1 (课体/九宗门)
    if (g_s1_isExtracting) {
        if ([NSStringFromClass([vcToPresent class]) containsString:@"課體概覽視圖"]) {
            vcToPresent.view.alpha = 0.0f; animated = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                NSString *extractedText = extractDataFromSplitView_S1(vcToPresent.view, g_s1_shouldIncludeXiangJie);
                if ([g_s1_currentTaskType isEqualToString:@"KeTi"]) {
                    [g_s1_keTi_resultsArray addObject:extractedText];
                    LogMessage(@"[S1] 成功提取“课体”第 %lu 项...", (unsigned long)g_s1_keTi_resultsArray.count);
                    [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeTiWorkQueue_S1]; }); }];
                } else if ([g_s1_currentTaskType isEqualToString:@"JiuZongMen"]) {
                    LogMessage(@"[S1] 成功提取“九宗门”详情！");
                    [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"--- 【九宗门详情】 ---\n\n%@", extractedText];
                    LogMessage(@"[S1] 内容已复制到剪贴板！");
                    g_s1_isExtracting = NO; g_s1_currentTaskType = nil;
                    [vcToPresent dismissViewControllerAnimated:NO completion:nil];
                }
            };
            Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion); return;
        }
    }

    // 逻辑分支 2: 脚本2 (四课三传详解)
    else if (g_s2_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            LogMessage(@"[S2-KeChuan] 捕获到弹窗: %@", vcClassName);
            vcToPresent.view.alpha = 0.0f; animated = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = vcToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                [g_s2_capturedKeChuanDetailArray addObject:[textParts componentsJoinedByString:@"\n"]];
                LogMessage(@"[S2-KeChuan] 成功提取内容 (共 %lu 条)", (unsigned long)g_s2_capturedKeChuanDetailArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeChuanQueue_Truth_S2]; }); }];
            };
            Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion); return;
        }
    }
    
    // 逻辑分支 3: 脚本2 (毕法/格局/年命等)
    else if ((g_s2_extractedData && ![vcToPresent isKindOfClass:[UIAlertController class]]) || g_s2_isExtractingNianming) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        
        if (g_s2_extractedData && ![vcToPresent isKindOfClass:[UIAlertController class]]) {
            vcToPresent.view.alpha = 0.0f; animated = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                BOOL isHandled = NO;
                if ([vcClassName containsString:@"法訣總覽視圖"] || [vcClassName containsString:@"格局總覽視圖"] || [vcClassName containsString:@"方法總覽視圖"] || [vcToPresent.title containsString:@"毕法"] || [vcToPresent.title containsString:@"格局"] || [vcToPresent.title containsString:@"方法"]) {
                    isHandled = YES;
                    NSMutableArray *textParts = [NSMutableArray array];
                    NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], vcToPresent.view, stackViews); [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                    for (UIStackView *stackView in stackViews) {
                        NSArray *arrangedSubviews = stackView.arrangedSubviews;
                        if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                            UILabel *titleLabel = arrangedSubviews[0]; NSString *rawTitle = [titleLabel.text ?: @"" stringByReplacingOccurrencesOfString:@" 毕法" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                            NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            NSMutableArray *descParts = [NSMutableArray array]; if (arrangedSubviews.count > 1) { for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } } }
                            [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]];
                        }
                    }
                    NSString *content = [textParts componentsJoinedByString:@"\n"];
                    if ([vcClassName containsString:@"法訣"] || [g_s2_extractedData[@"task"] isEqualToString:@"BiFa"]) g_s2_extractedData[@"毕法"] = content;
                    else if ([vcClassName containsString:@"格局"] || [g_s2_extractedData[@"task"] isEqualToString:@"GeJu"]) g_s2_extractedData[@"格局"] = content;
                    else if ([vcClassName containsString:@"方法"] || [g_s2_extractedData[@"task"] isEqualToString:@"FangFa"]) g_s2_extractedData[@"方法"] = content;
                } 
                else if ([vcClassName containsString:@"七政"]) {
                     isHandled = YES;
                     NSMutableArray *textParts = [NSMutableArray array];
                     NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                     for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                     g_s2_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                }
                if (!isHandled) { LogMessage(@"[S2] 抓取到未知弹窗 [%@]，内容被忽略。", vcClassName); }
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            Original_presentViewController(self, _cmd, vcToPresent, animated, completion); return;
        }
        else if (g_s2_isExtractingNianming && g_s2_currentItemToExtract) {
            __weak typeof(self) weakSelf = self;
            if ([vcToPresent isKindOfClass:[UIAlertController class]]) {
                UIAlertController *alert = (UIAlertController *)vcToPresent; UIAlertAction *targetAction = nil;
                for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_s2_currentItemToExtract]) { targetAction = action; break; } }
                if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
            }
            if ([g_s2_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
                UIView *contentView = vcToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
                [g_s2_capturedZhaiYaoArray addObject:[[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                [vcToPresent dismissViewControllerAnimated:NO completion:nil]; return;
            } else if ([g_s2_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
                void (^newCompletion)(void) = ^{
                    if (completion) { completion(); }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                        UIView *contentView = vcToPresent.view;
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                            [g_s2_capturedGeJuArray addObject:[strongSelf2 formatNianmingGejuFromView_S2:contentView]];
                            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
                        });
                    });
                };
                Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion); return;
            }
        }
    }
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 3. UI, 任务分发与核心逻辑实现
// =========================================================================

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
            NSInteger controlButtonTag = 556699;
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag; [controlButton setTitle:@"EchoAI 控制台" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18; controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2); controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

#pragma mark - Prestige UI v7.2
%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    NSInteger panelTag = 778899;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) {
            [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil;
        }];
        return;
    }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = panelTag;
    g_mainControlPanelView.backgroundColor = [UIColor clearColor];
    
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_mainControlPanelView.bounds;
    [g_mainControlPanelView addSubview:blurView];

    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 80)];
    [g_mainControlPanelView addSubview:contentView];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, contentView.bounds.size.width, 40)];
    titleLabel.text = @"EchoAI 终极提取器 v7.2";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, contentView.bounds.size.width, contentView.bounds.size.height - 120)];
    [contentView addSubview:scrollView];

    CGFloat currentY = 10;
    
    UIButton* (^createButton)(NSString*, NSInteger, UIColor*) = ^(NSString* title, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal]; btn.tag = tag; btn.backgroundColor = color;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.layer.cornerRadius = 8;
        return btn;
    };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) {
        UILabel *label = [[UILabel alloc] init];
        label.text = title; label.font = [UIFont boldSystemFontOfSize:18];
        label.textColor = [UIColor systemBlueColor]; return label;
    };
    
    UILabel *sec1Title = createSectionTitle(@"- 综合提取模式 -");
    sec1Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec1Title];
    currentY += 32;

    UIButton *easyModeBtn = createButton(@"Easy Mode (基础盘+年命)", 101, [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]);
    easyModeBtn.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 44);
    [scrollView addSubview:easyModeBtn];
    currentY += 54;
    
    UIButton *powerModeBtn = createButton(@"终极模式 (Power!!!)", 102, [UIColor colorWithRed:0.9 green:0.4 blue:0.13 alpha:1.0]);
    powerModeBtn.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 44);
    [scrollView addSubview:powerModeBtn];
    currentY += 64;
    
    UILabel *sec2Title = createSectionTitle(@"- 核心单项提取 -");
    sec2Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec2Title];
    currentY += 32;
    
    NSArray *coreButtons = @[
        @{@"title": @"四课三传详解", @"tag": @(301), @"color": [UIColor systemTealColor]},
        @{@"title": @"年命分析", @"tag": @(302), @"color": [UIColor systemIndigoColor]},
        @{@"title": @"课体 (带详解)", @"tag": @(201), @"color": [UIColor systemGreenColor]},
        @{@"title": @"九宗门 (带详解)", @"tag": @(203), @"color": [UIColor systemCyanColor]},
    ];
    CGFloat btnWidth = (scrollView.bounds.size.width - 40) / 2.0;
    for (int i=0; i<coreButtons.count; i++) {
        NSDictionary *config = coreButtons[i];
        UIButton *btn = createButton(config[@"title"], [config[@"tag"] integerValue], config[@"color"]);
        btn.frame = CGRectMake(15 + (i % 2) * (btnWidth + 10), currentY + (i / 2) * 54, btnWidth, 44);
        [scrollView addSubview:btn];
    }
    currentY += (coreButtons.count / 2) * 54 + 20;
    
    UILabel *sec3Title = createSectionTitle(@"- 辅助单项提取 -");
    sec3Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec3Title];
    currentY += 32;

    NSArray *auxButtons = @[
        @{@"title": @"毕法", @"tag": @(303), @"color": [UIColor systemOrangeColor]},
        @{@"title": @"格局", @"tag": @(304), @"color": [UIColor systemPurpleColor]},
        @{@"title": @"方法", @"tag": @(305), @"color": [UIColor systemPinkColor]},
    ];
    btnWidth = (scrollView.bounds.size.width - 45) / 3.0;
    for (int i=0; i<auxButtons.count; i++) {
        NSDictionary *config = auxButtons[i];
        UIButton *btn = createButton(config[@"title"], [config[@"tag"] integerValue], config[@"color"]);
        btn.frame = CGRectMake(15 + i * (btnWidth + 7.5), currentY, btnWidth, 44);
        [scrollView addSubview:btn];
    }
    currentY += 54;

    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY);

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, contentView.bounds.size.height - 230, contentView.bounds.size.width, 170)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.8];
    g_logTextView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO; g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已就绪。\n";
    [contentView addSubview:g_logTextView];

    UIButton *copyButton = createButton(@"复制日志并关闭", 999, [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1.0]);
    copyButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, contentView.bounds.size.width - 30, 40);
    [contentView addSubview:copyButton];
    
    g_mainControlPanelView.alpha = 0;
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)copyLogAndClose {
    if (g_logTextView && g_logTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logTextView.text;
        LogMessage(@"日志内容已复制到剪贴板！");
    }
    [self handleMasterButtonTap:nil];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    if (!sender) {
        if (g_mainControlPanelView) {
            [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) {
                [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil;
            }];
        }
        return;
    }
    
    if (g_s1_isExtracting || g_s2_isExtractingKeChuanDetail || g_s2_isExtractingNianming || g_s2_extractedData) {
        LogMessage(@"错误：已有其他任务在后台运行，请等待任务完成后再试。");
        return;
    }

    switch (sender.tag) {
        case 999: [self copyLogAndClose]; break;
        case 101: [self executeSimpleExtraction]; break;
        case 102: [self executeCompositeExtraction]; break;
        case 201: [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:YES]; break;
        case 203: [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES]; break;
        case 301: [self startExtraction_Truth_S2_WithCompletion:nil]; break;
        case 302: [self extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
            [self hideProgressHUD];
            NSString *finalText = [NSString stringWithFormat:@"--- 【年命分析】 ---\n\n%@", nianmingText];
            [UIPasteboard generalPasteboard].string = finalText;
            LogMessage(@"[S2] 年命分析提取完成，已复制到剪贴板。");
        }]; break;
        case 303: [self extractSinglePopupInfoWithTaskName:@"BiFa" selectorName:@"顯示法訣總覽"]; break;
        case 304: [self extractSinglePopupInfoWithTaskName:@"GeJu" selectorName:@"顯示格局總覽"]; break;
        case 305: [self extractSinglePopupInfoWithTaskName:@"FangFa" selectorName:@"顯示方法總覽"]; break;
        default: break;
    }
}

%new
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    NSInteger progressViewTag = 556677;
    UIView *existing = [keyWindow viewWithTag:progressViewTag]; if(existing) [existing removeFromSuperview];
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)]; progressView.center = keyWindow.center;
    progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8]; progressView.layer.cornerRadius = 10; progressView.tag = progressViewTag;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor]; spinner.center = CGPointMake(110, 50); [spinner startAnimating]; [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)]; progressLabel.textColor = [UIColor whiteColor];
    progressLabel.textAlignment = NSTextAlignmentCenter; progressLabel.font = [UIFont systemFontOfSize:14];
    progressLabel.adjustsFontSizeToFitWidth = YES; progressLabel.text = text; [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
}
%new
- (void)updateProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:556677];
    if (progressView) { for (UIView *subview in progressView.subviews) { if ([subview isKindOfClass:[UILabel class]]) { ((UILabel *)subview).text = text; break; } } }
}
%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:556677];
    if (progressView) { [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }]; }
}

#pragma mark - Extraction Logic & Launchers
%new
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include {
    g_s1_isExtracting = YES; g_s1_currentTaskType = taskType; g_s1_shouldIncludeXiangJie = include;
    LogMessage(@"--- [S1] 开始任务: %@ (详解: %@) ---", taskType, include ? @"是" : @"否");
    if ([taskType isEqualToString:@"KeTi"]) {
        UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) { LogMessage(@"[S1] 错误: 找不到主窗口。"); g_s1_isExtracting = NO; return; }
        Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元"); if (!keTiCellClass) { LogMessage(@"[S1] 错误: 找不到 '課體單元' 类。"); g_s1_isExtracting = NO; return; }
        NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
        for (UICollectionView *cv in allCVs) { for (id cell in cv.visibleCells) { if ([cell isKindOfClass:keTiCellClass]) { g_s1_keTi_targetCV = cv; break; } } if(g_s1_keTi_targetCV) break; }
        if (!g_s1_keTi_targetCV) { LogMessage(@"[S1] 错误: 找不到包含“课体”的UICollectionView。"); g_s1_isExtracting = NO; return; }
        g_s1_keTi_workQueue = [NSMutableArray array]; g_s1_keTi_resultsArray = [NSMutableArray array];
        NSInteger totalItems = [g_s1_keTi_targetCV.dataSource collectionView:g_s1_keTi_targetCV numberOfItemsInSection:0];
        for (NSInteger i = 0; i < totalItems; i++) { [g_s1_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
        if (g_s1_keTi_workQueue.count == 0) { LogMessage(@"[S1] 错误: 未找到任何“课体”单元来创建任务队列。"); g_s1_isExtracting = NO; return; }
        LogMessage(@"[S1] 发现 %lu 个“课体”单元，开始处理队列...", (unsigned long)g_s1_keTi_workQueue.count);
        [self processKeTiWorkQueue_S1];
    } else if ([taskType isEqualToString:@"JiuZongMen"]) {
        SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
        if ([self respondsToSelector:selector]) { 
            LogMessage(@"[S1] 正在调用方法: 顯示九宗門概覽");
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:selector];
            #pragma clang diagnostic pop
        } 
        else { LogMessage(@"[S1] 错误: 当前VC没有'顯示九宗門概覽'方法。"); g_s1_isExtracting = NO; }
    }
}
%new
- (void)processKeTiWorkQueue_S1 {
    if (g_s1_keTi_workQueue.count == 0) {
        LogMessage(@"[S1] 所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_s1_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        for (NSUInteger i = 0; i < g_s1_keTi_resultsArray.count; i++) {
            NSString *itemText = g_s1_keTi_resultsArray[i];
            NSArray *lines = [itemText componentsSeparatedByString:@"\n"];
            NSString *itemTitle = (lines.count > 0 && [lines[0] containsString:@"课"]) ? lines[0] : [NSString stringWithFormat:@"未知课体 %lu", (unsigned long)i+1];
            
            NSRange titleRange = [itemText rangeOfString:itemTitle];
            NSString *content = (titleRange.location != NSNotFound) ? [itemText stringByReplacingCharactersInRange:titleRange withString:@""] : itemText;
            content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            [finalResult appendFormat:@"--- 【%@】 ---\n\n%@\n\n\n", itemTitle, content];
        }
        [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        LogMessage(@"[S1] “课体”批量提取完成，所有内容已合并并复制！");
        g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_keTi_targetCV = nil; g_s1_keTi_workQueue = nil; g_s1_keTi_resultsArray = nil;
        return;
    }
    
    NSIndexPath *indexPath = g_s1_keTi_workQueue.firstObject; [g_s1_keTi_workQueue removeObjectAtIndex:0];
    LogMessage(@"[S1] 正在处理“课体”第 %lu/%lu 项...", (unsigned long)(g_s1_keTi_resultsArray.count + 1), (unsigned long)(g_s1_keTi_resultsArray.count + g_s1_keTi_workQueue.count + 1));
    
    id delegate = g_s1_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_s1_keTi_targetCV didSelectItemAtIndexPath:indexPath];
    } else { LogMessage(@"[S1] 错误: 无法触发点击事件。"); [self processKeTiWorkQueue_S1]; }
}
%new
- (void)executeSimpleExtraction {
    LogMessage(@"--- 开始执行 [Easy Mode] ---"); [self showProgressHUD:@"正在执行Easy Mode..."];
    [self performSimpleAnalysis_S2_WithCompletion:^(NSString *resultText) {
        [self hideProgressHUD]; [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"Easy mode结果已成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil]; LogMessage(@"--- [Easy Mode] 任务全部完成 ---");
    }];
}
%new
- (void)executeCompositeExtraction {
    LogMessage(@"--- 开始执行 [终极模式 Power!!!] ---"); [self showProgressHUD:@"步骤 1/3: 提取基础盘面..."];
    [self extractKePanInfo_S2_WithCompletion:^(NSString *kePanText) {
        g_s2_baseTextCacheForPowerMode = kePanText; LogMessage(@"[Power!] 基础盘面提取完成。");
        [self updateProgressHUD:@"步骤 2/3: 提取课传详解..."];
        [self startExtraction_Truth_S2_WithCompletion:^{
            LogMessage(@"[Power!] 课传详解提取完成。"); [self updateProgressHUD:@"步骤 3/3: 提取年命信息..."];
            [self extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
                [self hideProgressHUD]; LogMessage(@"[Power!] 年命信息提取完成。");
                NSMutableString *finalResult = [g_s2_baseTextCacheForPowerMode mutableCopy];
                if (g_s2_finalResultFromKeChuan.length > 0) { [finalResult appendFormat:@"\n\n--- 【课传详解】 ---\n\n%@", g_s2_finalResultFromKeChuan]; }
                if (nianmingText.length > 0) {
                     NSString *formattedNianming = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
                     formattedNianming = [formattedNianming stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
                    [finalResult appendFormat:@"\n\n--- 【年命分析】 ---\n\n%@", formattedNianming];
                }
                [finalResult appendString:CustomFooterText];
                [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"终极模式完成" message:@"所有信息已合并并复制！" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"太棒了！" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:alert animated:YES completion:nil];
                LogMessage(@"--- [终极模式 Power!!!] 任务全部完成 ---");
                g_s2_baseTextCacheForPowerMode = nil; g_s2_finalResultFromKeChuan = nil;
            }];
        }];
    }];
}
%new
- (void)extractSinglePopupInfoWithTaskName:(NSString*)taskName selectorName:(NSString*)selectorName {
    LogMessage(@"[S2-Single] 开始提取单项: %@", taskName); [self showProgressHUD:[NSString stringWithFormat:@"提取 %@...", taskName]];
    g_s2_extractedData = [NSMutableDictionary dictionaryWithDictionary:@{@"task": taskName}];
    SEL selector = NSSelectorFromString(selectorName);
    if ([self respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector withObject:nil];
        #pragma clang diagnostic pop
    }
    else { LogMessage(@"[S2-Single] 错误: 方法 %@ 不存在。", selectorName); [self hideProgressHUD]; g_s2_extractedData = nil; return; }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hideProgressHUD];
        NSString *result = g_s2_extractedData[@"毕法"] ?: g_s2_extractedData[@"格局"] ?: g_s2_extractedData[@"方法"];
        if (result.length > 0) {
            [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"--- 【%@】 ---\n\n%@", taskName, result];
            LogMessage(@"[S2-Single] %@ 提取成功，已复制。", taskName);
        } else { LogMessage(@"[S2-Single] %@ 提取失败或无内容。", taskName); }
        g_s2_extractedData = nil;
    });
}
%new
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion {
    if (g_s2_isExtractingKeChuanDetail) { LogMessage(@"[S2-KeChuan] 错误：任务已在进行中。"); return; }
    LogMessage(@"[S2-KeChuan] 开始提取任务..."); [self showProgressHUD:@"正在提取课传详解..."];
    g_s2_isExtractingKeChuanDetail = YES; g_s2_keChuan_completion_handler = completion;
    g_s2_capturedKeChuanDetailArray = [NSMutableArray array]; g_s2_keChuanWorkQueue = [NSMutableArray array]; g_s2_keChuanTitleQueue = [NSMutableArray array];
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(@"[S2-KeChuan] 致命错误: 找不到'課傳' ivar。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; [self hideProgressHUD]; return; }
    id keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer) { LogMessage(@"[S2-KeChuan] 致命错误: '課傳' 视图为nil。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; [self hideProgressHUD]; return; }
    
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults);
    if (sanChuanResults.count > 0) {
        UIView *sanChuanContainer = sanChuanResults.firstObject; const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
        for (int i = 0; ivarNames[i] != NULL; ++i) {
            Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue;
            UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue;
            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 2) { UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1];
                if (dizhiLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"taskType": @"diZhi"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]]; }
                if (tianjiangLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"taskType": @"tianJiang"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]]; }
            }
        }
    }
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults);
    if (siKeResults.count > 0) {
        UIView *siKeContainer = siKeResults.firstObject; NSDictionary *keDefs[] = { @{@"t": @"第一课", @"x": @"日", @"s": @"日上", @"j": @"日上天將"}, @{@"t": @"第二课", @"x": @"日上", @"s": @"日陰", @"j": @"日陰天將"}, @{@"t": @"第三课", @"x": @"辰", @"s": @"辰上", @"j": @"辰上天將"}, @{@"t": @"第四课", @"x": @"辰上", @"s": @"辰陰", @"j": @"辰陰天將"}};
        void (^addTask)(const char*, NSString*, NSString*) = ^(const char* iName, NSString* fTitle, NSString* tType) { if (!iName) return; Ivar ivar = class_getInstanceVariable(siKeContainerClass, iName); if (ivar) { UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar); if (label.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"taskType": tType} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", fTitle, label.text]]; } } };
        for (int i = 0; i < 4; ++i) { NSDictionary *d = keDefs[i]; addTask([d[@"x"] UTF8String], [NSString stringWithFormat:@"%@ - 下神", d[@"t"]], @"diZhi"); addTask([d[@"s"] UTF8String], [NSString stringWithFormat:@"%@ - 上神", d[@"t"]], @"diZhi"); addTask([d[@"j"] UTF8String], [NSString stringWithFormat:@"%@ - 天将", d[@"t"]], @"tianJiang"); }
    }
    
    if (g_s2_keChuanWorkQueue.count == 0) { LogMessage(@"[S2-KeChuan] 队列为空。"); g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; g_s2_finalResultFromKeChuan = @""; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; return; }
    LogMessage(@"[S2-KeChuan] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_s2_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth_S2];
}
%new
- (void)processKeChuanQueue_Truth_S2 {
    if (!g_s2_isExtractingKeChuanDetail || g_s2_keChuanWorkQueue.count == 0) {
        if (g_s2_isExtractingKeChuanDetail) {
            LogMessage(@"[S2-KeChuan] 全部任务处理完毕！");
            NSMutableString *resultStr = [NSMutableString string];
            if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) { [resultStr appendFormat:@"--- 【%@】 ---\n%@\n\n", g_s2_keChuanTitleQueue[i], g_s2_capturedKeChuanDetailArray[i]]; }
                g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (!g_s2_keChuan_completion_handler) { [UIPasteboard generalPasteboard].string = [NSString stringWithFormat:@"--- 【四课三传详解】 ---\n\n%@", g_s2_finalResultFromKeChuan]; LogMessage(@"[S2-KeChuan] 提取完成，已复制。"); }
            } else { g_s2_finalResultFromKeChuan = @"[S2-KeChuan 提取失败: 数量不匹配]"; }
        }
        g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD];
        if (g_s2_keChuan_completion_handler) { g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; }
        return;
    }
    
    NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject; [g_s2_keChuanWorkQueue removeObjectAtIndex:0];
    NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count];
    LogMessage(@"[S2-KeChuan] 正在处理: %@", title); [self updateProgressHUD:[NSString stringWithFormat:@"提取课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]];
    SEL action = [task[@"taskType"] isEqualToString:@"tianJiang"] ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:action]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:action withObject:task[@"gesture"]];
        #pragma clang diagnostic pop
    }
    else { LogMessage(@"[S2-KeChuan] 错误！方法 %@ 不存在。", NSStringFromSelector(action)); [g_s2_capturedKeChuanDetailArray addObject:@"[提取失败: 方法不存在]"]; [self processKeChuanQueue_Truth_S2]; }
}
%new
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion {
    __weak typeof(self) weakSelf = self;
    [self extractKePanInfo_S2_WithCompletion:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        LogMessage(@"[S2-Easy] 课盘信息提取完成。"); [self updateProgressHUD:@"正在提取年命信息..."];
        [strongSelf extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
            LogMessage(@"[S2-Easy] 年命信息提取完成。");
            NSString *formattedNianming = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""]; formattedNianming = [formattedNianming stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
            NSString *finalCombinedText = (nianmingText.length > 0) ? [NSString stringWithFormat:@"%@\n\n--- 【年命分析】 ---\n\n%@%@", kePanText, formattedNianming, CustomFooterText] : [NSString stringWithFormat:@"%@%@", kePanText, CustomFooterText];
            if(completion) { completion([finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        }];
    }];
}

// FIX: Corrected multi-line macro syntax and moved helper functions into scope.
#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

%new
- (void)extractKePanInfo_S2_WithCompletion:(void (^)(NSString *kePanText))completion {
    #define SafeString(str) (str ?: @"")
    g_s2_extractedData = [NSMutableDictionary dictionary];
    LogMessage(@"[S2-KePan] 提取基础信息...");
    g_s2_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName_S2:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_s2_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.七政視圖" separator:@" "]; g_s2_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.旬空視圖" separator:@""];
    g_s2_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.晝夜切換視圖" separator:@" "]; g_s2_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.課體視圖" separator:@" "];
    g_s2_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.九宗門視圖" separator:@" "]; g_s2_extractedData[@"天地盘"] = [self extractTianDiPanInfo_S2];
    
    NSMutableString *siKe = [NSMutableString string]; Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){ NSMutableArray *siKeViews=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews); if(siKeViews.count > 0){ UIView *c=siKeViews.firstObject; NSMutableArray *l=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], c, l); if(l.count >= 12){ NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for(UILabel *lbl in l){ NSString *k = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(lbl.frame))]; if(!cols[k]){ cols[k]=[NSMutableArray array]; } [cols[k] addObject:lbl]; } if (cols.allKeys.count == 4) { NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }]; NSMutableArray *c1=cols[keys[0]],*c2=cols[keys[1]],*c3=cols[keys[2]],*c4=cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text),SafeString(((UILabel*)c4[1]).text),SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text),SafeString(((UILabel*)c3[1]).text),SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text),SafeString(((UILabel*)c2[1]).text),SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text),SafeString(((UILabel*)c1[1]).text),SafeString(((UILabel*)c1[0]).text)]; } } } }
    g_s2_extractedData[@"四课"] = siKe;

    NSMutableString *sanChuan = [NSMutableString string]; Class scvClass = NSClassFromString(@"六壬大占.傳視圖");
    if(scvClass){ NSMutableArray *scvs = [NSMutableArray array]; FindSubviewsOfClassRecursive(scvClass, self.view, scvs); [scvs sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSArray *ts = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *ls = [NSMutableArray array]; for(NSUInteger i = 0; i < scvs.count; i++){ UIView *v = scvs[i]; NSMutableArray *lbs=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, lbs); [lbs sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(lbs.count >= 3){ NSString *lq=((UILabel*)lbs.firstObject).text, *tj=((UILabel*)lbs.lastObject).text, *dz=((UILabel*)[lbs objectAtIndex:lbs.count-2]).text; NSMutableArray *ssp = [NSMutableArray array]; if (lbs.count > 3) { for(UILabel *l in [lbs subarrayWithRange:NSMakeRange(1, lbs.count-3)]){ if(l.text.length > 0) [ssp addObject:l.text]; } } NSString *ss = [ssp componentsJoinedByString:@" "]; NSMutableString *ln = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [ln appendFormat:@" (%@)", ss]; } [ls addObject:[NSString stringWithFormat:@"%@ %@", (i < ts.count) ? ts[i] : @"", ln]]; } } sanChuan = [[ls componentsJoinedByString:@"\n"] mutableCopy]; }
    g_s2_extractedData[@"三传"] = sanChuan;
    
    LogMessage(@"[S2-KePan] 提取毕法、格局、七政等弹窗信息...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self respondsToSelector:NSSelectorFromString(@"顯示法訣總覽")]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示法訣總覽") withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:NSSelectorFromString(@"顯示格局總覽")]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示格局總覽") withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:NSSelectorFromString(@"顯示方法總覽")]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示方法總覽") withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:NSSelectorFromString(@"顯示七政信息WithSender:")]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:NSSelectorFromString(@"顯示七政信息WithSender:") withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }

        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *biFa = g_s2_extractedData[@"毕法"]?:@"", *geJu = g_s2_extractedData[@"格局"]?:@"", *fangFa = g_s2_extractedData[@"方法"]?:@"";
            if(biFa.length>0) biFa=[NSString stringWithFormat:@"\n--- 【毕法】 ---\n%@\n", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"\n--- 【格局】 ---\n%@\n", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"\n--- 【方法】 ---\n%@\n", fangFa];
            NSString *qiZheng = g_s2_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"\n--- 【七政四余】 ---\n%@\n", g_s2_extractedData[@"七政四余"]] : @"";
            
            NSString *finalText = [NSString stringWithFormat:
                @"--- 【基础信息】 ---\n%@\n月将: %@ | 空亡: %@ | 昼夜: %@\n课体: %@\n九宗门: %@\n\n"
                @"--- 【天地盘】 ---\n%@\n" @"--- 【四课】 ---\n%@\n\n" @"--- 【三传】 ---\n%@%@%@%@%@",
                SafeString(g_s2_extractedData[@"时间块"]), SafeString(g_s2_extractedData[@"月将"]), SafeString(g_s2_extractedData[@"空亡"]), SafeString(g_s2_extractedData[@"昼夜"]), SafeString(g_s2_extractedData[@"课体"]), SafeString(g_s2_extractedData[@"九宗门"]),
                SafeString(g_s2_extractedData[@"天地盘"]), SafeString(g_s2_extractedData[@"四课"]), SafeString(g_s2_extractedData[@"三传"]),
                biFa, geJu, fangFa, qiZheng
            ];
            g_s2_extractedData = nil; if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        });
    });
}
%new
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion {
    LogMessage(@"[S2-Nianming] 开始提取年命..."); [self showProgressHUD:@"正在提取年命..."];
    g_s2_isExtractingNianming = YES; g_s2_capturedZhaiYaoArray = [NSMutableArray array]; g_s2_capturedGeJuArray = [NSMutableArray array];
    UICollectionView *targetCV = nil; Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { LogMessage(@"[S2-Nianming] 未找到行年单元，跳过。"); g_s2_isExtractingNianming = NO; [self hideProgressHUD]; if (completion) { completion(@""); } return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { LogMessage(@"[S2-Nianming] 行年单元数量为0，跳过。"); g_s2_isExtractingNianming = NO; [self hideProgressHUD]; if (completion) { completion(@""); } return; }
    
    NSMutableArray *workQueue = [NSMutableArray array];
    for (NSUInteger i = 0; i < allUnitCells.count; i++) {
        [workQueue addObject:@{@"type": @"年命摘要", @"cell": allUnitCells[i], @"index": @(i)}];
        [workQueue addObject:@{@"type": @"格局方法", @"cell": allUnitCells[i], @"index": @(i)}];
    }
    
    __weak typeof(self) weakSelf = self; __block void (^processQueue)(void);
    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            LogMessage(@"[S2-Nianming] 所有年命任务处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSUInteger i = 0; i < allUnitCells.count; i++) {
                NSString *zhaiYao = (i < g_s2_capturedZhaiYaoArray.count) ? g_s2_capturedZhaiYaoArray[i] : @"[摘要未提取到]";
                NSString *geJu = (i < g_s2_capturedGeJuArray.count) ? g_s2_capturedGeJuArray[i] : @"[格局未提取到]";
                [resultStr appendFormat:@"--- 【人员 %lu】 ---\n", (unsigned long)i+1];
                [resultStr appendFormat:@"【年命摘要】\n%@\n\n", zhaiYao];
                [resultStr appendFormat:@"【格局方法】\n%@", geJu];
                if (i < allUnitCells.count - 1) { [resultStr appendString:@"\n\n--------------------\n\n"]; }
            }
            g_s2_isExtractingNianming = NO; if (completion) { completion(resultStr); } processQueue = nil;
            return;
        }
        NSDictionary *item = workQueue.firstObject; [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"]; UICollectionViewCell *cell = item[@"cell"]; NSInteger index = [item[@"index"] integerValue];
        LogMessage(@"[S2-Nianming] 正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        [strongSelf updateProgressHUD:[NSString stringWithFormat:@"年命: %ld/%lu - %@", (long)index+1, (unsigned long)allUnitCells.count, type]];
        g_s2_currentItemToExtract = type;
        id delegate = targetCV.delegate; NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath]; }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ processQueue(); });
    } copy];
    processQueue();
}

// FIX: Moved helper functions here, inside the %hook block, to ensure they are in scope.
%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value;
}
%new
- (NSString *)GetStringFromLayer:(id)layer {
    if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?";
}

%new
- (NSString *)formatNianmingGejuFromView_S2:(UIView *)contentView {
    Class cellClass = NSClassFromString(@"六壬大占.格局單元"); if (!cellClass) return @"";
    NSMutableArray *cells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, contentView, cells);
    [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
    NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array];
    for (UIView *cell in cells) {
        NSMutableArray *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
        if (labelsInCell.count > 0) {
            UILabel *titleLabel = labelsInCell[0]; NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            NSMutableString *contentString = [NSMutableString string];
            if (labelsInCell.count > 1) { for (NSUInteger i = 1; i < labelsInCell.count; i++) { [contentString appendString:((UILabel *)labelsInCell[i]).text]; } }
            NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content];
            if (![formattedPairs containsObject:pair]) { [formattedPairs addObject:pair]; }
        }
    }
    return [formattedPairs componentsJoinedByString:@"\n"];
}

%new
- (NSString *)extractTextFromFirstViewOfClassName_S2:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { LogMessage(@"[S2] 类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
    NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (NSString *)extractTianDiPanInfo_S2 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;
        id diGongDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"], tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"], tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";
        NSArray *diGongLayers=[diGongDict allValues], *tianShenLayers=[tianShenDict allValues], *tianJiangLayers=[tianJiangDict allValues];
        if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配";
        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (id layer in layers) {
                if (![layer isKindOfClass:[CALayer class]]) continue;
                CALayer *pLayer = [layer presentationLayer] ?: layer;
                CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil];
                CGFloat dx = pos.x - center.x, dy = pos.y - center.y;
                [allLayerInfos addObject:@{ @"type": type, @"text": [self GetStringFromLayer:layer], @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }];
            }
        };
        processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang");
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO; for (NSNumber *angleKey in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angleKey floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angleKey] addObject:info]; foundGroup=YES; break; } }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle]; if (group.count < 3) continue;
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }];
            NSString *diPan=@"?", *tianPan=@"?", *tianJiang=@"?";
            for(NSDictionary* layerInfo in group){ if([layerInfo[@"type"] isEqualToString:@"diPan"]) diPan = layerInfo[@"text"]; else if([layerInfo[@"type"] isEqualToString:@"tianPan"]) tianPan = layerInfo[@"text"]; else if([layerInfo[@"type"] isEqualToString:@"tianJiang"]) tianJiang = layerInfo[@"text"]; }
            [palaceData addObject:@{ @"diPan": diPan, @"tianPan": tianPan, @"tianJiang": tianJiang }];
        }
        if (palaceData.count != 12) return [NSString stringWithFormat:@"天地盘提取失败: 宫位数据不完整 (%ld/12)", (long)palaceData.count];
        NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }];
        NSMutableString *result = [NSMutableString string];
        for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return result;
    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
}
%end

// =========================================================================
// 4. S1 提取函数定义
// =========================================================================
static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie) {
    if (!rootView) return @"[错误: 根视图为空]";
    NSMutableString *finalResult = [NSMutableString string];
    NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews);
    if (stackViews.count > 0) {
        UIStackView *mainStackView = stackViews.firstObject; NSMutableArray *blocks = [NSMutableArray array]; NSMutableDictionary *currentBlock = nil;
        for (UIView *subview in mainStackView.arrangedSubviews) {
            if (![subview isKindOfClass:[UILabel class]]) continue;
            UILabel *label = (UILabel *)subview; NSString *text = label.text; if (!text || text.length == 0) continue;
            BOOL isTitle = (label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0;
            if (isTitle) { if (currentBlock) [blocks addObject:currentBlock]; currentBlock = [NSMutableDictionary dictionaryWithDictionary:@{@"title": text, @"content": [NSMutableString string]}]; } 
            else { if (currentBlock) { NSMutableString *content = currentBlock[@"content"]; if (content.length > 0) [content appendString:@" "]; [content appendString:text]; } }
        }
        if (currentBlock) [blocks addObject:currentBlock];
        for (NSDictionary *block in blocks) {
            NSString *title = block[@"title"]; NSString *content = [block[@"content"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (content.length > 0) { [finalResult appendFormat:@"%@\n%@\n\n", title, content]; } else { [finalResult appendFormat:@"%@\n\n", title]; }
        }
    }
    if (includeXiangJie) {
        Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
        if (tableViewClass) {
            NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, rootView, tableViews);
            if (tableViews.count > 0) {
                NSMutableArray *xiangJieLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], tableViews.firstObject, xiangJieLabels);
                if (xiangJieLabels.count > 0) {
                    [finalResult appendString:@"--- 【详解内容】 ---\n\n"];
                    for (NSUInteger i = 0; i < xiangJieLabels.count; i += 2) {
                        UILabel *titleLabel = xiangJieLabels[i]; if (i + 1 >= xiangJieLabels.count && [titleLabel.text isEqualToString:@"详解"]) continue;
                        if (i + 1 < xiangJieLabels.count) { [finalResult appendFormat:@"%@→%@\n\n", titleLabel.text, ((UILabel*)xiangJieLabels[i+1]).text]; } 
                        else { [finalResult appendFormat:@"%@→\n\n", titleLabel.text]; }
                    }
                }
            }
        }
    }
    return [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// =========================================================================
// 5. 构造函数
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[EchoAI-Ultimate-v7.2] 终极提取器 v7.2 (Final) 已加载。");
    }
}
