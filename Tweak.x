#import <UIKit/UIKit.h>

// --- UIStackView 的 Hook ---
%hook UIStackView

- (void)layoutSubviews {
    // 先让 UIStackView 完成它自己的所有布局计算
    %orig;

    // 遍历 UIStackView 管理的所有子视图 (arrangedSubviews)
    for (UIView *subview in self.arrangedSubviews) {
        // 判断子视图是不是 UILabel
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            // 判断是不是我们修改过的那个 Label
            if ([label.text isEqualToString:@"Echo定制"]) {
                
                // --- 找到了！---
                // 对于 StackView 里的元素，我们不需要去修改 frame 或 center。
                // StackView 会自动处理。
                // 我们只需要确保 Label 内部的文字是居中的。
                
                // 再次强制设置文本对齐为居中
                // 即使之前设置过，StackView 的布局过程也可能重置它
                if (label.textAlignment != NSTextAlignmentCenter) {
                    label.textAlignment = NSTextAlignmentCenter;
                }
                
                // 并且，为了让 StackView 正确计算宽度，
                // 我们需要告诉它，这个 Label 不要被压缩。
                // 我们通过设置 Content Hugging 和 Compression Resistance 来实现。
                // 这是处理 StackView 内部元素大小的关键。
                
                // 设置内容拥抱优先级：让 Label 尽量紧凑地包裹其内容，不要被无故拉伸
                [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                
                // 设置内容压缩阻力：当空间不足时，这个 Label “拒绝”被压缩
                [label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
                
                // 找到并处理完后就跳出循环
                break;
            }
        }
    }
}

%end


// --- UILabel 的 Hook 保持原样，只负责改文字 ---
%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSMutableString *newText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    if ([newText isEqualToString:@"通类"]) {
        [newText replaceOccurrencesOfString:@"通类" withString:@"Echo定制" options:NSLiteralSearch range:NSMakeRange(0, [newText length])];
    }
    
    %orig(newText);
}

%end
