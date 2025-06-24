#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V-Simple] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSDictionary *> *g_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_keChuanTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"测试课传(极简版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
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
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                // 提取文本
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                // 关键：在弹窗完全关闭后，再处理下一个任务
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processKeChuanQueue_Truth];
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 极简版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (!chuanViewClass) {
        EchoLog(@"错误: 找不到 '六壬大占.傳視圖' 类");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // 1. 找到所有 `傳視圖` 实例
    NSMutableArray *allChuanViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(chuanViewClass, self.view, allChuanViews);

    // 2. 【核心】严格按Y坐标排序，这是区分它们的唯一可靠方法
    [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
    }];
    
    // 3. 遍历这个【有序的】视图数组，构建任务队列
    NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
    for (NSUInteger i = 0; i < allChuanViews.count; i++) {
        if (i >= rowTitles.count) break;
        
        UIView *chuanView = allChuanViews[i]; // 这是明确的、特定顺序的视图实例
        
        NSMutableArray *labelsInView = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], chuanView, labelsInView);
        [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
            return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
        }];
        
        if (labelsInView.count >= 2) {
            UILabel *dizhiLabel = labelsInView[labelsInView.count - 2];
            UILabel *tianjiangLabel = labelsInView[labelsInView.count - 1];
            
            // 将UILabel实例本身加入队列
            [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
            
            [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    // 启动队列处理器
    [self processKeChuanQueue_Truth];
}

%new
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试处理完毕");
        // ... (结束弹窗逻辑)
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"极简版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil; g_capturedKeChuanDetailArray = nil; g_keChuanTitleQueue = nil;
        return;
    }

    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];

    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        EchoLog(@"正在点击: %@", g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count]);
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        // 直接调用，接收者是 self (ViewController)，参数是确定的 UILabel 实例
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"错误: 未能执行点击操作，跳过。");
        [self processKeChuanQueue_Truth]; // 如果失败，也要继续处理下一个
    }
}
%end
