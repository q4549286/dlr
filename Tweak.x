#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow)
// =========================================================================
// ... (您的UILabel和UIWindow的hook代码，原封不动地放在这里) ...
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { UIFont *currentFont = self.font; UIColor *currentColor = self.textColor; NSTextAlignment alignment = self.textAlignment; NSMutableDictionary *attributes = [NSMutableDictionary dictionary]; if (currentFont) attributes[NSFontAttributeName] = currentFont; if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor; NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init]; paragraphStyle.alignment = alignment; attributes[NSParagraphStyleAttributeName] = paragraphStyle; NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes]; [self setAttributedText:newAttributedText]; return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; [newAttributedText.mutableString setString:newString]; %orig(newAttributedText); return; } NSMutableAttributedString *newAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(newAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end

// =========================================================================
// Section 3: 【侦测器Tweak】 - 获取真实类名
// =========================================================================
static NSInteger const DetectorButtonTag = 223344;

@interface UIViewController (ClassNameDetector)
- (void)detectAndShowClassNames;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // 我们在所有ViewController上都加上这个侦测按钮，确保不会错过
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow || [keyWindow viewWithTag:DetectorButtonTag]) { return; }
        UIButton *detectorButton = [UIButton buttonWithType:UIButtonTypeSystem];
        // 按钮放在左上角，防止和原来的按钮重叠
        detectorButton.frame = CGRectMake(10, 45, 100, 36); 
        detectorButton.tag = DetectorButtonTag;
        [detectorButton setTitle:@"侦测类名" forState:UIControlStateNormal];
        detectorButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        detectorButton.backgroundColor = [UIColor systemTealColor]; // 醒目的蓝绿色
        [detectorButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        detectorButton.layer.cornerRadius = 8;
        [detectorButton addTarget:self action:@selector(detectAndShowClassNames) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:detectorButton];
    });
}

// 辅助方法：递归查找
%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage];
    }
}

// 按钮点击时执行的方法
%new
- (void)detectAndShowClassNames {
    // 1. 获取当前 ViewController 的真实类名
    NSString *vcClassName = NSStringFromClass([self class]);

    // 2. 查找所有的 UICollectionView
    NSMutableArray *collectionViews = [NSMutableArray array];
    [self findSubviewsOfClass:[UICollectionView class] inView:self.view andStoreIn:collectionViews];

    // 3. 准备要显示的信息
    NSMutableString *resultString = [NSMutableString string];
    [resultString appendFormat:@"当前ViewController类名:\n%@\n\n", vcClassName];
    [resultString appendFormat:@"找到 %ld 个 UICollectionView:\n", (unsigned long)collectionViews.count];
    
    for (int i = 0; i < collectionViews.count; i++) {
        UIView *cv = collectionViews[i];
        // 获取每个CollectionView的真实类名
        NSString *cvClassName = NSStringFromClass([cv class]);
        [resultString appendFormat:@"\n%d: %@\n", i + 1, cvClassName];
    }

    // 4. 在弹窗中显示，并提供复制按钮
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"真实类名侦测结果" message:resultString preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制所有信息" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = resultString;
    }];
    [alert addAction:copyAction];

    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:closeAction];

    [self presentViewController:alert animated:YES completion:nil];
}

%end
