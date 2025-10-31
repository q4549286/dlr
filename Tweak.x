%new
- (void)inspectTianDiPanData {
    // 创建或销毁日志窗口
    if (g_inspectorView) {
        [g_inspectorView removeFromSuperview];
        g_inspectorView = nil;
        g_logTextView = nil;
        return;
    }
    
    g_inspectorView = [[UIView alloc] initWithFrame:CGRectMake(10, 100, self.view.bounds.size.width - 20, 400)];
    g_inspectorView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    g_inspectorView.layer.cornerRadius = 15;
    g_inspectorView.layer.borderColor = [UIColor grayColor].CGColor;
    g_inspectorView.layer.borderWidth = 1.0;
    
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectInset(g_inspectorView.bounds, 10, 10)];
    g_logTextView.backgroundColor = [UIColor clearColor];
    g_logTextView.textColor = [UIColor whiteColor];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    
    [g_inspectorView addSubview:g_logTextView];
    [self.view.window addSubview:g_inspectorView];

    LogToScreen(@"[DEBUG] 开始执行 inspectTianDiPanData...");

    // 1. 找到天地盘视图实例
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖類");
    if (!plateViewClass) {
        LogToScreen(@"[CRITICAL] 找不到类 '六壬大占.天地盤視圖類'");
        return;
    }
    LogToScreen(@"[DEBUG] 成功找到类定义。");

    // ===================================================================
    // 【核心修正】: 使用兼容新旧iOS的API来查找视图
    // ===================================================================
    UIView *plateView = nil;
    NSMutableArray *windowsToSearch = [NSMutableArray array];

    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                [windowsToSearch addObjectsFromArray:scene.windows];
            }
        }
    }
    
    // 如果新API没找到，或者系统版本低于iOS 13，使用旧API作为后备
    if (windowsToSearch.count == 0) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        if ([UIApplication sharedApplication].windows) {
            [windowsToSearch addObjectsFromArray:[UIApplication sharedApplication].windows];
        }
        #pragma clang diagnostic pop
    }

    for (UIWindow *window in windowsToSearch) {
        // 使用递归函数来深度查找
        void (^__block findViewRecursive)(UIView *);
        findViewRecursive = ^(UIView *view) {
            if (plateView) return; // 找到就停止
            if ([view isKindOfClass:plateViewClass]) {
                plateView = view;
                return;
            }
            for (UIView *subview in view.subviews) {
                findViewRecursive(subview);
            }
        };
        findViewRecursive(window);
        if (plateView) break;
    }
    // ======================= 修正结束 ========================


    if (!plateView) {
        LogToScreen(@"[CRITICAL] 遍历所有窗口也找不到 '六壬大占.天地盤視圖類' 的实例。");
        return;
    }
    LogToScreen(@"[SUCCESS] 成功定位到天地盘视图实例: <%p>", plateView);

    // ... 后续的读取和打印逻辑保持不变 ...
    NSArray *ivarSuffixes = @[@"地宮宮名列", @"天神宮名列", @"天將宮名列"];

    for (NSString *suffix in ivarSuffixes) {
        LogToScreen(@"\n--- [TASK] 正在读取后缀为 '%@' 的变量 ---", suffix);
        id dataObject = GetIvarValueSafely(plateView, suffix);
        
        LogToScreen(@"[DEBUG] GetIvarValueSafely 返回的指针地址是: %p", dataObject);

        if (!dataObject) {
            LogToScreen(@"[ERROR] 读取失败: 变量值为 nil。跳过此变量。");
            continue;
        }

        LogToScreen(@"[SUCCESS] 成功读取到非空值。尝试分析...");

        @try {
            LogToScreen(@"[DEBUG] 尝试获取变量类型...");
            NSString *className = NSStringFromClass([dataObject class]);
            LogToScreen(@"[INFO] 变量类型: %@", className);
            
            if ([dataObject isKindOfClass:[NSDictionary class]]) {
                NSDictionary *dataDict = (NSDictionary *)dataObejct;
                LogToScreen(@"[INFO] 确认是 NSDictionary，包含 %lu 个条目:", (unsigned long)dataDict.count);
                
                int i = 0;
                for (id key in dataDict) {
                    CALayer *layer = dataDict[key];
                    NSString *text = GetStringFromLayer(layer);
                    CALayer *pLayer = [layer presentationLayer] ?: layer; 
                    
                    LogToScreen(@"  [%d] Key: %@ -> Text: '%@'", i, key, text);
                    LogToScreen(@"      - Position: {%.1f, %.1f}", pLayer.position.x, pLayer.position.y);
                    i++;
                }
            } else {
                LogToScreen(@"[WARNING] 变量不是预期的 NSDictionary 类型。");
            }
        } @catch (NSException *exception) {
            LogToScreen(@"\n\n[CRASH DETECTED!] 在分析变量 '%@' 时发生崩溃!", suffix);
            LogToScreen(@"[CRASH INFO] 原因: %@", exception.reason);
            LogToScreen(@"[CRASH INFO] 详细信息: %@", exception.userInfo);
        }
    }
    
    LogToScreen(@"\n--- [COMPLETE] 检查完毕 ---");
}
