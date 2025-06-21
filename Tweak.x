#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1: 文字替换功能 (原样保留)
// =========================================================================
%hook UILabel
// ... 您的UILabel hook代码原封不动地放在这里 ...
- (void)setText:(NSString *)text {
    if (!text) { %orig; return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; }
    if (newString) {
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;
        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];
        [self setAttributedText:newAttributedText];
        return;
    }
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig; return; }
    NSString *originalString = attributedText.string;
    NSString *newString = nil;
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; }
    if (newString) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:newString];
        %orig(newAttributedText);
        return;
    }
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}
%end


// =========================================================================
// Section 2: 全局水印功能 (原样保留)
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2);
    CGContextRotateCTM(context, angle * M_PI / 180);
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor};
    CGSize textSize = [text sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height);
    [text drawInRect:textRect withAttributes:attributes];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

%hook UIWindow
// ... 您的UIWindow hook代码原封不动地放在这里 ...
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel != UIWindowLevelNormal) { return; }
    NSInteger watermarkTag = 998877;
    if ([self viewWithTag:watermarkTag]) { return; }
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);
    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
    UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
    watermarkView.tag = watermarkTag;
    watermarkView.userInteractionEnabled = NO;
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
    [self addSubview:watermarkView];
    [self bringSubviewToFront:watermarkView];
}
%end


// =========================================================================
// Section 3: 【新功能】一键复制到 AI (已修正编译错误)
// =========================================================================

// 定义一个我们自己添加的属性的 key
static const void *AllLabelsOnViewKey = &AllLabelsOnViewKey;

// %hook 目标 ViewController
// 根据您的截图，类名是 "六壬大占.ViewController"
%hook 六壬大占.ViewController

// 在界面加载时，添加我们的按钮
- (void)viewDidLoad {
    %orig; // 在方法内部使用 %orig 是正确的

    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(self.view.frame.size.width - 100, 88, 90, 36); 
    [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
    copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    copyButton.tag = 112233;

    // 【修正】直接使用 %new 添加的方法名
    [copyButton addTarget:self action:@selector(copyAiButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    if (![self.view viewWithTag:copyButton.tag]) {
        [self.view addSubview:copyButton];
    }
}

// 在界面每次显示时，都刷新一下 UILabel 列表
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 【修正】直接调用 %new 添加的方法
    [self refreshAndSortLabelsForAiCopy];
}

// ----- 所有的 %new 方法都必须定义在 %hook 和 %end 之间 -----

%new
- (void)refreshAndSortLabelsForAiCopy {
    NSMutableArray *labels = [NSMutableArray array];
    [self findAllLabelsInView:self.view andStoreIn:labels];

    NSArray *sortedLabels = [labels sortedArrayUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        CGFloat y1 = roundf(obj1.frame.origin.y);
        CGFloat y2 = roundf(obj2.frame.origin.y);
        if (y1 < y2) return NSOrderedAscending;
        if (y1 > y2) return NSOrderedDescending;
        
        CGFloat x1 = roundf(obj1.frame.origin.x);
        CGFloat x2 = roundf(obj2.frame.origin.x);
        if (x1 < x2) return NSOrderedAscending;
        if (x1 > x2) return NSOrderedDescending;
        
        return NSOrderedSame;
    }];

    objc_setAssociatedObject(self, AllLabelsOnViewKey, sortedLabels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)findAllLabelsInView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) {
            [storage addObject:label];
        }
    }
    for (UIView *subview in view.subviews) {
        [self findAllLabelsInView:subview andStoreIn:storage];
    }
}

%new
- (void)copyAiButtonTapped {
    NSArray *sortedLabels = objc_getAssociatedObject(self, AllLabelsOnViewKey);

    if (!sortedLabels || sortedLabels.count == 0) {
        [self refreshAndSortLabelsForAiCopy];
        sortedLabels = objc_getAssociatedObject(self, AllLabelsOnViewKey);
    }
    
    if (sortedLabels.count == 0) {
        NSLog(@"[TweakLog] 未找到任何 UILabel。");
        return;
    }
    
    // ================== 数据提取核心区域 ==================
    NSMutableString *debugLog = [NSMutableString stringWithString:@"\n[TweakLog] --- 调试日志 ---\n"];
    for (int i = 0; i < sortedLabels.count; i++) {
        UILabel *label = sortedLabels[i];
        NSString *text = label.text ?: @"(空)";
        [debugLog appendFormat:@"索引 %d: '%@' | 位置: %@\n", i, text, NSStringFromCGRect(label.frame)];
    }
    NSLog(@"%@", debugLog);
    
    // 【请根据调试日志的结果，修改下面的索引值】
    NSString *methodName     = ((UILabel *)sortedLabels[4]).text;  // 示例: 元首门
    NSString *nianZhuGanZhi  = ((UILabel *)sortedLabels[6]).text;  // 示例: 己巳
    NSString *yueZhuGanZhi  = ((UILabel *)sortedLabels[7]).text;  // 示例: 庚午
    NSString *tianPan        = ((UILabel *)sortedLabels[25]).text; // 示例: 父
    NSString *diPan          = ((UILabel *)sortedLabels[26]).text; // 示例: 辰

    NSString *finalText = [NSString stringWithFormat:
        @"起课方式: %@\n"
        @"年柱: %@\n"
        @"月柱: %@\n"
        @"天盘: %@\n"
        @"地盘: %@\n\n"
        @"#奇门遁甲 #AI分析",
        methodName ?: @"未知",
        nianZhuGanZhi ?: @"未知",
        yueZhuGanZhi ?: @"未知",
        tianPan ?: @"未知",
        diPan ?: @"未知"
    ];
    // =======================================================
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end // 这是 %hook 六壬大占.ViewController 的结束
