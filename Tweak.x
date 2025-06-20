#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 文字替换功能 (此部分已确认工作正常，无需改动)
// =========================================================================
%hook UILabel

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

- (void)didMoveToWindow {
    %orig; 

    if (self.text && ([self.text isEqualToString:@"设置局式"] || [self.text isEqualToString:@"設置局式"])) {
        self.text = @"Echo定制";
    }
    
    if (self.attributedText && ([self.attributedText.string isEqualToString:@"设置局式"] || [self.attributedText.string isEqualToString:@"設置局式"])) {
        NSMutableAttributedString *newAttributedText = [self.attributedText mutableCopy];
        [newAttributedText.mutableString setString:@"Echo定制"];
        self.attributedText = newAttributedText;
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (已修复卡死问题)
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

    // 【重要修正】只在主程序窗口上添加水印。
    // 主窗口的 windowLevel 是 UIWindowLevelNormal (值为0.0)。
    // 键盘、状态栏等系统窗口的 level 更高，这样可以把它们过滤掉。
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
