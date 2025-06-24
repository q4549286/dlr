#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define EchoLog(format, ...) NSLog(@"[KeChuan-Debug-Struct] " format, ##__VA_ARGS__)

// --- 全局变量和辅助函数 (不变) ---
static NSInteger const StartButtonTag = 556689;
static NSInteger const NextButtonTag = 556690;
static NSMutableArray *g_debugWorkQueue = nil;

static id GetIvarFromObject(id object, const char *ivarName) { Ivar ivar = class_getInstanceVariable([object class], ivarName); if (ivar) { return object_getIvar(object, ivar); } return nil; }
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }

@interface UIViewController (EchoAIDebugAddons_Struct)
- (void)setupKeChuanDebug_Struct;
- (void)processNextKeChuanTask_Struct;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            [[keyWindow viewWithTag:StartButtonTag] removeFromSuperview];
            [[keyWindow viewWithTag:NextButtonTag] removeFromSuperview];

            UIButton *startButton = [UIButton buttonWithType:UIButtonTypeSystem];
            startButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 80, 150, 36);
            startButton.tag = StartButtonTag;
            [startButton setTitle:@"开始调试(结构修正)" forState:UIControlStateNormal];
            startButton.backgroundColor = [UIColor systemBlueColor];
            [startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            startButton.layer.cornerRadius = 8;
            [startButton addTarget:self action:@selector(setupKeChuanDebug_Struct) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:startButton];

            UIButton *nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
            nextButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 80 + 40, 150, 36);
            nextButton.tag = NextButtonTag;
            [nextButton setTitle:@"处理下一个 (剩: 0)" forState:UIControlStateNormal];
            nextButton.backgroundColor = [UIColor systemGreenColor];
            [nextButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            nextButton.layer.cornerRadius = 8;
            [nextButton addTarget:self action:@selector(processNextKeChuanTask_Struct) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:nextButton];
            nextButton.enabled = NO;
        });
    }
}

%new
- (void)setupKeChuanDebug_Struct {
    EchoLog(@"--- 建立结构修正版调试工作清单 ---");
    g_debugWorkQueue = [NSMutableArray array];

    // Part A: 三传 (通过 '三传视窗' 容器来查找)
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containerViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containerViews);
        if (containerViews.count > 0) {
            UIView *container = containerViews.firstObject;
            
            NSDictionary<NSString *, NSString *> *chuanMap = @{
                @"初傳": @"初传",
                @"中傳": @"中传",
                @"末傳": @"末传"
            };

            for (NSString *ivarName in chuanMap) {
                // 从容器中取出 '傳視圖' 对象
                UIView *chuanView = GetIvarFromObject(container, [ivarName cStringUsingEncoding:NSUTF8StringEncoding]);
                if (chuanView) {
                    // 再从 '傳視圖' 对象中取出 UILabel
                    UILabel *dizhiLabel = GetIvarFromObject(chuanView, "傳神字");
                    UILabel *tianjiangLabel = GetIvarFromObject(chuanView, "傳乘將");
                    
                    NSString *rowTitle = chuanMap[ivarName];
                    if (dizhiLabel) [g_debugWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi", @"title": [NSString stringWithFormat:@"%@ - 地支(%@)", rowTitle, dizhiLabel.text]}];
                    if (tianjiangLabel) [g_debugWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang", @"title": [NSString stringWithFormat:@"%@ - 天将(%@)", rowTitle, tianjiangLabel.text]}];
                }
            }
        }
    }

    // Part B: 四课 (查找方式不变，因为它本身就是唯一的容器)
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *siKeContainer = skViews.firstObject;
            NSArray *siKeTasks = @[
                @{@"ivar": @"日",       @"type": @"dizhi",     @"title": @"一课下神(干)"},
                @{@"ivar": @"日上",     @"type": @"dizhi",     @"title": @"一课上神"},
                @{@"ivar": @"日上天將", @"type": @"tianjiang", @"title": @"一课天将"},
                @{@"ivar": @"辰",       @"type": @"dizhi",     @"title": @"二课下神(支)"},
                @{@"ivar": @"辰上",     @"type": @"dizhi",     @"title": @"二课上神"},
                @{@"ivar": @"辰上天將", @"type": @"tianjiang", @"title": @"二课天将"},
                @{@"ivar": @"日上",     @"type": @"dizhi",     @"title": @"三课下神"},
                @{@"ivar": @"日陰",     @"type": @"dizhi",     @"title": @"三课上神(阴)"},
                @{@"ivar": @"日陰天將", @"type": @"tianjiang", @"title": @"三课天将(阴)"},
                @{@"ivar": @"辰上",     @"type": @"dizhi",     @"title": @"四课下神"},
                @{@"ivar": @"辰陰",     @"type": @"dizhi",     @"title": @"四课上神(阴)"},
                @{@"ivar": @"辰陰天將", @"type": @"tianjiang", @"title": @"四课天将(阴)"}
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
    } else { /* ... 错误处理 ... */ }
}

%new
- (void)processNextKeChuanTask_Struct {
    // 这部分逻辑和之前完全一样，因为它的问题不在于执行，而在于队列的建立
    if (!g_debugWorkQueue || g_debugWorkQueue.count == 0) {
        EchoLog(@"任务队列为空。");
        // ... 更新UI ...
        return;
    }

    NSDictionary *task = g_debugWorkQueue.firstObject;
    [g_debugWorkQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"];
    NSString *itemType = task[@"type"];
    NSString *itemTitle = task[@"title"];
    
    EchoLog(@"--- 正在处理任务: %@ ---", itemTitle);
    
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
    } else { EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。", itemTitle); }
    
    UIWindow *keyWindow = self.view.window;
    UIButton *nextButton = [keyWindow viewWithTag:NextButtonTag];
    [nextButton setTitle:[NSString stringWithFormat:@"处理下一个 (剩: %lu)", (unsigned long)g_debugWorkQueue.count] forState:UIControlStateNormal];
    if (g_debugWorkQueue.count == 0) {
        nextButton.enabled = NO;
        EchoLog(@"--- 所有调试任务已处理完毕 ---");
    }
}
%end
