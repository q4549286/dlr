// StatusBarFixTweak.xm
// 完整 Logos 越狱插件示例：
// 解决 App 强行隐藏状态栏的问题，同时保留原有文字替换与水印
// ------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1: 文字替换功能
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig; return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }
    if (newString) {
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;
        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];
        [self setAttributedText:newAttributedText];
        return;
    }
    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);
    %orig(simplifiedText);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig; return; }
    NSString *originalString = attributedText.string;
    NSString *newString = nil;
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }
    if (newString) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:newString];
        %orig(newAttributedText);
        return;
    }
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(newAttributedText);
}
%end

// =========================================================================
// Section 2: 水印功能
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2);
    CGContextRotateCTM(context, angle * M_PI / 180);
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor};
    CGSize textSize = [text sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height);
    [text drawInRect:textRect withAttributes:attributes];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel == UIWindowLevelNormal) {
        NSInteger watermarkTag = 998877;
        if ([self viewWithTag:watermarkTag]) {
            return; // 已添加
        }
        NSString *watermarkText = @"Echo定制";
        UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [[UIColor blackColor] colorWithAlphaComponent:0.08];
        CGFloat rotationAngle = -30.0;
        CGSize tileSize = CGSizeMake(150, 100);
        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);

        UIView *watermarkView = [[UIView alloc] initWithFrame:CGRectZero];
        watermarkView.tag = watermarkTag;
        watermarkView.userInteractionEnabled = NO;
        watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];

        // 只覆盖 Safe-Area 以下，避免挡住状态栏
        CGRect frame = self.bounds;
        CGFloat topInset = 0;
        if (@available(iOS 11.0, *)) {
            topInset = self.safeAreaInsets.top;
        } else {
            topInset = [UIApplication sharedApplication].statusBarFrame.size.height;
        }
        frame.origin.y += topInset;
        frame.size.height -= topInset;
        watermarkView.frame = frame;

        [self addSubview:watermarkView];
    }
}
%end

// =========================================================================
// Section 3: 终极状态栏修复 (iOS 13+ 全面覆盖)
// =========================================================================

// 3.1 动态修改 Info.plist 让 UIApplication API 生效
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *dict = [[%orig mutableCopy] autorelease];
    dict[@"UIViewControllerBasedStatusBarAppearance"] = @NO;
    return dict;
}
%end

// 3.2 Scene 级别：禁止 UIStatusBarManager 把状态栏隐藏
%hook UIStatusBarManager
- (BOOL)isStatusBarHidden {
    return NO;
}
%end

// 3.3 UIApplication 旧接口兜底
%hook UIApplication
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    %orig(NO, animation);
}
- (void)setStatusBarHidden:(BOOL)hidden {
    %orig(NO);
}
%end

// 3.4 UIViewController 基类默认实现
%hook UIViewController
- (BOOL)prefersStatusBarHidden {
    return NO;
}
- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil;
}
%end

// 3.5 遍历所有 UIViewController 子类，强制覆盖 prefersStatusBarHidden
static BOOL (*orig_prefersStatusBarHidden)(id, SEL);
static BOOL my_prefersStatusBarHidden(id self, SEL _cmd) {
    return NO;
}

%ctor {
    %init;

    // 延迟触发一次旧 API，确保最开始就显示状态栏
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationNone];
    });

    // 遍历并 Hook 所有 UIViewController 的子类
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    Class vcSuperclass = objc_getClass("UIViewController");
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (class_getSuperclass(cls) && class_getSuperclass(cls) == vcSuperclass) {
            MSHookMessageEx(cls, @selector(prefersStatusBarHidden), (IMP)my_prefersStatusBarHidden, (IMP *)&orig_prefersStatusBarHidden);
        }
    }
    free(classes);
}
