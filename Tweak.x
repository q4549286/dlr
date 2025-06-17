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
// Section 8: 最终决战方案
// =========================================================================

%hook UIWindow

// 我们只 Hook layoutSubviews，用一个方法解决所有问题
- (void)layoutSubviews {
    %orig;

    CGFloat statusBarHeight = 59.0;
    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // 判断当前窗口是不是那个捣乱的 UITextEffectsWindow
    if ([NSStringFromClass([self class]) isEqualToString:@"UITextEffectsWindow"]) {
        
        // --- 对付 UITextEffectsWindow ---
        self.userInteractionEnabled = NO; // 让它不响应触摸，触摸事件可以穿透到下层
        self.backgroundColor = [UIColor clearColor]; // 让它完全透明
        
        // 确保它的 frame 不会盖住状态栏
        CGRect newFrame = screenBounds;
        newFrame.origin.y = statusBarHeight;
        newFrame.size.height -= statusBarHeight;
        
        // 只有当它的 frame 不对时才去修改，避免无限循环
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
            // ... (这里是你完整的 createWatermarkImage 函数的调用和水印视图的创建代码)
            NSString *watermarkText = @"Echo定制";
            UIFont *watermarkFont = [UIFont systemFontOf-Size:16.0];
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

// UIApplication 的 Hook 依然需要，它负责逻辑可见性
%hook UIApplication
// ... (保持 setStatusBarHidden 和 isStatusBarHidden 的 Hook 不变) ...
%end
