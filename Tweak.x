#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define TestLog(format, ...) NSLog((@"[EchoAI-SiKeTest-v1] " format), ##VA_ARGS__)

// =========================================================================
// 1. 全局状态变量 (用于测试脚本)
// =========================================================================
static const NSInteger TestButtonTag = 20240523;
static const NSInteger TestProgressViewTag = 20240524;

// 任务控制
static BOOL g_isExtractingDetails = NO;
static NSMutableArray *g_extractionQueue = nil;
static NSMutableDictionary *g_capturedDetails = nil;
static NSString *g_currentExtractionKey = nil;
static dispatch_block_t g_completionBlock = nil;

// =========================================================================
// 2. 辅助函数
// =========================================================================
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}

// 核心：模拟点击手势
static BOOL findAndFireTapRecognizer(UIView *view) {
    // 优先查找视图本身的手势
    for (UIGestureRecognizer *recognizer in view.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UITapGestureRecognizer class]]) {
            id target = [recognizer valueForKey:@"_targets"][0];
            SEL action = NSSelectorFromString([[[target description] componentsSeparatedByString:@" "][1] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]]);
            if ([target respondsToSelector:action]) {
                TestLog(@"在视图 %@ 上找到并触发手势: %@", view.class, NSStringFromSelector(action));
                 _Pragma("clang diagnostic push")
                 _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"")
                [target performSelector:action withObject:recognizer];
                 _Pragma("clang diagnostic pop")
                return YES;
            }
        }
    }
    // 如果找不到，尝试其父视图（有时手势在容器上）
    if (view.superview) {
        return findAndFireTapRecognizer(view.superview);
    }
    return NO;
}


// =========================================================================
// 3. 核心Hook：拦截弹窗
// =========================================================================
%hook UIViewController

// 拦截所有弹窗请求
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_isExtractingDetails && g_currentExtractionKey) {
        TestLog(@"拦截到弹窗，用于任务: %@", g_currentExtractionKey);
        
        // 提取弹窗内的所有文本
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
        
        // 立即销毁弹窗，不让它显示出来
        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        
        // 清空当前任务键，防止重复捕获
        g_currentExtractionKey = nil;
        return; // 终止原始的 presentViewController 调用
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

// 在主界面加载时添加测试按钮
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
// 4. 新增功能：四课三传提取器
// =========================================================================
%new
- (void)performSiKeSanChuanExtraction {
    TestLog(@"--- 开始执行四课三传究极提取任务 ---");
    
    // 初始化状态
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
            
            // 按Y坐标分组
            NSMutableDictionary *rows = [NSMutableDictionary dictionary];
            for (UILabel *label in labels) {
                NSString *yKey = [NSString stringWithFormat:@"%.0f", roundf(label.frame.origin.y)];
                if (!rows[yKey]) { rows[yKey] = [NSMutableArray array]; }
                [rows[yKey] addObject:label];
            }
            
            NSArray *sortedYKeys = [[rows allKeys] sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) {
                return [@([o1 floatValue]) compare:@([o2 floatValue])];
            }];

            int lessonNum = 4;
            for (NSString *yKey in [sortedYKeys reverseObjectEnumerator]) { // 从下往上是1-4课
                NSArray *rowLabels = rows[yKey];
                [rowLabels sortedArrayUsingComparator:^NSComparisonResult(UILabel* o1, UILabel* o2) {
                    return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                }];
                if (rowLabels.count >= 3) {
                     // 主释义任务
                    [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_主释义", lessonNum], @"view": ((UILabel*)rowLabels[0]).superview.superview}];
                    // 分项释义任务
                    [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项1_%@", lessonNum, ((UILabel*)rowLabels[0]).text], @"view": rowLabels[0]}];
                    [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项2_%@", lessonNum, ((UILabel*)rowLabels[1]).text], @"view": rowLabels[1]}];
                    [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"第%d课_分项3_%@", lessonNum, ((UILabel*)rowLabels[2]).text], @"view": rowLabels[2]}];
                }
                lessonNum--;
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
                 // 主释义任务
                [g_extractionQueue addObject:@{@"key": [NSString stringWithFormat:@"%@_主释义", chuanTitles[i]], @"view": rowView}];
                // 分项释义任务
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
    
    UIView *centerBox = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
    centerBox.backgroundColor = [UIColor colorWithWhite:0.2 alpha:0.8];
    centerBox.layer.cornerRadius = 10;
    centerBox.center = progressView.center;
    spinner.center = CGPointMake(100, 45);
    progressLabel.frame = CGRectMake(10, 75, 180, 40);
    
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
            progressLabel.text = [NSString stringWithFormat:@"正在提取...\n%@", key];
            
            // 模拟点击
            BOOL success = findAndFireTapRecognizer(targetView);
            if (!success) {
                TestLog(@"任务 %@ 点击失败，目标视图: %@", key, targetView);
                g_capturedDetails[key] = @"[点击失败]";
            }
            
            // 延迟后处理下一个
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                processQueue();
            });
        });
    };
    
    processQueue();
}

%new
- (void)formatAndPresentResults {
    TestLog(@"开始格式化结果...");
    // 移除进度条
    [[self.view.window viewWithTag:TestProgressViewTag] removeFromSuperview];
    
    NSMutableString *result = [NSMutableString stringWithString:@"【四课三传究极详解 - 测试结果】\n====================\n\n"];
    
    // 使用 g_capturedDetails 字典来构建最终文本
    // 这个字典的键是唯一的，包含了所有信息
    // 我们可以通过解析键名来重建结构
    
    NSMutableDictionary *structuredResults = [NSMutableDictionary dictionary];
    for (NSString *key in g_capturedDetails) {
        NSArray *parts = [key componentsSeparatedByString:@"_"];
        if (parts.count < 2) continue;
        
        NSString *groupName = parts[0]; // e.g., "第一课" or "初传"
        NSString *itemType = parts[1];  // e.g., "主释义" or "分项1"
        
        if (!structuredResults[groupName]) {
            structuredResults[groupName] = [NSMutableDictionary dictionary];
        }
        
        if ([itemType isEqualToString:@"主释义"]) {
            structuredResults[groupName][@"主释义"] = g_capturedDetails[key];
        } else {
            if (!structuredResults[groupName][@"分项"]) {
                structuredResults[groupName][@"分项"] = [NSMutableArray array];
            }
            // 为了保持顺序，我们将分项的完整键和值都存起来
            [structuredResults[groupName][@"分项"] addObject:@{@"key": key, @"value": g_capturedDetails[key]}];
        }
    }
    
    // 定义正确的显示顺序
    NSArray *displayOrder = @[@"第一课", @"第二课", @"第三课", @"第四课", @"初传", @"中传", @"末传"];
    
    for (NSString *groupName in displayOrder) {
        NSDictionary *groupData = structuredResults[groupName];
        if (!groupData) continue;
        
        // 提取组标题，比如 "第1课_分项1_官" -> "官"
        NSString *rawTitleKey = [((NSDictionary*)groupData[@"分项"][0])[@"key"] stringByAppendingString:@"_"]; // 加个下划线方便分割
        NSArray* titleParts = [rawTitleKey componentsSeparatedByString:@"_"];
        NSMutableArray *cleanTitleParts = [NSMutableArray array];
        if (titleParts.count > 2) {
            for (int i=2; i<titleParts.count-1; i++) {
                 [cleanTitleParts addObject:titleParts[i]];
            }
        }
        
        [result appendFormat:@"--- %@ (%@) ---\n", groupName, [cleanTitleParts componentsJoinedByString:@" "]];
        
        NSString *mainMeaning = groupData[@"主释义"] ?: @"[未提取到]";
        [result appendFormat:@"【主释义】\n%@\n\n", mainMeaning];
        
        NSMutableArray *subItems = groupData[@"分项"];
        if (subItems) {
            // 对分项进行排序，以防万一
            [subItems sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
                return [o1[@"key"] compare:o2[@"key"]];
            }];
            
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

    // 复制到剪贴板
    [UIPasteboard generalPasteboard].string = result;
    
    // 显示成功提示
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"测试完成" message:@"四课三传的详细信息已提取并复制到剪贴板。请粘贴查看结果。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];

    // 重置状态
    g_isExtractingDetails = NO;
    g_extractionQueue = nil;
    g_capturedDetails = nil;
    g_currentExtractionKey = nil;
}

%end
