#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 针对UILabel的最终文字替换方案
// =========================================================================
%hook UILabel

// 1. 保留原始的setText: hook，用于捕获未来的、动态的文本变化。
- (void)setText:(NSString *)text {
    if (text && ([text isEqualToString:@"设置局式"] || [text isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制");
    } else {
        %orig(text);
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (attributedText && ([attributedText.string isEqualToString:@"设置局式"] || [attributedText.string isEqualToString:@"設置局式"])) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        %orig(newAttributedText);
    } else {
        %orig(attributedText);
    }
}


// 2. 【核心】新增didMoveToWindow hook，用于解决“时机问题”，捕获已经设置好的文本。
// 这个方法在UILabel被添加到窗口（即显示在屏幕上）时调用。
- (void)didMoveToWindow {
    %orig; // 必须先调用原始方法

    // 主动检查当前文本，如果是目标文本，就强制替换。
    // 这可以修复那些在tweak加载前就已设置好文本的label。
    if (self.text && ([self.text isEqualToString:@"设置局式"] || [self.text isEqualToString:@"設置局式"])) {
        self.text = @"Echo定制";
    }
    
    // 同时也要检查富文本（Attributed Text）
    if (self.attributedText && ([self.attributedText.string isEqualToString:@"设置局式"] || [self.attributedText.string isEqualToString:@"設置局式"])) {
        NSMutableAttributedString *newAttributedText = [self.attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        self.attributedText = newAttributedText;
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (无需任何改动，直接保留)
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
