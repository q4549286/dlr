#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h> // 为CALayer坐标转换引入

// =========================================================================
// 日志宏定义
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI] " format), ##__VA_ARGS__)

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow) - 已修复编译错误
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
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
    watermarkView.tag = watermarkTag; // <-- 修正编译错误
    watermarkView.userInteractionEnabled = NO; 
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; 
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; 
    [self addSubview:watermarkView]; 
    [self bringSubviewToFront:watermarkView]; 
}
%end
// =========================================================================
// Section 3: 【最终版】一键复制到 AI (已整合天地盘 V18 逻辑 + 年命提取)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;

// =========================================================================
// 【新功能】为年命提取增加新的状态标记
// =========================================================================
typedef NS_ENUM(NSInteger, EchoPopupType) {
    EchoPopupTypeNone,
    EchoPopupTypeBiFa,
    EchoPopupTypeGeJu,
    EchoPopupTypeFangFa,
    EchoPopupTypeQiZheng,
    EchoPopupTypeNianMingActionSheet, // 点击年命按钮后弹出的第一个窗口
    EchoPopupTypeNianMingDetailView    // 点击“年命摘要”后弹出的最终内容窗口
};
static EchoPopupType g_currentPopupType = EchoPopupTypeNone;
// 用于存储待处理的年命按钮
static NSMutableArray *g_nianMingButtonsToProcess = nil;
// 用于存储最终拼接文本的回调
static void (^g_finalCompletionBlock)(void) = nil;


// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    }
    free(ivars);
    return value;
}
static NSString* GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}

// 【新功能】触发下一个年命按钮的处理流程
static void processNextNianMingButton(void) {
    if (!g_nianMingButtonsToProcess || g_nianMingButtonsToProcess.count == 0) {
        EchoLog(@"[年命流程] 所有年命按钮处理完毕，执行最终拼接。");
        if (g_finalCompletionBlock) {
            dispatch_async(dispatch_get_main_queue(), g_finalCompletionBlock);
            g_finalCompletionBlock = nil; // 清理
        }
        return;
    }
    
    UIView *button = [g_nianMingButtonsToProcess firstObject];
    [g_nianMingButtonsToProcess removeObjectAtIndex:0];
    
    EchoLog(@"[年命流程] 正在处理下一个年命按钮...");
    g_currentPopupType = EchoPopupTypeNianMingActionSheet;
    
    // 【编译修复】使用更稳定和兼容ARC的模拟点击方式
    BOOL didTap = NO;
    for (UIGestureRecognizer *recognizer in button.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            EchoLog(@"[年命流程] 找到Tap Gesture, 正在模拟点击...");
            // 模拟手势状态变化来触发点击
            [recognizer setState:UIGestureRecognizerStateBegan];
            [recognizer setState:UIGestureRecognizerStateEnded];
            didTap = YES;
            break; // 找到一个就够了
        }
    }

    if (!didTap) {
        EchoLog(@"[年命流程] 未能找到合适的TapGesture来模拟点击，跳过此按钮。");
        processNextNianMingButton(); // 继续处理下一个
    }
}


@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
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
            [copyButton setTitle:@"提取课盘" forState:UIControlStateNormal];
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
    if (g_currentPopupType == EchoPopupTypeNianMingActionSheet && [viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        flag = NO;
        viewControllerToPresent.view.alpha = 0.0f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertController *actionSheet = (UIAlertController *)viewControllerToPresent;
            for (UIAlertAction *action in actionSheet.actions) {
                if ([action.title isEqualToString:@"年命摘要"]) {
                    EchoLog(@"[年命流程] 找到了'年命摘要'按钮，准备点击。");
                    g_currentPopupType = EchoPopupTypeNianMingDetailView;
                    void (^handler)(UIAlertAction *) = [action valueForKey:@"handler"];
                    if (handler) {
                        handler(action);
                    } else { 
                        [actionSheet dismissViewControllerAnimated:NO completion:^{ processNextNianMingButton(); }];
                    }
                    return;
                }
            }
            [actionSheet dismissViewControllerAnimated:NO completion:^{ processNextNianMingButton(); }];
        });
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    if (g_currentPopupType == EchoPopupTypeNianMingDetailView && [NSStringFromClass([viewControllerToPresent class]) isEqualToString:@"六壬大占.年命摘要視圖"]) {
        flag = NO;
        viewControllerToPresent.view.alpha = 0.0f;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableArray *textParts = [NSMutableArray array];
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
            [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
            
            for (UILabel *label in allLabels) {
                if (label.text.length > 0) { [textParts addObject:label.text]; }
            }
            
            if (!g_extractedData[@"年命"]) { g_extractedData[@"年命"] = [NSMutableArray array]; }
            [g_extractedData[@"年命"] addObject:[textParts componentsJoinedByString:@"\n"]];
            EchoLog(@"[年命流程] 成功提取一个年命摘要内容。");

            [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                processNextNianMingButton();
            }];
        });
        %orig(viewControllerToPresent, flag, completion);
        return;
    }

    if (g_extractedData && (g_currentPopupType == EchoPopupTypeBiFa || g_currentPopupType == EchoPopupTypeGeJu || g_currentPopupType == EchoPopupTypeFangFa || g_currentPopupType == EchoPopupTypeQiZheng)) {
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *title = @"";
            switch (g_currentPopupType) {
                case EchoPopupTypeBiFa: title = @"毕法"; break;
                case EchoPopupTypeGeJu: title = @"格局"; break;
                case EchoPopupTypeFangFa: title = @"方法"; break;
                case EchoPopupTypeQiZheng: title = @"七政"; break;
                default: break;
            }

            NSMutableArray *textParts = [NSMutableArray array];

            if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                NSMutableArray *stackViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UIStackView class], viewControllerToPresent.view, stackViews);
                [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                for (UIStackView *stackView in stackViews) {
                    NSArray *arrangedSubviews = stackView.arrangedSubviews;
                    if (arrangedSubviews.count >= 2 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                        UILabel *titleLabel = arrangedSubviews[0];
                        NSString *rawTitle = titleLabel.text ?: @"";
                        rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                        NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSMutableArray *descParts = [NSMutableArray array];
                        for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } }
                        NSString *fullDesc = [descParts componentsJoinedByString:@" "]; fullDesc = [fullDesc stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; fullDesc = [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, fullDesc]];
                    }
                }
                NSString *content = [textParts componentsJoinedByString:@"\n"];
                if ([title containsString:@"方法"]) g_extractedData[@"方法"] = content;
                else if ([title containsString:@"格局"]) g_extractedData[@"格局"] = content;
                else g_extractedData[@"毕法"] = content;
            }
            else if ([title containsString:@"七政"]) {
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
            }
            
            g_currentPopupType = EchoPopupTypeNone; 
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { EchoLog(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
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
- (NSString *)extractTianDiPanInfo_V18 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;

        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";

        NSArray *diGongLayers = [diGongDict allValues];
        NSArray *tianShenLayers = [tianShenDict allValues];
        NSArray *tianJiangLayers = [tianJiangDict allValues];
        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) return @"天地盘提取失败: 数据长度不匹配";

        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                if (![layer isKindOfClass:[CALayer class]]) continue;
                CALayer *pLayer = layer.presentationLayer ?: layer;
                CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil];
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                [allLayerInfos addObject:@{
                    @"type": type, @"text": GetStringFromLayer(layer),
                    @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy))
                }];
            }
        };
        processLayers(diGongLayers, @"diPan");
        processLayers(tianShenLayers, @"tianPan");
        processLayers(tianJiangLayers, @"tianJiang");

        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff > M_PI) diff = 2 * M_PI - diff;
                if (diff < 0.15) { [palaceGroups[groupAngle] addObject:info]; foundGroup = YES; break; }
            }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count != 3) continue;
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }];
            [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }];
        }
        
        if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整";

        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            return [@([diPanOrder indexOfObject:o1[@"diPan"]]) compare:@([diPanOrder indexOfObject:o2[@"diPan"]])];
        }];

        NSMutableString *resultText = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }
        return resultText;

    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason];
    }
}


%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];
    g_currentPopupType = EchoPopupTypeNone;

    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];
    EchoLog(@"主界面信息提取完毕。");

    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject; NSMutableArray* labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels);
            if(labels.count >= 12){
                NSMutableDictionary *columns = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; } [columns[columnKey] addObject:label]; }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=columns[sortedColumnKeys[0]],*c2=columns[sortedColumnKeys[1]],*c3=columns[sortedColumnKeys[2]],*c4=columns[sortedColumnKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString* k1s=((UILabel*)c4[0]).text,*k1t=((UILabel*)c4[1]).text,*k1d=((UILabel*)c4[2]).text; NSString* k2s=((UILabel*)c3[0]).text,*k2t=((UILabel*)c3[1]).text,*k2d=((UILabel*)c3[2]).text; NSString* k3s=((UILabel*)c2[0]).text,*k3t=((UILabel*)c2[1]).text,*k3d=((UILabel*)c2[2]).text; NSString* k4s=((UILabel*)c1[0]).text,*k4t=((UILabel*)c1[1]).text,*k4d=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_extractedData[@"四课"] = siKe;
    
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanViews);
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (NSUInteger i = 0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i]; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], view, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (labelsInView.count >= 3) {
                NSString *lq=((UILabel*)labelsInView.firstObject).text, *tj=((UILabel*)labelsInView.lastObject).text, *dz=((UILabel*)[labelsInView objectAtIndex:labelsInView.count-2]).text;
                NSMutableArray *ssParts = [NSMutableArray array]; if (labelsInView.count > 3) { for(UILabel *l in [labelsInView subarrayWithRange:NSMakeRange(1, labelsInView.count-3)]){ if(l.text && l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ssString = [ssParts componentsJoinedByString:@" "]; NSMutableString *fLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if (ssString.length > 0) { [fLine appendFormat:@" (%@)", ssString]; }
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", (i < chuanTitles.count) ? chuanTitles[i] : @"", fLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_extractedData[@"三传"] = sanChuan;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步无感抓取动态信息...");
        
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
        SEL selectorQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:");
        SEL selectorFangFa = NSSelectorFromString(@"顯示方法總覽");

        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
            code; \
            _Pragma("clang diagnostic pop")

        if ([self respondsToSelector:selectorBiFa]) { g_currentPopupType = EchoPopupTypeBiFa; dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorGeJu]) { g_currentPopupType = EchoPopupTypeGeJu; dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorFangFa]) { g_currentPopupType = EchoPopupTypeFangFa; dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        if ([self respondsToSelector:selectorQiZheng]) { g_currentPopupType = EchoPopupTypeQiZheng; dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        
        __block UIViewController *weakSelf = self;
        g_finalCompletionBlock = [^{
            dispatch_async(dispatch_get_main_queue(), ^{
                EchoLog(@"所有信息收集完毕，正在组合最终文本...");
                
                NSString *biFaOutput = [g_extractedData[@"毕法"] stringByReplacingOccurrencesOfString:@"通类门→\n" withString:@""];
                NSString *geJuOutput = [g_extractedData[@"格局"] stringByReplacingOccurrencesOfString:@"通类门→\n" withString:@""];
                NSString *fangFaOutput = [g_extractedData[@"方法"] stringByReplacingOccurrencesOfString:@"通类门→\n" withString:@""];
                
                if(biFaOutput.length > 0) biFaOutput = [NSString stringWithFormat:@"%@\n\n", biFaOutput];
                if(geJuOutput.length > 0) geJuOutput = [NSString stringWithFormat:@"%@\n\n", geJuOutput];
                if(fangFaOutput.length > 0) fangFaOutput = [NSString stringWithFormat:@"%@\n\n", fangFaOutput];

                NSString *nianMingOutput = @"";
                NSArray *nianMingArray = g_extractedData[@"年命"];
                if (nianMingArray && nianMingArray.count > 0) {
                    nianMingOutput = [NSString stringWithFormat:@"%@\n\n", [nianMingArray componentsJoinedByString:@"\n\n"]];
                }

                NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
                NSString *tianDiPanOutput = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";

                NSString *finalText = [NSString stringWithFormat:
                    @"%@\n\n"
                    @"月将: %@\n"
                    @"空亡: %@\n"
                    @"三宫时: %@\n"
                    @"昼夜: %@\n"
                    @"课体: %@\n"
                    @"九宗门: %@\n\n"
                    @"%@"
                    @"%@\n"
                    @"%@\n\n"
                    @"%@%@%@%@%@",
                    SafeString(g_extractedData[@"时间块"]), SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]), SafeString(g_extractedData[@"九宗门"]),
                    tianDiPanOutput,
                    SafeString(g_extractedData[@"四课"]),
                    SafeString(g_extractedData[@"三传"]),
                    biFaOutput, geJuOutput, fangFaOutput, nianMingOutput, qiZhengOutput
                ];
                
                finalText = [finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

                [UIPasteboard generalPasteboard].string = finalText;
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
                
                [weakSelf presentViewController:alert animated:YES completion:^{
                    g_extractedData = nil; g_currentPopupType = EchoPopupTypeNone; g_nianMingButtonsToProcess = nil; g_finalCompletionBlock = nil;
                    EchoLog(@"--- 复制任务完成 ---");
                }];
            });
        } copy];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSMutableArray *nianMingButtons = [NSMutableArray array];
            Class nianMingContainerClass = NSClassFromString(@"六壬大占.神煞行年視圖");
            if (nianMingContainerClass) {
                NSMutableArray *containerViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive(nianMingContainerClass, weakSelf.view, containerViews);
                if (containerViews.count > 0) {
                    UIView *container = containerViews.firstObject;
                    [nianMingButtons addObjectsFromArray:container.subviews];
                }
            }
            
            if (nianMingButtons.count == 0) {
                 EchoLog(@"[年命流程] 未找到年命按钮，直接执行最终拼接。");
                 processNextNianMingButton(); 
            } else {
                 g_nianMingButtonsToProcess = [nianMingButtons mutableCopy];
                 processNextNianMingButton();
            }
        });
    });
}

%end
