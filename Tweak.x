// [开发者]
// 请将此代码块完整粘贴到您的Tweak文件中，
// 替换掉旧的 startStandardExtraction, findTextInViewWithClassName, 和 formatPalaceLine 方法。

%new
- (void)startStandardExtraction {
    if (g_isExtracting) return;
    LogMessage(EchoLogTypeTask, @"[奇门] “提取奇门盘”任务已启动 (数据模型模式)。");
    g_isExtracting = YES;
    [self showProgressHUD:@"正在提取奇门盘..."];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSMutableString *reportContent = [NSMutableString string];
        
        // ==========================================================
        // 1. 提取顶部核心参数 (逻辑不变)
        // ==========================================================
        [reportContent appendString:@"// 1. 核心参数\n"];
        NSString *topInfo = [self findTextInViewWithClassName:@"CZJuShiView" separator:@"\n"]; 
        NSRange range = [topInfo rangeOfString:@"时家拆补飞盘"];
        if (range.location != NSNotFound) {
            topInfo = [topInfo substringToIndex:range.location];
        }
        [reportContent appendFormat:@"%@\n\n", SafeString(topInfo)];

        // ==========================================================
        // 2. 提取九宫格详情 (全新数据模型提取法)
        // ==========================================================
        [reportContent appendString:@"// 2. 九宫格详情\n"];

        Class containerClass = NSClassFromString(@"CZShowGongsCollectionView");
        if (containerClass) {
            NSMutableArray *containerViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive(containerClass, self.view, containerViews);

            if (containerViews.count > 0) {
                UIView *containerView = containerViews.firstObject;
                
                // 使用运行时直接获取 _gongsDataSource 实例变量
                Ivar dataSourceIvar = class_getInstanceVariable(containerClass, "_gongsDataSource");
                if (dataSourceIvar) {
                    // 从 containerView 实例中获取 ivar 的值
                    id dataSource = object_getIvar(containerView, dataSourceIvar);
                    
                    if (dataSource && [dataSource isKindOfClass:[NSArray class]]) {
                        NSArray *gongsData = (NSArray *)dataSource;
                        LogMessage(EchoLogTypeSuccess, @"[奇门] 成功访问数据源，共 %lu 个宫位模型。", (unsigned long)gongsData.count);

                        // 准备一个排序字典，确保输出顺序正确
                        NSDictionary *sortOrder = @{@"坎": @1, @"坤": @2, @"震": @3, @"巽": @4, @"中": @5, @"乾": @6, @"兑": @7, @"艮": @8, @"离": @9};
                        
                        NSArray *sortedGongs = [gongsData sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                            NSString *gongName1 = [obj1 valueForKey:@"gongName"];
                            NSString *gongName2 = [obj2 valueForKey:@"gongName"];
                            NSNumber *order1 = sortOrder[[gongName1 substringToIndex:1]];
                            NSNumber *order2 = sortOrder[[gongName2 substringToIndex:1]];
                            return [order1 compare:order2];
                        }];


                        for (id model in sortedGongs) {
                            // 使用 KVC (valueForKey) 安全地读取我们不知道头文件的对象的属性
                            NSString *gongName = [model valueForKey:@"gongName"];
                            NSString *tianPan = [model valueForKey:@"tianPan"];
                            NSString *diPan = [model valueForKey:@"diPan"];
                            NSString *shenName = [model valueForKey:@"shenName"];
                            NSString *xingName = [model valueForKey:@"xingName"];
                            NSString *menName = [model valueForKey:@"menName"];
                            NSString *tianGanTop = [model valueForKey:@"tianGanTop"];
                            NSString *tianGanBottom = [model valueForKey:@"tianGanBottom"];
                            BOOL isMaXing = [[model valueForKey:@"isMaXing"] boolValue];
                            BOOL isXunKong = [[model valueForKey:@"isXunKong"] boolValue];
                            
                            // 组合成我们想要的格式
                            NSString *specialSymbols = @"";
                            if (isMaXing) specialSymbols = [specialSymbols stringByAppendingString:@" 马"];
                            if (isXunKong) specialSymbols = [specialSymbols stringByAppendingString:@" O"];
                            
                            NSString *xingPart = [NSString stringWithFormat:@"%@ %@", xingName, tianGanTop];
                            NSString *menPart = [NSString stringWithFormat:@"%@ %@", menName, tianGanBottom];

                            [reportContent appendFormat:@"- %@ (%@%@): %@ | %@ | %@\n", gongName, tianPan, diPan, shenName, xingPart, menPart];
                        }

                    } else {
                        [reportContent appendString:@"[提取失败: _gongsDataSource 不是一个数组或为空]\n"];
                    }
                } else {
                    [reportContent appendString:@"[提取失败: 找不到 _gongsDataSource 实例变量]\n"];
                }
            } else {
                [reportContent appendString:@"[提取失败: 未找到 CZShowGongsCollectionView 视图]\n"];
            }
        } else {
            [reportContent appendString:@"[提取失败: 找不到 CZShowGongsCollectionView 类]\n"];
        }
        [reportContent appendString:@"\n"];

        // ==========================================================
        // 3. 提取底部附加信息 (逻辑不变)
        // ==========================================================
        [reportContent appendString:@"// 3. 附加信息\n"];
        NSString *bottomInfo = [self findTextInViewWithClassName:@"CZJuShiView" separator:@"\n"]; 
        range = [bottomInfo rangeOfString:@"年命"];
        if (range.location != NSNotFound) {
            bottomInfo = [bottomInfo substringFromIndex:range.location];
            range = [bottomInfo rangeOfString:@"时间流"];
            if (range.location != NSNotFound) {
                bottomInfo = [bottomInfo substringToIndex:range.location];
            }
        }
        [reportContent appendFormat:@"%@\n", [SafeString(bottomInfo) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        
        // ==========================================================
        // 4. 生成并输出报告
        // ==========================================================
        g_lastGeneratedReport = formatFinalReport(reportContent);
        
        [self hideProgressHUD];
        [self showEchoNotificationWithTitle:@"提取完成" message:@"奇门盘数据已生成并复制"];
        [self presentAIActionSheetWithReport:g_lastGeneratedReport];
        LogMessage(EchoLogTypeSuccess, @"[奇门] “提取奇门盘”任务完成。");
        g_isExtracting = NO;
    });
}

%new
- (NSString *)findTextInViewWithClassName:(NSString *)className separator:(NSString *)separator {
    Class targetClass = NSClassFromString(className);
    if (!targetClass) return [NSString stringWithFormat:@"[错误: 找不到类 %@]", className];
    
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(targetClass, self.view, targetViews);
    
    if (targetViews.count == 0) return [NSString stringWithFormat:@"[提取失败: 未找到 %@ 视图]", className];
    
    UIView *container = targetViews.firstObject;
    NSMutableArray *labels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], container, labels);
    
    [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) {
        if (roundf(l1.frame.origin.y) < roundf(l2.frame.origin.y)) return NSOrderedAscending;
        if (roundf(l1.frame.origin.y) > roundf(l2.frame.origin.y)) return NSOrderedDescending;
        return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)];
    }];
    
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labels) {
        if (label.text.length > 0 && !label.isHidden) {
            [textParts addObject:label.text];
        }
    }
    
    return [textParts componentsJoinedByString:separator];
}

// 注意：旧的 formatPalaceLine 方法现在已经不需要了，您可以删除它来保持代码整洁。

// 最后，更新 viewDidLoad hook
%hook UIViewController
- (void)viewDidLoad {
    %orig;
    // [已更新] 使用您找到的主视图控制器类名
    Class targetClass = NSClassFromString(@"CZQMHomeViewController"); 
    if (targetClass && [self isKindOfClass:targetClass] && self.navigationController) {
        // ... (后续创建按钮的代码保持不变) ...
        // 防止重复添加
        if (g_mainViewController) return;

        g_mainViewController = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;
            // 移除旧按钮（如果存在）
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) {
                [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview];
            }
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"Echo 面板" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2);
            controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}
// ... (其他 %new 方法) ...
%end
