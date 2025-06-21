#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
// Section 3: 【最终修复版】一键复制到 AI (修复汇总弹窗不显示问题)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
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

// 【关键修复】采用更标准的 hook 结构，确保只拦截目标弹窗，放行汇总弹窗
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 检查是否是我们需要无感抓取的目标
    if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        // 是目标，强制无感操作
        flag = NO;
        viewControllerToPresent.view.alpha = 0.0f;
        EchoLog(@"无感模式启动，目标弹窗 %@ 已设为透明且无动画。", viewControllerToPresent.title);
        
        // 安排抓取和关闭任务
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:viewControllerToPresent.view andStoreIn:labels];
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];
            NSMutableArray *textParts = [NSMutableArray array];
            NSString *title = viewControllerToPresent.title ?: @"";
            if(title.length == 0 && labels.count > 0) { title = ((UILabel*)labels.firstObject).text; }
            for (UILabel *label in labels) {
                if (label.text && label.text.length > 0 && ![label.text isEqualToString:title] && ![label.text isEqualToString:@"毕法"] && ![label.text isEqualToString:@"格局"]) {
                    [textParts addObject:label.text];
                }
            }
            NSString *content = [textParts componentsJoinedByString:@"\n"];

            if ([title containsString:@"日宿"]) {
                g_extractedData[@"七政四余"] = content;
                EchoLog(@"成功抓取 [七政四余] 内容 (源: 日宿弹窗)");
            } else if ([title containsString:@"格局"]) {
                g_extractedData[@"格局"] = content;
                EchoLog(@"成功抓取 [格局] 内容");
            } else if ([title containsString:@"法诀"] || [title containsString:@"毕法"]) {
                g_extractedData[@"毕法"] = content;
                EchoLog(@"成功抓取 [毕法] 内容");
            } else {
                 EchoLog(@"抓取到未知弹窗，标题: %@，内容被忽略。", title);
            }
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
    }
    
    // 统一调用原始方法。对于目标弹窗，flag已被修改为NO；对于其他弹窗（如汇总框），flag保持原样。
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { EchoLog(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView andStoreIn:labelsInView];
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
        _Pragma("clang diagnostic push") \
        _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
        code; \
        _Pragma("clang diagnostic pop")
    
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];

    // 提取静态信息
    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"起课方式"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    EchoLog(@"主界面信息提取完毕。");
    // 四课和三传提取逻辑保持不变
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步无感抓取动态信息...");
        
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
        SEL selectorQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:");

        if ([self respondsToSelector:selectorBiFa]) {
            EchoLog(@"正在调用 '顯示法訣總覽'...");
            dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorBiFa withObject:nil]); });
            [NSThread sleepForTimeInterval:0.3];
        }
        if ([self respondsToSelector:selectorGeJu]) {
            EchoLog(@"正在调用 '顯示格局總覽'...");
            dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorGeJu withObject:nil]); });
            [NSThread sleepForTimeInterval:0.3];
        }
        if ([self respondsToSelector:selectorQiZheng]) {
            EchoLog(@"正在调用 '顯示七政信息WithSender:'...");
            dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorQiZheng withObject:nil]); });
            [NSThread sleepForTimeInterval:0.3];
        } else {
            EchoLog(@"错误: 未能在ViewController上找到 '顯示七政信息WithSender:' 方法!");
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", g_extractedData[@"毕法"]] : @"";
            NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", g_extractedData[@"格局"]] : @"";
            NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n\n%@%@%@%@\n\n%@\n\n起课方式: %@",
                SafeString(g_extractedData[@"时间块"]), SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
                biFaOutput, geJuOutput, qiZhengOutput,
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
