#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

%hook UILabel

// 内部文本处理函数
- (NSString *)_myProcessedTextForOriginalText:(NSString *)originalText {
    if (!originalText || originalText.length == 0) {
        return originalText;
    }

    NSString *textToReturn = originalText;

    // 1. "通類" -> "Echo定制"
    if ([originalText isEqualToString:@"通類"]) {
        textToReturn = @"Echo定制";
    } else {
        // 2. 其他文本进行繁转简
        NSMutableString *simplifiedText = [originalText mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
        textToReturn = [simplifiedText copy];
    }
    return textToReturn;
}

- (void)setText:(NSString *)text {
    // 打印原始文本，帮助调试
    NSLog(@"[MyTweak_UILabel] setText: Original = '%@' for label: %@", text, self);

    NSString *processedText = [self _myProcessedTextForOriginalText:text];

    // 打印处理后的文本
    NSLog(@"[MyTweak_UILabel] setText: Processed = '%@' for label: %@", processedText, self);

    %orig(processedText); // 调用原始 setText:

    // --- 专门处理 "Echo定制" 的排版 ---
    if ([processedText isEqualToString:@"Echo定制"]) {
        // self 就是当前的 UILabel 实例
        // 判断一下，确保是我们要修改的那个label，避免误伤。
        // 你可以通过Flex3查看这个label的父视图的类名，或者它自身的tag等特征。
        // 例如，如果它在一个特定的父视图里：
        // if ([self.superview isKindOfClass:NSClassFromString(@"SomeSpecificContainerView")]) {
        // 或者简单粗暴地先不加判断，看看效果
            self.adjustsFontSizeToFitWidth = YES; // 允许字体大小根据宽度调整
            self.minimumScaleFactor = 0.5;      // 字体最小可以缩放到原始大小的50% (你可以调整这个值)
            self.numberOfLines = 1;             // 确保是单行
            // [self setNeedsLayout]; // 有时候需要调用这个来触发重新布局
            // [self.superview layoutIfNeeded]; // 甚至调用父视图的
        // }
        NSLog(@"[MyTweak_UILabel] Applied font adjustment for 'Echo定制' to label: %@", self);
    }
}

// %hook OtherRelevantClassIfLowerLabelsAreNotUILabel
// // ...
// %end

// --- 如果下半部分标签是用 setAttributedText: 设置的，你需要 hook 这个 ---
/*
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.string.length == 0) {
        %orig;
        return;
    }

    NSLog(@"[MyTweak_UILabel] setAttributedText: Original String = '%@' for label: %@", attributedText.string, self);

    NSString *originalString = attributedText.string;
    NSString *processedString;

    // "通類" 的处理（如果它也可能通过富文本设置）
    if ([originalString isEqualToString:@"通類"]) {
        processedString = @"Echo定制";
    } else {
        NSMutableString *simplifiedString = [originalString mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)simplifiedString, NULL, CFSTR("Hant-Hans"), false);
        processedString = [simplifiedString copy];
    }

    if (![processedString isEqualToString:originalString]) {
        // 如果文本改变了，我们需要创建一个新的 NSAttributedString
        // 最简单的方式是只替换字符串，保留大部分原有属性
        // 但如果 "Echo定制" 需要完全不同的属性，则需单独构建
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText replaceCharactersInRange:NSMakeRange(0, newAttributedText.length) withString:processedString];
        
        NSLog(@"[MyTweak_UILabel] setAttributedText: Processed String = '%@' for label: %@", processedString, self);
        %orig(newAttributedText);

        // 如果 "Echo定制" 是通过富文本设置的，并且也需要调整字体
        if ([processedString isEqualToString:@"Echo定制"]) {
            // 这里可能需要更小心，因为 attributedString 的字体设置更复杂
            // 但 adjustsFontSizeToFitWidth 仍然是 UILabel 的属性
            self.adjustsFontSizeToFitWidth = YES;
            self.minimumScaleFactor = 0.5;
            self.numberOfLines = 1;
            NSLog(@"[MyTweak_UILabel] Applied font adjustment for 'Echo定制' (Attributed) to label: %@", self);
        }
    } else {
        // 字符串未改变，直接调用原始方法
        %orig(attributedText);
    }
}
*/

%end
