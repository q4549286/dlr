#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 文字替换功能 (保持不变)
// =========================================================================
%hook UILabel
// ... (您这部分代码是完美的，此处省略以保持简洁，请直接使用您原来的版本) ...
// 实际使用时，请把您原来的 UILabel Hook 代码完整地放在这里
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *newString = nil;

    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }

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
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    NSString *newString = nil;

    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }

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
// Section 2: 水印功能 C 语言辅助函数 (保持不变)
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

// =========================================================================
// Section 3: 水印功能 Hook (保持不变)
// =========================================================================
%hook UIWindow
- (void)layoutSubviews {
    %orig; 
    if (self.windowLevel == UIWindowLevelNormal) {
        NSInteger watermarkTag = 998877;
        if ([self viewWithTag:watermarkTag]) {
            return;
        }
        NSString *watermarkText = @"Echo定制";
        UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
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
}
%end


// =========================================================================
// Section 4: 【核心修正】强制所有视图控制器显示状态栏
// =========================================================================
%hook UIViewController

// 覆盖这个方法，强制返回 NO，意味着“状态栏不隐藏”
- (BOOL)prefersStatusBarHidden {
    return NO;
}

// 有些复杂的容器控制器（如UINavigationController）会询问子控制器
// 我们也覆盖掉，确保它不会把决定权交给一个想要隐藏状态栏的子控制器
- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil;
}

%end
