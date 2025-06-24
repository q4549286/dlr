#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define EchoLog(format, ...) NSLog(@"[Popup-Detective-V2] " format, ##__VA_ARGS__)

// --- 辅助函数：打印一个对象的所有实例变量 ---
static void PrintAllIvars(id object, NSString *objectName) {
    if (!object) {
        EchoLog(@"对象 '%@' 为 nil，无法打印。", objectName);
        return;
    }
    
    unsigned int ivarCount;
    // class_copyIvarList 只能获取本类的ivar，所以我们需要遍历父类
    NSMutableString *ivarLog = [NSMutableString stringWithFormat:@"\n--- %@ (%@) 的实例变量 (Ivars) ---\n", objectName, NSStringFromClass([object class])];
    
    Class currentClass = [object class];
    while (currentClass && currentClass != [NSObject class]) {
        [ivarLog appendFormat:@"\n  --- 属于类: %@ ---\n", NSStringFromClass(currentClass)];
        ivars = class_copyIvarList(currentClass, &ivarCount);
        if (ivarCount == 0) {
            [ivarLog appendString:@"  (无自定义ivar)\n"];
        }
        for (unsigned int i = 0; i < ivarCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            const char *type = ivar_getTypeEncoding(ivar);
            [ivarLog appendFormat:@"  ? %s (%s)\n", name, type];
        }
        free(ivars);
        currentClass = class_getSuperclass(currentClass);
    }
    
    EchoLog(@"%@", ivarLog);
}

// --- 核心Hook ---
// 根据您之前的截图，弹出的详情窗口是 '六壬大占.課傳摘要視圖'，它是一个UIView。
// 管理它的ViewController很可能就是 '六壬大占.課傳摘要視圖控制器'。
// 我们先大胆地hook这个推测出来的名字。
// 如果日志没有输出，我们就需要换成hook '六壬大占.課傳摘要視圖' 的 - (id)initWith... 方法。
%hook 六壬大占.課傳摘要視圖控制器

- (void)viewDidLoad {
    // 先调用原始方法，确保所有东西都已加载
    %orig;

    EchoLog(@"--- 成功Hook到'課傳摘要視圖控制器'的 viewDidLoad ---");

    // 1. 打印弹窗VC自己的所有Ivars
    PrintAllIvars(self, @"弹窗自己 (self)");

    // 2. 打印创建它的那个VC (主VC) 的所有Ivars
    UIViewController *presentingVC = self.presentingViewController;
    PrintAllIvars(presentingVC, @"主VC (presentingViewController)");
}

%end

// 我们也hook一下天将的弹窗控制器，以防万一
%hook 六壬大占.天將摘要視圖控制器

- (void)viewDidLoad {
    %orig;
    EchoLog(@"--- 成功Hook到'天將摘要視圖控制器'的 viewDidLoad ---");
    PrintAllIvars(self, @"天将弹窗自己 (self)");
    PrintAllIvars(self.presentingViewController, @"主VC (presentingViewController)");
}

%end
