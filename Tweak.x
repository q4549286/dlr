#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 最终决战版 (V15 - 内省版)
// 目标: 对获取到的字典对象进行内省，找到其获取数据的方法
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Final] " format), ##__VA_ARGS__)

// ... 辅助函数 ...
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
static NSString* GetStringFromLayer(id layer) {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}

// 新增：调用未知对象的 allValues (或类似) 方法
static NSArray* GetValuesFromUnknownDictionary(id dict) {
    if (!dict) return nil;
    // 优先尝试标准方法
    if ([dict respondsToSelector:@selector(allValues)]) {
        return [dict allValues];
    }
    // 如果标准方法不行，就动态查找
    unsigned int methodCount;
    Method *methods = class_copyMethodList([dict class], &methodCount);
    if (!methods) return nil;
    SEL targetSelector = NULL;
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL selector = method_getName(methods[i]);
        NSString *methodName = NSStringFromSelector(selector);
        // 寻找无参数且看起来像返回值的 getter
        if (![methodName containsString:@":"] && ([methodName containsString:@"values"] || [methodName containsString:@"getObjects"])) {
            targetSelector = selector;
            break;
        }
    }
    free(methods);
    if (targetSelector) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id result = [dict performSelector:targetSelector];
        #pragma clang diagnostic pop
        if ([result isKindOfClass:[NSArray class]]) return result;
    }
    return nil;
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
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) return;
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) return;
        id plateView = plateViews.firstObject;

        id diGongDict = GetIvarValueSafely(plateView, @"地宮宮名列");
        id tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        id tianJiangDict = GetIvarValueSafely(plateView, @"天將宮名列");

        if (!diGongDict || !tianShenDict || !tianJiangDict) return;

        // 使用新方法获取values
        NSArray *diGongLayers = GetValuesFromUnknownDictionary(diGongDict);
        NSArray *tianShenLayers = GetValuesFromUnknownDictionary(tianShenDict);
        NSArray *tianJiangLayers = GetValuesFromUnknownDictionary(tianJiangDict);

        if (!diGongLayers || !tianShenLayers || !tianJiangLayers || diGongLayers.count != 12) {
             UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取失败" message:@"无法从字典对象中获取values数组" preferredStyle:UIAlertControllerStyleAlert];
             [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
             [self presentViewController:alert animated:YES completion:nil];
             return;
        }

        // 使用 V11 的几何排序逻辑，这是最可靠的
        NSMutableArray *allLayerInfos = [NSMutableArray array];
        CGPoint center = CGPointMake(CGRectGetMidX(((UIView *)plateView).bounds), CGRectGetMidY(((UIView *)plateView).bounds));
        
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) {
            for (CALayer *layer in layers) {
                CGPoint pos = layer.position;
                CGFloat dx = pos.x - center.x;
                CGFloat dy = pos.y - center.y;
                [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)) }];
            }
        };
        processLayers(diGongLayers, @"diPan");
        processLayers(tianShenLayers, @"tianPan");
        processLayers(tianJiangLayers, @"tianJiang");
        
        // 分组和排序... (V11的逻辑)
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO;
            for (NSNumber *groupAngle in [palaceGroups allKeys]) {
                CGFloat diff = fabsf([info[@"angle"] floatValue] - [groupAngle floatValue]);
                if (diff < 0.1) { [palaceGroups[groupAngle] addObject:info]; foundGroup = YES; break; }
            }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) {
            NSMutableArray *group = palaceGroups[groupAngle];
            if (group.count < 3) continue;
            [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }];
            [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }];
        }
        
        NSArray *diPanOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
            return [@([diPanOrder indexOfObject:o1[@"diPan"]]) compare:@([diPanOrder indexOfObject:o2[@"diPan"]])];
        }];

        NSMutableString *resultText = [NSMutableString string];
        [resultText appendString:@"天地盤數據\n\n"];
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
