#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    %orig;

    if (!self.text) { return; }

    NSMutableString *newText = [self.text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    if ([newText isEqualToString:@"通类"]) {
        self.text = @"Echo定制";
        
        // --- 核心改动 ---
        // 尝试将文本对齐方式设置为居中
        self.textAlignment = NSTextAlignmentCenter; // 在 iOS 6.0 之后，等同于 UITextAlignmentCenter

    } else {
        self.text = newText;
    }
}

%end
