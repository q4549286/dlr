#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { 
    if (!text) { 
        %orig(text); 
        return; 
    }
    NSString *newString = nil; 
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { 
        newString = @"Echo"; 
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { 
        newString = @"定制"; 
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { 
        newString = @"毕法"; 
    } 
    if (newString) { 
        %orig(newString); 
        return; 
    } 
    NSMutableString *simplifiedText = [text mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); 
    %orig(simplifiedText); 
}

- (void)setAttributedText:(NSAttributedString *)attributedText { 
    if (!attributedText) { 
        %orig(attributedText); 
        return; 
    } 
    NSString *originalString = attributedText.string; 
    NSString *newString = nil; 
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { 
        newString = @"Echo"; 
    } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { 
        newString = @"定制"; 
    } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { 
        newString = @"毕法"; 
    } 
    if (newString) { 
        NSMutableAttributedString *newAttr = [attributedText mutableCopy]; 
        [newAttr.mutableString setString:newString]; 
        %orig(newAttr); 
        return; 
    } 
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); 
    %orig(finalAttributedText); 
}
%end

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
    if (self.windowLevel != UIWindowLevelNormal) { return; } 
    NSInteger watermarkTag = 998877; 
    if ([self viewWithTag:watermarkTag]) { return; } 
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

// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终功能完整版)
// =========================================================================

#define LOG_PREFIX @"[CopyAI_DEBUG]"
static NSInteger const CopyAiButtonTag = 112233;
static NSString *g_bifaText = nil;
static NSString *g_qizhengText = nil;

// 声明所有需要的方法
@interface _UIBackdropView
@end
@interface UIViewController (CopyAi)
- (void)copyAiButtonTapped;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view storage:(NSMutableArray *)storage;
- (NSString *)extractAllTextFromTopViewControllerWithCaller:(NSString *)caller;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (void)顯示法訣總覽;
- (void)顯示七政信息WithSender:(id)sender;
@end


%hook 六壬大占_ViewController

// --- 钩子方法 ---
- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
        NSLog(@"%@ Adding CopyAI button.", LOG_PREFIX);
        UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
        copyButton.tag = CopyAiButtonTag;
        [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
        copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
        [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        copyButton.layer.cornerRadius = 8;
        [copyButton addTarget:self action:@selector(copyAiButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:copyButton];
    });
}

- (void)顯示法訣總覽 {
    NSLog(@"%@ Hooking 顯示法訣總覽...", LOG_PREFIX);
    %orig;
    g_bifaText = [self extractAllTextFromTopViewControllerWithCaller:@"顯示法訣總覽"];
}

- (void)顯示七政信息WithSender:(id)sender {
    NSLog(@"%@ Hooking 顯示七政信息WithSender:...", LOG_PREFIX);
    %orig;
    g_qizhengText = [self extractAllTextFromTopViewControllerWithCaller:@"顯示七政信息WithSender"];
}

// --- 新增的辅助方法 ---
%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view storage:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview storage:storage]; }
}

%new
- (NSString *)extractAllTextFromTopViewControllerWithCaller:(NSString *)caller {
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) { topController = topController.presentedViewController; }

    NSMutableArray *allLabels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:topController.view storage:allLabels];

    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];

    NSMutableString *fullText = [NSMutableString string];
    for (UILabel *label in allLabels) {
        if (label.text && ![label.text isEqualToString:@"毕法"] && ![label.text isEqualToString:@"完成"] && ![label.text isEqualToString:@"返回"]) {
             [fullText appendFormat:@"%@\n", label.text];
        }
    }
    NSString *result = [fullText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSLog(@"%@ Called from [%@], Extracted Text: \n---\n%@\n---", LOG_PREFIX, caller, result);
    return result;
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view storage:targetViews];
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView storage:labelsInView];
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

// --- 按钮点击的核心功能方法 ---
%new
- (void)copyAiButtonTapped {
    NSLog(@"%@ copyAiButtonTapped triggered!", LOG_PREFIX);
    #define SafeString(str) (str ?: @"")

    // 🔥 FIX: Use performSelector to call hooked methods from a %new method
    // This avoids the Logos preprocessor error.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:NSSelectorFromString(@"顯示法訣總覽")];
    [self performSelector:NSSelectorFromString(@"顯示七政信息WithSender:") withObject:nil];
#pragma clang diagnostic pop

    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];

    // 四课提取
    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *views = [NSMutableArray new]; [self findSubviewsOfClass:siKeViewClass inView:self.view storage:views];
        if(views.count > 0){
            UIView* c = views.firstObject; NSMutableArray* l = [NSMutableArray new]; [self findSubviewsOfClass:[UILabel class] inView:c storage:l];
            if(l.count >= 12){
                NSMutableDictionary *cols = [NSMutableDictionary new];
                for(UILabel *lbl in l){ NSString *k = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(lbl.frame))]; if(!cols[k]){ cols[k] = [NSMutableArray new]; } [cols[k] addObject:lbl]; }
                if (cols.allKeys.count == 4) {
                    NSArray *sKeys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=cols[sKeys[0]], *c2=cols[sKeys[1]], *c3=cols[sKeys[2]], *c4=cols[sKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    siKe = [NSMutableString stringWithFormat: @"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text), SafeString(((UILabel*)c4[1]).text), SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text), SafeString(((UILabel*)c3[1]).text), SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text), SafeString(((UILabel*)c2[1]).text), SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text), SafeString(((UILabel*)c1[1]).text), SafeString(((UILabel*)c1[0]).text)];
                }
            }
        }
    }

    // 三传提取
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *views = [NSMutableArray new]; [self findSubviewsOfClass:sanChuanViewClass inView:self.view storage:views]; [views sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray new];
        for (int i = 0; i < views.count; i++) {
            UIView *v = views[i]; NSMutableArray *labels = [NSMutableArray new]; [self findSubviewsOfClass:[UILabel class] inView:v storage:labels]; [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (labels.count >= 3) {
                NSString *lq = ((UILabel *)labels.firstObject).text; NSString *tj = ((UILabel *)labels.lastObject).text; NSString *dz = ((UILabel *)[labels objectAtIndex:labels.count - 2]).text;
                NSMutableArray *ssParts = [NSMutableArray new];
                if (labels.count > 3) { for (UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count - 3)]) { if (l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ssStr = [ssParts componentsJoinedByString:@" "];
                NSMutableString *fLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)];
                if (ssStr.length > 0) [fLine appendFormat:@" (%@)", ssStr];
                NSString *title = (i < titles.count) ? titles[i] : @""; [lines addObject:[NSString stringWithFormat:@"%@ %@", title, fLine]];
            }
        }
        sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy];
    }
    
    // 组合最终文本
    NSMutableString *finalText = [NSMutableString string];
    [finalText appendFormat:@"%@\n\n", SafeString(timeBlock)];
    if(g_qizhengText.length > 0) { [finalText appendFormat:@"七政:\n%@\n\n", SafeString(g_qizhengText)]; }
    [finalText appendFormat:@"空亡: %@\n", SafeString(kongWang)];
    [finalText appendFormat:@"三宫时: %@\n", SafeString(sanGongShi)];
    [finalText appendFormat:@"昼夜: %@\n", SafeString(zhouYe)];
    [finalText appendFormat:@"课体: %@\n\n", SafeString(fullKeti)];
    if(g_bifaText.length > 0) { [finalText appendFormat:@"毕法:\n%@\n\n", SafeString(g_bifaText)]; }
    [finalText appendFormat:@"%@\n\n", SafeString(siKe)];
    [finalText appendFormat:@"%@\n\n", SafeString(sanChuan)];
    [finalText appendFormat:@"起课方式: %@", SafeString(methodName)];
    
    g_bifaText = nil;
    g_qizhengText = nil;

    NSLog(@"%@ Final text ready for clipboard.", LOG_PREFIX);
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
