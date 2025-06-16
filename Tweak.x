#import <UIKit/UIKit.h>

// 声明一个我们可能会用到的私有类，如果它存在的话
@interface UIView (Private)
- (UIViewController *)_viewControllerForAncestor;
@end

%hook UILabel

- (void)setText:(NSString *)text {
    // 先调用原始方法，让 Label 完成它自己的所有初始设置
    %orig;

    // --- 繁转简的逻辑 ---
    // 注意：我们这里操作 self.text，因为 %orig 已经执行过了
    if (!self.text) {
        return;
    }
    NSMutableString *newText = [self.text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    // --- 特殊替换逻辑 ---
    if ([newText isEqualToString:@"通类"]) { // 注意：这里判断的是简体字
        // 1. 设置新的文本
        self.text = @"Echo定制";

        // 2. 关键步骤：让 Label 根据新内容自动调整大小
        [self sizeToFit];

        // 3. 重新居中（这是一个非常重要的技巧）
        // 获取它所在的父视图 (superview)
        UIView *superview = self.superview;
        if (superview) {
            // 将自己的中心点 X 坐标设置为父视图中心点的 X 坐标
            self.center = CGPointMake(superview.bounds.size.width / 2, self.center.y);
        }
    } else {
        // 对于其他不需要特殊处理的文本，直接设置转换后的简体文本
        self.text = newText;
    }
}

%end
