#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 辅助函数
static void LogMessage(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[ObserverV8] %@", message);
}

%hook UIViewController

// 这个方法会在任何 UICollectionViewCell 被点击时触发
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // 首先，判断是不是我们关心的那个 ViewController 和 CollectionView
    Class targetVCClass = NSClassFromString(@"六壬大占.ViewController");
    Class targetCVClass = NSClassFromString(@"六壬大占.課體視圖");

    if ([self isKindOfClass:targetVCClass] && [collectionView isKindOfClass:targetCVClass]) {
        LogMessage(@"\n\n==================================================");
        LogMessage(@"=========== 观察到【课体】点击事件！ ===========");
        LogMessage(@"==================================================");
        LogMessage(@"ViewController: %@", self);
        LogMessage(@"CollectionView: %@", collectionView);
        LogMessage(@"被点击的路径: %@", indexPath);
        
        LogMessage(@"\n--- 正在检查 ViewController 的所有实例变量 (Ivars) ---");
        unsigned int ivarCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &ivarCount);
        if (ivars) {
            for(unsigned int i = 0; i < ivarCount; i++) {
                Ivar ivar = ivars[i];
                const char *name = ivar_getName(ivar);
                const char *type = ivar_getTypeEncoding(ivar);
                
                // 尝试获取 Ivar 的值
                id value = nil;
                @try {
                    // 只对对象类型尝试获取值，防止基本类型导致崩溃
                    if (type[0] == '@') {
                        value = object_getIvar(self, ivar);
                    } else {
                        value = @"<非对象类型，不读取>";
                    }
                } @catch (NSException *exception) {
                    value = @"<读取失败>";
                }
                
                LogMessage(@"IVAR: %s (类型: %s) -- 值: %@", name, type, value);
            }
            free(ivars);
        }
        LogMessage(@"--- Ivar 列表检查完毕 ---\n");
        LogMessage(@"--- 现在将控制权交还给原始App... ---");
    }

    // 调用原始实现，让App正常工作
    %orig;
}

%end
