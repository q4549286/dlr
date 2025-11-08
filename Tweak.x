#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =======================================================================================
//
//  Echo 天地盘坐标校准工具 v1.0
//
//  - 功能: 专门用于提取“天地盘”中“天神”(上神)十二宫的原始屏幕坐标。
//  - 用法:
//    1. 独立安装此脚本，并暂时禁用主分析脚本。
//    2. 在App主界面，点击新增的红色“校准坐标”按钮。
//    3. 查看Xcode或设备控制台的日志输出。
//    4. 将输出的坐标代码块复制，用于更新主脚本中的坐标数据库。
//
// =======================================================================================

#pragma mark - Constants & Helpers

// 为校准按钮设置一个独立的Tag，避免与主脚本冲突
static const NSInteger kCoordinateCalibrationButtonTag = 112233;

// 辅助函数：递归查找指定类的子视图
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// 辅助函数：获取最顶层的Window
static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        frontmostWindow = [UIApplication sharedApplication].keyWindow;
    #pragma clang diagnostic pop
    }
    return frontmostWindow;
}

#pragma mark - Core Logic & UI Hook

@interface UIViewController (EchoCoordinateTool)
- (void)runCoordinateExtraction;
@end

%hook UIViewController

// 在主视图控制器加载时，添加我们的校准按钮
- (void)viewDidLoad {
    %orig;

    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:kCoordinateCalibrationButtonTag]) return;

            UIButton *calibButton = [UIButton buttonWithType:UIButtonTypeSystem];
            calibButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45 + 40, 140, 36);
            calibButton.tag = kCoordinateCalibrationButtonTag;
            [calibButton setTitle:@"校准坐标" forState:UIControlStateNormal];
            calibButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            calibButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0]; // 使用醒目的红色
            [calibButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            calibButton.layer.cornerRadius = 18;
            calibButton.layer.shadowColor = [UIColor blackColor].CGColor;
            calibButton.layer.shadowOffset = CGSizeMake(0, 2);
            calibButton.layer.shadowOpacity = 0.4;
            calibButton.layer.shadowRadius = 3;
            [calibButton addTarget:self action:@selector(runCoordinateExtraction) forControlEvents:UIControlEventTouchUpInside];
            
            [keyWindow addSubview:calibButton];
        });
    }
}

// 新增的方法，作为按钮点击后的核心处理逻辑
%new
- (void)runCoordinateExtraction {
    NSLog(@"[坐标校准] 任务启动：开始提取'天神宮名列'的原始坐标...");

    // 1. 查找天地盘视图
    Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖");
    if (!plateViewClass) {
        NSLog(@"[坐标校准] 错误: 找不到天地盘视图类 '六壬大占.天地盤視圖'");
        return;
    }

    UIWindow *keyWindow = GetFrontmostWindow();
    NSMutableArray *plateViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);

    if (plateViews.count == 0) {
        NSLog(@"[坐标校准] 错误: 未在当前界面找到天地盘视图实例。");
        return;
    }
    UIView *plateView = plateViews.firstObject;

    // 2. 使用运行时获取实例变量
    id tianShenDict = nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList(plateViewClass, &ivarCount);

    for (unsigned int i = 0; i < ivarCount; i++) {
        const char* ivarNameCStr = ivar_getName(ivars[i]);
        if (!ivarNameCStr) continue;
        NSString *ivarName = [NSString stringWithUTF8String:ivarNameCStr];
        if ([ivarName hasSuffix:@"天神宮名列"]) { // 精确匹配目标
            tianShenDict = object_getIvar(plateView, ivars[i]);
            NSLog(@"[坐标校准] 成功找到实例变量: %@", ivarName);
            break;
        }
    }
    free(ivars);

    if (!tianShenDict || ![tianShenDict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"[坐标校准] 错误: 未能获取'天神宮名列'的数据字典，或其类型不正确。");
        return;
    }

    // 3. 遍历字典中的所有CALayer，并提取信息
    NSArray *allLayers = [tianShenDict allValues];
    if (allLayers.count != 12) {
         NSLog(@"[坐标校准] 警告: 提取到的天神数量为 %lu, 而非预期的12个。", (unsigned long)allLayers.count);
    }

    NSMutableArray *extractedData = [NSMutableArray array];
    for (id layer in allLayers) {
        if (![layer isKindOfClass:[CALayer class]]) continue;

        CALayer *textLayer = (CALayer *)layer;
        NSString *text = ([textLayer respondsToSelector:@selector(string)]) ? [(id)textLayer string] : @"?";

        // 获取在窗口中的绝对坐标
        CGPoint position = [textLayer.superlayer convertPoint:textLayer.position toView:nil];
        
        [extractedData addObject:@{ @"text": text, @"point": [NSValue valueWithCGPoint:position] }];
    }

    // 4. 按十二地支顺序排序
    NSArray *order = @[@"午", @"巳", @"辰", @"卯", @"寅", @"丑", @"子", @"亥", @"戌", @"酉", @"申", @"未"];
    [extractedData sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSUInteger index1 = [order indexOfObject:obj1[@"text"]];
        NSUInteger index2 = [order indexOfObject:obj2[@"text"]];
        return [@(index1) compare:@(index2)];
    }];

    // 5. 格式化输出
    NSMutableString *outputString = [NSMutableString stringWithString:@"\n\n// ===== [Echo坐标校准工具] 提取结果 (天神/上神) =====\n"];
    [outputString appendString:@"// 请将以下代码块复制到主脚本的 g_tianDiPan_fixedCoordinates 数组中，替换所有 type 为 shangShen 的条目\n\n"];
    
    for (NSDictionary *data in extractedData) {
        NSString *name = data[@"text"];
        CGPoint point = [data[@"point"] CGPointValue];
        [outputString appendFormat:@"        @{@\"name\": @\"上神-%@位\", @\"type\": @\"shangShen\", @\"point\": [NSValue valueWithCGPoint:CGPointMake(%.1f, %.1f)]},\n", name, point.x, point.y];
    }
    [outputString appendString:@"\n// ================== 提取结束 ==================\n\n"];

    NSLog(@"%@", outputString);

    // 6. 弹窗提示用户
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提取完成"
                                                                   message:@"“天神/上神”坐标数据已输出到控制台日志。\n请检查Xcode或设备日志并复制结果。"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end

%ctor {
    @autoreleasepool {
        NSLog(@"[Echo坐标校准] 工具已加载。");
    }
}
