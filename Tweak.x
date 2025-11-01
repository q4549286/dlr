#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ===============================================================
// 1. 全局状态与日志
// ===============================================================

static BOOL g_isExtracting = NO;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_resultsArray = nil;

// 简化的日志函数
static void Log(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[Echo_Test] %@", message);
}

// ===============================================================
// 2. 辅助函数：精准查找自定义手势
// ===============================================================

static void FindGesturesOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !aClass || !storage) return;
    for (UIGestureRecognizer *gesture in view.gestureRecognizers) {
        if ([gesture isKindOfClass:aClass]) {
            [storage addObject:gesture];
        }
    }
    for (UIView *subview in view.subviews) {
        FindGesturesOfClassRecursive(aClass, subview, storage);
    }
}

// ===============================================================
// 3. 核心Hook：拦截弹窗并提取数据
// ===============================================================

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtracting) {
        // 目标弹窗的正确类名 (从你的头文件中解码)
        Class popupVCClass = NSClassFromString(@"_TtC12六壬大占27天地盤宮位摘要視圖"); // 天地盘宫位摘要视图
        
        if (popupVCClass && [vcToPresent isKindOfClass:popupVCClass]) {
            Log(@"成功拦截到目标弹窗！正在提取内容...");
            
            // 延时一小段时间，确保弹窗视图完全加载
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = vcToPresent.view;
                
                // 简单粗暴地提取所有UILabel的文本
                NSMutableArray<UILabel *> *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels, [NSMutableArray array]);
                
                // 按垂直位置排序
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
                    if (obj1.frame.origin.y < obj2.frame.origin.y) return NSOrderedAscending;
                    if (obj1.frame.origin.y > obj2.frame.origin.y) return NSOrderedDescending;
                    return NSOrderedSame;
                }];

                NSMutableString *extractedText = [NSMutableString string];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [extractedText appendFormat:@"%@\n", label.text];
                    }
                }
                
                Log(@"提取内容完成:\n---\n%@\n---", extractedText);
                [g_resultsArray addObject:extractedText];
                
                // 立刻处理下一个任务
                [self performSelector:@selector(processGestureQueue)];
            });
            
            // 阻止弹窗实际显示出来
            return;
        }
    }
    
    // 如果不是我们的目标，就执行原始的弹窗方法
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// 辅助函数，用于查找视图中的所有UILabel
static void FindSubviewsOfClassRecursive(Class targetClass, UIView *view, NSMutableArray *storage, NSMutableArray *visited) {
    if (!view || [visited containsObject:view]) return;
    [visited addObject:view];

    if ([view isKindOfClass:targetClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(targetClass, subview, storage, visited);
    }
}


// ===============================================================
// 4. 主逻辑：启动任务 -> 处理队列 -> 完成
// ===============================================================

// 正确、可读的Swift类名
#define kViewControllerClassName @"_TtC12六壬大占14ViewController"
#define kTianJiangGestureClassName @"_TtCC12六壬大占14ViewController18天將觸摸手勢"

%hook _TtC12六壬大占14ViewController

// ---- Step 3: 队列处理函数 ----
%new
- (void)processGestureQueue {
    if (g_workQueue.count == 0) {
        Log(@"======= 所有任务完成！=======");
        Log(@"成功提取了 %lu 个天将的详情。", (unsigned long)g_resultsArray.count);
        
        NSMutableString *finalReport = [NSMutableString string];
        for (int i = 0; i < g_resultsArray.count; i++) {
            [finalReport appendFormat:@"\n--- 天将详情 %d ---\n%@", i + 1, g_resultsArray[i]];
        }
        
        Log(@"最终合并报告:\n%@", finalReport);
        
        // 清理状态
        g_isExtracting = NO;
        g_workQueue = nil;
        g_resultsArray = nil;
        return;
    }

    // 1. 从队列中取出下一个手势
    UIGestureRecognizer *gesture = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    // 从手势的"位"属性获取其代表的天将名
    id positionInfo = [gesture valueForKey:@"位"];
    Log(@"--> 正在触发第 %lu 个任务: 天将 [%@]", (unsigned long)(g_resultsArray.count + 1), positionInfo);

    // 2. 获取手势的 target 和 action
    // Swift对象的手势目标存储在私有属性中，我们需要KVC来访问
    NSArray *targets = [gesture valueForKey:@"targets"];
    if (!targets || targets.count == 0) {
        Log(@"错误：手势没有找到targets！跳过...");
        [self processGestureQueue];
        return;
    }
    
    id targetActionPair = targets.firstObject;
    id realTarget = [targetActionPair valueForKey:@"target"];
    SEL realAction = NSSelectorFromString([NSString stringWithFormat:@"%@", [targetActionPair valueForKey:@"action"]]);
    
    // 3. 直接调用，完美模拟点击
    if (realTarget && realAction && [realTarget respondsToSelector:realAction]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [realTarget performSelector:realAction withObject:gesture];
        #pragma clang diagnostic pop
    } else {
        Log(@"错误：无法触发手势，Target或Action无效！跳过...");
        [g_resultsArray addObject:@"[提取失败]"];
        [self processGestureQueue];
    }
}

// ---- Step 2: 任务启动函数 ----
%new
- (void)startTianJiangExtractionTest {
    if (g_isExtracting) {
        Log(@"测试任务已在进行中，请勿重复点击。");
        return;
    }
    Log(@"======= 启动天地盘-天将详情提取测试 =======");
    
    // 1. 初始化
    g_isExtracting = YES;
    g_workQueue = [NSMutableArray array];
    g_resultsArray = [NSMutableArray array];

    // 2. 定位天地盘视图
    UIView *tianDiPanView = MSHookIvar<UIView *>(self, "天地盤視圖");
    if (!tianDiPanView) {
        Log(@"致命错误: 找不到'天地盤視圖'实例！测试终止。");
        g_isExtracting = NO;
        return;
    }

    // 3. 找到所有“天将触摸手势”并加入任务队列
    Class gestureClass = NSClassFromString(kTianJiangGestureClassName);
    if (gestureClass) {
        FindGesturesOfClassRecursive(gestureClass, tianDiPanView, g_workQueue);
        Log(@"成功找到 %lu 个天将手势。", (unsigned long)g_workQueue.count);
    } else {
        Log(@"致命错误: 找不到手势类 '%@'！测试终止。", kTianJiangGestureClassName);
        g_isExtracting = NO;
        return;
    }
    
    if (g_workQueue.count == 0) {
        Log(@"错误: 未找到任何天将手势。测试终止。");
        g_isExtracting = NO;
        return;
    }

    // 4. 启动队列处理
    [self processGestureQueue];
}

// ---- Step 1: 添加一个触发按钮 ----
- (void)viewDidLoad {
    %orig;

    // 在主界面加载后，延时添加一个测试按钮
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
        testButton.frame = CGRectMake(10, 45, 120, 36);
        [testButton setTitle:@"API测试" forState:UIControlStateNormal];
        testButton.backgroundColor = [UIColor systemRedColor];
        [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        testButton.layer.cornerRadius = 18;
        [testButton addTarget:self action:@selector(startTianJiangExtractionTest) forControlEvents:UIControlEventTouchUpInside];
        
        // 把按钮添加到主窗口上，确保它总在最前
        UIWindow *keyWindow = self.view.window;
        if (keyWindow) {
            [keyWindow addSubview:testButton];
            Log(@"测试按钮已添加。");
        }
    });
}

%end


// ===============================================================
// 5. 初始化Hook
// ===============================================================
%ctor {
    MSHookMessageEx(NSClassFromString(kViewControllerClassName), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
    Log(@"独立测试脚本加载成功。");
}
