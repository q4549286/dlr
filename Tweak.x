#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 数据区域模型 (不需要动) ---
@interface InfoRegion : NSObject
@property (nonatomic, strong) NSString *key;
@property (nonatomic, assign) CGRect region;
@property (nonatomic, strong) NSString *value;
+ (instancetype)regionWithKey:(NSString *)key rect:(CGRect)rect;
@end

@implementation InfoRegion
+ (instancetype)regionWithKey:(NSString *)key rect:(CGRect)rect {
    InfoRegion *info = [[InfoRegion alloc] init];
    info.key = key;
    info.region = rect;
    return info;
}
@end


// --- 关键修复：为目标类提供一个接口声明 ---
// --- 在这里替换成你确认后的真实类名 ---
@interface KechuanShiTu : UIView
// 在这里可以声明你发现的其他属性或方法，但对于当前目的，
// 只需要声明它继承自UIView就足够了。
@end


// --- Hook逻辑 ---
// --- 同样，在这里替换成真实类名 ---
%hook KechuanShiTu 

- (void)layoutSubviews {
    %orig;

    if (objc_getAssociatedObject(self, "hasExported")) { return; }

    NSLog(@"[导出插件] Hooked KechuanShiTu -layoutSubviews, 开始提取...");

    // --- !!! 核心工作：测量并填充这里的坐标 !!! ---
    NSArray<InfoRegion *> *regionsToExtract = @[
        [InfoRegion regionWithKey:@"chart_name" rect:CGRectMake(150, 20, 100, 40)],
        // ... 其他所有区域 ...
    ];
    
    // --- 遍历子视图的逻辑 (现在可以正常编译了) ---
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            CGPoint labelCenter = CGPointMake(CGRectGetMidX(label.frame), CGRectGetMidY(label.frame));
            
            for (InfoRegion *region in regionsToExtract) {
                if (CGRectContainsPoint(region.region, labelCenter)) {
                    region.value = label.text;
                    break; 
                }
            }
        }
    }
    
    // --- 组装并导出JSON的逻辑 (同前) ---
    NSMutableDictionary *jsonData = [NSMutableDictionary dictionary];
    for (InfoRegion *region in regionsToExtract) {
        if (region.value) {
            jsonData[region.key] = region.value;
        }
    }

    if (jsonData.count > 0) {
        NSLog(@"[导出插件] 最终聚合的数据: %@", jsonData);
        
        // 导出到文件
        NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
        NSString *filePath = [documentsPath stringByAppendingPathComponent:@"chart_export.json"];
        
        NSError *error = nil;
        NSData *jsonNSData = [NSJSONSerialization dataWithJSONObject:jsonData options:NSJSONWritingPrettyPrinted error:&error];
        if (jsonNSData) {
            [jsonNSData writeToFile:filePath atomically:YES];
            NSLog(@"[导出插件] JSON已保存至: %@", filePath);
        }

        objc_setAssociatedObject(self, "hasExported", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end
