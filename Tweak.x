#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h> // 引入 QuartzCore

// =========================================================================
// 极简独立测试版 (V11 - 几何排序版)
// 目标: 在V8的稳定基础上，通过几何坐标进行排序
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// ... (辅助函数 FindSubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) ...
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) return nil;
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

@interface UIViewController (FinalTweak)
- (void)runFinalExtraction;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return;
            [[keyWindow viewWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
            testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110, 36);
            [testButton setTitle:@"提取天地盤" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius = 8;
            [testButton addTarget:self action:@selector(runFinalExtraction) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewToFront:testButton];
        });
    }
}

%new
- (void)runFinalExtraction {
    @try {
        // 1. 查找视图和字典 (V8的稳定逻辑)
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return;
        
        UIWindow *keyWindow = self.view.window;
        if (!keyWindow) return;

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return;
        
        UIView *plateView = plateViews.firstObject;

        NSDictionary *diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");
        
        if (!diGongDict || !tianShenDict || !tianJiangDict) return;

        // 2. 安全地获取所有 CATextLayer
        NSArray *diGongLayers = [diGongDict allValues];
        NSArray *tianShenLayers = [tianShenDict allValues];
        NSArray *tianJiangLayers = [tianJiangDict allValues];

        if (diGongLayers.count != 12 || tianShenLayers.count != 12 || tianJiangLayers.count != 12) return;

        // 3. 计算所有 layer 的几何信息
        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds));

        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                if (![layer respondsToSelector:@selector(string)]) continue;
                
                CGPoint pos = layer.position;
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                
                NSMutableDictionary *info = [NSMutableDictionary dictionary];
                info[@"type"] = type;
                info[@"text"] = [layer valueForKey:@"string"] ?: @"";
                info[@"angle"] = @(atan2(dy, dx));
                info[@"radius"] = @(sqrt(dx*dx + dy*dy));
                [allLayerInfos addObject:info];
            }
        };

        processLayers(diGongLayers, @"diPan");
        processLayers(tianShenLayers, @"tianPan");
        processLayers(tianJiangLayers, @"tianJiang");

        // 4. 根据角度对所有36个layer进行分组
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSMutableDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff > M_PI) diff = 2 * M_PI - diff;
                if (diff < 0.1) { // 角度差小于0.1弧度视为同一组
                    [palaceGroups[groupAngle] addObject:info];
                    foundGroup = YES;
                    break;
                }
            }
            if (!foundGroup) {
                palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];
            }
        }
        
        // 5. 整理分组数据
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count < 3) continue; // 忽略不完整的宫位数据

            // 根据半径排序，识别地、天、将
            [group sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                return [obj2[@"radius"] compare:obj1[@"radius"]]; // 半径大的在前（地->天->将）
            }];
            
            NSDictionary *entry = @{
                @"diPan": [group[0][@"text"] description],
                @"tianPan": [group[1][@"text"] description],
                @"tianJiang": [group[2][@"text"] description]
            };
            [palaceData addObject:entry];
        }

        // 6. 按地盘（子丑寅卯...）顺序进行最终排序
        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSString *diPan1 = obj1[@"diPan"];
            NSString *diPan2 = obj2[@"diPan"];
            NSUInteger index1 = [diPanOrder indexOfObject:diPan1];
            NSUInteger index2 = [diPanOrder indexOfObject:diPan2];
            return [@(index1) compare:@(index2)];
        }];

        // 7. 格式化输出
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"天地盤數據 (V11)\n\n"];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宮: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取成功" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // 安全网
    }
}

%end
