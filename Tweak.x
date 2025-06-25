// Filename: UltimateDataHub_v2.1
// 终极数据中枢 v2.1 - 修复编译错误，优化Power模式任务链，功能全面稳定。
// 以 EchoAI-Combined (代码块儿2) 为坚实基础，无缝整合 CombinedExtractor_v1.0 (代码块儿1) 的功能。
// 实现了全新的UI布局和功能划分，提供独立、复合及终极一键提取模式。

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、宏定义与辅助函数 (统一管理)
// =========================================================================

// --- 统一日志 ---
static UITextView *g_logTextView = nil;
static void LogMessage(NSString *format, ...);

// --- 任务状态控制 ---
typedef NS_ENUM(NSInteger, ExtractionTaskType) {
    TaskTypeNone,
    TaskTypeKeTi,          // 课体批量
    TaskTypeJiuZongMen,    // 九宗门
    TaskTypeSiKeSanChuan,  // 四课三传详情 (S1)
    TaskTypeNianMing,      // 年命分析 (S2)
    TaskTypeSimplePopup,   // 通用弹窗 (毕法/格局/方法)
    TaskTypeComposite,     // 复合任务 (Easy/Power)
};
static ExtractionTaskType g_currentTask = TaskTypeNone;
static NSString *g_currentPopupType = nil; // 用于区分毕法、格局等具体弹窗类型

// --- 数据存储 ---
// S1 (四课三传)
static NSMutableArray *g_s1_capturedDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_s1_workQueue = nil;
static NSMutableArray<NSString *> *g_s1_titleQueue = nil;
static NSString *g_s1_finalResult = nil;
static void (^g_s1_completion_handler)(NSString *result) = nil;


// S2 (年命 & 弹窗)
static NSMutableDictionary *g_s2_extractedData = nil;
static NSMutableArray *g_s2_capturedZhaiYaoArray = nil;
static NSMutableArray *g_s2_capturedGeJuArray = nil;
static NSString *g_s2_currentItemToExtract = nil;
static void (^g_s2_nianming_completion_handler)(NSString *nianmingText) = nil;


// 课体批量提取
static NSMutableArray *g_keTi_workQueue = nil;
static NSMutableArray *g_keTi_resultsArray = nil;
static UICollectionView *g_keTi_targetCV = nil;
static void (^g_keTi_completion_handler)(NSString *result) = nil; // 新增：用于Power模式

// Power!!! 模式数据汇总
static NSMutableDictionary *g_powerModeResults = nil;

// --- 全局UI ---
static UIView *g_mainControlPanelView = nil;

// --- 自定义文本块 ---
static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果由 UltimateDataHub v2.1 生成，仅供参考。\n"
"2. 请结合实际情况与专业知识进行综合判断。\n"
"3. [在此处添加您的Prompt或更多说明]";


// --- 辅助函数 (已合并与优化) ---
static void LogMessage(NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, g_logTextView.text];
        NSLog(@"[UltimateDataHub] %@", message);
    });
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// S2的辅助函数
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
static NSString* GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
static UIImage* createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }


// =========================================================================
// 2. UI微调 Hooks (来自S2, 保持不变)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self sendSubviewToBack:watermarkView]; }
%end

// =========================================================================
// 3. 主功能接口声明
// =========================================================================
@interface UIViewController (UltimateDataHub)
// --- UI与主控 ---
- (void)createOrShowMainControlPanel;
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer;
- (void)copyLogAndClose;
- (void)showProgressHUD:(NSString *)text;
- (void)updateProgressHUD:(NSString *)text;
- (void)hideProgressHUD;

// --- 独立功能按钮 ---
- (void)executeKeTiExtraction;
- (void)executeJiuZongMenExtraction;
- (void)executeSiKeSanChuanExtraction;
- (void)executeNianMingExtraction;
- (void)executePopupExtraction:(UIButton *)sender;

// --- 复合功能按钮 ---
- (void)executeEasyMode;
- (void)executePowerMode;

// --- 核心提取逻辑 (内部调用) ---
// 课体
- (void)startKeTiExtractionWithCompletion:(void (^)(NSString *result))completion;
- (void)processKeTiWorkQueue;
// 四课三传 (S1)
- (void)startExtraction_S1_WithCompletion:(void (^)(NSString *result))completion;
- (void)process_S1_Queue;
// 盘面 & 年命 (S2)
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion;
- (void)extractKePanInfo_S2_WithCompletion:(void (^)(NSString *kePanText))completion;
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion;

// --- 辅助方法 ---
- (NSString *)extractTextFromFirstViewOfClassName_S2:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_S2;
- (NSString *)formatNianmingGejuFromView_S2:(UIView *)contentView;
@end


// =========================================================================
// 4. 核心 Hook 实现
// =========================================================================
%hook UIViewController

// --- 统一注入点 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger controlButtonTag = 556699;
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"终极数据中枢" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2);
            controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

// --- 终极弹窗拦截器 ---
- (void)presentViewController:(UIViewController *)vcToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    
    // 拦截1: 课体 或 九宗门
    Class keTiGaiLanClass = NSClassFromString(@"六壬大占.課體概覽視圖");
    if ((g_currentTask == TaskTypeKeTi || g_currentTask == TaskTypeJiuZongMen) && keTiGaiLanClass && [vcToPresent isKindOfClass:keTiGaiLanClass]) {
        vcToPresent.view.alpha = 0.0f; flag = NO;
        
        void (^extractionCompletion)(void) = ^{
            if (completion) { completion(); }
            
            // --- 提取逻辑 ---
            UIView *contentView = vcToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                if (roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];
            NSMutableArray<NSString *> *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) { [textParts addObject:label.text]; }
            }
            NSString *extractedText = [textParts componentsJoinedByString:@"\n"];
            
            if (g_currentTask == TaskTypeKeTi) {
                [g_keTi_resultsArray addObject:extractedText];
                LogMessage(@"成功提取“课体”第 %lu 项...", (unsigned long)g_keTi_resultsArray.count);
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeTiWorkQueue]; // 继续处理队列
                    });
                }];
            } else if (g_currentTask == TaskTypeJiuZongMen) {
                LogMessage(@"成功提取“九宗门”详情！");
                NSString *formattedResult = [NSString stringWithFormat:@"- - - - - - - - - - - - - -\n【九宗门详情】\n- - - - - - - - - - - - - -\n\n%@", extractedText];
                
                if (g_powerModeResults) {
                    g_powerModeResults[@"JiuZongMen"] = formattedResult;
                } else {
                    [UIPasteboard generalPasteboard].string = formattedResult;
                    LogMessage(@"内容已复制到剪贴板！");
                }
                
                g_currentTask = TaskTypeNone;
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            }
        };
        %orig(vcToPresent, flag, extractionCompletion);
        return;
    }

    // 拦截2: 四课三传详情 (S1 逻辑)
    if (g_currentTask == TaskTypeSiKeSanChuan) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            LogMessage(@"[S1] 捕获到弹窗: %@", vcClassName);
            vcToPresent.view.alpha = 0.0f; flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = vcToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
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
                [g_s1_capturedDetailArray addObject:fullDetail];
                LogMessage(@"[S1] 成功提取内容 (共 %lu 条)", (unsigned long)g_s1_capturedDetailArray.count);
                
                [vcToPresent dismissViewControllerAnimated:NO completion:^{
                    const double kDelayInSeconds = 0.2;
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self process_S1_Queue];
                    });
                }];
            };
            %orig(vcToPresent, flag, newCompletion);
            return;
        }
    }
    
    // 拦截3: 毕法/格局/方法/七政 等弹窗
    if ((g_currentTask == TaskTypeComposite && g_s2_extractedData) || g_currentTask == TaskTypeSimplePopup) {
        if (![vcToPresent isKindOfClass:[UIAlertController class]]) {
            vcToPresent.view.alpha = 0.0f; flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *title = vcToPresent.title ?: @"";
                // ... (后面提取逻辑与原版 S2 相同)
                NSMutableArray *textParts = [NSMutableArray array];
                if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                    NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], vcToPresent.view, stackViews); [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                    for (UIStackView *stackView in stackViews) {
                        NSArray *arrangedSubviews = stackView.arrangedSubviews;
                        if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                            UILabel *titleLabel = arrangedSubviews[0]; NSString *rawTitle = titleLabel.text ?: @""; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                            NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            NSMutableArray *descParts = [NSMutableArray array]; if (arrangedSubviews.count > 1) { for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } } }
                            NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                            [textParts addObject:[NSString stringWithFormat:@"%@ → %@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
                        }
                    }
                    NSString *content = [textParts componentsJoinedByString:@"\n"];
                    
                    if (g_currentTask == TaskTypeSimplePopup) {
                        NSString *header = [NSString stringWithFormat:@"- - - - - - - - - - - - - -\n【%@】\n- - - - - - - - - - - - - -\n\n", g_currentPopupType];
                        NSString *formattedResult = [NSString stringWithFormat:@"%@%@", header, content];
                         if (g_powerModeResults) {
                            g_powerModeResults[g_currentPopupType] = formattedResult;
                        } else {
                            [UIPasteboard generalPasteboard].string = formattedResult;
                            LogMessage(@"[%@] 提取完成并已复制！", g_currentPopupType);
                            [self hideProgressHUD];
                        }
                        g_currentTask = TaskTypeNone;
                        g_currentPopupType = nil;
                    } else { // Composite task
                        if ([title containsString:@"方法"]) g_s2_extractedData[@"方法"] = content;
                        else if ([title containsString:@"格局"]) g_s2_extractedData[@"格局"] = content;
                        else g_s2_extractedData[@"毕法"] = content;
                    }
                } else if ([NSStringFromClass([vcToPresent class]) containsString:@"七政"]) {
                    NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                    if(g_s2_extractedData) g_s2_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                }
                
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(vcToPresent, flag, completion);
            return;
        }
    }

    // 拦截4: 年命分析
    if (g_currentTask == TaskTypeNianMing && g_s2_currentItemToExtract) {
        __weak typeof(self) weakSelf = self;
        if ([vcToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)vcToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:g_s2_currentItemToExtract]) {
                    targetAction = action;
                    break;
                }
            }
            if (targetAction) {
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) {
                    ((void (^)(UIAlertAction *))handler)(targetAction);
                }
                return;
            }
        }

        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([g_s2_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = vcToPresent.view;
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
            }];
            NSMutableArray *textParts = [NSMutableArray array];
            for (UILabel *label in allLabels) {
                if (label.text && label.text.length > 0) {
                    [textParts addObject:label.text];
                }
            }
            NSString *compactText = [[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [g_s2_capturedZhaiYaoArray addObject:compactText];
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([g_s2_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                    UIView *contentView = vcToPresent.view;
                    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
                    NSMutableArray *tableViews = [NSMutableArray array];
                    if (tableViewClass) { FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews); }
                    UITableView *theTableView = tableViews.firstObject;
                    if (theTableView && [theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && theTableView.dataSource) {
                        id<UITableViewDelegate> delegate = theTableView.delegate;
                        id<UITableViewDataSource> dataSource = theTableView.dataSource;
                        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:theTableView] : 1;
                        for (NSInteger section = 0; section < sections; section++) {
                            NSInteger rows = [dataSource tableView:theTableView numberOfRowsInSection:section];
                            for (NSInteger row = 0; row < rows; row++) {
                                [delegate tableView:theTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                            }
                        }
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                        NSString *formattedGeju = [strongSelf2 formatNianmingGejuFromView_S2:contentView];
                        [g_s2_capturedGeJuArray addObject:formattedGeju];
                        [vcToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                });
            };
            %orig(vcToPresent, flag, newCompletion);
            return;
        }
    }

    // 如果没有被任何任务拦截，则执行原始调用
    %orig(vcToPresent, flag, completion);
}


// =========================================================================
// 5. 全新UI和控制逻辑
// =========================================================================
%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{
            g_mainControlPanelView.alpha = 0;
            g_mainControlPanelView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil;
        }];
        return;
    }

    CGFloat panelWidth = keyWindow.bounds.size.width - 20;
    CGFloat panelHeight = 550;
    g_mainControlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, (keyWindow.bounds.size.height - panelHeight) / 2, panelWidth, panelHeight)];
    g_mainControlPanelView.tag = panelTag;
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.95];
    g_mainControlPanelView.layer.cornerRadius = 20;
    g_mainControlPanelView.layer.borderColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.7].CGColor;
    g_mainControlPanelView.layer.borderWidth = 1.5;
    g_mainControlPanelView.layer.shadowColor = [UIColor blackColor].CGColor;
    g_mainControlPanelView.layer.shadowRadius = 20;
    g_mainControlPanelView.layer.shadowOpacity = 0.5;
    g_mainControlPanelView.clipsToBounds = NO;
    g_mainControlPanelView.alpha = 0;
    g_mainControlPanelView.transform = CGAffineTransformMakeScale(1.1, 1.1);

    // --- 标题 ---
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, panelWidth, 30)];
    titleLabel.text = @"大六壬终极数据中枢 v2.1";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_mainControlPanelView addSubview:titleLabel];
    
    // --- 复合功能按钮 ---
    CGFloat btnWidth = (panelWidth - 45) / 2;
    UIButton *easyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    easyButton.frame = CGRectMake(15, 65, btnWidth, 48);
    [easyButton setTitle:@"Easy Mode" forState:UIControlStateNormal];
    [easyButton addTarget:self action:@selector(executeEasyMode) forControlEvents:UIControlEventTouchUpInside];
    easyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];

    UIButton *powerButton = [UIButton buttonWithType:UIButtonTypeSystem];
    powerButton.frame = CGRectMake(btnWidth + 30, 65, btnWidth, 48);
    [powerButton setTitle:@"Power!!!" forState:UIControlStateNormal];
    [powerButton addTarget:self action:@selector(executePowerMode) forControlEvents:UIControlEventTouchUpInside];
    powerButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.3 blue:0.13 alpha:1.0];

    for (UIButton *btn in @[easyButton, powerButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:18];
        btn.layer.cornerRadius = 10;
        [g_mainControlPanelView addSubview:btn];
    }
    
    // --- 分割线 ---
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(20, 128, panelWidth - 40, 1)];
    divider.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    [g_mainControlPanelView addSubview:divider];

    // --- 独立功能按钮网格 ---
    NSArray *buttonTitles = @[@"课体提取", @"九宗门详情", @"四课三传详解", @"年命分析", @"毕法全览", @"格局全览", @"方法全览", @"复制日志并关闭"];
    NSArray *buttonSelectors = @[@"executeKeTiExtraction", @"executeJiuZongMenExtraction", @"executeSiKeSanChuanExtraction", @"executeNianMingExtraction", @"executePopupExtraction:", @"executePopupExtraction:", @"executePopupExtraction:", @"copyLogAndClose"];
    
    CGFloat gridYStart = 145;
    CGFloat smallBtnWidth = (panelWidth - 45) / 2;
    CGFloat smallBtnHeight = 44;

    for (int i = 0; i < buttonTitles.count; i++) {
        int row = i / 2;
        int col = i % 2;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(15 + col * (smallBtnWidth + 15), gridYStart + row * (smallBtnHeight + 10), smallBtnWidth, smallBtnHeight);
        [btn setTitle:buttonTitles[i] forState:UIControlStateNormal];
        [btn addTarget:self action:NSSelectorFromString(buttonSelectors[i]) forControlEvents:UIControlEventTouchUpInside];
        btn.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        btn.layer.cornerRadius = 8;

        if ([buttonSelectors[i] isEqualToString:@"executePopupExtraction:"]) {
            if ([buttonTitles[i] containsString:@"毕法"]) btn.tag = 1;
            if ([buttonTitles[i] containsString:@"格局"]) btn.tag = 2;
            if ([buttonTitles[i] containsString:@"方法"]) btn.tag = 3;
        }
        
        [g_mainControlPanelView addSubview:btn];
    }
    
    // --- 日志窗口 ---
    CGFloat logYStart = gridYStart + 4 * (smallBtnHeight + 10) + 10;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, logYStart, panelWidth - 20, panelHeight - logYStart - 10)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.7];
    g_logTextView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"终极数据中枢 v2.1 已就绪。\n";
    [g_mainControlPanelView addSubview:g_logTextView];
    
    // --- 拖动手势 ---
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanelPan:)];
    [g_mainControlPanelView addGestureRecognizer:pan];
    
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        g_mainControlPanelView.alpha = 1;
        g_mainControlPanelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

%new
- (void)handlePanelPan:(UIPanGestureRecognizer *)recognizer {
    UIView *panel = recognizer.view;
    CGPoint translation = [recognizer translationInView:panel.superview];
    panel.center = CGPointMake(panel.center.x + translation.x, panel.center.y + translation.y);
    [recognizer setTranslation:CGPointZero inView:panel.superview];
}

%new
- (void)copyLogAndClose {
    if (g_logTextView && g_logTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logTextView.text;
        LogMessage(@"日志内容已复制到剪贴板！");
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (g_mainControlPanelView) {
            [g_mainControlPanelView removeFromSuperview];
            g_mainControlPanelView = nil;
            g_logTextView = nil;
        }
    });
}

%new
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
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
- (void)updateProgressHUD:(NSString *)text {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
    NSInteger progressViewTag = 556677;
    UIView *progressView = [keyWindow viewWithTag:progressViewTag];
    if (progressView) {
        for (UIView *subview in progressView.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                ((UILabel *)subview).text = text;
                break;
            }
        }
    }
}

%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
    NSInteger progressViewTag = 556677;
    UIView *progressView = [keyWindow viewWithTag:progressViewTag];
    if (progressView) {
        [UIView animateWithDuration:0.3 animations:^{
            progressView.alpha = 0;
        } completion:^(BOOL finished) {
            [progressView removeFromSuperview];
        }];
    }
}


// =========================================================================
// 6. 独立功能实现
// =========================================================================

// --- 课体提取 ---
%new
- (void)executeKeTiExtraction {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    [self startKeTiExtractionWithCompletion:nil];
}

%new
- (void)startKeTiExtractionWithCompletion:(void (^)(NSString *result))completion {
    if (g_currentTask != TaskTypeNone && g_currentTask != TaskTypeComposite) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    LogMessage(@"--- 开始“课体”批量提取任务 ---");
    if (!completion) {
      [self showProgressHUD:@"正在查找课体列表..."];
    }

    UIWindow *keyWindow = self.view.window;
    if (!keyWindow) { 
        LogMessage(@"错误: 找不到主窗口。"); 
        if (!completion) [self hideProgressHUD];
        if (completion) completion(@"[课体提取失败: 找不到主窗口]");
        return;
    }
    
    g_keTi_targetCV = nil;
    Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (!keTiCellClass) { 
        LogMessage(@"错误: 找不到 '六壬大占.課體單元' 类。"); 
        if (!completion) [self hideProgressHUD];
        if (completion) completion(@"[课体提取失败: 找不到单元类]");
        return;
    }
    
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
    
    for (UICollectionView *cv in allCVs) {
        for (UICollectionViewCell *cell in cv.visibleCells) {
             if ([cell isKindOfClass:keTiCellClass]) {
                 g_keTi_targetCV = cv; break;
             }
        }
        if (g_keTi_targetCV) { break; }
    }

    if (!g_keTi_targetCV) { 
        LogMessage(@"错误: 找不到包含“课体”的UICollectionView。");
        if (!completion) [self hideProgressHUD];
        if (completion) completion(@"[课体提取失败: 找不到列表视图]");
        return;
    }
    
    g_currentTask = TaskTypeKeTi;
    g_keTi_workQueue = [NSMutableArray array];
    g_keTi_resultsArray = [NSMutableArray array];
    g_keTi_completion_handler = completion;
    
    NSInteger totalItems = [g_keTi_targetCV.dataSource collectionView:g_keTi_targetCV numberOfItemsInSection:0];
    for (NSInteger i = 0; i < totalItems; i++) {
        [g_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]];
    }

    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"错误: 未找到任何“课体”单元来创建任务队列。");
        g_currentTask = TaskTypeNone;
        if (!completion) [self hideProgressHUD];
        if (completion) completion(@"[课体提取失败: 列表为空]");
        g_keTi_completion_handler = nil;
        return;
    }

    LogMessage(@"发现 %lu 个“课体”单元，开始处理队列...", (unsigned long)g_keTi_workQueue.count);
    if (!completion) {
      NSUInteger totalCount = g_keTi_workQueue.count;
      [self updateProgressHUD:[NSString stringWithFormat:@"正在提取课体 1/%lu", (unsigned long)totalCount]];
    }
    [self processKeTiWorkQueue];
}


%new
- (void)processKeTiWorkQueue {
    if (g_keTi_workQueue.count == 0) {
        LogMessage(@"所有 %lu 项“课体”任务处理完毕！", (unsigned long)g_keTi_resultsArray.count);
        NSMutableString *finalResult = [NSMutableString string];
        [finalResult appendString:@"- - - - - - - - - - - - - -\n【课体信息详解】\n- - - - - - - - - - - - - -\n\n"];
        for (NSUInteger i = 0; i < g_keTi_resultsArray.count; i++) {
            [finalResult appendFormat:@"--- 课体第 %lu 项详情 ---\n", (unsigned long)i + 1];
            [finalResult appendString:g_keTi_resultsArray[i]];
            [finalResult appendString:@"\n\n"];
        }
        
        if (g_keTi_completion_handler) {
            g_keTi_completion_handler(finalResult);
        } else {
            [UIPasteboard generalPasteboard].string = finalResult;
            LogMessage(@"“课体”批量提取完成，所有内容已合并并复制！");
            [self hideProgressHUD];
        }
        
        if (!g_keTi_completion_handler) { // Power 模式下不重置任务类型
            g_currentTask = TaskTypeNone;
        }
        g_keTi_targetCV = nil;
        g_keTi_workQueue = nil;
        g_keTi_resultsArray = nil;
        g_keTi_completion_handler = nil;
        return;
    }
    
    NSIndexPath *indexPath = g_keTi_workQueue.firstObject;
    [g_keTi_workQueue removeObjectAtIndex:0];
    
    if (!g_keTi_completion_handler) {
        NSUInteger totalCount = g_keTi_resultsArray.count + g_keTi_workQueue.count + 1;
        NSUInteger currentCount = g_keTi_resultsArray.count + 1;
        LogMessage(@"正在处理“课体”第 %lu/%lu 项...", currentCount, totalCount);
        [self updateProgressHUD:[NSString stringWithFormat:@"正在提取课体 %lu/%lu", currentCount, totalCount]];
    }
    
    id delegate = g_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_keTi_targetCV didSelectItemAtIndexPath:indexPath];
    }
}


// --- 九宗门提取 ---
%new
- (void)executeJiuZongMenExtraction {
    if (g_currentTask != TaskTypeNone && g_currentTask != TaskTypeComposite) { LogMessage(@"错误：已有任务在进行中。"); return; }

    LogMessage(@"--- 开始“九宗门”提取任务 ---");
    g_currentTask = TaskTypeJiuZongMen;

    SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
    if ([self respondsToSelector:selector]) {
        LogMessage(@"正在调用方法: 顯示九宗門概覽");
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: 当前ViewController没有'顯示九宗門概覽'方法。");
        if(g_powerModeResults) g_powerModeResults[@"JiuZongMen"] = @"[九宗门提取失败: 方法不存在]";
        g_currentTask = TaskTypeNone;
    }
}

// --- 四课三传详情 ---
%new
- (void)executeSiKeSanChuanExtraction {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    [self showProgressHUD:@"开始提取四课三传..."];
    [self startExtraction_S1_WithCompletion:^(NSString *result) {
        if (!g_powerModeResults) {
            [UIPasteboard generalPasteboard].string = result;
            LogMessage(@"四课三传详情提取完成并已复制!");
            [self hideProgressHUD];
        }
    }];
}

// --- 年命分析 ---
%new
- (void)executeNianMingExtraction {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    [self showProgressHUD:@"开始提取年命信息..."];
    [self extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
        if (!g_powerModeResults) {
            NSString *formattedResult = [NSString stringWithFormat:@"- - - - - - - - - - - - - -\n【年命分析】\n- - - - - - - - - - - - - -\n\n%@", nianmingText];
            [UIPasteboard generalPasteboard].string = formattedResult;
            LogMessage(@"年命信息提取完成并已复制！");
            [self hideProgressHUD];
        }
    }];
}

// --- 弹窗提取 (毕法/格局/方法) ---
%new
- (void)executePopupExtraction:(UIButton *)sender {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    SEL selectorToCall = nil;
    NSString *taskName = nil;
    
    switch (sender.tag) {
        case 1: 
            taskName = @"毕法";
            selectorToCall = NSSelectorFromString(@"顯示法訣總覽");
            break;
        case 2:
            taskName = @"格局";
            selectorToCall = NSSelectorFromString(@"顯示格局總覽");
            break;
        case 3:
            taskName = @"方法";
            selectorToCall = NSSelectorFromString(@"顯示方法總覽");
            break;
        default:
            LogMessage(@"错误：未知的按钮Tag。");
            return;
    }

    if ([self respondsToSelector:selectorToCall]) {
        LogMessage(@"--- 开始 [%@] 提取任务 ---", taskName);
        [self showProgressHUD:[NSString stringWithFormat:@"正在提取%@...", taskName]];
        g_currentTask = TaskTypeSimplePopup;
        g_currentPopupType = taskName;
        
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selectorToCall withObject:nil];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"错误: 当前VC没有'%@'方法。", NSStringFromSelector(selectorToCall));
    }
}


// =========================================================================
// 7. 复合功能实现 (Easy & Power)
// =========================================================================
%new
- (void)executeEasyMode {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    LogMessage(@"--- 开始执行 [Easy mode] ---");
    g_currentTask = TaskTypeComposite;
    [self showProgressHUD:@"正在执行Easy mode..."];
    
    [self performSimpleAnalysis_S2_WithCompletion:^(NSString *resultText) {
        [self hideProgressHUD];
        if (!g_powerModeResults) {
             [UIPasteboard generalPasteboard].string = resultText;
             LogMessage(@"[Easy mode] 结果已成功复制到剪贴板。");
        }
        g_currentTask = TaskTypeNone;
        LogMessage(@"--- [Easy mode] 任务全部完成 ---");
    }];
}

%new
- (void)executePowerMode {
    if (g_currentTask != TaskTypeNone) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    LogMessage(@"--- !!! 开始终极提取 [Power Mode] !!! ---");
    g_currentTask = TaskTypeComposite;
    g_powerModeResults = [NSMutableDictionary dictionary];

    __weak typeof(self) weakSelf = self;
    
    void (^startNextTask)(void);
    __block int step = 1;
    int totalSteps = 5;

    void (^finalizePowerMode)(void) = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        LogMessage(@"[Power Mode] 所有模块提取完毕，正在整合数据...");
        [strongSelf updateProgressHUD:@"正在整合所有数据..."];

        NSMutableString *finalString = [NSMutableString string];
        [finalString appendString:@"# 大六壬终极数据报告 (Power Mode)\n\n"];
        
        // 1. Easy Mode 基础盘面
        NSString *easyResult = g_powerModeResults[@"EasyMode"] ?: @"";
        [finalString appendString:easyResult];
        [finalString appendString:@"\n\n"];
        
        // 2. 课体
        NSString *keTiResult = g_powerModeResults[@"KeTi"] ?: @"";
        [finalString appendString:keTiResult];

        // 3. 九宗门
        NSString *jiuZongMenResult = g_powerModeResults[@"JiuZongMen"] ?: @"";
        [finalString appendString:jiuZongMenResult];
        
        // 4. 四课三传详情
        NSString *s1Result = g_powerModeResults[@"SiKeSanChuan"] ?: @"";
        [finalString appendString:s1Result];

        // 5. 年命
        NSString *nianMingResult = g_powerModeResults[@"NianMing"] ?: @"";
        [finalString appendString:nianMingResult];
        
        [finalString appendString:CustomFooterText];
        
        [UIPasteboard generalPasteboard].string = finalString;
        LogMessage(@"[Power Mode] 终极提取完成！所有数据已整合并复制到剪贴板！");
        [strongSelf hideProgressHUD];
        
        g_powerModeResults = nil;
        g_currentTask = TaskTypeNone;
    };
    
    startNextTask = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        
        switch (step) {
            case 1: { // Easy Mode
                [strongSelf updateProgressHUD:[NSString stringWithFormat:@"步骤 %d/%d: 提取基础盘面 (Easy)", step, totalSteps]];
                [strongSelf performSimpleAnalysis_S2_WithCompletion:^(NSString *resultText) {
                    g_powerModeResults[@"EasyMode"] = resultText;
                    step++; startNextTask();
                }];
                break;
            }
            
            case 2: { // 课体
                [strongSelf updateProgressHUD:[NSString stringWithFormat:@"步骤 %d/%d: 提取课体详情...", step, totalSteps]];
                [strongSelf startKeTiExtractionWithCompletion:^(NSString *result) {
                    g_powerModeResults[@"KeTi"] = result;
                    step++; startNextTask();
                }];
                break;
            }

            case 3: { // 九宗门
                [strongSelf updateProgressHUD:[NSString stringWithFormat:@"步骤 %d/%d: 提取九宗门...", step, totalSteps]];
                 [strongSelf executeJiuZongMenExtraction];
                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                     step++; startNextTask();
                 });
                 break;
            }

            case 4: { // 四课三传
                [strongSelf updateProgressHUD:[NSString stringWithFormat:@"步骤 %d/%d: 提取四课三传详解...", step, totalSteps]];
                [strongSelf startExtraction_S1_WithCompletion:^(NSString *result) {
                    g_powerModeResults[@"SiKeSanChuan"] = result;
                    step++; startNextTask();
                }];
                break;
            }

            case 5: { // 年命
                 [strongSelf updateProgressHUD:[NSString stringWithFormat:@"步骤 %d/%d: 提取年命分析...", step, totalSteps]];
                 [strongSelf extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
                     g_powerModeResults[@"NianMing"] = nianmingText;
                     step++; startNextTask();
                 }];
                 break;
            }

            default: {
                finalizePowerMode();
                break;
            }
        }
    } copy];
    
    startNextTask();
}


// =========================================================================
// 8. 原始核心功能实现 (S1, S2等)
// =========================================================================
%new
- (void)startExtraction_S1_WithCompletion:(void (^)(NSString *result))completion {
    if (g_currentTask != TaskTypeNone && g_currentTask != TaskTypeComposite) { LogMessage(@"[S1] 错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"[S1] 开始提取任务...");
    g_currentTask = TaskTypeSiKeSanChuan;
    g_s1_completion_handler = completion;
    g_s1_capturedDetailArray = [NSMutableArray array];
    g_s1_workQueue = [NSMutableArray array];
    g_s1_titleQueue = [NSMutableArray array];

    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(@"[S1] 致命错误: 找不到总容器 '課傳' 的ivar。"); g_currentTask = TaskTypeNone; if(g_s1_completion_handler) g_s1_completion_handler(@"[S1提取失败: 找不到容器]"); g_s1_completion_handler = nil; return; }
    id keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer || ![keChuanContainer isKindOfClass:[UIView class]]) { LogMessage(@"[S1] 致命错误: '課傳' 总容器视图为nil或类型错误。"); g_currentTask = TaskTypeNone; if(g_s1_completion_handler) g_s1_completion_handler(@"[S1提取失败: 容器错误]"); g_s1_completion_handler = nil; return; }
    
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults);
    
    if (sanChuanResults.count > 0) {
        UIView *sanChuanContainer = sanChuanResults.firstObject;
        const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
        for (int i = 0; ivarNames[i] != NULL; ++i) {
            Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue;
            UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue;
            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1];
                if (dizhiLabel.gestureRecognizers.count > 0) {
                    [g_s1_workQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"diZhi"} mutableCopy]];
                    [g_s1_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                }
                if (tianjiangLabel.gestureRecognizers.count > 0) {
                    [g_s1_workQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"tianJiang"} mutableCopy]];
                    [g_s1_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
    
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults);
    if (siKeResults.count > 0) {
        UIView *siKeContainer = siKeResults.firstObject;
        NSDictionary *keDefinitions[] = {
            @{@"title": @"第一课", @"xiaShen": @"日",   @"shangShen": @"日上", @"tianJiang": @"日上天將"},
            @{@"title": @"第二课", @"xiaShen": @"日上", @"shangShen": @"日陰", @"tianJiang": @"日陰天將"},
            @{@"title": @"第三课", @"xiaShen": @"辰",   @"shangShen": @"辰上", @"tianJiang": @"辰上天將"},
            @{@"title": @"第四课", @"xiaShen": @"辰上", @"shangShen": @"辰陰", @"tianJiang": @"辰陰天將"}
        };
        void (^addTaskBlock)(const char*, NSString*, NSString*) = ^(const char* ivarName, NSString* fullTitle, NSString* taskType) {
            if (!ivarName) return;
            Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarName);
            if (ivar) {
                UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar);
                if (label && [label isKindOfClass:[UILabel class]] && label.gestureRecognizers.count > 0) {
                    [g_s1_workQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"contextView": siKeContainer, @"taskType": taskType} mutableCopy]];
                    NSString *finalTitle = [NSString stringWithFormat:@"%@ (%@)", fullTitle, label.text];
                    [g_s1_titleQueue addObject:finalTitle];
                }
            }
        };
        for (int i = 0; i < 4; ++i) {
            NSDictionary *def = keDefinitions[i];
            NSString *keTitle = def[@"title"];
            addTaskBlock([def[@"xiaShen"] UTF8String],   [NSString stringWithFormat:@"%@ - 下神", keTitle], @"diZhi");
            addTaskBlock([def[@"shangShen"] UTF8String], [NSString stringWithFormat:@"%@ - 上神", keTitle], @"diZhi");
            addTaskBlock([def[@"tianJiang"] UTF8String], [NSString stringWithFormat:@"%@ - 天将", keTitle], @"tianJiang");
        }
    }

    if (g_s1_workQueue.count == 0) {
        LogMessage(@"[S1] 队列为空，未找到任何可提取项。");
        g_currentTask = TaskTypeNone;
        if(g_s1_completion_handler) g_s1_completion_handler(@"[S1提取失败: 队列为空]");
        g_s1_completion_handler = nil;
        return;
    }
    
    LogMessage(@"[S1] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_s1_workQueue.count);
    [self process_S1_Queue];
}

%new
- (void)process_S1_Queue {
    if (g_s1_workQueue.count == 0) {
        LogMessage(@"[S1] 全部任务处理完毕！");
        NSMutableString *resultStr = [NSMutableString string];
        if (g_s1_capturedDetailArray && g_s1_titleQueue && g_s1_capturedDetailArray.count == g_s1_titleQueue.count) {
            [resultStr appendString:@"- - - - - - - - - - - - - -\n【四课三传详解】\n- - - - - - - - - - - - - -\n\n"];
            for (NSUInteger i = 0; i < g_s1_titleQueue.count; i++) {
                NSString *title = g_s1_titleQueue[i];
                NSString *detail = g_s1_capturedDetailArray[i];
                [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
            }
            g_s1_finalResult = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            g_s1_finalResult = @"[S1 提取失败: 标题和内容数量不匹配]";
        }
        
        if (!g_powerModeResults) { // Power模式不重置
            g_currentTask = TaskTypeNone;
        }
        
        if (g_s1_completion_handler) {
            g_s1_completion_handler(g_s1_finalResult);
            g_s1_completion_handler = nil;
        }
        return;
    }
    
    NSMutableDictionary *task = g_s1_workQueue.firstObject;
    [g_s1_workQueue removeObjectAtIndex:0];
    
    NSString *title = g_s1_titleQueue[g_s1_capturedDetailArray.count];
    UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
    NSString *taskType = task[@"taskType"];
    
    LogMessage(@"[S1] 正在处理: %@ (类型: %@)", title, taskType);
    
    SEL actionToPerform = [taskType isEqualToString:@"tianJiang"] ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:");
    
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        LogMessage(@"[S1] 错误！方法 %@ 不存在。", NSStringFromSelector(actionToPerform));
        [g_s1_capturedDetailArray addObject:@"[提取失败: 方法不存在]"];
        [self process_S1_Queue];
    }
}

%new
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion {
    __weak typeof(self) weakSelf = self;
    [self extractKePanInfo_S2_WithCompletion:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        LogMessage(@"[S2] 课盘信息提取完成。");
        [strongSelf updateProgressHUD:@"正在提取年命信息..."];
        [strongSelf extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            LogMessage(@"[S2] 年命信息提取完成。");
            
            NSString *finalCombinedText;
            if (nianmingText && nianmingText.length > 0) {
                finalCombinedText = [NSString stringWithFormat:@"%@\n\n- - - - - - - - - - - - - -\n【年命分析】\n- - - - - - - - - - - - - -\n\n%@%@", kePanText, nianmingText, CustomFooterText];
            } else {
                finalCombinedText = [NSString stringWithFormat:@"%@%@", kePanText, CustomFooterText];
            }
            
            if(completion) {
                completion([finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
            }
        }];
    }];
}

%new
- (void)extractKePanInfo_S2_WithCompletion:(void (^)(NSString *kePanText))completion {
    #define SafeString(str) (str ?: @"")
    g_s2_extractedData = [NSMutableDictionary dictionary];
    LogMessage(@"[S2-KePan] 提取时间、月将、空亡等基础信息...");
    g_s2_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName_S2:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_s2_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.七政視圖" separator:@" "];
    g_s2_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.旬空視圖" separator:@""];
    g_s2_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.三宮時視圖" separator:@" "];
    g_s2_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_s2_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.課體視圖" separator:@" "];
    g_s2_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.九宗門視圖" separator:@" "];
    g_s2_extractedData[@"天地盘"] = [self extractTianDiPanInfo_S2];
    
    LogMessage(@"[S2-KePan] 提取四课信息...");
    NSMutableString *siKe = [NSMutableString string]; Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if(siKeViews.count > 0){
            UIView *container=siKeViews.firstObject; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels);
            if(labels.count >= 12){
                NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label]; }
                if (cols.allKeys.count == 4) {
                    NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=cols[keys[0]],*c2=cols[keys[1]],*c3=cols[keys[2]],*c4=cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString *k1s=((UILabel*)c4[0]).text, *k1t=((UILabel*)c4[1]).text, *k1d=((UILabel*)c4[2]).text;
                    NSString *k2s=((UILabel*)c3[0]).text, *k2t=((UILabel*)c3[1]).text, *k2d=((UILabel*)c3[2]).text;
                    NSString *k3s=((UILabel*)c2[0]).text, *k3t=((UILabel*)c2[1]).text, *k3d=((UILabel*)c2[2]).text;
                    NSString *k4s=((UILabel*)c1[0]).text, *k4t=((UILabel*)c1[1]).text, *k4d=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@→%@%@\n第二课: %@→%@%@\n第三课: %@→%@%@\n第四课: %@→%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_s2_extractedData[@"四课"] = siKe;

    LogMessage(@"[S2-KePan] 提取三传信息...");
    NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray array];
        for(NSUInteger i = 0; i < scViews.count; i++){
            UIView *v = scViews[i]; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 3){
                NSString *lq=((UILabel*)labels.firstObject).text, *tj=((UILabel*)labels.lastObject).text, *dz=((UILabel*)[labels objectAtIndex:labels.count-2]).text;
                NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for(UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count-3)]){ if(l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ss = [ssParts componentsJoinedByString:@" "]; NSMutableString *line = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [line appendFormat:@" (%@)", ss]; }
                [lines addObject:[NSString stringWithFormat:@"%@ %@", (i < titles.count) ? titles[i] : @"", line]];
            }
        }
        sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_s2_extractedData[@"三传"] = sanChuan;
    
    LogMessage(@"[S2-KePan] 提取毕法、格局、七政等弹窗信息...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa=NSSelectorFromString(@"顯示法訣總覽"), sGeJu=NSSelectorFromString(@"顯示格局總覽"), sQiZheng=NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa=NSSelectorFromString(@"顯示方法總覽");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *biFa = g_s2_extractedData[@"毕法"]?:@"", *geJu = g_s2_extractedData[@"格局"]?:@"", *fangFa = g_s2_extractedData[@"方法"]?:@"";
            NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"]; for (NSString *t in trash) { biFa=[biFa stringByReplacingOccurrencesOfString:t withString:@""]; geJu=[geJu stringByReplacingOccurrencesOfString:t withString:@""]; fangFa=[fangFa stringByReplacingOccurrencesOfString:t withString:@""]; }
            if(biFa.length>0) biFa=[NSString stringWithFormat:@"\n【毕法】\n%@\n", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"\n【格局】\n%@\n", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"\n【方法】\n%@\n", fangFa];
            NSString *qiZheng = g_s2_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"\n【七政四余】\n%@\n", g_s2_extractedData[@"七政四余"]] : @"";
            NSString *tianDiPan = g_s2_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_s2_extractedData[@"天地盘"]] : @"";
            
            NSString *finalText = [NSString stringWithFormat:
            @"%@\n\n月将: %@ | 空亡: %@ | 三宫时: %@\n昼夜: %@ | 课体: %@ | 九宗门: %@\n\n- - - - - 【盘面详情】 - - - - -\n\n%@\n【四课】\n%@\n\n【三传】\n%@\n%@%@%@%@",
            SafeString(g_s2_extractedData[@"时间块"]), SafeString(g_s2_extractedData[@"月将"]), SafeString(g_s2_extractedData[@"空亡"]), SafeString(g_s2_extractedData[@"三宫时"]), SafeString(g_s2_extractedData[@"昼夜"]), SafeString(g_s2_extractedData[@"课体"]), SafeString(g_s2_extractedData[@"九宗门"]), tianDiPan, SafeString(g_s2_extractedData[@"四课"]), SafeString(g_s2_extractedData[@"三传"]), biFa, geJu, fangFa, qiZheng];
            
            g_s2_extractedData = nil;
            if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        });
    });
}

%new
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion {
    if (g_currentTask != TaskTypeNone && g_currentTask != TaskTypeComposite) { LogMessage(@"错误：已有任务在进行中。"); return; }
    
    g_currentTask = TaskTypeNianMing;
    g_s2_capturedZhaiYaoArray = [NSMutableArray array];
    g_s2_capturedGeJuArray = [NSMutableArray array];
    g_s2_nianming_completion_handler = completion;
    
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { LogMessage(@"[S2-Nianming] 未找到行年单元，跳过。"); g_currentTask = TaskTypeNone; if (completion) { completion(@""); } return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { LogMessage(@"[S2-Nianming] 行年单元数量为0，跳过。"); g_currentTask = TaskTypeNone; if (completion) { completion(@""); } return; }
    
    NSMutableArray *workQueue = [NSMutableArray array];
    for (NSUInteger i = 0; i < allUnitCells.count; i++) {
        UICollectionViewCell *cell = allUnitCells[i];
        [workQueue addObject:@{@"type": @"年命摘要", @"cell": cell, @"index": @(i)}];
        [workQueue addObject:@{@"type": @"格局方法", @"cell": cell, @"index": @(i)}];
    }
    
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            LogMessage(@"[S2-Nianming] 所有年命任务处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            NSUInteger personCount = allUnitCells.count;
            for (NSUInteger i = 0; i < personCount; i++) {
                NSString *zhaiYao = (i < g_s2_capturedZhaiYaoArray.count) ? g_s2_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_s2_capturedGeJuArray.count) ? g_s2_capturedGeJuArray[i] : @"[年命格局未提取到]";
                [resultStr appendFormat:@"--- 人员 %lu ---\n", (unsigned long)i+1];
                [resultStr appendString:@"【年命摘要】\n"];
                [resultStr appendString:zhaiYao];
                [resultStr appendString:@"\n\n【格局方法】\n"];
                [resultStr appendString:geJu];
                if (i < personCount - 1) { [resultStr appendString:@"\n\n--------------------\n\n"]; }
            }
            
            if (!g_powerModeResults) { // Power模式不重置
                g_currentTask = TaskTypeNone;
            }
            if (g_s2_nianming_completion_handler) { g_s2_nianming_completion_handler(resultStr); }
            g_s2_nianming_completion_handler = nil;
            processQueue = nil;
            return;
        }
        NSDictionary *item = workQueue.firstObject; [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"]; UICollectionViewCell *cell = item[@"cell"]; NSInteger index = [item[@"index"] integerValue];
        LogMessage(@"[S2-Nianming] 正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        g_s2_currentItemToExtract = type;
        id delegate = targetCV.delegate; NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    } copy];
    processQueue();
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
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;
        
        id diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        id tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        id tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

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
                [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }];
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
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count < 3) continue;
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }];
            NSString *diPanText = @"?", *tianPanText = @"?", *tianJiangText = @"?";
            for(NSDictionary* layerInfo in group){
                if([layerInfo[@"type"] isEqualToString:@"diPan"]) diPanText = layerInfo[@"text"];
                else if([layerInfo[@"type"] isEqualToString:@"tianPan"]) tianPanText = layerInfo[@"text"];
                else if([layerInfo[@"type"] isEqualToString:@"tianJiang"]) tianJiangText = layerInfo[@"text"];
            }
            [palaceData addObject:@{ @"diPan": diPanText, @"tianPan": tianPanText, @"tianJiang": tianJiangText }];
        }
        if (palaceData.count != 12) return [NSString stringWithFormat:@"天地盘提取失败: 宫位数据不完整 (%ld/12)", (long)palaceData.count];
        
        NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            NSUInteger index1 = [order indexOfObject:o1[@"diPan"]];
            NSUInteger index2 = [order indexOfObject:o2[@"diPan"]];
            return [@(index1) compare:@(index2)];
        }];
        
        NSMutableString *result = [NSMutableString stringWithString:@"【天地盘】\n"];
        for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return result;
    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
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
            if (labelsInCell.count > 1) {
                for (NSUInteger i = 1; i < labelsInCell.count; i++) { [contentString appendString:((UILabel *)labelsInCell[i]).text]; }
            }
            NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content];
            if (![formattedPairs containsObject:pair]) { [formattedPairs addObject:pair]; }
        }
    }
    return [formattedPairs componentsJoinedByString:@"\n"];
}

%end

%ctor {
    NSLog(@"[UltimateDataHub] v2.1已加载。所有功能通过主面板触发。");
}
