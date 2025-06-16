#import <UIKit/UIKit.h>

%hook UILabel

// 我们只 hook setAttributedText:，因为 setText: 最终也会调用它。
// 这是所有文本样式设置的最终入口。
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.length == 0) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;

    // --- 精准定位我们要修改的文本 ---
    if ([originalString isEqualToString:@"通類"] || [originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"]) {

        // 1. 获取原厂零件，并创建一份可修改的副本。
        // 这一步保留了所有我们看不见的、复杂的原始属性。
        NSMutableAttributedString *finalString = [attributedText mutableCopy];

        // 2. 只替换文本内容。
        [finalString.mutableString setString:@"Echo定制"];
        
        // 3. 定义我们必须修改的两个参数。
        NSString *fontNameToUse = @".SFUI-Heavy";
        CGFloat fontSizeToUse = 14.0; // 这是我们调试好的尺寸
        UIColor *colorToUse = [UIColor colorNamed:@"银灰五"];

        // 4. 创建新的字体和颜色对象。
        UIFont *newFont = [UIFont fontWithName:fontNameToUse size:fontSizeToUse];
        
        // 5. 【核心】在保留所有其他属性的基础上，强制覆盖字体和颜色属性。
        // 我们需要指定作用范围为整个字符串。
        NSRange fullRange = NSMakeRange(0, [finalString length]);
        
        if (newFont) {
            [finalString addAttribute:NSFontAttributeName value:newFont range:fullRange];
        }
        if (colorToUse) {
            // 如果原来的颜色是动态的，我们的新颜色也必须是动态的才能协调。
            [finalString addAttribute:NSForegroundColorAttributeName value:colorToUse range:fullRange];
        }

        // 6. 将我们精心“改装”过的、包含所有原始微调参数的富文本，交给原始方法去显示。
        %orig(finalString);
        return;
    }
    
    // --- 对于其他所有我们不关心的文本，执行通用繁转简 ---
    // 同样使用“修改”的思路，以最大程度保留样式
    NSMutableAttributedString *simplifiedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    
    %orig(simplifiedText);
}

%end
