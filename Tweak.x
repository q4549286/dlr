#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// ... 全局变量和辅助函数部分保持不变 ...
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Container-V2] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556685; // 新的Tag
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_containerWorkQueue = nil;
static NSMutableArray *g_taskTitleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

@interface UIViewController (EchoAITestAddons_Container_V2)
- (void)performKeChuanDetailExtractionTest_Container_V2;
- (void)processContainerQueue_V2;
@end

%hook UIViewController

// ... viewDidLoad 和 presentViewController 保持不变 ...
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
            [testButton setTitle:@"测试课传(容器V2)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Container_V2) forControlEvents:UIControlEventTouchUpInside];
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
                // ... 内部提取逻辑不变 ...
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
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
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
- (void)performKeChuanDetailExtractionTest_Container_V2 {
    EchoLog(@"开始执行 [课传详情] 容器队列V2版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_containerWorkQueue = [NSMutableArray array];
    g_taskTitleQueue = [NSMutableArray array];

    // --- Part A: 查找所有容器视图并放入队列 ---
    
    // 【关键修改】
    // 1. 先找到总的三传容器
    Class sanChuanZongViewClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanZongViewClass) {
        NSMutableArray *sczViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanZongViewClass, self.view, sczViews);
        if (sczViews.count > 0) {
            UIView *sanChuanZongView = sczViews.firstObject;
            
            // 2. 在总容器内部，再去找每一个传的视图
            Class sanChuanDanViewClass = NSClassFromString(@"六壬大占.傳視圖");
            if (sanChuanDanViewClass) {
                NSMutableArray *scDanViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive(sanChuanDanViewClass, sanChuanZongView, scDanViews);
                [scDanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UIView *view in scDanViews) {
                    [g_containerWorkQueue addObject:@{@"container": view, @"type": @"sanchuan"}];
                }
            }
        }
    }

    // 2. 查找四课容器 (逻辑不变)
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            [g_containerWorkQueue addObject:@{@"container": skViews.firstObject, @"type": @"sike"}];
        }
    }
    
    if (g_containerWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何课传容器视图。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }

    // --- Part B: 启动容器队列处理器 ---
    [self processContainerQueue_V2];
}

%new
- (void)processContainerQueue_V2 {
    // 这个函数内部的逻辑完全不需要改变，因为它处理的是已经找到的容器
    // ... 代码与上一版完全相同 ...
    if (g_containerWorkQueue.count == 0) {
        // --- 所有容器都处理完毕 ---
        EchoLog(@"[课传详情] 所有容器处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_taskTitleQueue.count; i++) {
            NSString *title = g_taskTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"容器V2版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        g_isExtractingKeChuanDetail = NO;
        g_containerWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_taskTitleQueue = nil;
        return;
    }
    
    NSDictionary *task = g_containerWorkQueue.firstObject;
    [g_containerWorkQueue removeObjectAtIndex:0];
    
    UIView *container = task[@"container"];
    NSString *type = task[@"type"];
    
    NSMutableArray *subTasks = [NSMutableArray array];
    if ([type isEqualToString:@"sanchuan"]) {
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], container, labels);
        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
        
        if (labels.count >= 2) {
            // 这里我们需要确定哪个是初传、中传、末传。
            // 之前通过索引判断，现在因为是分开的视图，可能需要更可靠的方法
            // 暂时我们还是用六亲来判断，但更好的方法是记录它们的顺序
            UILabel *dizhiLabel = labels[labels.count - 2];
            UILabel *tianjiangLabel = labels[labels.count - 1];
            UILabel *titleLabel = labels.firstObject; 
            
            [subTasks addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
            [g_taskTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titleLabel.text, dizhiLabel.text]];
            
            [subTasks addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
            [g_taskTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titleLabel.text, tianjiangLabel.text]];
        }

    } else if ([type isEqualToString:@"sike"]) {
        // ... 四课解析逻辑不变 ...
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], container, allLabels);
        NSMutableDictionary *cols = [NSMutableDictionary dictionary];
        for (UILabel *label in allLabels) {
            NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
            if (!cols[key]) { cols[key] = [NSMutableArray array]; }
            [cols[key] addObject:label];
        }
        
        if (cols.allKeys.count == 4) {
            NSArray *sortedKeys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
            NSArray *colTitles = @[@"第四课", @"第三课", @"第二课", @"第一课"];
            for (NSUInteger i = 0; i < sortedKeys.count; i++) {
                NSMutableArray *colLabels = cols[sortedKeys[i]];
                [colLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                if (colLabels.count >= 2) {
                    UILabel *tianjiangLabel = colLabels[0];
                    UILabel *dizhiLabel = colLabels[1];
                    [subTasks addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                    [g_taskTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", colTitles[i], dizhiLabel.text]];
                    [subTasks addObject:@{@"item": tianjiangLabel, @"type": "tianjiang"}];
                    [g_taskTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", colTitles[i], tianjiangLabel.text]];
                }
            }
        }
    }
    
    __block void (^processSubTasks)(void);
    processSubTasks = ^{
        if (subTasks.count == 0) {
            [self processContainerQueue_V2];
            processSubTasks = nil;
            return;
        }
        
        NSDictionary *subTask = subTasks.firstObject;
        [subTasks removeObjectAtIndex:0];
        
        UIView *itemToClick = subTask[@"item"];
        NSString *itemType = subTask[@"type"];
        
        SEL actionToPerform = nil;
        if ([itemType isEqualToString:@"dizhi"]) actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
        else if ([itemType isEqualToString:@"tianjiang"]) actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
        
        if (actionToPerform && [self respondsToSelector:actionToPerform]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [self performSelector:actionToPerform withObject:itemToClick];
            #pragma clang diagnostic pop
        }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processSubTasks();
        });
    };
    
    processSubTasks();
}
%end
