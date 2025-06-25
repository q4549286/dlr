#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// =========================================================================
// 全局变量及辅助函数
// =========================================================================
static UIView *g_loggerPanel = nil;
static UITextView *g_logTextView = nil;
static BOOL g_isTracerArmed = NO;
// 全局Hook存储，用于之后恢复
static NSMutableDictionary<NSString *, NSValue *> *g_originalImplementations = nil;

// 日志函数
static void LogToScreen(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[TracerV14.1] %@", message);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_logTextView) {
            NSString *currentText = g_logTextView.text;
            NSString *newText = [currentText stringByAppendingFormat:@"%@\n", message];
            g_logTextView.text = newText;
            if (newText.length > 0) {
                [g_logTextView scrollRangeToVisible:NSMakeRange(newText.length - 1, 1)];
            }
        }
    });
}

// 动态Hook一个方法的核心函数
static void StartHookingMethod(Class aClass, SEL selector, id block) {
    if (!aClass || !selector || !block) return;
    
    NSString *key = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(aClass), NSStringFromSelector(selector)];
    
    Method originalMethod = class_getInstanceMethod(aClass, selector);
    if (!originalMethod) {
        LogToScreen(@"[Hook错误] 无法在 %@ 中找到方法 %@", NSStringFromClass(aClass), NSStringFromSelector(selector));
        return;
    }
    
    // 保存原始实现
    IMP originalImp = method_getImplementation(originalMethod);
    [g_originalImplementations setObject:[NSValue valueWithPointer:originalImp] forKey:key];
    
    // 设置新的实现
    IMP newImp = imp_implementationWithBlock(block);
    class_replaceMethod(aClass, selector, newImp, method_getTypeEncoding(originalMethod));
}

// 恢复所有被Hook的方法
static void StopAllHooks() {
    if (!g_originalImplementations) return;
    for (NSString *key in g_originalImplementations) {
        NSArray *parts = [key componentsSeparatedByString:@"_"];
        if (parts.count < 2) continue;
        
        NSString *className = parts[0];
        NSString *selectorName = [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)].lastObject;
        
        Class aClass = NSClassFromString(className);
        SEL selector = NSSelectorFromString(selectorName);
        
        IMP originalImp = [[g_originalImplementations objectForKey:key] pointerValue];
        
        if (aClass && selector && originalImp) {
            class_replaceMethod(aClass, selector, originalImp, method_getTypeEncoding(class_getInstanceMethod(aClass, selector)));
        }
    }
    [g_originalImplementations removeAllObjects];
}


// =========================================================================
// 界面与启动逻辑
// =========================================================================
@interface UIViewController (CallTracer)
- (void)toggleTracerPanel_V14_1;
- (void)armAndHideTracer_V14_1;
- (void)copyLogsAndClose_V14_1;
- (void)triggerTraceForIndexPath:(NSIndexPath *)indexPath inCollectionView:(UICollectionView *)collectionView;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            NSInteger buttonTag = 141141;
            if ([keyWindow viewWithTag:buttonTag]) { [[keyWindow viewWithTag:buttonTag] removeFromSuperview]; }
            
            UIButton *loggerButton = [UIButton buttonWithType:UIButtonTypeSystem];
            loggerButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            loggerButton.tag = buttonTag;
            [loggerButton setTitle:@"追溯面板" forState:UIControlStateNormal];
            loggerButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            loggerButton.backgroundColor = [UIColor systemTealColor];
            [loggerButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            loggerButton.layer.cornerRadius = 8;
            [loggerButton addTarget:self action:@selector(toggleTracerPanel_V14_1) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:loggerButton];
        });
    }
}

%new
- (void)toggleTracerPanel_V14_1 {
    if (g_loggerPanel && g_loggerPanel.superview) {
        [g_loggerPanel removeFromSuperview];
        g_loggerPanel = nil;
        g_logTextView = nil;
        StopAllHooks();
        g_isTracerArmed = NO;
        return;
    }
    
    g_originalImplementations = [NSMutableDictionary dictionary];
    UIWindow *keyWindow = self.view.window;
    
    CGFloat panelWidth = keyWindow.bounds.size.width - 20;
    CGFloat panelHeight = 350;
    g_loggerPanel = [[UIView alloc] initWithFrame:CGRectMake(10, 100, panelWidth, panelHeight)];
    g_loggerPanel.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    g_loggerPanel.layer.cornerRadius = 12; g_loggerPanel.clipsToBounds = YES;
    
    UIButton *armButton = [UIButton buttonWithType:UIButtonTypeSystem];
    armButton.frame = CGRectMake(10, 10, panelWidth - 20, 40);
    [armButton setTitle:@"准备追溯 (点击后隐藏)" forState:UIControlStateNormal];
    [armButton addTarget:self action:@selector(armAndHideTracer_V14_1) forControlEvents:UIControlEventTouchUpInside];
    armButton.backgroundColor = [UIColor systemGreenColor];
    [armButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    armButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:armButton];
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(10, 60, panelWidth - 20, panelHeight - 120)];
    g_logTextView.backgroundColor = [UIColor blackColor];
    g_logTextView.textColor = [UIColor greenColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.text = @"请点击上方绿色按钮，然后点击一个【课体】单元格来追溯其调用链。";
    [g_loggerPanel addSubview:g_logTextView];
    
    UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
    copyButton.frame = CGRectMake(10, panelHeight - 50, panelWidth - 20, 40);
    [copyButton setTitle:@"复制日志并关闭" forState:UIControlStateNormal];
    [copyButton addTarget:self action:@selector(copyLogsAndClose_V14_1) forControlEvents:UIControlEventTouchUpInside];
    copyButton.backgroundColor = [UIColor systemOrangeColor];
    [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    copyButton.layer.cornerRadius = 8;
    [g_loggerPanel addSubview:copyButton];
    
    [keyWindow addSubview:g_loggerPanel];
}

%new
- (void)armAndHideTracer_V14_1 {
    g_isTracerArmed = YES;
    if (g_logTextView) { g_logTextView.text = @""; } // 清空日志
    if (g_loggerPanel) { g_loggerPanel.hidden = YES; }
}

%new
- (void)copyLogsAndClose_V14_1 {
    if (g_logTextView.text.length > 0) {
        [UIPasteboard generalPasteboard].string = g_logTextView.text;
    }
    [self toggleTracerPanel_V14_1];
}

// =========================================================================
// 核心追溯逻辑
// =========================================================================

%new
- (void)triggerTraceForIndexPath:(NSIndexPath *)indexPath inCollectionView:(UICollectionView *)collectionView {
    LogToScreen(@"追溯开始！起点: %@, 路径: %@", [collectionView cellForItemAtIndexPath:indexPath], indexPath);
    
    // 1. 建立响应者链
    NSMutableArray<UIResponder *> *responderChain = [NSMutableArray array];
    UIResponder *responder = [collectionView cellForItemAtIndexPath:indexPath];
    while (responder) {
        [responderChain addObject:responder];
        responder = [responder nextResponder];
    }
    LogToScreen(@"\n--- 响应者链 ---");
    for (UIResponder *r in responderChain) {
        LogToScreen(@"-> %@", [r class]);
    }
    LogToScreen(@"--- 响应者链结束 ---\n");

    // 2. 动态Hook链上所有对象的潜在方法
    NSArray *potentialSelectors = @[
        @"touchesBegan:withEvent:",
        @"touchesMoved:withEvent:",
        @"touchesEnded:withEvent:",
        @"touchesCancelled:withEvent:",
        // 最关键的，所有以 handle 或 did 开头的方法
    ];
    
    for (UIResponder *r in responderChain) {
        unsigned int methodCount = 0;
        Method *methods = class_copyMethodList([r class], &methodCount);
        for (unsigned int i = 0; i < methodCount; i++) {
            SEL selector = method_getName(methods[i]);
            NSString *selectorName = NSStringFromSelector(selector);
            
            BOOL shouldHook = NO;
            if ([selectorName hasPrefix:@"handle"] || [selectorName hasPrefix:@"did"] || [selectorName hasPrefix:@"show"] || [selectorName hasPrefix:@"顯示"]) {
                shouldHook = YES;
            }
            
            if (shouldHook) {
                LogToScreen(@"[准备Hook]: %@ -> %@", NSStringFromClass([r class]), selectorName);
                StartHookingMethod([r class], selector, ^(id self, id arg1) { // 简化为最多一个参数
                    LogToScreen(@"\n<<<<<<<<<<<<<<<<< HOOK TRIGGERED >>>>>>>>>>>>>>>>>");
                    LogToScreen(@"[调用追溯]: 对象 [%@] 调用了方法 [%@]", [self class], selectorName);
                    LogToScreen(@"[参数1]: %@", arg1);
                    LogToScreen(@"<<<<<<<<<<<<<<<<<<<<<<<<<>>>>>>>>>>>>>>>>>>>>>>>>>\n");
                    
                    // 调用原始实现
                    NSString *key = [NSString stringWithFormat:@"%@_%@", NSStringFromClass([self class]), selectorName];
                    IMP originalImp = [[g_originalImplementations objectForKey:key] pointerValue];
                    if (originalImp) {
                        ((void (*)(id, SEL, id))originalImp)(self, selector, arg1);
                    }
                });
            }
        }
        free(methods);
    }
    
    LogToScreen(@"Hook已设置。现在重新调用原始 didSelectItemAtIndexPath...");
    
    // 3. 调用原始实现来触发调用链
    NSString *key = [NSString stringWithFormat:@"%@_collectionView:didSelectItemAtIndexPath:", NSStringFromClass([self class])];
    IMP originalImp = [[g_originalImplementations objectForKey:key] pointerValue];
    if (originalImp) {
        ((void (*)(id, SEL, id, id))originalImp)(self, @selector(collectionView:didSelectItemAtIndexPath:), collectionView, indexPath);
    }
    
    LogToScreen(@"\n--- 追溯完毕，请检查以上日志 ---");

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        LogToScreen(@"\n--- 自动清理Hooks ---");
        StopAllHooks();
        if(g_loggerPanel) {
            g_loggerPanel.hidden = NO;
        }
    });
}

// 这是我们主Hook点
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (g_isTracerArmed) {
        g_isTracerArmed = NO;
        
        Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
        if ([self isKindOfClass:targetVCClass]) {
            // 在主方法中保存原始实现
             StartHookingMethod([self class], @selector(collectionView:didSelectItemAtIndexPath:), nil); // 只是为了保存
            // 触发我们的追溯逻辑
            [self triggerTraceForIndexPath:indexPath inCollectionView:collectionView];
            return; // 阻止原始的%orig被调用，因为我们已经在triggerTrace内部手动调用了
        }
    }
    
    %orig;
}

%end
