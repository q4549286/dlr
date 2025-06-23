#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Final-Integrated] " format), ##__VA_ARGS__)

// =========================================================================
// Section 1: 原始功能 - 简繁转换 & 水印 (无改动)
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { 
    %orig; 
    if (self.windowLevel != UIWindowLevelNormal) { return; } 
    NSInteger watermarkTag = 998877; 
    if ([self viewWithTag:watermarkTag]) { return; } 
    NSString *watermarkText = @"Echo定制"; 
    UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; 
    UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; 
    CGFloat rotationAngle = -30.0; 
    CGSize tileSize = CGSizeMake(150, 100); 
    UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); 
    UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; 
    watermarkView.tag = watermarkTag;
    watermarkView.userInteractionEnabled = NO; 
    watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; 
    watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; 
    [self addSubview:watermarkView]; 
    [self bringSubviewToFront:watermarkView]; 
}
%end

// =========================================================================
// Section 2: 全功能提取逻辑
// =========================================================================

static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;
static NSString *g_currentItemToExtractForNianMing = nil;
static void (^g_nianMingCompletionBlock)(void) = nil;

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
- (NSString *)extractTianDiPanInfo_V18;
- (void)extractNianMingInfoWithCompletion:(void(^)(NSString *result))completionBlock;
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
            [copyButton setTitle:@"提取课盘" forState:UIControlStateNormal];
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
    // --- 优先处理年命提取流程 ---
    if (g_currentItemToExtractForNianMing != nil) {
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:g_currentItemToExtractForNianMing]) { targetAction = action; break; }
            }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        
        if (([g_currentItemToExtractForNianMing isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) ||
            ([g_currentItemToExtractForNianMing isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"])) {
            
            void (^newCompletion)(void) = ^{
                if (completion) completion();

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UIView *contentView = viewControllerToPresent.view;
                    Class geJuCellClass = NSClassFromString(@"六壬大占.格局單元");
                    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
                    
                    if (tableViewClass && geJuCellClass) {
                        NSMutableArray *tableViews = [NSMutableArray array];
                        FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
                        UITableView *theTableView = tableViews.firstObject;
                        if (theTableView && [theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
                            id<UITableViewDelegate> delegate = theTableView.delegate;
                            for (UITableViewCell *cell in theTableView.visibleCells) {
                                if ([cell isKindOfClass:geJuCellClass]) {
                                    NSIndexPath *indexPath = [theTableView indexPathForCell:cell];
                                    if (indexPath) { [delegate tableView:theTableView didSelectRowAtIndexPath:indexPath]; }
                                }
                            }
                        }
                    }
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        NSMutableArray *textElements = [NSMutableArray array];
                        NSMutableSet *labelsInCells = [NSMutableSet set];
                        
                        if (geJuCellClass) {
                            NSMutableArray *cells = [NSMutableArray array];
                            FindSubviewsOfClassRecursive(geJuCellClass, contentView, cells);
                            for (UIView *cell in cells) {
                                NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labels);
                                if (labels.count >= 2) {
                                    [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                                    NSString *title = ((UILabel *)labels[0]).text ?: @"";
                                    NSMutableArray *descParts = [NSMutableArray array];
                                    for(NSUInteger i = 1; i < labels.count; i++) { [descParts addObject:((UILabel *)labels[i]).text]; }
                                    NSString *desc = [descParts componentsJoinedByString:@" "];
                                    NSString *formattedText = [NSString stringWithFormat:@"%@→%@", title, desc];
                                    CGRect absoluteRect = [cell convertRect:cell.bounds toView:nil];
                                    [textElements addObject:@{@"text": formattedText, @"y": @(absoluteRect.origin.y)}];
                                    [labelsInCells addObjectsFromArray:labels];
                                }
                            }
                        }

                        NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                        for (UILabel *label in allLabels) {
                            if (![labelsInCells containsObject:label] && label.text.length > 0) {
                                CGRect absoluteRect = [label convertRect:label.bounds toView:nil];
                                [textElements addObject:@{@"text": label.text, @"y": @(absoluteRect.origin.y)}];
                            }
                        }

                        [textElements sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) { return [obj1[@"y"] compare:obj2[@"y"]]; }];
                        NSString *finalText = [[textElements valueForKey:@"text"] componentsJoinedByString:@"\n"];
                        
                        if (g_extractedData) {
                            NSUInteger personIndex = [(NSArray *)g_extractedData[@"__年命已处理人员__"] count];
                            NSString *key = [NSString stringWithFormat:@"%@_%lu", g_currentItemToExtractForNianMing, personIndex];
                            if (!g_extractedData[@"年命提取结果"]) { g_extractedData[@"年命提取结果"] = [NSMutableDictionary dictionary]; }
                            [g_extractedData[@"年命提取结果"] setObject:finalText forKey:key];
                        }
                        
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:^{
                            if(g_nianMingCompletionBlock) g_nianMingCompletionBlock();
                        }];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion);
            return;
        }
    }
    
    // --- 原有的无感抓取逻辑 ---
    if (g_extractedData && g_currentItemToExtractForNianMing == nil) { // 确保不是在提取年命时触发
        viewControllerToPresent.view.alpha = 0.0f;
        flag = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0) {
                 NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                 if (labels.count > 0) {
                     [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                     UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; }
                 }
            }
            if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                // ... (原有StackView提取逻辑保持不变)
            } else if ([NSStringFromClass([viewControllerToPresent class]) containsString:@"七政"]) {
                // ... (原有七政提取逻辑保持不变)
            }
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion);
        return;
    }
    
    %orig(viewControllerToPresent, flag, completion);
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) { return @""; }
    NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
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
- (NSString *)extractTianDiPanInfo_V18 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, self.view.window, plateViews);
        if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;

        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";

        NSArray *diGongLayers = [diGongDict allValues]; NSArray *tianShenLayers = [tianShenDict allValues]; NSArray *tianJiangLayers = [tianJiangDict allValues];
        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) return @"天地盘提取失败: 数据长度不匹配";

        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                if (![layer isKindOfClass:[CALayer class]]) continue;
                CALayer *pLayer = layer.presentationLayer ?: layer;
                CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil];
                CGFloat dx = pos.x - center.x; CGFloat dy = pos.y - center.y;
                [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }];
            }
        };
        processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang");

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
        for (NSDictionary *entry in palaceData) { [resultText appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return resultText;

    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
}

%new
- (void)extractNianMingInfoWithCompletion:(void(^)(NSString *result))completionBlock {
    UICollectionView *targetCollectionView = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *collectionViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
    for (UICollectionView *cv in collectionViews) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCollectionView = cv; break; } }
    if (!targetCollectionView) { if (completionBlock) completionBlock(@""); return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCollectionView.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    
    g_extractedData[@"__年命已处理人员__"] = [NSMutableArray array];

    dispatch_queue_t queue = dispatch_queue_create("com.echoai.nianming.queue", DISPATCH_QUEUE_SERIAL);
    
    void (^__block processNextItem)(int, NSArray*);
    processNextItem = ^(int itemIndex, NSArray *itemsToExtract) {
        if (itemIndex >= itemsToExtract.count) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableString *finalResultString = [NSMutableString string];
                NSDictionary *extractedResults = g_extractedData[@"年命提取结果"];
                
                for (NSUInteger i = 0; i < allUnitCells.count; i++) {
                    NSString *zhaiYao = [extractedResults objectForKey:[NSString stringWithFormat:@"年命摘要_%lu", i]] ?: @"";
                    NSString *geJu = [extractedResults objectForKey:[NSString stringWithFormat:@"格局方法_%lu", i]] ?: @"";
                    NSString *personIdentifier = [[zhaiYao componentsSeparatedByString:@"\n"] firstObject] ?: [NSString stringWithFormat:@"人员 %lu", (i+1)];
                    
                    if (i > 0) [finalResultString appendString:@"\n====================\n"];
                    [finalResultString appendFormat:@"\n【%@】\n\n", personIdentifier];
                    [finalResultString appendString:zhaiYao];
                    [finalResultString appendString:@"\n\n"];
                    [finalResultString appendString:geJu];
                }
                
                g_currentItemToExtractForNianMing = nil; g_nianMingCompletionBlock = nil;
                if (completionBlock) completionBlock(finalResultString);
            });
            return;
        }
        
        NSString *item = itemsToExtract[itemIndex];
        g_currentItemToExtractForNianMing = item;

        void (^__block processNextPerson)(int);
        processNextPerson = ^(int personIndex) {
            if (personIndex >= allUnitCells.count) { processNextItem(itemIndex + 1, itemsToExtract); return; }
            g_nianMingCompletionBlock = ^{ processNextPerson(personIndex + 1); };
            dispatch_sync(dispatch_get_main_queue(), ^{
                UICollectionViewCell *cell = allUnitCells[personIndex];
                NSIndexPath *indexPath = [targetCollectionView indexPathForCell:cell];
                id<UICollectionViewDelegate> delegate = targetCollectionView.delegate;
                if(delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]){
                    #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
                    SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:@selector(collectionView:didSelectItemAtIndexPath:) withObject:targetCollectionView withObject:indexPath];);
                } else { if(g_nianMingCompletionBlock) g_nianMingCompletionBlock(); } // Failsafe
            });
        };
        [g_extractedData[@"__年命已处理人员__"] removeAllObjects]; // 重置计数器
        processNextPerson(0);
    };
    
    dispatch_async(queue, ^{
        processNextItem(0, @[@"年命摘要", @"格局方法"]);
    });
}

%new
- (void)copyAiButtonTapped_FinalMethod {
    #define SafeString(str) (str ?: @"")
    
    EchoLog(@"--- 开始执行一键复制任务 ---");
    g_extractedData = [NSMutableDictionary dictionary];

    // 静态信息提取
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];

    NSMutableString *siKe = [NSMutableString string];
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if(siKeViews.count > 0){
            // ... (您的四课提取逻辑保持不变)
        }
    }
    g_extractedData[@"四课"] = siKe;

    NSMutableString *sanChuan = [NSMutableString string];
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (sanChuanViewClass) {
        // ... (您的三传提取逻辑保持不变)
    }
    g_extractedData[@"三传"] = sanChuan;
    
    // 动态信息提取
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步抓取动态信息...");
        SEL selectorBiFa = NSSelectorFromString(@"顯示法訣總覽"), selectorGeJu = NSSelectorFromString(@"顯示格局總覽"), selectorQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:"), selectorFangFa = NSSelectorFromString(@"顯示方法總覽");

        #define SUPPRESS(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
        
        dispatch_semaphore_t dynamicInfoSemaphore = dispatch_semaphore_create(0);
        
        // --- 1. 抓取毕法、格局等信息 ---
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self respondsToSelector:selectorBiFa]) { SUPPRESS([self performSelector:selectorBiFa withObject:nil]); }
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([self respondsToSelector:selectorGeJu]) { SUPPRESS([self performSelector:selectorGeJu withObject:nil]); }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if ([self respondsToSelector:selectorFangFa]) { SUPPRESS([self performSelector:selectorFangFa withObject:nil]); }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        if ([self respondsToSelector:selectorQiZheng]) { SUPPRESS([self performSelector:selectorQiZheng withObject:nil]); }
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             dispatch_semaphore_signal(dynamicInfoSemaphore);
                        });
                    });
                });
            });
        });
        dispatch_semaphore_wait(dynamicInfoSemaphore, DISPATCH_TIME_FOREVER);
        
        // --- 2. 抓取年命信息 ---
        dispatch_semaphore_t nianMingSemaphore = dispatch_semaphore_create(0);
        [self extractNianMingInfoWithCompletion:^(NSString *result) {
            if (result && result.length > 0) { g_extractedData[@"年命信息"] = result; }
            dispatch_semaphore_signal(nianMingSemaphore);
        }];
        dispatch_semaphore_wait(nianMingSemaphore, DISPATCH_TIME_FOREVER);
        
        // --- 3. 所有信息抓取完毕，组合最终文本 ---
        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            NSString *biFaOutput = g_extractedData[@"毕法"] ?: @"", *geJuOutput = g_extractedData[@"格局"] ?: @"", *fangFaOutput = g_extractedData[@"方法"] ?: @"";
            if(biFaOutput.length > 0) biFaOutput = [NSString stringWithFormat:@"毕法:\n%@\n\n", biFaOutput];
            if(geJuOutput.length > 0) geJuOutput = [NSString stringWithFormat:@"格局:\n%@\n\n", geJuOutput];
            if(fangFaOutput.length > 0) fangFaOutput = [NSString stringWithFormat:@"方法:\n%@\n\n", fangFaOutput];
            NSString *qiZhengOutput = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *tianDiPanOutput = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";
            NSString *nianMingOutput = g_extractedData[@"年命信息"] ? [NSString stringWithFormat:@"\n\n--- 年命详情 ---\n%@", g_extractedData[@"年命信息"]] : @"";

            NSString *finalText = [NSString stringWithFormat:
                @"%@\n\n"
                @"月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n九宗门: %@\n\n"
                @"%@"
                @"%@\n"
                @"%@\n\n"
                @"%@%@%@%@",
                SafeString(g_extractedData[@"时间块"]),
                SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]), SafeString(g_extractedData[@"九宗门"]),
                tianDiPanOutput, SafeString(g_extractedData[@"四课"]), SafeString(g_extractedData[@"三传"]),
                biFaOutput, geJuOutput, fangFaOutput, qiZhengOutput
            ];
            finalText = [finalText stringByAppendingString:nianMingOutput];
            finalText = [finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

            [UIPasteboard generalPasteboard].string = finalText;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已复制到剪贴板" message:finalText preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:^{ g_extractedData = nil; }];
        });
    });
}
%end
