#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数 (保持不变)
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-FinalPort] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556690; // 新的Tag
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
@interface UIViewController (EchoAITestAddons_FinalPort)
- (void)performKeChuanDetailExtractionTest_FinalPort;
- (void)processKeChuanQueue_FinalPort;
@end

%hook UIViewController

// --- viewDidLoad 和 presentViewController 保持不变 ---
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
            [testButton setTitle:@"测试课传(最终移植)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor systemRedColor];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailExtractionTest_FinalPort) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = viewControllerToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                    if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                NSMutableArray<NSString *> *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text && label.text.length > 0) {
                        [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                    }
                }
                NSString *fullDetail = [textParts componentsJoinedByString:@"\n"];
                [g_capturedKeChuanDetailArray addObject:fullDetail];
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)performKeChuanDetailExtractionTest_FinalPort {
    EchoLog(@"开始执行 [课传详情] 最终移植版测试");
    g_isExtractingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanWorkQueue = [NSMutableArray array];
    g_keChuanTitleQueue = [NSMutableArray array];

    // --- Part A: 100% 移植您原始脚本的三传解析逻辑 ---
    // 我们相信这个方法是正确的，因为您的截图证明了Y坐标是不同的
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *scViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
        
        // 关键：对找到的视图按Y坐标排序
        [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) {
            return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
        }];
        
        // 打印出找到的视图坐标，用于调试
        EchoLog(@"找到 %ld 个傳視圖，坐标如下:", (unsigned long)scViews.count);
        for(UIView *v in scViews) {
            EchoLog(@" - %@", NSStringFromCGRect(v.frame));
        }

        NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
        for (NSUInteger i = 0; i < scViews.count; i++) {
            if (i >= rowTitles.count) break;
            UIView *v = scViews[i];
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], v, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            
            if (labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count - 2];
                UILabel *tianjiangLabel = [labels lastObject];
                
                [g_keChuanWorkQueue addObject:@{@"item": dizhiLabel, @"type": @"dizhi"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]];
                
                [g_keChuanWorkQueue addObject:@{@"item": tianjiangLabel, @"type": @"tianjiang"}];
                [g_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]];
            }
        }
    }

    // --- Part B: 100% 移植您原始脚本的四课解析逻辑 (这部分一直没问题) ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        // ... 四课解析逻辑不变 ...
    }
    
    if (g_keChuanWorkQueue.count == 0) {
        EchoLog(@"测试失败: 未找到任何可点击的课传项目。");
        g_isExtractingKeChuanDetail = NO;
        return;
    }
    [self processKeChuanQueue_FinalPort];
}

%new
// --- 队列处理器 (保持不变) ---
- (void)processKeChuanQueue_FinalPort {
    // ... 队列处理逻辑不变 ...
}
%end
