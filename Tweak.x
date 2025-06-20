#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 修复后的文字替换功能
// =========================================================================
%hook UILabel

// 1. 捕获动态设置的文本
- (void)setText:(NSString *)text {
    // 【核心修复】增加一个判断，如果文本已经包含 "Echo定制版"，就不再替换，防止重复。
    if (text && [text containsString:@"胎元"] && ![text containsString:@"Echo定制版"]) {
        // 使用您要求的新文字进行替换
        NSString *newText = [text stringByReplacingOccurrencesOfString:@"胎元" withString:@"Echo定制版 胎元"];
        %orig(newText);
    } else {
        %orig(text);
    }
}

// 2. 捕获动态设置的富文本
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (attributedText && [attributedText.string containsString:@"胎元"] && ![attributedText.string containsString:@"Echo定制版"]) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString replaceOccurrencesOfString:@"胎元"
                                                         withString:@"Echo定制版 胎元"
                                                            options:0
                                                              range:NSMakeRange(0, newAttributedText.length)];
        %orig(newAttributedText);
    } else {
        %orig(attributedText);
    }
}


// 3. 检查已存在的文本（解决时机问题）
- (void)didMoveToWindow {
    %orig; 

    // 检查普通文本
    if (self.text && [self.text containsString:@"胎元"] && ![self.text containsString:@"Echo定制版"]) {
        self.text = [self.text stringByReplacingOccurrencesOfString:@"胎元" withString:@"Echo定制版 胎元"];
    }
    
    // 检查富文本
    if (self.attributedText && [self.attributedText.string containsString:@"胎元"] && ![self.attributedText.string containsString:@"Echo定制版"]) {
        NSMutableAttributedString *newAttributedText = [self.attributedText mutableCopy];
        [newAttributedText.mutableString replaceOccurrencesOfString:@"胎元"
                                                         withString:@"Echo定制版 胎元"
                                                            options:0
                                                              range:NSMakeRange(0, newAttributedText.length)];
        self.attributedText = newAttributedText;
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (无需改动)
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
