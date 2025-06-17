#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 文字替换功能 (保持不变，您的代码是正确的)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig; return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; }
    if (newString) {
        UIFont *currentFont = self.font; UIColor *currentColor = self.textColor; NSTextAlignment alignment = self.textAlignment;
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
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; }
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
// Section 2: 水印功能 (保持不变)
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180);
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor};
    CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height);
    [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext();
    return image;
}
%hook UIWindow
- (void)layoutSubviews {
    %orig; 
    if (self.windowLevel == UIWindowLevelNormal) {
        NSInteger watermarkTag = 998877;
        if ([self viewWithTag:watermarkTag]) { return; }
        NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08]; CGFloat rotationAngle = -30.0;
        CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
        UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag;
        watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView];
    }
}
%end

// =========================================================================
// Section 3: 【终极状态栏修复】
// =========================================================================

// 策略一：直接拦截并修改 UIApplication 的全局设置
// 这是最有可能解决问题的部分，因为它直接针对老式的、全局性的状态栏隐藏方法。
%hook UIApplication

// 拦截这个最常用的方法
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    // 无论 App 想做什么（传进来的 hidden 是 YES 还是 NO），我们都强制传 NO 给原始方法
    %orig(NO, animation);
}

// 同时拦截不带动画的这个方法，以防万一
- (void)setStatusBarHidden:(BOOL)hidden {
    %orig(NO);
}

%end


// 策略二：继续保持对现代 UIViewController 方法的覆盖
// 这是一个好习惯，确保我们的 Tweak 在不同 iOS 版本和 App 架构下都能工作。
%hook UIViewController

- (BOOL)prefersStatusBarHidden {
    return NO; // 强制“不隐藏”
}

- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil; // 让父控制器说了算
}

%end


// 策略三：在主视图控制器出现后，强制刷新状态栏外观
// 根据您提供的信息，我们直接锁定 "ViewController" 这个类
%hook ViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;

    // 在视图显示出来后，主动通知系统：“请重新检查一下状态栏的显示状态”
    // 这会触发系统再次调用 prefersStatusBarHidden 方法，确保我们的设置被应用。
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}

%end
