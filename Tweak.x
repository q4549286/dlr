#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 声明部分 ---
static void * const kIsEchoLabelKey = (void *)&kIsEchoLabelKey;

@interface UILabel (MyTweak)
- (void)setIsEchoLabel:(BOOL)isEcho;
- (BOOL)isEchoLabel;
@end


%hook UILabel

// --- 关联对象实现 ---
- (void)setIsEchoLabel:(BOOL)isEcho {
    objc_setAssociatedObject(self, kIsEchoLabelKey, @(isEcho), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isEchoLabel {
    NSNumber *value = objc_getAssociatedObject(self, kIsEchoLabelKey);
    return [value boolValue];
}


// --- 核心逻辑 ---

// 第一步：在 setText 中只改文字，并打标记
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSMutableString *newText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newText, NULL, CFSTR("Hant-Hans"), false);

    // 判断是否是我们需要特殊处理的情况
    if ([newText isEqualToString:@"通类"]) {
        // 1. 替换文字为“Echo定制”
        [newText replaceOccurrencesOfString:@"通类" withString:@"Echo定制" options:NSLiteralSearch range:NSMakeRange(0, [newText length])];
        // 2. 打上“特殊处理”标记
        [self setIsEchoLabel:YES];
    } else {
        // 3. 对于其他 Label，确保没有标记
        [self setIsEchoLabel:NO];
    }
    
    // 调用原始方法，把修改后的文本传进去
    %orig(newText);
}


// 第二步：拦截 setTextAlignment:，强制居中
- (void)setTextAlignment:(NSTextAlignment)alignment {
    // 如果是我们的特殊 Label，就忽略原始的 alignment，强制设为居中
    if ([self isEchoLabel]) {
        %orig(NSTextAlignmentCenter);
    } else {
        // 否则，保持系统原来的设定
        %orig;
    }
}

%end
