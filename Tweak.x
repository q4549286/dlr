#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h> // 必须导入这个头文件才能使用 CATextLayer

// =========================================================================
// Section 1: 终极文字替换 (覆盖 UILabel, UIButton, CATextLayer 和底层绘图)
// =========================================================================

// ----- 目标 1: UILabel -----
%hook UILabel
- (void)setText:(NSString *)text {
    if (text && ([text isEqualToString:@"设置局式"] || [text isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制");
    } else {
        %orig(text);
    }
}
%end

// ----- 目标 2: UIButton -----
%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (title && ([title isEqualToString:@"设置局式"] || [title isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制", state);
    } else {
        %orig(title, state);
    }
}
%end

// ----- 【新增目标 3】: CATextLayer (非常有可能就是这个！) -----
%hook CATextLayer
- (void)setString:(id)string {
    NSString *textToCompare = nil;
    if ([string isKindOfClass:[NSString class]]) {
        textToCompare = (NSString *)string;
    } else if ([string isKindOfClass:[NSAttributedString class]]) {
        textToCompare = [(NSAttributedString *)string string];
    }

    if (textToCompare && ([textToCompare isEqualToString:@"设置局式"] || [textToCompare isEqualToString:@"設置局式"])) {
        if ([string isKindOfClass:[NSAttributedString class]]) {
            // 如果是富文本，保留样式，只改文字
            NSMutableAttributedString *newAttrString = [string mutableCopy];
            [newAttrString.mutableString setString:@"Echo定制"];
            %orig(newAttrString);
        } else {
            // 如果是普通文本，直接替换
            %orig(@"Echo定制");
        }
    } else {
        %orig(string);
    }
}
%end

// ----- 目标 4: 底层绘图函数 (作为最后的保险) -----
%hook NSString
- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
    if ([(NSString *)self isEqualToString:@"设置局式"] || [(NSString *)self isEqualToString:@"設置局式"]) {
        [@"Echo定制" drawInRect:rect withAttributes:attrs];
    } else {
        %orig(rect, attrs);
    }
}
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
    if ([(NSString *)self isEqualToString:@"设置局式"] || [(NSString *)self isEqualToString:@"設置局式"]) {
        [@"Echo定制" drawAtPoint:point withAttributes:attrs];
    } else {
        %orig(point, attrs);
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
