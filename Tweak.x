#import <UIKit/UIKit.h>

%hook UILabel

// 我们主要 hook setText:，因为 App 很可能用的是这个方法
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // --- 第 1 步：处理特殊文本替换，比如 “我的分类” ---
    // 同时检查简体和繁体，更保险
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        
        NSString *newString = @"";
        if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"]) {
            newString = @"Echo定制";
        } else if ([text isEqualToString:@"通類"]) {
            // 这里我保留了你最初的需求
            newString = @"Echo定制"; 
        }

        // 从 Label 自身获取当前正在使用的字体、颜色和对齐方式
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        // 创建一个属性字典来保存这些样式
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        // 创建并设置段落样式以保留对齐
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

        // 使用新文本和旧样式，创建一个新的富文本字符串
        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];

        // 调用 setAttributedText: 来应用我们的新富文本并直接返回
        [self setAttributedText:newAttributedText];
        return; // 处理完毕，必须 return，防止后面的代码再次处理
    }

    // --- 第 2 步：处理所有其他文本，进行通用的繁体转简体 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    // 调用原始方法，传入转换后的字符串
    %orig(simplifiedText);
}

// 为了代码健壮性，我们也 hook setAttributedText:
// 这样即使 App 调用的是这个方法，我们的逻辑也能覆盖到
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    
    // --- 同样，先处理特殊文本 ---
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        
        NSString *newString = @"";
        if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"]) {
            newString = @"Echo定制";
        } else if ([originalString isEqualToString:@"通類"]) {
            newString = @"Echo定制";
        }

        // 创建一个可修改的富文本副本，这样可以保留所有原始样式
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        // 替换文本内容
        [newAttributedText.mutableString setString:newString];

        %orig(newAttributedText);
        return;
    }
    
    // --- 再处理通用繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    
    %orig(newAttributedText);
}

%end
