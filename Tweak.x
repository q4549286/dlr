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
// Section 3: 【新功能】一键复制到 AI (已修复编译错误)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSInteger const DebugButtonTag = 445566;

// 辅助函数，用于获取当前活跃的Window
static UIWindow *getActiveWindow() {
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                // 如果是iOS 15+, 直接用keyWindow
                if (@available(iOS 15.0, *)) {
                    return scene.keyWindow;
                }
                // iOS 13/14, 遍历windows
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        return window;
                    }
                }
            }
        }
    }
    // Fallback for older iOS versions
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return [UIApplication sharedApplication].keyWindow;
    #pragma clang diagnostic pop
}


@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)debugButtonTapped;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTextFromCollectionViewByShowingItFirst:(SEL)showSelector viewClassName:(NSString *)viewClassName;
// App内部方法声明，防止编译器警告
- (void)顯示法訣總覽;
- (void)顯示七政信息WithSender:(id)sender;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = getActiveWindow(); // 使用新的辅助函数
            if (!keyWindow) { return; }
            
            if (![keyWindow viewWithTag:CopyAiButtonTag]) {
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
            }
            
            if (![keyWindow viewWithTag:DebugButtonTag]) {
                UIButton *debugButton = [UIButton buttonWithType:UIButtonTypeSystem];
                debugButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 85, 90, 30);
                debugButton.tag = DebugButtonTag;
                [debugButton setTitle:@"Debug" forState:UIControlStateNormal];
                debugButton.titleLabel.font = [UIFont systemFontOfSize:12];
                debugButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.4 blue:0.2 alpha:1.0];
                [debugButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                debugButton.layer.cornerRadius = 6;
                [debugButton addTarget:self action:@selector(debugButtonTapped) forControlEvents:UIControlEventTouchUpInside];
                [keyWindow addSubview:debugButton];
            }
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
    if (!targetViewClass) return @"";
    NSMutableArray *targetViews = [NSMutableArray array];
    UIWindow *keyWindow = getActiveWindow(); // 使用新的辅助函数
    [self findSubviewsOfClass:targetViewClass inView:keyWindow andStoreIn:targetViews];
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
- (NSString *)extractTextFromCollectionViewByShowingItFirst:(SEL)showSelector viewClassName:(NSString *)viewClassName {
    if (![self respondsToSelector:showSelector]) {
        return nil;
    }
    
    NSMethodSignature *signature = [self methodSignatureForSelector:showSelector];
    if (signature.numberOfArguments > 2) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showSelector withObject:nil];
        #pragma clang diagnostic pop
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:showSelector];
        #pragma clang diagnostic pop
    }

    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    Class targetViewClass = NSClassFromString(viewClassName);
    if (!targetViewClass) return nil;
    
    UIWindow *keyWindow = getActiveWindow(); // 使用新的辅助函数
    NSMutableArray *views = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:keyWindow andStoreIn:views];
    
    UICollectionView *collectionView = views.firstObject;
    if (!collectionView || ![collectionView isKindOfClass:[UICollectionView class]]) {
         if (self.presentedViewController) { [self.presentedViewController dismissViewControllerAnimated:NO completion:nil]; }
         return nil;
    }

    id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
    if (!dataSource) {
        if (self.presentedViewController) { [self.presentedViewController dismissViewControllerAnimated:NO completion:nil]; }
        return nil;
    }

    NSInteger sections = 1;
    if ([dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
        sections = [dataSource numberOfSectionsInCollectionView:collectionView];
    }
    
    NSMutableArray *allTexts = [NSMutableArray array];
    for (NSInteger section = 0; section < sections; section++) {
        NSInteger items = [dataSource collectionView:collectionView numberOfItemsInSection:section];
        for (NSInteger item = 0; item < items; item++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
            UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
            
            NSMutableArray *labelsInCell = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:cell.contentView andStoreIn:labelsInCell];
            [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
                 return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
            }];
            
            NSMutableString *cellText = [NSMutableString string];
            for (UILabel *label in labelsInCell) {
                if (label.text && label.text.length > 0) {
                    [cellText appendFormat:@"%@ ", label.text];
                }
            }
            NSString *trimmedText = [cellText stringbyTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (trimmedText.length > 0) {
                [allTexts addObject:trimmedText];
            }
        }
    }
    
    if (self.presentedViewController) {
        [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
    } else {
        [collectionView.superview removeFromSuperview];
    }
    
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];

    return allTexts.count > 0 ? [allTexts componentsJoinedByString:@"\n"] : nil;
}

// 【主功能】
%new
- (void)copyAiButtonTapped_FinalPerfect {
    #define SafeString(str) (str ?: @"")

    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    NSString *biFaList = [self extractTextFromCollectionViewByShowingItFirst:@selector(顯示法訣總覽) viewClassName:@"六壬大占.格局總覽視圖"];
    NSString *qiZhengList = [self extractTextFromCollectionViewByShowingItFirst:@selector(顯示七政信息WithSender:) viewClassName:@"六壬大占.七政信息視圖"];

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
                    siKe = [NSMutableString stringWithFormat:
                        @"第一课: %@->%@%@\n"
                        @"第二课: %@->%@%@\n"
                        @"第三课: %@->%@%@\n"
                        @"第四课: %@->%@%@",
                        SafeString(ke1_di), SafeString(ke1_tian), SafeString(ke1_shen),
                        SafeString(ke2_di), SafeString(ke2_tian), SafeString(ke2_shen),
                        SafeString(ke3_di), SafeString(ke3_tian), SafeString(ke3_shen),
                        SafeString(ke4_di), SafeString(ke4_tian), SafeString(ke4_shen)
                    ];
                }
            }
        }
    }

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
                    for (UILabel *label in shenShaLabels) {
                        if (label.text && label.text.length > 0) { [shenShaParts addObject:label.text]; }
                    }
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

    NSMutableString *finalText = [NSMutableString string];
    [finalText appendFormat:@"%@\n\n", SafeString(timeBlock)];
    [finalText appendFormat:@"月将: %@\n", SafeString(yueJiang)];
    [finalText appendFormat:@"空亡: %@\n", SafeString(kongWang)];
    [finalText appendFormat:@"三宫时: %@\n", SafeString(sanGongShi)];
    [finalText appendFormat:@"昼夜: %@\n", SafeString(zhouYe)];
    [finalText appendFormat:@"课体: %@\n\n", SafeString(fullKeti)];
    [finalText appendFormat:@"%@\n\n", SafeString(siKe)];
    [finalText appendFormat:@"%@\n\n", SafeString(sanChuan)];
    if (biFaList && biFaList.length > 0) { [finalText appendFormat:@"毕法:\n%@\n\n", biFaList]; }
    if (qiZhengList && qiZhengList.length > 0) { [finalText appendFormat:@"七政:\n%@\n\n", qiZhengList]; }
    [finalText appendFormat:@"起课方式: %@", SafeString(methodName)];
    
    NSString *cleanedFinalText = [finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    [UIPasteboard generalPasteboard].string = cleanedFinalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:cleanedFinalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// 【Debug功能】
%new
- (void)debugButtonTapped {
    #define DebugString(str) (str ?: @"nil")

    NSMutableString *debugInfo = [NSMutableString string];
    
    [debugInfo appendString:@"--- 固定视图提取 ---\n"];
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    [debugInfo appendFormat:@"时间块: %@\n", DebugString(timeBlock)];
    NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    [debugInfo appendFormat:@"月将: %@\n", DebugString(yueJiang)];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    [debugInfo appendFormat:@"空亡: %@\n", DebugString(kongWang)];
    
    [debugInfo appendString:@"\n--- 动态列表提取 ---\n"];
    [debugInfo appendString:@"正在尝试提取毕法...\n"];
    NSString *biFaList = [self extractTextFromCollectionViewByShowingItFirst:@selector(顯示法訣總覽) viewClassName:@"六壬大占.格局總覽視圖"];
    [debugInfo appendFormat:@"毕法列表:\n%@\n", DebugString(biFaList)];

    [debugInfo appendString:@"\n正在尝试提取七政...\n"];
    NSString *qiZhengList = [self extractTextFromCollectionViewByShowingItFirst:@selector(顯示七政信息WithSender:) viewClassName:@"六壬大占.七政信息視圖"];
    [debugInfo appendFormat:@"七政列表:\n%@\n", DebugString(qiZhengList)];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Debug 信息" message:debugInfo preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction]; // 修复：将action添加到alert
    [self presentViewController:alert animated:YES completion:nil];
}

%end
