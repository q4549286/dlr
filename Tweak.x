#import <UIKit/UIKit.h>


// =========================================================================
// Section 1: UILabel 文字和样式替换
// =========================================================================
%hook UILabel

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
// Section 2, 7, 8 合并: 最终的 UIWindow & UIApplication 解决方案
// =========================================================================

// 【修复】将 createWatermarkImage 函数的定义，完整地移动到 %hook UIWindow 的前面
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

// 我们只 Hook layoutSubviews，用一个方法解决所有问题
- (void)layoutSubviews {
    %orig;

    CGFloat statusBarHeight = 59.0;
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // 判断当前窗口是不是那个捣乱的 UITextEffectsWindow
    if ([NSStringFromClass([self class]) isEqualToString:@"UITextEffectsWindow"]) {
        
        // --- 对付 UITextEffectsWindow ---
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        
        CGRect newFrame = screenBounds;
        newFrame.origin.y = statusBarHeight;
        newFrame.size.height -= statusBarHeight;
        
        if (!CGRectEqualToRect(self.frame, newFrame)) {
            self.frame = newFrame;
        }

    } 
    // 判断当前窗口是不是我们的主窗口
    else if (self.windowLevel == UIWindowLevelNormal) {
        
        // --- 对付主窗口 ---

        // 1. 为状态栏腾出空间
        CGRect newFrame = screenBounds;
        newFrame.origin.y = statusBarHeight;
        newFrame.size.height -= statusBarHeight;
        if (!CGRectEqualToRect(self.frame, newFrame)) {
            self.frame = newFrame;
        }

        // 2. 添加水印 (只在主窗口上加)
        NSInteger watermarkTag = 998877;
        if (![self viewWithTag:watermarkTag]) {
            NSString *watermarkText = @"Echo定制";
            
            // 【修复】修正了 systemFontOf-Size: 的拼写错误
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
            
            [self insertSubview:watermarkView atIndex:0];
        }
    }
}

%end


%hook UIApplication

// 逻辑上强制状态栏可见
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    %orig(NO, animation); 
}

- (BOOL)isStatusBarHidden {
    return NO;
}

%end
