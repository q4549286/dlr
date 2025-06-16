#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h> // 需要包含这个头文件

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *finalTextToSet; // 我们将在这里准备最终要设置的文本

    // 优先处理特定字符串 "通類"
    if ([text isEqualToString:@"通類"]) {
        finalTextToSet = @"我的分类";
    } else {
        // 对于其他所有文本，进行繁转简处理
        NSMutableString *processedText = [text mutableCopy];
        CFStringTransform((__bridge CFMutableStringRef)processedText, NULL, CFSTR("Hant-Hans"), false);

        // 在繁转简之后，如果文本中包含 "通类"，则替换为 "Echo定制"
        // 注意：如果原始文本就是 "通类" (已经是简体)，它也会在这里被替换
        // 如果原始文本是其他繁体词，如 "數據類"，会先变成 "数据类"，这一步不会替换它
        NSRange rangeOfTongLei = [processedText rangeOfString:@"通类"];
        if (rangeOfTongLei.location != NSNotFound) {
            // 只有当原始文本不是 "通類" (因为那个情况我们已经处理并设为"我的分类")
            // 并且繁转简后包含 "通类" 时，才替换为 "Echo定制"
            // (其实上面的 if ([text isEqualToString:@"通類"]) 已经覆盖了，这里主要是处理其他源头产生的 "通类")
            [processedText replaceOccurrencesOfString:@"通类"
                                         withString:@"Echo定制"
                                            options:NSLiteralSearch
                                              range:NSMakeRange(0, [processedText length])];
        }
        finalTextToSet = [processedText copy]; // 转为不可变字符串
    }

    // 最后，用处理好的文本调用原始方法
    %orig(finalTextToSet);
}

%end
