#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// --- 定义一个简单的数据结构来管理我们要提取的区域 ---
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


// --- 在这里替换成你确认后的真实类名 ---
%hook KechuanShiTu 

- (void)layoutSubviews {
    // 必须先调用原始实现，这样所有的UILabel才会被正确布局
    %orig;

    // --- 在这个点，所有UILabel的frame和text都应该是最终确定的了 ---
    
    // 防止重复导出
    if (objc_getAssociatedObject(self, "hasExported")) { return; }

    NSLog(@"[导出插件] Hooked KechuanShiTu -layoutSubviews, 开始提取...");

    // --- 这是核心：定义所有你需要提取文字的区域 ---
    // !!! 你需要用FLEX或其他工具，仔细查看排盘界面，把每个文字的坐标和大小测量出来，填在这里
    // !!! 这是唯一需要你手动完成的“体力活”
    // 示例坐标 (你需要替换成真实的测量值):
    NSArray<InfoRegion *> *regionsToExtract = @[
        // 课体名称
        [InfoRegion regionWithKey:@"chart_name" rect:CGRectMake(150, 20, 100, 40)], // "伏吟门"

        // 四课 - 关系
        [InfoRegion regionWithKey:@"sike_1_relation" rect:CGRectMake(100, 100, 20, 20)], // "兄"
        [InfoRegion regionWithKey:@"sike_2_relation" rect:CGRectMake(100, 130, 20, 20)], // "财"
        [InfoRegion regionWithKey:@"sike_3_relation" rect:CGRectMake(100, 160, 20, 20)], // "官"
        
        // 四课 - 天盘地支
        [InfoRegion regionWithKey:@"sike_1_ganzhi" rect:CGRectMake(180, 95, 40, 30)], // "申"
        [InfoRegion regionWithKey:@"sike_2_ganzhi" rect:CGRectMake(180, 125, 40, 30)], // "寅"
        [InfoRegion regionWithKey:@"sike_3_ganzhi" rect:CGRectMake(180, 155, 40, 30)], // "巳"
        
        // 四课 - 天将
        [InfoRegion regionWithKey:@"sike_1_general" rect:CGRectMake(250, 100, 50, 20)], // "白虎"
        [InfoRegion regionWithKey:@"sike_2_general" rect:CGRectMake(250, 130, 50, 20)], // "螣蛇"
        [InfoRegion regionWithKey:@"sike_3_general" rect:CGRectMake(250, 160, 50, 20)], // "勾陈"
        
        // ... 在此添加所有其他你需要的信息，比如三传、神煞等
    ];
    
    // --- 遍历所有UILabel，看它们落入哪个区域 ---
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"UILabel")]) {
            UILabel *label = (UILabel *)subview;
            
            // 注意：这里的label.frame是相对于其父视图(即`课传视图`)的坐标
            // 这正是我们需要的
            CGPoint labelCenter = CGPointMake(CGRectGetMidX(label.frame), CGRectGetMidY(label.frame));
            
            for (InfoRegion *region in regionsToExtract) {
                if (CGRectContainsPoint(region.region, labelCenter)) {
                    region.value = label.text;
                    //NSLog(@"[导出插件] 找到值: %@ -> %@", region.key, region.value);
                    break; // 假设一个Label只属于一个区域
                }
            }
        }
    }
    
    // --- 组装并导出JSON ---
    NSMutableDictionary *jsonData = [NSMutableDictionary dictionary];
    for (InfoRegion *region in regionsToExtract) {
        if (region.value) {
            jsonData[region.key] = region.value;
        } else {
            // 可选：记录哪些区域没有找到值，方便调试
            //NSLog(@"[导出插件] 警告: 未在区域 %@ 中找到任何文本", region.key);
        }
    }

    // 检查是否提取到了任何数据
    if (jsonData.count > 0) {
        // ... 导出JSON到文件或打印的逻辑 (同上一个回答) ...
        NSLog(@"[导出插件] 最终聚合的数据: %@", jsonData);
        
        // 标记已导出
        objc_setAssociatedObject(self, "hasExported", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end
