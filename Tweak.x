// StatusBarFixTweak.xm – v1.2
// -----------------------------------------------------------------------------
// * 彻底显示状态栏 & 图标 (信号、电量、时间)
// * 解决 iOS 13+ UIStatusBar_Modern 被置 hidden/alpha=0 的情况
// * ARC 安全，忽略弃用警告，Theos 可编译 (arm64 / iOS 12‑17)
// -----------------------------------------------------------------------------

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// =========================================================================
// Section 0: 工具函数 – 强制遍历所有窗口，确保状态栏视图可见
// =========================================================================
static void ForceShowStatusBarViews(void) {
    for (UIWindow *w in UIApplication.sharedApplication.windows) {
        NSString *cls = NSStringFromClass(w.class);
        if ([cls isEqualToString:@"UIStatusBarWindow"] || w.windowLevel >= UIWindowLevelStatusBar) {
            w.hidden = NO;
            w.alpha  = 1.0;
            // 再遍历子视图
            for (UIView *v in w.subviews) {
                v.hidden = NO; v.alpha = 1.0;
            }
        }
    }
}

// =========================================================================
// Section 1: 文字替换功能 (与前版相同)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text {
    if (!text) { %orig; return; }
    NSString *newString = nil;
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) {
        newString = @"Echo";
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) {
        newString = @"定制";
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) {
        newString = @"毕法";
    }
    if (newString) {
        UIFont *f = self.font; UIColor *c = self.textColor; NSTextAlignment a = self.textAlignment;
        NSMutableDictionary *attr = [@{} mutableCopy];
        if (f) attr[NSFontAttributeName] = f;
        if (c) attr[NSForegroundColorAttributeName] = c;
        NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new]; ps.alignment = a; attr[NSParagraphStyleAttributeName] = ps;
        self.attributedText = [[NSAttributedString alloc] initWithString:newString attributes:attr];
        return;
    }
    NSMutableString *simp = [text mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simp, NULL, CFSTR("Hant-Hans"), false);
    %orig(simp);
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) { %orig; return; }
    NSString *origStr = attributedText.string; NSString *newString = nil;
    if ([origStr isEqualToString:@"我的分类"] || [origStr isEqualToString:@"我的分類"] || [origStr isEqualToString:@"通類"]) newString = @"Echo";
    else if ([origStr isEqualToString:@"起課"] || [origStr isEqualToString:@"起课"]) newString = @"定制";
    else if ([origStr isEqualToString:@"法诀"] || [origStr isEqualToString:@"法訣"]) newString = @"毕法";

    NSMutableAttributedString *mut = [attributedText mutableCopy];
    if (newString) {
        [mut.mutableString setString:newString]; %orig(mut); return;
    }
    CFStringTransform((__bridge CFMutableStringRef)mut.mutableString, NULL, CFSTR("Hant-Hans"), false);
    %orig(mut);
}
%end

// =========================================================================
// Section 2: 水印功能 (略同 v1.1，省略无关改动)
// =========================================================================
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) {
    UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, tileSize.width/2, tileSize.height/2); CGContextRotateCTM(ctx, angle*M_PI/180);
    [text drawInRect:(CGRect){-tileSize.width/2,-tileSize.height/2,tileSize} withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:textColor}];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return img;
}

%hook UIWindow
- (void)layoutSubviews {
    %orig;
    if (self.windowLevel == UIWindowLevelNormal) {
        const NSInteger kTag = 998877;
        if ([self viewWithTag:kTag]) return;
        UIImage *pattern = createWatermarkImage(@"Echo定制", [UIFont systemFontOfSize:16], [[UIColor blackColor] colorWithAlphaComponent:0.08], (CGSize){150,100}, -30);
        UIView *v = [[UIView alloc] initWithFrame:CGRectZero]; v.tag=kTag; v.backgroundColor=[UIColor colorWithPatternImage:pattern]; v.userInteractionEnabled=NO; v.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        CGRect f=self.bounds; CGFloat inset = 0; if(@available(iOS 11,*)) inset=self.safeAreaInsets.top; else inset=UIApplication.sharedApplication.statusBarFrame.size.height; f.origin.y+=inset; f.size.height-=inset; v.frame=f; [self addSubview:v];
    }
}
%end

// =========================================================================
// Section 3: 状态栏彻底修复
// =========================================================================

// 3.1 动态篡改 Info.plist
%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSMutableDictionary *dict = (%orig).mutableCopy; dict[@"UIViewControllerBasedStatusBarAppearance"] = @NO; return dict;
}
%end

// 3.2 Scene 级别强制
%hook UIStatusBarManager
- (BOOL)isStatusBarHidden { return NO; }
%end

// 3.3 UIApplication 旧接口兜底
%hook UIApplication
- (void)setStatusBarHidden:(BOOL)hidden withAnimation:(UIStatusBarAnimation)animation { %orig(NO, animation); ForceShowStatusBarViews(); }
- (void)setStatusBarHidden:(BOOL)hidden { %orig(NO); ForceShowStatusBarViews(); }
%end

// 3.4 UIViewController 默认实现
%hook UIViewController
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIViewController *)childViewControllerForStatusBarHidden { return nil; }
%end

// 3.5 捕捉 UIStatusBar & UIStatusBar_Modern 自身隐藏/透明
%hook UIStatusBar
- (void)setHidden:(BOOL)hidden { %orig(NO); }
- (void)setAlpha:(CGFloat)alpha { %orig(1.0); }
%end

%hook UIStatusBar_Modern
- (void)setHidden:(BOOL)hidden { %orig(NO); }
- (void)setAlpha:(CGFloat)alpha { %orig(1.0); }
%end

// 3.6 全 VC 覆盖 prefersStatusBarHidden
static BOOL (*orig_prefersStatusBarHidden)(id, SEL);
static BOOL my_prefersStatusBarHidden(id self, SEL _cmd) { return NO; }

%ctor {
    %init;

    // 延迟 0.3s 强刷一次，确保初启动可见
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ ForceShowStatusBarViews(); });

    // Hook 所有 UIViewController 子类
    unsigned int n=0; Class *classes=objc_copyClassList(&n); Class superCls=objc_getClass("UIViewController");
    for(unsigned int i=0;i<n;i++){ if(class_getSuperclass(classes[i])==superCls){ MSHookMessageEx(classes[i],@selector(prefersStatusBarHidden),(IMP)my_prefersStatusBarHidden,(IMP*)&orig_prefersStatusBarHidden);} }
    free(classes);
}

#pragma clang diagnostic pop
