#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 极简独立测试版 (V12 - 角色分配修正版)
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
        // 1. 查找视图和字典
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

        // 2. 计算所有 layer 的几何信息，并打上类型标签
        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds));

        void (^processLayers)(NSDictionary *, NSString *) = ^(NSDictionary *dict, NSString *type) {
            for (CALayer *layer in [dict allValues]) {
                if (![layer respondsToSelector:@selector(string)]) continue;
                
                CGPoint pos = layer.position;
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                
                NSMutableDictionary *info = [NSMutableDictionary dictionary];
                info[@"type"] = type;
                info[@"text"] = [layer valueForKey:@"string"] ?: @"";
                info[@"angle"] = @(atan2(dy, dx));
                [allLayerInfos addObject:info];
            }
        };

        processLayers(diGongDict, @"diPan");
        processLayers(tianShenDict, @"tianPan");
        processLayers(tianJiangDict, @"tianJiang");

        // 3. 根据角度对所有36个layer进行分组 (放宽阈值)
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSMutableDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff > M_PI) diff = 2 * M_PI - diff;
                if (diff < 0.2) { // 阈值从 0.1 调大到 0.2
                    [palaceGroups[groupAngle] addObject:info];
                    foundGroup = YES;
                    break;
                }
            }
            if (!foundGroup) {
                palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];
            }
        }
        
        // 4. 整理分组数据 (使用类型标签分配角色)
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSArray *group = palaceGroups[groupAngle];
            if (group.count != 3) {
                 EchoLog(@"警告：一个宫位分组的数量不是3，已跳过。数量: %lu", (unsigned long)group.count);
                 continue;
            }

            NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithDictionary:@{@"diPan": @"?", @"tianPan": @"?", @"tianJiang": @"??"}];
            for (NSDictionary *info in group) {
                entry[info[@"type"]] = info[@"text"];
            }
            [palaceData addObject:entry];
        }

        // 5. 按地盘（子丑寅卯...）顺序进行最终排序
        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            NSString *diPan1 = [obj1[@"diPan"] description];
            NSString *diPan2 = [obj2[@"diPan"] description];
            NSUInteger index1 = [diPanOrder indexOfObject:diPan1];
            NSUInteger index2 = [diPanOrder indexOfObject:diPan2];
            return [@(index1) compare:@(index2)];
        }];

        // 6. 格式化输出
        NSMutableString *resultText = [NSMutableString string];
        [resultText appendFormat:@"天地盤數據 (V12) - 共%ld组\n\n", (unsigned long)palaceData.count];
        for (NSDictionary *entry in palaceData) {
            [resultText appendFormat:@"%@宮: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取结果" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ...
    }
}

%end
