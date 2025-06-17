#import <UIKit/UIKit.h>
#import <FLEXing/FLEXManager.h>

// 构造函数，在 App 启动时显示 FLEXing 按钮 (如果不需要可以删除或注释掉这部分)
%ctor {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[FLEXManager sharedManager] showExplorer];
    });
}


// =========================================================================
// Section 1: UILabel 文字和样式替换
// =========================================================================
%hook UILabel

- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }

    NSString *newString = nil;

    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }

    if (newString) {
        UIFont *currentFont = self.font;
        UIColor *currentColor = self.textColor;
        NSTextAlignment alignment = self.textAlignment;
        
        NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
        if (currentFont) attributes[NSFontAttributeName] = currentFont;
        if (currentColor) attributes[NSForegroundColorAttributeName] = currentColor;
        
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        paragraphStyle.alignment = alignment;
        attributes[NSParagraphStyleAttributeName] = paragraphStyle;

        NSAttributedString *newAttributedText = [[NSAttributedString alloc] initWithString:newString attributes:attributes];
        [self setAttributedText:newAttributedText];
        return;
    }

    NSMutableString *simplifiedText = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false);

    %orig(simplifiedText);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }

    NSString *originalString = attributedText.string;
    NSString *newString = nil;

    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) {
        newString = @"Echo";
    } 
    else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) {
        newString = @"定制";
    }
    else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }

    if (newString) {
        NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
        [newAttributedText.mutableString setString:newString];
        %orig(newAttributedText);
        return;
    }
    
    NSMutableAttributedString *newAttributedText = [attributedText mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)newAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false);
    
    %orig(newAttributedText);
}

%end


// =========================================================================
// Section 2: 全局水印 & 状态栏修复
// =========================================================================

// 这是创建水印“瓦片”的辅助函数，必须放在 %hook UIWindow 的前面
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

// Hook 1: 修改 Frame，为状态栏腾出物理空间
- (void)setFrame:(CGRect)frame {
    if (self.windowLevel == UIWindowLevelNormal) {
        CGFloat statusBarHeight = 59.0; // 适用于带灵动岛的设备
        CGRect screenBounds = [[UIScreen mainScreen] bounds];

        if (CGRectEqualToRect(frame, screenBounds)) {
            CGRect newFrame = frame;
            newFrame.origin.y = statusBarHeight;
            newFrame.size.height -= statusBarHeight;
            %orig(newFrame);
            return;
        }
    }
    %orig;
}

// Hook 2: 添加和管理水印
- (void)layoutSubviews {
    %orig;

    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    NSInteger watermarkTag = 998877;
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
    CGFloat rotationAngle = -30.0;
    CGSize tileSize = CGSizeMake(150, 100);

    UIView *watermarkView = [self viewWithTag:watermarkTag];

    if (watermarkView) {
        // 水印已存在，无需操作，因为 autoresizingMask 会自动调整大小
    } else {
        // 水印不存在，创建它
        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
        
        UIView *newWatermarkView = [[UIView alloc] initWithFrame:self.bounds]; // 直接使用 self.bounds 即可
        newWatermarkView.tag = watermarkTag;
        newWatermarkView.userInteractionEnabled = NO;
        newWatermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        newWatermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        
        [self insertSubview:newWatermarkView atIndex:0];
    }
}

%end


%hook UIApplication

// Hook 3: 强制设置状态栏的逻辑为“可见”
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    %orig(NO, animation); 
}

// Hook 4: 确保 App 查询状态时也得到“可见”的结果
- (BOOL)isStatusBarHidden {
    return NO;
}

%end
