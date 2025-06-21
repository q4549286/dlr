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
// Section 3: 【新功能】一键复制到 AI (最终竣工版)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMasterpiece;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromViewWithClassName:(NSString *)className separator:(NSString *)separator;
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalMasterpiece) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

// 提取文本的通用核心方法 (使用繁体类名)
%new
- (NSString *)extractTextFromViewWithClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) return @"";

    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    
    [targetViews sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
        return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
    }];

    NSMutableArray *textParts = [NSMutableArray array];
    for (UIView *view in targetViews) {
        NSMutableArray *labelsInView = [NSMutableArray array];
        [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView];
        if (labelsInView.count > 0) {
            // 假设每个视图里只有一个UILabel是我们想要的
            [textParts addObject:((UILabel *)labelsInView.firstObject).text ?: @""];
        }
    }
    return [textParts componentsJoinedByString:separator];
}

// 【最终竣工版】
%new
- (void)copyAiButtonTapped_FinalMasterpiece {
    #define SafeString(str) (str ?: @"")

    // --- 1. 结构化提取 (使用您确认的繁体类名) ---
    NSString *methodName = [self extractTextFromViewWithClassName:@"六壬大占.九宗門視圖" separator:@" "];
    NSString *timeBlock = [[self extractTextFromViewWithClassName:@"六壬大占.年月日視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *fullKeti = [self extractTextFromViewWithClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *sanChuan = [self extractTextFromViewWithClassName:@"六壬大占.傳視圖" separator:@" "];

    // --- 2. 健壮的地标定位法提取 ---
    NSMutableArray *allLabels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:self.view andStoreIn:allLabels];
    
    NSString *nianZhuShaVal = @"", *yueZhuShaVal = @"", *tianPan = @"", *diPan = @"";
    NSMutableDictionary *labelMap = [NSMutableDictionary dictionary];
    for (UILabel *label in allLabels) {
        if (label.text && label.text.length > 0) {
            NSString *key = [[label.text componentsSeparatedByString:@"\n"] firstObject];
            // 使用简体作为key，因为界面上已经是简体了
            if (!labelMap[key]) { [labelMap setObject:label forKey:key]; }
        }
    }

    // 【强化版地标定位】
    UILabel* (^findRightLabel)(NSString*) = ^UILabel* (NSString *key) {
        UILabel *anchor = labelMap[key];
        if (!anchor) return nil;
        UILabel *foundLabel = nil;
        CGFloat minDistance = CGFLOAT_MAX;
        for (UILabel *label in allLabels) {
            if (label == anchor) continue;
            if (fabs(CGRectGetMidY(label.frame) - CGRectGetMidY(anchor.frame)) < 10 && CGRectGetMinX(label.frame) > CGRectGetMaxX(anchor.frame)) {
                CGFloat distance = CGRectGetMinX(label.frame) - CGRectGetMaxX(anchor.frame);
                if (distance < minDistance) {
                    minDistance = distance;
                    foundLabel = label;
                }
            }
        }
        return foundLabel;
    };
    
    nianZhuShaVal = findRightLabel(@"太岁").text;
    yueZhuShaVal = findRightLabel(@"岁德").text;
    tianPan = findRightLabel(@"官").text;
    diPan = findRightLabel(@"财").text;
    
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
        SafeString(methodName), SafeString(fullKeti), SafeString(sanChuan), SafeString(timeBlock),
        SafeString(nianZhuShaVal), SafeString(yueZhuShaVal), SafeString(tianPan), SafeString(diPan)
    ];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
