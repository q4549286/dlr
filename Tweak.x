#import <UIKit/UIKit.h>

// =========================================================================
// Section 1: 你原有的文字替换功能 (无需任何改动，直接保留)
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
// Section 2: 全新的全局水印功能
// =========================================================================

// 定义一个C函数，专门用来创建水印图片的“瓦片”
// 这样做可以保持代码整洁
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); // 使用NO表示背景透明
    CGContextRef context = UIGraphicsGetCurrentContext();

    // 将坐标系原点移动到瓦片中心，方便旋转
    CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2);
    // 旋转坐标系
    CGContextRotateCTM(context, angle * M_PI / 180);

    // 设置文字属性
    NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor};
    // 计算文字尺寸，使其在旋转后居中
    CGSize textSize = [text sizeWithAttributes:attributes];
    CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height);
    
    // 绘制文字
    [text drawInRect:textRect withAttributes:attributes];

    // 从上下文中获取图片
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return image;
}

%hook UIWindow

// Hook layoutSubviews 方法，这是一个在窗口布局变化时会被调用的安全时机
- (void)layoutSubviews {
    %orig; // 必须先调用原始方法

    // 定义一个独一无二的 tag，用来识别我们的水印视图，防止重复添加
    NSInteger watermarkTag = 998877;
    
    // 如果已经存在水印视图，就直接返回，什么都不做
    if ([self viewWithTag:watermarkTag]) {
        return;
    }

    // --- 在这里自定义你的水印样式 ---
    NSString *watermarkText = @"Echo定制";
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; // 黑色，8%的透明度，效果会很淡
    CGFloat rotationAngle = -30.0; // 倾斜-30度
    CGSize tileSize = CGSizeMake(150, 100); // 每个水印“瓦片”的尺寸，可以调整间距
    // --------------------------------

    // 1. 创建水印瓦片图片
    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);

    // 2. 创建一个和窗口一样大的视图作为水印层
    UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
    watermarkView.tag = watermarkTag; // 打上我们的专属标签
    watermarkView.userInteractionEnabled = NO; // 非常重要！让水印不影响下层UI的点击事件
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; // 确保窗口尺寸变化时，水印层也跟着变

    // 3. 将瓦片图片设置为水印层的背景色，实现平铺效果
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
    
    // 4. 将水印层添加到窗口上，并确保它在最顶层
    [self addSubview:watermarkView];
    [self bringSubviewToFront:watermarkView];
}

%end
// =========================================================================
// Section 6: 终极状态栏显示方案 (组合拳)
// =========================================================================

// 我们需要同时 Hook UIWindow 和 UIApplication

%hook UIWindow

// Hook setFrame: 来强制为状态栏腾出物理空间
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

%end


%hook UIApplication

// Hook setStatusBarHidden: 来强制设置状态栏的逻辑为“可见”
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation {
    // 无论 App 传什么进来，我们都强制用 NO (不隐藏) 去调用原始方法
    %orig(NO, animation); 
}

// Hook isStatusBarHidden 来确保 App 查询状态时也得到“可见”的结果
- (BOOL)isStatusBarHidden {
    return NO;
}

%end
