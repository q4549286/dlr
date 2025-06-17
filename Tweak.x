#import <UIKit/UIKit.h>
//#import <FLEXing/FLEXManager.h>

// 构造函数，在 App 启动时显示 FLEXing 按钮 (如果调试完成，可以删除或注释掉这部分)
//%ctor {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[FLEXManager sharedManager] showExplorer];
//    });
//}


// =========================================================================
// Section 1: UILabel 文字和样式替换 (这是你已成功的部分)
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
// Section 2: 全局水印 (这是你已成功的部分)
// =========================================================================

// 创建水印“瓦片”的辅助函数
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

// 只是在主窗口上添加水印
%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel == UIWindowLevelNormal) {
        NSInteger watermarkTag = 998877;
        if (![self viewWithTag:watermarkTag]) {
            NSString *watermarkText = @"Echo定制";
            UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
            UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
            CGFloat rotationAngle = -30.0;
            CGSize tileSize = CGSizeMake(150, 100);

            UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
            
            UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds];
            watermarkView.tag = watermarkTag;
            watermarkView.userInteractionEnabled = NO;
            watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
            
            [self insertSubview:watermarkView atIndex:0];
        }
    }
}
%end


// =========================================================================
// Section 3: 终极状态栏修复 (直接操控 SceneDelegate 和 Window)
// =========================================================================

// !!!【非常重要】!!!
// 请用 FLEXing 找到 App 的 SceneDelegate 真实类名, 然后替换掉下面的 "AppNameSceneDelegate"
%hook AppNameSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    %orig;

    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    UIWindowScene *windowScene = (UIWindowScene *)scene;

    // 延时执行，确保 App 的所有原生布局代码都已执行完毕
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 1. 强制设置 statusBarManager 的属性为可见
        if (@available(iOS 13.0, *)) {
            id statusBarManager = [windowScene performSelector:@selector(statusBarManager)];
            if (statusBarManager) {
                // 直接设置私有属性 _statusBarHidden，比调用方法更强制
                [statusBarManager setValue:@(NO) forKey:@"_statusBarHidden"];
                
                // 触发 statusBarManager 更新其外观
                [statusBarManager performSelector:@selector(updateStatusBarAppearance)];
            }
        }

        // 2. 遍历所有窗口，强制修改全屏窗口的 frame 为状态栏腾出空间
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            CGRect screenBounds = [[UIScreen mainScreen] bounds];
            if (CGRectEqualToRect(window.frame, screenBounds)) {
                CGFloat statusBarHeight = 59.0;
                CGRect newFrame = window.frame;

                // 只有当 frame 的 y 坐标还是 0 时才修改，防止重复执行
                if (newFrame.origin.y < statusBarHeight) {
                    newFrame.origin.y = statusBarHeight;
                    newFrame.size.height -= statusBarHeight;
                    window.frame = newFrame;
                }
            }
        }
    });
}

%end
