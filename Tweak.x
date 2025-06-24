#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量、宏定义与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog((@"[EchoAI-Test-V2] " format), ##__VA_ARGS__)

static const NSInteger MainButtonTag = 112244;
static const NSInteger ProgressViewTag = 556677;

// --- 异步提取状态变量 ---
static BOOL g_isExtractingDetails = NO;
static NSMutableDictionary *g_capturedDetails = nil; // 存储抓取到的详细信息
static NSMutableArray *g_workQueue = nil; // 任务队列
static void (^g_completionBlock)(void) = nil; // 任务完成后的回调

// --- 辅助函数：必须在使用前定义 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}


// =========================================================================
// 2. 核心功能 - 视图控制器扩展
// =========================================================================

// --- 接口声明：告诉编译器我们将要实现这些新方法 ---
@interface UIViewController (EchoAIExtraction)
- (void)performDetailedExtractionTest;
- (void)processNextQueueItem; // 修复点：添加此方法的声明
@end

%hook UIViewController

// --- 界面入口：添加按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            if ([keyWindow viewWithTag:MainButtonTag]) { [[keyWindow viewWithTag:MainButtonTag] removeFromSuperview]; }
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            testButton.tag = MainButtonTag;
            [testButton setTitle:@"高级技法解析" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performDetailedExtractionTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- 核心钩子：拦截弹窗 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingDetails && [viewControllerToPresent isKindOfClass:NSClassFromString(@"六壬大占.註解視圖控制器")]) {
        flag = NO; // 无动画快速呈现
        void (^newCompletion)(void) = ^{
            if (completion) completion();
            
            // 弹窗出现后，立即提取内容
            UIView *contentView = viewControllerToPresent.view;
            NSMutableArray<UILabel *> *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, labels); // 此处调用现在是安全的
            [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
            }];
            
            NSString *title = @"";
            NSMutableString *description = [NSMutableString string];
            
            if (labels.count > 0) {
                title = labels.firstObject.text ?: @"";
                for (NSUInteger i = 1; i < labels.count; i++) {
                    [description appendFormat:@"%@\n", labels[i].text ?: @""];
                }
            }
            
            NSString *fullText = [NSString stringWithFormat:@"%@\n%@", title, description];
            
            // 将提取到的内容存入字典
            NSString *key = (NSString *)g_workQueue.firstObject[@"key"];
            if (key) {
                g_capturedDetails[key] = [fullText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                EchoLog(@"成功捕获 [%@] 的信息", key);
            }
            
            // 关闭弹窗
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                 // 弹窗关闭后，处理下一个任务
                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (g_workQueue.count > 0) { // 检查数组是否为空
                        [g_workQueue removeObjectAtIndex:0];
                    }
                    if (g_workQueue.count > 0) {
                        [(UIViewController *)self.view.window.rootViewController performSelector:@selector(processNextQueueItem)];
                    } else {
                        if (g_completionBlock) {
                            g_completionBlock();
                        }
                    }
                });
            }];
        };
        %orig(viewControllerToPresent, flag, newCompletion);
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)processNextQueueItem {
    if (!g_workQueue || g_workQueue.count == 0) return;

    NSDictionary *task = g_workQueue.firstObject;
    UIView *targetLabel = task[@"label"];
    
    // 找到包含这个Label的父Cell
    UIView *parentCell = targetLabel;
    while (parentCell && ![parentCell isKindOfClass:[UICollectionViewCell class]]) {
        parentCell = parentCell.superview;
    }
    
    if (!parentCell) {
        EchoLog(@"错误：无法为Label [%@] 找到父Cell", ((UILabel *)targetLabel).text);
        // 跳过这个任务
        [g_workQueue removeObjectAtIndex:0];
        if (g_workQueue.count > 0) {
            [self processNextQueueItem]; // 此处调用现在是安全的
        } else {
            if (g_completionBlock) g_completionBlock();
        }
        return;
    }

    // 找到Cell所在的CollectionView
    UIView *collectionView = parentCell.superview;
    while (collectionView && ![collectionView isKindOfClass:[UICollectionView class]]) {
        collectionView = collectionView.superview;
    }
    
    if (collectionView && [collectionView isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)collectionView;
        NSIndexPath *indexPath = [cv indexPathForCell:(UICollectionViewCell *)parentCell];
        if (indexPath && [cv.delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            EchoLog(@"模拟点击: [%@]", ((UILabel *)targetLabel).text);
            [cv.delegate collectionView:cv didSelectItemAtIndexPath:indexPath];
        } else {
             EchoLog(@"错误：无法为 [%@] 执行点击", ((UILabel *)targetLabel).text);
        }
    } else {
         EchoLog(@"错误：无法为 [%@] 找到父CollectionView", ((UILabel *)targetLabel).text);
    }
}


%new
- (void)performDetailedExtractionTest {
    EchoLog(@"--- 开始执行详细信息提取测试 ---");
    
    g_isExtractingDetails = YES;
    g_capturedDetails = [NSMutableDictionary dictionary];
    g_workQueue = [NSMutableArray array];

    // --- 1. 查找所有可点击的Label ---
    NSMutableArray<UILabel *> *allClickableLabels = [NSMutableArray array]; // 改为强类型
    
    // 查找四课和三传的容器视图
    NSArray *viewClassNames = @[@"六壬大占.四課視圖", @"六壬大占.傳視圖"];
    for (NSString *className in viewClassNames) {
        Class viewClass = NSClassFromString(className);
        if (viewClass) {
            NSMutableArray *containerViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive(viewClass, self.view, containerViews); // 此处调用现在是安全的
            for (UIView *container in containerViews) {
                NSMutableArray<UILabel *> *labelsInContainer = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], container, labelsInContainer);
                
                for (UILabel *label in labelsInContainer) {
                    // **核心判断逻辑：通过颜色识别**
                    // 非黑色、非深灰色、非白色的都认为是彩色可点击
                    CGFloat red, green, blue, alpha;
                    [label.textColor getRed:&red green:&green blue:&blue alpha:&alpha];
                    // 简单判断：只要不是接近灰色的都算 (r,g,b分量差别大)
                    if (fabs(red - green) > 0.05 || fabs(red - blue) > 0.05 || fabs(green - blue) > 0.05) {
                        [allClickableLabels addObject:label];
                    }
                }
            }
        }
    }
    
    if (allClickableLabels.count == 0) {
        EchoLog(@"错误：未能找到任何可点击的彩色标签。");
        g_isExtractingDetails = NO;
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"提取失败" message:@"未能找到任何可点击的彩色标签。请检查App界面。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        return;
    }

    // --- 2. 建立任务队列 ---
    // 按界面位置从上到下，从左到右排序
    [allClickableLabels sortUsingComparator:^NSComparisonResult(UILabel *v1, UILabel *v2) {
        if (roundf(v1.frame.origin.y) < roundf(v2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(v1.frame.origin.y) > roundf(v2.frame.origin.y)) return NSOrderedDescending;
        return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
    }];

    // 建立任务队列，并过滤掉三传中的地盘（最下面一行）
    NSMutableArray *finalWorkQueue = [NSMutableArray array];
    // 找出三传区域的Y坐标边界
    CGFloat sanChuanTopY = CGFLOAT_MAX;
    Class sanChuanClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanClass, self.view, sanChuanViews);
        if (sanChuanViews.count > 0) {
            sanChuanTopY = ((UIView *)sanChuanViews.firstObject).frame.origin.y;
        }
    }

    // 按列分组
    NSMutableDictionary *columns = [NSMutableDictionary dictionary];
    for (UILabel *label in allClickableLabels) {
        NSString *key = [NSString stringWithFormat:@"%.0f", roundf(label.center.x)];
        if (!columns[key]) {
            columns[key] = [NSMutableArray array];
        }
        [columns[key] addObject:label];
    }
    
    for (NSString *key in columns) {
        NSMutableArray *columnLabels = columns[key];
        // 如果该列在三传区域，并且元素多于2个，则只取前2个
        if (columnLabels.count > 0 && ((UILabel *)columnLabels.firstObject).frame.origin.y >= sanChuanTopY) {
            if (columnLabels.count > 2) {
                // 按Y坐标排序，只取前两个
                [columnLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
                    return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)];
                }];
                [finalWorkQueue addObject:columnLabels[0]];
                [finalWorkQueue addObject:columnLabels[1]];
            } else {
                 [finalWorkQueue addObjectsFromArray:columnLabels];
            }
        } else { // 四课区域的全部加入
            [finalWorkQueue addObjectsFromArray:columnLabels];
        }
    }
    
    // 重新排序最终队列
    [finalWorkQueue sortUsingComparator:^NSComparisonResult(UILabel *v1, UILabel *v2) {
        if (roundf(v1.frame.origin.y) < roundf(v2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(v1.frame.origin.y) > roundf(v2.frame.origin.y)) return NSOrderedDescending;
        return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
    }];

    for (UILabel *label in finalWorkQueue) {
        NSString *uniqueKey = [NSString stringWithFormat:@"%@ (%.0f,%.0f)", label.text, label.frame.origin.x, label.frame.origin.y];
        [g_workQueue addObject:@{@"label": label, @"key": uniqueKey, @"original_text": label.text}];
    }
    
    EchoLog(@"建立任务队列，共 %ld 个项目。", g_workQueue.count);

    // --- 3. 设置完成后的回调 ---
    __weak typeof(self) weakSelf = self;
    g_completionBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        EchoLog(@"--- 所有任务完成，正在整理结果 ---");
        
        NSMutableString *finalReport = [NSMutableString stringWithString:@"【四课三传详细信息提取报告】\n\n"];
        
        // 按原始顺序输出结果
        for (NSDictionary *task in g_workQueue) {
            NSString *originalText = task[@"original_text"];
            NSString *key = task[@"key"];
            NSString *details = g_capturedDetails[key] ?: @"[信息提取失败]";
            
            [finalReport appendFormat:@"---- %@ ----\n%@\n\n", originalText, details];
        }

        [UIPasteboard generalPasteboard].string = finalReport;
        
        // 清理全局变量
        g_isExtractingDetails = NO;
        g_capturedDetails = nil;
        g_workQueue = nil;
        g_completionBlock = nil;
        
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"测试完成" message:[NSString stringWithFormat:@"成功提取 %ld 条详细信息，已全部复制到剪贴板。", (unsigned long)g_capturedDetails.count] preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [strongSelf presentViewController:successAlert animated:YES completion:nil];
    };

    // --- 4. 启动任务队列 ---
    if (g_workQueue.count > 0) {
        [self processNextQueueItem];
    } else {
         if (g_completionBlock) g_completionBlock();
    }
}

%end
