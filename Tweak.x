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
// Section 7: 终极状态栏显示方案 v2 (双窗口操作)
// =========================================================================

%hook UIWindow

// 我们只 Hook setFrame:，但这次逻辑更强大，能同时处理两个窗口
- (void)setFrame:(CGRect)frame {
    
    // --- 关键的状态栏高度值 ---
    CGFloat statusBarHeight = 59.0;
    // -------------------------

    CGRect screenBounds = [[UIScreen mainScreen] bounds];

    // **【核心修复】**
    // 不再检查 windowLevel，而是直接检查 frame 是否为全屏。
    // 这样，无论是 level 0 的 UIWindow 还是 level 10 的 UITextEffectsWindow，
    // 只要它想全屏，就会被我们的 Hook 捕捉到并进行修改！
    if (CGRectEqualToRect(frame, screenBounds)) {
        CGRect newFrame = frame;
        newFrame.origin.y = statusBarHeight;
        newFrame.size.height -= statusBarHeight;
        
        // 用我们计算出的新 frame 去调用原始方法
        %orig(newFrame);
        return; // 修改后直接返回
    }
    
    // 对于其他非全屏的 frame 设置，直接放行，不作修改
    %orig;
}

// 保留 layoutSubviews Hook，它负责水印
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    NSInteger watermarkTag = 998877;
    // ... (你之前成功的水印代码放在这里，保持不变) ...
    // 例如:
    UIView *watermarkView = [self viewWithTag:watermarkTag];
    if (!watermarkView) {
        // 创建水印...
    }
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
