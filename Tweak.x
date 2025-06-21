#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1: 辅助接口与函数
// =========================================================================

// 声明我们推断的核心数据对象接口
@interface PaiPanResult : NSObject
@property (nonatomic, readonly) NSArray<NSString *> *法訣; // 使用繁体
@property (nonatomic, readonly) NSArray<NSString *> *七政信息;
@end

// 声明 ViewController 拥有一个名为 `課傳` 的属性
@interface UIViewController (PaiPanProperty)
@property (nonatomic, readonly) PaiPanResult *課傳;
@end

// 【新】独立的 C 递归函数，用于查找指定类的子视图
static void findSubviewsOfClass(UIView *view, Class targetClass, NSMutableArray *storage) {
    if ([view isKindOfClass:targetClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        findSubviewsOfClass(subview, targetClass, storage);
    }
}

// 【新】独立的 C 递归函数，用于查找所有 UILabel
static void findAllLabelsInView(UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:[UILabel class]]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        findAllLabelsInView(subview, storage);
    }
}


// =========================================================================
// Section 2: UI 修改与按钮创建
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_Final;
- (NSString *)extractTextFromViewWithClassName:(NSString *)className separator:(NSString *)separator;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIWindowScene *scene in UIApplication.sharedApplication.connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive) {
                        for (UIWindow *window in scene.windows) {
                            if (window.isKeyWindow) { keyWindow = window; break; }
                        }
                        if (keyWindow) break;
                    }
                }
            }
            if (!keyWindow) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                keyWindow = UIApplication.sharedApplication.keyWindow;
                #pragma clang diagnostic pop
            }

            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_Final) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// =========================================================================
// Section 3: 核心复制逻辑
// =========================================================================

%new
- (NSString *)extractTextFromViewWithClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) return @"";
    
    NSMutableArray *targetViews = [NSMutableArray array];
    findSubviewsOfClass(self.view, targetViewClass, targetViews); // 使用新的C函数

    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    
    NSMutableArray *labelsInView = [NSMutableArray array];
    findAllLabelsInView(containerView, labelsInView); // 使用新的C函数

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
- (void)copyAiButtonTapped_Final {
    #define SafeString(str) (str ?: @"")

    id keChuanData = nil;
    if ([self respondsToSelector:@selector(課傳)]) {
        keChuanData = [self performSelector:@selector(課傳)];
    }

    NSString *biFa = @"";
    if (keChuanData && [keChuanData respondsToSelector:@selector(法訣)]) {
        NSArray *biFaArray = [keChuanData performSelector:@selector(法訣)];
        if (biFaArray && [biFaArray isKindOfClass:[NSArray class]] && biFaArray.count > 0) {
            biFa = [biFaArray componentsJoinedByString:@"\n"];
        }
    }

    NSString *qiZheng = @"";
    if (keChuanData && [keChuanData respondsToSelector:@selector(七政信息)]) {
        NSArray *qiZhengArray = [keChuanData performSelector:@selector(七政信息)];
        if (qiZhengArray && [qiZhengArray isKindOfClass:[NSArray class]] && qiZhengArray.count > 0) {
             qiZheng = [qiZhengArray componentsJoinedByString:@"\n"];
        }
    }

    NSString *timeBlock = [[self extractTextFromViewWithClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang = [self extractTextFromViewWithClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang = [self extractTextFromViewWithClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromViewWithClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromViewWithClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromViewWithClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromViewWithClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array];
        findSubviewsOfClass(self.view, siKeViewClass, siKeViews);
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject;
            NSMutableArray* labels = [NSMutableArray array];
            findAllLabelsInView(container, labels);
            if(labels.count >= 12){
                NSMutableDictionary *columns=[NSMutableDictionary dictionary];
                for(UILabel *label in labels){ NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[key]){ columns[key] = [NSMutableArray array]; } [columns[key] addObject:label]; }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=columns[sortedKeys[0]], *c2=columns[sortedKeys[1]], *c3=columns[sortedKeys[2]], *c4=columns[sortedKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    [c2 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    [c3 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    [c4 sortUsingComparator:^NSComparisonResult(UILabel *a, UILabel *b) { return [@(a.frame.origin.y) compare:@(b.frame.origin.y)]; }];
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text), SafeString(((UILabel*)c4[1]).text), SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text), SafeString(((UILabel*)c3[1]).text), SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text), SafeString(((UILabel*)c2[1]).text), SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text), SafeString(((UILabel*)c1[1]).text), SafeString(((UILabel*)c1[0]).text)];
                }
            }
        }
    }
    
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        findSubviewsOfClass(self.view, sanChuanViewClass, sanChuanViews);
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"];
        NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i=0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i];
            NSMutableArray *labelsInView = [NSMutableArray array];
            findAllLabelsInView(view, labelsInView);
            [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (labelsInView.count >= 3) {
                NSString *liuQin = ((UILabel *)labelsInView.firstObject).text, *tianJiang = ((UILabel *)labelsInView.lastObject).text, *diZhi = ((UILabel *)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                NSMutableArray *shenShaParts = [NSMutableArray array];
                if (labelsInView.count > 3) { for (UILabel *label in [labelsInView subarrayWithRange:NSMakeRange(1, labelsInView.count - 3)]) { if(label.text) [shenShaParts addObject:label.text]; } }
                NSString *shenShaString = [shenShaParts componentsJoinedByString:@" "];
                NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(liuQin), SafeString(diZhi), SafeString(tianJiang)];
                if (shenShaString.length > 0) [formattedLine appendFormat:@" (%@)", shenShaString];
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", (i < chuanTitles.count ? chuanTitles[i] : @""), formattedLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }

    NSMutableString *finalText = [NSMutableString string];
    [finalText appendFormat:@"%@\n\n", SafeString(timeBlock)];
    [finalText appendFormat:@"月将: %@\n", SafeString(yueJiang)];
    [finalText appendFormat:@"空亡: %@\n", SafeString(kongWang)];
    [finalText appendFormat:@"三宫时: %@\n", SafeString(sanGongShi)];
    [finalText appendFormat:@"昼夜: %@\n", SafeString(zhouYe)];
    [finalText appendFormat:@"课体: %@\n\n", SafeString(fullKeti)];
    if (siKe.length > 0) { [finalText appendFormat:@"%@\n\n", SafeString(siKe)]; }
    if (sanChuan.length > 0) { [finalText appendFormat:@"%@\n\n", SafeString(sanChuan)]; }
    if (biFa.length > 0) { [finalText appendFormat:@"毕法:\n%@\n\n", SafeString(biFa)]; }
    if (qiZheng.length > 0) { [finalText appendFormat:@"七政:\n%@\n\n", SafeString(qiZheng)]; }
    finalText = [[finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
    [finalText appendFormat:@"\n\n起课方式: %@", SafeString(methodName)];
    
    [UIPasteboard generalPasteboard].string = finalText;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end

// =========================================================================
// Section 4: 保留的原始修改
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end
