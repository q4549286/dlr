#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText:
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        
        NSString *newString = @"Echo定制";

        // --- 核心修改在这里 ---
        // 我们不再依赖自动缩放，而是直接创建一个新的、更小的字体。
        // 原始大小是 23.98，我们从 14.0 开始尝试。
        // self.font.fontName 可以确保字体类型（比如萍方-中黑体）保持不变。
        UIFont *newFont = [UIFont fontWithName:self.font.fontName size:14.0]; // <--- 如果还是太大，就改小这个数字（比如12.0）；如果太小，就改大（比如16.0）

        // --- 下面的代码负责保留颜色和对齐 ---
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (newFont) attributes[NSFontAttributeName] = newFont; // 使用我们创建的新字体
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];

        [self setAttributedText:newAttributedText];
        return;
    }

    // --- 其他文本，照常进行繁转简 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

// 同样为了健壮性，也修改 setAttributedText:
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {

        // --- 核心修改在这里 ---
        // 从原始富文本中获取字体名称
        NSDictionary *originalAttributes = [attributedText attributesAtIndex:0 effectiveRange:NULL];
        UIFont *originalFont = originalAttributes[NSFontAttributeName];
        NSString *fontName = originalFont.fontName ?: self.font.fontName;

        // 创建新字体
        UIFont *newFont = [UIFont fontWithName:fontName size:14.0]; // <--- 同样，在这里调整大小

        // 创建一个可修改的富文本副本，并设置新字体
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        if (newFont) {
            [newAttributedText addAttribute:NSFontAttributeName value:newFont range:NSMakeRange(0, newAttributedText.length)];
        }

        %orig(newAttributedText);
        return;
    }
    
    // --- 其他文本，照常进行繁转简 ---
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}

%end
