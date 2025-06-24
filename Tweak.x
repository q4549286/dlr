#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局状态管理
// =========================================================================

// 自动化流程的控制标志，YES表示正在提取
static BOOL g_isExtractingKeChuanDetail = NO;
// 存储提取到的弹窗详细文本
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
// 待点击的UILabel对象队列 (工作队列)
static NSMutableArray *g_keChuanWorkQueue = nil;
// 与工作队列一一对应的标题队列
static NSMutableArray *g_keChuanTitleQueue = nil;

// 辅助函数：递归查找视图层级中所有指定类的子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}


// =========================================================================
// 2. 主功能实现
// =========================================================================
@interface UIViewController (FinalTruthAddons)
- (void)startKeChuanExtractionProcess;
- (void)processNextInKeChuanQueue;
@end

%hook UIViewController

// --- viewDidLoad: 注入功能按钮 ---
- (void)viewDidLoad {
    %orig;
    // 仅在目标App的主视图控制器中添加按钮
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 延迟执行，确保视图层级已完全加载并稳定
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) { return; }

            NSInteger buttonTag = 556699; // 使用一个新的唯一Tag
            // 如果按钮已存在，先移除，防止重复添加
            [[keyWindow viewWithTag:buttonTag] removeFromSuperview];

            UIButton *extractionButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractionButton.frame = CGRectMake(keyWindow.bounds.size.width - 160, 45 + 88, 150, 40);
            extractionButton.tag = buttonTag;
            [extractionButton setTitle:@"一键提取课传(稳定版)" forState:UIControlStateNormal];
            extractionButton.titleLabel.font = [UIFont boldSystemFontOfSize:15];
            extractionButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]; // 换个醒目的蓝色
            [extractionButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractionButton.layer.cornerRadius = 10;
            extractionButton.layer.shadowColor = [UIColor blackColor].CGColor;
            extractionButton.layer.shadowOffset = CGSizeMake(0, 2);
            extractionButton.layer.shadowOpacity = 0.3;
            [extractionButton addTarget:self action:@selector(startKeChuanExtractionProcess) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:extractionButton];
        });
    }
}

// --- presentViewController: 核心拦截逻辑 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 仅当我们的自动化流程启动时才进行拦截
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        // 判断弹出的视图是否是我们需要提取的目标
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            // 优化：隐藏弹窗过程，让提取在后台“瞬间”完成
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;

            // 创建一个新的completion闭包，在原始弹窗逻辑完成后执行我们的提取代码
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); } // 如果原始调用有completion，先执行它

                // 1. 提取文本
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                // 按从上到下、从左到右的视觉顺序排序Label
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    CGFloat y1 = roundf(o1.frame.origin.y);
                    CGFloat y2 = roundf(o2.frame.origin.y);
                    if (y1 < y2) return NSOrderedAscending;
                    if (y1 > y2) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];

                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];

                // 2. 关闭弹窗，并在关闭后驱动队列进入下一步
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 【【【最关键的稳定性修复】】】
                    // 必须延迟执行下一步！因为UI操作是异步的，立即调用会导致App内部状态未更新，
                    // 从而在下一次点击时仍然使用旧数据。0.1秒的延迟给予主线程足够的时间来“喘息”和重置状态。
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processNextInKeChuanQueue];
                    });
                }];
            };
            
            %orig(viewControllerToPresent, flag, extractionCompletion);
            return;
        }
    }
    
    // 如果不是在提取模式，或弹窗不是目标类型，则正常执行原始逻辑
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- startKeChuanExtractionProcess: 按钮点击后，准备并启动整个流程 ---
- (void)startKeChuanExtractionProcess {
    // 防止重复点击导致流程混乱
    if (g_isExtractingKeChuanDetail) {
        NSLog(@"[Tweak] 提取任务正在进行中，请勿重复点击。");
        return;
    }
    
    // 1. 初始化所有全局状态
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    NSLog(@"[Tweak] 开始构建课传提取队列...");

    // 2. 构建任务队列 - Part A: 三传
    Class sanChuanClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanClass) {
        NSMutableArray *views = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanClass, self.view, views);
        if (views.count > 0) {
            UIView *container = views.firstObject;
            const char *ivars[] = {"初傳", "中傳", "末傳"};
            NSString *titles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; i < 3; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanClass, ivars[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(container, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        if (labels.count >= 2) {
                            UILabel *dizhi = labels[labels.count-2];
                            UILabel *tianjiang = labels[labels.count-1];
                            [g_keChuanWorkQueue addObject:dizhi];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], dizhi.text]];
                            [g_keChuanWorkQueue addObject:tianjiang];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], tianjiang.text]];
                        }
                    }
                }
            }
        }
    }

    // 3. 构建任务队列 - Part B: 四课
    Class siKeClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeClass) {
        NSMutableArray *views = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeClass, self.view, views);
        if (views.count > 0) {
            UIView *container = views.firstObject;
            const char *ivars[] = {"第一課", "第二課", "第三課", "第四課"};
            NSString *titles[] = {@"第一课", @"第二课", @"第三课", @"第四课"};
            for (int i = 0; i < 4; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeClass, ivars[i]);
                if (ivar) {
                    UIView *keView = object_getIvar(container, ivar);
                    if (keView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        if (labels.count >= 2) {
                            UILabel *tianjiang = labels.firstObject;
                            UILabel *dizhi = labels.lastObject;
                            [g_keChuanWorkQueue addObject:dizhi];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], dizhi.text]];
                            [g_keChuanWorkQueue addObject:tianjiang];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], tianjiang.text]];
                        }
                    }
                }
            }
        }
    }

    // 4. 检查队列并启动
    if (g_keChuanWorkQueue.count == 0) {
        NSLog(@"[Tweak] 未找到可提取的课传信息。");
        g_isExtractingKeChuanDetail = NO; // 重置状态
        return;
    }
    
    NSLog(@"[Tweak] 队列构建完成，共 %lu 个任务。开始执行...", (unsigned long)g_keChuanWorkQueue.count);
    [self processNextInKeChuanQueue];
}

%new
// --- processNextInKeChuanQueue: 自动化队列的驱动引擎 ---
- (void)processNextInKeChuanQueue {
    // 检查队列是否已空，如果为空，则表示所有任务已完成
    if (g_keChuanWorkQueue.count == 0) {
        NSLog(@"[Tweak] 所有任务已完成。");
        // ---- 结束流程 ----
        NSMutableString *resultStr = [NSMutableString stringWithString:@"【六壬大占 - 课传详情提取结果】\n\n"];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        
        // 复制到剪贴板并弹窗提示
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成" message:[NSString stringWithFormat:@"已成功提取 %lu 条详情，并全部复制到剪贴板。", (unsigned long)g_capturedKeChuanDetailArray.count] preferredStyle:UIAlertControllerStyleAlert];
        
        // 【编译错误修复】使用正确的 UIAlertActionStyle
        [alert addAction:[UIAlertAction actionWithTitle:@"太棒了！" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        
        // 清理所有全局变量，为下一次运行做准备
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    // ---- 处理当前任务 ----
    UILabel *itemToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    // 使用已完成任务的数量来定位当前任务的标题
    NSString *currentTitle = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    NSLog(@"[Tweak] 正在处理: %@", currentTitle);

    // 根据标题内容判断应该调用哪个方法来模拟点击
    SEL actionToPerform = [currentTitle containsString:@"地支"] ? NSSelectorFromString(@"顯示課傳摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        NSLog(@"[Tweak] 错误: 方法 %@ 未找到，跳过此任务。", NSStringFromSelector(actionToPerform));
        // 即使一个任务失败，也要继续处理下一个
        [self processNextInKeChuanQueue];
    }
}

%end
