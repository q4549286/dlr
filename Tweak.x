// ==========================================================
// 核心提取逻辑 (v3.2 最终编译修复版)
// ==========================================================
%new
- (void)startStandardExtraction {
    if (g_isExtracting) return;
    LogMessage(EchoLogTypeTask, @"[奇门] v3.2 提取任务启动 (终极完美版)...");
    g_isExtracting = YES;
    [self showProgressHUD:@"正在精准提取..."];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableString *reportContent = [NSMutableString string];
        
        // --- 1. 提取顶部概览 ---
        @try {
            Class juShiViewClass = NSClassFromString(@"CZJuShiView");
            Class baziViewClass = NSClassFromString(@"CZShowBaZiView");
            if(juShiViewClass && baziViewClass) {
                NSMutableArray *juShiViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive(juShiViewClass, self.view, juShiViews);
                UIView *juShiView = (juShiViews.count > 0) ? juShiViews.firstObject : nil;
                NSMutableArray *baziViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive(baziViewClass, self.view, baziViews);
                UIView *baziView = (baziViews.count > 0) ? baziViews.firstObject : nil;
                if (juShiView && baziView) {
                    NSDate *dateUse = [juShiView valueForKey:@"dateUse"];
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    NSString *timeStr = [formatter stringFromDate:dateUse];
                    Ivar baZiIvar = class_getInstanceVariable(baziViewClass, "_baZi");
                    Ivar juTouIvar = class_getInstanceVariable(baziViewClass, "_juTou");
                    if (baZiIvar && juTouIvar) {
                        id baZiModel = object_getIvar(baziView, baZiIvar);
                        id juTouModel = object_getIvar(baziView, juTouIvar);
                        if (baZiModel && juTouModel) {
                            NSString *nianZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"nianGan"]), SafeString([baZiModel valueForKey:@"nianZhi"])];
                            NSString *yueZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"yueGan"]), SafeString([baZiModel valueForKey:@"yueZhi"])];
                            NSString *riZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"riGan"]), SafeString([baZiModel valueForKey:@"riZhi"])];
                            NSString *shiZhu = [NSString stringWithFormat:@"%@%@", SafeString([baZiModel valueForKey:@"shiGan"]), SafeString([baZiModel valueForKey:@"shiZhi"])];
                            NSString *juStr = SafeString([juTouModel valueForKey:@"juStr"]);
                            NSString *shiKong = SafeString([juTouModel valueForKey:@"shiKong"]);
                            NSString *zhiFu = SafeString([juTouModel valueForKey:@"zhiFu"]);
                            NSString *zhiShi = SafeString([juTouModel valueForKey:@"zhiShi"]);
                            NSString *起局方式 = @"时家拆补"; 
                            
                            NSMutableString *geJuStr = [NSMutableString string];
                            Class geJuCellClass = NSClassFromString(@"CZShowShiJianGeCollectionViewCell");
                            if(geJuCellClass) {
                                 NSMutableArray *geJuCells = [NSMutableArray array];
                                 FindSubviewsOfClassRecursive(geJuCellClass, self.view, geJuCells);
                                 for(UIView* cell in geJuCells) {
                                    UILabel* label = [cell valueForKey:@"label"];
                                    if(label.text) [geJuStr appendFormat:@"%@ ", label.text];
                                 }
                            }
                            [reportContent appendFormat:@"%@ | %@ | %@ | %@ | %@\n", timeStr, 起局方式, juStr, shiKong, [geJuStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                            [reportContent appendFormat:@"值符: %@ | 值使: %@\n", zhiFu, zhiShi];
                            [reportContent appendFormat:@"四柱: %s %s %s %s\n\n", [nianZhu UTF8String], [yueZhu UTF8String], [riZhu UTF8String], [shiZhu UTF8String]];
                        }
                    }
                }
            }
        } @catch (NSException *exception) {
            [reportContent appendString:@"[顶部提取失败]\n\n"];
            LogMessage(EchoLogError, @"[CRASH-DEBUG] 顶部提取失败: %@", exception);
        }

        // --- 2. 提取九宫格详情 ---
        Class cellClass = NSClassFromString(@"CZGongChuanRenThemeCollectionViewCell");
        if (!cellClass) {
            [reportContent appendString:@"[提取失败: 找不到九宫格Cell类]\n"];
        } else {
            NSMutableArray *allCells = [NSMutableArray array];
            FindSubviewsOfClassRecursive(cellClass, self.view, allCells);
            if (allCells.count >= 9) {
                Ivar gongIvar = class_getInstanceVariable(cellClass, "_gong");
                if (gongIvar) {
                    NSMutableArray *gongItems = [NSMutableArray array];
                    for (UIView *cell in allCells) {
                        id model = object_getIvar(cell, gongIvar);
                        if (model) { [gongItems addObject:@{@"model": model, @"cell": cell}]; }
                    }
                    
                    NSDictionary *sortOrder = @{@"坎":@1, @"坤":@2, @"震":@3, @"巽":@4, @"中":@5, @"乾":@6, @"兑":@7, @"艮":@8, @"离":@9};
                    [gongItems sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                         NSString *gongName1 = [obj1[@"model"] valueForKey:@"gongHouTianNameStr"];
                         NSString *gongName2 = [obj2[@"model"] valueForKey:@"gongHouTianNameStr"];
                         if (!gongName1 || gongName1.length < 1 || !gongName2 || gongName2.length < 1) return NSOrderedSame;
                         NSNumber *order1 = sortOrder[[gongName1 substringToIndex:1]];
                         NSNumber *order2 = sortOrder[[gongName2 substringToIndex:1]];
                         return [order1 compare:order2 ? order2 : @(99)];
                    }];

                    for (NSDictionary *item in gongItems) {
                        @try {
                            id model = item[@"model"];
                            UIView *cell = item[@"cell"];
                            
                            NSString *gongName = SafeString([model valueForKey:@"gongHouTianNameStr"]);
                            if ([gongName containsString:@"中5宫"]) {
                                [reportContent appendString:@"{中宫||中|地盘己|}\n"];
                                continue;
                            }
                            
                            NSString *tianPanGan = SafeString([model valueForKey:@"tianPanGanStr"]);
                            NSString *diPanGan = SafeString([model valueForKey:@"diPanGanStr"]);
                            NSString *baShen = SafeString([model valueForKey:@"baShenStr"]);
                            NSString *jiuXing = SafeString([model valueForKey:@"jiuXingStr"]);
                            NSString *baMen = SafeString([model valueForKey:@"baMenStr"]);
                            BOOL isMaXing = [[model valueForKey:@"isMaXing"] boolValue];
                            BOOL isKongWang = [[model valueForKey:@"isKongWang"] boolValue];
                            NSString *yinGan = SafeString([model valueForKey:@"yinGanStr"]);
                            NSString *tianPanJiGan = SafeString([model valueForKey:@"tianPanJiGanStr"]);
                            NSString *diPanJiGan = SafeString([model valueForKey:@"diPanJiGanStr"]);
                            
                            NSString *xingWangShuai = [SafeString([[cell valueForKey:@"labelXingWangShuai"] text]) stringByReplacingOccurrencesOfString:@"`" withString:@""];
                            NSString *menWangShuai = [SafeString([[cell valueForKey:@"labelMenWangShuai"] text]) stringByReplacingOccurrencesOfString:@"`" withString:@""];
                            NSString *tianPan12 = SafeString([[cell valueForKey:@"labelTianPanGan12ZhangSheng"] text]);
                            NSString *diPan12 = SafeString([[cell valueForKey:@"labelDiPanGan12ZhangSheng"] text]);
                            NSString *tianPanJiGan12 = SafeString([[cell valueForKey:@"labelTianPanJiGan12ZhangSheng"] text]);
                            NSString *diPanJiGan12 = SafeString([[cell valueForKey:@"labelDiPanJiGan12ZhangSheng"] text]);

                            NSString *gongGua = SafeString([[cell valueForKey:@"labelGongGuaShuNeiWaiPan"] text]);
                            NSString *gongWangShuai = @"";
                            NSArray *gongGuaParts = [gongGua componentsSeparatedByString:@" "];
                            if (gongGuaParts.count > 2) { gongWangShuai = gongGuaParts[2]; }
                            
                            NSString *tianPan12Final = (tianPanJiGan.length > 0) ? tianPanJiGan12 : tianPan12;
                            NSString *diPan12Final = (diPanJiGan.length > 0) ? diPanJiGan12 : diPan12;
                            
                            NSMutableString *xingPart = [NSMutableString stringWithFormat:@"%@(%@,%@)", jiuXing, xingWangShuai, tianPan12Final];
                            NSMutableString *menPart = [NSMutableString stringWithFormat:@"%@(%@,%@)", baMen, menWangShuai, diPan12Final];
                            
                            NSMutableString *tiandiPart = [NSMutableString string];
                            [tiandiPart appendFormat:@"天盘%@%@", tianPanGan, (tianPanJiGan.length > 0) ? [NSString stringWithFormat:@"(%@)", tianPanJiGan]:@""];
                            [tiandiPart appendFormat:@"(%@) ", tianPan12];
                            [tiandiPart appendFormat:@"地盘%@%@", diPanGan, (diPanJiGan.length > 0) ? [NSString stringWithFormat:@"(%@)", diPanJiGan]:@""];
                            [tiandiPart appendFormat:@"(%@)", diPan12];
                            
                            NSMutableString *otherPart = [NSMutableString string];
                            if(isKongWang) [otherPart appendString:@"空亡 "];
                            if(yinGan.length > 0) [otherPart appendFormat:@"暗干%@ ", yinGan];
                            if(isMaXing) [otherPart appendString:@"马星"];
                            
                            // [编译修复] 在格式化字符串中为 otherPart 添加了 %@
                            [reportContent appendFormat:@"{%@(%@)|%@|%@|%@|%@|%@}\n",
                                gongName, gongWangShuai, xingPart, baShen, menPart, tiandiPart, [otherPart stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
                            ];
                        } @catch (NSException *exception) {
                            LogMessage(EchoLogError, @"[CRASH-DEBUG] 宫位提取失败: %@", exception);
                            continue;
                        }
                    }
                }
            }
        }
        
        // 底部信息提取被我暂时注释掉了，因为我们还没有最终确认它的精确容器
        // [reportContent appendString:@"// 3. 附加信息\n"];
        // ...
        
        g_lastGeneratedReport = formatFinalReport(reportContent);
        
        [self hideProgressHUD];
        [self showEchoNotificationWithTitle:@"提取完成" message:@"专家格式报告已生成"];
        [self presentAIActionSheetWithReport:g_lastGeneratedReport];
        LogMessage(EchoLogTypeSuccess, @"[奇门] v3.2 提取任务完成。");
        g_isExtracting = NO;
    });
}
