#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;            // 存储需要点击的【容器视图】
static NSMutableArray *g_keChuanTitleQueue = nil;           // 存储每个详情对应的标题

// 递归查找指定类的所有子视图
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

// --- viewDidLoad: 创建按钮 (保持不变) ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger TestButtonTag = 556690;
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"课传提取(修复版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemGreenColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 (保持不变) ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        // 捕获“课传摘要”或“天将摘要”弹窗
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            // 隐藏弹窗，加速处理
            viewControllerToPresent.view.alpha = 0.0f; 
            flag = NO;
            
            // 创建新的完成回调，在原回调之后执行我们的逻辑
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                
                // 按从上到下，从左到右的顺序排序标签
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                // 提取所有标签文本并合并
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                
                // 关闭当前弹窗，然后立即处理队列中的下一个任务
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    [self processKeChuanQueue_Truth];
                }];
            };
            
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    // 对于其他所有情况，正常显示弹窗
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Truth: 构建任务队列 (已修正和扩展) ---
- (void)performKeChuanDetailExtractionTest_Truth {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // ================= Part A: 提取三传信息 =================
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            
            // 使用正确的繁体中文ivar名来获取每个传的容器视图
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            
            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    // 从ivar获取代表“初传”、“中传”或“末传”的那个容器视图 (chuanView)
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        // 查找内部的UILabel，仅为了获取文本来构建标题
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        
                        if(labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            
                            // 【【关键修正】】: 队列中存储的是chuanView，而不是UILabel
                            // 为“地支”添加一个任务
                            [g_keChuanWorkQueue addObject:chuanView];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text ?: @"?"]];
                            
                            // 为“天将”添加一个任务
                            [g_keChuanWorkQueue addObject:chuanView];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text ?: @"?"]];
                        }
                    }
                }
            }
        }
    }
    
    // ================= Part B: 提取四课信息 (已添加) =================
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeContainerClass) {
        NSMutableArray *containers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *siKeContainer = containers.firstObject;

            const char *ivarNames[] = {"第一課", "第二課", "第三課", "第四課", NULL};
            NSString *rowTitles[] = {@"第一课", @"第二课", @"第三课", @"第四课"};

            for (int i = 0; ivarNames[i] != NULL; ++i) {
                Ivar ivar = class_getInstanceVariable(siKeContainerClass, ivarNames[i]);
                if (ivar) {
                    // 获取代表“第X课”的容器视图 (keView)
                    UIView *keView = object_getIvar(siKeContainer, ivar);
                    if (keView) {
                        NSMutableArray *labels = [NSMutableArray array];
                        FindSubviewsOfClassRecursive([UILabel class], keView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                        
                        if(labels.count >= 3) {
                            UILabel *dizhiLabel = labels[2];     // 天盘
                            UILabel *tianjiangLabel = labels[1]; // 天将
                            
                            // 为“地支”添加一个任务
                            [g_keChuanWorkQueue addObject:keView];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text ?: @"?"]];
                            
                            // 为“天将”添加一个任务
                            [g_keChuanWorkQueue addObject:keView];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text ?: @"?"]];
                        }
                    }
                }
            }
        }
    }

    // 如果队列为空，则直接结束
    if (g_keChuanWorkQueue.count == 0) {
        g_isExtractingKeChuanDetail = NO;
        // 可以加一个提示，说没有找到课传信息
        return;
    }
    
    // 开始处理队列中的第一个任务
    [self processKeChuanQueue_Truth];
}

%new
// --- processKeChuanQueue_Truth: 处理队列，触发弹窗 (保持不变) ---
- (void)processKeChuanQueue_Truth {
    // 如果队列已空，说明所有任务完成
    if (g_keChuanWorkQueue.count == 0) {
        // 整理所有提取到的数据
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        
        // 复制到剪贴板并提示用户
        if (resultStr.length > 0) {
            [UIPasteboard generalPasteboard].string = resultStr;
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有三传和四课的详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:successAlert animated:YES completion:nil];
        }
        
        // 重置所有全局状态
        g_isExtractingKeChuanDetail = NO;
        g_keChuanWorkQueue = nil;
        g_capturedKeChuanDetailArray = nil;
        g_keChuanTitleQueue = nil;
        return;
    }
    
    // 从队列中取出一个任务（现在是容器视图）
    UIView *itemToClick = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    
    // 根据当前已捕获详情的数量，从标题队列中获取对应的标题
    // 这个标题可以帮助我们判断应该调用哪个方法
    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];

    // 根据标题内容决定要执行的动作
    SEL actionToPerform = nil;
    if ([title containsString:@"地支"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else { // 包含“天将”
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }
    
    if ([self respondsToSelector:actionToPerform]) {
        // 使用 performSelector 触发方法，将容器视图作为 sender 传入
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        // 如果方法不存在，记录一个空信息并继续处理下一个任务，以防卡死
        [g_capturedKeChuanDetailArray addObject:@"[错误：方法未找到]"];
        [self processKeChuanQueue_Truth];
    }
}
%end
