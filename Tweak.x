#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// =================` 对象中，读取它的 `string` 属性，这个属性里就存着我们最终想要的文字（比如“子========================================================
// 极简独立测试版 (V8 - The Final One)
// 目标”、“贵人”等）。

---

### **最终代码 (V8 - 终极解锁版)**

这是: 将获取到的字典数据解析为最终文本
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGS__)

// ... (辅助函数 Find我们最后的、也是最有信心的版本。它将解开这个“字典”，并从中提取出最终的文字。SubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) ...
static void FindSubviewsOf

```objc
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

ClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if ([view isKindOfClass:a// =========================================================================
// 极简独立测试版 (V8 - 终极解锁版Class]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) { Find)
// 目标: 解析字典并从CATextLayer中提取文字
// =========================================================================

#SubviewsOfClassRecursive(aClass, subview, storage); }
}
static id GetIvarValuedefine EchoLog(format, ...) NSLog((@"[EchoAI-Test] " format), ##__VA_ARGSSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix)__)

// ... (辅助函数 FindSubviewsOfClassRecursive 和 GetIvarValueSafely 保持不变) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvar ...
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {List([object class], &ivarCount);
    if (!ivars) return nil;
    id value =
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
         in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); }
Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
}
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *            if ([ivarName hasSuffix:ivarNameSuffix]) {
                ptrdiff_t offset = ivarivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars)_getOffset(ivar);
                void **ivar_ptr = (void **)((__bridge void *)object + offset return nil;
    id value = nil;
    for (unsigned int i = 0; i < iv);
                value = (__bridge id)(*ivar_ptr);
                break;
            }
        }
    arCount; i++) {
        Ivar ivar = ivars[i];
        const char *name}
    free(ivars);
    return value;
}

// 新增辅助函数：从字典 = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                pt中提取 CATextLayer 的字符串
static NSArray<NSString *> *ExtractStringsFromTextLayerDictionary(NSDictionary *dict) {rdiff_t offset = ivar_getOffset(ivar);
                void **ivar_ptr = (void
    if (!dict ||  **)((__bridge void *)object + offset);
                value = (__bridge id)(*ivar_ptr);
                break;![dict isKindOfClass:[NSDictionary class]]) return nil;
    
    NSMutableArray<NSString *> *strings
            }
        }
    }
    free(ivars);
    return value;
}


 = [NSMutableArray array];
    // 字典的值是 CATextLayer，我们需要遍历它们
    for (id layer in [dict allValues]) {
        if ([layer respondsToSelector:@selector(string)]) {
            id// 新增辅助函数：从可能是字典的对象中提取CATextLayer的文字
static NSArray<NSString *> * stringValue = [layer valueForKey:@"string"];
            if ([stringValue isKindOfClass:[NSString class]]) {
                [strings addObjectExtractStringsFromTextLayerContainer(id container) {
    // 检查对象是否响应 'allValues' 方法:stringValue];
            }
        }
    }
    return [strings copy];
}


@interface UIViewController (TianDiPanTest)
- (void)runTianDiPanTest;
@end

%，这是字典的特征
    if (![container respondsToSelector:@selector(allValues)hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString]) {
        EchoLog(@"对象 %@ 不是一个类字典类型。", container);
        return nil;
    }
    
    // 获取(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0所有值，这些值应该是 CATextLayer
    NSArray *layers = [container allValues];
    if (layers..5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *count == 0) {
        EchoLog(@"容器 %@ 为空。", container);
        return nil;
keyWindow = self.view.window;
            if (!keyWindow) return;
            [[keyWindow view    }
    
    NSMutableArray<NSString *> *strings = [NSMutableArray array];
    for (id layer inWithTag:12345] removeFromSuperview];
            UIButton *testButton = [UIButton buttonWithType:UIButtonType layers) {
        // 检查每个值是否是 CATextLayer，并获取其 string 属性
        System];
            testButton.tag = 12345;
            testButton.frame = CGRectMake(keyWindow.bounds.size.width - 120, 45, 110,if ([layer isKindOfClass:[CATextLayer class]]) {
            CATextLayer *textLayer = (CATextLayer *)layer;
            id layerString = textLayer.string;
            if ([layerString isKindOfClass:[NSString class]]) { 36);
            [testButton setTitle:@"測試天地盤" forState:UIControlStateNormal];
            testButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            testButton.backgroundColor = [
                [strings addObject:layerString];
            } else if ([layerString isKindOfClass:[NSAttributedString class]]) {
                //UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0 如果是富文本，也取其字符串
                [strings addObject:((NSAttributedString *)layerString).string];
            ];
            [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            testButton.layer.cornerRadius}
        }
    }
    
    // 这里需要根据App的逻辑对提取出的字符串进行排序 = 8;
            [testButton addTarget:self action:@selector(runTianDiPanTest) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:testButton];
            [keyWindow bringSubviewTo，因为字典是无序的。
    // 一个合理的猜测是按照地支顺序来排。
    //Front:testButton];
        });
    }
}

%new
- (void)runTianDi 如果输出顺序不对，我们再调整这里的排序逻辑。
    NSArray *diZhiOrder = @[@"子PanTest {
    @try {
        EchoLog(@"--- 开始执行天地盘提取测试 V8 ---");
    ", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申
        // 1. 查找视图
        Class plateViewClass = NSClassFromString(@"六壬大占.天地", @"酉", @"戌", @"亥"];
    [strings sortUsingComparator:^NSComparisonResult(NSString *obj1盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類");
        if (!plateViewClass) { /* ... */ return; }
        
        UIWindow *keyWindow = self.view, NSString *obj2) {
        NSUInteger index1 = [diZhiOrder indexOfObject:obj1.window;
        if (!keyWindow) { return; }

        NSMutableArray *plateViews = [NSMutableArray array];
        NSUInteger index2 = [diZhiOrder indexOfObject:obj2];
        if (index1];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if ( != NSNotFound && index2 != NSNotFound) {
            return [@(index1) compare:@(index2)];
        plateViews.count == 0) { /* ... */ return; }
        
        id plateView = plate}
        return [obj1 compare:obj2]; // 默认排序
    }];

    return [strings copyViews.firstObject;

        // 2. 获取字典对象
        NSDictionary *diGongDict = GetIvar];
}


@interface UIViewController (TianDiPanTest)
- (void)runTianDiPanTestValueSafely(plateView, @"地宮宮名列");
        NSDictionary *tianShenDict = GetIvarValueSafely(plateView, @"天神宮名列");
        NSDictionary *tianJiangDict;
@end

%hook UIViewController

- (void)viewDidLoad { /* ... 保持不变 ... */ }

 = GetIvarValueSafely(plateView, @"天將宮名列");

        // 3.%new
- (void)runTianDiPanTest {
    @try {
        EchoLog(@"--- 从字典中提取字符串数组
        NSArray<NSString *> *diGongStrings = ExtractStringsFromTextLayerDictionary( 开始执行天地盘提取测试 V8 ---");
    
        id plateView = /* ... 查找视图的代码，diGongDict);
        NSArray<NSString *> *tianShenStrings = ExtractStringsFromTextLayerDictionary(保持不变 ... */;
        // ...
        
        // 2. 获取包含CATextLayer的字典对象
        idtianShenDict);
        NSArray<NSString *> *tianJiangStrings = ExtractStringsFromTextLayerDictionary( diGongContainer = GetIvarValueSafely(plateView, @"地宮宮名列");
        id ttianJiangDict);
        
        // 4. 检查并格式化
        NSMutableString *resultTextianShenContainer = GetIvarValueSafely(plateView, @"天神宮名列");
        id = [NSMutableString string];
        if (diGongStrings.count == 12 && tianShenStrings.count tianJiangContainer = GetIvarValueSafely(plateView, @"天將宮名列");

         == 12 && tianJiangStrings.count == 12) {
            [resultText appendString:@"天地盤// 3. 从容器中提取字符串数组
        NSArray<NSString *> *diGongStrings = ExtractStringsFromTextLayerContainer(diGongContainer);
        NSArray<NSString *> *tianShenStrings = ExtractStringsFrom數據提取成功！\n\n"];
            // 这里的排序可能不是固定的，如果输出顺序不对TextLayerContainer(tianShenContainer);
        NSArray<NSString *> *tianJiangStrings = ExtractStringsFromTextLayerContainer(tianJiangContainer);
        
        // 4. 检查并格式化
        NSMutableString *，我们需要根据坐标重新排序，但先看结果
            for (int i = 0; i < 12;resultText = [NSMutableString string];
        BOOL isDataValid = (diGongStrings.count == 1 i++) {
                NSString *dp = diGongStrings[i];
                NSString *tp = tianShen2 && tianShenStrings.count == 12 && tianJiangStrings.count == 12);Strings[i];
                NSString *tj = tianJiangStrings[i];
                [resultText appendFormat

        if (isDataValid) {
            [resultText appendString:@"天地盤數據提取成功！\n:@"%@宮: %@(%@)\n", dp, tp, tj];
            }
        } else\n"];
            for (int i = 0; i < 12; i++) {
                 {
            [resultText appendString:@"从字典提取文字失败！\n\n"];
            [resultTextNSString *dp = diGongStrings[i] ?: @"?";
                NSString *tp = tianShenStrings[i] ?: @"?";
                NSString *tj = tianJiangStrings[i] ?: @"??";
                [ appendFormat:@"地宫文字数: %ld\n", (unsigned long)diGongStrings.count];
            [resultText appendFormat:@"天神文字数: %ld\n", (unsigned long)tianShenStrings.count];
resultText appendFormat:@"%@宮: %@(%@)\n", dp, tp, tj];
            }            [resultText appendFormat:@"天将文字数: %ld\n", (unsigned long)tianJiang
        } else {
            [resultText appendString:@"最终数据解析失败！\n\n"];
            [resultStrings.count];
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"天地盤測試Text appendFormat:@"地宮解析出 %ld 个字符串\n", (unsigned long)diGongStrings.count結果(V8)" message:resultText preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[];
            [resultText appendFormat:@"天神解析出 %ld 个字符串\n", (unsigned long)tUIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alertianShenStrings.count];
            [resultText appendFormat:@"天將解析出 %ld 个字符串\n animated:YES completion:nil];

    } @catch (NSException *exception) {
        // ... ", (unsigned long)tianJiangStrings.count];
        }

        UIAlertController *alert = [UIAlertController alert
    }
}

%end
