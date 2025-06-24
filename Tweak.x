#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (与V8相同)
// =========================================================================
static UITextView *g_screenLogger = nil;

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
            [testButton setTitle:@"测试课传(V9最终版)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]; // 蓝色
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
        // 【V9修改】现在弹窗可能不再是那两种，我们需要更通用的捕获方式。
        // 但根据之前的经验，弹窗类型应该是固定的。我们先保持这个检查。
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            NSString *expectedTitle = @"未知项目";
            if (g_capturedKeChuanDetailArray.count < g_keChuanTitleQueue.count) {
                expectedTitle = g_keChuanTitleQueue[g_capturedKeChuanDetailArray.count];
            }
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
- (void)performKeChuanDetailExtractionTest_Truth {
    g_screenLogger.text = @"";
    EchoLog(@"开始V9最终决战测试...");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    
    // 1. 找到作为容器的 UICollectionView
    UICollectionView *targetCollectionView = nil;
    NSMutableArray *allCVs = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, allCVs);
    
    // 我们需要一种方法来唯一识别出包含三传的那个CV
    // 假设它内部的Cell是 `六壬大占.傳視圖`
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (chuanViewClass) {
        for (UICollectionView *cv in allCVs) {
            // 刷新并获取可见cell
            [cv layoutIfNeeded];
            NSArray<__kindof UICollectionViewCell *> *cells = [cv visibleCells];
            if (cells.count > 0 && [cells.firstObject isKindOfClass:chuanViewClass]) {
                targetCollectionView = cv;
                break;
            }
        }
    }
    
    if (!targetCollectionView) {
        EchoLog(@"致命错误: 未能找到包含'傳視圖'的UICollectionView!");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    EchoLog(@"成功定位目标CV: <%@: %p>", [targetCollectionView class], targetCollectionView);

    // 2. 构建任务队列。现在任务不再是点击UILabel，而是调用代理方法
    // 假设三传在第0个section，item分别是0, 1, 2
    // 假设地支摘要和天将摘要是同一个cell点击后弹出的不同内容，或者需要某种方式区分。
    // 我们先做一个大胆的假设：App内部根据一个状态来决定显示地支还是天将摘要。
    // 我们将为每个传连续调用两次 `didSelectItem`，期望它能交替显示地支和天将。
    
    NSArray *chuanTitles = @[@"初传", @"中传", @"末传"];
    for (NSInteger i = 0; i < chuanTitles.count; i++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForItem:i inSection:0]; // 假设都在section 0
        
        // 第一次点击，期望是地支
        NSString *dizhiTitle = [NSString stringWithFormat:@"%@ - 地支", chuanTitles[i]];
        [g_keChuanWorkQueue addObject:@{@"cv": targetCollectionView, @"indexPath": indexPath, @"title": dizhiTitle}];
        [g_keChuanTitleQueue addObject:dizhiTitle];
        
        // 第二次点击，期望是天将
        NSString *tianjiangTitle = [NSString stringWithFormat:@"%@ - 天将", chuanTitles[i]];
        [g_keChuanWorkQueue addObject:@{@"cv": targetCollectionView, @"indexPath": indexPath, @"title": tianjiangTitle}];
        [g_keChuanTitleQueue addObject:tianjiangTitle];
    }
    
    if (g_keChuanWorkQueue.count == 0) { EchoLog(@"测试失败: 未构建队列."); g_isExtractingKeChuanDetail = NO; return; }
    EchoLog(@"队列构建完成,共%lu项。开始处理...", (unsigned long)g_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth];
}

%new
// ================== 【【【V9核心修改：模拟调用代理方法】】】 ==================
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
    NSString *title = task[@"title"];
    
    id<UICollectionViewDelegate> delegate = cv.delegate;

    EchoLog(@"处理任务: %@\n将为CV<%p>调用代理方法\ndidSelectItemAtIndexPath: [%ld-%ld]", title, cv, (long)indexPath.section, (long)indexPath.item);

    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:cv didSelectItemAtIndexPath:indexPath];
    } else {
        EchoLog(@"错误: CV的delegate不存在或不响应代理方法!");
        // 即使出错也要继续，避免卡死
        [self processKeChuanQueue_Truth];
    }
}
%end
