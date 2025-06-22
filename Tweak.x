#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "substrate.h" // a.k.a. Cydia Substrate

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI] " format), ##__VA_ARGS__)

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow) - 保持不变
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
// Section 3: 【终极方案】一键复制到 AI (动态 Hook 天地盘)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;
static IMP g_original_animationDidStop = NULL; // 用于保存原始方法实现

// 这是我们将要注入的 animationDidStop:finished: 方法
static void replacement_animationDidStop(id self, SEL _cmd, id arg1, BOOL arg2) {
    if (g_extractedData && [g_extractedData[@"天地盘"] isEqualToString:@"PENDING"]) {
        EchoLog(@"Hooked animationDidStop: 成功触发！准备提取天地盘数据...");
        
        NSMutableString *result = [NSMutableString string];
        @try {
            id diGongMingLie = [self valueForKey:@"地宫名列"];
            if (diGongMingLie && [diGongMingLie isKindOfClass:[NSArray class]]) {
                [result appendFormat:@"地盘: %@\n", [diGongMingLie componentsJoinedByString:@" "]];
            }
            id tianShenGongMingLie = [self valueForKey:@"天神宫名列"];
            if (tianShenGongMingLie && [tianShenGongMingLie isKindOfClass:[NSArray class]]) {
                [result appendFormat:@"天盘神: %@\n", [tianShenGongMingLie componentsJoinedByString:@" "]];
            }
            id tianJiangGongMingLie = [self valueForKey:@"天将宫名列"];
            if (tianJiangGongMingLie && [tianJiangGongMingLie isKindOfClass:[NSArray class]]) {
                NSArray *diZhi = @[@"子",@"丑",@"寅",@"卯",@"辰",@"巳",@"午",@"未",@"申",@"酉",@"戌",@"亥"];
                if ([tianJiangGongMingLie count] == 12) {
                    NSMutableArray *tianPanParts = [NSMutableArray array];
                    for (int i=0; i<12; i++) { [tianPanParts addObject:[NSString stringWithFormat:@"%@->%@", diZhi[i], tianJiangGongMingLie[i]]]; }
                    [result appendFormat:@"天盘将: %@\n", [tianPanParts componentsJoinedByString:@", "]];
                } else {
                    [result appendFormat:@"天盘将: %@\n", [tianJiangGongMingLie componentsJoinedByString:@" "]];
                }
            }
            g_extractedData[@"天地盘"] = result;
            EchoLog(@"天地盘数据提取成功！");
        } @catch (NSException *exception) {
            EchoLog(@"提取天地盘数据时发生异常: %@", exception);
            g_extractedData[@"天地盘"] = @"天地盘提取异常";
        }
    }
    
    // 调用原始的 animationDidStop 方法
    if (g_original_animationDidStop) {
        ((void (*)(id, SEL, id, BOOL))g_original_animationDidStop)(self, _cmd, arg1, arg2);
    }
}


@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
@end

@implementation UIViewController (CopyAiAddon)
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView andStoreIn:labelsInView];
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}
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
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalMethod) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:viewControllerToPresent.view andStoreIn:labels];
            
            NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0 && labels.count > 0) {
                 [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                title = ((UILabel*)labels.firstObject).text;
            }

            NSMutableArray *fangfaViews = [NSMutableArray array];
            Class fangfaViewClass = NSClassFromString(@"六壬大占.格局單元");
            if (fangfaViewClass) { [self findSubviewsOfClass:fangfaViewClass inView:viewControllerToPresent.view andStoreIn:fangfaViews]; }

            NSString* content = nil;
            NSMutableArray *leftColumn = [NSMutableArray array];
            NSMutableArray *rightColumn = [NSMutableArray array];
            NSMutableArray *textParts = [NSMutableArray array];
            CGFloat midX = viewControllerToPresent.view.bounds.size.width / 2;

            if ([vcClassName containsString:@"七政"]) {
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for(UILabel *label in labels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
            }
            else if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"]) {
                for(UILabel *label in labels) { if (![label.text isEqualToString:title]) { if (CGRectGetMidX(label.frame) < midX) { [leftColumn addObject:label.text]; } else { [rightColumn addObject:label.text]; } } }
                for (int i=0; i < MIN(leftColumn.count, rightColumn.count); i++) { [textParts addObject:[NSString stringWithFormat:@"%@: %@", leftColumn[i], rightColumn[i]]]; }
                content = [textParts componentsJoinedByString:@"\n"];
                if ([title containsString:@"格局"]) { g_extractedData[@"格局"] = content; }
                else { g_extractedData[@"毕法"] = content; }
            }
            else if (fangfaViews.count > 0) {
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for(UILabel *label in labels) { if (CGRectGetMidX(label.frame) < midX) { [leftColumn addObject:label.text]; } else { [rightColumn addObject:label.text]; } }
                for (int i=0; i < MIN(leftColumn.count, rightColumn.count); i++) { [textParts addObject:[NSString stringWithFormat:@"%@: %@", leftColumn[i], rightColumn[i]]]; }
                g_extractedData[@"方法"] = [textParts componentsJoinedByString:@"\n"];
            }
            
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];

    // 1. 埋下天地盘的“伏笔”
    g_extractedData[@"天地盘"] = @"PENDING";
    Class panViewClass = NSClassFromString(@"六壬大占.天地盘视图类");
    SEL animationSelector = @selector(animationDidStop:finished:);
    if (panViewClass && class_getInstanceMethod(panViewClass, animationSelector)) {
        // 使用 MSHookMessageEx 动态 Hook
        MSHookMessageEx(panViewClass, animationSelector, (IMP)&replacement_animationDidStop, &g_original_animationDidStop);
        EchoLog(@"成功动态 Hook 天地盘的 animationDidStop:finished:");
    } else {
        g_extractedData[@"天地盘"] = @"天地盘Hook失败";
    }

    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"起课方式"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    // 静态四课和三传...
    // ... (代码与之前版本相同)
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步无感抓取动态信息...");
        
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
        SEL selectorQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:");
        SEL selectorFangFa = NSSelectorFromString(@"顯示方法總覽");

        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")

        if ([self respondsToSelector:selectorBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        if ([self respondsToSelector:selectorQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        
        // 轮询等待天地盘数据
        for (int i = 0; i < 20; i++) { // 最多等2秒
            if (![g_extractedData[@"天地盘"] isEqualToString:@"PENDING"]) {
                break;
            }
            [NSThread sleepForTimeInterval:0.1];
        }

        // 任务完成，取消 Hook
        if (g_original_animationDidStop) {
            MSHookMessageEx(panViewClass, animationSelector, g_original_animationDidStop, NULL);
            g_original_animationDidStop = NULL;
            EchoLog(@"成功取消 Hook 天地盘的 animationDidStop:finished:");
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            
            NSString *tianDiPanOutput = ([g_extractedData[@"天地盘"] isEqualToString:@"PENDING"] || [g_extractedData[@"天地盘"] isEqualToString:@"天地盘Hook失败"]) ? @"" : [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]];
            NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", g_extractedData[@"毕法"]] : @"";
            NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", g_extractedData[@"格局"]] : @"";
            NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *fangFaOutput = g_extractedData[@"方法"] ? [NSString stringWithFormat:@"方法:\n%@\n\n", g_extractedData[@"方法"]] : @"";

            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n"
                @"月将: %@\n"
                @"空亡: %@\n"
                @"%@" // 天地盘
                @"三宫时: %@\n"
                @"昼夜: %@\n"
                @"课体: %@\n\n"
                @"%@%@%@%@" // 毕法, 格局, 方法, 七政四余
                @"%@\n\n"
                @"%@\n\n"
                @"起课方式: %@",
                SafeString(g_extractedData[@"时间块"]),
                SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]),
                tianDiPanOutput,
                SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
                biFaOutput, geJuOutput, fangFaOutput, qiZhengOutput,
                SafeString(g_extractedData[@"四课"]),
                SafeString(g_extractedData[@"三传"]),
                SafeString(g_extractedData[@"起课方式"])
            ];
            
            [UIPasteboard generalPasteboard].string = finalText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                 g_extractedData = nil;
                 EchoLog(@"--- 复制任务完成 ---");
            }];
        });
    });
}

%end
