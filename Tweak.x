// =========================================================================
// Section 3: 【新功能】一键复制到 AI (全新重构 - 信号量同步 + 格局支持)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;
// 新增：用于同步弹窗抓取操作的信号量
static dispatch_semaphore_t g_modalScrapingSemaphore = NULL;

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

// 【关键修改】重构 presentViewController hook
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    // 只有在执行复制任务时才进行拦截
    if (g_extractedData && g_modalScrapingSemaphore) {
        EchoLog(@"弹窗事件被触发，准备抓取内容...");
        // 延迟一小段时间确保视图完全加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableArray *labels = [NSMutableArray array];
            [self findSubviewsOfClass:[UILabel class] inView:viewControllerToPresent.view andStoreIn:labels];
            
            [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
                if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
                if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
                return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
            }];
            
            NSMutableArray *textParts = [NSMutableArray array];
            NSString *title = viewControllerToPresent.title ?: @"";
            
            // 如果标题为空，尝试从第一个 label 获取
            if(title.length == 0 && labels.count > 0) {
                title = ((UILabel*)labels.firstObject).text;
            }

            for (UILabel *label in labels) {
                if (label.text && label.text.length > 0 && ![label.text isEqualToString:title]) {
                     // 统一过滤掉所有弹窗中不需要的标题行
                     if (![label.text isEqualToString:@"毕法"] && ![label.text isEqualToString:@"格局"]) {
                        [textParts addObject:label.text];
                    }
                }
            }
            
            NSString *content = [textParts componentsJoinedByString:@"\n"];

            // 根据标题或内容判断存到哪个 key
            if ([title containsString:@"七政"]) {
                g_extractedData[@"七政"] = content;
                EchoLog(@"成功抓取 [七政] 内容");
            } else if ([title containsString:@"法诀"]) { // 法诀对应毕法
                g_extractedData[@"毕法"] = content;
                EchoLog(@"成功抓取 [毕法] 内容");
            } else if ([title containsString:@"格局"]) { // 新增：格局
                g_extractedData[@"格局"] = content;
                EchoLog(@"成功抓取 [格局] 内容");
            } else {
                 EchoLog(@"抓取到未知弹窗，标题: %@，内容被忽略。", title);
            }
            
            // 【关键修改】不再直接关闭弹窗，而是发送信号通知主控流程
            EchoLog(@"内容抓取完毕，发送信号...");
            dispatch_semaphore_signal(g_modalScrapingSemaphore);
        });
    }
    // 正常执行原始的 presentViewController
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
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        if (roundf(obj1.frame.origin.y) < roundf(obj2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(obj1.frame.origin.y) > roundf(obj2.frame.origin.y)) return NSOrderedDescending;
        return [@(obj1.frame.origin.x) compare:@(obj2.frame.origin.x)];
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

    // 静态信息提取（同步执行）
    EchoLog(@"正在提取主界面静态信息...");
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"起课方式"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"四课"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.四課視圖" separator:@"\n"]; // 四课用换行符更清晰
    g_extractedData[@"三传"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三傳視圖" separator:@"\n"]; // 三传也用换行符
    EchoLog(@"主界面信息提取完毕。");

    // 【关键修改】使用后台线程和信号量来同步抓取动态弹窗信息
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步任务，顺序抓取动态信息...");
        
        // 定义需要触发的弹窗选择器（Selector）
        // !!! 注意: '顯示格局總覽' 是基于'六壬大占.格局總覽視圖'推测的方法名，如果无效，需要您用 FLEX 等工具确认准确的方法名
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽"); 
        SEL selectorQiZheng = NSSelectorFromString(@"顯示七政信息:");

        // 使用宏来抑制编译器关于 performSelector 的警告
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
            code; \
            _Pragma("clang diagnostic pop")

        // 封装的抓取单个弹窗的 Block
        void (^scrapeModal)(SEL, id) = ^(SEL selector, id object) {
            if ([self respondsToSelector:selector]) {
                EchoLog(@"准备触发选择器: %@", NSStringFromSelector(selector));
                g_modalScrapingSemaphore = dispatch_semaphore_create(0);
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selector withObject:object]);
                });
                
                // 等待信号，超时设置为5秒，防止无限等待
                if (dispatch_semaphore_wait(g_modalScrapingSemaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) != 0) {
                    EchoLog(@"等待 %@ 超时!", NSStringFromSelector(selector));
                } else {
                    EchoLog(@"收到 %@ 的信号，继续...", NSStringFromSelector(selector));
                }
                
                // 抓取完毕后，在主线程关闭当前弹窗
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (self.presentedViewController) {
                        [self.presentedViewController dismissViewControllerAnimated:NO completion:nil];
                    }
                });
                
                g_modalScrapingSemaphore = nil;
                [NSThread sleepForTimeInterval:0.2]; // 短暂休眠，给UI关闭动画一点时间，防止操作过快
            } else {
                EchoLog(@"错误: 未找到选择器 '%@'", NSStringFromSelector(selector));
            }
        };

        // 按顺序执行抓取
        scrapeModal(selectorBiFa, nil);
        scrapeModal(selectorGeJu, nil);
        scrapeModal(selectorQiZheng, nil);
        
        // 所有信息收集完毕，回到主线程组合文本并显示
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            
            // 格式化输出，如果某个字段不存在则不显示
            NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"毕法:\n%@\n\n", g_extractedData[@"毕法"]] : @"";
            NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"格局:\n%@\n\n", g_extractedData[@"格局"]] : @"";
            NSString *qiZhengOutput = g_extractedData[@"七政"] ? [NSString stringWithFormat:@"七政:\n%@\n\n", g_extractedData[@"七政"]] : @"";
            
            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n"
                @"月将: %@\n"
                @"空亡: %@\n"
                @"三宫时: %@\n"
                @"昼夜: %@\n"
                @"课体: %@\n\n"
                @"%@" // 毕法
                @"%@" // 格局
                @"%@" // 七政
                @"四课:\n%@\n\n"
                @"三传:\n%@\n\n"
                @"起课方式: %@",
                SafeString(g_extractedData[@"时间块"]),
                SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
                biFaOutput,
                geJuOutput,
                qiZhengOutput,
                SafeString(g_extractedData[@"四课"]),
                SafeString(g_extractedData[@"三传"]),
                SafeString(g_extractedData[@"起课方式"])
            ];
            
            [UIPasteboard generalPasteboard].string = finalText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                // 在用户点击“好的”之后才清理数据
                g_extractedData = nil;
                EchoLog(@"--- 复制任务完成，数据已清理 ---");
            }];
            [alert addAction:okAction];
            [self presentViewController:alert animated:YES completion:nil];
        });
    });
}
%end
