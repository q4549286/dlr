#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 修正后的宏定义，更具兼容性
#define TestLog(format, ...) NSLog((@"[EchoAI-SiKeTest-v1] " format), ##__VA_ARGS__)

// =========================================================================
// 1. 接口声明
// =========================================================================
@interface UIViewController (EchoTestAddons)
- (void)performSiKeSanChuanExtraction;
- (void)formatAndPresentResults;
@end

// =========================================================================
// 2. 全局状态变量
// =========================================================================
static const NSInteger TestButtonTag = 20240523;
static const NSInteger TestProgressViewTag = 20240524;

static BOOL g_isExtractingDetails = NO;
static NSMutableArray *g_extractionQueue = nil;
static NSMutableDictionary *g_capturedDetails = nil;
static NSString *g_currentExtractionKey = nil;

// =========================================================================
// 3. 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 模拟点击手势 (一个更健壮的版本)
static BOOL findAndFireTapRecognizer(UIView *view) {
    if (!view) return NO;
    
    // 优先查找视图本身的手势
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            // 通过KVC获取targets数组
            NSArray *targets = [recognizer valueForKey:@"_targets"];
            if (targets && targets.count > 0) {
                id targetContainer = targets[0];
                id target = [targetContainer valueForKey:@"_target"];
                SEL action = (SEL)[targetContainer valueForKey:@"_action"];
                
                if (target && action && [target respondsToSelector:action]) {
                    TestLog(@"在视图 %@ 上找到并触发手势: %@", view.class, NSStringFromSelector(action));
                    _Pragma("clang diagnostic push")
                    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")
                    [target performSelector:action withObject:recognizer];
                    _Pragma("clang diagnostic pop")
                    return YES;
                }
            }
        }
    }
    
    // 如果找不到，并且当前视图是UILabel，它的父视图可能包含手势
    if ([view isKindOfClass:[UILabel class]] && view.superview) {
        return findAndFireTapRecognizer(view.superview);
    }
    
    return NO;
}


// =========================================================================
// 4. 核心Hook：拦截弹窗
// =========================================================================
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingDetails && g_currentExtractionKey) {
        TestLog(@"拦截到弹窗，用于任务: %@", g_currentExtractionKey);
        
        NSMutableArray *allLabels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels);
        [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
            return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
        }];
        
        NSMutableArray *textParts = [NSMutableArray array];
        for (UILabel *label in allLabels) {
            if (label.text && label.text.length > 0) {
                NSString *cleanedText = [label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                [textParts addObject:cleanedText];
            }
        }
        
        NSString *fullText = [textParts componentsJoinedByString:@"\n"];
        g_capturedDetails[g_currentExtractionKey] = fullText.length > 0 ? fullText : @"[无内容]";
        
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        
        g_currentExtractionKey = nil;
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:TestButtonTag]) return;
            
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 85, 140, 36);
            testButton.tag = TestButtonTag;
            [testButton setTitle:@"开始测试(四课三传)" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.6 blue:0.2 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(performSiKeSanChuanExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
        });
    }
}

// =========================================================================
// 5. 新增功能实现
// =========================================================================
%new
- (void)performSiKeSanChuanExtraction {
    TestLog(@"--- 开始执行四课三传究极提取任务 ---");
    
    g_isExtractingDetails = YES;
    g_extractionQueue = [NSMutableArray array];
    g_capturedDetails = [NSMutableDictionary dictionary];
    
    // --- 1. 构建任务队列 ---
    
    // 提取四课
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (siKeViewClass) {
        NSMutableArray *siKeViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if (siKeViews.count > 0) {
            UIView *container = siKeViews.firstObject;
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], container, labels);
            
            NSMutableDictionary *cols = [NSMutableDictionary dictionary];
            for (UILabel *label in labels) {
                NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
                if (!cols[key]) { cols[key] = [NSMutableArray array]; }
                [cols[key] addObject:label];
            }
            
            if (cols.allKeys.count == 4) {
                NSArray *sortedXKeys = [[cols allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) {
                    return [@([o1 floatValue]) compare:@([o2 floatValue])];
                }];

                NSArray *lessons = @[cols[sortedXKeys[3]], cols[sortedXKeys[2]], cols[sortedXKeys[1]], cols[sortedXKeys[0]]];
                for (int i = 0; i < lessons.count; i++) {
                    NSMutableArray *lessonLabels = lessons[i];
                    [lessonLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                        return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                    }];
                    if (lessonLabels.count >= 3) {
                        int lessonNum = i + 1;
                        UIView *mainClickableView = ((UILabel*)lessonLabels[0]).superview.superview; // 主释义的点击目标
                        [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_主释义", lessonNum], @"view": mainClickableView}];
                        [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项1_%@", lessonNum, ((UILabel*)lessonLabels[0]).text], @"view": lessonLabels[0]}];
                        [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项2_%@", lessonNum, ((UILabel*)lessonLabels[1]).text], @"view": lessonLabels[1]}];
                        [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项3_%@", lessonNum, ((UILabel*)lessonLabels[2]).text], @"view": lessonLabels[2]}];
                    }
                }
            }
        }
    }

    // 提取三传
    Class chuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (chuanViewClass) {
        NSMutableArray *chuanViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(chuanViewClass, self.view, chuanViews);
        [chuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) {
            return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
        }];

        NSArray *chuanTitles = @[@"初传", @"中传", @"末传"];
        for (int i = 0; i < chuanViews.count && i < chuanTitles.count; i++) {
            UIView *rowView = chuanViews[i];
            NSMutableArray *labels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], rowView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
            }];

            if (labels.count > 0) {
                [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"%@_主释义", chuanTitles[i]], @"view": rowView}];
                for(int j = 0; j < labels.count; j++){
                    [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"%@_分项%d_%@", chuanTitles[i], j+1, ((UILabel*)labels[j]).text], @"view": labels[j]}];
                }
            }
        }
    }
    
    TestLog(@"构建任务队列完成，共 %ld 个任务。", (unsigned long)g_extractionQueue.count);

    if (g_extractionQueue.count == 0) {
        g_isExtractingDetails = NO;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"错误" message:@"未能找到四课三传的任何可点击项。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    // --- 2. 显示进度条 ---
    UIWindow *keyWindow = self.view.window;
    UIView *progressView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    progressView.tag = TestProgressViewTag;
    
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor];
    [spinner startAnimating];
    
    UILabel *progressLabel = [[UILabel alloc] init];
    progressLabel.textColor = [UIColor whiteColor];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.numberOfLines = 2;
    progressLabel.font = [UIFont systemFontOfSize:13.0];
    
    UIView *centerBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)];
    centerBox.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    centerBox.layer.cornerRadius = 10;
    centerBox.center = progressView.center;
    spinner.center = CGPointMake(110, 45);
    progressLabel.frame = CGRectMake(10, 75, 200, 40);
    
    [centerBox addSubview:spinner];
    [centerBox addSubview:progressLabel];
    [progressView addSubview:centerBox];
    [keyWindow addSubview:progressView];

    
    // --- 3. 开始异步处理队列 ---
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    
    processQueue = ^{
        if (g_extractionQueue.count == 0) {
            TestLog(@"--- 所有任务处理完毕 ---");
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf formatAndPresentResults];
            });
            processQueue = nil;
            return;
        }
        
        NSDictionary *task = g_extractionQueue.firstObject;
        [g_extractionQueue removeObjectAtIndex:0];
        
        NSString *key = task[@"key"];
        UIView *targetView = task[@"view"];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            g_currentExtractionKey = key;
            TestLog(@"正在处理任务: %@", key);
            progressLabel.text = [NSString stringWithFormat:@"正在提取 (%ld/%lu):\n%@",(long)(g_capturedDetails.count + 1), (unsigned long)(g_capturedDetails.count + g_extractionQueue.count + 1), key];
            
            BOOL success = findAndFireTapRecognizer(targetView);
            if (!success) {
                TestLog(@"任务 %@ 点击失败，目标视图: %@", key, targetView);
                g_capturedDetails[key] = @"[点击失败]";
            }
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                processQueue();
            });
        });
    };
    
    processQueue();
}

%new
- (void)formatAndPresentResults {
    TestLog(@"开始格式化结果...");
    [[self.view.window viewWithTag:TestProgressViewTag] removeFromSuperview];
    
    NSMutableString *result = [NSMutableString stringWithString:@"【四课三传究极详解 - 测试结果】\n====================\n\n"];
    
    NSMutableDictionary *structuredResults = [NSMutableDictionary dictionary];
    for (NSString *key in g_capturedDetails) {
        NSArray *parts = [key componentsSeparatedByString:@"_"];
        if (parts.count < 2) continue;
        
        NSString *groupName = parts[0];
        NSString *itemType = parts[1];
        
        if (!structuredResults[groupName]) {
            structuredResults[groupName] = [NSMutableDictionary dictionary];
            structuredResults[groupName][@"分项"] = [NSMutableArray array];
        }
        
        if ([itemType isEqualToString:@"主释义"]) {
            structuredResults[groupName][@"主释义"] = g_capturedDetails[key];
        } else {
            [structuredResults[groupName][@"分项"] addObject:@{@"key": key, @"value": g_capturedDetails[key]}];
        }
    }
    
    NSArray *displayOrder = @[@"第一课", @"第二课", @"第三课", @"第四课", @"初传", @"中传", @"末传"];
    
    for (NSString *groupName in displayOrder) {
        NSDictionary *groupData = structuredResults[groupName];
        if (!groupData) continue;
        
        NSMutableArray *subItems = groupData[@"分项"];
        NSMutableString *titleLine = [NSMutableString string];
        if (subItems) {
            [subItems sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
                return [o1[@"key"] compare:o2[@"key"]];
            }];
            for(NSDictionary* item in subItems){
                NSArray *keyParts = [item[@"key"] componentsSeparatedByString:@"_"];
                if(keyParts.count > 2) [titleLine appendFormat:@"%@ ", keyParts[2]];
            }
        }
        
        [result appendFormat:@"--- %@ (%@) ---\n", groupName, [titleLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
        
        NSString *mainMeaning = groupData[@"主释义"] ?: @"[未提取到]";
        [result appendFormat:@"【主释义】\n%@\n\n", mainMeaning];
        
        if (subItems) {
            for (NSDictionary *item in subItems) {
                NSString *itemKey = item[@"key"];
                NSString *itemValue = item[@"value"];
                NSArray *keyParts = [itemKey componentsSeparatedByString:@"_"];
                NSString *subItemName = (keyParts.count > 2) ? keyParts[2] : @"分项";

                [result appendFormat:@"  【分项: %@】\n  %@\n", subItemName, [itemValue stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "]];
            }
        }
        [result appendString:@"\n--------------------\n\n"];
    }

    [UIPasteboard generalPasteboard].string = result;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:@"四课三传的详细信息已提取并复制到剪贴板。请粘贴查看结果。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];

    g_isExtractingDetails = NO;
    g_extractionQueue = nil;
    g_capturedDetails = nil;
    g_currentExtractionKey = nil;
}

%end
