#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 你原有的文字替换功能 (无需任何改动，直接保留)
// =========================================================================
%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *newString = nil;

    if ([text isEqualToString:@"胎元"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo定制 胎元";
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
// Section 2: 全局水印功能 (已修复卡死问题)
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

- (void)layoutSubviews {
    %orig;

    // 【重要修正】只在主程序窗口上添加水印，以防止在键盘等系统窗口上添加导致卡死。
    // 主窗口的 windowLevel 是 UIWindowLevelNormal (值为0.0)。
    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    NSInteger watermarkTag = 998877;
    if ([self viewWithTag:watermarkTag]) {
        return;
    }

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
