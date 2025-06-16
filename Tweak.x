#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 声明部分 ---
// 定义一个独一无二的 key，用于关联我们的标记
static void * const kIsSpecialLabelKey = (void *)&kIsSpecialLabelKey;

// 为 UILabel 创建一个分类来声明新方法
@interface UILabel (MyTweak)
- (void)setIsSpecialLabel:(BOOL)isSpecial;
- (BOOL)isSpecialLabel;
@end


%hook UILabel

// --- 关联对象实现 ---
- (void)setIsSpecialLabel:(BOOL)isSpecial {
    objc_setAssociatedObject(self, kIsSpecialLabelKey, @(isSpecial), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isSpecialLabel {
    NSNumber *value = objc_getAssociatedObject(self, kIsSpecialLabelKey);
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
        // 1. 替换文字
        [newText replaceOccurrencesOfString:@"通类" withString:@"我的分类" options:NSLiteralSearch range:NSMakeRange(0, [newText length])];
        // 2. 打上“特殊处理”标记
        [self setIsSpecialLabel:YES];
    } else {
        // 3. 对于其他 Label，确保没有标记
        [self setIsSpecialLabel:NO];
    }
    
    // 调用原始方法，把修改后的文本传进去
    %orig(newText);
}


// 第二步：拦截 setTextAlignment:，强制居中
- (void)setTextAlignment:(NSTextAlignment)alignment {
    // 如果是我们的特殊 Label，就忽略原始的 alignment，强制设为居中
    if ([self isSpecialLabel]) {
        %orig(NSTextAlignmentCenter);
    } else {
        // 否则，保持系统原来的设定
        %orig;
    }
}


// 第三步：拦截 setFrame:，调整宽度
- (void)setFrame:(CGRect)frame {
    if ([self isSpecialLabel]) {
        // 获取字体信息，这是精确计算宽度的基础
        UIFont *font = self.font;
        if (font) {
            // 计算“我的分类”这四个字需要的宽度
            // "我的分类" 是4个字符，"通类"是2个字符，所以宽度大约是原来的2倍
            // 为了保险起见，我们给一个更大的宽度，比如乘以 2.1
            CGFloat originalWidth = frame.size.width;
            CGFloat newWidth = originalWidth * 2.1; 

            // 在系统计算出的 frame 基础上，只修改宽度
            frame.size.width = newWidth;

            // 由于宽度变了，为了保持居中，还需要调整 x 坐标
            // 新的 x = 旧的 x - (新宽度 - 旧宽度) / 2
            frame.origin.x -= (newWidth - originalWidth) / 2;
        }
    }
    // 把修改后（或未修改）的 frame 交给原始方法去设置
    %orig(frame);
}

%end
