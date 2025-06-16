#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>

%hook UILabel

// 使用 %new 来声明和定义一个我们添加到 UILabel 上的新方法
// 注意 %new 后面直接跟方法签名和实现体
%new
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

// 现在我们 hook setText:
- (void)setText:(NSString *)text {
    NSLog(@"[MyTweak_UILabel] setText: Original = '%@' for label: %@ (isMainThread: %d)", text, self, [NSThread isMainThread]);

    // 调用上面用 %new 定义的新方法
    NSString *processedText = [self myTweak_processedTextForOriginalText:text]; // 现在编译器应该能找到它了

    NSLog(@"[MyTweak_UILabel] setText: Processed = '%@' for label: %@ (isMainThread: %d)", processedText, self, [NSThread isMainThread]);

    %orig(processedText);

    if ([processedText isEqualToString:@"Echo定制"]) {
        self.adjustsFontSizeToFitWidth = YES;
        self.minimumScaleFactor = 0.5; // 你可以调整这个值
        self.numberOfLines = 1;
        NSLog(@"[MyTweak_UILabel] Applied font adjustment for 'Echo定制' to label: %@", self);
    }
}

// Hook setAttributedText:
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText || attributedText.string.length == 0) {
        %orig;
        return;
    }

    NSLog(@"[MyTweak_UILabel] setAttributedText: Original String = '%@' for label: %@ (isMainThread: %d)", attributedText.string, self, [NSThread isMainThread]);

    NSString *originalString = attributedText.string;
    // 调用上面用 %new 定义的新方法
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
