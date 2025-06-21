#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1 & 2: 您的原始代码 (UILabel, UIWindow)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedTsext); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end

// =========================================================================
// Section 3: 【新功能】一键复制到 AI (最终完美版 Pro)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTextFromTableViewClassName:(NSString *)className;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    // 按钮会出现在所有继承自UIViewController的页面，包括列表页和主页
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { 
            // 如果按钮已存在，则将其提到最前，防止被新页面覆盖
            UIView *button = [keyWindow viewWithTag:CopyAiButtonTag];
            if (button) {
                [keyWindow bringSubviewToFront:button];
            }
            return; 
        }
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

// 原始提取函数，用于固定布局
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) return @"";
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

// 新增：专门用于提取列表视图内容的函数
%new
- (NSString *)extractTextFromTableViewClassName:(NSString *)className {
    Class targetClass = NSClassFromString(className);
    if (!targetClass) return nil; // 返回nil表示未找到

    NSMutableArray *tableViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetClass inView:self.view andStoreIn:tableViews];
    if (tableViews.count == 0) return nil;

    UITableView *tableView = tableViews.firstObject;
    if (![tableView isKindOfClass:[UITableView class]]) return nil;

    NSMutableArray *allCellsText = [NSMutableArray array];
    for (UITableViewCell *cell in tableView.visibleCells) {
        NSMutableArray *labelsInCell = [NSMutableArray array];
        [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labelsInCell];
        // 按从左到右排序
        [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
            return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
        }];
        NSMutableArray *lineParts = [NSMutableArray array];
        for (UILabel *label in labelsInCell) {
            if (label.text && label.text.length > 0) {
                [lineParts addObject:label.text];
            }
        }
        if (lineParts.count > 0) {
            [allCellsText addObject:[lineParts componentsJoinedByString:@" "]];
        }
    }
    return [allCellsText componentsJoinedByString:@"\n"];
}


// 【最终完美版 Pro】
%new
- (void)copyAiButtonTapped_FinalPerfect {
    #define SafeString(str) (str ?: @"")
    
    NSString *finalText = nil;
    NSString *alertTitle = @"已复制到剪贴板";

    // --- 核心逻辑重构：根据当前界面执行不同操作 ---

    // 1. 检查是否为“七政信息”列表页
    NSString *qizhengListContent = [self extractTextFromTableViewClassName:@"六壬大占.七政信息視圖"];
    if (qizhengListContent && qizhengListContent.length > 0) {
        finalText = qizhengListContent;
    }
    
    // 2. 如果不是七政页，再检查是否为“毕法”列表页
    if (!finalText) {
        NSString *bifaListContent = [self extractTextFromTableViewClassName:@"六壬大占.IntrinsicTableView"];
        if (bifaListContent && bifaListContent.length > 0) {
            finalText = bifaListContent;
        }
    }

    // 3. 如果都不是，则执行原始主界面提取逻辑
    if (!finalText) {
        // --- 3.1. 结构化提取所有信息 ---
        NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
        NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
        NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
        NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
        NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
        NSString *biFa = [self extractTextFromFirstViewOfClassName:@"六壬大占.格局單元" separator:@" "]; // 这个仍然保留，以防万一
        NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
        
        // --- 3.2. 【四课提取逻辑 - 保持不变】---
        NSMutableString *siKe = [NSMutableString string];
        // ... (此处省略四课提取的详细代码，与上一版完全相同，已包含在下面)
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
                    for(UILabel *label in labels){ NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; } [columns[columnKey] addObject:label]; }
                    if (columns.allKeys.count == 4) {
                        NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) { return [@([obj1 floatValue]) compare:@([obj2 floatValue])]; }];
                        NSMutableArray *c1 = columns[sortedColumnKeys[0]]; NSMutableArray *c2 = columns[sortedColumnKeys[1]]; NSMutableArray *c3 = columns[sortedColumnKeys[2]]; NSMutableArray *c4 = columns[sortedColumnKeys[3]];
                        [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text), SafeString(((UILabel*)c4[1]).text), SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text), SafeString(((UILabel*)c3[1]).text), SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text), SafeString(((UILabel*)c2[1]).text), SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text), SafeString(((UILabel*)c1[1]).text), SafeString(((UILabel*)c1[0]).text)];
                    }
                }
            }
        }

        // --- 3.3. 【三传提取逻辑 - 优化版，保持不变】---
        NSMutableString *sanChuan = [NSMutableString string];
        // ... (此处省略三传提取的详细代码，与上一版完全相同，已包含在下面)
        Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
        if (sanChuanViewClass) {
            NSMutableArray *sanChuanViews = [NSMutableArray array];
            [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews];
            [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *obj1, UIView *obj2) { return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)]; }];
            NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"];
            NSMutableArray *sanChuanLines = [NSMutableArray array];
            for (int i = 0; i < sanChuanViews.count; i++) {
                UIView *view = sanChuanViews[i]; NSMutableArray *labelsInView = [NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView]; [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) { return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)]; }];
                if (labelsInView.count >= 3) {
                    NSString *liuQin = ((UILabel *)labelsInView.firstObject).text; NSString *tianJiang = ((UILabel *)labelsInView.lastObject).text; NSString *diZhi = ((UILabel *)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                    NSMutableArray *shenShaParts = [NSMutableArray array];
                    if (labelsInView.count > 3) { NSRange shenShaRange = NSMakeRange(1, labelsInView.count - 3); NSArray *shenShaLabels = [labelsInView subarrayWithRange:shenShaRange]; for (UILabel *label in shenShaLabels) { if (label.text && label.text.length > 0) { [shenShaParts addObject:label.text]; } } }
                    NSString *shenShaString = [shenShaParts componentsJoinedByString:@" "];
                    NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(liuQin), SafeString(diZhi), SafeString(tianJiang)]; if (shenShaString.length > 0) { [formattedLine appendFormat:@" (%@)", shenShaString]; }
                    NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @""; [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, formattedLine]];
                } else {
                    NSMutableArray *lineParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if(label.text) [lineParts addObject:label.text]; } NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @""; [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, [lineParts componentsJoinedByString:@" "]]];
                }
            }
            sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
        }
        
        // --- 3.4. 组合主界面最终文本 ---
        finalText = [NSString stringWithFormat:
            @"%@\n\n"
            @"月将: %@\n"
            @"空亡: %@\n"
            @"三宫时: %@\n"
            @"昼夜: %@\n"
            @"课体: %@\n"
            @"毕法: %@\n\n"
            @"%@\n\n"
            @"%@\n\n"
            @"起课方式: %@",
            SafeString(timeBlock),
            SafeString(yueJiang), SafeString(kongWang), SafeString(sanGongShi), SafeString(zhouYe), SafeString(fullKeti), SafeString(biFa),
            SafeString(siKe),
            SafeString(sanChuan),
            SafeString(methodName)
        ];
    }
    
    // --- 最终步骤：复制到剪贴板并显示弹窗 ---
    if (finalText && finalText.length > 0) {
        [UIPasteboard generalPasteboard].string = finalText;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:alertTitle message:finalText preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        // 如果因为某些原因什么都没提取到，给个提示
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取失败" message:@"未能在此页面找到可复制的内容。" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

%end
