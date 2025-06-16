#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

%hook UILabel

// 将帮助方法定义在 %hook 内部，这样它就成为 UILabel 的一部分（在 hook 的上下文中）
// 你可以给它起一个不容易冲突的名字，比如加个前缀
- (NSString *)myTweak_processedTextForOriginalText:(NSString *)originalText {
    if (!originalText || originalText.length == 0) {
        return originalText;
    }

    NSString *textToReturn = originalText;

    if ([originalText isEqualToString:@"通類"]) {
        textToReturn = @"Echo定制";
    } else {
        NSMutableString *simplifiedText = [originalText mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
        textToReturn = [simplifiedText copy];
    }
    return textToReturn;
}

- (void)setText:(NSString *)text {
    NSLog(@"[MyTweak_UILabel] setText: Original = '%@' for label: %@ (isMainThread: %d)", text, self, [NSThread isMainThread]);

    // 调用上面定义的帮助方法
    NSString *processedText = [self myTweak_processedTextForOriginalText:text];

    NSLog(@"[MyTweak_UILabel] setText: Processed = '%@' for label: %@ (isMainThread: %d)", processedText, self, [NSThread isMainThread]);

    %orig(processedText);

    if ([processedText isEqualToString:@"Echo定制"]) {
        self.adjustsFontSizeToFitWidth = YES;
        self.minimumScaleFactor = 0.5; // 你可以调整这个值
        self.numberOfLines = 1;
        NSLog(@"[MyTweak_UILabel] Applied font adjustment for 'Echo定制' to label: %@", self);
    }
}

// 如果需要 hook setAttributedText，也类似处理
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.string.length == 0) {
        %orig;
        return;
    }

    NSLog(@"[MyTweak_UILabel] setAttributedText: Original String = '%@' for label: %@ (isMainThread: %d)", attributedText.string, self, [NSThread isMainThread]);

    NSString *originalString = attributedText.string;
    // 调用帮助方法处理字符串部分
    NSString *processedString = [self myTweak_processedTextForOriginalText:originalString];

    if (![processedString isEqualToString:originalString]) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText replaceCharactersInRange:NSMakeRange(0, newAttributedText.length) withString:processedString];
        
        NSLog(@"[MyTweak_UILabel] setAttributedText: Processed String = '%@' for label: %@", processedString, self);
        %orig(newAttributedText);

        if ([processedString isEqualToString:@"Echo定制"]) {
            self.adjustsFontSizeToFitWidth = YES;
            self.minimumScaleFactor = 0.5;
            self.numberOfLines = 1;
            NSLog(@"[MyTweak_UILabel] Applied font adjustment for 'Echo定制' (Attributed) to label: %@", self);
        }
    } else {
        %orig(attributedText);
    }
}

%end
