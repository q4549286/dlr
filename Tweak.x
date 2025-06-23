// =========================================================================
// Section 3: 【最终版】一键复制到 AI (已整合天地盘 V18 逻辑)
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;

// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) { free(ivars); return nil; }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    }
    free(ivars);
    return value;
}
static NSString* GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}


@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (void)extractMainTextViewContent;
- (NSString *)extractTianDiPanInfo_V18;
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
            NSString *title = viewControllerToPresent.title ?: @"";
            
            if (title.length == 0) { /* 尝试获取标题的代码... */ }

            NSMutableArray *stackViews = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UIStackView class], viewControllerToPresent.view, stackViews);
            
            if (stackViews.count > 0) {
                 NSMutableArray *textParts = [NSMutableArray array];
                [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                
                for (UIStackView *stackView in stackViews) {
                    NSArray *arrangedSubviews = stackView.arrangedSubviews;
                    if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                        UILabel *titleLabel = arrangedSubviews[0];
                        NSString *cleanTitle = [titleLabel.text stringByReplacingOccurrencesOfString:@" 毕法" withString:@""];
                        
                        NSMutableArray *descParts = [NSMutableArray array];
                        for (NSUInteger i = 1; i < arrangedSubviews.count; i++) {
                            if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) {
                                NSString *rawText = ((UILabel *)arrangedSubviews[i]).text;
                                [descParts addObject:[rawText stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                            }
                        }
                        NSString *fullDesc = [descParts componentsJoinedByString:@" "]; 
                        
                        NSString *pairString = [NSString stringWithFormat:@"%@→%@", [cleanTitle stringByReplacingOccurrencesOfString:@"\n" withString:@" "], fullDesc];
                        [textParts addObject:pairString];
                    }
                }
                
                NSString *content = [textParts componentsJoinedByString:@"\n"];
                
                if ([title containsString:@"方法"]) g_extractedData[@"方法"] = content;
                else if ([title containsString:@"格局"]) g_extractedData[@"格局"] = content;
                else g_extractedData[@"毕法"] = content;
                
            } else {
                 EchoLog(@"抓取到未知弹窗 [%@]，内容被忽略。", title);
            }
            
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (void)extractMainTextViewContent {
    NSMutableArray *textViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UITextView class], self.view, textViews);

    for (UITextView *textView in textViews) {
        if (textView.text.length > 0) {
            NSArray *lines = [textView.text componentsSeparatedByString:@"\n"];
            NSMutableArray *qizhengLines = [NSMutableArray array];
            NSMutableArray *tongleiLines = [NSMutableArray array];
            BOOL isQiZhengSection = NO;
            BOOL isTongLeiSection = NO;

            for (NSString *line in lines) {
                NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                if ([trimmedLine isEqualToString:@"七政四余:"]) {
                    isQiZhengSection = YES;
                    isTongLeiSection = NO;
                    continue; // 跳过标题行
                } else if ([trimmedLine containsString:@"通类门"]) {
                    isQiZhengSection = NO;
                    isTongLeiSection = YES;
                    // 跳过类似 "通类门 方法→" 的无用行
                    if ([trimmedLine containsString:@"→"]) continue;
                }
                
                if (isQiZhengSection && trimmedLine.length > 0) {
                    [qizhengLines addObject:trimmedLine];
                } else if (isTongLeiSection && trimmedLine.length > 0) {
                    [tongleiLines addObject:trimmedLine];
                }
            }

            if (qizhengLines.count > 0) {
                g_extractedData[@"七政四余"] = [qizhengLines componentsJoinedByString:@"\n"];
                EchoLog(@"成功抓取主界面 [七政四余]");
            }
            if (tongleiLines.count > 0) {
                g_extractedData[@"通类门"] = [tongleiLines componentsJoinedByString:@"\n"];
                EchoLog(@"成功抓取主界面 [通类门]");
            }
            // 找到一个包含有效内容的TextView后就停止，避免重复
            if(qizhengLines.count > 0 || tongleiLines.count > 0) break;
        }
    }
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { return @""; }
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";

    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];
    
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) {
        if (label.text && label.text.length > 0) {
             [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
        }
    }
    return [textParts componentsJoinedByString:separator];
}

%new
- (NSString *)extractTianDiPanInfo_V18 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;

        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";

        NSArray *diGongLayers = [diGongDict allValues];
        NSArray *tianShenLayers = [tianShenDict allValues];
        NSArray *tianJiangLayers = [tianJiangDict allValues];
        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) return @"天地盘提取失败: 数据长度不匹配";

        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                if (![layer isKindOfClass:[CALayer class]]) continue;
                CALayer *pLayer = layer.presentationLayer ?: layer;
                CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil];
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                [allLayerInfos addObject:@{
                    @"type": type, @"text": GetStringFromLayer(layer),
                    @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy))
                }];
            }
        };
        processLayers(diGongLayers, @"diPan");
        processLayers(tianShenLayers, @"tianPan");
        processLayers(tianJiangLayers, @"tianJiang");

        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff > M_PI) diff = 2 * M_PI - diff;
                if (diff < 0.15) { [palaceGroups[groupAngle] addObject:info]; foundGroup = YES; break; }
            }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count != 3) continue;
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }];
            [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }];
        }
        
        if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整";

        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            return [@([diPanOrder indexOfObject:o1[@"diPan"]]) compare:@([diPanOrder indexOfObject:o2[@"diPan"]])];
        }];

        NSMutableString *resultText = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }
        return resultText;

    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason];
    }
}


%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行复制到AI任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];

    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];
    [self extractMainTextViewContent]; // 提取主界面TextView内容
    
    // 四课和三传代码...
    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if(siKeViews.count > 0){
            UIView* container = siKeViews.firstObject; NSMutableArray* labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels);
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
        NSMutableArray *sanChuanViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, sanChuanViews);
        [sanChuanViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *chuanTitles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *sanChuanLines = [NSMutableArray array];
        for (NSUInteger i = 0; i < sanChuanViews.count; i++) {
            UIView *view = sanChuanViews[i]; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], view, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
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
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽");
        SEL selectorGeJu = NSSelectorFromString(@"顯示格局總覽");
        SEL selectorFangFa = NSSelectorFromString(@"顯示方法總覽");

        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) \
            _Pragma("clang diagnostic push") \
            _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
            code; \
            _Pragma("clang diagnostic pop")

        if ([self respondsToSelector:selectorBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:selectorFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:selectorFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; } 
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *biFaOutput = g_extractedData[@"毕法"] ? [NSString stringWithFormat:@"%@\n\n", g_extractedData[@"毕法"]] : @"";
            NSString *geJuOutput = g_extractedData[@"格局"] ? [NSString stringWithFormat:@"%@\n\n", g_extractedData[@"格局"]] : @"";
            NSString *fangFaOutput = g_extractedData[@"方法"] ? [NSString stringWithFormat:@"%@\n\n", g_extractedData[@"方法"]] : @"";
            NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *tongLeiOutput = g_extractedData[@"通类门"] ? [NSString stringWithFormat:@"%@\n\n", g_extractedData[@"通类门"]] : @"";
            NSString *tianDiPanOutput = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";

            NSString *finalText = [NSString stringWithFormat:
                @"%@\n"
                @"月将: %@\n"
                @"空亡: %@\n"
                @"三宫时: %@\n"
                @"昼夜: %@\n"
                @"课体: %@\n"
                @"九宗门: %@\n\n"
                @"%@" // 天地盘
                @"%@\n" // 四课
                @"%@\n\n" // 三传
                @"%@%@%@%@%@" // 毕法, 格局, 方法, 七政, 通类门
                ,
                SafeString(g_extractedData[@"时间块"]),
                SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]),
                SafeString(g_extractedData[@"九宗门"]),
                tianDiPanOutput,
                SafeString(g_extractedData[@"四课"]),
                SafeString(g_extractedData[@"三传"]),
                biFaOutput, geJuOutput, fangFaOutput, qiZhengOutput, tongLeiOutput
            ];
            
            finalText = [finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            [UIPasteboard generalPasteboard].string = finalText;
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            
            [self presentViewController:alert animated:YES completion:^{
                g_extractedData = nil;
            }];
        });
    });
}

%end
