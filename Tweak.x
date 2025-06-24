#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (与V8相同)
// =========================================================================
static UITextView *g_screenLogger = nil;
#define EchoLog(format, ...) do { /* ... 与V8相同 ... */ } while (0)
// ... 其他全局变量和辅助函数与V8相同 ...

#define EchoLog(format, ...) \
    do { \
        NSString *logMessage = [NSString stringWithFormat:format, ##__VA_ARGS__]; \
        NSLog(@"[KeChuan-Test-Truth-V9-Delegate] %@", logMessage); \
        if (g_screenLogger) { \
            dispatch_async(dispatch_get_main_queue(), ^{ \
                NSString *newText = [NSString stringWithFormat:@"%@\n- %@", g_screenLogger.text, logMessage]; \
                if (newText.length > 2000) { newText = [newText substringFromIndex:newText.length - 2000]; } \
                g_screenLogger.text = newText; \
                [g_screenLogger scrollRangeToVisible:NSMakeRange(g_screenLogger.text.length - 1, 1)]; \
            }); \
        } \
    } while (0)

static NSInteger const TestButtonTag = 556690;
static NSInteger const LoggerViewTag = 778899;
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

// viewDidLoad 和 presentViewController 保持稳定
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
            [testButton setTitle:@"测试课传(V9决战)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.5 blue:0.9 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Truth) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            if ([keyWindow viewWithTag:LoggerViewTag]) { [[keyWindow viewWithTag:LoggerViewTag] removeFromSuperview]; }
            UITextView *logger = [[UITextView alloc] initWithFrame:CGRectMake(10, 45, keyWindow.bounds.size.width - 170, 150)];
            logger.tag = LoggerViewTag;
            logger.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
            logger.textColor = [UIColor cyanColor];
            logger.font = [UIFont monospacedSystemFontOfSize:10 weight:UIFontWeightRegular];
            logger.editable = NO;
            logger.layer.borderColor = [UIColor cyanColor].CGColor;
            logger.layer.borderWidth = 1.0;
            logger.layer.cornerRadius = 5;
            g_screenLogger = logger;
            [keyWindow addSubview:g_screenLogger];
        });
    }
}
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            NSString *expectedTitle = @"未知项目";
            if (g_capturedKeChuanDetailArray.count < g_keChuanTitleQueue.count) { expectedTitle = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count]; }
            EchoLog(@"捕获弹窗 for [%@]", expectedTitle);
            viewControllerToPresent.view.alpha = 0.0f; flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{ [self processKeChuanQueue_Truth]; }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// ================== 【【【V9核心修改：识别CollectionView并构建任务】】】 ==================
- (void)performKeChuanDetailExtractionTest_Truth {
    g_screenLogger.text = @"";
    EchoLog(@"开始V9决战测试...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // 1. 找到所有的 CollectionView
    NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, allCVs);
    EchoLog(@"找到 %lu 个 CollectionView", (unsigned long)allCVs.count);

    if (allCVs.count == 0) {
        EchoLog(@"错误: 未找到任何CollectionView!");
        return;
    }
    
    // 2. 遍历所有找到的 CollectionView，从中提取任务
    // 我们假设三传和四课在不同的CV或者同一个CV的不同section
    for (UICollectionView *cv in allCVs) {
        id<UICollectionViewDataSource> dataSource = cv.dataSource;
        if (!dataSource) continue;

        NSInteger sections = 1;
        if ([dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)]) {
            sections = [dataSource numberOfSectionsInCollectionView:cv];
        }

        for (NSInteger section = 0; section < sections; section++) {
            NSInteger items = [dataSource collectionView:cv numberOfRowsInSection:section];
            for (NSInteger item = 0; item < items; item++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                UICollectionViewCell *cell = [cv cellForItemAtIndexPath:indexPath];
                
                // 如果cell不在屏幕上，dataSource方法也可以
                if (!cell) {
                    if ([dataSource respondsToSelector:@selector(collectionView:cellForItemAtIndexPath:)]) {
                         cell = [dataSource collectionView:cv cellForItemAtIndexPath:indexPath];
                    }
                }
                if (!cell) continue;

                // 从Cell中提取文本来判断它是什么
                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                if (labels.count == 0) continue;

                // 简单的启发式规则来判断是三传还是四课cell
                // 三传cell通常有3个以上label（六亲，地支，天将），四课通常有2个（天将，地支）
                // 这个规则可能需要根据实际情况微调
                
                NSString *title;
                // 这是一个非常粗略的判断，需要根据实际情况调整
                // 我们可以通过cell的类名来判断，如果它有特定类名的话
                if (labels.count >= 3 && [[labels[0] text] length] <= 2) { // 可能是三传
                    title = [NSString stringWithFormat:@"三传Cell S:%ld I:%ld", (long)section, (long)item];
                } else if (labels.count >= 2) { // 可能是四课
                    title = [NSString stringWithFormat:@"四课Cell S:%ld I:%ld", (long)section, (long)item];
                } else {
                    continue;
                }

                EchoLog(@"发现任务: %@, 对应cell: <%@: %p>", title, [cell class], cell);

                // 【V9核心】我们的任务现在是CollectionView和IndexPath！
                // 我们需要两次点击，一次地支，一次天将
                [g_keChuanWorkQueue addObject:@{@"cv": cv, @"indexPath": indexPath, @"type": @"dizhi"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支", title]];
                
                [g_keChuanWorkQueue addObject:@{@"cv": cv, @"indexPath": indexPath, @"type": @"tianjiang"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将", title]];
            }
        }
    }
    
    if (g_keChuanWorkQueue.count == 0) { EchoLog(@"测试失败: 未构建任何CV任务."); g_isExtractingKeChuanDetail = NO; return; }
    EchoLog(@"队列构建完成,共%lu项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// ================== 【【【V9核心修改：调用didSelectItemAtIndexPath】】】 ==================
- (void)processKeChuanQueue_Truth {
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"所有任务完成! 生成结果.");
        g_isExtractingKeChuanDetail = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ g_screenLogger.text = @"测试完成。请检查剪贴板。"; });
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        return;
    }
    
    NSDictionary *task = g_keChuanWorkQueue.firstObject; [g_keChuanWorkQueue removeObjectAtIndex:0];
    UICollectionView *cv = task[@"cv"];
    NSIndexPath *indexPath = task[@"indexPath"];
    NSString *type = task[@"type"]; // 'dizhi' or 'tianjiang'

    id<UICollectionViewDelegate> delegate = cv.delegate;
    
    // 这里有一个难题：didSelectItemAtIndexPath只有一个，它怎么区分地支和天将？
    // 答案是：它很可能不区分！点击cell就是点击cell，弹出的内容由cell自身决定
    // 或者，它内部通过某种状态切换。我们先假设点击cell就会弹出正确的地支/天将弹窗
    // 但我们的钩子是通用的，所以我们无法区分。
    // 为了模拟，我们在这里假设，didSelectItemAtIndexPath 会处理一切。
    // 但是，由于我们一个cell要点击两次，这可能会导致问题。
    // 【重大简化】我们先假设每次点击cell只对应一个弹窗。所以一个cell只处理一次。
    
    // 为避免重复处理同一个cell，我们检查一下
    if ([type isEqualToString:@"tianjiang"]) {
        // 如果是天将任务，我们跳过，因为地支任务已经点击过这个cell了
        // 这是一个临时方案，如果地支和天将弹窗内容不同，说明有更复杂的机制
        EchoLog(@"跳过 %@ 的天将任务，因为cell已在地支任务中处理", indexPath);
        [self processKeChuanQueue_Truth];
        return;
    }

    NSString *title = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
    EchoLog(@"处理任务: %@\n将调用 didSelectItemAtIndexPath", title);

    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        EchoLog(@"在代理 <%@: %p> 上调用方法...", [delegate class], delegate);
        [delegate collectionView:cv didSelectItemAtIndexPath:indexPath];
    } else {
        EchoLog(@"警告: 未找到代理或代理未实现didSelectItemAtIndexPath!");
        [self processKeChuanQueue_Truth]; // 继续下一个
    }
}
%end
