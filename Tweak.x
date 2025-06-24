#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ... 全局变量和辅助函数，带屏幕日志 ...
#define EchoLog(format, ...) do { /* ... */ } while(0)
// ...

%hook UIViewController

// ... viewDidLoad 创建按钮和日志 ...

%new
- (void)performKeChuanDetailExtractionTest_Truth {
    g_screenLogger.text = @"";
    EchoLog(@"开始V14 Ivar读取测试...");
    
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    if (!sanChuanContainerClass) {
        EchoLog(@"错误: 找不到'三傳視圖'类!");
        return;
    }
    
    NSMutableArray *containers = [NSMutableArray array];
    FindSubviewsOfClassRecursive(sanChuanContainerClass, self.view, containers);
    
    if (containers.count == 0) {
        EchoLog(@"错误: 未找到'三傳視圖'的实例!");
        return;
    }
    
    UIView *sanChuanContainer = containers.firstObject;
    EchoLog(@"找到三传容器: <%@: %p>", [sanChuanContainer class], sanChuanContainer);
    
    const char *ivarNames[] = {"初传", "中传", "末传", NULL};
    
    for (int i = 0; ivarNames[i] != NULL; ++i) {
        const char *ivarName = ivarNames[i];
        Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarName);
        
        if (ivar) {
            // 直接读取ivar的值
            id ivarValue = object_getIvar(sanChuanContainer, ivar);
            EchoLog(@"找到Ivar '%s'. 值: <%@: %p>", ivarName, [ivarValue class], ivarValue);
            
            // 如果能读到值，我们可以尝试用FLEX去分析这个ivarValue对象
            if (ivarValue) {
                // 在这里，我们可以尝试分析ivarValue是什么
                // 比如，看它是否响应某些我们已知的方法
                if ([ivarValue respondsToSelector:@selector(description)]) {
                    EchoLog(@"  - Description: %@", [ivarValue description]);
                }
            }
        } else {
            EchoLog(@"警告: 未找到Ivar '%s'!", ivarName);
        }
    }
}

// ... 其他方法暂时不需要 ...
%end
