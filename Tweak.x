#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // 1. 创建一个可修改的字符串副本
    NSMutableString *simplifiedText = [text mutableCopy];

    // 2. 使用苹果的 CoreFoundation 框架进行繁转简
    // "Hant" 代表繁体中文 (Han Traditional)
    // "Hans" 代表简体中文 (Han Simplified)
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    // 可选：在自动转换后，进行一些你自己的特殊替换
    // 比如，你可能不只想把“通類”变成“通类”，而是想变成“我的分类”
    [simplifiedText replaceOccurrencesOfString:@"通类" withString:@"我的分类" options:NSLiteralSearch range:NSMakeRange(0, [simplifiedText length])];


    // 3. 调用原始方法，传入转换后的字符串
    %orig(simplifiedText);
}

%end
