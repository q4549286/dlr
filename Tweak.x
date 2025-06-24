#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================
#define EchoLog(format, ...) NSLog(@"[KeChuan-Test-PosSort] " format, ##__VA_ARGS__)

static NSInteger const TestButtonTag = 556688; // 新的Tag
static BOOL g_isExtractingDetails = NO;
static NSMutableArray *g_capturedDetailsArray = nil;
static NSMutableArray *g_workQueue = nil;
static NSMutableArray *g_titleQueue = nil;

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// =========================================================================
// 2. 主功能区
// =========================================================================
@interface UIViewController (EchoAITestAddons_PosSort)
- (void)performPosSortExtractionTest;
- (void)processPosSortQueue;
@end

%hook UIViewController

// viewDidLoad 和 presentViewController 保持不变
- (void)viewDidLoad { %orig; Class c=NSClassFromString(@"六壬大占.ViewController"); if(c&&[self isKindOfClass:c]){ dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.5*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ UIWindow*w=self.view.window;if(!w)return; if([w viewWithTag:TestButtonTag])[[w viewWithTag:TestButtonTag]removeFromSuperview]; UIButton*b=[UIButton buttonWithType:UIButtonTypeSystem]; b.frame=CGRectMake(w.bounds.size.width-150,45+80,140,36); b.tag=TestButtonTag;[b setTitle:@"测试位置排序点击" forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:16];b.backgroundColor=[UIColor colorWithRed:0.9 green:0.4 blue:0.4 alpha:1.0];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];b.layer.cornerRadius=8;[b addTarget:self action:@selector(performPosSortExtractionTest) forControlEvents:UIControlEventTouchUpInside];[w addSubview:b]; }); } }
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion{ if(g_isExtractingDetails){ NSString*n=NSStringFromClass([viewControllerToPresent class]);if([n containsString:@"摘要視圖"]||[n containsString:@"課體視圖"]){ viewControllerToPresent.view.alpha=0.0f;flag=NO; dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(0.2*NSEC_PER_SEC)),dispatch_get_main_queue(),^{ NSMutableArray*a=[NSMutableArray array];FindSubviewsOfClassRecursive([UILabel class],viewControllerToPresent.view,a);[a sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){if(roundf(o1.frame.origin.y)<roundf(o2.frame.origin.y))return NSOrderedAscending;if(roundf(o1.frame.origin.y)>roundf(o2.frame.origin.y))return NSOrderedDescending;return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];}]; NSMutableArray*t=[NSMutableArray array];for(UILabel*l in a){if(l.text&&l.text.length>0){[t addObject:[l.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];}} [g_capturedDetailsArray addObject:[t componentsJoinedByString:@"\n"]];[viewControllerToPresent dismissViewControllerAnimated:NO completion:nil]; }); %orig(viewControllerToPresent,flag,completion);return;}} %orig(viewControllerToPresent,flag,completion); }

%new
- (void)performPosSortExtractionTest {
    EchoLog(@"开始执行 [位置排序点击] 测试");
    g_isExtractingDetails = YES;
    g_capturedDetailsArray = [NSMutableArray array];
    g_workQueue = [NSMutableArray array];
    g_titleQueue = [NSMutableArray array];

    // --- Step 1: 建立点击任务队列 ---
    
    // --- 三传 (全新解析逻辑) ---
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (sanChuanContainerClass) {
        NSMutableArray *cViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, cViews);
        if (cViews.count > 0) {
            UIView *container = cViews.firstObject;
            NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, allLabels);
            
            // 按Y坐标分组，Y坐标相似的分为一行
            NSMutableDictionary *rows = [NSMutableDictionary dictionary];
            for (UILabel *label in allLabels) {
                NSString *yKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidY(label.frame))];
                if (!rows[yKey]) { rows[yKey] = [NSMutableArray array]; }
                [rows[yKey] addObject:label];
            }
            
            // 获取所有行，并按Y坐标排序
            NSArray *sortedYKeys = [rows.allKeys sortedArrayUsingComparator:^NSComparisonResult(id o1, id o2){ return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
            
            if (sortedYKeys.count >= 3) { // 确保有三行
                NSArray *rowTitles = @[@"初传", @"中传", @"末传"];
                for (NSUInteger i = 0; i < sortedYKeys.count; i++) {
                    NSString *yKey = sortedYKeys[i];
                    NSMutableArray *rowLabels = rows[yKey];
                    // 对行内标签按X坐标排序
                    [rowLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel*o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                    
                    if (rowLabels.count >= 2) {
                        UILabel *dizhi = rowLabels[rowLabels.count - 2];
                        UILabel *tianjiang = rowLabels[rowLabels.count - 1];
                        
                        [g_workQueue addObject:@{@"item": dizhi, @"type": @"dizhi"}];
                        [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhi.text]];
                        
                        [g_workQueue addObject:@{@"item": tianjiang, @"type": @"tianjiang"}];
                        [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiang.text]];
                    }
                }
            }
        }
    }

    // --- 四课 (解析逻辑不变，因为它一直很可靠) ---
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *skViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, skViews);
        if (skViews.count > 0) {
            UIView *container = skViews.firstObject;
            NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, allLabels);
            NSMutableDictionary *cols = [NSMutableDictionary dictionary];
            for (UILabel *l in allLabels) {
                NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(l.frame))];
                if (!cols[key]) { cols[key] = [NSMutableArray array]; } [cols[key] addObject:l];
            }
            if (cols.allKeys.count == 4) {
                NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(id o1,id o2){return [@([o1 floatValue]) compare:@([o2 floatValue])];}];
                NSArray *titles = @[@"第四课",@"第三课",@"第二课",@"第一课"];
                for(NSUInteger i=0;i<keys.count;i++){
                    NSMutableArray *colLabels = cols[keys[i]];
                    [colLabels sortUsingComparator:^NSComparisonResult(UILabel*o1,UILabel*o2){return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];}];
                    if(colLabels.count>=2){
                        UILabel *tianjiang=colLabels[0],*dizhi=colLabels[1];
                        [g_workQueue addObject:@{@"item": dizhi, @"type": @"dizhi"}];
                        [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", titles[i], dizhi.text]];
                        [g_workQueue addObject:@{@"item": tianjiang, @"type": @"tianjiang"}];
                        [g_titleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", titles[i], tianjiang.text]];
                    }
                }
            }
        }
    }
    
    // 九宗门 & 课体 (逻辑不变)
    // ...
    

    if (g_workQueue.count == 0) { EchoLog(@"测试失败: 未能建立任何点击任务。"); g_isExtractingDetails = NO; return; }
    EchoLog(@"工作队列建立完毕，共 %ld 个任务。", (long)g_workQueue.count);
    [self processPosSortQueue];
}

%new
- (void)processPosSortQueue {
    if (g_workQueue.count == 0) {
        // ... (队列完成后的逻辑，保持不变)
        EchoLog(@"[位置排序点击] 测试处理完毕");
        NSMutableString *resultStr = [NSMutableString string];
        for (NSUInteger i = 0; i < g_titleQueue.count; i++) {
            [resultStr appendFormat:@"--- %@ ---\n%@\n\n", g_titleQueue[i], (i < g_capturedDetailsArray.count) ? g_capturedDetailsArray[i] : @"[信息提取失败]"];
        }
        [UIPasteboard generalPasteboard].string = resultStr;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"位置排序版测试完成" message:@"所有详情已提取并复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        g_isExtractingDetails = NO; g_workQueue = nil; g_capturedDetailsArray = nil; g_titleQueue = nil;
        return;
    }
    
    NSDictionary *task = g_workQueue.firstObject;
    [g_workQueue removeObjectAtIndex:0];
    
    UIView *itemToClick = task[@"item"];
    NSString *type = task[@"type"];
    
    SEL actionToPerform = nil;
    if ([type isEqualToString:@"dizhi"] || [type isEqualToString:@"common"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳摘要WithSender:");
    } else if ([type isEqualToString:@"tianjiang"]) {
        actionToPerform = NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
    }

    if (actionToPerform && [self respondsToSelector:actionToPerform]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:actionToPerform withObject:itemToClick];
        #pragma clang diagnostic pop
    } else {
        EchoLog(@"警告: 未能为 %@ 找到并执行对应的点击方法。", type);
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self processPosSortQueue];
    });
}
%end
