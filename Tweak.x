#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // --- 第一步：常规的繁转简 ---
    NSMutableString *newText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);


    // --- 第二步：判断是否是我们的特殊情况 ---
    if ([newText isEqualToString:@"通类"]) {
        // 是特殊情况，我们将构建一个富文本字符串

        // 1. 设置最终的文本内容
        NSString *finalString = @"Echo定制";

        // 2. 创建一个“段落样式” (Paragraph Style) 对象
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        // 3. 在这个样式对象里，设置文本对齐方式为“居中”
        paragraphStyle.alignment = NSTextAlignmentCenter;
        
        // 4. 获取 Label 当前的字体，保证样式统一
        UIFont *font = self.font;
        // 获取 Label 当前的文本颜色
        UIColor *textColor = self.textColor;

        // 5. 创建一个属性字典，把我们想附加的样式都放进去
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        
        // 添加“段落样式”（包含居中信息）
        if (paragraphStyle) {
            [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
        }
        // 添加“字体信息”
        if (font) {
            [attributes setObject:font forKey:NSFontAttributeName];
        }
        // 添加“文本颜色信息”
        if (textColor) {
            [attributes setObject:textColor forKey:NSForegroundColorAttributeName];
        }

        // 6. 使用最终文本和属性字典，创建一个富文本字符串
        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:finalString attributes:attributes];
        
        // 7. 调用 UILabel 的 setAttributedText: 方法，而不是 setText:
        // 注意：这里我们不能用 %orig，因为原始调用的是 setText:
        // 我们需要直接调用 UILabel 的另一个 setter 方法
        self.attributedText = attributedString;

        // 因为我们已经手动设置了内容，所以这里直接返回，不再执行后续的 %orig
        return;

    } else {
        // --- 对于所有其他情况 ---
        // 走原始的 setText: 流程
        %orig(newText);
    }
}

%end
