#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-Truth-V5-Debug] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690;
static BOOL g_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanWorkQueue = nil;
static NSMutableArray *g_keChuanTitleQueue = nil;

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

// --- viewDidLoad 和 presentViewController 保持稳定，无需修改 ---
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; } if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; } UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36); testButton.tag = TestButtonTag; [testButton setTitle:@"测试课传(真理版)" forState:UIControlStateNormal]; testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16]; testButton.backgroundColor = [UIColor systemGreenColor]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; testButton.layer.cornerRadius = 8; [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside]; [keyWindow addSubview:testButton]; }); } }
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion { if (g_isExtractingKeChuanDetail) { NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]); if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) { viewControllerToPresent.view.alpha = 0.0f; flag = NO; void (^newCompletion)(void) = ^{ if (completion) { completion(); } UIView *contentView = viewControllerToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray<NSString *> *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } } NSString *fullDetail = [textParts componentsJoinedByString:@"\n"]; [g_capturedKeChuanDetailArray addObject:fullDetail]; [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{ [self processKeChuanQueue_Truth]; }]; }; %orig(viewControllerToPresent, flag, newCompletion); return; } } %orig(viewControllerToPresent, flag, completion); }

%new
- (void)performKeChuanDetailExtractionTest_Truth {
    EchoLog(@"开始执行 [课传详情] 真理版测试 V5 (带视觉调试)");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    // ======================= 【【【核心修正点 V5】】】 =======================
    // 1. 精准找到父容器 `三傳視圖`
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanContainers = [NSMutableArray array];
    if (sanChuanContainerClass) {
        FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, sanChuanContainers);
    }
    
    if (sanChuanContainers.count > 0) {
        UIView *sanChuanContainer = sanChuanContainers.firstObject;
        
        // 2. 在父容器内，找到所有的子传视图 `傳視圖`
        Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
        NSMutableArray *allChuanViews = [NSMutableArray array];
        if (chuanViewClass) {
            for (UIView *subview in sanChuanContainer.subviews) {
                if ([subview isKindOfClass:chuanViewClass]) {
                    [allChuanViews addObject:subview];
                }
            }
        }
        
        // 3. 【最终方案】直接比较它们相对于父容器的 frame.origin.y 进行排序
        [allChuanViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
            CGFloat y1 = v1.frame.origin.y;
            CGFloat y2 = v2.frame.origin.y;
            if (y1 < y2) return NSOrderedAscending;
            if (y1 > y2) return NSOrderedDescending;
            return NSOrderedSame;
        }];
        
        // 4. 【视觉调试】为排序后的视图添加不同颜色的边框
        NSArray *debugColors = @[[UIColor greenColor], [UIColor blueColor], [UIColor redColor]];
        for (NSUInteger i = 0; i < allChuanViews.count; i++) {
            if (i >= debugColors.count) break;
            UIView *chuanView = allChuanViews[i];
            chuanView.layer.borderColor = [debugColors[i] CGColor];
            chuanView.layer.borderWidth = 3.0f; // 加粗边框使其明显
        }

        // 延迟2秒，让你能看清颜色标记，然后再继续执行
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 5. 按排好的顺序准备点击任务
            NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
            for (NSUInteger i = 0; i < allChuanViews.count; i++) {
                if (i >= rowTitles.count) break;
                
                UIView *chuanView = allChuanViews[i];
                // 恢复边框
                chuanView.layer.borderWidth = 0.0f;
                
                EchoLog(@"正在处理 %@, 相对Y坐标: %f", rowTitles[i], chuanView.frame.origin.y);

                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                
                if (labels.count >= 2) {
                    UILabel *dizhiLabel = labels[labels.count - 2];
                    UILabel *tianjiangLabel = labels[labels.count - 1];
                    
                    [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                    
                    [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
                    [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                }
            }
            
            // （四课逻辑保持不变，这里省略以保持简洁，实际代码中应保留）
            // ... 四课代码 ...

            if (g_keChuanWorkQueue.count == 0) {
                EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
                g_isExtractingKeChuanDetail = NO;
                return;
            }
            // 开始处理队列
            [self processKeChuanQueue_Truth];
        });

    } else {
        EchoLog(@"错误：未能找到'六壬大占.三傳視圖'容器，无法解析三传。");
    }
}

// 队列处理器保持不变
%new
- (void)processKeChuanQueue_Truth { if (g_keChuanWorkQueue.count == 0) { EchoLog(@"[课传详情] 测试处理完毕"); NSMutableString *resultStr = [NSMutableString string]; for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) { NSString *title = g_keChuanTitleQueue[i]; NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]"; [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail]; } [UIPasteboard generalPasteboard].string = resultStr; UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"真理版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert]; [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]]; [self presentViewController:successAlert animated:YES completion:nil]; g_isExtractingKeChuanDetail = NO; g_keChuanWorkQueue = nil; g_capturedKeChuanDetailArray = nil; g_keChuanTitleQueue = nil; return; } NSDictionary *task = g_keChuanWorkQueue.firstObject; [g_keChuanWorkQueue removeObjectAtIndex:0]; UIView *itemToClick = task[@"item"]; NSString *itemType = task[@"type"]; SEL actionToPerform = nil; if ([itemType isEqualToString:@"dizhi"]) { actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:"); } else if ([itemType isEqualToString:@"tianjiang"]) { actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:"); } if (actionToPerform && [self respondsToSelector:actionToPerform]) { #pragma clang diagnostic push #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
[self performSelector:actionToPerform withObject:itemToClick]; #pragma clang diagnostic pop
} else { EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。将跳过并处理下一个。", itemType); [self processKeChuanQueue_Truth]; } }
%end
