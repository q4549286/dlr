#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow) - 这部分没有问题
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { UIFont *currentFont = self.font; UIColor *currentColor = self.textColor; NSTextAlignment alignment = self.textAlignment; NSMutableDictionary *attributes = [NSMutableDictionary dictionary]; if (currentFont) attributes[NSFontAttributeName] = currentFont; if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor; NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init]; paragraphStyle.alignment = alignment; attributes[NSParagraphStyleAttributeName] = paragraphStyle; NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes]; [self setAttributedText:newAttributedText]; return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; [newAttributedText.mutableString setString:newString]; %orig(newAttributedText); return; } NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(newAttributedText); }
%end

static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end


// =========================================================================
// Section 3: 【新功能】一键复制到 AI (极简核心验证版)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_CoreTest;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = objc_getClass("六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); 
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"提取课体" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor systemIndigoColor]; // 换个颜色，表示新版本
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_CoreTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// 辅助方法：递归查找指定类的所有子视图
%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage];
    }
}

// 【极简核心验证版】
%new
- (void)copyAiButtonTapped_CoreTest {
    // 1. 找到所有 `六壬大占.课体视图`
    NSMutableArray *ketiViews = [NSMutableArray array];
    Class ketiViewClass = objc_getClass("六壬大占.课体视图");
    if (!ketiViewClass) {
        // 如果找不到这个类，弹窗报错
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"找不到类: 六壬大占.课体视图" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    [self findSubviewsOfClass:ketiViewClass inView:self.view andStoreIn:ketiViews];
    
    // 2. 提取所有这些视图内部的UILabel
    NSMutableArray *allKetiLabels = [NSMutableArray array];
    for (UIView *ketiView in ketiViews) {
        [self findSubviewsOfClass:[UILabel class] inView:ketiView andStoreIn:allKetiLabels];
    }

    // 3. 按Y坐标排序这些UILabel
    [allKetiLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
    }];

    // 4. 拼接文本
    NSMutableString *fullKetiText = [NSMutableString string];
    for (UILabel *label in allKetiLabels) {
        if (label.text && label.text.length > 0) {
            [fullKetiText appendFormat:@"%@\n", label.text];
        }
    }

    // 5. 在弹窗中显示结果
    NSString *title = [NSString stringWithFormat:@"共找到 %ld 个课体视图", (unsigned long)ketiViews.count];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:fullKetiText preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制内容" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = fullKetiText;
    }];
    [alert addAction:copyAction];

    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:closeAction];

    [self presentViewController:alert animated:YES completion:nil];
}

%end
