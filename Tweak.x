#import <UIKit/UIKit.h>
//#import <FLEXing/FLEXManager.h>

// 构造函数，用于调试
//%ctor {
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [[FLEXManager sharedManager] showExplorer];
//    });
//}


// =========================================================================
// Section 1: UILabel 文字和样式替换 (保持不变)
// =========================================================================
%hook UILabel
// ... (请在这里保留你完整的、已成功的 UILabel Hook 代码) ...
%end


// =========================================================================
// Section 2: 全局水印 & 状态栏修复的最终组合
// =========================================================================

// 水印瓦片创建函数 (必须放在 %hook 之前)
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

// Hook 1: 强制为状态栏腾出物理空间
- (void)setFrame:(CGRect)frame {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    // 对所有全屏窗口生效
    if (CGRectEqualToRect(frame, screenBounds)) {
        CGFloat statusBarHeight = 59.0;
        
        CGRect newFrame = frame;
        if (newFrame.origin.y < statusBarHeight) {
            newFrame.origin.y = statusBarHeight;
            newFrame.size.height -= statusBarHeight;
        }
        
        %orig(newFrame);
        return;
    }
    %orig;
}

// Hook 2: 添加和管理水印
- (void)layoutSubviews {
    %orig;

    // 只在主窗口上添加水印
    if (self.windowLevel != UIWindowLevelNormal) {
        return;
    }

    NSInteger watermarkTag = 998877;
    UIView *watermarkView = [self viewWithTag:watermarkTag];

    if (!watermarkView) {
        NSString *watermarkText = @"Echo定制";
        UIFont *watermarkFont = [UIFont systemFontOfSize:16.0];
        UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.08];
        CGFloat rotationAngle = -30.0;
        CGSize tileSize = CGSizeMake(150, 100);

        UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle);
        
        UIView *newWatermarkView = [[UIView alloc] initWithFrame:self.bounds];
        newWatermarkView.tag = watermarkTag;
        newWatermarkView.userInteractionEnabled = NO;
        newWatermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        newWatermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage];
        
        [self insertSubview:newWatermarkView atIndex:0];
    }
    
    // 确保水印在最底层
    [self sendSubviewToBack:[self viewWithTag:watermarkTag]];
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
