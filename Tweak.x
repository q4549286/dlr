#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define EchoLog(format, ...) NSLog(@"[KeChuan-Debug-Full] " format, ##__VA_ARGS__)

// --- 全局变量 ---
static NSInteger const StartButtonTag = 556685;
static NSInteger const NextButtonTag = 556686;
static NSMutableArray *g_debugWorkQueue = nil;

// --- 辅助函数 ---
static id GetIvarFromObject(id object, const char *ivarName) { Ivar ivar = class_getInstanceVariable([object class], ivarName); if (ivar) { return object_getIvar(object, ivar); } return nil; }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

@interface UIViewController (EchoAIDebugAddons_Full)
- (void)setupKeChuanDebug_Full;
- (void)processNextKeChuanTask_Full;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            
            // 移除旧按钮，以防万一
            [[keyWindow viewWithTag:StartButtonTag] removeFromSuperview];
            [[keyWindow viewWithTag:NextButtonTag] removeFromSuperview];

            // "开始/重置调试" 按钮
            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 80, 150, 36);
            startButton.tag = StartButtonTag;
            [startButton setTitle:@"开始调试(完整版)" forState:UIControlStateNormal];
            startButton.backgroundColor = [UIColor systemBlueColor];
            [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            startButton.layer.cornerRadius = 8;
            [startButton addTarget:self action:@selector(setupKeChuanDebug_Full) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:startButton];

            // "处理下一个" 按钮
            UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
            nextButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 80 + 40, 150, 36);
            nextButton.tag = NextButtonTag;
            [nextButton setTitle:@"处理下一个 (剩: 0)" forState:UIControlStateNormal];
            nextButton.backgroundColor = [UIColor systemGreenColor];
            [nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            nextButton.layer.cornerRadius = 8;
            [nextButton addTarget:self action:@selector(processNextKeChuanTask_Full) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:nextButton];
            nextButton.enabled = NO;
        });
    }
}

%new
// 步骤一: 建立一个包含所有可点击目标的完整工作清单
- (void)setupKeChuanDebug_Full {
    EchoLog(@"--- 建立完整版调试工作清单 ---");
    g_debugWorkQueue = [NSMutableArray array];

    // Part A: 三传 (6个目标)
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            UIView *chuanView = scViews[i];
            UILabel *dizhiLabel = GetIvarFromObject(chuanView, "傳神字");
            UILabel *tianjiangLabel = GetIvarFromObject(chuanView, "傳乘將");
            if (dizhiLabel) [g_debugWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi", @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]}];
            if (tianjiangLabel) [g_debugWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang", @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]}];
        }
    }

    // Part B: 四课 (12个目标)
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            // 定义所有12个目标的ivar名称和它们的类型/标题
            NSArray *siKeTasks = @[
                // 第一课
                @{@"ivar": @"日",       @"type": @"dizhi", @"title": @"一课下神(干)"},
                @{@"ivar": @"日上",     @"type": @"dizhi", @"title": @"一课上神"},
                @{@"ivar": @"日上天將", @"type": @"tianjiang", @"title": @"一课天将"},
                // 第二课
                @{@"ivar": @"辰",       @"type": @"dizhi", @"title": @"二课下神(支)"},
                @{@"ivar": @"辰上",     @"type": @"dizhi", @"title": @"二课上神"},
                @{@"ivar": @"辰上天將", @"type": @"tianjiang", @"title": @"二课天将"},
                // 第三课
                @{@"ivar": @"日上",     @"type": @"dizhi", @"title": @"三课下神"}, // 注意：这里复用了'日上'
                @{@"ivar": @"日陰",     @"type": "dizhi", @"title": @"三课上神(阴)"},
                @{@"ivar": @"日陰天將", @"type": "tianjiang", @"title": @"三课天将(阴)"},
                // 第四课
                @{@"ivar": @"辰上",     @"type": @"dizhi", @"title": @"四课下神"}, // 注意：这里复用了'辰上'
                @{@"ivar": @"辰陰",     @"type": "dizhi", @"title": @"四课上神(阴)"},
                @{@"ivar": @"辰陰天將", @"type": "tianjiang", @"title": @"四课天将(阴)"}
            ];
            
            for (NSDictionary *taskInfo in siKeTasks) {
                UILabel *label = GetIvarFromObject(siKeContainer, [taskInfo[@"ivar"] cStringUsingEncoding:NSUTF8StringEncoding]);
                if (label) {
                    NSString *title = [NSString stringWithFormat:@"%@(%@)", taskInfo[@"title"], label.text];
                    [g_debugWorkQueue addObject:@{@"item": label, @"type": taskInfo[@"type"], @"title": title}];
                }
            }
        }
    }
    
    UIWindow *keyWindow = self.view.window;
    UIButton *nextButton = [keyWindow viewWithTag:NextButtonTag];
    if (g_debugWorkQueue.count > 0) {
        EchoLog(@"建立工作清单成功，共 %lu 个任务。", (unsigned long)g_debugWorkQueue.count);
        nextButton.enabled = YES;
        [nextButton setTitle:[NSString stringWithFormat:@"处理下一个 (剩: %lu)", (unsigned long)g_debugWorkQueue.count] forState:UIControlStateNormal];
    } else {
        EchoLog(@"建立工作清单失败，未找到任何任务。");
        nextButton.enabled = NO;
        [nextButton setTitle:@"处理下一个 (剩: 0)" forState:UIControlStateNormal];
    }
}

%new
// 步骤二: 手动触发，一次只处理一个任务
- (void)processNextKeChuanTask_Full {
    if (!g_debugWorkQueue || g_debugWorkQueue.count == 0) {
        EchoLog(@"任务队列为空，请先点击'开始调试'。");
        UIWindow *keyWindow = self.view.window;
        UIButton *nextButton = [keyWindow viewWithTag:NextButtonTag];
        nextButton.enabled = NO;
        [nextButton setTitle:@"处理下一个 (剩: 0)" forState:UIControlStateNormal];
        return;
    }

    // 从队列中取出一个任务
    NSDictionary *task = g_debugWorkQueue.firstObject;
    [g_debugWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];
    NSString *itemTitle = task[@"title"];
    
    EchoLog(@"--- 正在处理任务: %@ ---", itemTitle);
    
    // 根据类型决定调用哪个方法
    SEL actionToPerform = nil;
    if ([itemType isEqualToString:@"dizhi"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([itemType isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
        
        // 弹出的内容需要您手动查看和验证。这个调试脚本不自动抓取。
        // 它只负责触发点击。
    } else {
        EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。", itemTitle);
    }
    
    // 更新按钮状态
    UIWindow *keyWindow = self.view.window;
    UIButton *nextButton = [keyWindow viewWithTag:NextButtonTag];
    [nextButton setTitle:[NSString stringWithFormat:@"处理下一个 (剩: %lu)", (unsigned long)g_debugWorkQueue.count] forState:UIControlStateNormal];
    if (g_debugWorkQueue.count == 0) {
        nextButton.enabled = NO;
        EchoLog(@"--- 所有调试任务已处理完毕 ---");
    }
}
%end
