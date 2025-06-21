#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =========================================================================
// Section 1: 最终工作版 V3 - 声明与Hook
// =========================================================================

// --- 声明我们推断存在的全局单例和数据接口 ---

// 1. 声明核心数据对象接口
@interface KeChuanData : NSObject
@property (nonatomic, strong) NSArray<NSString *> *法诀; // 毕法/格局
@property (nonatomic, strong) NSArray *七政;         // 七政信息
@end

// 2. 声明全局单例的接口
// 我们推断存在一个名为 `排盘` 的类，它有一个叫 `共享` (shared) 的方法来获取唯一实例
@interface PaiPanSingleton : NSObject
+ (instancetype)共享; // class method to get the shared instance
@property (nonatomic, strong) KeChuanData *课传; // The data object within the singleton
@end

// 3. 声明我们的附加功能接口
@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
@end


// --- Hook UIViewController (只为添加按钮) ---
static NSInteger const CopyAiButtonTag = 112233;

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
                        keyWindow = scene.windows.firstObject;
                        break;
                    }
                }
            } else {
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
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// =========================================================================
// Section 2: 最终工作版 V3 - 核心复制逻辑
// =========================================================================

%new
- (void)copyAiButtonTapped_FinalPerfect {
    #define SafeString(str) (str ?: @"")

    // --- 0. 【关键】获取全局单例和核心数据 ---
    KeChuanData *keChuanData = nil;
    Class paiPanClass = NSClassFromString(@"六壬大占.排盘");
    if (paiPanClass && [paiPanClass respondsToSelector:@selector(共享)]) {
        PaiPanSingleton *sharedInstance = [paiPanClass performSelector:@selector(共享)];
        if (sharedInstance && [sharedInstance respondsToSelector:@selector(课传)]) {
            keChuanData = [sharedInstance valueForKey:@"课传"];
        }
    }

    // --- 1. 从界面提取基础信息 ---
    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    NSString *yueJiang = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    NSString *kongWang = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
    NSString *sanGongShi = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    NSString *zhouYe = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    NSString *fullKeti = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    NSString *methodName = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    
    // --- 2. 【关键】从 `课传` 对象中提取毕法和七政 ---
    NSString *biFa = @"";
    if (keChuanData && [keChuanData respondsToSelector:@selector(法诀)]) {
        NSArray *biFaArray = [keChuanData valueForKey:@"法诀"];
        if (biFaArray && biFaArray.count > 0) {
            biFa = [biFaArray componentsJoinedByString:@"\n"];
        }
    }

    NSString *qiZheng = @"";
    if (keChuanData && [keChuanData respondsToSelector:@selector(七政)]) {
        NSArray *qiZhengArray = [keChuanData valueForKey:@"七政"];
        if (qiZhengArray && qiZhengArray.count > 0) {
             qiZheng = [qiZhengArray componentsJoinedByString:@"\n"];
        }
    }
    
    // --- 3. 四课提取逻辑 (保持不变) ---
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
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *obj1, NSString *obj2) { return [@([obj1 floatValue]) compare:@([obj2 floatValue])]; }];
                    NSMutableArray *c1=columns[sortedColumnKeys[0]], *c2=columns[sortedColumnKeys[1]], *c3=columns[sortedColumnKeys[2]], *c4=columns[sortedColumnKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];}];
                    [c2 sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];}];
                    [c3 sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];}];
                    [c4 sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];}];
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(((UILabel*)c4[2]).text), SafeString(((UILabel*)c4[1]).text), SafeString(((UILabel*)c4[0]).text), SafeString(((UILabel*)c3[2]).text), SafeString(((UILabel*)c3[1]).text), SafeString(((UILabel*)c3[0]).text), SafeString(((UILabel*)c2[2]).text), SafeString(((UILabel*)c2[1]).text), SafeString(((UILabel*)c2[0]).text), SafeString(((UILabel*)c1[2]).text), SafeString(((UILabel*)c1[1]).text), SafeString(((UILabel*)c1[0]).text)];
                }
            }
        }
    }

    // --- 4. 三传提取逻辑 (保持不变) ---
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews];
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView*a,UIView*b){return [@(a.frame.origin.y) compare:@(b.frame.origin.y)];}];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"];
        NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i=0; i<sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i];
            NSMutableArray *labelsInView = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView];
            [labelsInView sortUsingComparator:^NSComparisonResult(UILabel*a,UILabel*b){return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];}];
            if (labelsInView.count >= 3) {
                NSString *liuQin = ((UILabel *)labelsInView.firstObject).text, *tianJiang = ((UILabel *)labelsInView.lastObject).text, *diZhi = ((UILabel *)[labelsInView objectAtIndex:labelsInView.count - 2]).text;
                NSMutableArray *shenShaParts = [NSMutableArray array];
                if (labelsInView.count > 3) { for (UILabel *label in [labelsInView subarrayWithRange:NSMakeRange(1, labelsInView.count - 3)]) { if(label.text) [shenShaParts addObject:label.text]; } }
                NSString *shenShaString = [shenShaParts componentsJoinedByString:@" "];
                NSMutableString *formattedLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(liuQin), SafeString(diZhi), SafeString(tianJiang)];
                if (shenShaString.length > 0) [formattedLine appendFormat:@" (%@)", shenShaString];
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", (i < chuanTitles.count ? chuanTitles[i] : @""), formattedLine]];
            } else {
                NSMutableArray *lineParts = [NSMutableArray array];
                for (UILabel *label in labelsInView) { if(label.text) [lineParts addObject:label.text]; }
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", (i < chuanTitles.count ? chuanTitles[i] : @""), [lineParts componentsJoinedByString:@" "]]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    
    // --- 5. 组合最终文本 (全新排版) ---
    NSMutableString *finalText = [NSMutableString string];
    [finalText appendFormat:@"%@\n\n", SafeString(timeBlock)];
    [finalText appendFormat:@"月将: %@\n", SafeString(yueJiang)];
    [finalText appendFormat:@"空亡: %@\n", SafeString(kongWang)];
    [finalText appendFormat:@"三宫时: %@\n", SafeString(sanGongShi)];
    [finalText appendFormat:@"昼夜: %@\n", SafeString(zhouYe)];
    [finalText appendFormat:@"课体: %@\n\n", SafeString(fullKeti)];
    [finalText appendFormat:@"%@\n\n", SafeString(siKe)];
    [finalText appendFormat:@"%@\n\n", SafeString(sanChuan)];

    if (biFa.length > 0) {
        [finalText appendFormat:@"毕法:\n%@\n\n", SafeString(biFa)];
    }
    if (qiZheng.length > 0) {
        [finalText appendFormat:@"七政:\n%@\n\n", SafeString(qiZheng)];
    }
    
    [finalText appendFormat:@"起课方式: %@", SafeString(methodName)];
    
    [UIPasteboard generalPasteboard].string = finalText;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

// =========================================================================
// Section 3: 辅助函数
// =========================================================================

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

%end
