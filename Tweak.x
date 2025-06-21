#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 声明接口 ---
@interface KeChuanObject : NSObject
@property (nonatomic, strong) NSArray<NSString *> *法诀;
@property (nonatomic, strong) NSArray *七政;
@end

@interface UIViewController (CopyAiAddon)
- (void)copyAiButtonTapped_FinalPerfect;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
@end

// --- 关键注入逻辑 ---
static void (*original_viewDidLoad)(id, SEL);

static void new_viewDidLoad(UIViewController *self, SEL _cmd) {
    original_viewDidLoad(self, _cmd); // 调用原始方法

    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if ([self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window;
            if (!keyWindow) return; // 安全检查

            UIButton *copyButton = [UIButton buttonWithType:UIButtonTypeSystem];
            copyButton.frame = CGRectMake(keyWindow.bounds.size.width - 100, 45, 90, 36);
            [copyButton setTitle:@"复制到AI" forState:UIControlStateNormal];
            copyButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            copyButton.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:0.86 alpha:1.0];
            [copyButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            copyButton.layer.cornerRadius = 8;
            [copyButton addTarget:self action:@selector(copyAiButtonTapped_FinalPerfect) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:copyButton];
        });
    }
}

// --- 核心复制方法 ---
static void copyAiButtonTapped_FinalPerfect(UIViewController *self, SEL _cmd) {
    #define SafeString(str) (str ?: @"")

    KeChuanObject *keChuanData = nil;
    @try {
        keChuanData = [self valueForKey:@"课传"];
    } @catch (NSException *exception) {
        // Log error if needed
    }

    NSString *timeBlock = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    // ... (其他界面信息提取，此处省略，完整版我会提供)
    NSString *biFa = @"";
    if (keChuanData && [keChuanData respondsToSelector:@selector(法诀)]) {
        NSArray *biFaArray = [keChuanData valueForKey:@"法诀"];
        if (biFaArray.count > 0) biFa = [biFaArray componentsJoinedByString:@"\n"];
    }
    // ... 组合最终文本并显示弹窗
}

// ... 其他辅助方法的实现 ...

// --- dylib 入口函数 ---
__attribute__((constructor)) static void init() {
    Class vcClass = NSClassFromString(@"六壬大占.ViewController");
    
    // 动态添加我们的复制方法
    class_addMethod(vcClass, @selector(copyAiButtonTapped_FinalPerfect), (IMP)copyAiButtonTapped_FinalPerfect, "v@:");
    // ... 动态添加其他辅助方法 ...

    // Hook viewDidLoad
    Method viewDidLoadMethod = class_getInstanceMethod(vcClass, @selector(viewDidLoad));
    original_viewDidLoad = (void (*)(id, SEL))method_getImplementation(viewDidLoadMethod);
    method_setImplementation(viewDidLoadMethod, (IMP)new_viewDidLoad);
}
