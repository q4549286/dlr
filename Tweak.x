#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 最终决战版 (V18 - V8核心 + 终极几何排序)
// 目标: 在V8稳定获取数据的基础上，用最可靠的几何排序法解决配对问题
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Final] " format), ##__VA_ARGS__)

// ... (辅助函数 FindSubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) ...
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

@interface UIViewController (FinalTweak)
- (void)runFinalExtraction;
@end

%hook UIViewController

- (void)viewDidLoad { %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
            [[keyWindow viewWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem]; testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"最终提取" forState:UIControlStateNormal]; testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor purpleColor]; [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton]; [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runFinalExtraction {
    @try {
        // 1. 查找视图 (稳定)
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return;
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return;
        UIView *plateView = plateViews.firstObject;

        // 2. 获取字典对象 (稳定)
        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return;

        // 3. 安全地获取所有 CATextLayer (稳定)
        NSArray *diGongLayers = [diGongDict allValues];
        NSArray *tianShenLayers = [tianShenDict allValues];
        NSArray *tianJiangLayers = [tianJiangDict allValues];
        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) return;

        // 4. 几何排序法 (V11的逻辑，但更安全)
        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];

        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                if (![layer isKindOfClass:[CALayer class]]) continue;
                
                // 获取最可靠的屏幕坐标
                CALayer *pLayer = layer.presentationLayer ?: layer;
                CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil];
                
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                
                [allLayerInfos addObject:@{
                    @"type": type,
                    @"text": GetStringFromLayer(layer),
                    @"angle": @(atan2(dy, dx)),
                    @"radius": @(sqrt(dx*dx + dy*dy))
                }];
            }
        };
        processLayers(diGongLayers, @"diPan");
        processLayers(tianShenLayers, @"tianPan");
        processLayers(tianJiangLayers, @"tianJiang");

        // 5. 分组
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff > M_PI) diff = 2 * M_PI - diff;
                if (diff < 0.15) { // 稍微放宽容错率
                    [palaceGroups[groupAngle] addObject:info];
                    foundGroup = YES;
                    break;
                }
            }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        
        // 6. 整理与排序
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count != 3) continue; // 只处理正好有3个元素的组
            
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) {
                return [o2[@"radius"] compare:o1[@"radius"]]; // 半径大的在前（地->天->将）
            }];
            
            [palaceData addObject:@{
                @"diPan": group[0][@"text"],
                @"tianPan": group[1][@"text"],
                @"tianJiang": group[2][@"text"]
            }];
        }
        
        if (palaceData.count != 12) { /* 错误处理 */ return; }

        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            return [@([diPanOrder indexOfObject:o1[@"diPan"]]) compare:@([diPanOrder indexOfObject:o2[@"diPan"]])];
        }];

        // 7. 输出
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"天地盤數據 (V18)\n\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宮: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取成功" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ...
    }
}
%end
