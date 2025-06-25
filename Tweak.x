#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量、宏定义与辅助函数 (已合并)
// =========================================================================

// --- 统一日志 ---
static UITextView *g_logTextView = nil; // 全局日志窗口
static void LogMessage(NSString *format, ...);

// --- S1 (Truth Extractor) 全局变量 ---
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;
static NSString *g_s1_finalResult = nil;
// FIX: Dedicated completion handler for the S1 process to solve the race condition.
static void (^g_s1_completion_handler)(void) = nil;


// --- S2 (Advanced Analysis) 全局变量 ---
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;

// --- 全局UI与状态 ---
static UIView *g_mainControlPanelView = nil;
static BOOL g_isPerformingCompositeExtraction = NO;
static NSString *g_s2_baseTextCache = nil;

// --- 自定义文本块 (来自S2) ---
static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果仅供参考。\n"
"2. 请结合实际情况进行判断。\n"
"3. [在此处添加您的Prompt或更多说明]";


// --- 辅助函数 (已合并) ---
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
        NSLog(@"[EchoAI-Combined] %@", message);
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
// 3. 主功能区：UIViewController 整合
// =========================================================================
@interface UIViewController (EchoAICombinedPowerhouse)
// --- 新增的UI和主控制函数 ---
- (void)createOrShowMainControlPanel;
- (void)executeSimpleExtraction;
- (void)executeCompositeExtraction;
- (void)copyLogAndClose;
- (void)showProgressHUD:(NSString *)text;
- (void)updateProgressHUD:(NSString *)text;
- (void)hideProgressHUD;

// --- 来自 S1 (Truth Extractor) 的函数 ---
- (void)startExtraction_Truth_S1_WithCompletion:(void (^)(void))completion;
- (void)processKeChuanQueue_Truth_S1;

// --- 来自 S2 (Advanced Analysis) 的函数 ---
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion;
- (void)extractKePanInfo_S2_WithCompletion:(void (^)(NSString *kePanText))completion;
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion;
- (NSString *)extractTextFromFirstViewOfClassName_S2:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_S2;
- (NSString *)formatNianmingGejuFromView_S2:(UIView *)contentView;
@end


%hook UIViewController

// --- viewDidLoad (统一注入点) ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger controlButtonTag = 556699; // 新的唯一Tag
            if ([keyWindow viewWithTag:controlButtonTag]) { [[keyWindow viewWithTag:controlButtonTag] removeFromSuperview]; }
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = controlButtonTag;
            [controlButton setTitle:@"Echo定制控制台" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:1.0]; // 更专业的蓝色
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

// --- presentViewController (已合并S1和S2的逻辑) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // S1 的拦截逻辑
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            LogMessage(@"[S1] 捕获到弹窗: %@", vcClassName);
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
                LogMessage(@"[S1] 成功提取内容 (共 %lu 条)", (unsigned long)g_capturedKeChuanDetailArray.count);
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    const double kDelayInSeconds = 0.2;
                    LogMessage(@"[S1] 弹窗已关闭，延迟 %.1f 秒后处理下一个...", kDelayInSeconds);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_Truth_S1];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    // S2 的拦截逻辑
    else if ((g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) || g_isExtractingNianming) {
        // S2 的毕法/格局/七政等提取逻辑
        if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *title = viewControllerToPresent.title ?: @"";
                if (title.length == 0) {
                     NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                     if (labels.count > 0) { [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; } }
                }

                NSMutableArray *textParts = [NSMutableArray array];
                if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                    // (代码与S2原始版本相同)
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
                } else if ([NSStringFromClass([viewControllerToPresent class]) containsString:@"七政"]) {
                    NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                    g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                } else {
                    LogMessage(@"[S2] 抓取到未知弹窗 [%@]，内容被忽略。", title);
                }
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
        // S2 的年命提取逻辑
        else if (g_isExtractingNianming && g_currentItemToExtract) {
            // (代码与S2原始版本相同)
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
                                for (NSInteger row = 0; row < rows; row++) { [delegate tableView:theTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]]; }
                            }
                        }
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                            NSString *formattedGeju = [strongSelf2 formatNianmingGejuFromView_S2:contentView];
                            [g_capturedGeJuArray addObject:formattedGeju];
                            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                        });
                    });
                };
                %orig(viewControllerToPresent, flag, newCompletion); return;
            }
        }
    }
    
    // 如果没有被以上逻辑拦截，则执行原始调用
    %orig(viewControllerToPresent, flag, completion);
}


// =========================================================================
// 4. 新的UI和控制逻辑
// =========================================================================
%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    NSInteger panelTag = 556692;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; return;
    }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:CGRectMake(10, 90, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 130)];
    g_mainControlPanelView.tag = panelTag;
    g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_mainControlPanelView.layer.cornerRadius = 16;
    g_mainControlPanelView.layer.borderColor = [UIColor darkGrayColor].CGColor;
    g_mainControlPanelView.layer.borderWidth = 1.0;
    g_mainControlPanelView.clipsToBounds = YES;

    // --- 标题 ---
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, g_mainControlPanelView.bounds.size.width, 30)];
    titleLabel.text = @"Echo定制版高级功能";
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_mainControlPanelView addSubview:titleLabel];

    // --- 按钮 ---
    UIButton *simpleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    simpleButton.frame = CGRectMake(15, 50, g_mainControlPanelView.bounds.size.width/2 - 22.5, 44);
    [simpleButton setTitle:@"Easy mode" forState:UIControlStateNormal];
    [simpleButton addTarget:self action:@selector(executeSimpleExtraction) forControlEvents:UIControlEventTouchUpInside];
    simpleButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]; // Dodger Blue
    
    UIButton *compositeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    compositeButton.frame = CGRectMake(g_mainControlPanelView.bounds.size.width/2 + 7.5, 50, g_mainControlPanelView.bounds.size.width/2 - 22.5, 44);
    [compositeButton setTitle:@"Power！！！" forState:UIControlStateNormal];
    [compositeButton addTarget:self action:@selector(executeCompositeExtraction) forControlEvents:UIControlEventTouchUpInside];
    compositeButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.13 alpha:1.0]; // Orange

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(15, 104, g_mainControlPanelView.bounds.size.width - 30, 40);
    [copyButton setTitle:@"复制日志并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogAndClose) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.7 blue:0.4 alpha:1.0]; // Green
    
    for (UIButton *btn in @[simpleButton, compositeButton, copyButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        btn.layer.cornerRadius = 8;
        [g_mainControlPanelView addSubview:btn];
    }
    
    // --- 日志窗口 ---
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 158, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 168)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];
    g_logTextView.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]; // Light Green
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.layer.cornerRadius = 8;
    g_logTextView.layer.borderColor = [UIColor darkGrayColor].CGColor;
    g_logTextView.layer.borderWidth = 1.0;
    g_logTextView.text = @"日志控制台已就绪。\n";
    
    [g_mainControlPanelView addSubview:g_logTextView];
    [keyWindow addSubview:g_mainControlPanelView];
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
- (void)executeSimpleExtraction {
    LogMessage(@"--- 开始执行 [Easy mode] ---");
    [self showProgressHUD:@"正在执行Easy mode..."];
    [self performSimpleAnalysis_S2_WithCompletion:^(NSString *resultText) {
        [self hideProgressHUD];
        [UIPasteboard generalPasteboard].string = resultText;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"Easy mode结果已成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        LogMessage(@"--- [Easy mode] 任务全部完成 ---");
    }];
}

%new
- (void)executeCompositeExtraction {
    LogMessage(@"--- 开始执行 [Power！！！] ---");
    g_isPerformingCompositeExtraction = YES;
    
    [self showProgressHUD:@"步骤 1/3: 提取课盘信息..."];
    [self extractKePanInfo_S2_WithCompletion:^(NSString *kePanText) {
        g_s2_baseTextCache = kePanText;
        LogMessage(@"[Power！！！] 课盘信息提取完成。");

        [self updateProgressHUD:@"步骤 2/3: 提取课传详情..."];
        [self startExtraction_Truth_S1_WithCompletion:^{
            LogMessage(@"[Power！！！] 课传详情提取完成。");

            [self updateProgressHUD:@"步骤 3/3: 提取年命信息..."];
            [self extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
                [self hideProgressHUD];
                LogMessage(@"[Power！！！] 年命信息提取完成。");

                NSMutableString *finalResult = [g_s2_baseTextCache mutableCopy];
                
                NSString *s1ResultString = g_s1_finalResult ?: @"";
                if (s1ResultString.length > 0) {
                    NSString *s1Formatted = [NSString stringWithFormat:@"\n\n====================\n【课传详解】\n====================\n\n%@", s1ResultString];
                    NSRange qiZhengRange = [finalResult rangeOfString:@"七政四余:"];
                    if (qiZhengRange.location != NSNotFound) {
                        NSRange nextBlockRange = [finalResult rangeOfString:@"\n\n" options:0 range:NSMakeRange(qiZhengRange.location, finalResult.length - qiZhengRange.location)];
                        if (nextBlockRange.location != NSNotFound) {
                            [finalResult insertString:s1Formatted atIndex:nextBlockRange.location];
                        } else {
                            [finalResult appendString:s1Formatted];
                        }
                    } else {
                        [finalResult appendString:s1Formatted];
                    }
                }
                
                if (nianmingText && nianmingText.length > 0) {
                    NSString *formattedNianming = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
                    formattedNianming = [formattedNianming stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
                    [finalResult appendFormat:@"\n\n====================\n【年命分析】\n====================\n\n%@", formattedNianming];
                }

                [finalResult appendString:CustomFooterText];
                
                [UIPasteboard generalPasteboard].string = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Power！！！完成" message:@"所有信息已合并，并成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
                [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
                [self presentViewController:successAlert animated:YES completion:nil];
                LogMessage(@"--- [Power！！！] 任务全部完成 ---");

                g_isPerformingCompositeExtraction = NO;
                g_s2_baseTextCache = nil;
                g_s1_finalResult = nil;
            }];
        }];
    }];
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
// 5. S1 (Truth Extractor) 核心功能实现
// =========================================================================
%new
- (void)startExtraction_Truth_S1_WithCompletion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) { LogMessage(@"[S1] 错误：提取任务已在进行中。"); return; }
    
    LogMessage(@"[S1] 开始提取任务...");
    g_isExtractingKeChuanDetail = YES;
    g_s1_completion_handler = completion; // Store completion block globally.
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(@"[S1] 致命错误: 找不到总容器 '課傳' 的ivar。"); g_isExtractingKeChuanDetail = NO; if(g_s1_completion_handler) g_s1_completion_handler(); g_s1_completion_handler = nil; return; }
    id keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer || ![keChuanContainer isKindOfClass:[UIView class]]) { LogMessage(@"[S1] 致命错误: '課傳' 总容器视图为nil或类型错误。"); g_isExtractingKeChuanDetail = NO; if(g_s1_completion_handler) g_s1_completion_handler(); g_s1_completion_handler = nil; return; }
    LogMessage(@"[S1] 成功获取总容器 '課傳': %@", keChuanContainer);

    // Part A: 三传提取
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
                    [g_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"diZhi"} mutableCopy]];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                }
                if (tianjiangLabel.gestureRecognizers.count > 0) {
                    [g_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"contextView": chuanView, @"taskType": @"tianJiang"} mutableCopy]];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
    
    // Part B: 四课提取
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
                    [g_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"contextView": siKeContainer, @"taskType": taskType} mutableCopy]];
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

    if (g_keChuanWorkQueue.count == 0) {
        LogMessage(@"[S1] 队列为空，未找到任何可提取项。");
        g_isExtractingKeChuanDetail = NO;
        if(g_s1_completion_handler) g_s1_completion_handler();
        g_s1_completion_handler = nil;
        return;
    }
    
    LogMessage(@"[S1] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth_S1];
}

%new
- (void)processKeChuanQueue_Truth_S1 {
    if (!g_isExtractingKeChuanDetail || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingKeChuanDetail) {
            LogMessage(@"[S1] 全部任务处理完毕！");
            
            NSMutableString *resultStr = [NSMutableString string];
            if (g_capturedKeChuanDetailArray && g_keChuanTitleQueue && g_capturedKeChuanDetailArray.count == g_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
                    NSString *title = g_keChuanTitleQueue[i];
                    NSString *detail = g_capturedKeChuanDetailArray[i];
                    [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
                }
                 g_s1_finalResult = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            } else {
                 g_s1_finalResult = @"[S1 提取失败: 标题和内容数量不匹配]";
            }
        }
        g_isExtractingKeChuanDetail = NO;
        
        // FIX: Call and clear the global completion handler here, ensuring S1 is truly finished.
        if (g_s1_completion_handler) {
            g_s1_completion_handler();
            g_s1_completion_handler = nil;
        }
        return;
    }
    
    NSMutableDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
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
        [g_capturedKeChuanDetailArray addObject:@"[提取失败: 方法不存在]"];
        [self processKeChuanQueue_Truth_S1];
    }
}


// =========================================================================
// 6. S2 (Advanced Analysis) 核心功能实现
// =========================================================================
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

%new
- (void)performSimpleAnalysis_S2_WithCompletion:(void (^)(NSString *resultText))completion {
    __weak typeof(self) weakSelf = self;
    [self extractKePanInfo_S2_WithCompletion:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        LogMessage(@"[S2] 课盘信息提取完成。");
        [self updateProgressHUD:@"正在提取年命信息..."];
        [strongSelf extractNianmingInfo_S2_WithCompletion:^(NSString *nianmingText) {
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            LogMessage(@"[S2] 年命信息提取完成。");
            
            NSString *formattedNianming = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
            formattedNianming = [formattedNianming stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];

            NSString *finalCombinedText;
            if (nianmingText && nianmingText.length > 0) {
                finalCombinedText = [NSString stringWithFormat:@"%@\n\n====================\n【年命分析】\n====================\n\n%@%@", kePanText, formattedNianming, CustomFooterText];
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
    g_extractedData = [NSMutableDictionary dictionary];
    LogMessage(@"[S2-KePan] 提取时间、月将、空亡等基础信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName_S2:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName_S2:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_S2];
    
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
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_extractedData[@"四课"] = siKe;

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
    g_extractedData[@"三传"] = sanChuan;
    
    LogMessage(@"[S2-KePan] 提取毕法、格局、七政等弹窗信息...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa=NSSelectorFromString(@"顯示法訣總覽"), sGeJu=NSSelectorFromString(@"顯示格局總覽"), sQiZheng=NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa=NSSelectorFromString(@"顯示方法總覽");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
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
- (void)extractNianmingInfo_S2_WithCompletion:(void (^)(NSString *nianmingText))completion {
    g_isExtractingNianming = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { LogMessage(@"[S2-Nianming] 未找到行年单元，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { LogMessage(@"[S2-Nianming] 行年单元数量为0，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
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
        NSDictionary *item = workQueue.firstObject; [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"]; UICollectionViewCell *cell = item[@"cell"]; NSInteger index = [item[@"index"] integerValue];
        LogMessage(@"[S2-Nianming] 正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        g_currentItemToExtract = type;
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
            NSString *diPanText = @"?";
            NSString *tianPanText = @"?";
            NSString *tianJiangText = @"?";
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
        
        NSMutableString *result = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return result;
    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
}

%end
