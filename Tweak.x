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
// Section 3: 【新功能】一键复制到 AI (链式反应方案)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;
static NSArray *g_taskQueue = nil;
static int g_currentTaskIndex = -1;
static __weak UIViewController *g_mainViewController = nil;

// 宏定义，用于安全地调用performSelector
#define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

void executeNextTask() {
    g_currentTaskIndex++;
    if (!g_mainViewController || g_currentTaskIndex >= g_taskQueue.count) {
        EchoLog(@"所有任务执行完毕，开始组合最终文本...");
        // 所有任务完成，组合并显示最终结果
        NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", g_extractedData[@"毕法"]] : @"";
        NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", g_extractedData[@"格局"]] : @"";
        NSString *qiZhengOutput = g_extractedData[@"七政"] ? [NSString stringWithFormat:@"七政:\n%@\n\n", g_extractedData[@"七政"]] : @"";
        
        #define SafeString(str) (str ?: @"")
        NSString *finalText = [NSString stringWithFormat:
            @"%@\n\n"
            @"月将: %@\n"
            @"空亡: %@\n"
            @"三宫时: %@\n"
            @"昼夜: %@\n"
            @"课体: %@\n\n"
            @"%@" // 毕法
            @"%@" // 格局
            @"%@" // 七政
            @"%@\n\n"
            @"%@\n\n"
            @"起课方式: %@",
            SafeString(g_extractedData[@"时间块"]),
            SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
            biFaOutput,
            geJuOutput,
            qiZhengOutput,
            SafeString(g_extractedData[@"四课"]),
            SafeString(g_extractedData[@"三传"]),
            SafeString(g_extractedData[@"起课方式"])
        ];
        
        [UIPasteboard generalPasteboard].string = finalText;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        [g_mainViewController presentViewController:alert animated:YES completion:^{
            g_extractedData = nil;
            g_mainViewController = nil;
            g_taskQueue = nil;
            g_currentTaskIndex = -1;
            EchoLog(@"--- 复制任务完成 ---");
        }];
        return;
    }

    // 执行当前任务
    NSDictionary *task = g_taskQueue[g_currentTaskIndex];
    NSString *selectorName = task[@"selector"];
    SEL selector = NSSelectorFromString(selectorName);
    
    if ([g_mainViewController respondsToSelector:selector]) {
        EchoLog(@"执行任务 %d: 调用 '%@'", g_currentTaskIndex + 1, selectorName);
        dispatch_async(dispatch_get_main_queue(), ^{
            SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([g_mainViewController performSelector:selector withObject:nil]);
        });
    } else {
        EchoLog(@"错误: 未找到方法 '%@', 跳过此任务。", selectorName);
        executeNextTask(); // 直接执行下一个任务
    }
}


@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_ChainReaction;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_mainViewController = self;
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_ChainReaction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 只有在执行我们的任务队列时才进行抓取
    if (g_taskQueue && g_currentTaskIndex < g_taskQueue.count) {
        EchoLog(@"弹窗事件被触发，准备抓取内容...");
        // 确保视图加载完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             // 提取数据
            NSDictionary *currentTask = g_taskQueue[g_currentTaskIndex];
            NSString *dataKey = currentTask[@"key"];
            
            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:viewControllerToPresent.view andStoreIn:labels];
            
            [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
                if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
                return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
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
            g_extractedData[dataKey] = content;
            EchoLog(@"成功抓取 [%@] 内容", dataKey);
        });
    }
    %orig(viewControllerToPresent, flag, completion);
}

// Hook弹窗关闭事件，以触发下一个任务
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
     if (g_taskQueue && g_currentTaskIndex < g_taskQueue.count) {
        EchoLog(@"弹窗关闭事件被触发，执行下一个任务...");
        %orig(flag, ^{
            executeNextTask();
            if (completion) completion();
        });
     } else {
        %orig(flag, completion);
     }
}


%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) {
        EchoLog(@"类名 '%@' 未找到。", className);
        return @"";
    }
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView andStoreIn:labelsInView];
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (void)copyAiButtonTapped_ChainReaction {
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];
    g_mainViewController = self;
    
    // --- 1. 提取所有静态信息 ---
    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"起课方式"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    // 四课和三传也属于静态信息
    // (四课代码)
    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array];
        [self findSubviewsOfClass:siKeViewClass inView:self.view andStoreIn:siKeViews];
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject;
            NSMutableArray* labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:container andStoreIn:labels];
            if(labels.count >= 12){
                NSMutableDictionary *columns = [NSMutableDictionary dictionary];
                for(UILabel *label in labels){
                    NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                    if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; }
                    [columns[columnKey] addObject:label];
                }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) {
                        return [@([obj1 floatValue]) compare:@([obj2 floatValue])];
                    }];
                    NSMutableArray *column1 = columns[sortedColumnKeys[0]];
                    NSMutableArray *column2 = columns[sortedColumnKeys[1]];
                    NSMutableArray *column3 = columns[sortedColumnKeys[2]];
                    NSMutableArray *column4 = columns[sortedColumnKeys[3]];
                    [column1 sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
                    [column2 sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
                    [column3 sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
                    [column4 sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
                    NSString* ke1_shen = ((UILabel*)column4[0]).text;
                    NSString* ke1_tian = ((UILabel*)column4[1]).text;
                    NSString* ke1_di = ((UILabel*)column4[2]).text;
                    NSString* ke2_shen = ((UILabel*)column3[0]).text;
                    NSString* ke2_tian = ((UILabel*)column3[1]).text;
                    NSString* ke2_di = ((UILabel*)column3[2]).text;
                    NSString* ke3_shen = ((UILabel*)column2[0]).text;
                    NSString* ke3_tian = ((UILabel*)column2[1]).text;
                    NSString* ke3_di = ((UILabel*)column2[2]).text;
                    NSString* ke4_shen = ((UILabel*)column1[0]).text;
                    NSString* ke4_tian = ((UILabel*)column1[1]).text;
                    NSString* ke4_di = ((UILabel*)column1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", ke1_di, ke1_tian, ke1_shen, ke2_di, ke2_tian, ke2_shen, ke3_di, ke3_tian, ke3_shen, ke4_di, ke4_tian, ke4_shen];
                }
            }
        }
    }
    g_extractedData[@"四课"] = siKe;
    // (三传代码)
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews];
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"];
        NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i = 0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i];
            NSMutableArray *labelsInView = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView];
            [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)]; }];
            if (labelsInView.count >= 3) {
                NSString *liuQin = ((UILabel *)labelsInView.firstObject).text;
                NSString *tianJiang = ((UILabel *)labelsInView.lastObject).text;
                NSString *diZhi = ((UILabel *)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                NSMutableArray *shenShaParts = [NSMutableArray array];
                if (labelsInView.count > 3) {
                    NSRange shenShaRange = NSMakeRange(1, labelsInView.count - 3);
                    NSArray *shenShaLabels = [labelsInView subarrayWithRange:shenShaRange];
                    for (UILabel *label in shenShaLabels) { if (label.text && label.text.length > 0) { [shenShaParts addObject:label.text]; } }
                }
                NSString *shenShaString = [shenShaParts componentsJoinedByString:@" "];
                NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", liuQin, diZhi, tianJiang];
                if (shenShaString.length > 0) { [formattedLine appendFormat:@" (%@)", shenShaString]; }
                NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @"";
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, formattedLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_extractedData[@"三传"] = sanChuan;
    EchoLog(@"主界面信息提取完毕。");

    // --- 2. 定义动态任务队列 ---
    g_taskQueue = @[
        @{@"key": @"毕法", @"selector": @"顯示法訣總覽"},
        @{@"key": @"格局", @"selector": @"顯示格局總覽"},
        @{@"key": @"七政", @"selector": @"顯示七政信息:"}
    ];
    g_currentTaskIndex = -1;

    // --- 3. 启动任务队列 ---
    executeNextTask();
}

%end
