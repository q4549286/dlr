#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 1. 获取目标类。注意，类名可能需要处理一下，去掉模块名
//    "六壬大占.课传视图" 在运行时可能表示为 "LiurenDazhan.KechuanShiTu" 或其他形式
//    你可以用 NSClassFromString(@"六壬大占.课传视图") 来尝试获取
const char *className = "六壬大占.课传视图"; // 这个需要验证
Class targetClass = objc_getClass(className);

// 2. 在 +load 方法里进行 Method Swizzling
+ (void)load {
    if (targetClass) {
        // 交换 layoutSubviews 方法
        // ... (交换代码同前) ...
    }
}

// 3. 我们的Hook实现
- (void)my_layoutSubviews {
    // 先调用原始实现
    [self my_layoutSubviews];

    // --- 在这里，self 就是 `六壬大占.课传视图` 的实例 ---
    
    // 4. 直接通过KVC (Key-Value Coding) 访问实例变量
    //    KVC可以无视变量是否私有，直接获取。变量名就是你在FLEX里看到的。
    //    注意：FLEX里看到的可能是中文，实际代码里的变量名可能是拼音或英文。
    //    你需要尝试一下，或者用Hopper确认真正的变量名。我们先假设就是中文。
    
    id sikeData = [self valueForKey:@"四课"];
    id sanchuanData = [self valueForKey:@"三传"];
    id ketiData = [self valueForKey:@"课体"];
    id jiuzongmenData = [self valueForKey:@"九宗门"];
    
    // 5. 检查数据并处理
    if (sikeData && sanchuanData) {
        NSLog(@"[导出插件] 成功获取到数据模型!");
        NSLog(@"四课数据: %@", sikeData);
        NSLog(@"三传数据: %@", sanchuanData);
        NSLog(@"课体数据: %@", ketiData);
        
        // sikeData 和 sanchuanData 很可能已经是 NSArray 或 NSDictionary 了
        // 你需要打印出来看看它们的具体结构，然后就可以轻松组装成你的目标JSON了。
        
        // 示例：假设sikeData是个字典数组
        NSDictionary *exportData = @{
            @"si_ke": sikeData,
            @"san_chuan": sanchuanData,
            @"ke_ti": ketiData
            // ...
        };

        // ... 导出JSON ...
        
        // 为了防止重复导出，可以加个标记
        // 比如给这个view关联一个对象，表示已经导出过了
        if (!objc_getAssociatedObject(self, "hasExported")) {
            // ... 执行导出 ...
            objc_setAssociatedObject(self, "hasExported", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}
