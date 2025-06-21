#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end

// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终布局分析版 - 已修正繁体兼容)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalLayoutAnalysis;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (UILabel *)findLabelToRightOf:(UILabel *)anchorLabel inArray:(NSArray *)labels;
- (NSString *)extractTextFromViewsWithClassName:(NSString *)className separator:(NSString *)separator;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (!targetClass) targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); 
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalLayoutAnalysis) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (UILabel *)findLabelToRightOf:(UILabel *)anchorLabel inArray:(NSArray *)labels {
    if (!anchorLabel) return nil;
    UILabel *foundLabel = nil;
    CGFloat minDistance = CGFLOAT_MAX;
    for (UILabel *label in labels) {
        if (label == anchorLabel) continue;
        if (fabs(CGRectGetMidY(label.frame) - CGRectGetMidY(anchorLabel.frame)) < 10 && CGRectGetMinX(label.frame) > CGRectGetMinX(anchorLabel.frame)) {
            CGFloat distance = CGRectGetMinX(label.frame) - CGRectGetMaxX(anchorLabel.frame);
            if (distance < minDistance) {
                minDistance = distance;
                foundLabel = label;
            }
        }
    }
    return foundLabel;
}

// 【已升级】提取文本的通用核心方法，现在能处理多个同名视图
%new
- (NSString *)extractTextFromViewsWithClassName:(NSString *)className separator:(NSString *)separator {
    // 【关键修正】同时尝试简体和繁体类名
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) {
        NSString *traditionalClassName = [className mutableCopy];
        // 自动进行一些常见的简繁体替换
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"占" withString:@"占"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"视图" withString:@"視圖"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"门" withString:@"門"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"时" withString:@"時"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"传" withString:@"傳"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"课" withString:@"課"];
        traditionalClassName = [traditionalClassName stringByReplacingOccurrencesOfString:@"体" withString:@"體"];
        targetViewClass = NSClassFromString(traditionalClassName);
    }
    
    if (!targetViewClass) return @"";

    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    
    if (targetViews.count == 0) return @"";

    [targetViews sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
        return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
    }];

    NSMutableArray *allTextParts = [NSMutableArray array];
    for (UIView *containerView in targetViews) {
        NSMutableArray *labelsInView = [NSMutableArray array];
        UIView *content = [containerView valueForKey:@"contentView"] ?: containerView;
        [self findSubviewsOfClass:[UILabel class] inView:content andStoreIn:labelsInView];
        
        [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
            if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
            if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
            return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
        }];

        for (UILabel *label in labelsInView) {
            if (label.text && label.text.length > 0) {
                [allTextParts addObject:label.text];
            }
        }
    }
    return [allTextParts componentsJoinedByString:separator];
}

// 【最终布局分析版】
%new
- (void)copyAiButtonTapped_FinalLayoutAnalysis {
    #define SafeString(str) (str ?: @"")

    // --- 1. 结构化提取 ---
    NSString *methodName = [self extractTextFromViewsWithClassName:@"六壬大占.九宗门视图" separator:@" "];
    NSString *timeBlock = [[self extractTextFromViewsWithClassName:@"六壬大占.年月日时视图" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *sanChuan = [self extractTextFromViewsWithClassName:@"六壬大占.传视图" separator:@" "];
    NSString *fullKeti = [self extractTextFromViewsWithClassName:@"六壬大占.课体视图" separator:@" "];

    // --- 2. 地标定位法提取其他信息 ---
    NSMutableArray *allLabels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:self.view andStoreIn:allLabels];
    
    NSString *nianZhuShaVal = @"", *yueZhuShaVal = @"", *tianPan = @"", *diPan = @"";
    NSMutableDictionary *labelMap = [NSMutableDictionary dictionary];
    for (UILabel *label in allLabels) {
        if (label.text && label.text.length > 0) {
            NSString *key = [[label.text componentsSeparatedByString:@"\n"] firstObject];
            if (!labelMap[key]) { [labelMap setObject:label forKey:key]; }
        }
    }

    UILabel *taoSuiLabel = labelMap[@"太岁"] ?: labelMap[@"太歲"];
    if (taoSuiLabel) nianZhuShaVal = [self findLabelToRightOf:taoSuiLabel inArray:allLabels].text;

    UILabel *suiDeLabel = labelMap[@"岁德"] ?: labelMap[@"歲德"];
    if (suiDeLabel) yueZhuShaVal = [self findLabelToRightOf:suiDeLabel inArray:allLabels].text;

    UILabel *tianPanAnchor = labelMap[@"官"];
    if (tianPanAnchor) tianPan = [self findLabelToRightOf:tianPanAnchor inArray:allLabels].text;

    UILabel *diPanAnchor = labelMap[@"财"] ?: labelMap[@"財"];
    if (diPanAnchor) diPan = [self findLabelToRightOf:diPanAnchor inArray:allLabels].text;
    
    // --- 3. 组合最终文本 ---
    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"课体: %@\n"
        @"三传: %@\n"
        @"%@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        SafeString(methodName), SafeString(fullKeti), SafeString(sanChuan),
        SafeString(timeBlock), SafeString(nianZhuShaVal), SafeString(yueZhuShaVal),
        SafeString(tianPan), SafeString(diPan)
    ];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
