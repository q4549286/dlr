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
// Section 2: 全局水印功能 (已修复编译错误和状态栏问题)
// =========================================================================

// **【核心修复】**
// 将 createWatermarkImage 函数的定义，完整地移动到 %hook UIWindow 的前面！
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

// layoutSubviews Hook - 只负责水印
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }
    
    NSInteger watermarkTag = 998877;
    // ... (这里是你上一轮修改过的 layoutSubviews 的内部代码，保持不变) ...
    // 它会在这里调用 createWatermarkImage，但因为函数定义在前面，所以编译器认识它
    // ...
    // 比如：
    if ([self viewWithTag:watermarkTag]) {
        // ... (更新 frame 的代码) ...
        return;
    }

    // ... (首次创建水印的代码) ...
    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
    // ...
}

// ... (这里是你 setFrame 的 Hook，保持不变) ...
- (void)setFrame:(CGRect)frame {
    // ...
}

%end
// =========================================================================
// Section 7: 终极状态栏显示方案 v2 (双窗口操作)
// =========================================================================
%hook UIWindow

// 我们只 Hook setFrame:，但这次逻辑更强大
- (void)setFrame:(CGRect)frame {
    
    // --- 关键的状态栏高度值 ---
    CGFloat statusBarHeight = 59.0;
    // -------------------------

    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // 不再检查 windowLevel，而是直接检查类名和 frame
    // 无论是 UIWindow 还是 UITextEffectsWindow，只要它想全屏，就把它往下推！
    if (CGRectEqualToRect(frame, screenBounds)) {
        CGRect newFrame = frame;
        newFrame.origin.y = statusBarHeight;
        newFrame.size.height -= statusBarHeight;
        %orig(newFrame);
        return;
    }
    
    // 对于其他非全屏的 frame 设置，直接放行
    %orig;
}

%end


// 我们依然需要这个 Hook 来确保逻辑上的可见性
%hook UIApplication

- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    %orig(NO, animation); 
}

- (BOOL)isStatusBarHidden {
    return NO;
}

%end
