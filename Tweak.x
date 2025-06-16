#import <UIKit/UIKit.h>

%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    // --- 文本处理部分，和你的版本一样 ---
    NSMutableString *newText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    // --- 我们的特殊处理分支 ---
    if ([newText isEqualToString:@"通类"]) {
        // 将文本替换为最终内容
        newText = [@"我的分类" mutableCopy];

        // --- 关键的布局调整策略 ---
        // 在调用 %orig 之前，修改 self 的属性，让它为接下来的布局做准备

        // 策略 1: 修改文本对齐方式
        // 告诉 Label，无论你的框多宽，请让里面的文字居中显示。
        self.textAlignment = NSTextAlignmentCenter;
        
        // 策略 2: 允许 Label 根据内容调整宽度
        // 这会告诉 Label：“如果你的内容变多了，你可以撑宽自己”。
        // 如果 App 使用 Auto Layout，这通常是必要的。
        [self setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentCompressionResistancePriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];

    }

    // --- 最终调用原始方法 ---
    // 将我们处理好的一切（新的文本内容）交给原始方法去执行
    %orig(newText);
}

%end
