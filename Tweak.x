// EchoAIO-Combined-Tweak.x
// =========================================================================
//                  EchoAI All-in-One Combined Tweak
//
//  - Merged by AI on 2024-XX-XX
//  - Combines KeChuan Detail Extractor and Advanced Full-Plate Extractor.
//  - Features a unified control panel and global logging system.
// =========================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量、宏与辅助函数
// =========================================================================

// --- UI & State Flags ---
static UIView *g_mainControlPanel = nil;
static UITextView *g_logTextView = nil;

// --- Simple Extraction (KeChuan) State ---
static BOOL g_isExtractingSimple = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

// --- Complex Extraction (Full Plate) State ---
static BOOL g_isExtractingComplex = NO;
static NSMutableDictionary *g_complexExtractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract_Nianming = nil;
static NSMutableArray *g_capturedZhaiYaoArray_Nianming = nil;
static NSMutableArray *g_capturedGeJuArray_Nianming = nil;


// --- Unified Logging Function ---
static void EchoLog(NSString *format, ...) {
    if (!g_logTextView) {
        va_list args;
        va_start(args, format);
        NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);
        NSLog(@"[EchoAI-Tweak-EarlyLog] %@", message);
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
        
        // Prepend new log message
        NSString *oldText = g_logTextView.text ?: @"";
        g_logTextView.text = [NSString stringWithFormat:@"%@\n%@", fullMessage, oldText];
        
        // Also print to Xcode/Console log for debugging
        NSLog(@"[EchoAI-Tweak] %@", message);
    });
}


// --- Helper Functions (Combined & Deduplicated) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }

static NSString * GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }

static UIImage * createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }

static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果仅供参考。\n"
"2. 请结合实际情况进行判断。\n"
"3. [在此处添加您的Prompt或更多说明]";


// =========================================================================
// 2. UI 微调 Hooks (来自原脚本，保持不变)
// =========================================================================
%hook UILabel
(void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
(void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIWindow
(void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self sendSubviewToBack:watermarkView]; }
%end

// =========================================================================
// 3. 主功能区：UIViewController 整合
// =========================================================================
@interface UIViewController (EchoAICombinedAddons)
// --- UI Control ---
- (void)toggleMainPanel_Echo;
- (void)copySimpleResultsAndClose_Echo;
- (void)clearLogAndClose_Echo;

// --- Simple Extraction (KeChuan) ---
- (void)startSimpleExtraction_Echo;
- (void)processSimpleExtractionQueue_Echo;

// --- Complex Extraction (Full Plate) ---
- (void)startComplexExtraction_Echo;
- (void)extractComplexKePanInfo_Echo:(void (^)(NSString *kePanText))completion;
- (void)extractComplexNianmingInfo_Echo:(void (^)(NSString *nianmingText))completion;
- (NSString *)extractTextFromFirstViewOfClassName_Echo:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_Echo;
- (NSString *)formatNianmingGejuFromView_Echo:(UIView *)contentView;
@end


%hook UIViewController

// --- viewDidLoad: Inject the main trigger button ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger mainButtonTag = 888666;
            if ([keyWindow viewWithTag:mainButtonTag]) { [[keyWindow viewWithTag:mainButtonTag] removeFromSuperview]; }
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = mainButtonTag;
            [controlButton setTitle:@"Echo工具箱" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 8;
            controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2);
            controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(toggleMainPanel_Echo) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

// --- presentViewController: The master interceptor for all extraction tasks ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // --- Interceptor for Simple Extraction (KeChuan) ---
    if (g_isExtractingSimple) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            EchoLog(@"捕获弹窗 (简单提取): %@", vcClassName);
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
                EchoLog(@"成功提取内容 (共 %lu 条)", (unsigned long)g_capturedKeChuanDetailArray.count);
                
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    const double kDelayInSeconds = 0.2; 
                    EchoLog(@"弹窗已关闭，延迟 %.1f 秒后处理下一个...", kDelayInSeconds);
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDelayInSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processSimpleExtractionQueue_Echo];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    // --- Interceptor for Complex Extraction (KePan part) ---
    else if (g_isExtractingComplex && g_complexExtractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        viewControllerToPresent.view.alpha = 0.0f; flag = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0) {
                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                if (labels.count > 0) { [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; } }
            }
            EchoLog(@"捕获弹窗 (复合提取-课盘): %@", title);
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
                if ([title containsString:@"方法"]) g_complexExtractedData[@"方法"] = content; else if ([title containsString:@"格局"]) g_complexExtractedData[@"格局"] = content; else g_complexExtractedData[@"毕法"] = content;
            } else if ([vcClassName containsString:@"七政"]) {
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_complexExtractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
            } else { EchoLog(@"[复合提取] 抓取到未知弹窗 [%@]，内容被忽略。", title); }
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion); return;
    }
    // --- Interceptor for Complex Extraction (Nianming part) ---
    else if (g_isExtractingNianming && g_currentItemToExtract_Nianming) {
        __weak typeof(self) weakSelf = self;
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent; UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract_Nianming]) { targetAction = action; break; } }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        EchoLog(@"捕获弹窗 (复合提取-年命): %@", vcClassName);
        if ([g_currentItemToExtract_Nianming isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = viewControllerToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            NSString *compactText = [[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [g_capturedZhaiYaoArray_Nianming addObject:compactText];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil]; return;
        } else if ([g_currentItemToExtract_Nianming isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
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
                        NSString *formattedGeju = [strongSelf2 formatNianmingGejuFromView_Echo:contentView];
                        [g_capturedGeJuArray_Nianming addObject:formattedGeju];
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion); return;
        }
    }

    // --- If no extraction is active, proceed as normal ---
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 4. %new Methods: UI Panel, Simple & Complex Extraction Logic
// =========================================================================

// --- Main Control Panel ---
%new
- (void)toggleMainPanel_Echo {
    UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
    if (g_mainControlPanel && g_mainControlPanel.superview) {
        [UIView animateWithDuration:0.3 animations:^{
            g_mainControlPanel.alpha = 0;
            g_mainControlPanel.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [g_mainControlPanel removeFromSuperview];
            g_mainControlPanel = nil;
            g_logTextView = nil;
        }];
        return;
    }
    
    // Create Panel
    g_mainControlPanel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, keyWindow.bounds.size.width - 20, keyWindow.bounds.size.height - 150)];
    g_mainControlPanel.center = keyWindow.center;
    g_mainControlPanel.backgroundColor = [UIColor colorWithWhite:0.15 alpha:0.95];
    g_mainControlPanel.layer.cornerRadius = 16;
    g_mainControlPanel.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:1.0].CGColor;
    g_mainControlPanel.layer.borderWidth = 1.0;
    g_mainControlPanel.clipsToBounds = YES;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, g_mainControlPanel.bounds.size.width, 30)];
    titleLabel.text = @"Echo 高级工具";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [g_mainControlPanel addSubview:titleLabel];
    
    // Buttons
    CGFloat buttonWidth = (g_mainControlPanel.bounds.size.width - 40) / 2;
    UIButton *simpleButton = [UIButton buttonWithType:UIButtonTypeSystem];
    simpleButton.frame = CGRectMake(15, 60, buttonWidth, 44);
    [simpleButton setTitle:@"简单提取 (课传详情)" forState:UIControlStateNormal];
    [simpleButton addTarget:self action:@selector(startSimpleExtraction_Echo) forControlEvents:UIControlEventTouchUpInside];
    simpleButton.backgroundColor = [UIColor systemGreenColor];
    
    UIButton *complexButton = [UIButton buttonWithType:UIButtonTypeSystem];
    complexButton.frame = CGRectMake(25 + buttonWidth, 60, buttonWidth, 44);
    [complexButton setTitle:@"复合提取 (全盘报告)" forState:UIControlStateNormal];
    [complexButton addTarget:self action:@selector(startComplexExtraction_Echo) forControlEvents:UIControlEventTouchUpInside];
    complexButton.backgroundColor = [UIColor systemRedColor];
    
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(15, 115, buttonWidth, 44);
    [copyButton setTitle:@"复制简单结果" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copySimpleResultsAndClose_Echo) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    
    UIButton *clearButton = [UIButton buttonWithType:UIButtonTypeSystem];
    clearButton.frame = CGRectMake(25 + buttonWidth, 115, buttonWidth, 44);
    [clearButton setTitle:@"清空日志并关闭" forState:UIControlStateNormal];
    [clearButton addTarget:self action:@selector(clearLogAndClose_Echo) forControlEvents:UIControlEventTouchUpInside];
    clearButton.backgroundColor = [UIColor systemBlueColor];

    for (UIButton *btn in @[simpleButton, complexButton, copyButton, clearButton]) {
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        btn.layer.cornerRadius = 8;
        [g_mainControlPanel addSubview:btn];
    }
    
    // Log Text View
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 175, g_mainControlPanel.bounds.size.width - 20, g_mainControlPanel.bounds.size.height - 185)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
    g_logTextView.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.layer.cornerRadius = 8;
    g_logTextView.text = @"日志控制台已就绪。\n";
    [g_mainControlPanel addSubview:g_logTextView];
    
    // Add to window with animation
    g_mainControlPanel.transform = CGAffineTransformMakeScale(1.1, 1.1);
    g_mainControlPanel.alpha = 0;
    [keyWindow addSubview:g_mainControlPanel];
    [UIView animateWithDuration:0.3 animations:^{
        g_mainControlPanel.transform = CGAffineTransformIdentity;
        g_mainControlPanel.alpha = 1.0;
    }];
}

%new
- (void)copySimpleResultsAndClose_Echo {
    if (g_capturedKeChuanDetailArray && g_keChuanTitleQueue && g_capturedKeChuanDetailArray.count > 0 && g_capturedKeChuanDetailArray.count == g_keChuanTitleQueue.count) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = g_capturedKeChuanDetailArray[i];
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        EchoLog(@"简单提取结果已复制到剪贴板！");
    } else {
        EchoLog(@"没有可复制的简单提取结果，或队列数量不匹配。标题: %lu, 内容: %lu", (unsigned long)g_keChuanTitleQueue.count, (unsigned long)g_capturedKeChuanDetailArray.count);
    }
    [self toggleMainPanel_Echo]; // Close panel
}

%new
- (void)clearLogAndClose_Echo {
    if(g_logTextView) {
        g_logTextView.text = @"日志已清空。\n";
    }
    [self toggleMainPanel_Echo]; // Close panel
}

// --- Simple Extraction (KeChuan) Logic ---
%new
- (void)startSimpleExtraction_Echo {
    if (g_isExtractingSimple || g_isExtractingComplex) { EchoLog(@"错误：已有提取任务在进行中。"); return; }
    
    EchoLog(@"===> 开始 [简单提取 - 课传详情] 任务...");
    g_isExtractingSimple = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
  
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { EchoLog(@"致命错误: 找不到总容器 '課傳' 的ivar。"); g_isExtractingSimple = NO; return; }
    UIView *keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer) { EchoLog(@"致命错误: '課傳' 总容器视图为nil。"); g_isExtractingSimple = NO; return; }
    EchoLog(@"成功获取总容器 '課傳': %@", keChuanContainer);

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

    if (g_keChuanWorkQueue.count == 0) { EchoLog(@"队列为空，未找到任何可提取项。简单提取任务结束。"); g_isExtractingSimple = NO; return; }
    EchoLog(@"任务队列构建完成，总计 %lu 项。", (unsigned long)g_keChuanWorkQueue.count);
    [self processSimpleExtractionQueue_Echo];
}

%new
- (void)processSimpleExtractionQueue_Echo {
    if (!g_isExtractingSimple || g_keChuanWorkQueue.count == 0) {
        if (g_isExtractingSimple) {
            EchoLog(@"<=== 所有 [简单提取] 任务处理完毕！结果可点击“复制简单结果”按钮获取。");
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有课传详情已提取。" preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
        g_isExtractingSimple = NO; return;
    }
  
    NSDictionary *task = g_keChuanWorkQueue.firstObject; 
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    
    UIGestureRecognizer *gestureToTrigger = task[@"gesture"];
    UIView *contextView = task[@"contextView"];
    NSString *taskType = task[@"taskType"];
    
    EchoLog(@"正在处理: %@ (类型: %@)", title, taskType);
    
    Ivar keChuanIvar = class_getInstanceVariable([self class], "課傳");
    if (keChuanIvar) {
        object_setIvar(self, keChuanIvar, contextView);
    } else {
        EchoLog(@"警告！找不到内部变量 '課傳'，继续尝试。");
    }
    
    SEL actionToPerform = nil;
    if ([taskType isEqualToString:@"tianJiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    } else {
        // Corrected spelling as per original script's fix
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    }
    
    if ([self respondsToSelector:actionToPerform]) {
        EchoLog(@"调用方法 %@...", NSStringFromSelector(actionToPerform));
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:gestureToTrigger];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误！方法 %@ 不存在。", NSStringFromSelector(actionToPerform));
        [g_capturedKeChuanDetailArray addObject:@"[提取失败: 方法不存在]"];
        [self processSimpleExtractionQueue_Echo]; // Process next item
    }
}


// --- Complex Extraction (Full Plate) Logic ---
%new
- (void)startComplexExtraction_Echo {
    if (g_isExtractingSimple || g_isExtractingComplex) { EchoLog(@"错误：已有提取任务在进行中。"); return; }
    
    EchoLog(@"===> 开始 [复合提取 - 全盘报告] 任务...");
    g_isExtractingComplex = YES;

    UIWindow *keyWindow = self.view.window;
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
    progressView.center = keyWindow.center; progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75]; progressView.layer.cornerRadius = 10; progressView.tag = 556677;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    spinner.color = [UIColor whiteColor]; spinner.center = CGPointMake(100, 45); [spinner startAnimating]; [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 80, 180, 30)];
    progressLabel.textColor = [UIColor whiteColor]; progressLabel.textAlignment = NSTextAlignmentCenter; progressLabel.font = [UIFont systemFontOfSize:14]; progressLabel.adjustsFontSizeToFitWidth = YES;
    progressLabel.text = @"提取课盘信息..."; [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
    
    __weak typeof(self) weakSelf = self;
    [self extractComplexKePanInfo_Echo:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) { [[keyWindow viewWithTag:556677] removeFromSuperview]; g_isExtractingComplex=NO; return; }
        EchoLog(@"--- 课盘信息提取完成 ---");
        progressLabel.text = @"提取年命信息...";
        [strongSelf extractComplexNianmingInfo_Echo:^(NSString *nianmingText) {
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) { [[keyWindow viewWithTag:556677] removeFromSuperview]; g_isExtractingComplex=NO; return; }
            EchoLog(@"--- 年命信息提取完成 ---");
            [[keyWindow viewWithTag:556677] removeFromSuperview];

            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
            
            NSString *finalCombinedText;
            if (nianmingText && nianmingText.length > 0) {
                finalCombinedText = [NSString stringWithFormat:@"%@\n\n====================\n【年命分析】\n====================\n\n%@%@", kePanText, nianmingText, CustomFooterText];
            } else {
                finalCombinedText = [NSString stringWithFormat:@"%@%@", kePanText, CustomFooterText];
            }
            [UIPasteboard generalPasteboard].string = [finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"解析完成" message:@"所有高级技法信息已合并，并成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf2 presentViewController:successAlert animated:YES completion:nil];
            EchoLog(@"<=== [复合提取] 任务全部完成！结果已复制。");
            g_isExtractingComplex = NO;
        }];
    }];
}

%new
- (void)extractComplexKePanInfo_Echo:(void (^)(NSString *kePanText))completion {
    #define SafeString(str) (str ?: @"")
    g_complexExtractedData = [NSMutableDictionary dictionary];
    EchoLog(@"复合提取: 正在获取时间、月将、空亡等基础信息...");
    g_complexExtractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_complexExtractedData[@"月将"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.七政視圖" separator:@" "];
    g_complexExtractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.旬空視圖" separator:@""];
    g_complexExtractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.三宮時視圖" separator:@" "];
    g_complexExtractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_complexExtractedData[@"课体"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.課體視圖" separator:@" "];
    g_complexExtractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName_Echo:@"六壬大占.九宗門視圖" separator:@" "];
    
    EchoLog(@"复合提取: 正在解析天地盘...");
    g_complexExtractedData[@"天地盘"] = [self extractTianDiPanInfo_Echo];

    EchoLog(@"复合提取: 正在解析四课...");
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
                    NSString *k1s=((UILabel*)c4[0]).text,*k1t=((UILabel*)c4[1]).text,*k1d=((UILabel*)c4[2]).text; NSString *k2s=((UILabel*)c3[0]).text,*k2t=((UILabel*)c3[1]).text,*k2d=((UILabel*)c3[2]).text; NSString *k3s=((UILabel*)c2[0]).text,*k3t=((UILabel*)c2[1]).text,*k3d=((UILabel*)c2[2]).text; NSString *k4s=((UILabel*)c1[0]).text,*k4t=((UILabel*)c1[1]).text,*k4d=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_complexExtractedData[@"四课"] = siKe;

    EchoLog(@"复合提取: 正在解析三传...");
    NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.三傳視圖"); // Note: Corrected from 傳視圖 to 三傳視圖 for consistency
    if(!sanChuanViewClass) sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); // Fallback
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray array];
        for(NSUInteger i = 0; i < scViews.count && i < titles.count; i++){
            UIView *v = scViews[i]; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 3){
                NSString *lq=((UILabel*)labels.firstObject).text, *tj=((UILabel*)labels.lastObject).text, *dz=((UILabel*)[labels objectAtIndex:labels.count-2]).text;
                NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for(UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count-3)]){ if(l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ss = [ssParts componentsJoinedByString:@" "]; NSMutableString *line = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [line appendFormat:@" (%@)", ss]; }
                [lines addObject:[NSString stringWithFormat:@"%@ %@", titles[i], line]];
            }
        }
        sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_complexExtractedData[@"三传"] = sanChuan;
    
    EchoLog(@"复合提取: 正在触发毕法、格局、方法、七政等弹窗...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa=NSSelectorFromString(@"顯示法訣總覽"), sGeJu=NSSelectorFromString(@"顯示格局總覽"), sQiZheng=NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa=NSSelectorFromString(@"顯示方法總覽");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"复合提取: 正在整合所有课盘信息...");
            NSString *biFa = g_complexExtractedData[@"毕法"]?:@"", *geJu = g_complexExtractedData[@"格局"]?:@"", *fangFa = g_complexExtractedData[@"方法"]?:@"";
            NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"]; for (NSString *t in trash) { biFa=[biFa stringByReplacingOccurrencesOfString:t withString:@""]; geJu=[geJu stringByReplacingOccurrencesOfString:t withString:@""]; fangFa=[fangFa stringByReplacingOccurrencesOfString:t withString:@""]; }
            if(biFa.length>0) biFa=[NSString stringWithFormat:@"%@\n\n", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"%@\n\n", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"%@\n\n", fangFa];
            NSString *qiZheng = g_complexExtractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_complexExtractedData[@"七政四余"]] : @"";
            NSString *tianDiPan = g_complexExtractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_complexExtractedData[@"天地盘"]] : @"";
            NSString *finalText = [NSString stringWithFormat:@"%@\n\n月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n九宗门: %@\n\n%@%@\n%@\n\n%@%@%@%@", SafeString(g_complexExtractedData[@"时间块"]), SafeString(g_complexExtractedData[@"月将"]), SafeString(g_complexExtractedData[@"空亡"]), SafeString(g_complexExtractedData[@"三宫时"]), SafeString(g_complexExtractedData[@"昼夜"]), SafeString(g_complexExtractedData[@"课体"]), SafeString(g_complexExtractedData[@"九宗门"]), tianDiPan, SafeString(g_complexExtractedData[@"四课"]), SafeString(g_complexExtractedData[@"三传"]), biFa, geJu, fangFa, qiZheng];
            g_complexExtractedData = nil; // Clear data for this part
            if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        });
    });
}

%new
- (void)extractComplexNianmingInfo_Echo:(void (^)(NSString *nianmingText))completion {
    g_isExtractingNianming = YES;
    g_capturedZhaiYaoArray_Nianming = [NSMutableArray array];
    g_capturedGeJuArray_Nianming = [NSMutableArray array];
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { EchoLog(@"年命提取模块：未找到行年单元，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { EchoLog(@"年命提取模块：行年单元数量为0，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
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
            EchoLog(@"所有年命任务处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            NSUInteger personCount = allUnitCells.count;
            for (NSUInteger i = 0; i < personCount; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray_Nianming.count) ? g_capturedZhaiYaoArray_Nianming[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_capturedGeJuArray_Nianming.count) ? g_capturedGeJuArray_Nianming[i] : @"[年命格局未提取到]";
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
        EchoLog(@"正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        g_currentItemToExtract_Nianming = type;
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

// --- Complex Extraction Helpers ---
%new
- (NSString *)formatNianmingGejuFromView_Echo:(UIView *)contentView {
    Class cellClass = NSClassFromString(@"六壬大占.格局單元");
    if (!cellClass) return @"";
    NSMutableArray *cells = [NSMutableArray array];
    FindSubviewsOfClassRecursive(cellClass, contentView, cells);
    [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
    }];
    NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array];
    for (UIView *cell in cells) {
        NSMutableArray *labelsInCell = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
        if (labelsInCell.count > 0) {
            UILabel *titleLabel = labelsInCell[0];
            NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            
            NSMutableString *contentString = [NSMutableString string];
            if (labelsInCell.count > 1) {
                for (NSUInteger i = 1; i < labelsInCell.count; i++) {
                    UILabel *contentLabel = labelsInCell[i];
                    [contentString appendString:contentLabel.text];
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

%new
- (NSString *)extractTextFromFirstViewOfClassName_Echo:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { EchoLog(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
    NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (NSString *)extractTianDiPanInfo_Echo {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;
        NSDictionary *diGongDict=GetIvarValueSafely(plateView,@"地宮宮名列"),*tianShenDict=GetIvarValueSafely(plateView,@"天神宮名列"),*tianJiangDict=GetIvarValueSafely(plateView,@"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";
        NSArray *diGongLayers=[diGongDict allValues],*tianShenLayers=[tianShenDict allValues],*tianJiangLayers=[tianJiangDict allValues];
        if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配";
        NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = [layer presentationLayer] ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; CGFloat dx = pos.x - center.x, dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } };
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

%end
