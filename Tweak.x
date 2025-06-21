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
// Section 3: 【新功能】一键复制到 AI (调试专用版)
// =========================================================================

static const char *AllLabelsOnViewKey = "AllLabelsOnViewKey";
static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)refreshAndSortLabelsForAiCopy;
- (void)findAllLabelsInView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (void)copyAiButtonTapped_Debug; // 改个名字，表明是调试用的
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = objc_getClass("六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) {
                return;
            }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); 
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"查看索引" forState:UIControlStateNormal]; // 按钮文字改成"查看索引"
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor systemOrangeColor]; // 按钮颜色改成橙色，以示区别
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_Debug) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    Class targetClass = objc_getClass("六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        [self refreshAndSortLabelsForAiCopy];
    }
}

%new
- (void)refreshAndSortLabelsForAiCopy {
    NSMutableArray *labels = [NSMutableArray array];
    [self findAllLabelsInView:self.view andStoreIn:labels];
    NSArray *sortedLabels = [labels sortedArrayUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        CGFloat y1 = roundf(obj1.frame.origin.y); CGFloat y2 = roundf(obj2.frame.origin.y);
        if (y1 < y2) return NSOrderedAscending; if (y1 > y2) return NSOrderedDescending;
        CGFloat x1 = roundf(obj1.frame.origin.x); CGFloat x2 = roundf(obj2.frame.origin.x);
        if (x1 < x2) return NSOrderedAscending; if (x1 > x2) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    objc_setAssociatedObject(self, &AllLabelsOnViewKey, sortedLabels, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)findAllLabelsInView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text.length > 0) { [storage addObject:label]; }
    }
    for (UIView *subview in view.subviews) { [self findAllLabelsInView:subview andStoreIn:storage]; }
}

// 【调试专用版】点击后，弹窗直接显示所有索引和文本
%new
- (void)copyAiButtonTapped_Debug {
    NSArray *sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    if (!sortedLabels || sortedLabels.count == 0) {
        [self refreshAndSortLabelsForAiCopy];
        sortedLabels = objc_getAssociatedObject(self, &AllLabelsOnViewKey);
    }
    if (sortedLabels.count == 0) { 
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"未找到任何文本标签" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return; 
    }
    
    // 创建一个巨大的字符串，包含所有信息
    NSMutableString *treasureMap = [NSMutableString string];
    for (int i = 0; i < sortedLabels.count; i++) {
        UILabel *label = sortedLabels[i];
        NSString *text = [label.text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]; // 把换行符显示成\n
        // 格式: 索引 - "文本内容"
        [treasureMap appendFormat:@"%d - \"%@\"\n", i, text];
    }
    
    // 在一个弹窗里显示这个巨大的字符串
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"索引藏宝图" message:treasureMap preferredStyle:UIAlertControllerStyleAlert];
    
    // 添加一个“复制”按钮，可以直接把这张“藏宝图”复制下来发给我
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制这张图" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = treasureMap;
    }];
    [alert addAction:copyAction];

    // 添加一个“关闭”按钮
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    [alert addAction:closeAction];

    [self presentViewController:alert animated:YES completion:nil];
}

%end
