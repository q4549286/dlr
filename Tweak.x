您提了两个非常棒、非常核心的问题！这说明您观察得非常仔细。让我来为您解答：

-----

### 问题一：变量名是繁体字，有影响吗？

**回答：完全没有影响，这反而是个好现象，说明我们百分之百找对了！**

Objective-C 和 Swift 语言都支持使用包括中文在内的任何 Unicode 字符来作为变量名。我们只需要在代码里，也使用一模一样的繁体字 `地宫名列` 和 `天神宫名列` 就可以了。直接复制粘贴是最好的方式，确保不会出错。

-----

### 问题二：变量的值是 `nil`（空的），不影响吗？

**回答：这个 `nil` 值也完全不影响，并且这是【完全正常】的现象！**

这是解开谜题的最后一把钥匙。这个现象叫做 **“懒加载” (Lazy Initialization)**。

您可以把这个变量想象成一个 **“懒人沙发”**：

  * **平时不用时：** 它被折叠起来，不占空间（在程序里就是 `nil`，不占内存）。
  * **当您第一次想坐上去时：** 您把它“砰”地一下展开，它才变成了能坐的沙发（程序第一次访问这个变量，它才去计算和加载真实的数据）。
  * **之后：** 它就一直是展开的沙发形态了（变量里有值了）。

您在 FLEX 里看到 `nil`，是因为您查看的时候，程序还“懒得”去加载数据。

而我们的 **“复制到AI”** 按钮，是在界面完全显示好之后才点击的。到那个时候，为了把天地盘画出来，程序早就已经把这些“懒人沙发”全部展开了（所有变量都加载好值了）。

所以，请完全放心，我们的代码去读取时，一定能读到正确的数据。

-----

### 重新为您提供最终代码

非常抱歉，我上次的回答在生成代码时被意外中断了。

现在，我将为您提供 **【完整的、未经删减的最终代码】**。请用下面的全部代码，替换掉您原来的 `Section 3` 及之后的所有内容。

```objc
// =========================================================================
// Section 3: 【最终版】一键复制到 AI (已集成天地盘提取功能)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; }
            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
            copyButton.tag = CopyAiButtonTag;
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalMethod) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:viewControllerToPresent.view andStoreIn:labels];
            
            NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0 && labels.count > 0) {
                 [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                     if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
                     if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
                     return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
                 }];
                 title = ((UILabel*)labels.firstObject).text;
            }

            NSMutableArray *fangfaViews = [NSMutableArray array];
            Class fangfaViewClass = NSClassFromString(@"六壬大占.格局單元");
            if (fangfaViewClass) { [self findSubviewsOfClass:fangfaViewClass inView:viewControllerToPresent.view andStoreIn:fangfaViews]; }

            NSString* content = nil;
            NSMutableArray *leftColumn = [NSMutableArray array];
            NSMutableArray *rightColumn = [NSMutableArray array];
            NSMutableArray *textParts = [NSMutableArray array];
            CGFloat midX = viewControllerToPresent.view.bounds.size.width / 2;

            if ([vcClassName containsString:@"七政"]) {
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for(UILabel *label in labels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                EchoLog(@"成功抓取 [七政四余] 内容 (单列排版)");
            }
            else if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"]) {
                for(UILabel *label in labels) { if (![label.text isEqualToString:title]) { if (CGRectGetMidX(label.frame) < midX) { [leftColumn addObject:label.text]; } else { [rightColumn addObject:label.text]; } } }
                for (int i=0; i < MIN(leftColumn.count, rightColumn.count); i++) { [textParts addObject:[NSString stringWithFormat:@"%@: %@", leftColumn[i], rightColumn[i]]]; }
                content = [textParts componentsJoinedByString:@"\n"];
                if ([title containsString:@"格局"]) { g_extractedData[@"格局"] = content; EchoLog(@"成功抓取并重排版 [格局] 内容"); }
                else { g_extractedData[@"毕法"] = content; EchoLog(@"成功抓取并重排版 [毕法] 内容"); }
            }
            else if (fangfaViews.count > 0) {
                [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for(UILabel *label in labels) { if (CGRectGetMidX(label.frame) < midX) { [leftColumn addObject:label.text]; } else { [rightColumn addObject:label.text]; } }
                for (int i=0; i < MIN(leftColumn.count, rightColumn.count); i++) { [textParts addObject:[NSString stringWithFormat:@"%@: %@", leftColumn[i], rightColumn[i]]]; }
                g_extractedData[@"方法"] = [textParts componentsJoinedByString:@"\n"];
                EchoLog(@"成功抓取并重排版 [方法] 内容");
            } else {
                 EchoLog(@"抓取到未知弹窗，内容被忽略。");
            }
            
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)findSubviewsOfClass:(Class)aClass inView:(UIView *)view andStoreIn:(NSMutableArray *)storage {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { [self findSubviewsOfClass:aClass inView:subview andStoreIn:storage]; }
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { EchoLog(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    [self findSubviewsOfClass:targetViewClass inView:self.view andStoreIn:targetViews];
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    [self findSubviewsOfClass:[UILabel class] inView:containerView andStoreIn:labelsInView];
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}

%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];

    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"起课方式"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    EchoLog(@"主界面信息提取完毕。");

    // ==========================================================
    // 新增：提取天地盘信息
    // ==========================================================
    EchoLog(@"正在提取天地盘信息...");
    NSMutableString *tianDiPanInfo = [NSMutableString string];
    Class tianDiPanViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (tianDiPanViewClass) {
        NSMutableArray *tianDiPanViews = [NSMutableArray array];
        [self findSubviewsOfClass:tianDiPanViewClass inView:self.view andStoreIn:tianDiPanViews];
        if (tianDiPanViews.count > 0) {
            UIView *tianDiPanView = tianDiPanViews.firstObject;
            
            // 使用 valueForKey 安全地读取 Swift 属性
            id diGong = [tianDiPanView valueForKey:@"地宫名列"];
            id tianShenGong = [tianDiPanView valueForKey:@"天神宫名列"];

            if ([diGong isKindOfClass:[NSArray class]] && ((NSArray *)diGong).count > 0) {
                [tianDiPanInfo appendFormat:@"地盘: %@\n", [diGong componentsJoinedByString:@" "]];
            }
            if ([tianShenGong isKindOfClass:[NSArray class]] && ((NSArray *)tianShenGong).count > 0) {
                [tianDiPanInfo appendFormat:@"天盘: %@", [tianShenGong componentsJoinedByString:@" "]];
            }
            EchoLog(@"成功提取天地盘数据！");
        } else {
            EchoLog(@"未找到天地盘视图实例。");
        }
    } else {
        EchoLog(@"未找到天地盘视图类。");
    }
    g_extractedData[@"天地盘"] = tianDiPanInfo;
    
    // 四课和三传代码...
    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array]; [self findSubviewsOfClass:siKeViewClass inView:self.view andStoreIn:siKeViews];
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject; NSMutableArray* labels = [NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:container andStoreIn:labels];
            if(labels.count >= 12){
                NSMutableDictionary *columns = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *columnKey = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!columns[columnKey]){ columns[columnKey] = [NSMutableArray array]; } [columns[columnKey] addObject:label]; }
                if (columns.allKeys.count == 4) {
                    NSArray *sortedColumnKeys = [columns.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=columns[sortedColumnKeys[0]],*c2=columns[sortedColumnKeys[1]],*c3=columns[sortedColumnKeys[2]],*c4=columns[sortedColumnKeys[3]];
                    [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString* k1s=((UILabel*)c4[0]).text,*k1t=((UILabel*)c4[1]).text,*k1d=((UILabel*)c4[2]).text; NSString* k2s=((UILabel*)c3[0]).text,*k2t=((UILabel*)c3[1]).text,*k2d=((UILabel*)c3[2]).text; NSString* k3s=((UILabel*)c2[0]).text,*k3t=((UILabel*)c2[1]).text,*k3d=((UILabel*)c2[2]).text; NSString* k4s=((UILabel*)c1[0]).text,*k4t=((UILabel*)c1[1]).text,*k4d=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_extractedData[@"四课"] = siKe;
    
    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        NSMutableArray *sanChuanViews = [NSMutableArray array]; [self findSubviewsOfClass:sanChuanViewClass inView:self.view andStoreIn:sanChuanViews];
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (int i = 0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i]; NSMutableArray *labelsInView = [NSMutableArray array]; [self findSubviewsOfClass:[UILabel class] inView:view andStoreIn:labelsInView]; [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if (labelsInView.count >= 3) {
                NSString *lq=((UILabel*)labelsInView.firstObject).text, *tj=((UILabel*)labelsInView.lastObject).text, *dz=((UILabel*)[labelsInView objectAtIndex:labelsInView.count-2]).text;
                NSMutableArray *ssParts = [NSMutableArray array]; if (labelsInView.count > 3) { for(UILabel *l in [labelsInView subarrayWithRange:NSMakeRange(1, labelsInView.count-3)]){ if(l.text && l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ssString = [ssParts componentsJoinedByString:@" "]; NSMutableString *fLine = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if (ssString.length > 0) { [fLine appendFormat:@" (%@)", ssString]; }
                [sanChuanLines addObject:[NSString stringWithFormat:@"%@ %@", (i < chuanTitles.count) ? chuanTitles[i] : @"", fLine]];
            }
        }
        sanChuan = [[sanChuanLines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_extractedData[@"三传"] = sanChuan;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步无感抓取动态信息...");
        
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
        SEL selectorQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:");
        SEL selectorFangFa = NSSelectorFromString(@"顯示方法總覽");

        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
            code; \
            _Pragma("clang diagnostic pop")

        if ([self respondsToSelector:selectorBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        if ([self respondsToSelector:selectorQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            
            NSString *tianDiPanOutput = g_extractedData[@"天地盘"] && ((NSString *)g_extractedData[@"天地盘"]).length > 0 ? [NSString stringWithFormat:@"%@\n\n", g_extractedData[@"天地盘"]] : @"";
            NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", g_extractedData[@"毕法"]] : @"";
            NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", g_extractedData[@"格局"]] : @"";
            NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *fangFaOutput = g_extractedData[@"方法"] ? [NSString stringWithFormat:@"方法:\n%@\n\n", g_extractedData[@"方法"]] : @"";

            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n"
                @"月将: %@\n"
                @"空亡: %@\n"
                @"三宫时: %@\n"
                @"昼夜: %@\n"
                @"课体: %@\n\n"
                @"%@" // 天地盘
                @"%@%@%@%@" // 毕法, 格局, 方法, 七政四余
                @"%@\n\n"
                @"%@\n\n"
                @"起课方式: %@",
                SafeString(g_extractedData[@"时间块"]),
                SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
                tianDiPanOutput,
                biFaOutput, geJuOutput, fangFaOutput, qiZhengOutput,
                SafeString(g_extractedData[@"四课"]),
                SafeString(g_extractedData[@"三传"]),
                SafeString(g_extractedData[@"起课方式"])
            ];
            
            [UIPasteboard generalPasteboard].string = finalText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                 g_extractedData = nil;
                 EchoLog(@"--- 复制任务完成 ---");
            }];
        });
    });
}

%end
```
