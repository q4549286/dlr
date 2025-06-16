#import <UIKit/UIKit.h>

%hook UILabel

// 主要 hook setText: 方法
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *newString = nil;

    // --- 第 1 步：检查是否是我们想修改的特定文本 ---

    // 案例一: "通类" 或 "我的分类" -> "Echo"
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    // 案例二: "起課" (繁体) 或 "起课" (简体) -> "定制"
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    }

    // --- 如果匹配到了任何一个案例，就执行样式保留并替换 ---
    if (newString) {
        // 从 Label 自身获取当前正在使用的字体、颜色和对齐方式
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        // 创建属性字典以保存样式
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

        // 使用新文本和旧样式，创建新的富文本
        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];

        // 应用新的富文本并直接返回，不再执行后续代码
        [self setAttributedText:newAttributedText];
        return;
    }

    // --- 第 2 步：如果不是特殊文本，就执行通用的繁体转简体 ---
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    %orig(simplifiedText);
}

// 同时 hook setAttributedText: 以增强代码的健壮性
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    NSString *newString = nil;

    // --- 同样，先检查特殊文本 ---
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    }

    if (newString) {
        // 直接在富文本副本上修改字符串内容，保留所有样式
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
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
