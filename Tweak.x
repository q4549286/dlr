#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    // ‼️ 先调用 %orig，让 App 完成它自己的所有设置，包括 attributedText
    %orig;

    // 安全检查，检查 text 和 attributedText
    if (!self.text && !self.attributedText) {
        return;
    }

    // --- 统一进行繁转简 ---
    // 优先处理 attributedText，因为它包含更多格式
    if (self.attributedText) {
        NSMutableAttributedString *newAttrText = [self.attributedText mutableCopy];
        // 对富文本的整个范围进行转换
        CFStringTransform((__bridge CFMutableStringRef)newAttrText.mutableString, NULL, CFSTR("Hant-Hans"), false);
        self.attributedText = newAttrText;
    } else if (self.text) {
        NSMutableString *newText = [self.text mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
        self.text = newText;
    }


    // --- 接下来，只针对特殊情况进行二次修改 ---
    // 检查转换后的文本是否是 "通类"
    if ([self.text isEqualToString:@"通类"]) {
        
        NSString *finalString = @"Echo定制";
        
        // --- 核心改动：缩小字体 ---
        // 获取当前字体，然后创建一个小一号的新字体
        UIFont *originalFont = self.font;
        UIFont *smallerFont = [UIFont fontWithName:originalFont.fontName size:originalFont.pointSize - 4]; // 减4个点，你可以调整这个值
        
        // --- 构建富文本 ---
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (paragraphStyle) { [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName]; }
        if (smallerFont) { [attributes setObject:smallerFont forKey:NSFontAttributeName]; } // 使用新创建的小号字体
        if (self.textColor) { [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName]; }

        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:finalString attributes:attributes];
        
        self.attributedText = attributedString;
        
        // 再次通知布局系统，因为字体大小也影响了内在尺寸
        [self invalidateIntrinsicContentSize];
    }
}

%end

// --- 我们再次请回 UIStackView 的 Hook 来解决排版挤压问题 ---
%hook UIStackView

- (void)layoutSubviews {
    %orig;

    // 遍历 StackView 管理的所有子视图
    for (UIView *subview in self.arrangedSubviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            // 如果是我们定制的 Label
            if ([label.text isEqualToString:@"Echo定制"]) {
                // 设置内容压缩阻力：当空间不足时，这个 Label “拒绝”被压缩
                // 这是防止它被旁边视图挤压的关键！
                [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                break;
            }
        }
    }
}
%end
