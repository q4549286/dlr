#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Combined-V13-Compact] " format), ##VA_ARGS)

// --- 全局状态变量 ---
static NSInteger const CombinedButtonTag = 112244;
static NSInteger const ProgressViewTag = 556677;
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;

// --- 自定义文本块 ---
static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果仅供参考。\n"
"2. 请结合实际情况进行判断。\n"
"3. [在此处添加您的Prompt或更多说明]";

// --- 辅助函数 (保持不变) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { ptrdiff_t offset = ivar_getOffset(ivar); void **ivar_ptr = (void **)((__bridge void *)object + offset); value = (__bridge id)(*ivar_ptr); break; } } } free(ivars); return value; }
static NSString GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }

// =========================================================================
// 2. 界面UI微调 Hooks (UILabel, UIWindow) - 保持不变
// =========================================================================

%hook UILabel
(void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
(void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIWindow
(void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end

// =========================================================================
// 3. 主功能区：UIViewController 整合
// =========================================================================

@interface UIViewController (EchoAICombinedAddons)
(void)performCombinedAnalysis;
(void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion;
(void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
(NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
(NSString *)extractTianDiPanInfo_V18;
(NSString *)formatNianmingGejuFromView:(UIView *)contentView;
@end

%hook UIViewController
(void)viewDidLoad {
%orig;
Class targetClass = NSClassFromString(@"六壬大占.ViewController");
if (targetClass && [self isKindOfClass:targetClass]) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
        if ([keyWindow viewWithTag:CombinedButtonTag]) { [[keyWindow viewWithTag:CombinedButtonTag] removeFromSuperview]; }
        UIButton *combinedButton = [UIButton buttonWithType:UIButtonTypeSystem];
        combinedButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
        combinedButton.tag = CombinedButtonTag;
        [combinedButton setTitle:@"高级技法解析" forState:UIControlStateNormal];
        combinedButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
        combinedButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
        [combinedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        combinedButton.layer.cornerRadius = 8;
        [combinedButton addTarget:self action:@selector(performCombinedAnalysis) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:combinedButton];
    });
}
}

(void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
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
        } else if ([vcClassName containsString:@"七政"]) {
            NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
            for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
            g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
        } else { EchoLog(@"[课盘提取] 抓取到未知弹窗 [%@]，内容被忽略。", title); }
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
    });
    %orig(viewControllerToPresent, flag, completion); return;
}
else if (g_isExtractingNianming && g_currentItemToExtract) {
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
        // 【紧凑化修改】
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
                        for (NSInteger row = 0; row < rows; row++) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                            [delegate tableView:theTableView didSelectRowAtIndexPath:indexPath];
                        }
                    }
                }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                    NSString *formattedGeju = [strongSelf2 formatNianmingGejuFromView:contentView];
                    [g_capturedGeJuArray addObject:formattedGeju];
                    [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                });
            });
        };
        %orig(viewControllerToPresent, flag, newCompletion); return;
    }
}
%orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 4. "高级技法解析" 功能实现
// =========================================================================
// ====================== 【V13 核心修复】 ======================
%new
(NSString *)formatNianmingGejuFromView:(UIView *)contentView {
    // 找到所有可见的 TableViewCell，它们是天然的条目分隔
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
        // FIX: Removed invalid "Generated code" and "Use code with caution." lines
        if (labelsInCell.count > 0) {
            // 第一个label是标题
            UILabel *titleLabel = labelsInCell[0];
            NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            
            // 后续所有label都是内容
            NSMutableString *contentString = [NSMutableString string];
            if (labelsInCell.count > 1) {
                for (NSUInteger i = 1; i < labelsInCell.count; i++) {
                    UILabel *contentLabel = labelsInCell[i];
                    [contentString appendString:contentLabel.text];
                }
            }
            
            // 【紧凑化修改】
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
(void)performCombinedAnalysis {
EchoLog(@"--- 开始执行 [高级技法解析] 联合任务 ---");
UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
progressView.center = keyWindow.center; progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75]; progressView.layer.cornerRadius = 10; progressView.tag = ProgressViewTag;
UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
spinner.color = [UIColor whiteColor]; spinner.center = CGPointMake(100, 45); [spinner startAnimating]; [progressView addSubview:spinner];
UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 80, 180, 30)];
progressLabel.textColor = [UIColor whiteColor]; progressLabel.textAlignment = NSTextAlignmentCenter; progressLabel.font = [UIFont systemFontOfSize:14]; progressLabel.adjustsFontSizeToFitWidth = YES;
progressLabel.text = @"提取课盘信息..."; [progressView addSubview:progressLabel];
[keyWindow addSubview:progressView];
__weak typeof(self) weakSelf = self;
[self extractKePanInfoWithCompletion:^(NSString *kePanText) {
    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) { [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview]; return; }
    EchoLog(@"--- 课盘信息提取完成 ---");
    progressLabel.text = @"提取年命信息...";
    [strongSelf extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
        __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) { [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview]; return; }
        EchoLog(@"--- 年命信息提取完成 ---");
        [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview];
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
        EchoLog(@"--- [高级技法解析] 联合任务全部完成 ---");
    }];
}];
}

%new
(void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion {
#define SafeString(str) (str ?: @"")
g_extractedData = [NSMutableDictionary dictionary];
g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];
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
g_extractedData[@"四课"] = siKe;
NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
if(sanChuanViewClass){
    NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame
