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
// Section 2: 全局水印功能 (已修复状态栏问题 v2)
// =========================================================================

// ... createWatermarkImage 函数保持不变 ...

%hook UIWindow

// layoutSubviews Hook - 只负责水印
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }
    
    NSInteger watermarkTag = 998877;
    if ([self viewWithTag:watermarkTag]) {
        // 如果水印已存在，我们只需更新它的 frame
        UIView *watermarkView = [self viewWithTag:watermarkTag];
        
        // --- 核心修复在这里 ---
        CGFloat statusBarHeight = 59.0;
        CGRect newFrame = self.bounds;
        newFrame.origin.y = -statusBarHeight; // 向上移动状态栏的高度
        newFrame.size.height += statusBarHeight; // 增加高度以填满顶部
        watermarkView.frame = newFrame;
        // --- 修复结束 ---

        return;
    }

    // --- 下面是首次创建水印的代码 ---
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);

    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
    
    // --- 核心修复也在这里 ---
    CGFloat statusBarHeight = 59.0;
    CGRect initialFrame = self.bounds;
    initialFrame.origin.y = -statusBarHeight; // 向上移动
    initialFrame.size.height += statusBarHeight; // 增加高度
    // --- 修复结束 ---

    UIView *watermarkView = [[UIView alloc] initWithFrame:initialFrame];
    watermarkView.tag = watermarkTag;
    watermarkView.userInteractionEnabled = NO;
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
    
    [self insertSubview:watermarkView atIndex:0];
}

// ... 这里是你之前成功的 setFrame 和 UIApplication 的 Hook ...
// 保持它们不变，因为它们是让状态栏出现的必要条件！

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
