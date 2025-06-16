#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void * const kShouldRecenterKey = (void *)&kShouldRecenterKey;

@interface UILabel (MyTweak)
- (void)setShouldRecenter:(BOOL)shouldRecenter;
- (BOOL)shouldRecenter;
@end

%hook UILabel

- (void)setShouldRecenter:(BOOL)shouldRecenter {
    objc_setAssociatedObject(self, kShouldRecenterKey, @(shouldRecenter), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldRecenter {
    NSNumber *value = objc_getAssociatedObject(self, kShouldRecenterKey);
    return [value boolValue];
}

- (void)setText:(NSString *)text {
    %orig;
    if (!self.text) { return; }

    NSMutableString *newText = [self.text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);
    
    if ([newText isEqualToString:@"通类"]) {
        self.text = @"Echo定制";
        [self setShouldRecenter:YES];
        // 请求系统在下一个周期更新布局，而不是立即
        [self setNeedsLayout];
    } else {
        self.text = newText;
        [self setShouldRecenter:NO];
    }
}

- (void)layoutSubviews {
    %orig;

    if ([self shouldRecenter]) {
        UIView *superview = self.superview;
        if (superview) {
            // 计算目标中心点 X 坐标
            CGFloat targetCenterX = superview.bounds.size.width / 2;
            
            // --- 这就是我们的“断路器” ---
            // 如果中心点已经差不多在目标位置了（允许0.5像素的误差），就直接返回，打破循环！
            if (fabs(self.center.x - targetCenterX) < 0.5) {
                // 清除标记并返回
                [self setShouldRecenter:NO];
                return;
            }
            
            // 如果还没居中，才执行修改操作
            [self sizeToFit];
            self.center = CGPointMake(targetCenterX, self.center.y);
        }
    }
}

%end
