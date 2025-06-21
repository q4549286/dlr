#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow)
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

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
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
    if (!targetViewClass) return @""; // 如果找不到类，返回空
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    if (targetViews.count == 0) return @""; // 如果找不到视图，返回空
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView andStoreIn:labelsInView];
    
    // 按从上到下，从左到右的顺序排序标签
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];
    
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) {
        if (label.text && label.text.length > 0) {
            [textParts addObject:label.text];
        }
    }
    // 如果是“格局单元”，则过滤掉“毕法”二字
    if ([className isEqualToString:@"六壬大占.格局单元"]){
         [textParts removeObject:@"毕法"];
    }

    return [textParts componentsJoinedByString:separator];
}

// 【最终完美版 - 20231003】
%new
- (void)copyAiButtonTapped_FinalPerfect {
    #define SafeString(str) (str ?: @"")

    // --- 1. 提取所有可见信息 (使用原有方法) ---
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    // --- 2. 提取隐藏信息 (根据您的最终发现) ---
    // 【提取毕法】 从法诀视图提取，并用换行符连接
    NSString *biFaList = [self extractTextFromFirstViewOfClassName:@"六壬大占.法訣視圖" separator:@"\n"];
    NSString *formattedBiFa = biFaList.length > 0 ? [NSString stringWithFormat:@"毕法:\n%@", biFaList] : @"";

    // 【提取格局】 从格局视图提取，用空格连接
    NSString *geJuList = [self extractTextFromFirstViewOfClassName:@"六壬大占.格局視圖" separator:@" "];
    NSString *formattedGeJu = geJuList.length > 0 ? [NSString stringWithFormat:@"格局: %@", geJuList] : @"";
    
    // --- 3. 【四课提取逻辑 - 保持不变】---
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
                    NSString* ke1_shen = ((UILabel*)column4[0]).text; NSString* ke1_tian = ((UILabel*)column4[1]).text; NSString* ke1_di = ((UILabel*)column4[2]).text;
                    NSString* ke2_shen = ((UILabel*)column3[0]).text; NSString* ke2_tian = ((UILabel*)column3[1]).text; NSString* ke2_di = ((UILabel*)column3[2]).text;
                    NSString* ke3_shen = ((UILabel*)column2[0]).text; NSString* ke3_tian = ((UILabel*)column2[1]).text; NSString* ke3_di = ((UILabel*)column2[2]).text;
                    NSString* ke4_shen = ((UILabel*)column1[0]).text; NSString* ke4_tian = ((UILabel*)column1[1]).text; NSString* ke4_di = ((UILabel*)column1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(ke1_di), SafeString(ke1_tian), SafeString(ke1_shen), SafeString(ke2_di), SafeString(ke2_tian), SafeString(ke2_shen), SafeString(ke3_di), SafeString(ke3_tian), SafeString(ke3_shen), SafeString(ke4_di), SafeString(ke4_tian), SafeString(ke4_shen)];
                }
            }
        }
    }
    
    // --- 4. 【三传提取逻辑 - 优化版，保持不变】---
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
                NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(liuQin), SafeString(diZhi), SafeString(tianJiang)];
                if (shenShaString.length > 0) { [formattedLine appendFormat:@" (%@)", shenShaString]; }
                NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @"";
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, formattedLine]];
            } else {
                NSMutableArray *lineParts = [NSMutableArray array];
                for (UILabel *label in labelsInView) { if(label.text) [lineParts addObject:label.text]; }
                NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @"";
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, [lineParts componentsJoinedByString:@" "]]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    
    // --- 5. 组合最终文本 (全新排版) ---
    NSMutableArray *finalParts = [NSMutableArray array];
    if (timeBlock.length > 0) [finalParts addObject:timeBlock];
    
    NSMutableString *basicInfo = [NSMutableString string];
    if (yueJiang.length > 0) [basicInfo appendFormat:@"月将: %@\n", yueJiang];
    if (kongWang.length > 0) [basicInfo appendFormat:@"空亡: %@\n", kongWang];
    if (sanGongShi.length > 0) [basicInfo appendFormat:@"三宫时: %@\n", sanGongShi];
    if (zhouYe.length > 0) [basicInfo appendFormat:@"昼夜: %@\n", zhouYe];
    if (fullKeti.length > 0) [basicInfo appendFormat:@"课体: %@\n", fullKeti];
    if (formattedGeJu.length > 0) [basicInfo appendFormat:@"%@\n", formattedGeJu];
    if (formattedBiFa.length > 0) [basicInfo appendFormat:@"%@\n", formattedBiFa];
    if (basicInfo.length > 0) [finalParts addObject:[basicInfo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    
    if (siKe.length > 0) [finalParts addObject:siKe];
    if (sanChuan.length > 0) [finalParts addObject:sanChuan];
    if (methodName.length > 0) [finalParts addObject:[NSString stringWithFormat:@"起课方式: %@", methodName]];
    
    NSString *finalText = [finalParts componentsJoinedByString:@"\n\n"];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

%end
