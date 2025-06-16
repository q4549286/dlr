#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText:
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // 同时检查"通類"和我们之前修改过的"我的分类"
    if ([text isEqualToString:@"通類"] || [text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"]) {
        
        NSString *newString = @"Echo定制";

        // --- 核心！使用从Flex找到的精确字体名称 ---
        NSString *fontNameToUse = @".SFUI-Heavy";
        // --- 这是我们之前调试好的、能放得下文本的尺寸 ---
        CGFloat fontSizeToUse = 14.0; // 如果需要微调，可以修改这个值

        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        // 保留原始的颜色和对齐方式
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (newFont) attributes[NSFontAttributeName] = newFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
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

        // --- 核心！同样使用精确的字体名称和尺寸 ---
        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 14.0;
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        // 创建一个可修改的副本，这样可以保留颜色、阴影等所有其他样式
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        // 替换文本
        [newAttributedText.mutableString setString:@"Echo定制"];
        
        // 只更新字体属性，覆盖掉原来的大字体
        if (newFont) {
            [newAttributedText addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, newAttributedText.length)];
        }

        %orig(newAttributedText);
        return;
    }
    
    // --- 其他所有文本，照常进行繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}

%end
