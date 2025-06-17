#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 文字替换功能 (保持不变)
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
// Section 3: 修正后的水印和状态栏处理
// =========================================================================

%hook UIWindow

// 我们只 Hook layoutSubviews 来添加水印，这是最安全的方式。
// 不再需要任何关于 frame 的 Hook。
- (void)layoutSubviews {
    %orig; // 必须先调用原始方法

    // 只在主窗口 (UIWindowLevelNormal) 添加水印，避免添加到键盘、弹窗等系统窗口上。
    if (self.windowLevel == UIWindowLevelNormal) {
        NSInteger watermarkTag = 998877;
        
        // 如果已经存在水印视图，就直接返回，防止重复添加。
        if ([self viewWithTag:watermarkTag]) {
            return;
        }

        // --- 在这里自定义你的水印样式 ---
        NSString *watermarkText = @"Echo定制";
        UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        CGFloat rotationAngle = -30.0;
        CGSize tileSize = CGSizeMake(150, 100);
        // --------------------------------

        // 1. 创建水印瓦片图片
        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);

        // 2. 创建一个和窗口一样大的视图作为水印层
        UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
        watermarkView.tag = watermarkTag;
        watermarkView.userInteractionEnabled = NO; // 非常重要！让水印不影响下层UI的点击事件
        watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        // 3. 将瓦片图片设置为水印层的背景色，实现平铺效果
        watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        
        // 4. 将水印层添加到窗口上，并确保它在最顶层，这样能保证水印总是可见
        [self addSubview:watermarkView];
        [self bringSubviewToFront:watermarkView];
    }
}

%end


// 强制让系统知道要显示状态栏。
// 在移除了错误的 frame 修改后，这个 Hook 会真正生效，作为一道保险。
%hook UIApplication

- (BOOL)isStatusBarHidden {
    return NO;
}

%end
