#import <UIKit/UIKit.h>
#import <objc/runtime.h> // 引入运行时库，用于添加属性

// 定义一个独一无二的 key，用于关联我们的标记
static void * const kShouldRecenterKey = (void *)&kShouldRecenterKey;

%hook UILabel

// 我们需要一个地方来存放“是否需要重新居中”这个状态
// Objective-C 的 Category 不能直接加属性，但可以用“关联对象”这个黑魔法来模拟
- (void)setShouldRecenter:(BOOL)shouldRecenter {
    objc_setAssociatedObject(self, kShouldRecenterKey, @(shouldRecenter), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldRecenter {
    NSNumber *value = objc_getAssociatedObject(self, kShouldRecenterKey);
    return [value boolValue];
}


// 第一步：在 setText: 中只改文字，并打上标记
- (void)setText:(NSString *)text {
    %orig;

    if (!self.text) {
        return;
    }

    NSMutableString *newText = [self.text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    // 我们只在文本匹配时打标记
    if ([newText isEqualToString:@"通类"]) {
        self.text = @"我的分类";
        // 打上“需要重新居中”的标记
        [self setShouldRecenter:YES];
    } else {
        self.text = newText;
        // 其他情况确保标记为 NO
        [self setShouldRecenter:NO];
    }
}

// 第二步：在最合适的时机 layoutSubviews 中执行布局修改
- (void)layoutSubviews {
    // 必须先调用原始的 layoutSubviews，让系统完成它的布局
    %orig;

    // 检查我们之前打的标记
    if ([self shouldRecenter]) {
        // 在这里调整大小和居中
        [self sizeToFit];
        
        UIView *superview = self.superview;
        if (superview) {
            self.center = CGPointMake(superview.bounds.size.width / 2, self.center.y);
        }
        
        // 重要：执行完一次后，把标记清除，防止不必要的重复操作
        [self setShouldRecenter:NO];
    }
}

%end
