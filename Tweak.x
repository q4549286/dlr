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
        
        // --- 在这里调整字体大小！---
        // 尝试从 14.0 增加到 16.0，可以根据需要改成 15.0, 17.0 等。
        CGFloat fontSizeToUse = 17.0; 
        
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;

        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (newFont) attributes[NSFontAttributeName] = newFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

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
        
        // --- 同样，在这里调整字体大小！确保和上面的一致 ---
        CGFloat fontSizeToUse = 17.0;
        
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        
        NSMutableParagraphStyle *paragraphStyle = [[attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL] mutableCopy];
        if (!paragraphStyle) {
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        }
        paragraphStyle.alignment = NSTextAlignmentCenter;

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
