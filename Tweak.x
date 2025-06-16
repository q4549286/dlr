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

        // --- 核心修改！我们不再使用 self.textColor，而是通过名字创建这个智能颜色 ---
        UIColor *currentColor = [UIColor colorNamed:@"银灰五"];
        
        // 如果因为某些原因（比如App更新后名字变了）找不到这个颜色，我们提供一个备用方案，保证不崩溃
        if (!currentColor) {
            currentColor = self.textColor ?: [UIColor whiteColor];
        }

        // --- 这是我们之前调试好的字体和尺寸 ---
        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 14.0; 
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        // --- 组装属性 ---
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

        // --- 核心修改！同样使用名字来获取智能颜色 ---
        UIColor *currentColor = [UIColor colorNamed:@"银灰五"];
        
        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 14.0;
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];

        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        
        // 创建一个属性字典来覆盖
        NSMutableDictionary *newAttributes = [NSMutableDictionary dictionary];
        if (newFont) newAttributes[NSFontAttributeName] = newFont;
        if (currentColor) newAttributes[NSForegroundColorAttributeName] = currentColor;
        
        // 清除旧属性并应用新属性，以确保字体和颜色被完全替换
        [newAttributedText setAttributes:@{} range:NSMakeRange(0, newAttributedText.length)];
        [newAttributedText addAttributes:newAttributes range:NSMakeRange(0, newAttributedText.length)];
        
        %orig(newAttributedText);
        return;
    }
    
    // --- 其他所有文本，照常进行繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}

%end
