#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 新的文字替换功能 (将 “胎元” 替换为 “Echo定制胎元”)
// =========================================================================
%hook UILabel

// 1. 捕获动态设置的文本
- (void)setText:(NSString *)text {
    // 检查文本中是否 *包含* "胎元"
    if (text && [text containsString:@"胎元"]) {
        // 创建一个新字符串，只把 "胎元" 替换掉，保留其他部分
        NSString *newText = [text stringByReplacingOccurrencesOfString:@"胎元" withString:@"Echo定制胎元"];
        %orig(newText);
    } else {
        %orig(text);
    }
}

// 2. 捕获动态设置的富文本 (Attributed Text)
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (attributedText && [attributedText.string containsString:@"胎元"]) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        // 在可变富文本中进行替换
        [newAttributedText.mutableString replaceOccurrencesOfString:@"胎元"
                                                         withString:@"Echo定制胎元"
                                                            options:0
                                                              range:NSMakeRange(0, newAttributedText.length)];
        %orig(newAttributedText);
    } else {
        %orig(attributedText);
    }
}


// 3. 检查已存在的文本 (解决时机问题，当Label显示时检查)
- (void)didMoveToWindow {
    %orig; // 必须先调用原始方法

    // 检查普通文本
    if (self.text && [self.text containsString:@"胎元"]) {
        self.text = [self.text stringByReplacingOccurrencesOfString:@"胎元" withString:@"Echo定制胎元"];
    }
    
    // 检查富文本
    if (self.attributedText && [self.attributedText.string containsString:@"胎元"]) {
        NSMutableAttributedString *newAttributedText = [self.attributedText mutableCopy];
        [newAttributedText.mutableString replaceOccurrencesOfString:@"胎元"
                                                         withString:@"Echo定制胎元"
                                                            options:0
                                                              range:NSMakeRange(0, newAttributedText.length)];
        self.attributedText = newAttributedText;
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (和之前一样，无需改动)
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

    // 只在主窗口上添加水印，防止键盘等界面卡死
    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    NSInteger watermarkTag = 998877;
    if ([self viewWithTag:watermarkTag]) {
        return;
    }

    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);
    
    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
    UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
    watermarkView.tag = watermarkTag;
    watermarkView.userInteractionEnabled = NO;
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
    
    [self addSubview:watermarkView];
    [self bringSubviewToFront:watermarkView];
}

%end
