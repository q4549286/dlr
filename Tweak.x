#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

// 用于控制自动化流程的状态和数据存储
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

// 递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}


// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_Truth)
- (void)performKeChuanDetailExtractionTest_Truth;
- (void)processKeChuanQueue_Truth;
@end

%hook UIViewController

// --- viewDidLoad: 在主界面加载时创建功能按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 延迟执行，确保视图层级已稳定
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) { return; }

            NSInteger testButtonTag = 556690;
            // 移除旧按钮，防止重复添加
            if ([keyWindow viewWithTag:testButtonTag]) {
                [[keyWindow viewWithTag:testButtonTag] removeFromSuperview];
            }

            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"课传提取(修正版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗内容，并驱动自动化队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        // 检查是否是我们关心的弹窗类型
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            // 隐藏弹窗动画，加速提取
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;

            // 创建一个新的completion block，在原始completion之后执行我们的逻辑
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }

                // 提取弹窗内的所有UILabel文本
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                // 按从上到下、从左到右的顺序排序Label
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];

                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        // 将多行文本合并为一行，便于处理
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];

                // 关闭当前弹窗，并在完成后触发下一个任务
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    // 【【【核心修正】】】
                    // 在关闭弹窗和处理下一个任务之间插入一个微小延迟。
                    // 这给目标App的主线程足够的时间来重置其内部状态，防止因处理速度过快而导致的数据错误。
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_Truth];
                    });
                }];
            };
            
            // 使用我们修改后的completion block来调用原始的present方法
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    // 如果不是在提取模式下，或者弹窗类型不匹配，则正常执行
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Truth: 按钮点击事件，初始化并构建任务队列 ---
- (void)performKeChuanDetailExtractionTest_Truth {
    // 初始化全局状态
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // Part A: 提取三传信息
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            
            // 使用正确的繁体中文ivar名来获取对应的视图
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        
                        if(labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            // 将地支Label和对应标题加入队列
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                            
                            // 将天将Label和对应标题加入队列
                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }
    
    // Part B: 提取四课信息
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *siKeContainer = containers.firstObject;

            // 四课的Ivar名是固定的
            const char *ivarNames[] = {"第一課", "第二課", "第三課", "第四課", NULL};
            NSString *rowTitles[] = {@"第一课", @"第二课", @"第三课", @"第四课"};

            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *keView = object_getIvar(siKeContainer, ivar);
                    if (keView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        
                        if (labels.count >= 2) {
                            // 四课的布局是上下结构，天将在上，地支在下
                            UILabel *tianjiangLabel = labels.firstObject;
                            UILabel *dizhiLabel = labels.lastObject;

                            // 将地支Label和对应标题加入队列
                            [g_keChuanWorkQueue addObject:dizhiLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];

                            // 将天将Label和对应标题加入队列
                            [g_keChuanWorkQueue addObject:tianjiangLabel];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }

    // 如果队列为空，则直接结束
    if (g_keChuanWorkQueue.count == 0) {
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    
    // 开始处理队列中的第一个任务
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 自动化队列处理器 ---
- (void)processKeChuanQueue_Truth {
    // 检查队列是否已处理完毕
    if (g_keChuanWorkQueue.count == 0) {
        // ---- 结束逻辑 ----
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        
        // 将结果复制到剪贴板并提示用户
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertControllerStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        
        // 清理全局变量，重置状态
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    // ---- 队列处理逻辑 ----
    // 取出队列头的任务
    UILabel *itemToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    // 根据标题判断应该调用哪个方法
    // 使用 g_capturedKeChuanDetailArray.count 作为当前已完成任务的索引来获取正确的标题
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];

    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else { // 天将
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    // 动态调用目标方法，模拟点击
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        // 如果方法不存在，跳过当前任务，继续处理下一个
        NSLog(@"[EchoAI_Tweak] Warning: Selector %@ not found. Skipping.", NSStringFromSelector(actionToPerform));
        [self processKeChuanQueue_Truth];
    }
}
%end
