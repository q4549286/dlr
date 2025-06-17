// StatusBarFixTweak.xm – v1.1
// -----------------------------------------------------------------------------
// 解决状态栏被强制隐藏 + 保留文字替换 / 水印功能
// * 修复 ARC/Clang 报错 & iOS 13+ API 弃用警告
// * 默认在 Theos 下编译通过 (arm64 / iOS 12‑17)
// -----------------------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 在整个文件关闭弃用 API 警告，避免 -Werror 构建失败
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// =========================================================================
// Section 1: 文字替换功能
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
// Section 2: 水印功能
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
        static NSInteger const kWatermarkTag = 998877;
        if ([self viewWithTag:kWatermarkTag]) return; // 已添加

        NSString *watermarkText = @"Echo定制";
        UIFont   *watermarkFont  = [UIFont systemFontOfSize:16.0];
        UIColor  *watermarkColor = [[UIColor blackColor] colorWithAlphaComponent:0.08];
        CGFloat   rotationAngle  = -30.0;
        CGSize    tileSize       = CGSizeMake(150, 100);
        UIImage  *patternImage   = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);

        UIView *watermarkView = [[UIView alloc] initWithFrame:CGRectZero];
        watermarkView.tag = kWatermarkTag;
        watermarkView.userInteractionEnabled = NO;
        watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];

        // 只覆盖 Safe‑Area 以下，避免挡住状态栏
        CGRect frame = self.bounds;
        CGFloat topInset = 0;
        if (@available(iOS 11.0, *)) {
            topInset = self.safeAreaInsets.top; // 刘海 + 状态栏
        } else {
            topInset = [UIApplication sharedApplication].statusBarFrame.size.height; // <= iOS 10
        }
        frame.origin.y += topInset;
        frame.size.height -= topInset;
        watermarkView.frame = frame;

        [self addSubview:watermarkView];
    }
}
%end

// =========================================================================
// Section 3: 终极状态栏修复
// =========================================================================

// 3.1 动态修改 Info.plist，让旧 API 生效
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *origInfo = %orig;
    NSMutableDictionary *dict = origInfo.mutableCopy; // ARC 自动管理
    dict[@"UIViewControllerBasedStatusBarAppearance"] = @NO;
    return dict;
}
%end

// 3.2 Scene 级别：禁止 UIStatusBarManager 隐藏状态栏
%hook UIStatusBarManager
- (BOOL)isStatusBarHidden { return NO; }
%end

// 3.3 UIApplication 旧接口兜底
%hook UIApplication
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation { %orig(NO, animation); }
- (void)setStatusBarHidden:(BOOL)hidden { %orig(NO); }
%end

// 3.4 UIViewController 基类默认实现
%hook UIViewController
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIViewController *)childViewControllerForStatusBarHidden { return nil; }
%end

// 3.5 遍历所有 UIViewController 子类，统一覆盖
static BOOL (*orig_prefersStatusBarHidden)(id, SEL);
static BOOL my_prefersStatusBarHidden(id self, SEL _cmd) { return NO; }

%ctor {
    %init;

    // 遍历并 Hook
    unsigned int count = 0;
    Class *classes = objc_copyClassList(&count);
    Class vcSuper = objc_getClass("UIViewController");
    for (unsigned int i = 0; i < count; i++) {
        Class cls = classes[i];
        if (class_getSuperclass(cls) == vcSuper) {
            MSHookMessageEx(cls, @selector(prefersStatusBarHidden), (IMP)my_prefersStatusBarHidden, (IMP *)&orig_prefersStatusBarHidden);
        }
    }
    free(classes);
}

#pragma clang diagnostic pop
