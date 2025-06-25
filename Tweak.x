#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =====================================================================================
// 1. 全局变量、宏定义与核心辅助函数 (整合自两个脚本)
// =====================================================================================

// --- 统一日志系统 ---
static UITextView *g_unifiedLogTextView = nil;
static void LogMessage(NSString *format, ...) {
    if (!g_unifiedLogTextView) {
        // 如果UI还没创建，就先打印到控制台
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"[UnifiedExtractor-Log] %@", message);
        return;
    }
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss.SSS"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSString *fullMessage = [logPrefix stringByAppendingString:message];
        
        // 保持滚动条在顶部
        NSString *oldText = g_unifiedLogTextView.text ?: @"";
        g_unifiedLogTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, oldText];
        NSLog(@"[UnifiedExtractor] %@", message);
    });
}


// --- 脚本1 (课传详情) 所需的全局变量 ---
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

// --- 脚本2 (高级技法) 所需的全局变量 ---
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;

// --- 统一控制面板所需的全局变量 ---
static UIView *g_unifiedControlPanel = nil;
static NSString *g_lastResultString = nil; // 用于存储最后一次生成的结果，方便复制

// --- 自定义文本 ---
static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果由 EchoAI 定制脚本生成，仅供参考。\n"
"2. 请结合实际情况进行判断。\n"
"3. [Prompt: 请基于以上六壬课盘信息，进行详细分析。]";


// --- 辅助函数 (来自两个脚本，已去重) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
static NSString * GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
static UIImage * createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }


// =====================================================================================
// 2. UI微调 Hooks (UILabel, UIWindow) - 来自原脚本2，保持不变
// =====================================================================================
%hook UILabel
(void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
(void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIWindow
(void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self sendSubviewToBack:watermarkView]; }
%end


// =====================================================================================
// 3. 主功能区：统一的 UIViewController 扩展
// =====================================================================================
@interface UIViewController (EchoAIUnifiedExtractor)
// --- 新的统一UI和流程控制 ---
- (void)createOrShowUnifiedPanel;
- (void)startSimpleExtraction_Unified;
- (void)startComplexExtraction_Unified;
- (void)copyAndClose_Unified;
- (void)setPanelButtonsEnabled:(BOOL)enabled;

// --- 封装后的原脚本1的核心逻辑 ---
- (void)_performDetailedKeChuanExtractionWithCompletion:(void (^)(NSString *resultText))completion;
- (void)_processKeChuanQueueWithCompletion:(void (^)(NSString *resultText))completion;
- (void)_startKeChuanExtractionSetup;

// --- 封装后的原脚本2的核心逻辑 ---
- (void)_performAdvancedAnalysisExtractionWithCompletion:(void (^)(NSString *resultText))completion;
- (void)_extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion;
- (void)_extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
- (NSString *)_extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)_extractTianDiPanInfo_V18;
- (NSString *)_formatNianmingGejuFromView:(UIView *)contentView;
@end


%hook UIViewController

// --- 统一的 viewDidLoad Hook ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger unifiedButtonTag = 778899;
            // 移除可能残留的旧按钮
            for (int tag in @[@556691, @112244]) {
                 if ([keyWindow viewWithTag:tag]) [[keyWindow viewWithTag:tag] removeFromSuperview];
            }
            if ([keyWindow viewWithTag:unifiedButtonTag]) { return; } // 如果新按钮已存在，则不重复添加
            
            UIButton *unifiedButton = [UIButton buttonWithType:UIButtonTypeSystem];
            unifiedButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            unifiedButton.tag = unifiedButtonTag;
            [unifiedButton setTitle:@"高级提取面板" forState:UIControlStateNormal];
            unifiedButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            unifiedButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0];
            [unifiedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            unifiedButton.layer.cornerRadius = 8;
            unifiedButton.layer.shadowColor = [UIColor blackColor].CGColor;
            unifiedButton.layer.shadowOffset = CGSizeMake(0, 2);
            unifiedButton.layer.shadowOpacity = 0.4;
            unifiedButton.layer.shadowRadius = 3;
            [unifiedButton addTarget:self action:@selector(createOrShowUnifiedPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:unifiedButton];
        });
    }
}

// --- 统一的 presentViewController Hook (处理所有后台抓取逻辑) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // --- 逻辑分支1: 正在进行【课传详情】提取 (来自原脚本1) ---
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            LogMessage(@"捕获到弹窗: %@", vcClassName);
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
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
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                LogMessage(@"成功提取课传内容 (当前共 %lu 条)", (unsigned long)g_capturedKeChuanDetailArray.count);
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    const double kDelayInSeconds = 0.2; 
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        // 注意：这里不再直接调用自身，而是由外部的完成回调驱动
                        // [self _processKeChuanQueueWithCompletion:...]; 
                        // The flow is now controlled by the calling function.
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    
    // --- 逻辑分支2: 正在进行【高级技法】的课盘提取 (来自原脚本2) ---
    if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        viewControllerToPresent.view.alpha = 0.0f; flag = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0) {
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                if (labels.count > 0) { [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; } }
            }
            NSMutableArray *textParts = [NSMutableArray array];
            if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], viewControllerToPresent.view, stackViews); [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                for (UIStackView *stackView in stackViews) {
                    NSArray *arrangedSubviews = stackView.arrangedSubviews;
                    if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                        UILabel *titleLabel = arrangedSubviews[0]; NSString *rawTitle = titleLabel.text ?: @""; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                        NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSMutableArray *descParts = [NSMutableArray array]; if (arrangedSubviews.count > 1) { for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } } }
                        NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                        [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
                    }
                }
                NSString *content = [textParts componentsJoinedByString:@"\n"];
                if ([title containsString:@"方法"]) g_extractedData[@"方法"] = content; else if ([title containsString:@"格局"]) g_extractedData[@"格局"] = content; else g_extractedData[@"毕法"] = content;
                LogMessage(@"捕获到: %@", title);
            } else if ([vcClassName containsString:@"七政"]) {
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                LogMessage(@"捕获到: 七政四余");
            } else { LogMessage(@"[课盘提取] 抓取到未知弹窗 [%@]，内容被忽略。", title); }
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion); return;
    }

    // --- 逻辑分支3: 正在进行【高级技法】的年命提取 (来自原脚本2) ---
    if (g_isExtractingNianming && g_currentItemToExtract) {
        __weak typeof(self) weakSelf = self;
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent; UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = viewControllerToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            NSString *compactText = [[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [g_capturedZhaiYaoArray addObject:compactText];
            LogMessage(@"捕获到: 年命摘要");
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil]; return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                    UIView *contentView = viewControllerToPresent.view;
                    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView"); NSMutableArray *tableViews = [NSMutableArray array]; if (tableViewClass) { FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews); }
                    UITableView *theTableView = tableViews.firstObject;
                    if (theTableView && [theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && theTableView.dataSource) {
                        id<UITableViewDelegate> delegate = theTableView.delegate; id<UITableViewDataSource> dataSource = theTableView.dataSource;
                        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:theTableView] : 1;
                        for (NSInteger section = 0; section < sections; section++) {
                            NSInteger rows = [dataSource tableView:theTableView numberOfRowsInSection:section];
                            for (NSInteger row = 0; row < rows; row++) {
                                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                                [delegate tableView:theTableView didSelectRowAtIndexPath:indexPath];
                            }
                        }
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                        NSString *formattedGeju = [strongSelf2 _formatNianmingGejuFromView:contentView];
                        [g_capturedGeJuArray addObject:formattedGeju];
                        LogMessage(@"捕获到: 年命格局");
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion); return;
        }
    }

    // --- 如果以上条件都不满足，则执行原始调用 ---
    %orig(viewControllerToPresent, flag, completion);
}


// =========================================================================
// 4. 新的统一功能实现 (%new methods)
// =========================================================================
%new
// --- UI创建与控制 ---
- (void)createOrShowUnifiedPanel {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 7788991;
    if (g_unifiedControlPanel && g_unifiedControlPanel.superview) {
        [g_unifiedControlPanel removeFromSuperview]; g_unifiedControlPanel = nil; g_unifiedLogTextView = nil;
        return;
    }
    
    // 创建毛玻璃背景
    g_unifiedControlPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 90, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 130)];
    g_unifiedControlPanel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    g_unifiedControlPanel.tag = panelTag;
    g_unifiedControlPanel.layer.cornerRadius = 16;
    g_unifiedControlPanel.clipsToBounds = YES;
    g_unifiedControlPanel.backgroundColor = [UIColor clearColor];

    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_unifiedControlPanel.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [g_unifiedControlPanel addSubview:blurView];

    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, g_unifiedControlPanel.bounds.size.width, 30)];
    titleLabel.text = @"高级提取控制台";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [blurView.contentView addSubview:titleLabel];

    // 按钮
    UIButton *simpleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    simpleButton.frame = CGRectMake(20, 60, (g_unifiedControlPanel.bounds.size.width / 2) - 30, 44);
    [simpleButton setTitle:@"简单提取" forState:UIControlStateNormal];
    [simpleButton addTarget:self action:@selector(startSimpleExtraction_Unified) forControlEvents:UIControlEventTouchUpInside];
    simpleButton.backgroundColor = [UIColor systemGreenColor];
    simpleButton.tag = 101;

    UIButton *complexButton = [UIButton buttonWithType:UIButtonTypeSystem];
    complexButton.frame = CGRectMake(g_unifiedControlPanel.bounds.size.width / 2 + 10, 60, (g_unifiedControlPanel.bounds.size.width / 2) - 30, 44);
    [complexButton setTitle:@"复合提取" forState:UIControlStateNormal];
    [complexButton addTarget:self action:@selector(startComplexExtraction_Unified) forControlEvents:UIControlEventTouchUpInside];
    complexButton.backgroundColor = [UIColor systemBlueColor];
    complexButton.tag = 102;

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(20, g_unifiedControlPanel.bounds.size.height - 65, g_unifiedControlPanel.bounds.size.width - 40, 44);
    [copyButton setTitle:@"复制结果并关闭面板" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyAndClose_Unified) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    copyButton.tag = 103;
    copyButton.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    
    for (UIButton *btn in @[simpleButton, complexButton, copyButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
    }
    
    [blurView.contentView addSubview:simpleButton];
    [blurView.contentView addSubview:complexButton];
    [blurView.contentView addSubview:copyButton];

    // 日志视图
    g_unifiedLogTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 120, g_unifiedControlPanel.bounds.size.width - 40, g_unifiedControlPanel.bounds.size.height - 120 - 65 - 10)];
    g_unifiedLogTextView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    g_unifiedLogTextView.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    g_unifiedLogTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_unifiedLogTextView.editable = NO;
    g_unifiedLogTextView.layer.cornerRadius = 8;
    g_unifiedLogTextView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
    g_unifiedLogTextView.layer.borderWidth = 1.0;
    g_unifiedLogTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    g_unifiedLogTextView.text = @"日志控制台已就绪。\n";
    
    [blurView.contentView addSubview:g_unifiedLogTextView];
    [keyWindow addSubview:g_unifiedControlPanel];
}

- (void)copyAndClose_Unified {
    if (g_lastResultString && g_lastResultString.length > 0) {
        [UIPasteboard generalPasteboard].string = g_lastResultString;
        LogMessage(@"最后一次成功的结果已复制到剪贴板！");
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"复制成功" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alert animated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });

    } else {
        LogMessage(@"剪贴板无内容可复制。");
    }
    
    if (g_unifiedControlPanel) {
        [g_unifiedControlPanel removeFromSuperview];
        g_unifiedControlPanel = nil;
        g_unifiedLogTextView = nil;
    }
}

- (void)setPanelButtonsEnabled:(BOOL)enabled {
    if (!g_unifiedControlPanel) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIButton *simpleButton = [g_unifiedControlPanel viewWithTag:101];
        UIButton *complexButton = [g_unifiedControlPanel viewWithTag:102];
        simpleButton.enabled = enabled;
        complexButton.enabled = enabled;
        simpleButton.alpha = enabled ? 1.0 : 0.5;
        complexButton.alpha = enabled ? 1.0 : 0.5;
    });
}

// --- 简单提取流程 ---
- (void)startSimpleExtraction_Unified {
    [self setPanelButtonsEnabled:NO];
    g_lastResultString = nil; // 清空旧结果
    LogMessage(@"--- 开始 [简单提取] 任务 ---");

    [self _performAdvancedAnalysisExtractionWithCompletion:^(NSString *resultText) {
        LogMessage(@"--- [简单提取] 任务完成 ---");
        g_lastResultString = resultText;
        [UIPasteboard generalPasteboard].string = resultText;

        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"简单提取结果已成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        [self setPanelButtonsEnabled:YES];
    }];
}

// --- 复合提取流程 ---
- (void)startComplexExtraction_Unified {
    [self setPanelButtonsEnabled:NO];
    g_lastResultString = nil; // 清空旧结果
    LogMessage(@"--- 开始 [复合提取] 任务 ---");
    LogMessage(@"阶段 1/2: 正在执行高级技法提取...");

    __weak typeof(self) weakSelf = self;
    // 步骤1: 执行高级技法提取
    [self _performAdvancedAnalysisExtractionWithCompletion:^(NSString *advancedResult) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            LogMessage(@"错误：控制器已被释放，任务中断。");
            [self setPanelButtonsEnabled:YES];
            return;
        }
        
        LogMessage(@"阶段 1/2: 高级技法提取完成。");
        LogMessage(@"阶段 2/2: 正在执行课传详情提取...");
        
        // 步骤2: 执行课传详情提取
        [strongSelf _performDetailedKeChuanExtractionWithCompletion:^(NSString *kechuanResult) {
            LogMessage(@"阶段 2/2: 课传详情提取完成。");
            LogMessage(@"正在合并结果...");

            NSString *finalCombinedText;
            if (kechuanResult && kechuanResult.length > 0) {
                // 寻找插入点
                NSString *qizhengMarker = @"七政四余:";
                NSRange qizhengRange = [advancedResult rangeOfString:qizhengMarker options:NSBackwardsSearch];
                
                if (qizhengRange.location != NSNotFound) {
                    // 找到七政四余，找到其后的第一个换行符
                    NSRange nextNewlineRange = [advancedResult rangeOfString:@"\n" options:0 range:NSMakeRange(qizhengRange.location, advancedResult.length - qizhengRange.location)];
                    if (nextNewlineRange.location != NSNotFound) {
                        // 插入到七政四余内容之后
                        NSMutableString *mutableResult = [advancedResult mutableCopy];
                        NSString *insertionText = [NSString stringWithFormat:@"\n\n====================\n【课传详情】\n====================\n\n%@\n\n", kechuanResult];
                        [mutableResult insertString:insertionText atIndex:nextNewlineRange.location + nextNewlineRange.length];
                        finalCombinedText = mutableResult;
                    } else {
                        // 如果七政四余后面没有换行符，就直接拼在后面
                        finalCombinedText = [advancedResult stringByAppendingFormat:@"\n\n====================\n【课传详情】\n====================\n\n%@", kechuanResult];
                    }
                } else {
                    // 如果没找到七政四余，就附加在末尾
                    finalCombinedText = [advancedResult stringByAppendingFormat:@"\n\n====================\n【课传详情】\n====================\n\n%@", kechuanResult];
                }
            } else {
                // 课传详情提取失败或无内容
                LogMessage(@"警告：课传详情无内容，仅使用高级技法结果。");
                finalCombinedText = advancedResult;
            }

            g_lastResultString = [finalCombinedText stringByAppendingString:CustomFooterText];
            [UIPasteboard generalPasteboard].string = g_lastResultString;

            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"复合提取完成" message:@"所有信息已合并，并成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf presentViewController:successAlert animated:YES completion:nil];
            
            LogMessage(@"--- [复合提取] 任务全部完成 ---");
            [strongSelf setPanelButtonsEnabled:YES];
        }];
    }];
}

// =========================================================================
// 5. 封装后的原脚本核心逻辑
// =========================================================================

// --- 原脚本1: 课传详情提取核心逻辑 (封装版) ---

%new
- (void)_performDetailedKeChuanExtractionWithCompletion:(void (^)(NSString *resultText))completion {
    if (g_isExtractingKeChuanDetail) {
        LogMessage(@"错误：课传详情提取任务已在进行中。");
        if(completion) completion(@"[提取失败: 任务已在进行中]");
        return;
    }
    
    [self _startKeChuanExtractionSetup];
    
    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"课传队列为空，未找到任何可提取项。");
        g_isExtractingKeChuanDetail = NO;
        if(completion) completion(@"");
        return;
    }
    
    LogMessage(@"课传任务队列构建完成，总计 %lu 项。", (unsigned long)g_keChuanWorkQueue.count);
    [self _processKeChuanQueueWithCompletion:completion];
}

%new
- (void)_startKeChuanExtractionSetup {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(@"致命错误: 找不到总容器 '課傳' 的ivar。"); g_isExtractingKeChuanDetail = NO; return; }
    UIView *keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer) { LogMessage(@"致命错误: '課傳' 总容器视图为nil。"); g_isExtractingKeChuanDetail = NO; return; }

    // Part A: 三传提取
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, keChuanContainer, sanChuanResults);
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
                    [g_keChuanWorkQueue addObject:@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"diZhi"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                }
                if (tianjiangLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"tianJiang"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
  
    // Part B: 四课提取
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, keChuanContainer, siKeResults);
    if (siKeResults.count > 0) {
        UIView *siKeContainer = siKeResults.firstObject;
        NSDictionary *keDefinitions[] = {
            @{@"title": @"第一课", @"xiaShen": @"日",    @"shangShen": @"日上", @"tianJiang": @"日上天將"},
            @{@"title": @"第二课", @"xiaShen": @"日上", @"shangShen": @"日陰", @"tianJiang": @"日陰天將"},
            @{@"title": @"第三课", @"xiaShen": @"辰",    @"shangShen": @"辰上", @"tianJiang": @"辰上天將"},
            @{@"title": @"第四课", @"xiaShen": @"辰上", @"shangShen": @"辰陰", @"tianJiang": @"辰陰天將"}
        };
        void (^addTaskBlock)(const char*, NSString*, NSString*) = ^(const char* ivarName, NSString* fullTitle, NSString* taskType) {
            if (!ivarName) return;
            Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarName);
            if (ivar) {
                UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar);
                if (label && [label isKindOfClass:[UILabel class]] && label.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:@{@"gesture": label.gestureRecognizers.firstObject, @"contextView": siKeContainer, @"taskType": taskType}];
                    NSString *finalTitle = [NSString stringWithFormat:@"%@ (%@)", fullTitle, label.text];
                    [g_keChuanTitleQueue addObject:finalTitle];
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
}

%new
- (void)_processKeChuanQueueWithCompletion:(void (^)(NSString *resultText))completion {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"课传详情全部任务处理完毕！");
            // 格式化最终结果
            NSMutableString *resultStr = [NSMutableString string];
            if (g_capturedKeChuanDetailArray.count == g_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
                    NSString *title = g_keChuanTitleQueue[i];
                    NSString *detail = g_capturedKeChuanDetailArray[i];
                    [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
                }
            } else {
                 [resultStr appendString:@"[提取失败: 标题与内容数量不匹配]"];
                 LogMessage(@"错误: 标题(%lu)与内容(%lu)数量不匹配。", (unsigned long)g_keChuanTitleQueue.count, (unsigned long)g_capturedKeChuanDetailArray.count);
            }
            g_isExtractingKeChuanDetail = NO;
            if (completion) {
                completion([resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
            }
        }
        return;
    }
  
    NSDictionary *task = g_keChuanWorkQueue.firstObject; 
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    
    UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
    UIView *contextView = task[@"contextView"];
    NSString *taskType = task[@"taskType"];
    
    LogMessage(@"正在处理课传: %@ (类型: %@)", title, taskType);
    
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (keChuanIvar) { object_setIvar(self, keChuanIvar, contextView); }
    
    SEL actionToPerform = nil;
    if ([taskType isEqualToString:@"tianJiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    } else {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    }
    
    __weak typeof(self) weakSelf = self;
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
        // 延迟后继续处理下一个
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf _processKeChuanQueueWithCompletion:completion];
            }
        });
    } else {
        LogMessage(@"错误！方法 %@ 不存在。", NSStringFromSelector(actionToPerform));
        [g_capturedKeChuanDetailArray addObject:@"[提取失败: 方法不存在]"];
        [self _processKeChuanQueueWithCompletion:completion]; // 立即处理下一个
    }
}


// --- 原脚本2: 高级技法提取核心逻辑 (封装版) ---

%new
- (void)_performAdvancedAnalysisExtractionWithCompletion:(void (^)(NSString *resultText))completion {
    __weak typeof(self) weakSelf = self;
    [self _extractKePanInfoWithCompletion:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) { if(completion) completion(@""); return; }
        LogMessage(@"高级技法-课盘信息提取完成");
        
        [strongSelf _extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) { if(completion) completion(@""); return; }
            LogMessage(@"高级技法-年命信息提取完成");

            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
            
            NSString *finalCombinedText;
            if (nianmingText && nianmingText.length > 0) {
                finalCombinedText = [NSString stringWithFormat:@"%@\n\n====================\n【年命分析】\n====================\n\n%@", kePanText, nianmingText];
            } else {
                finalCombinedText = kePanText;
            }
            
            if (completion) {
                completion([finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
            }
        }];
    }];
}

%new
- (void)_extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion {
    #define SafeString(str) (str ?: @"")
    g_extractedData = [NSMutableDictionary dictionary];
    LogMessage(@"提取: 时间块...");
    g_extractedData[@"时间块"] = [[self _extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    LogMessage(@"提取: 月将, 空亡, 三宫时, 昼夜, 课体, 九宗门...");
    g_extractedData[@"月将"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self _extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    LogMessage(@"提取: 天地盘...");
    g_extractedData[@"天地盘"] = [self _extractTianDiPanInfo_V18];
    LogMessage(@"提取: 四课...");
    NSMutableString *siKe = [NSMutableString string]; Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){ NSMutableArray *siKeViews=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews); if(siKeViews.count > 0){ UIView *container=siKeViews.firstObject; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels); if(labels.count >= 12){ NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label]; } if (cols.allKeys.count == 4) { NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }]; NSMutableArray *c1=cols[keys[0]],*c2=cols[keys[1]],*c3=cols[keys[2]],*c4=cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel o1, UILabel o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel o1, UILabel o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel o1, UILabel o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel o1, UILabel o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSString *k1s=((UILabel *)c4[0]).text,*k1t=((UILabel *)c4[1]).text,*k1d=((UILabel *)c4[2]).text; NSString *k2s=((UILabel *)c3[0]).text,*k2t=((UILabel *)c3[1]).text,*k2d=((UILabel *)c3[2]).text; NSString *k3s=((UILabel *)c2[0]).text,*k3t=((UILabel *)c2[1]).text,*k3d=((UILabel *)c2[2]).text; NSString *k4s=((UILabel *)c1[0]).text,*k4t=((UILabel *)c1[1]).text,*k4d=((UILabel *)c1[2]).text; siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)]; } } } }
    g_extractedData[@"四课"] = siKe;
    LogMessage(@"提取: 三传...");
    NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.三傳視圖"); // 注意这里我修正了原脚本的一个可能的拼写错误，从 傳視圖 -> 三傳視圖
    if (!sanChuanViewClass) sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); // 兼容旧的类名
    if(sanChuanViewClass){ NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray array]; for(NSUInteger i = 0; i < scViews.count; i++){ UIView *v = scViews[i]; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(labels.count >= 3){ NSString *lq=((UILabel *)labels.firstObject).text, *tj=((UILabel *)labels.lastObject).text, *dz=((UILabel *)[labels objectAtIndex:labels.count-2]).text; NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for(UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count-3)]){ if(l.text.length > 0) [ssParts addObject:l.text]; } } NSString *ss = [ssParts componentsJoinedByString:@" "]; NSMutableString *line = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [line appendFormat:@" (%@)", ss]; } [lines addObject:[NSString stringWithFormat:@"%@ %@", (i < titles.count) ? titles[i] : @"", line]]; } } sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy]; }
    g_extractedData[@"三传"] = sanChuan;
    
    LogMessage(@"提取: 毕法, 格局, 方法, 七政 (后台弹窗)...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa=NSSelectorFromString(@"顯示法訣總覽"), sGeJu=NSSelectorFromString(@"顯示格局總覽"), sQiZheng=NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa=NSSelectorFromString(@"顯示方法總覽");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored "-Warc-performSelector-leaks"") code; _Pragma("clang diagnostic pop")
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *biFa = g_extractedData[@"毕法"]?:@"", *geJu = g_extractedData[@"格局"]?:@"", *fangFa = g_extractedData[@"方法"]?:@"";
            NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"]; for (NSString *t in trash) { biFa=[biFa stringByReplacingOccurrencesOfString:t withString:@""]; geJu=[geJu stringByReplacingOccurrencesOfString:t withString:@""]; fangFa=[fangFa stringByReplacingOccurrencesOfString:t withString:@""]; }
            if(biFa.length>0) biFa=[NSString stringWithFormat:@"%@\n\n", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"%@\n\n", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"%@\n\n", fangFa];
            NSString *qiZheng = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *tianDiPan = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";
            NSString *finalText = [NSString stringWithFormat:@"%@\n\n月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n九宗门: %@\n\n%@%@\n%@\n\n%@%@%@%@", SafeString(g_extractedData[@"时间块"]), SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]), SafeString(g_extractedData[@"九宗门"]), tianDiPan, SafeString(g_extractedData[@"四课"]), SafeString(g_extractedData[@"三传"]), biFa, geJu, fangFa, qiZheng];
            g_extractedData = nil;
            if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        });
    });
}

%new
- (void)_extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion {
    g_isExtractingNianming = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { LogMessage(@"年命提取模块：未找到行年单元，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { LogMessage(@"年命提取模块：行年单元数量为0，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
    LogMessage(@"发现 %lu 个年命单元，开始提取...", (unsigned long)allUnitCells.count);
    NSMutableArray *workQueue = [NSMutableArray array];
    for (NSUInteger i = 0; i < allUnitCells.count; i++) {
        UICollectionViewCell *cell = allUnitCells[i];
        [workQueue addObject:@{@"type": @"年命摘要", @"cell": cell, @"index": @(i)}];
        [workQueue addObject:@{@"type": @"格局方法", @"cell": cell, @"index": @(i)}];
    }
    
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            LogMessage(@"所有年命任务处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            NSUInteger personCount = allUnitCells.count;
            for (NSUInteger i = 0; i < personCount; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[年命格局未提取到]";
                [resultStr appendFormat:@"--- 人员 %lu ---\n", (unsigned long)i+1];
                [resultStr appendString:@"【年命摘要】\n"];
                [resultStr appendString:zhaiYao];
                [resultStr appendString:@"\n\n【格局方法】\n"];
                [resultStr appendString:geJu];
                if (i < personCount - 1) { [resultStr appendString:@"\n\n--------------------\n\n"]; }
            }
            g_isExtractingNianming = NO;
            if (completion) { completion(resultStr); }
            processQueue = nil;
            return;
        }
        NSDictionary *item = workQueue.firstObject;
        [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"];
        UICollectionViewCell *cell = item[@"cell"];
        NSInteger index = [item[@"index"] integerValue];
        LogMessage(@"正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        g_currentItemToExtract = type;
        id delegate = targetCV.delegate;
        NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };
    processQueue();
}

%new
- (NSString *)_extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { LogMessage(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
    NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (NSString *)_extractTianDiPanInfo_V18 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;
        id diGongDict=GetIvarValueSafely(plateView,@"地宮宮名列"), tianShenDict=GetIvarValueSafely(plateView,@"天神宮名列"), tianJiangDict=GetIvarValueSafely(plateView,@"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";
        if(![diGongDict isKindOfClass:[NSDictionary class]] || ![tianShenDict isKindOfClass:[NSDictionary class]] || ![tianJiangDict isKindOfClass:[NSDictionary class]]) return @"天地盘提取失败: 核心数据类型错误";
        NSArray *diGongLayers=[(NSDictionary *)diGongDict allValues], *tianShenLayers=[(NSDictionary *)tianShenDict allValues], *tianJiangLayers=[(NSDictionary *)tianJiangDict allValues];
        if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配";
        NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = ((CALayer *)layer).presentationLayer ?: (CALayer *)layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toView:nil]; CGFloat dx = pos.x - center.x, dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } };
        processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang");
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO; for (NSNumber *angle in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angle floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angle] addObject:info]; foundGroup=YES; break; } }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count != 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }]; }
        if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整";
        NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }];
        NSMutableString *result = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return result;
    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
}

%new
- (NSString *)_formatNianmingGejuFromView:(UIView *)contentView {
    Class cellClass = NSClassFromString(@"六壬大占.格局單元"); if (!cellClass) return @"";
    NSMutableArray *cells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, contentView, cells);
    [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
    NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array];
    for (UIView *cell in cells) {
        NSMutableArray *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
        if (labelsInCell.count > 0) {
            UILabel *titleLabel = labelsInCell[0];
            NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            NSMutableString *contentString = [NSMutableString string];
            if (labelsInCell.count > 1) {
                for (NSUInteger i = 1; i < labelsInCell.count; i++) {
                    UILabel *contentLabel = labelsInCell[i];
                    [contentString appendString:contentLabel.text ?: @""];
                }
            }
            NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content];
            if (![formattedPairs containsObject:pair]) {
                [formattedPairs addObject:pair];
            }
        }
    }
    return [formattedPairs componentsJoinedByString:@"\n"];
}


%end
