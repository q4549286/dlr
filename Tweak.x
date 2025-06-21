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
// Section 3: 【新功能】一键复制到 AI (按钮位置修正 + 全新提取模板)
// =========================================================================

static const char *AllLabelsOnViewKey = "AllLabelsOnViewKey";
static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)refreshAndSortLabelsForAiCopy;
- (void)findAllLabelsInView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (void)copyAiButtonTapped;
@end

%hook UIViewController

// 【已修正】按钮将被添加到 Window 上，确保在最顶层
- (void)viewDidLoad {
    %orig;

    Class targetClass = objc_getClass("六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 使用 dispatch_after 确保 window 已经准备好
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) {
                return;
            }
            
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            // Y坐标设置为45，放在"定制"按钮附近。您可以微调。
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); 
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            
            [copyButton addTarget:self action:@selector(copyAiButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:copyButton];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    Class targetClass = objc_getClass("六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        [self refreshAndSortLabelsForAiCopy];
    }
}

%new
- (void)refreshAndSortLabelsForAiCopy {
    NSMutableArray *labels = [NSMutableArray array];
    [self findAllLabelsInView:self.view andStoreIn:labels];
    NSArray *sortedLabels = [labels sortedArrayUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        CGFloat y1 = roundf(obj1.frame.origin.y); CGFloat y2 = roundf(obj2.frame.origin.y);
        if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
        CGFloat x1 = roundf(obj1.frame.origin.x); CGFloat x2 = roundf(obj2.frame.origin.x);
        if (x1 < x2) return NSOrderedAscending; if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    objc_setAssociatedObject(self, &AllLabelsOnViewKey, sortedLabels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)findAllLabelsInView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) { [storage addObject:label]; }
    }
    for (UIView *subview in view.subviews) { [self findAllLabelsInView:subview andStoreIn:storage]; }
}

// 【已更新】全新的数据提取模板
%new
- (void)copyAiButtonTapped {
    NSArray *sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    if (!sortedLabels || sortedLabels.count == 0) {
        [self refreshAndSortLabelsForAiCopy];
        sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    }
    if (sortedLabels.count == 0) { NSLog(@"[TweakLog] 未找到任何 UILabel。"); return; }
    
    // ----- 打印调试日志，这是您寻找正确索引的唯一工具！-----
    NSMutableString *debugLog = [NSMutableString stringWithString:@"\n[TweakLog] --- 调试日志 ---\n"];
    for (int i = 0; i < sortedLabels.count; i++) {
        UILabel *label = sortedLabels[i];
        NSString *text = label.text ?: @"(空)";
        [debugLog appendFormat:@"索引 %d: '%@' | 位置: %@\n", i, text, NSStringFromCGRect(label.frame)];
    }
    NSLog(@"%@", debugLog);
    
    // ================== 全新的数据提取区域 ==================
    //
    //  请根据上面打印出的日志，将下面所有的 [99] 替换为正确的索引号！
    //
    
    // 起课方式 (比如 "元首门")
    NSString *methodName = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";
    
    // 四柱第一行 (比如 "乙巳年 壬午月")
    NSString *sichouLine1 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 四柱第二行 (比如 "辛酉日 丁酉时")
    NSString *sichouLine2 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 节令第一行 (比如 "夏时 火王")
    NSString *jielingLine1 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 节令第二行 (比如 "夏至 初候")
    NSString *jielingLine2 = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";
    
    // 年柱神煞 (比如 "太岁"，它在底部表格中，在“己”的旁边)
    NSString *nianZhuSha = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 月柱神煞 (比如 "岁德"，它在底部表格中，在“庚”的旁边)
    NSString *yueZhuSha = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 天盘 (比如 "亥"，在罗盘上)
    NSString *tianPan = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 地盘 (比如 "寅"，在罗盘上)
    NSString *diPan = sortedLabels.count > 99 ? ((UILabel *)sortedLabels[99]).text : @"";

    // 为了防止提取内容为空时显示 "(null)"，我们做一下处理
    #define SafeString(str) (str ?: @"")

    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"%@\n"
        @"%@\n"
        @"%@\n"
        @"%@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        SafeString(methodName),
        SafeString(sichouLine1),
        SafeString(sichouLine2),
        SafeString(jielingLine1),
        SafeString(jielingLine2),
        SafeString(nianZhuSha),
        SafeString(yueZhuSha),
        SafeString(tianPan),
        SafeString(diPan)
    ];
    
    // ----- 结束数据提取 -----
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
