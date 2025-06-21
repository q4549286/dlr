#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow) - 这部分没有问题
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { UIFont *currentFont = self.font; UIColor *currentColor = self.textColor; NSTextAlignment alignment = self.textAlignment; NSMutableDictionary *attributes = [NSMutableDictionary dictionary]; if (currentFont) attributes[NSFontAttributeName] = currentFont; if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor; NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init]; paragraphStyle.alignment = alignment; attributes[NSParagraphStyleAttributeName] = paragraphStyle; NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes]; [self setAttributedText:newAttributedText]; return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; [newAttributedText.mutableString setString:newString]; %orig(newAttributedText); return; } NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(newAttributedText); }
%end

static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end


// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终完美解决中文类名问题版)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (UILabel *)findLabelToRightOf:(UILabel *)anchorLabel inArray:(NSArray *)labels;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // 【修正】使用 NSClassFromString 来安全地获取中文类名
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// 辅助方法：递归查找指定类的所有子视图
%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage];
    }
}

// 辅助方法：查找某个UILabel右边最近的UILabel
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

// 【最终完美版】
%new
- (void)copyAiButtonTapped_FinalPerfect {
    #define SafeString(str) (str ?: @"")

    // --- 1. 获取所有 UILabel, 用于提取非结构化信息 ---
    NSMutableArray *allLabels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:self.view andStoreIn:allLabels];

    // --- 2. 提取课体 (精准提取) ---
    NSMutableString *fullKeti = [NSMutableString string];
    NSMutableArray *ketiCells = [NSMutableArray array];
    // 【修正】使用 NSClassFromString 来安全地获取中文类名
    Class ketiCellClass = NSClassFromString(@"六壬大占.课体单元");

    if (ketiCellClass) {
        [self findSubviewsOfClass:ketiCellClass inView:self.view andStoreIn:ketiCells];
        
        // 按Y坐标给这些单元格排序
        [ketiCells sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) {
            return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
        }];

        // 遍历每个单元格，取出里面的文字
        for (UIView *cell in ketiCells) {
            NSMutableArray *labelsInCell = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell andStoreIn:labelsInCell];
            if (labelsInCell.count > 0) {
                [fullKeti appendString:((UILabel *)labelsInCell.firstObject).text];
            }
        }
    }

    // --- 3. 提取其他信息 (使用最可靠的方法) ---
    NSString *methodName = @"";
    NSString *timeBlock = @"";
    NSString *nianZhuSha = @"";
    NSString *yueZhuSha = @"";
    NSString *tianPan = @"";
    NSString *diPan = @"";
    
    // 创建一个文本->标签的映射表，用于地标定位
    NSMutableDictionary *labelMap = [NSMutableDictionary dictionary];
    for (UILabel *label in allLabels) {
        if (label.text && label.text.length > 0) {
            NSString *key = [[label.text componentsSeparatedByString:@"\n"] firstObject];
            if (!labelMap[key]) {
                [labelMap setObject:label forKey:key];
            }
        }
    }

    // 按坐标范围大致定位
    CGFloat screenWidth = self.view.bounds.size.width;
    for (UILabel *label in allLabels) {
        CGRect frame = label.frame;
        if (frame.origin.y < 100 && frame.origin.y > 20 && fabs(CGRectGetMidX(frame) - screenWidth / 2) < 50) {
            methodName = label.text;
        }
        if (frame.origin.x < 50 && frame.origin.y < 150 && [label.text containsString:@"\n"]) {
            timeBlock = [label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        }
    }

    // 按地标提取神煞
    UILabel *taoSuiLabel = labelMap[@"太岁"];
    if (taoSuiLabel) nianZhuSha = [self findLabelToRightOf:taoSuiLabel inArray:allLabels].text;

    UILabel *suiDeLabel = labelMap[@"岁德"];
    if (suiDeLabel) yueZhuSha = [self findLabelToRightOf:suiDeLabel inArray:allLabels].text;

    // 按地标提取天地盘
    UILabel *tianPanAnchor = labelMap[@"官"];
    if (tianPanAnchor) tianPan = [self findLabelToRightOf:tianPanAnchor inArray:allLabels].text;

    UILabel *diPanAnchor = labelMap[@"财"];
    if (diPanAnchor) diPan = [self findLabelToRightOf:diPanAnchor inArray:allLabels].text;
    
    // --- 4. 组合最终文本 ---
    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"课体: %@\n"
        @"%@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        SafeString(methodName),
        SafeString(fullKeti),
        SafeString(timeBlock),
        SafeString(nianZhuSha),
        SafeString(yueZhuSha),
        SafeString(tianPan),
        SafeString(diPan)
    ];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
