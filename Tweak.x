#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 全新的、更强力的文字替换功能 (通过Hook绘图函数实现)
// =========================================================================
// 这种方法可以捕获到绝大多数情况，包括自定义视图
%hook NSString

// Hook最常用的字符串绘制方法
- (void)drawInRect:(CGRect)rect withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
    NSString *originalString = (NSString *)self;
    if ([originalString isEqualToString:@"设置局式"] || [originalString isEqualToString:@"設置局式"]) {
        // 如果匹配，就用新文字和原始样式来绘制
        [@"Echo定制" drawInRect:rect withAttributes:attrs];
    } else {
        // 如果不匹配，就正常绘制原始内容
        %orig(rect, attrs);
    }
}

// Hook另一个常用的字符串绘制方法
- (void)drawAtPoint:(CGPoint)point withAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs {
    NSString *originalString = (NSString *)self;
    if ([originalString isEqualToString:@"设置局式"] || [originalString isEqualToString:@"設置局式"]) {
        [@"Echo定制" drawAtPoint:point withAttributes:attrs];
    } else {
        %orig(point, attrs);
    }
}

%end

// 同时Hook富文本(NSAttributedString)的绘制方法，以防万一
%hook NSAttributedString

- (void)drawInRect:(CGRect)rect {
    NSAttributedString *originalString = (NSAttributedString *)self;
    if ([originalString.string isEqualToString:@"设置局式"] || [originalString.string isEqualToString:@"設置局式"]) {
        // 创建一个可变副本，只修改文字内容，保留所有样式（颜色、字体等）
        NSMutableAttributedString *newString = [originalString mutableCopy];
        [newString.mutableString setString:@"Echo定制"];
        // 绘制修改后的富文本
        [newString drawInRect:rect];
    } else {
        %orig(rect);
    }
}

- (void)drawAtPoint:(CGPoint)point {
    NSAttributedString *originalString = (NSAttributedString *)self;
     if ([originalString.string isEqualToString:@"设置局式"] || [originalString.string isEqualToString:@"設置局式"]) {
        NSMutableAttributedString *newString = [originalString mutableCopy];
        [newString.mutableString setString:@"Echo定制"];
        [newString drawAtPoint:point];
    } else {
        %orig(point);
    }
}

%end


// =========================================================================
// Section 2: 全局水印功能 (无需任何改动，工作正常，直接保留)
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
