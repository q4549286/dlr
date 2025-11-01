#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// =========================================================================
// 1. 全局状态与辅助函数
// =========================================================================

// 状态标志，用于控制提取流程和Hook行为
static BOOL g_isExtractingDetails = NO;
// 任务队列，存放待提取的宫位名称 (e.g., "子", "丑", ...)
static NSMutableArray<NSString *> *g_extractionWorkQueue = nil;
// 结果存储，将宫位名称映射到其提取出的详情文本
static NSMutableDictionary<NSString *, NSString *> *g_extractionResults = nil;
// 当前正在处理的宫位，用于在Hook中正确关联结果
static NSString *g_currentPalaceBeingProcessed = nil;
// 指向原始 presentViewController 方法的指针
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));

// 弹窗，用于显示进度
static UIAlertController *g_progressAlert = nil;

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

// 递归查找指定类的所有子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 安全地获取对象的实例变量值
static id GetIvarValueSafely(id object, NSString *ivarName) {
    if (!object || !ivarName) return nil;
    Ivar ivar = class_getInstanceVariable([object class], [ivarName UTF8String]);
    if (!ivar) return nil;
    return object_getIvar(object, ivar);
}

// 从 CALayer 中提取字符串
static NSString* GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"";
}

// 从弹出的详情视图中提取所有文本
static NSString* extractTextFromPopupView(UIView *popupView) {
    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], popupView, labels);
    
    // 按垂直位置排序，确保文本顺序正确
    [labels sortUsingComparator:^NSComparisonResult(UILabel *obj1, UILabel *obj2) {
        return [@(obj1.frame.origin.y) compare:@(obj2.frame.origin.y)];
    }];
    
    NSMutableString *result = [NSMutableString string];
    for (UILabel *label in labels) {
        if (label.text && label.text.length > 0) {
            [result appendFormat:@"%@\n", [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
    }
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


// =========================================================================
// 2. 核心Hook与方法实现
// =========================================================================

%hook UIViewController

// 新增一个方法，用于处理按钮点击事件
%new
- (void)handleExtractTianDiPanDetailsTapped {
    if (g_isExtractingDetails) {
        NSLog(@"[TDP Extractor] 提取任务已在进行中，请稍候。");
        return;
    }
    
    NSLog(@"[TDP Extractor] 任务启动...");

    // 1. 初始化状态
    g_isExtractingDetails = YES;
    g_extractionWorkQueue = [NSMutableArray array];
    g_extractionResults = [NSMutableDictionary dictionary];
    g_currentPalaceBeingProcessed = nil;

    // 2. 找到天地盘视图，并从中获取12宫的名称列表
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖");
    if (!plateViewClass) {
        NSLog(@"[TDP Extractor] 错误: 找不到 '六壬大占.天地盤視圖' 类。");
        g_isExtractingDetails = NO;
        return;
    }
    
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, self.view, plateViews);
    if (plateViews.count == 0) {
        NSLog(@"[TDP Extractor] 错误: 在当前视图中找不到天地盘实例。");
        g_isExtractingDetails = NO;
        return;
    }
    UIView *plateView = plateViews.firstObject;

    // 3. (关键) 确认ViewController响应我们猜测的“精确制导”方法
    // 根据FLEX分析，方法名很可能是 `顯示指定地宮詳情:`
    SEL directShowSelector = NSSelectorFromString(@"顯示指定地宮詳情:");
    if (![self respondsToSelector:directShowSelector]) {
        NSLog(@"[TDP Extractor] 致命错误: ViewController上找不到方法 '顯示指定地宮詳情:'。无法继续。");
        // 在这里可以弹出一个错误提示给用户
        UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"提取失败" message:@"Tweak与当前App版本不兼容（找不到关键方法）。" preferredStyle:UIAlertControllerStyleAlert];
        [errorAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:errorAlert animated:YES completion:nil];
        g_isExtractingDetails = NO;
        return;
    }

    // 4. 从实例变量中获取宫位名称列表，构建任务队列
    // 注意：这里的实例变量名 `地宮宮名列` 是从你的FLEX截图中直接获得的
    NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
    if (!diGongDict) {
        NSLog(@"[TDP Extractor] 错误: 无法从天地盘视图获取 '地宮宮名列' 实例变量。");
        g_isExtractingDetails = NO;
        return;
    }
    
    for (id key in diGongDict) {
        CALayer *layer = diGongDict[key];
        NSString *palaceName = GetStringFromLayer(layer);
        if (palaceName.length > 0) {
            [g_extractionWorkQueue addObject:palaceName];
        }
    }

    if (g_extractionWorkQueue.count != 12) {
        NSLog(@"[TDP Extractor] 警告: 获取到的宫位数量不是12个 (%lu)，流程可能不完整。", (unsigned long)g_extractionWorkQueue.count);
    }
    
    NSLog(@"[TDP Extractor] 任务队列构建完成，包含 %lu 个宫位。", (unsigned long)g_extractionWorkQueue.count);

    // 5. 显示进度提示并开始处理队列
    g_progressAlert = [UIAlertController alertControllerWithTitle:@"正在提取天地盘详情..." message:@"请稍候 (0/12)" preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:g_progressAlert animated:YES completion:^{
        [self processNextPalaceInQueue];
    }];
}

// 新增一个方法，用于循环处理任务队列
%new
- (void)processNextPalaceInQueue {
    // 终止条件：队列为空，任务完成
    if (g_extractionWorkQueue.count == 0) {
        NSLog(@"[TDP Extractor] 所有宫位提取完成。");
        
        // 格式化最终报告
        NSMutableString *finalReport = [NSMutableString stringWithString:@"// ======== 天地盘十二宫详情 ========\n\n"];
        NSArray *palaceOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        for (NSString *palaceName in palaceOrder) {
            NSString *details = g_extractionResults[palaceName] ?: @"[提取失败]";
            [finalReport appendFormat:@"//--- %@宫 详情 ---\n%@\n\n", palaceName, details];
        }

        // 复制到剪贴板
        [UIPasteboard generalPasteboard].string = finalReport;

        // 关闭进度提示，显示成功信息
        [g_progressAlert dismissViewControllerAnimated:YES completion:^{
            UIAlertController *doneAlert = [UIAlertController alertControllerWithTitle:@"提取完成" message:@"天地盘12宫详情已全部复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [doneAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:doneAlert animated:YES completion:nil];
        }];

        // 重置状态
        g_isExtractingDetails = NO;
        g_extractionWorkQueue = nil;
        g_extractionResults = nil;
        g_currentPalaceBeingProcessed = nil;
        g_progressAlert = nil;
        
        return;
    }

    // 从队列中取出一个任务
    NSString *palaceName = g_extractionWorkQueue.firstObject;
    [g_extractionWorkQueue removeObjectAtIndex:0];
    g_currentPalaceBeingProcessed = palaceName;

    // 更新进度
    if (g_progressAlert) {
        g_progressAlert.message = [NSString stringWithFormat:@"请稍候 (%lu/12)", (unsigned long)(12 - g_extractionWorkQueue.count)];
    }
    
    NSLog(@"[TDP Extractor] 正在处理: %@宫", palaceName);
    
    // (关键) 直接调用App的内部方法来显示详情
    SEL directShowSelector = NSSelectorFromString(@"顯示指定地宮詳情:");
    SUPPRESS_LEAK_WARNING([self performSelector:directShowSelector withObject:palaceName]);
}


// 在主界面加载时，添加我们的触发按钮
- (void)viewDidLoad {
    %orig;

    // 确保只在目标ViewController上添加按钮
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        // 使用dispatch_after确保UI已完全加载
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
            extractButton.frame = CGRectMake(self.view.bounds.size.width - 160, 45, 150, 36);
            [extractButton setTitle:@"提取天地盘详情" forState:UIControlStateNormal];
            extractButton.backgroundColor = [UIColor colorWithRed:0.1 green:0.4 blue:0.7 alpha:1.0];
            [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            extractButton.layer.cornerRadius = 18;
            extractButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            [extractButton addTarget:self action:@selector(handleExtractTianDiPanDetailsTapped) forControlEvents:UIControlEventTouchUpInside];
            
            // 添加阴影，使其更显眼
            extractButton.layer.shadowColor = [UIColor blackColor].CGColor;
            extractButton.layer.shadowOffset = CGSizeMake(0, 2);
            extractButton.layer.shadowOpacity = 0.5;
            extractButton.layer.shadowRadius = 3;
            
            [self.view addSubview:extractButton];
            [self.view bringSubviewToFront:extractButton];
        });
    }
}

%end


// =========================================================================
// 3. 拦截器实现
// =========================================================================

// 这是整个流程的魔法核心：拦截弹窗
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    // 检查是否是我们的提取任务触发的弹窗
    if (g_isExtractingDetails && g_currentPalaceBeingProcessed) {
        // 进一步确认弹窗的类型是否正确
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"詳情視圖"]) {
            NSLog(@"[TDP Extractor] 成功拦截到 %@宫 的详情弹窗。", g_currentPalaceBeingProcessed);
            
            // 延迟一小段时间，确保弹窗的视图内容已经加载完毕
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                // 从弹窗视图中提取文本
                NSString *extractedText = extractTextFromPopupView(vcToPresent.view);
                
                // 将结果存入字典
                g_extractionResults[g_currentPalaceBeingProcessed] = extractedText;
                
                // 清理当前宫位标记
                g_currentPalaceBeingProcessed = nil;
                
                // 继续处理下一个宫位
                [self processNextPalaceInQueue];
            });
            
            // (关键) 直接返回，不调用原始的 presentViewController 方法，这样用户就看不到弹窗了
            return;
        }
    }
    
    // 如果不是我们的任务，就执行原始的弹窗逻辑
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


// =========================================================================
// 4. Tweak初始化
// =========================================================================

%ctor {
    @autoreleasepool {
        // Hook UIViewController 的 presentViewController 方法
        MSHookMessageEx(
            NSClassFromString(@"UIViewController"),
            @selector(presentViewController:animated:completion:),
            (IMP)&Tweak_presentViewController,
            (IMP *)&Original_presentViewController
        );
        
        NSLog(@"[TDP Extractor] 天地盘详情提取Tweak已加载。");
    }
}
