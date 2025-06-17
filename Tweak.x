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
// Section 2 & 5 & 7 合并: 所有 UIWindow 相关的 Hook
// =========================================================================

// ... createWatermarkImage 函数的定义在这里 (确保它在 %hook 之前) ...
static UIImage *createWatermarkImage(...) { ... }


%hook UIWindow

// 1. Hook setFrame: 来强制为状态栏腾出物理空间
- (void)setFrame:(CGRect)frame {
    if (self.windowLevel == UIWindowLevelNormal) {
        CGFloat statusBarHeight = 59.0;
        CGRect screenBounds = [[UIScreen mainScreen] bounds];

        if (CGRectEqualToRect(frame, screenBounds)) {
            CGRect newFrame = frame;
            newFrame.origin.y = statusBarHeight;
            newFrame.size.height -= statusBarHeight;
            %orig(newFrame);
            return;
        }
    }
    %orig;
}


// 2. Hook layoutSubviews: 来添加和管理水印
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    // --- 【核心修复1】将所有变量定义移到最前面 ---
    NSInteger watermarkTag = 998877;
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);
    CGFloat statusBarHeight = 59.0;
    // ---------------------------------------------

    UIView *watermarkView = [self viewWithTag:watermarkTag];

    if (watermarkView) {
        // 如果水印已存在，我们只需更新它的 frame
        CGRect newFrame = self.bounds;
        newFrame.origin.y = -statusBarHeight;
        newFrame.size.height += statusBarHeight;
        watermarkView.frame = newFrame;
    } else {
        // 如果水印不存在，就创建它
        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
        
        CGRect initialFrame = self.bounds;
        initialFrame.origin.y = -statusBarHeight;
        initialFrame.size.height += statusBarHeight;

        UIView *newWatermarkView = [[UIView alloc] initWithFrame:initialFrame];
        newWatermarkView.tag = watermarkTag;
        newWatermarkView.userInteractionEnabled = NO;
        newWatermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        newWatermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        
        [self insertSubview:newWatermarkView atIndex:0];
    }
}

%end // UIWindow Hook 结束
