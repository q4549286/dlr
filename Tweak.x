#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText:，因为 App 很可能用的是这个方法
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // --- 第 1 步：处理特殊文本替换，比如 “我的分类” ---
    // 同时检查简体和繁体，更保险
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        
        // 【核心代码】开启字体自动缩放，让文本适应UILabel的宽度
        self.adjustsFontSizeToFitWidth = YES;
        // 设置一个最小缩放比例，防止文本变得太小。0.5代表最多缩小到原字体的一半。
        // 如果觉得缩得太小了，可以改成 0.7；如果还是放不下，可以改成 0.4。
        self.minimumScaleFactor = 0.5;

        // --- 下面的代码负责保留原有样式 ---
        NSString *newString = @"Echo定制";

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
        return; // 处理完毕，必须 return
    }

    // --- 第 2 步：处理所有其他文本，进行通用的繁体转简体 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    %orig(simplifiedText);
}

// 为了代码健壮性，我们也 hook setAttributedText:
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    
    // --- 同样，先处理特殊文本 ---
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        
        // 【核心代码】同样需要在这里开启自动缩放
        self.adjustsFontSizeToFitWidth = YES;
        self.minimumScaleFactor = 0.5;

        // 创建一个可修改的富文本副本，保留所有原始样式
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        // 仅替换文本内容
        [newAttributedText.mutableString setString:@"Echo定制"];

        %orig(newAttributedText);
        return; // 处理完毕，必须 return
    }
    
    // --- 再处理通用繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    
    %orig(newAttributedText);
}

%end
