#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Final-V1] " format, ##__VA_ARGS__)

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

// --- 任务状态控制 ---
static dispatch_queue_t g_echo_task_queue;
static BOOL g_isExtractingDetails = NO;

// --- 数据存储 ---
static NSMutableDictionary *g_capturedData = nil;

// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

static id GetIvarView(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) { return object_getIvar(object, ivar); }
    return nil;
}

static NSString * const CustomFooterText = @"\n\n"
"--- 自定义注意事项 ---\n"
"1. 本解析结果仅供参考。\n"
"2. 请结合实际情况进行判断。\n"
"3. [在此处添加您的Prompt或更多说明]";

// =========================================================================
// 2. 核心功能接口声明
// =========================================================================
@interface UIViewController (EchoAIFinal)
- (void)performFullAnalysis;
- (void)echo_step1_extractBaseInfo:(void (^)(BOOL success))completion;
- (void)echo_step2_extractKeChuanDetails:(void (^)(BOOL success))completion;
- (void)echo_step3_extractNianMingDetails:(void (^)(BOOL success))completion;
- (void)echo_step4_assembleAndCopy;
- (NSString *)echo_extractTextFromViewHierachy:(UIView *)view;
@end


// =========================================================================
// 3. UIViewController Hooks
// =========================================================================
%hook UIViewController

// --- 添加功能按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            [button setTitle:@"高级技法解析" forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            button.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.layer.cornerRadius = 8;
            [button addTarget:self action:@selector(performFullAnalysis) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:button];
        });
    }
}

// --- 核心拦截器 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingDetails) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        // --- 拦截课传详情页 ---
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;
                    // 模拟展开
                    Class tvClass = NSClassFromString(@"六壬大占.天將摘要視圖") ?: [UITableView class];
                    NSMutableArray *tableViews = [NSMutableArray array];
                    FindSubviewsOfClassRecursive(tvClass, contentView, tableViews);
                    for (UITableView *tv in tableViews) {
                        if ([tv.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && tv.dataSource) {
                            for (int s=0; s<tv.numberOfSections; s++) for (int r=0; r<[tv numberOfRowsInSection:s]; r++) {
                                [tv.delegate tableView:tv didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:r inSection:s]];
                            }
                        }
                    }
                    // 提取文本
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSString *text = [self echo_extractTextFromViewHierachy:contentView];
                        [g_capturedData[@"keChuanDetails"] addObject:text];
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:g_capturedData[@"completionBlock"]];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }

        // --- 拦截年命摘要和格局页 (可以根据需要添加这部分逻辑) ---
        // 此处暂时留空，可以后续整合之前的年命提取逻辑

    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 4. 功能实现
// =========================================================================

%new
// --- 总控制器 ---
- (void)performFullAnalysis {
    if (g_isExtractingDetails) {
        EchoLog(@"正在执行解析，请稍候...");
        return;
    }
    EchoLog(@"--- 开始执行完整解析 ---");
    g_isExtractingDetails = YES;
    g_capturedData = [NSMutableDictionary dictionary];
    if (!g_echo_task_queue) {
        g_echo_task_queue = dispatch_queue_create("com.echoai.taskqueue", DISPATCH_QUEUE_SERIAL);
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(g_echo_task_queue, ^{
        // Step 1
        dispatch_sync(dispatch_get_main_queue(), ^{
            [weakSelf echo_step1_extractBaseInfo:^(BOOL success) {
                // Step 2
                [weakSelf echo_step2_extractKeChuanDetails:^(BOOL success) {
                    // Step 3 (年命部分暂时跳过，可后续添加)
                    // [weakSelf echo_step3_extractNianMingDetails:^(BOOL success) {
                        // Step 4
                        [weakSelf echo_step4_assembleAndCopy];
                    // }];
                }];
            }];
        });
    });
}

%new
// --- 步骤1：提取基本信息和列表 ---
- (void)echo_step1_extractBaseInfo:(void (^)(BOOL success))completion {
    EchoLog(@"[步骤1] 提取基本信息...");
    // 这部分代码从您之前的脚本中提取，用于抓取所有不需要点击的浅层信息
    // 为简化，此处只列出框架，实际需要填充您的提取代码
    g_capturedData[@"baseInfo"] = @"[此处应为提取到的时间、月将、空亡、四课三传表面文字等信息]\n";
    g_capturedData[@"bifaInfo"] = @"[此处应为提取到的毕法诀信息]\n";
    g_capturedData[@"gejuInfo"] = @"[此处应为提取到的格局信息]\n";
    
    EchoLog(@"[步骤1] 完成。");
    if (completion) completion(YES);
}


%new
// --- 步骤2：提取课传详情 ---
- (void)echo_step2_extractKeChuanDetails:(void (^)(BOOL success))completion {
    EchoLog(@"[步骤2] 提取课传详情...");
    g_capturedData[@"keChuanDetails"] = [NSMutableArray array];
    
    NSMutableArray *taskTargets = [NSMutableArray array];
    
    // 精确获取四课视图
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            id siKeViewInstance = siKeViews.firstObject;
            // 假设这些ivar名称是固定的，如果不是，需要动态获取
            NSArray *ivarNames = @[@"_日上", @"_日阴", @"_辰上", @"_辰阴"]; 
            for (NSString *ivarNameStr in ivarNames) {
                UIView *keView = GetIvarView(siKeViewInstance, [ivarNameStr UTF8String]);
                if (keView) [taskTargets addObject:keView];
            }
        }
    }
    
    // 精确获取三传视图
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanViews);
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        [taskTargets addObjectsFromArray:sanChuanViews];
    }

    if (taskTargets.count == 0) {
        EchoLog(@"[步骤2] 未找到任何课传视图，跳过。");
        if (completion) completion(YES);
        return;
    }
    
    __block void (^processNextTask)(void);
    __weak typeof(self) weakSelf = self;
    
    void (^taskCompletionBlock)(void) = ^{
        dispatch_async(g_echo_task_queue, ^{
            processNextTask();
        });
    };

    g_capturedData[@"completionBlock"] = taskCompletionBlock;
    
    processNextTask = ^{
        if (taskTargets.count == 0) {
            EchoLog(@"[步骤2] 所有课传详情提取完成。");
            g_capturedData[@"completionBlock"] = nil; // 清理
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(YES);
            });
            return;
        }
        
        id sender = taskTargets.firstObject;
        [taskTargets removeObjectAtIndex:0];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"调用 '顯示課傳摘要WithSender:' for %@", sender);
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [weakSelf performSelector:@selector(顯示課傳摘要WithSender:) withObject:sender];
            #pragma clang diagnostic pop
        });
    };
    
    // 启动第一个任务
    processNextTask();
}

%new
// --- 步骤3：提取年命详情 (留作扩展) ---
- (void)echo_step3_extractNianMingDetails:(void (^)(BOOL success))completion {
    EchoLog(@"[步骤3] 提取年命详情 (已跳过)...");
    if (completion) completion(YES);
}

%new
// --- 步骤4：整合并输出 ---
- (void)echo_step4_assembleAndCopy {
    EchoLog(@"[步骤4] 整合所有信息...");
    
    NSMutableString *finalString = [NSMutableString string];
    [finalString appendString:g_capturedData[@"baseInfo"] ?: @""];
    [finalString appendString:g_capturedData[@"bifaInfo"] ?: @""];
    [finalString appendString:g_capturedData[@"gejuInfo"] ?: @""];

    NSArray *details = g_capturedData[@"keChuanDetails"];
    if (details.count > 0) {
        [finalString appendString:@"\n\n--- 课传详情 ---\n"];
        NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
        for (NSUInteger i=0; i < details.count; i++) {
            NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目%lu", (unsigned long)i+1];
            [finalString appendFormat:@"\n[%@]\n%@\n", title, details[i]];
        }
    }
    
    [finalString appendString:CustomFooterText];
    
    [UIPasteboard generalPasteboard].string = finalString;
    EchoLog(@"--- 完整解析完成，结果已复制到剪贴板 ---");
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"解析完成" message:@"所有高级技法信息已合并，并成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    
    g_isExtractingDetails = NO;
    g_capturedData = nil;
}

%new
// --- 文本提取辅助函数 ---
- (NSString *)echo_extractTextFromViewHierachy:(UIView *)view {
    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], view, allLabels);
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        CGPoint p1 = [l1.superview convertPoint:l1.frame.origin toView:nil];
        CGPoint p2 = [l2.superview convertPoint:l2.frame.origin toView:nil];
        if (fabs(p1.y - p2.y) > 2) return p1.y < p2.y ? NSOrderedAscending : NSOrderedDescending;
        return p1.x < p2.x ? NSOrderedAscending : NSOrderedDescending;
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in allLabels) {
        if (label.text.length > 0) {
            [textParts addObject:[label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }
    NSString *raw = [textParts componentsJoinedByString:@"\n"];
    return [raw stringByReplacingOccurrencesOfString:@"\n{2,}" withString:@"\n" options:NSRegularExpressionSearch range:NSMakeRange(0, raw.length)];
}

%end
