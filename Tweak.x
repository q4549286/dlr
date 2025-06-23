#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define EchoLog(format, ...) NSLog((@"[EchoAI-Final] " format), ##__VA_ARGS__)

// =========================================================================
// Section 1 & 2: 原始代码
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }
%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end
// =========================================================================
// Section 3: 【最终版】一键复制到 AI (整合所有功能)
// =========================================================================
static NSInteger const CopyAiButtonTag = 112233;
static NSMutableDictionary *g_extractedData = nil;

// 辅助函数
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { ptrdiff_t offset = ivar_getOffset(ivar); void **ivar_ptr = (void **)((__bridge void *)object + offset); value = (__bridge id)(*ivar_ptr); break; } } } free(ivars); return value; }
static NSString* GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalMethod;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
@end


%hook UIViewController
- (void)viewDidLoad { %orig; Class targetClass = NSClassFromString(@"六壬大占.ViewController"); if (targetClass && [self isKindOfClass:targetClass]) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ UIWindow *keyWindow = self.view.window; if (!keyWindow || [keyWindow viewWithTag:CopyAiButtonTag]) { return; } UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem]; copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36); copyButton.tag = CopyAiButtonTag; [copyButton setTitle:@"提取课盘" forState:UIControlStateNormal]; copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14]; copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0]; [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; copyButton.layer.cornerRadius = 8; [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalMethod) forControlEvents:UIControlEventTouchUpInside]; [keyWindow addSubview:copyButton]; }); } }

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_extractedData) {
        // --- 拦截操作表 (UIAlertController) ---
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent;
            UIAlertAction *targetAction = nil;
            // 同时检查 "年命摘要" 和其他未来可能的目标
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:@"年命摘要"]) {
                    targetAction = action;
                    break;
                }
            }
            if (targetAction) {
                EchoLog(@"已拦截到目标操作表，自动执行动作。");
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return; // 阻止操作表显示
            }
        }
        // --- 拦截内容视图 ---
        else {
            viewControllerToPresent.view.alpha = 0.0f;
            flag = NO;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
                NSString *title = viewControllerToPresent.title ?: @"";
                 if (title.length == 0) {
                     NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                     if (labels.count > 0) {
                         [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
                         UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; }
                     }
                 }
                NSMutableArray *textParts = [NSMutableArray array];
                
                if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                    // (此处省略了毕法/格局/方法/七政的提取代码，与之前版本相同，为了简洁)
                    // (实际代码中这部分是存在的，只是这里不重复展示)
                } 
                // --- 【新增】处理年命摘要 ---
                else if ([vcClassName containsString:@"年命摘要視圖"]) {
                    EchoLog(@"抓取到 '年命摘要' 页面: %@", title);
                    NSMutableString *currentNianMingText = [NSMutableString string];
                    if (title.length > 0) { [currentNianMingText appendFormat:@"%@\n", title]; }
                    NSMutableArray *contentLabels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UIView class], viewControllerToPresent.view, contentLabels);
                    [contentLabels filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id obj, id bind){ return [obj respondsToSelector:@selector(text)]; }]];
                    [contentLabels sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                    for (UIView *view in contentLabels) {
                        NSString *text = [view valueForKey:@"text"];
                        if (text && text.length > 0 && ![currentNianMingText containsString:text]) { [currentNianMingText appendFormat:@"%@\n", text]; }
                    }
                    // 清理尾部换行并加入年命数组
                    NSString *finalEntry = [currentNianMingText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    [g_extractedData[@"年命"] addObject:finalEntry];
                } else {
                    // (此处省略了毕法/格局/方法/七政的提取代码，与之前版本相同)
                }
                [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// (此处省略了 extractTextFromFirstViewOfClassName 和 extractTianDiPanInfo_V18 方法，与之前版本相同)

%new
- (void)copyAiButtonTapped_FinalMethod {
    // (此处省略了大部分静态信息提取的代码，与之前版本相同)
    
    // ... 假设其他信息已提取 ...
    g_extractedData[@"年命"] = [NSMutableArray array];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        EchoLog(@"开始异步无感抓取动态信息...");

        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")

        // --- 【核心修改】循环提取所有年命信息 ---
        dispatch_sync(dispatch_get_main_queue(), ^{
            Class unitClass = NSClassFromString(@"六壬大占.行年單元");
            if (unitClass) {
                NSMutableArray *collectionViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UICollectionView class], self.view, collectionViews);
                UICollectionView *targetCollectionView = nil;
                for (UICollectionView *cv in collectionViews) {
                    if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) {
                        targetCollectionView = cv;
                        break;
                    }
                }

                if (targetCollectionView && targetCollectionView.delegate) {
                    id delegate = targetCollectionView.delegate;
                    SEL selector = @selector(collectionView:didSelectItemAtIndexPath:);
                    if ([delegate respondsToSelector:selector]) {
                        // 1. 获取所有可见的行年单元格
                        NSMutableArray *unitCells = [NSMutableArray array];
                        for (UICollectionViewCell *cell in targetCollectionView.visibleCells) {
                            if ([cell isKindOfClass:unitClass]) {
                                [unitCells addObject:cell];
                            }
                        }

                        // 2. 按x坐标排序，确保按 A, B, C... 的顺序处理
                        [unitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
                            return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)];
                        }];
                        
                        EchoLog(@"找到 %ld 个行年单元，将依次处理。", (long)unitCells.count);

                        // 3. 循环触发点击和提取
                        for (UICollectionViewCell *cell in unitCells) {
                            NSIndexPath *indexPath = [targetCollectionView indexPathForCell:cell];
                            if (indexPath) {
                                EchoLog(@"正在处理 IndexPath: section=%ld, item=%ld", (long)indexPath.section, (long)indexPath.item);
                                SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([delegate performSelector:selector withObject:targetCollectionView withObject:indexPath];);
                                // 等待上一个的抓取流程完成
                                [NSThread sleepForTimeInterval:0.5]; 
                            }
                        }
                    }
                }
            }
        });
        
        // (此处省略了毕法/格局/方法/七政的 performSelector 代码，与之前版本相同)

        dispatch_async(dispatch_get_main_queue(), ^{
            EchoLog(@"所有信息收集完毕，正在组合最终文本...");
            // (此处省略了大部分最终文本组合的代码，与之前版本相同)
            
            // --- 【核心修改】组合年命信息 ---
            NSString *nianMingOutput = @"";
            NSArray *nianMingEntries = g_extractedData[@"年命"];
            if (nianMingEntries && nianMingEntries.count > 0) {
                nianMingOutput = [NSString stringWithFormat:@"年命:\n%@\n\n", [nianMingEntries componentsJoinedByString:@"\n\n"]];
            }
            
            // ... 组合 finalText ...
            // finalText = [NSString stringWithFormat:..., nianMingOutput, ...];
            
            // (显示最终的 UIAlertController)
        });
    });
}

%end
