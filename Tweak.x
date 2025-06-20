#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// Section 1: 文字替换功能 (保持原样，等待确认目标控件)
// =========================================================================

%hook UILabel
- (void)setText:(NSString *)text {
    if (text && ([text isEqualToString:@"设置局式"] || [text isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制");
    } else {
        %orig(text);
    }
}
%end

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (title && ([title isEqualToString:@"设置局式"] || [title isEqualToString:@"設置局式"])) {
        %orig(@"Echo定制", state);
    } else {
        %orig(title, state);
    }
}
%end

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
            NSMutableAttributedString *newAttrString = [string mutableCopy];
            [newAttrString.mutableString setString:@"Echo定制"];
            %orig(newAttrString);
        } else {
            %orig(@"Echo定制");
        }
    } else {
        %orig(string);
    }
}
%end

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
// Section 2: 全局水印功能 (已临时注释掉，方便您进行调试)
// =========================================================================
/*
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
*/
