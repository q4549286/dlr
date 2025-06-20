#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 修改后的文字替换功能 (覆盖UILabel和UIButton)
// =========================================================================

// Hook UILabel (用于替换普通的文本标签)
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

%end


// 【新增】Hook UIButton (用于替换按钮上的文字)
%hook UIButton

- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (title && ([title isEqualToString:@"设置局式"] || [title isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制", state);
    } else {
        %orig(title, state);
    }
}

- (void)setAttributedTitle:(NSAttributedString *)title forState:(UIControlState)state {
    if (title && ([title.string isEqualToString:@"设置局式"] || [title.string isEqualToString:@"設置局式"])) {
        NSMutableAttributedString *newTitle = [title mutableCopy];
        [newTitle.mutableString setString:@"Echo定制"];
        %orig(newTitle, state);
    } else {
        %orig(title, state);
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (无需任何改动，直接保留)
// =========================================================================

// 定义一个C函数，专门用来创建水印图片的“瓦片”
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

    // --- 水印样式 ---
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);
    // -----------------

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
