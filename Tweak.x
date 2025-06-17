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
// Section 2 & 3: 全局水印 & 强制显示状态栏 (最终整合方案)
// =========================================================================

// ... (创建水印图片的 C 函数 createWatermarkImage 保持不变，放在这里) ...
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

// 同样 Hook layoutSubviews，这是一个安全且会被反复调用的时机
- (void)layoutSubviews {
    %orig; // 先执行原始方法

    // 【第一步】强制为状态栏腾出空间
    // ------------------------------------
    
    // 只在 App 的主窗口操作
    if (self.windowLevel == UIWindowLevelNormal) {
        
        // 获取状态栏的 frame，这是获取其高度的最可靠方法
        // 注意：需要通过 keyWindow 的 windowScene 来获取
        UIStatusBarManager *statusBarManager = self.windowScene.statusBarManager;
        if (statusBarManager && statusBarManager.statusBarFrame.size.height > 0) {
            
            CGRect statusBarFrame = statusBarManager.statusBarFrame;
            CGFloat statusBarHeight = statusBarFrame.size.height;
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            
            // 计算 App 窗口的新 frame
            CGRect newWindowFrame = CGRectMake(0, statusBarHeight, screenBounds.size.width, screenBounds.size.height - statusBarHeight);

            // 关键：只有当窗口当前的 frame 和我们计算出的新 frame 不一样时，才去设置它
            // 这样可以避免在 layoutSubviews 中无限循环调用
            if (!CGRectEqualToRect(self.frame, newWindowFrame)) {
                self.frame = newWindowFrame;
            }
        }
    }

    // 【第二步】添加我们的水印
    // ------------------------------------
    
    NSInteger watermarkTag = 998877;
    if ([self viewWithTag:watermarkTag]) {
        return;
    }

    // 如果是主窗口，才添加水印
    if (self.windowLevel == UIWindowLevelNormal) {
        NSString *watermarkText = @"Echo定制";
        UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        CGFloat rotationAngle = -30.0;
        CGSize tileSize = CGSizeMake(150, 100);

        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
        
        // 注意：水印视图的 frame 应该是 self.bounds，而不是全屏的 bounds
        // 因为 self (UIWindow) 的 frame 已经被我们修改过了
        UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
        
        watermarkView.tag = watermarkTag;
        watermarkView.userInteractionEnabled = NO;
        watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        
        [self insertSubview:watermarkView atIndex:0];
    }
}

%end
