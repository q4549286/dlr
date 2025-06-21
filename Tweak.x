#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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
// Section 3: 【新功能】一键复制到 AI (最终完美版)
// =========================================================================

#define LOG_PREFIX @"[CopyAI_DEBUG]"

static NSInteger const CopyAiButtonTag = 112233;
static NSString *g_bifaText = nil;     // 全局变量，用于存储毕法信息
static NSString *g_qizhengText = nil; // 全局变量，用于存储七政信息

// 递归查找所有UILabel
static void findAllLabelsInView(UIView *view, NSMutableArray *labels) {
    if ([view isKindOfClass:[UILabel class]]) {
        [labels addObject:(UILabel *)view];
    }
    for (UIView *subview in view.subviews) {
        findAllLabelsInView(subview, labels);
    }
}

// 提取当前最顶层视图控制器中的所有文本
static NSString *extractAllTextFromTopViewController(NSString *caller) {
    // 强制UI在主线程更新，确保我们能拿到最新的视图层级
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];

    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *topController = keyWindow.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    
    NSMutableArray *allLabels = [NSMutableArray array];
    findAllLabelsInView(topController.view, allLabels);
    
    // 按从上到下，从左到右排序
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        // 使用中心点Y坐标进行比较，更稳定
        CGFloat y1 = CGRectGetMidY(obj1.frame);
        CGFloat y2 = CGRectGetMidY(obj2.frame);
        if (fabs(y1 - y2) > 1.0) { // 如果Y坐标差异明显
             return y1 < y2 ? NSOrderedAscending : NSOrderedDescending;
        }
        // Y坐标相近时，按X坐标排序
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];
    
    NSMutableString *fullText = [NSMutableString string];
    for (UILabel *label in allLabels) {
        // 过滤掉一些通用标题和空文本
        if (label.text && ![label.text isEqualToString:@"毕法"] && ![label.text isEqualToString:@"完成"] && ![label.text isEqualToString:@"返回"]) {
             [fullText appendFormat:@"%@\n", label.text];
        }
    }
    NSString *result = [fullText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSLog(@"%@ Called from [%@], Extracted Text: \n---\n%@\n---", LOG_PREFIX, caller, result);
    return result;
}

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (void)顯示法訣總覽;
- (void)顯示七政信息WithSender:(id)sender;
@end

%hook 六壬大占_ViewController

// 埋伏点1：钩住显示法诀的方法
- (void)顯示法訣總覽 {
    NSLog(@"%@ Hooking 顯示法訣總覽...", LOG_PREFIX);
    %orig; // 先让它执行原始逻辑，把视图和数据加载到内存
    g_bifaText = extractAllTextFromTopViewController(@"顯示法訣總覽");
}

// 埋伏点2：钩住显示七政的方法
- (void)顯示七政信息WithSender:(id)sender {
    NSLog(@"%@ Hooking 顯示七政信息WithSender:...", LOG_PREFIX);
    %orig; // 同上，先执行原始逻辑
    g_qizhengText = extractAllTextFromTopViewController(@"顯示七政信息WithSender");
}

- (void)viewDidLoad {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
        NSLog(@"%@ Adding CopyAI button to window.", LOG_PREFIX);
        UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
        copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
        copyButton.tag = CopyAiButtonTag;
        [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
        copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
        [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        copyButton.layer.cornerRadius = 8;
        [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:copyButton];
    });
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
        NSLog(@"%@ ERROR: Class not found: %@", LOG_PREFIX, className);
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
    NSString *result = [textParts componentsJoinedByString:separator];
    NSLog(@"%@ Extracted from %@: %@", LOG_PREFIX, className, result);
    return result;
}

// 【最终完美版】
%new
- (void)copyAiButtonTapped_FinalPerfect {
    NSLog(@"%@ copyAiButtonTapped_FinalPerfect triggered!", LOG_PREFIX);
    #define SafeString(str) (str ?: @"")

    // --- 0. 触发隐藏信息计算 ---
    NSLog(@"%@ Silently calling internal methods...", LOG_PREFIX);
    [self 顯示法訣總覽];
    [self 顯示七政信息WithSender:nil];

    // --- 1. 结构化提取主界面信息 ---
    NSLog(@"%@ Extracting main screen info...", LOG_PREFIX);
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    // --- 2. 四课提取 ---
    NSMutableString *siKe = [NSMutableString string];
    // ... 四课提取逻辑 ...
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array]; [self findSubviewsOfClass:siKeViewClass inView:self.view andStoreIn:siKeViews];
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject; NSMutableArray* labels = [NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:container andStoreIn:labels];
            if(labels.count >= 12){
                NSMutableDictionary *columns = [NSMutableDictionary dictionary];
                for(UILabel *label in labels){ NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; } [columns[columnKey] addObject:label]; }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) { return [@([obj1 floatValue]) compare:@([obj2 floatValue])]; }];
                    NSMutableArray *c1 = columns[sortedColumnKeys[0]]; NSMutableArray *c2 = columns[sortedColumnKeys[1]]; NSMutableArray *c3 = columns[sortedColumnKeys[2]]; NSMutableArray *c4 = columns[sortedColumnKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }]; [c2 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }]; [c3 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }]; [c4 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    siKe = [NSMutableString stringWithFormat: @"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text), SafeString(((UILabel*)c4[1]).text), SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text), SafeString(((UILabel*)c3[1]).text), SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text), SafeString(((UILabel*)c2[1]).text), SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text), SafeString(((UILabel*)c1[1]).text), SafeString(((UILabel*)c1[0]).text)];
                }
            }
        }
    }

    // --- 3. 三传提取 ---
    NSMutableString *sanChuan = [NSMutableString string];
    // ... 三传提取逻辑 ...
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array]; [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews]; [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i = 0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i]; NSMutableArray *labelsInView = [NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView]; [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)]; }];
            if (labelsInView.count >= 3) {
                NSString *liuQin = ((UILabel *)labelsInView.firstObject).text; NSString *tianJiang = ((UILabel *)labelsInView.lastObject).text; NSString *diZhi = ((UILabel *)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                NSMutableArray *shenShaParts = [NSMutableArray array];
                if (labelsInView.count > 3) { NSRange r = NSMakeRange(1, labelsInView.count - 3); for (UILabel *l in [labelsInView subarrayWithRange:r]) { if (l.text && l.text.length > 0) { [shenShaParts addObject:l.text]; } } }
                NSString *shenShaString = [shenShaParts componentsJoinedByString:@" "];
                NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(liuQin), SafeString(diZhi), SafeString(tianJiang)];
                if (shenShaString.length > 0) { [formattedLine appendFormat:@" (%@)", shenShaString]; }
                NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @""; [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, formattedLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    
    // --- 4. 组合最终文本 ---
    NSLog(@"%@ Assembling final text...", LOG_PREFIX);
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
    
    // 清理全局变量
    g_bifaText = nil;
    g_qizhengText = nil;

    NSLog(@"%@ Final text ready for clipboard:\n---\n%@\n---", LOG_PREFIX, finalText);
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
