#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define EchoLog(format, ...) NSLog(@"[KeChuan-Auto-Fix] " format, ##__VA_ARGS__)

// --- 全局变量 ---
static NSInteger const TestButtonTag = 556693;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

// --- 辅助函数 ---
static id GetIvarFromObject(id object, const char *ivarName) { Ivar ivar = class_getInstanceVariable([object class], ivarName); if (ivar) { return object_getIvar(object, ivar); } return nil; }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

@interface UIViewController (EchoAIAutoFixAddons)
- (void)performKeChuanExtraction_AutoFix;
- (void)processKeChuanQueue_AutoFix;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 80, 150, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"开始自动提取(修正)" forState:UIControlStateNormal];
            testButton.backgroundColor = [UIColor systemPurpleColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanExtraction_AutoFix) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { /* ... 排序 ... */ if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performKeChuanExtraction_AutoFix {
    EchoLog(@"--- 开始执行自动提取(修正版) ---");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    // Part A: 三传
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containerViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containerViews);
        if (containerViews.count > 0) {
            UIView *container = containerViews.firstObject;
            NSDictionary<NSString *, NSString *> *chuanMap = @{ @"初傳": @"初传", @"中傳": @"中传", @"末傳": @"末传" };
            for (NSString *ivarName in chuanMap) {
                UIView *chuanView = GetIvarFromObject(container, [ivarName cStringUsingEncoding:NSUTF8StringEncoding]);
                if (chuanView) {
                    UILabel *dizhiLabel = GetIvarFromObject(chuanView, "傳神字");
                    UILabel *tianjiangLabel = GetIvarFromObject(chuanView, "傳乘將");
                    NSString *rowTitle = chuanMap[ivarName];
                    // 【关键改动】我们把整个 'chuanView' 作为 'sender'，而不是 UILabel
                    if (dizhiLabel) {
                        [g_keChuanWorkQueue addObject:@{@"item": chuanView, @"type": @"dizhi", @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitle, dizhiLabel.text]}];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitle, dizhiLabel.text]];
                    }
                    if (tianjiangLabel) {
                        [g_keChuanWorkQueue addObject:@{@"item": chuanView, @"type": @"tianjiang", @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitle, tianjiangLabel.text]}];
                        [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitle, tianjiangLabel.text]];
                    }
                }
            }
        }
    }

    // Part B: 四课
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            // 【关键改动】对于四课，我们把整个 'siKeContainer' 作为 'sender'
            // 但我们需要一种方法告诉它我们点的是哪个。这里我们还是传UILabel，但要做好失败的准备
            NSArray *siKeTasks = @[
                @{@"ivar": @"日", @"type": @"dizhi", @"title": @"一课下神(干)"}, @{@"ivar": @"日上", @"type": @"dizhi", @"title": @"一课上神"}, @{@"ivar": @"日上天將", @"type": @"tianjiang", @"title": @"一课天将"},
                @{@"ivar": @"辰", @"type": @"dizhi", @"title": @"二课下神(支)"}, @{@"ivar": @"辰上", @"type": @"dizhi", @"title": @"二课上神"}, @{@"ivar": @"辰上天將", @"type": @"tianjiang", @"title": @"二课天将"},
                @{@"ivar": @"日上", @"type": @"dizhi", @"title": @"三课下神"}, @{@"ivar": @"日陰", @"type": @"dizhi", @"title": @"三课上神(阴)"}, @{@"ivar": @"日陰天將", @"type": @"tianjiang", @"title": @"三课天将(阴)"},
                @{@"ivar": @"辰上", @"type": @"dizhi", @"title": @"四课下神"}, @{@"ivar": @"辰陰", @"type": @"dizhi", @"title": @"四课上神(阴)"}, @{@"ivar": @"辰陰天將", @"type": @"tianjiang", @"title": @"四课天将(阴)"}
            ];
            for (NSDictionary *taskInfo in siKeTasks) {
                UILabel *label = GetIvarFromObject(siKeContainer, [taskInfo[@"ivar"] cStringUsingEncoding:NSUTF8StringEncoding]);
                if (label) {
                    NSString *title = [NSString stringWithFormat:@"%@(%@)", taskInfo[@"title"], label.text];
                    [g_keChuanWorkQueue addObject:@{@"item": label, @"type": taskInfo[@"type"], @"title": title}];
                    [g_keChuanTitleQueue addObject:title];
                }
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) { /* ... */ return; }
    [self processKeChuanQueue_AutoFix];
}

%new
- (void)processKeChuanQueue_AutoFix {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"--- 自动提取处理完毕 ---");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"详情已复制" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        /* ... 重置全局变量 ... */
        return;
    }
    
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToSend = task[@"item"];
    NSString *itemType = task[@"type"];
    NSString *itemTitle = task[@"title"];
    EchoLog(@"正在处理: %@", itemTitle);
    
    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    else if ([itemType isEqualToString:@"tianjiang"]) actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToSend];
        #pragma clang diagnostic pop
    } else { /* ... */ }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processKeChuanQueue_AutoFix];
    });
}
%end
