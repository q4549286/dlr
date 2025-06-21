#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1: 文字替换与简繁转换 (最终修正版)
// =========================================================================
%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) { %orig(text); return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; }

    if (newString) {
        %orig(newString);
        return;
    }
    
    // 【关键修正】使用正确的繁体->简体转换
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig(attributedText); return; }
    NSString *originalString = attributedText.string;
    NSString *newString = nil;
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; }

    if (newString) {
        NSMutableAttributedString *newAttr = [attributedText mutableCopy];
        [newAttr.mutableString setString:newString];
        %orig(newAttr);
        return;
    }
    
    // 【关键修正】使用正确的繁体->简体转换
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(finalAttributedText);
}
%end


// =========================================================================
// Section 2: 全局水印功能 (原样保留)
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end


// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终成品版)
// =========================================================================
static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_Production;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (UILabel *)findLabelToRightOf:(UILabel *)anchorLabel inArray:(NSArray *)labels;
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_Production) forControlEvents:UIControlEventTouchUpInside];
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

%new
- (void)copyAiButtonTapped_Production {
    #define SafeString(str) (str ?: @"")

    NSMutableArray *allLabels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:self.view andStoreIn:allLabels];

    NSMutableString *fullKeti = [NSMutableString string];
    Class ketiCellClass = NSClassFromString(@"六壬大占.课体单元");
    if (!ketiCellClass) ketiCellClass = NSClassFromString(@"六壬大占.課體單元");
    if (ketiCellClass) {
        NSMutableArray *ketiCells = [NSMutableArray array];
        [self findSubviewsOfClass:ketiCellClass inView:self.view andStoreIn:ketiCells];
        [ketiCells sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
            return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
        }];
        NSMutableArray *ketiTextParts = [NSMutableArray array];
        for (UIView *cell in ketiCells) {
            UIView *content = [cell valueForKey:@"contentView"] ?: cell;
            for(UIView *subview in content.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    NSString *text = ((UILabel *)subview).text;
                    if(text) [ketiTextParts addObject:text];
                    break;
                }
            }
        }
        fullKeti = [[ketiTextParts componentsJoinedByString:@" "] mutableCopy];
    }
    
    NSString *methodName = @"", *timeBlock = @"", *nianZhuShaVal = @"", *yueZhuShaVal = @"", *tianPan = @"", *diPan = @"";
    NSMutableDictionary *labelMap = [NSMutableDictionary dictionary];
    for (UILabel *label in allLabels) {
        if (label.text && label.text.length > 0) {
            NSString *key = [[label.text componentsSeparatedByString:@"\n"] firstObject];
            if (!labelMap[key]) { [labelMap setObject:label forKey:key]; }
        }
    }
    
    CGFloat screenWidth = self.view.bounds.size.width;
    for (UILabel *label in allLabels) {
        CGRect frame = label.frame;
        if (frame.origin.y < 100 && frame.origin.y > 20 && fabs(CGRectGetMidX(frame) - screenWidth / 2) < 50) { methodName = label.text; }
        if (frame.origin.x < 50 && frame.origin.y < 150 && [label.text containsString:@"\n"]) { timeBlock = [label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; }
    }
    
    UILabel *taoSuiLabel = labelMap[@"太岁"] ?: labelMap[@"太歲"];
    if (taoSuiLabel) nianZhuShaVal = [self findLabelToRightOf:taoSuiLabel inArray:allLabels].text;

    UILabel *suiDeLabel = labelMap[@"岁德"] ?: labelMap[@"歲德"];
    if (suiDeLabel) yueZhuShaVal = [self findLabelToRightOf:suiDeLabel inArray:allLabels].text;

    UILabel *tianPanAnchor = labelMap[@"官"];
    if (tianPanAnchor) tianPan = [self findLabelToRightOf:tianPanAnchor inArray:allLabels].text;

    UILabel *diPanAnchor = labelMap[@"财"] ?: labelMap[@"財"];
    if (diPanAnchor) diPan = [self findLabelToRightOf:diPanAnchor inArray:allLabels].text;
    
    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"课体: %@\n"
        @"%@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        SafeString(methodName), SafeString(fullKeti), SafeString(timeBlock),
        SafeString(nianZhuShaVal), SafeString(yueZhuShaVal), SafeString(tianPan), SafeString(diPan)
    ];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
