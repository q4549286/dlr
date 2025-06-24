#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
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
@interface UIViewController (EchoAITestAddons_Atonement)
- (void)performKeChuanDetailExtractionTest_Atonement;
- (void)processKeChuanQueue_Atonement;
@end

%hook UIViewController

// --- viewDidLoad: 创建按钮 ---
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger TestButtonTag = 556692;
            if ([keyWindow viewWithTag:TestButtonTag]) { [[keyWindow viewWithTag:TestButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 80, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"课传提取(谢罪舞)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.1 blue:0.1 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_Atonement) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// --- presentViewController: 捕获弹窗并驱动队列 ---
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self processKeChuanQueue_Atonement];
                    });
                }];
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
// --- performKeChuanDetailExtractionTest_Atonement: 构建任务队列 ---
- (void)performKeChuanDetailExtractionTest_Atonement {
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *containers = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
        if (containers.count > 0) {
            UIView *sanChuanContainer = containers.firstObject;
            const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL};
            NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
            for (int i = 0; i < 3; ++i) {
                Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]);
                if (ivar) {
                    UIView *chuanView = object_getIvar(sanChuanContainer, ivar);
                    if (chuanView) {
                        NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                        if (labels.count >= 2) {
                            UILabel *dizhiLabel = labels[labels.count-2];
                            UILabel *tianjiangLabel = labels[labels.count-1];
                            [g_keChuanWorkQueue addObject:@{ @"label": dizhiLabel, @"indexPathRow": @(i), @"type": @"地支" }];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                            [g_keChuanWorkQueue addObject:@{ @"label": tianjiangLabel, @"indexPathRow": @(i), @"type": @"天将" }];
                            [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
                        }
                    }
                }
            }
        }
    }
    if (g_keChuanWorkQueue.count == 0) { g_isExtractingKeChuanDetail = NO; return; }
    [self processKeChuanQueue_Atonement];
}

%new
// --- processKeChuanQueue_Atonement: 执行“谢罪之舞” ---
- (void)processKeChuanQueue_Atonement {
    if (g_keChuanWorkQueue.count == 0) {
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_keChuanTitleQueue.count; i++) {
            NSString *title = g_keChuanTitleQueue[i];
            NSString *detail = (i < g_capturedKeChuanDetailArray.count) ? g_capturedKeChuanDetailArray[i] : @"[信息提取失败]";
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", title, detail];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"所有详情已复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:successAlert animated:YES completion:nil];
        g_isExtractingKeChuanDetail = NO; g_keChuanWorkQueue = nil; g_capturedKeChuanDetailArray = nil; g_keChuanTitleQueue = nil;
        return;
    }
    NSDictionary *task = g_keChuanWorkQueue.firstObject;
    [g_keChuanWorkQueue removeObjectAtIndex:0];
    UILabel *targetLabel = task[@"label"];
    NSInteger rowIndex = [task[@"indexPathRow"] integerValue];
    NSString *type = task[@"type"];
    UICollectionView *collectionView = nil;
    Class sanChuanCellClass = NSClassFromString(@"六壬大占.傳視圖");
    NSMutableArray *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, allCVs);
    for (UICollectionView *cv in allCVs) {
        if ([cv.visibleCells.firstObject isKindOfClass:sanChuanCellClass]) {
            collectionView = cv;
            break;
        }
    }
    if (!collectionView) { [self processKeChuanQueue_Atonement]; return; }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    id<UICollectionViewDelegate> delegate = collectionView.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }
    SEL actionToPerform = nil;
    if ([type isEqualToString:@"地支"]) { actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:"); }
    else { actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:"); }
    if ([self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:targetLabel];
        #pragma clang diagnostic pop
    } else {
        [self processKeChuanQueue_Atonement];
    }
}

// 【【【最终的、也是最耻辱的语法修正】】】
// 我将我之前愚蠢地忘记了的、最基本的 %end，添加到它本该在的地方。
%end
