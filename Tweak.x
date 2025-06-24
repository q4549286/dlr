#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[Popup-Detective] " format, ##__VA_ARGS__)

// --- 辅助函数 ---
static id GetIvarFromObject(id object, const char *ivarName) { Ivar ivar = class_getInstanceVariable([object class], ivarName); if (ivar) { return object_getIvar(object, ivar); } return nil; }

// 新增一个打印对象所有ivar的辅助函数
static void PrintAllIvars(id object, NSString *objectName) {
    if (!object) {
        EchoLog(@"对象 '%@' 为 nil", objectName);
        return;
    }
    unsigned int ivarCount;
    Ivar *ivars = class_copyIvarList([object class], &ivarCount);
    NSMutableString *ivarLog = [NSMutableString stringWithFormat:@"\n--- %@ (%@) 的实例变量 (Ivars) ---\n", objectName, NSStringFromClass([object class])];
    for (unsigned int i = 0; i < ivarCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        [ivarLog appendFormat:@"? %s (%s)\n", name, type];
    }
    free(ivars);
    EchoLog(@"%@", ivarLog);
}

// --- Hook 弹窗的 ViewController ---
// 【关键】我们需要知道弹窗VC的真实类名，根据你之前的截图，它叫 六壬大占.課傳摘要視圖
// 但它本身是UIView，它的控制器可能叫 六壬大占.課傳摘要視圖控制器
// 我们先假设它就是 六壬大占.課傳摘要視圖，如果不行再换
%hook 六壬大占.課傳摘要視圖

// 我们Hook它的初始化方法或viewDidLoad
- (void)viewDidLoad {
    EchoLog(@"--- 成功Hook到弹窗的 viewDidLoad ---");

    // 1. 打印弹窗VC自己的所有Ivars
    PrintAllIvars(self, @"弹窗自己 (self)");

    // 2. 打印创建它的那个VC (主VC) 的所有Ivars
    // presentingViewController 是指向主VC的属性
    UIViewController *presentingVC = self.presentingViewController;
    PrintAllIvars(presentingVC, @"主VC (presentingViewController)");

    // 3. 尤其关注主VC的 '課傳' 这个ivar，看看在弹窗时它的值是什么
    if (presentingVC) {
        id keChuanObject = GetIvarFromObject(presentingVC, "課傳");
        if (keChuanObject) {
            EchoLog(@"--- 在弹窗时，主VC的'課傳'对象存在！---");
            // 打印这个'課傳'对象的内部
            PrintAllIvars(keChuanObject, @"主VC的'課傳'对象");
        }
    }
    
    // 调用原始方法，让弹窗正常显示
    %orig;
}

// 为了以防万一，我们也hook一下天将的弹窗
%end

%hook 六壬大占.天將摘要視圖
- (void)viewDidLoad {
     EchoLog(@"--- 成功Hook到天将弹窗的 viewDidLoad ---");
     PrintAllIvars(self, @"天将弹窗自己 (self)");
     PrintAllIvars(self.presentingViewController, @"主VC (presentingViewController)");
    %orig;
}
%end


// --- 用于触发的调试脚本 ---
@interface UIViewController (EchoAIDetectiveTrigger)
- (void)triggerDetectivePopup;
@end

%hook 六壬大占.ViewController
- (void)viewDidLoad {
    %orig;
    // 添加一个按钮来触发一次点击，以便我们观察Hook的日志
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.frame = CGRectMake(10, keyWindow.bounds.size.height - 60, 150, 44);
        [button setTitle:@"触发侦查弹窗" forState:UIControlStateNormal];
        button.backgroundColor = [UIColor systemOrangeColor];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(triggerDetectivePopup) forControlEvents:UIControlEventTouchUpInside];
        [keyWindow addSubview:button];
    });
}

%new
- (void)triggerDetectivePopup {
    EchoLog(@"--- 准备触发一次点击来启动侦查 ---");
    // 我们手动点击一次“初传地支”，来触发弹窗
    id keChuanShiTu = GetIvarFromObject(self, "課傳");
    if (keChuanShiTu) {
        id sanChuanContainer = GetIvarFromObject(keChuanShiTu, "三傳視圖"); // 假设課傳視圖内部有三傳視圖
        if(sanChuanContainer){
            id chuChuanView = GetIvarFromObject(sanChuanContainer, "初傳");
            if(chuChuanView){
                id dizhiLabel = GetIvarFromObject(chuChuanView, "傳神字");
                if(dizhiLabel){
                    [self performSelector:@selector(顯示課傳摘要WithSender:) withObject:dizhiLabel];
                }
            }
        } else {
             EchoLog(@"在'課傳視圖'中未找到'三傳視圖'");
        }
    }
}
%end
