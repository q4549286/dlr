#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 文字替换功能 (保持不变)
// =========================================================================
%hook UILabel
// ... (此处省略，请使用您完整的UILabel代码) ...
- (void)setText:(NSString *)text { if (!text) { %orig; return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { UIFont *currentFont = self.font; UIColor *currentColor = self.textColor; NSTextAlignment alignment = self.textAlignment; NSMutableDictionary *attributes = [NSMutableDictionary dictionary]; if (currentFont) attributes[NSFontAttributeName] = currentFont; if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor; NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init]; paragraphStyle.alignment = alignment; attributes[NSParagraphStyleAttributeName] = paragraphStyle; NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes]; [self setAttributedText:newAttributedText]; return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig; return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; [newAttributedText.mutableString setString:newString]; %orig(newAttributedText); return; } NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(newAttributedText); }
%end

// =========================================================================
// Section 2: 水印功能 (保持不变)
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel == UIWindowLevelNormal) { NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; } }
%end

// =========================================================================
// Section 3: 【终极状态栏修复】
// =========================================================================

// 策略一：直接拦截并修改 UIApplication 的全局设置
%hook UIApplication
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    %orig(NO, animation);
}
- (void)setStatusBarHidden:(BOOL)hidden {
    %orig(NO);
}
%end

// 策略二：继续保持对现代 UIViewController 方法的覆盖
%hook UIViewController
- (BOOL)prefersStatusBarHidden {
    return NO;
}
- (UIViewController *)childViewControllerForStatusBarHidden {
    return nil;
}
%end


// ------------------- 【关键修复】 -------------------
// 在 Hook App 自家的 ViewController 之前，
// 我们需要先告诉编译器它的“身世”：它是一个 UIViewController。
@interface ViewController : UIViewController
@end
// ----------------------------------------------------


// 策略三：在主视图控制器出现后，强制刷新状态栏外观
%hook ViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // 因为我们上面已经声明了 ViewController 的父类是 UIViewController，
    // 所以编译器现在知道 `self` 可以调用这个方法了。
    if ([self respondsToSelector:@selector(setNeedsStatusBarAppearanceUpdate)]) {
        [self setNeedsStatusBarAppearanceUpdate];
    }
}
%end
