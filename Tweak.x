#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量与辅助函数
// =========================================================================

static const NSInteger kEchoControlButtonTag = 556699;
static const NSInteger kEchoMainPanelTag = 778899;

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) { frontmostWindow = window; break; }
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

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) { [storage addObject:view]; }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
    }
}

// =========================================================================
// 2. 接口声明
// =========================================================================

@interface UIViewController (EchoCoordsExtractor)
- (void)createOrShowExtractorPanel;
- (void)extractAndLogCoordinates;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
- (NSString *)GetStringFromLayer:(id)layer;
@end

// =========================================================================
// 3. 核心 Hook 与实现
// =========================================================================

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow || [keyWindow viewWithTag:kEchoControlButtonTag]) return;
            
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"推衍课盘" forState:UIControlStateNormal];
            controlButton.backgroundColor = [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0];
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            [controlButton addTarget:self action:@selector(createOrShowExtractorPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowExtractorPanel {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) return;

    UIView *existingPanel = [keyWindow viewWithTag:kEchoMainPanelTag];
    if (existingPanel) {
        [existingPanel removeFromSuperview];
        return;
    }

    UIView *panel = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
    panel.center = keyWindow.center;
    panel.tag = kEchoMainPanelTag;
    panel.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    panel.layer.cornerRadius = 15;
    panel.clipsToBounds = YES;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 30)];
    titleLabel.text = @"坐标提取工具";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [panel addSubview:titleLabel];

    UIButton *extractButton = [UIButton buttonWithType:UIButtonTypeSystem];
    extractButton.frame = CGRectMake(50, 80, 200, 50);
    [extractButton setTitle:@"提取天地盘坐标" forState:UIControlStateNormal];
    extractButton.backgroundColor = [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0];
    [extractButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    extractButton.layer.cornerRadius = 10;
    [extractButton addTarget:self action:@selector(extractAndLogCoordinates) forControlEvents:UIControlEventTouchUpInside];
    [panel addSubview:extractButton];
    
    [keyWindow addSubview:panel];
}

%new
- (void)extractAndLogCoordinates {
    NSLog(@"[Echo-Coords-Extractor] ========== 开始提取天地盘坐标 ==========");
    
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖");
        if (!plateViewClass) {
            NSLog(@"[Echo-Coords-Extractor] 错误: 找不到视图类 六壬大占.天地盤視圖");
            return;
        }
        
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow) {
            NSLog(@"[Echo-Coords-Extractor] 错误: 找不到 keyWindow");
            return;
        }

        NSMutableArray *plateViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews);
        if (plateViews.count == 0) {
            NSLog(@"[Echo-Coords-Extractor] 错误: 找不到 天地盤視圖 实例");
            return;
        }
        
        UIView *plateView = plateViews.firstObject;
        
        id diGongDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"];
        id tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"];
        id tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"];

        if (!diGongDict || !tianShenDict || !tianJiangDict) {
            NSLog(@"[Echo-Coords-Extractor] 错误: 未能获取核心数据字典");
            return;
        }

        NSMutableString *logOutput = [NSMutableString string];
        [logOutput appendString:@"\n\n// --- 天将坐标 ---\n"];
        
        for (CALayer *layer in [tianJiangDict allValues]) {
            CALayer *pLayer = [layer presentationLayer] ?: layer;
            CGPoint positionInView = [plateView.layer convertPoint:pLayer.position fromLayer:pLayer.superlayer];
            NSString *name = [self GetStringFromLayer:layer];
            [logOutput appendFormat:@"@{@\"name\": @\"%@\", @\"type\": @\"tianJiang\", @\"point\": [NSValue valueWithCGPoint:CGPointMake(%.2f, %.2f)]},\n", name, positionInView.x, positionInView.y];
        }

        [logOutput appendString:@"\n// --- 宫位坐标 ---\n"];
        // 为了获取宫位（地支）的坐标，我们直接用天盘神的位置，因为它们是对齐的
        for (CALayer *layer in [tianShenDict allValues]) {
            CALayer *pLayer = [layer presentationLayer] ?: layer;
            CGPoint positionInView = [plateView.layer convertPoint:pLayer.position fromLayer:pLayer.superlayer];
            NSString *name = [self GetStringFromLayer:layer]; // 注意：这里用天盘神的名字（亥、子、丑...）来代表宫位地支
            [logOutput appendFormat:@"@{@\"name\": @\"%@\", @\"type\": @\"gongWei\", @\"point\": [NSValue valueWithCGPoint:CGPointMake(%.2f, %.2f)]},\n", name, positionInView.x, positionInView.y];
        }

        NSLog(@"[Echo-Coords-Extractor] 提取完成！请复制下面的代码块到你的 Tweak 中：\n\n%@", logOutput);
        
        // 自动关闭面板
        [[keyWindow viewWithTag:kEchoMainPanelTag] removeFromSuperview];

    } @catch (NSException *exception) {
        NSLog(@"[Echo-Coords-Extractor] 提取过程中发生异常: %@", exception.reason);
    }
    
    NSLog(@"[Echo-Coords-Extractor] ========== 提取结束 ==========");
}

%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix {
    if (!object || !ivarNameSuffix) return nil;
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    if (!ivars) {
        free(ivars);
        return nil;
    }
    id value = nil;
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name) {
            NSString *ivarName = [NSString stringWithUTF8String:name];
            if ([ivarName hasSuffix:ivarNameSuffix]) {
                value = object_getIvar(object, ivar);
                break;
            }
        }
    }
    free(ivars);
    return value;
}

%new
- (NSString *)GetStringFromLayer:(id)layer {
    if (layer && [layer respondsToSelector:@selector(string)]) {
        id stringValue = [layer valueForKey:@"string"];
        if ([stringValue isKindOfClass:[NSString class]]) return stringValue;
        if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string;
    }
    return @"?";
}

%end

%ctor {
    NSLog(@"[Echo-Coords-Extractor] 坐标提取工具已加载。");
}
