#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// 日志宏定义
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
// Section 3: 【新功能】一键复制到 AI (终极无感版)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromStaticViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTextFromInvisibleVC:(NSString *)vcClassName;
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

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (NSString *)extractTextFromStaticViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { return @""; }
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

// 【核心】无感抓取动态内容的方法
%new
- (NSString *)extractTextFromInvisibleVC:(NSString *)vcClassName {
    Class vcClass = NSClassFromString(vcClassName);
    if (!vcClass) {
        EchoLog(@"错误: 找不到视图控制器类 '%@'", vcClassName);
        return nil;
    }
    
    UIViewController *invisibleVC = [[vcClass alloc] init];
    if (!invisibleVC) {
        EchoLog(@"错误: 创建'%@'实例失败", vcClassName);
        return nil;
    }

    // 强制加载视图层级，但并不显示它
    [invisibleVC loadViewIfNeeded];
    
    NSMutableArray *labels = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:invisibleVC.view andStoreIn:labels];
    
    [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
    }];
    
    NSMutableArray *textParts = [NSMutableArray array];
    NSString *title = invisibleVC.title ?: @"";
    if (title.length == 0 && labels.count > 0) {
        title = ((UILabel*)labels.firstObject).text;
    }

    for (UILabel *label in labels) {
        if (label.text && label.text.length > 0 && ![label.text isEqualToString:title] && ![label.text isEqualToString:@"毕法"]) {
            [textParts addObject:label.text];
        }
    }
    
    return [textParts componentsJoinedByString:@"\n"];
}


%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行【无感】复制到AI任务 ---");
    
    NSMutableDictionary *data = [NSMutableDictionary dictionary];

    // --- 1. 提取主界面静态信息 ---
    EchoLog(@"[1/3] 正在提取主界面静态信息...");
    data[@"时间块"] = [[self extractTextFromStaticViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    data[@"月将"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    data[@"空亡"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    data[@"三宫时"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    data[@"昼夜"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    data[@"课体"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    data[@"起课方式"] = [self extractTextFromStaticViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    // 提取四课
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
                for(UILabel *label in labels){ NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; } [columns[columnKey] addObject:label]; }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) { return [@([obj1 floatValue]) compare:@([obj2 floatValue])]; }];
                    NSMutableArray *c1=columns[sortedColumnKeys[0]], *c2=columns[sortedColumnKeys[1]], *c3=columns[sortedColumnKeys[2]], *c4=columns[sortedColumnKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}]; [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}]; [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}]; [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}];
                    NSString* s1=((UILabel*)c4[0]).text, *t1=((UILabel*)c4[1]).text, *d1=((UILabel*)c4[2]).text;
                    NSString* s2=((UILabel*)c3[0]).text, *t2=((UILabel*)c3[1]).text, *d2=((UILabel*)c3[2]).text;
                    NSString* s3=((UILabel*)c2[0]).text, *t3=((UILabel*)c2[1]).text, *d3=((UILabel*)c2[2]).text;
                    NSString* s4=((UILabel*)c1[0]).text, *t4=((UILabel*)c1[1]).text, *d4=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(d1),SafeString(t1),SafeString(s1), SafeString(d2),SafeString(t2),SafeString(s2), SafeString(d3),SafeString(t3),SafeString(s3), SafeString(d4),SafeString(t4),SafeString(s4)];
                }
            }
        }
    }
    data[@"四课"] = siKe;

    // 提取三传
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews];
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2){return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"];
        NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i=0; i<sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i];
            NSMutableArray *labelsInView = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView];
            [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];}];
            if(labelsInView.count >= 3){
                NSString *lq=((UILabel*)labelsInView.firstObject).text, *tj=((UILabel*)labelsInView.lastObject).text, *dz=((UILabel*)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                NSMutableArray *ssParts = [NSMutableArray array];
                if(labelsInView.count > 3){
                    for(UILabel *l in [labelsInView subarrayWithRange:NSMakeRange(1, labelsInView.count - 3)]) { if(l.text.length>0) [ssParts addObject:l.text]; }
                }
                NSString *ssStr = [ssParts componentsJoinedByString:@" "];
                NSMutableString *fLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)];
                if(ssStr.length > 0) [fLine appendFormat:@" (%@)", ssStr];
                NSString *title = (i < chuanTitles.count) ? chuanTitles[i] : @"";
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", title, fLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    data[@"三传"] = sanChuan;
    EchoLog(@"主界面信息提取完毕。");
    
    // --- 2. 在后台线程中无感抓取动态信息 ---
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"[2/3] 开始在后台无感抓取动态信息...");
        
        // 抓取毕法
        data[@"毕法"] = [self extractTextFromInvisibleVC:@"六壬大占.法訣總覽視圖控制器"];
        EchoLog(@"毕法信息抓取完毕。");

        // 抓取格局
        data[@"格局"] = [self extractTextFromInvisibleVC:@"六壬大占.格局總覽視圖控制器"];
        EchoLog(@"格局信息抓取完毕。");

        // 抓取七政
        data[@"七政"] = [self extractTextFromInvisibleVC:@"六壬大占.七政信息視圖控制器"];
        EchoLog(@"七政信息抓取完毕。");

        // --- 3. 组合并显示最终结果 ---
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"[3/3] 所有信息收集完毕，正在组合最终文本...");
            
            NSString *biFaOutput = data[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", data[@"毕法"]] : @"";
            NSString *geJuOutput = data[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", data[@"格局"]] : @"";
            NSString *qiZhengOutput = data[@"七政"] ? [NSString stringWithFormat:@"七政:\n%@\n\n", data[@"七政"]] : @"";
            
            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n"
                @"月将: %@\n"
                @"空亡: %@\n"
                @"三宫时: %@\n"
                @"昼夜: %@\n"
                @"课体: %@\n\n"
                @"%@" @"%@" @"%@"
                @"%@\n\n"
                @"%@\n\n"
                @"起课方式: %@",
                SafeString(data[@"时间块"]),
                SafeString(data[@"月将"]), SafeString(data[@"空亡"]), SafeString(data[@"三宫时"]), SafeString(data[@"昼夜"]), SafeString(data[@"课体"]),
                biFaOutput, geJuOutput, qiZhengOutput,
                SafeString(data[@"四课"]),
                SafeString(data[@"三传"]),
                SafeString(data[@"起课方式"])
            ];
            
            [UIPasteboard generalPasteboard].string = finalText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:okAction];
            [self presentViewController:alert animated:YES completion:nil];
            EchoLog(@"--- 复制任务完成 ---");
        });
    });
}

%end
