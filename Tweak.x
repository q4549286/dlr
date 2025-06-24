#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[EchoAI-Test-KCD-V4.1] " format, ##__VA_ARGS__)

// --- 全局状态变量 ---
static BOOL g_isTestingKeChuanDetail = NO;
static NSMutableArray *g_capturedKeChuanDetailArray = nil;
static NSMutableArray *g_keChuanTaskQueue = nil;
static void (^g_processQueueBlock)(void) = nil;


// --- 辅助函数 ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarView(id object, const char *ivarName) {
    Ivar ivar = class_getInstanceVariable([object class], ivarName);
    if (ivar) {
        return object_getIvar(object, ivar);
    }
    EchoLog(@"警告: 未能找到名为 %s 的实例变量。", ivarName);
    return nil;
}


// --- 声明 ---
@interface UIViewController (EchoAITestAddons)
- (void)performKeChuanDetailTest;
- (NSString *)extractTextFromViewHierachy:(UIView *)view;
- (void)triggerTapOnView:(UIView *)view;
@end


// =========================================================================
// 主 Hook
// =========================================================================
%hook UIViewController

// 1. 添加测试按钮
- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            NSInteger testButtonTag = 999111; if ([keyWindow viewWithTag:testButtonTag]) { [[keyWindow viewWithTag:testButtonTag] removeFromSuperview]; }
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 90, 140, 36);
            testButton.tag = testButtonTag;
            [testButton setTitle:@"测试课传详情V4" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            testButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.5 alpha:1.0]; // 紫色
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performKeChuanDetailTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// 2. 拦截详情窗口
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isTestingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([vcClassName isEqualToString:@"六壬大占.課傳摘要視圖"]) {
            EchoLog(@"捕获到 '課傳摘要視圖'...");
            
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                EchoLog(@"'課傳摘要視圖' 已显示，开始模拟展开和提取...");
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;
                    Class tableViewClass = NSClassFromString(@"六壬大占.天將摘要視圖") ?: NSClassFromString(@"六壬大占.IntrinsicTableView") ?: [UITableView class];
                    NSMutableArray *tableViews = [NSMutableArray array];
                    FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
                    
                    if (tableViews.count > 0) {
                         EchoLog(@"找到 %lu 个 TableView，尝试展开...", (unsigned long)tableViews.count);
                         for (UITableView *theTableView in tableViews) {
                            if ([theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && theTableView.dataSource) {
                                id<UITableViewDelegate> delegate = theTableView.delegate;
                                id<UITableViewDataSource> dataSource = theTableView.dataSource;
                                NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:theTableView] : 1;
                                for (NSInteger section = 0; section < sections; section++) {
                                    NSInteger rows = [dataSource tableView:theTableView numberOfRowsInSection:section];
                                    for (NSInteger row = 0; row < rows; row++) {
                                        [delegate tableView:theTableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                                    }
                                }
                            }
                         }
                    }
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSString *detailText = [self extractTextFromViewHierachy:contentView];
                        [g_capturedKeChuanDetailArray addObject:detailText];
                        EchoLog(@"内容提取完成，关闭详情页。");
                        
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                             if (g_processQueueBlock) { g_processQueueBlock(); }
                        }];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 新增的功能实现
// =========================================================================
%new
// 3. 核心测试逻辑 (最终版)
- (void)performKeChuanDetailTest {
    EchoLog(@"--- 开始测试四课三传详情提取 V4.1 ---");
    g_isTestingKeChuanDetail = YES;
    g_capturedKeChuanDetailArray = [NSMutableArray array];
    g_keChuanTaskQueue = [NSMutableArray array];

    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array]; 
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            id siKeViewInstance = siKeViews.firstObject;
            NSArray *ivarNames = @[@"_日上", @"_日阴", @"_辰上", @"_辰阴"];
            for (NSString *ivarNameStr in ivarNames) {
                UIView *keView = GetIvarView(siKeViewInstance, [ivarNameStr UTF8String]);
                if (keView) { [g_keChuanTaskQueue addObject:keView]; }
            }
        }
    }
    
    NSMutableArray *sanChuanTasksMutable = [NSMutableArray array];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanTasksMutable);
        [sanChuanTasksMutable sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        [g_keChuanTaskQueue addObjectsFromArray:sanChuanTasksMutable];
    }
    
    if (g_keChuanTaskQueue.count == 0) {
        EchoLog(@"错误：未能获取任何可点击的课、传视图。"); g_isTestingKeChuanDetail = NO; return;
    }
    
    EchoLog(@"任务队列准备就绪，总共 %lu 个任务。", (unsigned long)g_keChuanTaskQueue.count);

    __weak typeof(self) weakSelf = self;
    g_processQueueBlock = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || g_keChuanTaskQueue.count == 0) {
            EchoLog(@"--- 所有任务处理完毕 ---");
            NSMutableString *finalResult = [NSMutableString string];
            NSArray *titles = @[@"第1课", @"第2课", @"第3课", @"第4课", @"初传", @"中传", @"末传"];
            for (NSUInteger i = 0; i < g_capturedKeChuanDetailArray.count; i++) {
                NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"项目 %lu", (unsigned long)i+1];
                [finalResult appendFormat:@"\n[%@ 详情]\n%@\n--------------------\n", title, g_capturedKeChuanDetailArray[i]];
            }
            NSLog(@"%@", finalResult);
            EchoLog(@"--- 测试结束 ---");
            g_isTestingKeChuanDetail = NO; g_processQueueBlock = nil; g_keChuanTaskQueue = nil;
            return;
        }

        UIView *targetView = g_keChuanTaskQueue.firstObject;
        [g_keChuanTaskQueue removeObjectAtIndex:0];
        EchoLog(@"处理任务... 剩余 %lu 个", (unsigned long)g_keChuanTaskQueue.count);
        [strongSelf triggerTapOnView:targetView];
        
    } copy];

    g_processQueueBlock();
}

%new
// 4. 模拟点击手势
- (void)triggerTapOnView:(UIView *)view {
    if (!view) return;
    
    UIGestureRecognizer *tapRecognizer = nil;
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            tapRecognizer = recognizer; break;
        }
    }
    if (!tapRecognizer) {
        for(UIView *subview in view.subviews) {
             for (UIGestureRecognizer *recognizer in subview.gestureRecognizers) {
                if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
                    tapRecognizer = recognizer; break;
                }
            }
            if(tapRecognizer) break;
        }
    }

    if(tapRecognizer) {
        Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
        id targets = object_getIvar(tapRecognizer, targetsIvar);
        
        if (targets && [targets count] > 0) {
            id targetContainer = [targets firstObject];
            id target = [targetContainer valueForKey:@"_target"];
            SEL action = NSSelectorFromString([targetContainer valueForKey:@"_action"]);
            
            if (target && action && [target respondsToSelector:action]) {
                EchoLog(@"找到手势并执行: %@ on target %@", NSStringFromSelector(action), target);
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [target performSelector:action withObject:tapRecognizer];
                #pragma clang diagnostic pop
                return;
            }
        }
    }
     EchoLog(@"警告: 未能在视图 %@ 上找到可执行的Tap手势。", view);
}

%new
// 5. 提取文本
- (NSString *)extractTextFromViewHierachy:(UIView *)view {
    NSMutableArray *allLabels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], view, allLabels);
    
    [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        CGPoint p1 = [l1.superview convertPoint:l1.frame.origin toView:nil];
        CGPoint p2 = [l2.superview convertPoint:l2.frame.origin toView:nil];
        if (p1.y < p2.y - 2) return NSOrderedAscending;
        if (p1.y > p2.y + 2) return NSOrderedDescending;
        if (p1.x < p2.x) return NSOrderedAscending;
        if (p1.x > p2.x) return NSOrderedDescending;
        return NSOrderedSame;
    }];
        
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in allLabels) {
         if (label.text && label.text.length > 0) {
            [textParts addObject:[label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }

    NSString *rawText = [textParts componentsJoinedByString:@"\n"];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\n{2,}" options:0 error:nil];
    return [regex stringByReplacingMatchesInString:rawText options:0 range:NSMakeRange(0, rawText.length) withTemplate:@"\n"];
}

%end
