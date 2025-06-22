#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Debug] " format), ##__VA_ARGS__)

// =========================================================================
// Section 1 & 2: 原始功能 (保持最小化，确保不干扰调试)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end


// =========================================================================
// Section 3: 【调试脚本】
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiDebugAddon)
- (void)runTianDiPanDiagnostics;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)formatObjectForDebug:(id)obj;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
            copyButton.tag = CopyAiButtonTag;
            // 按钮标题改为调试模式
            [copyButton setTitle:@"开始调试" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.4 blue:0.1 alpha:1.0]; // 使用醒目的橙色
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            // 按钮事件改为执行调试方法
            [copyButton addTarget:self action:@selector(runTianDiPanDiagnostics) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// 禁用无感抓取，避免干扰
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (NSString *)formatObjectForDebug:(id)obj {
    if (!obj) {
        return @"(nil)";
    }
    if ([obj isKindOfClass:[NSArray class]] || [obj isKindOfClass:[NSDictionary class]]) {
        return [NSString stringWithFormat:@"(类型: %@)\n%@", NSStringFromClass([obj class]), obj];
    }
    return [NSString stringWithFormat:@"(类型: %@) %@", NSStringFromClass([obj class]), obj];
}

%new
- (void)runTianDiPanDiagnostics {
    EchoLog(@"--- 开始执行天地盘诊断程序 ---");
    
    NSMutableString *report = [NSMutableString stringWithString:@"--- 天地盘视图 调试报告 ---\n\n"];
    
    // 【关键修正】使用您提供的正确类名
    NSString *className = @"六壬大占.天地盘视圖類";
    Class tiandiPanViewClass = NSClassFromString(className);
    
    if (!tiandiPanViewClass) {
        [report appendFormat:@"错误：未能找到 '%@' 这个类。\n请再次用Flex确认类名是否正确无误。", className];
    } else {
        NSMutableArray *views = [NSMutableArray array];
        [self findSubviewsOfClass:tiandiPanViewClass inView:self.view andStoreIn:views];
        
        if (views.count == 0) {
            [report appendFormat:@"错误：找到了 '%@' 类，但在当前视图层级中找不到它的实例。\n", className];
        } else {
            UIView *tiandiPanView = views.firstObject;
            [report appendFormat:@"成功找到视图实例: %@\n\n", tiandiPanView.description];
            
            // --- 测试 1: 直接KVC ---
            [report appendString:@"--- [测试 1: 直接KVC] ---\n"];
            @try {
                id tianPan = [tiandiPanView valueForKey:@"天盤"];
                id diPan = [tiandiPanView valueForKey:@"地盤"];
                [report appendFormat:@"valueForKey:@\"天盤\": %@\n\n", [self formatObjectForDebug:tianPan]];
                [report appendFormat:@"valueForKey:@\"地盤\": %@\n\n", [self formatObjectForDebug:diPan]];
            } @catch (NSException *e) {
                [report appendFormat:@"直接KVC测试发生异常: %@\n", e.reason];
            }

            // --- 测试 2: 带下划线KVC ---
            [report appendString:@"--- [测试 2: 带下划线KVC] ---\n"];
            @try {
                id _tianPan = [tiandiPanView valueForKey:@"_天盤"];
                id _diPan = [tiandiPanView valueForKey:@"_地盤"];
                [report appendFormat:@"valueForKey:@\"_天盤\": %@\n\n", [self formatObjectForDebug:_tianPan]];
                [report appendFormat:@"valueForKey:@\"_地盤\": %@\n\n", [self formatObjectForDebug:_diPan]];
            } @catch (NSException *e) {
                [report appendFormat:@"带下划线KVC测试发生异常: %@\n", e.reason];
            }

            // --- 测试 3: 运行时属性列表 ---
            [report appendString:@"--- [测试 3: 运行时属性列表 (Properties)] ---\n"];
            unsigned int propCount;
            objc_property_t *properties = class_copyPropertyList(tiandiPanViewClass, &propCount);
            if (propCount == 0) {
                [report appendString:@"未发现任何属性。\n"];
            } else {
                for (unsigned int i = 0; i < propCount; i++) {
                    const char *propName_C = property_getName(properties[i]);
                    NSString *propName = [NSString stringWithUTF8String:propName_C];
                    [report appendFormat:@"- 发现属性: %@\n", propName];
                    // 尝试读取该属性的值
                    @try {
                        id propValue = [tiandiPanView valueForKey:propName];
                        [report appendFormat:@"  值为: %@\n\n", [self formatObjectForDebug:propValue]];
                    } @catch (NSException *exception) {
                        [report appendFormat:@"  读取值失败: %@\n\n", exception.reason];
                    }
                }
                free(properties);
            }

            // --- 测试 4: 运行时实例变量列表 ---
            [report appendString:@"\n--- [测试 4: 运行时实例变量列表 (Ivars)] ---\n"];
            unsigned int ivarCount;
            Ivar *ivars = class_copyIvarList(tiandiPanViewClass, &ivarCount);
            if (ivarCount == 0) {
                [report appendString:@"未发现任何实例变量。\n"];
            } else {
                for (unsigned int i = 0; i < ivarCount; i++) {
                    const char *ivarName_C = ivar_getName(ivars[i]);
                    NSString *ivarName = [NSString stringWithUTF8String:ivarName_C];
                    [report appendFormat:@"- 发现实例变量: %@\n", ivarName];
                }
                free(ivars);
            }
        }
    }
    
    // --- 显示调试报告窗口 ---
    EchoLog(@"诊断完成，生成报告:\n%@", report);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盘视图 调试报告" message:report preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"复制报告" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [UIPasteboard generalPasteboard].string = report;
        EchoLog(@"报告已复制到剪贴板。");
    }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil];
    
    [alert addAction:copyAction];
    [alert addAction:closeAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

%end
