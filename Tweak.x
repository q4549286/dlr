#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText:
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    if ([text isEqualToString:@"通類"] || [text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"]) {
        
        NSString *newString = @"Echo定制";

        UIColor *currentColor = [UIColor colorNamed:@"银灰五"];
        if (!currentColor) {
            currentColor = self.textColor ?: [UIColor whiteColor];
        }

        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 14.0; 
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        // --- 核心修改！我们不再复制原始对齐，而是强制居中对齐 ---
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (newFont) attributes[NSFontAttributeName] = newFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle; // 应用居中对齐

        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];

        [self setAttributedText:newAttributedText];
        return;
    }

    // --- 其他所有文本，照常进行繁转简 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

// 同时 hook setAttributedText: 以确保万无一失
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    
    if ([originalString isEqualToString:@"通類"] || [originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"]) {

        UIColor *currentColor = [UIColor colorNamed:@"银灰五"];
        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 17.0;
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        
        // --- 核心修改！同样强制居中对齐 ---
        // 1. 获取原始段落样式（如果有的话），并创建可修改的副本
        NSMutableParagraphStyle *paragraphStyle = [[attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL] mutableCopy];
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        // 2. 强制设为居中
        paragraphStyle.alignment = NSTextAlignmentCenter;

        // 3. 应用所有我们需要的属性
        if (newFont) [newAttributedText addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, newAttributedText.length)];
        if (currentColor) [newAttributedText addAttribute:NSForegroundColorAttributeName value:currentColor range:NSMakeRange(0, newAttributedText.length)];
        [newAttributedText addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, newAttributedText.length)];
        
        %orig(newAttributedText);
        return;
    }
    
    // --- 其他所有文本，照常进行繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}

%end
