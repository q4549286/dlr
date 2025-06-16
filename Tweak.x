#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    // 先调用原始方法，确保 Label 处于一个有效的状态
    %orig;

    // 安全检查
    if (!self.text) {
        return;
    }

    // 复制一份当前文本用于判断和转换
    NSMutableString *judgingText = [self.text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)judgingText, NULL, CFSTR("Hant-Hans"), false);
    
    // --- 只处理“通类”这一个特定情况 ---
    if ([judgingText isEqualToString:@"通类"]) {

        // --- 构建富文本 ---
        NSString *finalString = @"Echo定制";
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (paragraphStyle) { [attributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName]; }
        if (self.font) { [attributes setObject:self.font forKey:NSFontAttributeName]; }
        if (self.textColor) { [attributes setObject:self.textColor forKey:NSForegroundColorAttributeName]; }

        NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:finalString attributes:attributes];
        
        self.attributedText = attributedString;
        
        // --- 最关键的补充步骤 ---
        // 在设置了新内容后，通知自动布局系统：“我的内在尺寸变了，请重新计算布局！”
        // 这会触发约束系统去重新求解，找到一个能容纳新内容的新尺寸。
        [self invalidateIntrinsicContentSize];

    } else {
        // --- 对于所有其他 UILabel ---
        // 如果文本没变，我们就不再重新设置，避免不必要的刷新
        if (![self.text isEqualToString:judgingText]) {
            self.text = judgingText;
        }
    }
}

%end
