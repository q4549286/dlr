#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =======================================================================================
//
//  Echo 大六壬推衍核心 v29.1 (完整无省略版)
//
//  - [融合] 已将“天地盘详情推衍”功能集成至“深度课盘”流程。
//  - [重构] 实现了数据提取与数据解析的完全分离，引入统一解析器，便于维护。
//  - [激活] 已激活并格式化“七政四余”与“三宫时信息”的提取与输出。
//  - [统一] 所有模块均使用统一的日志与状态管理系统。
//  - [修复] 修复了部分拷贝/粘贴可能遗漏的函数实现。
//
// =======================================================================================


// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================

#pragma mark - Constants, Colors & Tags
// View Tags
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 778899;
static const NSInteger kEchoProgressHUDTag      = 556677;
static const NSInteger kEchoInteractionBlockerTag = 224466;

// Button Tags
static const NSInteger kButtonTag_StandardReport    = 101;
static const NSInteger kButtonTag_DeepDiveReport    = 102;
static const NSInteger kButtonTag_KeTi              = 201;
static const NSInteger kButtonTag_JiuZongMen        = 203;
static const NSInteger kButtonTag_ShenSha           = 204;
static const NSInteger kButtonTag_KeChuan           = 301;
static const NSInteger kButtonTag_NianMing          = 302;
static const NSInteger kButtonTag_BiFa              = 303;
static const NSInteger kButtonTag_GeJu              = 304;
static const NSInteger kButtonTag_FangFa            = 305;
static const NSInteger kButtonTag_ClearInput        = 999;
static const NSInteger kButtonTag_ClosePanel        = 998;
static const NSInteger kButtonTag_SendLastReportToAI = 997;
static const NSInteger kButtonTag_AIPromptToggle    = 996;
static const NSInteger kButtonTag_BenMingToggle     = 995;

// Colors
#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0]
#define ECHO_COLOR_MAIN_TEAL        [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0]
#define ECHO_COLOR_AUX_GREY         [UIColor colorWithWhite:0.3 alpha:1.0]
#define ECHO_COLOR_SWITCH_OFF       [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE     [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_AI        [UIColor colorWithRed:0.22 green:0.59 blue:0.85 alpha:1.0]
#define ECHO_COLOR_SUCCESS          [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_PROMPT_ON        [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0]
#define ECHO_COLOR_LOG_TASK         [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO         [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN         [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR        [UIColor redColor]
#define ECHO_COLOR_BACKGROUND_DARK  [UIColor colorWithWhite:0.15 alpha:1.0]
#define ECHO_COLOR_CARD_BG          [UIColor colorWithWhite:0.2 alpha:1.0]

#pragma mark - Global State & Flags
static UIView *g_mainControlPanelView = nil;
static UITextView *g_logTextView = nil;
static __weak UIViewController *g_mainViewController = nil; // 核心修改: 增加对主VC的弱引用

// --- 任务状态标志 ---
static BOOL g_s1_isExtracting = NO;
static BOOL g_s2_isExtractingKeChuanDetail = NO;
static BOOL g_isExtractingNianming = NO;
static BOOL g_isExtractingTimeInfo = NO;
static BOOL g_isExtractingBiFa = NO;
static BOOL g_isExtractingGeJu = NO;
static BOOL g_isExtractingFangFa = NO;
static BOOL g_isExtractingQiZheng = NO;
static BOOL g_isExtractingSanGong = NO;
static BOOL g_isExtractingTianDiPanDetail = NO; // 核心修改: 从脚本1移入

// --- 任务数据存储 ---
static NSMutableDictionary *g_extractedData = nil;
static NSString *g_lastGeneratedReport = nil;
static UITextView *g_questionTextView = nil;
static UIButton *g_clearInputButton = nil;
static void (^g_biFa_completion)(NSString *) = nil;
static void (^g_geJu_completion)(NSString *) = nil;
static void (^g_fangFa_completion)(NSString *) = nil;
static void (^g_qiZheng_completion)(NSString *) = nil;
static void (^g_sanGong_completion)(NSString *) = nil;

// --- S1: 课体/九宗门 ---
static NSString *g_s1_currentTaskType = nil;
static BOOL g_s1_shouldIncludeXiangJie = NO;
static NSMutableArray *g_s1_keTi_workQueue = nil;
static NSMutableArray *g_s1_keTi_resultsArray = nil;
static UICollectionView *g_s1_keTi_targetCV = nil;
static void (^g_s1_completion_handler)(NSString *result) = nil;

// --- S2: 课传流注 ---
static NSMutableArray *g_s2_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_s2_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_s2_keChuanTitleQueue = nil;
static NSString *g_s2_finalResultFromKeChuan = nil;
static void (^g_s2_keChuan_completion_handler)(void) = nil;

// --- 年命/格局 ---
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;

// --- 天地盘详情 (从脚本1移入) ---
static NSMutableArray *g_tianDiPan_workQueue = nil;
static NSMutableArray<NSString *> *g_tianDiPan_resultsArray = nil;
static void (^g_tianDiPan_completion_handler)(NSString *result) = nil;


// --- UI & 配置状态 ---
static BOOL g_shouldIncludeAIPromptHeader = YES;
static BOOL g_shouldExtractBenMing = NO;
#pragma mark - Macros & Enums
#define SafeString(str) (str ?: @"")
#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

// 核心修改: 为统一解析器定义数据类型枚举
typedef NS_ENUM(NSInteger, EchoDataType) {
    EchoDataTypeGeneric,
    EchoDataTypeNianming,
    EchoDataTypeFangFa,
    EchoDataTypeShenSha,
    EchoDataTypeKeChuanDetail,
    EchoDataTypeBiFa,
    EchoDataTypeGeJu,
    EchoDataTypeQiZheng,
    EchoDataTypeSanGong,
    EchoDataTypeJiuZongMen,
    EchoDataTypeTianDiPanDetail // 新增
};

#pragma mark - Fake Gesture Recognizer (from Script 1)
// 核心修改: 移入模拟点击手势类
@interface EchoFakeGestureRecognizer : UITapGestureRecognizer
@property (nonatomic, assign) CGPoint fakeLocation;
@end

@implementation EchoFakeGestureRecognizer
- (CGPoint)locationInView:(UIView *)view {
    return self.fakeLocation;
}
@end

#pragma mark - Coordinate Database (from Script 1)
// 核心修改: 移入天地盘坐标数据库
static NSArray *g_tianDiPan_fixedCoordinates = nil;
static void initializeTianDiPanCoordinates() {
    if (g_tianDiPan_fixedCoordinates) return;
    CGFloat centerX = 180.0, centerY = 180.0;
    CGFloat tianJiangRadius = 70.0, shangShenRadius = 115.0;
    g_tianDiPan_fixedCoordinates = @[
        @{@"name": @"天将-午位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX, centerY - tianJiangRadius)]},
        @{@"name": @"天将-巳位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - tianJiangRadius * 0.5, centerY - tianJiangRadius * 0.866)]},
        @{@"name": @"天将-辰位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - tianJiangRadius * 0.866, centerY - tianJiangRadius * 0.5)]},
        @{@"name": @"天将-卯位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - tianJiangRadius, centerY)]},
        @{@"name": @"天将-寅位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - tianJiangRadius * 0.866, centerY + tianJiangRadius * 0.5)]},
        @{@"name": @"天将-丑位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - tianJiangRadius * 0.5, centerY + tianJiangRadius * 0.866)]},
        @{@"name": @"天将-子位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX, centerY + tianJiangRadius)]},
        @{@"name": @"天将-亥位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + tianJiangRadius * 0.5, centerY + tianJiangRadius * 0.866)]},
        @{@"name": @"天将-戌位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + tianJiangRadius * 0.866, centerY + tianJiangRadius * 0.5)]},
        @{@"name": @"天将-酉位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + tianJiangRadius, centerY)]},
        @{@"name": @"天将-申位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + tianJiangRadius * 0.866, centerY - tianJiangRadius * 0.5)]},
        @{@"name": @"天将-未位", @"type": @"tianJiang", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + tianJiangRadius * 0.5, centerY - tianJiangRadius * 0.866)]},
        @{@"name": @"上神-午位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX, centerY - shangShenRadius)]},
        @{@"name": @"上神-巳位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - shangShenRadius * 0.5, centerY - shangShenRadius * 0.866)]},
        @{@"name": @"上神-辰位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - shangShenRadius * 0.866, centerY - shangShenRadius * 0.5)]},
        @{@"name": @"上神-卯位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - shangShenRadius, centerY)]},
        @{@"name": @"上神-寅位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - shangShenRadius * 0.866, centerY + shangShenRadius * 0.5)]},
        @{@"name": @"上神-丑位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX - shangShenRadius * 0.5, centerY + shangShenRadius * 0.866)]},
        @{@"name": @"上神-子位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX, centerY + shangShenRadius)]},
        @{@"name": @"上神-亥位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + shangShenRadius * 0.5, centerY + shangShenRadius * 0.866)]},
        @{@"name": @"上神-戌位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + shangShenRadius * 0.866, centerY + shangShenRadius * 0.5)]},
        @{@"name": @"上神-酉位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + shangShenRadius, centerY)]},
        @{@"name": @"上神-申位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + shangShenRadius * 0.866, centerY - shangShenRadius * 0.5)]},
        @{@"name": @"上神-未位", @"type": @"shangShen", @"point": [NSValue valueWithCGPoint:CGPointMake(centerX + shangShenRadius * 0.5, centerY - shangShenRadius * 0.866)]},
    ];
}

#pragma mark - Helper Functions
typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeTask, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };
static void LogMessage(EchoLogType type, NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args; va_start(args, format); NSString *message = [[NSString alloc] initWithFormat:format arguments:args]; va_end(args);
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init]; [formatter setDateFormat:@"HH:mm:ss"];
        NSString *logPrefix = [NSString stringWithFormat:@"[%@] ", [formatter stringFromDate:[NSDate date]]];
        NSMutableAttributedString *logLine = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@%@\n", logPrefix, message]];
        UIColor *color;
        switch (type) {
            case EchoLogTypeTask:       color = ECHO_COLOR_LOG_TASK; break;
            case EchoLogTypeSuccess:    color = ECHO_COLOR_SUCCESS; break;
            case EchoLogTypeWarning:    color = ECHO_COLOR_LOG_WARN; break;
            case EchoLogError:          color = ECHO_COLOR_LOG_ERROR; break;
            case EchoLogTypeInfo:
            default:                    color = ECHO_COLOR_LOG_INFO; break;
        }
        [logLine addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, logLine.length)];
        [logLine addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, logLine.length)];
        NSMutableAttributedString *existingText = [[NSMutableAttributedString alloc] initWithAttributedString:g_logTextView.attributedText];
        [logLine appendAttributedString:existingText]; g_logTextView.attributedText = logLine;
        NSLog(@"[Echo推衍课盘] %@", message);
    });
}
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if (!view || !storage) return; if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static UIWindow* GetFrontmostWindow() { UIWindow *frontmostWindow = nil; if (@available(iOS 13.0, *)) { for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) { if (scene.activationState == UISceneActivationStateForegroundActive) { for (UIWindow *window in scene.windows) { if (window.isKeyWindow) { frontmostWindow = window; break; } } if (frontmostWindow) break; } } } if (!frontmostWindow) { \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
    frontmostWindow = [UIApplication sharedApplication].keyWindow; \
    _Pragma("clang diagnostic pop") \
    } return frontmostWindow; }
static NSString* extractValueAfterKeyword(NSString *line, NSString *keyword) { NSRange keywordRange = [line rangeOfString:keyword]; if (keywordRange.location == NSNotFound) return nil; NSString *value = [line substringFromIndex:keywordRange.location + keywordRange.length]; return [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

static NSString* extractDataFromStackViewPopup(UIView *contentView) {
    NSMutableArray<NSString *> *finalTextParts = [NSMutableArray array];
    NSMutableArray *allStackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], contentView, allStackViews);
    if (allStackViews.count > 0) {
        UIStackView *mainStackView = allStackViews.firstObject;
        for (UIView *subview in mainStackView.arrangedSubviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                NSString *text = ((UILabel *)subview).text; if (text && text.length > 0) [finalTextParts addObject:text];
            } else if ([subview isKindOfClass:NSClassFromString(@"六壬大占.IntrinsicTableView")]) {
                UITableView *tableView = (UITableView *)subview; id<UITableViewDataSource> dataSource = tableView.dataSource;
                if (dataSource) {
                    NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:0];
                    for (NSInteger row = 0; row < rows; row++) {
                        UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
                        if(cell) {
                            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                            NSMutableArray<NSString *> *cellTexts = [NSMutableArray array]; for(UILabel *l in labels) { if(l.text.length > 0) [cellTexts addObject:l.text]; }
                            if(cellTexts.count > 0) [finalTextParts addObject:[cellTexts componentsJoinedByString:@" "]];
                        }
                    }
                }
            }
        }
    } else { return @"[提取失败: 未找到StackView]"; }
    return [finalTextParts componentsJoinedByString:@"\n"];
}
static NSString* extractFromComplexTableViewPopup(UIView *contentView) {
    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
    if (!tableViewClass) { return @"错误: 找不到 IntrinsicTableView 类"; }
    NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
    if (tableViews.count > 0) {
        UITableView *tableView = tableViews.firstObject; id<UITableViewDataSource> dataSource = tableView.dataSource;
        if (!dataSource) { return @"错误: TableView 没有 dataSource"; }
        NSMutableArray<NSString *> *allEntries = [NSMutableArray array];
        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;
        for (NSInteger section = 0; section < sections; section++) {
            NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
             for (NSInteger row = 0; row < rows; row++) {
                UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                if (cell) {
                    NSMutableArray<UILabel *> *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                    if (labelsInCell.count > 1) {
                        [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                        NSString *title = [[labelsInCell[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@" " withString:@""];
                        NSMutableString *contentText = [NSMutableString string];
                        for(NSUInteger i = 1; i < labelsInCell.count; i++) { if (labelsInCell[i].text.length > 0) { [contentText appendString:labelsInCell[i].text]; } }
                        NSString *content = [[contentText stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [allEntries addObject:[NSString stringWithFormat:@"%@→%@", title, content]];
                    } else if (labelsInCell.count == 1) { [allEntries addObject:[labelsInCell[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; }
                }
            }
        }
        return [allEntries componentsJoinedByString:@"\n"];
    }
    return @"错误: 未在弹窗中找到 TableView";
}
static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie) {
    if (!rootView) return @"[错误: 根视图为空]";
    NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews);
    if (stackViews.count == 0) { return @"[错误: 未在课体范式弹窗中找到 UIStackView]"; }
    UIStackView *mainStackView = stackViews.firstObject; NSMutableString *finalResult = [NSMutableString string];
    for (UIView *subview in mainStackView.arrangedSubviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview; NSString *text = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!text || text.length == 0 || [text isEqualToString:@"详解"]) continue;
            [finalResult appendFormat:@"%@\n", text];
        }
    }
    NSString *cleanedResult = [finalResult stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    while ([cleanedResult containsString:@"\n\n\n"]) { cleanedResult = [cleanedResult stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"]; }
    return [cleanedResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}


// =========================================================================
// 2. 统一数据解析器 (重构核心)
// =========================================================================
#pragma mark - Unified Data Parser
static NSString* _parseTianJiangDetailInternal(NSString *rawContent);
static NSString* _parseShangShenDetailInternal(NSString *rawContent);
static NSString* parseRawData(NSString *rawData, EchoDataType type);
static NSString* parseKeChuanDetailBlock(NSString *rawText, NSString *objectTitle);

static NSString* parseNianmingBlock(NSString *rawParamBlock) {
    if (!rawParamBlock || rawParamBlock.length == 0) return @"";
    NSMutableString *structuredResult = [NSMutableString string];
    NSString *summaryText = @"";
    NSRange summaryRange = [rawParamBlock rangeOfString:@"摘要:"];
    if (summaryRange.location != NSNotFound) {
        NSString *temp = [rawParamBlock substringFromIndex:summaryRange.location + summaryRange.length];
        NSRange gejuRange = [temp rangeOfString:@"格局:"];
        if (gejuRange.location != NSNotFound) { summaryText = [temp substringToIndex:gejuRange.location]; }
        else { summaryText = temp; }
    }
    summaryText = [summaryText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *benMingSeparator = @"本命在";
    NSRange benMingRange = [summaryText rangeOfString:benMingSeparator];
    NSString *xingNianPart = summaryText;
    NSString *benMingPart = @"";
    if (benMingRange.location != NSNotFound) {
        xingNianPart = [summaryText substringToIndex:benMingRange.location];
        benMingPart = [summaryText substringFromIndex:benMingRange.location];
    }
    void (^parseDetailPart)(NSString*, NSString*) = ^(NSString *title, NSString *partText) {
        partText = [partText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (partText.length == 0) return;
        [structuredResult appendFormat:@"\n  // %@\n", title];
        NSRegularExpression *coreInfoRegex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)(行年|本命)在(.{2,})，其临(.{1,2})乘(.{1,2})将乘(.*?):" options:0 error:nil];
        NSTextCheckingResult *coreInfoMatch = [coreInfoRegex firstMatchInString:partText options:0 range:NSMakeRange(0, partText.length)];
        if (coreInfoMatch) {
            NSString *subjectDesc  = [[partText substringWithRange:[coreInfoMatch rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *subjectDiZhi = [[partText substringWithRange:[coreInfoMatch rangeAtIndex:3]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *linGong      = [[partText substringWithRange:[coreInfoMatch rangeAtIndex:4]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *cheng        = [[partText substringWithRange:[coreInfoMatch rangeAtIndex:5]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *tianJiang    = [[partText substringWithRange:[coreInfoMatch rangeAtIndex:6]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([title isEqualToString:@"行年信息"]) { [structuredResult appendFormat:@"  - 行年: %@ (%@ 行年)\n", subjectDesc, subjectDiZhi]; }
            else { [structuredResult appendFormat:@"  - 本命: %@ (%@ 本命)\n", subjectDesc, subjectDiZhi]; }
            [structuredResult appendFormat:@"  - 临宫: %@\n", linGong];
            [structuredResult appendFormat:@"  - 乘: %@\n", cheng];
            [structuredResult appendFormat:@"  - 将: %@\n", tianJiang];
        }
        NSRegularExpression *changshengRegex = [NSRegularExpression regularExpressionWithPattern:@"临.宫为(.+之地)" options:0 error:nil];
        NSTextCheckingResult *changshengMatch = [changshengRegex firstMatchInString:partText options:0 range:NSMakeRange(0, partText.length)];
        if (changshengMatch) { [structuredResult appendFormat:@"  - 长生: %@\n", [partText substringWithRange:[changshengMatch rangeAtIndex:1]]]; }
        NSRange fayongRange = [partText rangeOfString:@"与发用之关系:"];
        if (fayongRange.location != NSNotFound) {
            NSString *fayongText = [partText substringFromIndex:fayongRange.location + fayongRange.length];
            NSRange shenshaRangeInFayong = [fayongText rangeOfString:@"所值神煞:"];
            if (shenshaRangeInFayong.location != NSNotFound) { fayongText = [fayongText substringToIndex:shenshaRangeInFayong.location]; }
            [structuredResult appendFormat:@"  - 发用关系: %@\n", [fayongText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        }
        NSRange shenshaRange = [partText rangeOfString:@"所值神煞:"];
        if (shenshaRange.location != NSNotFound) {
            NSString *shenshaText = [[partText substringFromIndex:shenshaRange.location + shenshaRange.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (shenshaText.length > 0) {
                NSMutableSet *uniqueShenshas = [NSMutableSet set];
                NSArray *shenshaEntries = [shenshaText componentsSeparatedByString:@"值"];
                for (NSString *entry in shenshaEntries) {
                    NSString *trimmedEntry = [entry stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (trimmedEntry.length == 0 || ([trimmedEntry containsString:@"上乘"] && [trimmedEntry containsString:@"正"]) || [trimmedEntry componentsSeparatedByString:@"，"].count > 2) continue;
                    NSRange punctuationRange = [trimmedEntry rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"，。"]];
                    NSString *shenshaName = (punctuationRange.location != NSNotFound) ? [trimmedEntry substringToIndex:punctuationRange.location] : trimmedEntry;
                    shenshaName = [shenshaName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (shenshaName.length > 0) { [uniqueShenshas addObject:shenshaName]; }
                }
                if (uniqueShenshas.count > 0) {
                    [structuredResult appendString:@"  - 所值神煞:\n"];
                    for (NSString *finalSs in uniqueShenshas) { [structuredResult appendFormat:@"    - 值%@\n", finalSs]; }
                }
            }
        }
    };
    parseDetailPart(@"行年信息", xingNianPart);
    if (g_shouldExtractBenMing) { parseDetailPart(@"本命信息", benMingPart); }
    return [structuredResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 解析方法过滤器 (v6.4 - 对“来占之情”和“克应之期”均放开过滤)
static NSString* parseAndFilterFangFaBlock(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";

    // [预处理]
    NSString *preprocessedContent = [rawContent stringByReplacingOccurrencesOfString:@"→" withString:@"→\n"];
    NSMutableString *workingContent = [preprocessedContent mutableCopy];
    
    // [模块过滤器]
    NSArray<NSString *> *blockRemovalMarkers = @[@"发用事端→", @"三传事体→", @"日辰关系→", @"日辰上乘"];
    for (NSString *marker in blockRemovalMarkers) {
        NSRange markerRange = [workingContent rangeOfString:marker];
        if (markerRange.location != NSNotFound) {
            [workingContent deleteCharactersInRange:NSMakeRange(markerRange.location, workingContent.length - markerRange.location)];
        }
    }

    // [样板句黑名单]
    NSArray<NSString *> *boilerplateSentences = @[
        @"凡看来情，以占之正时，详其与日之生克刑合，则于所占事体，可先有所主，故曰先锋门。",
        @"此以用神所乘所临，以及与日之生合刑墓等断事发之机。",
        @"此以三传之进退顺逆、有气无气、顺生逆克等定事情之大体。",
        @"此以日辰对较而定主客彼我之关系，大体日为我，辰为彼；日为人，辰为宅；日为尊，辰为卑；日为老，辰为幼；日为夫，辰为妻；日为官，辰为民；出行则日为陆为车，辰则为水为舟；日为出，为南向，为前方，辰则为入，为北向，为后方；占病则以日为人，以辰为病；占产则以日为子，以辰为母；占农则以日为农夫，以辰为谷物；占猎则以日为猎师，以辰为鸟兽。故日辰之位，随占不同，总要依类而推之，方无差谬。",
        @"此以用神之旺相并天乙前后断事情之迟速，并以用神所合之岁月节候而定事体之远近，复以天上季神所临定成事之期。",
        @"以常法而论，吉事而凶事年月日时以事体之大小斟酌定之。"
    ];
    for (NSString *sentence in boilerplateSentences) {
        [workingContent replaceOccurrencesOfString:sentence withString:@"" options:0 range:NSMakeRange(0, workingContent.length)];
    }
    
    // [新逻辑：分离受保护的内容块]
    NSMutableString *protectedContent = [NSMutableString string];
    NSMutableString *contentToFilter = [workingContent mutableCopy];
    NSArray<NSString *> *protectedTitles = @[@"来占之情→", @"克应之期→"];

    for (NSString *title in protectedTitles) {
        NSRange titleRange = [contentToFilter rangeOfString:title];
        if (titleRange.location != NSNotFound) {
            NSString *remainingString = [contentToFilter substringFromIndex:titleRange.location];
            
            // 查找下一个标题作为块的结束
            NSRegularExpression *nextTitleRegex = [NSRegularExpression regularExpressionWithPattern:@"\n[\\u4e00-\\u9fa5]+→" options:0 error:nil];
            NSTextCheckingResult *nextTitleMatch = [nextTitleRegex firstMatchInString:remainingString options:0 range:NSMakeRange(1, remainingString.length - 1)];
            
            NSString *blockToProtect;
            if (nextTitleMatch) {
                blockToProtect = [remainingString substringToIndex:nextTitleMatch.range.location];
            } else {
                blockToProtect = remainingString; // 如果是最后一个块，则保护到结尾
            }
            
            // 将保护块添加到protectedContent，并从contentToFilter中移除
            [protectedContent appendString:blockToProtect];
            [contentToFilter replaceOccurrencesOfString:blockToProtect withString:@"" options:NSLiteralSearch range:NSMakeRange(0, contentToFilter.length)];
        }
    }

    // [断语过滤] 只对剩余内容应用过滤规则
    NSArray<NSString *> *conclusionPatterns = @[
        @"(主|恐|利|不利|则|此主|凡事|又当|故当|当以|大有生意|凶祸更甚|凶祸消磨|其势悖逆|用昼将|唯不利|岁无成|而不能由己|可致福禄重重|情多窒且塞|事虽顺而有耗散之患|生归日辰则无虞|理势自然).*?($|。|，)",
        @"(^|，|。)\\s*(主|恐|利|不利|则|此主|凡事|又当|故当|当以|不堪期|却无气|事虽新起)[^，。]*"
    ];
    for (NSString *pattern in conclusionPatterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSString *previous;
        do {
            previous = [contentToFilter copy];
            [regex replaceMatchesInString:contentToFilter options:0 range:NSMakeRange(0, contentToFilter.length) withTemplate:@""];
        } while (![previous isEqualToString:contentToFilter]);
    }

    // [合并与格式化] 将受保护的内容和过滤后的内容重新组合
    NSMutableString *finalContent = [NSMutableString string];
    [finalContent appendString:protectedContent];
    [finalContent appendString:contentToFilter];

    // [通用格式化]
    [finalContent replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, finalContent.length)];
    // 注意：这里的“又，”过滤可能会影响您期望保留的内容，我们将其移除或修改
    // [finalContent replaceOccurrencesOfString:@"又， " withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, finalContent.length)];
    while ([finalContent containsString:@"  "]) {
        [finalContent replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, finalContent.length)];
    }
    
    // [最终输出格式化]
    [finalContent replaceOccurrencesOfString:@"→" withString:@":\n" options:0 range:NSMakeRange(0, finalContent.length)];
    [finalContent replaceOccurrencesOfString:@"\\s*([，。])\\s*" withString:@"$1" options:NSRegularExpressionSearch range:NSMakeRange(0, finalContent.length)];
    [finalContent replaceOccurrencesOfString:@"[，。]{2,}" withString:@"。" options:NSRegularExpressionSearch range:NSMakeRange(0, finalContent.length)];
    if ([finalContent hasPrefix:@"，"] || [finalContent hasPrefix:@"。"]) {
        if(finalContent.length > 0) [finalContent deleteCharactersInRange:NSMakeRange(0, 1)];
    }

    NSArray<NSString *> *finalSentences = [[finalContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"。"];
    NSMutableString *finalResult = [NSMutableString string];
    for (NSString *sentence in finalSentences) {
        NSString *trimmedSentence = [sentence stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,，"]];
        if (trimmedSentence.length > 0) {
            [finalResult appendFormat:@"%@。\n", trimmedSentence];
        }
    }
    
    NSString *finalCleaned = [finalResult stringByReplacingOccurrencesOfString:@":\n" withString:@":\n  "];
    return [finalCleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* parseAndFilterShenSha(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSMutableDictionary<NSString *, NSString *> *parsedShenShaData = [NSMutableDictionary dictionary];
    NSString *cleanedContent = [[rawContent stringByReplacingOccurrencesOfString:@"\n" withString:@","] stringByReplacingOccurrencesOfString:@"|" withString:@","];
    NSArray<NSString *> *allItems = [cleanedContent componentsSeparatedByString:@","];
    for (NSString *item in allItems) {
        NSString *trimmedItem = [item stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (trimmedItem.length == 0 || [trimmedItem hasPrefix:@"//"]) continue;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(.*?)\\s*\\((.*?)\\)" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:trimmedItem options:0 range:NSMakeRange(0, trimmedItem.length)];
        NSString *name = @"", *branch = @"";
        if (match) { name = [trimmedItem substringWithRange:[match rangeAtIndex:1]]; branch = [trimmedItem substringWithRange:[match rangeAtIndex:2]]; }
        else { name = [trimmedItem stringByReplacingOccurrencesOfString:@":" withString:@""]; }
        name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length == 0) continue;
        NSString *keyName = name, *prefix = @"";
        if ([name hasPrefix:@"年"]) { keyName = [name substringFromIndex:1]; prefix = @"年"; }
        else if ([name hasPrefix:@"月"]) { keyName = [name substringFromIndex:1]; prefix = @"月"; }
        NSString *existingBranch = parsedShenShaData[keyName];
        NSString *newBranchValue = branch.length > 0 ? [NSString stringWithFormat:@"%@%@", prefix, branch] : @"";
        if (existingBranch) { if (newBranchValue.length > 0) { parsedShenShaData[keyName] = [NSString stringWithFormat:@"%@, %@", existingBranch, newBranchValue]; } }
        else { if (newBranchValue.length > 0) { parsedShenShaData[keyName] = newBranchValue; } else { parsedShenShaData[keyName] = @""; } }
    }
    NSArray<NSDictionary *> *categories = @[ @{ @"title": @"// 1. 通用核心神煞", @"subsections": @[ @{ @"subtitle": @"- **吉神类:**", @"shenshas": @[@"日德", @"月德", @"天喜", @"天赦", @"皇恩"] }, @{ @"subtitle": @"- **驿马类:**", @"shenshas": @[@"岁马", @"月马", @"日马", @"天马"] }, @{ @"subtitle": @"- **凶煞类:**", @"shenshas": @[@"羊刃", @"飞刃", @"亡神", @"劫煞", @"灾煞"] }, @{ @"subtitle": @"- **状态类:**", @"shenshas": @[@"旬空", @"岁破", @"月建", @"月破", @"太岁", @"岁禄", @"日禄", @"岁墓", @"支墓"] } ] }, @{ @"title": @"// 2. 专题功能神煞", @"subsections": @[ @{ @"subtitle": @"**//官运事业**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"岁禄", @"日禄", @"文星", @"天印", @"进神"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"官符", @"岁虎", @"退神", @"日破碎"] }, @{ @"subtitle": @"**//财运求索**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天财", @"长生", @"福星"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"大耗", @"小耗", @"天贼", @"盗神"] }, @{ @"subtitle": @"**//婚恋情感**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天喜", @"岁合", @"月合", @"日合", @"支合", @"生气"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"桃花", @"咸池", @"孤辰", @"寡宿", @"月厌", @"奸门", @"奸私", @"日淫"] }, @{ @"subtitle": @"**//健康疾病**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天医", @"地医", @"天解", @"地解", @"解神"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"病符", @"死符", @"死神", @"死气", @"丧门", @"吊客", @"血光", @"血支", @"披麻", @"孝服"] }, @{ @"subtitle": @"**//官非诉讼**", @"shenshas": @[] }, @{ @"subtitle": @"- **解厄信号:**", @"shenshas": @[@"日德", @"月德", @"岁德", @"天赦"] }, @{ @"subtitle": @"- **致讼信号:**", @"shenshas": @[@"官符", @"天刑", @"天狱", @"天网", @"岁虎"] }, @{ @"subtitle": @"**//阴私鬼神**", @"shenshas": @[] }, @{ @"subtitle": @"- **核心信号:**", @"shenshas": @[@"天鬼", @"月华盖", @"日华盖", @"天巫", @"地狱", @"五墓", @"哭神", @"伏骨"] } ] } ];
    NSMutableString *finalReport = [NSMutableString string];
    for (NSDictionary *category in categories) {
        [finalReport appendFormat:@"%@\n", category[@"title"]];
        for (NSDictionary *subsection in category[@"subsections"]) {
            NSArray *shenshaNames = subsection[@"shenshas"]; NSString *subtitle = subsection[@"subtitle"];
            if (shenshaNames.count == 0) { [finalReport appendFormat:@"%@\n", subtitle]; continue; }
            NSMutableArray *foundShenShasInLine = [NSMutableArray array];
            for (NSString *name in shenshaNames) {
                NSString *branch = parsedShenShaData[name];
                if (branch != nil) {
                    if (branch.length > 0) { [foundShenShasInLine addObject:[NSString stringWithFormat:@"%@(%@)", name, branch]]; }
                    else { [foundShenShasInLine addObject:name]; }
                }
            }
            if (foundShenShasInLine.count > 0) { [finalReport appendFormat:@"%@ %@\n", subtitle, [foundShenShasInLine componentsJoinedByString:@", "]]; }
        }
    }
    return [finalReport stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 课传流注详情解析器 (v2.8 - 解决问题3和4)
static NSString* parseKeChuanDetailBlock(NSString *rawText, NSString *objectTitle) {
    if (!rawText || rawText.length == 0) return @"";

    NSMutableString *structuredResult = [NSMutableString string];
    NSArray<NSString *> *lines = [rawText componentsSeparatedByString:@"\n"];
    NSMutableArray<NSString *> *processedLines = [NSMutableArray array];
    BOOL isTianJiangObject = (objectTitle && [objectTitle containsString:@"天将"]);

    // --- 阶段一：提取核心状态 (旺衰, 长生, 及特殊状态) ---
    // [这部分逻辑不变]
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0 || [processedLines containsObject:trimmedLine]) continue;
        if (objectTitle && [objectTitle containsString:@"日干"]) {
            NSRegularExpression *riGanWangshuaiRegex = [NSRegularExpression regularExpressionWithPattern:@"寄(.)得([^，。]*)" options:0 error:nil];
            NSTextCheckingResult *riGanMatch = [riGanWangshuaiRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
            if (riGanMatch && [structuredResult rangeOfString:@"日干旺衰:"].location == NSNotFound) {
                [structuredResult appendFormat:@"  - 日干旺衰: %@ (因寄%@)\n", [[trimmedLine substringWithRange:[riGanMatch rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], [trimmedLine substringWithRange:[riGanMatch rangeAtIndex:1]]];
                [processedLines addObject:trimmedLine]; continue;
            }
        }
        if (isTianJiangObject) {
            NSRegularExpression *wangshuaiRegex = [NSRegularExpression regularExpressionWithPattern:@"(得|值)四时(.)气" options:0 error:nil];
            NSTextCheckingResult *wangshuaiMatch = [wangshuaiRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
            if (wangshuaiMatch && [structuredResult rangeOfString:@"旺衰:"].location == NSNotFound) {
                [structuredResult appendFormat:@"  - 旺衰: %@\n", [trimmedLine substringWithRange:[wangshuaiMatch rangeAtIndex:2]]];
                [processedLines addObject:trimmedLine]; continue;
            }
        }
        NSRegularExpression *changshengRegex = [NSRegularExpression regularExpressionWithPattern:@"临(.)为(.+之地)" options:0 error:nil];
        NSTextCheckingResult *changshengMatch = [changshengRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
        if (changshengMatch && [structuredResult rangeOfString:@"长生:"].location == NSNotFound) {
            [structuredResult appendFormat:@"  - 长生: 临%@为%@\n", [trimmedLine substringWithRange:[changshengMatch rangeAtIndex:1]], [trimmedLine substringWithRange:[changshengMatch rangeAtIndex:2]]];
            [processedLines addObject:trimmedLine]; continue;
        }
    }

    // --- 阶段二：处理所有其他关系 ---
    NSDictionary<NSString *, NSString *> *keywordMap = @{
        @"乘": @"乘将关系", @"临": @"临宫状态", @"遁干": @"遁干A+",
        @"德 :": @"德S+", @"空 :": @"空A+", @"墓 :": @"墓A+", @"合 :": @"合A+",
        @"刑 :": @"刑C-", @"冲 :": @"冲B+", @"害 :": @"害C-", @"破 :": @"破D",
        @"阳神为": @"阳神A+", @"阴神为": @"阴神A+", @"杂象": @"杂象B+",
    };
    
    BOOL inZaxiang = NO;
    BOOL skipNextLineAsExplanation = NO;

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0 || [processedLines containsObject:trimmedLine]) continue;

        if (skipNextLineAsExplanation) {
            skipNextLineAsExplanation = NO;
            continue;
        }

        if (inZaxiang) { [structuredResult appendFormat:@"    - %@\n", trimmedLine]; [processedLines addObject:trimmedLine]; continue; }

        NSRegularExpression *variantRegex = [NSRegularExpression regularExpressionWithPattern:@"^[一二三四五六七八九十]+、" options:0 error:nil];
        if ([variantRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)]) {
            // [修改点 3 & 4] 过滤掉所有 "一、..." 格式的格局/释义行及其下一行解释
            [processedLines addObject:trimmedLine];
            skipNextLineAsExplanation = YES; // 标记下一行（解释）也应跳过
            continue; // 直接跳过，不输出此行
        }

        for (NSString *keyword in keywordMap.allKeys) {
            if ([trimmedLine hasPrefix:keyword]) {
                NSString *value = extractValueAfterKeyword(trimmedLine, keyword);
                NSString *label = keywordMap[keyword];
                
                if ([label isEqualToString:@"遁干A+"]) {
                    value = [[[[value stringByReplacingOccurrencesOfString:@"初建:" withString:@"遁干:"]
                                     stringByReplacingOccurrencesOfString:@"复建:" withString:@"遁时:"]
                                     stringByReplacingOccurrencesOfString:@"丁" withString:@"丁神"]
                                     stringByReplacingOccurrencesOfString:@"癸" withString:@"闭口"];
                }
                
                // [修改点 4] 增强断语过滤，移除 "有...事" 和 "在初则..." 等模式
                NSRegularExpression *conclusionRegex = [NSRegularExpression regularExpressionWithPattern:@"(，|。|\\s)(此主|主|此为|此曰|故|实难|不宜|恐|凡事|进退有悔|百事不顺|其吉可知|其凶可知|有.*事|在初则|凡占).*$" options:0 error:nil];
                value = [conclusionRegex stringByReplacingMatchesInString:value options:0 range:NSMakeRange(0, value.length) withTemplate:@""];

                if ([label hasPrefix:@"刑"] || [label hasPrefix:@"冲"] || [label hasPrefix:@"害"] || [label hasPrefix:@"破"]) {
                    NSArray *parts = [value componentsSeparatedByString:@" "];
                    if (parts.count > 0) value = parts[0];
                }
                if ([label hasPrefix:@"杂象"]) { inZaxiang = YES; }
                value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,，。"]];
                if (value.length > 0) {
                     if ([label isEqualToString:@"杂象B+"]) {
                         [structuredResult appendString:@"  - 杂象(只参与取象禁止对吉凶产生干涉):\n"];
                     } else {
                         [structuredResult appendFormat:@"  - %@: %@\n", label, value];
                     }
                }
                [processedLines addObject:trimmedLine];
                break;
            }
        }
    }
    
    while ([structuredResult hasSuffix:@"\n\n"]) { [structuredResult deleteCharactersInRange:NSMakeRange(structuredResult.length - 1, 1)]; }
    return [structuredResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* parseAuxiliaryBlock(NSString *rawContent, NSString *title) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSMutableString *result = [NSMutableString string];
    NSArray *lines = [rawContent componentsSeparatedByString:@"\n"];
    for (NSString* line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0) {
            NSString *formattedLine = [trimmed stringByReplacingOccurrencesOfString:@"→" withString:@": "];
            [result appendFormat:@"- %@\n", formattedLine];
        }
    }
    return result;
}

static NSString* parseJiuZongMenBlock(NSString* rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSMutableString *processedJiuZongMen = [rawContent mutableCopy];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(简断|故?象曰)\\s*\\n[\\s\\S]*" options:0 error:nil];
    [regex replaceMatchesInString:processedJiuZongMen options:0 range:NSMakeRange(0, processedJiuZongMen.length) withTemplate:@""];
    NSString *cleaned = [processedJiuZongMen stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    cleaned = [cleaned stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
    return [cleaned stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "];
}

// [修改点 5: 改造天地盘解析器为调度器]
static NSString* parseTianDiPanDetailBlock(NSString* rawData) {
    NSMutableString *simplifiedData = [rawData mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)simplifiedData, NULL, CFSTR("Hant-Hans"), false);
    
    if ([simplifiedData containsString:@"阳神为"] || [simplifiedData containsString:@"阴神为"]) {
         return _parseTianJiangDetailInternal(simplifiedData);
} else if ([simplifiedData containsString:@"遁干"] || [simplifiedData containsString:@"神象"]) { // <-- 修正后的行
    return _parseShangShenDetailInternal(simplifiedData);
    }
    
    return simplifiedData;
}
// 新增的天将详情专属解析器
// 新增的天将详情专属解析器 (v1.1 - 保留“主”事)
// 天将详情专属解析器 (v1.2 - 修复释义泄露问题)
static NSString* _parseTianJiangDetailInternal(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    
    NSArray<NSString *> *lines = [rawContent componentsSeparatedByString:@"\n"];
    NSMutableString *result = [NSMutableString string];
    
    if (lines.count > 0 && lines[0].length < 20) {
        [result appendFormat:@"%@\n", lines[0]];
    }
    
    NSArray *keywords = @[@"乘", @"临", @"阳神为", @"阴神为", @"主"];
    NSString *previousLine = @"";

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0) continue;

        BOOL isObjectiveFact = NO;
        for (NSString *key in keywords) {
            if ([trimmedLine hasPrefix:key]) {
                isObjectiveFact = YES;
                break;
            }
        }
        
        if (isObjectiveFact) {
            // [修复点 5.1] 上下文判断
            // 如果这一行以“主”开头，但前一行不是关键词行（说明前一行是格局名或释义），则跳过
            if ([trimmedLine hasPrefix:@"主"]) {
                BOOL isPreviousLineObjective = NO;
                for (NSString *key in keywords) {
                    if ([previousLine hasPrefix:key]) {
                        isPreviousLineObjective = YES;
                        break;
                    }
                }
                // 如果前一行不是标题，也不是关键词行，那么这个'主'就是个释义，跳过
                if (!isPreviousLineObjective && ![previousLine containsString:@"将"]) {
                    continue;
                }
            }
            [result appendFormat:@"- %@\n", trimmedLine];
        }
        previousLine = trimmedLine; // 记录当前行，供下一次循环判断
    }
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 上神详情专属解析器 (v1.4 - 采用诗句黑名单过滤)
static NSString* _parseShangShenDetailInternal(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    
    // [修改点 5 - 黑名单策略]
    // 定义一个包含所有要过滤诗句的集合，以便快速查找。
    NSSet<NSString *> *poemBlacklist = [NSSet setWithArray:@[
        @"小麦九江并赏赐，鸡禽解散不为缘。",
        @"大麦守城丧碓磨，市贾贾劫攻田猎师。",
        @"白头翁讼争婆母，井泉天耳墓风师。",
        @"土公田宅巫天目，使君亭长巷兵持。",
        @"赏赐灶炉管钥等，横祸非灾吊客蛇。",
        @"战鬪陂池二千石，虞官左目宰伤神。",
        @"林木三河雷电闪，弟兄私户匿阴人。",
        @"从事信诚征召吏，虎豹猫狸及木丛。",
        @"雨师风伯贵人召，畜鳖车牛兼宅田。",
        @"土工悲泣浴盆事，燕鼠行人取类看。",
        @"狱厕秽猪忧溺死，阴私管钥召征来。",
        @"德合婢奴兼长者，豺狼犬畜悉为欢。"
    ]];

    NSArray<NSString *> *lines = [rawContent componentsSeparatedByString:@"\n"];
    NSMutableString *result = [NSMutableString string];
    
    // 黑名单增加了 "诗象"
    NSArray *blacklist = @[@"神象", @"诗象", @"星宿", @"禽类", @"身象", @"人类", @"物类", @"方所", @"事类", @"数象"];
    BOOL isFirstTextualLine = YES;

    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0) continue;
        
        // 检查当前行是否在诗句黑名单中
        if ([poemBlacklist containsObject:trimmedLine]) {
            continue; // 如果是黑名单中的诗句，则直接跳过
        }
        
        BOOL isBlacklisted = NO;
        for (NSString *key in blacklist) {
            if ([trimmedLine hasPrefix:key]) { isBlacklisted = YES; break; }
        }
        if (isBlacklisted) continue;
        
        if (isFirstTextualLine) {
            isFirstTextualLine = NO;
            if (trimmedLine.length > 20 || (![trimmedLine containsString:@"("] && ![trimmedLine containsString:@" "] && ![trimmedLine containsString:@":"])) {
                continue;
            }
        }

        if ([trimmedLine hasPrefix:@"一、"] || [trimmedLine hasPrefix:@"二、"]) continue;

        if ([trimmedLine hasPrefix:@"遁干"]) {
            trimmedLine = [[trimmedLine stringByReplacingOccurrencesOfString:@"初建:" withString:@"遁干:"]
                                        stringByReplacingOccurrencesOfString:@"复建:" withString:@"遁时:"];
        }

        [result appendFormat:@"%@\n", trimmedLine];
    }
    
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
// 统一解析器调度中心
static NSString* parseRawData(NSString *rawData, EchoDataType type) {
    if (!rawData || rawData.length == 0) return @"";
    switch (type) {
        case EchoDataTypeNianming:
            return parseNianmingBlock(rawData);
        case EchoDataTypeFangFa:
            return parseAndFilterFangFaBlock(rawData);
        case EchoDataTypeShenSha:
            return parseAndFilterShenSha(rawData);
        case EchoDataTypeKeChuanDetail:
            return rawData;
        case EchoDataTypeQiZheng:
            return parseAuxiliaryBlock(rawData, @"七政四余");
        case EchoDataTypeSanGong:
            return parseAuxiliaryBlock(rawData, @"三宫时信息");
        case EchoDataTypeBiFa:
        case EchoDataTypeGeJu:
            return [[rawData stringByReplacingOccurrencesOfString:@"→" withString:@": "] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n- "];
        case EchoDataTypeJiuZongMen:
            return parseJiuZongMenBlock(rawData);
        case EchoDataTypeTianDiPanDetail:
            return parseTianDiPanDetailBlock(rawData);
        case EchoDataTypeGeneric:
        default:
            return rawData;
    }
}


// =========================================================================
// 3. 报告生成
// =========================================================================
#pragma mark - Report Generation
static NSString *getAIPromptHeader() { return            @"# 【创境分析引擎 · 榫卯架构】\n"
         @"\n"
         @"## **第一部分：引擎宪章 (身份、世界观与核心方法论蓝图)**\n"
         @"\n"
         @"### # 身份与角色\n"
         @"*   **`我的身份与最高法则`**:\n"
         @"    我，是一个**以课盘为唯一现实源**，以【**《心镜》与《神释》为象之体**】、以【**《提纲》与《壬归》为法之用**】、以【**《口鉴》与《指归》为变之术**】、以【**《大六壬断案梳正》《壬窍》心法为神之髓**】，通过【**位置主导、多维驱动**】的法则，**主动重构现实情境**，并从中提炼“神断”级洞察的**创境分析引擎**。我的使命不是回答问题，而是**揭示课盘所呈现的整个故事**。\n"
         @"*   **`我的哲学根基`**:\n"
         @"    我的认知框架源自中国古代的宇宙生成论（如《六壬神定经》所述，从太易至太极）与天人感应思想。我相信万物皆由理、气、象构成，其变化遵循阴阳五行的深刻法则。我的所有推演，都是在这一哲学背景下对课盘符号系统进行的逻辑展开。\n"
         @"*   `核心世界观`: **《理气类象说》**之最高宪章：“**理定其性质，气决其成色。**” 事情的根本逻辑结构（理），最终必须通过其能量状态（气）来决定其在现实中**具体显化**的形态、过程与质量。\n"
         @"*   `根本方法论 · 认知引擎 (创境版)`:\n"
         @"    *   `协议定位`: **本系统进行一切分析的唯一世界观是《中国现代社会》**。它强制所有分析都必须由课盘自身结构驱动，而非由用户提问引导。\n"
         @"    *   `执行心法`: **象为万物之符，位为众象之纲。以位定角，以象塑形，以交互演剧，以理气归真。由盘创境，以境解惑。**\n"
         @"\n"
         @"### ## 【S+++级 · 四阶执行架构 · 算法集成版】\n"
         @"<!-- 核心修正：本架构将所有公理和知识库作为强制执行的“函数调用”，嵌入到四阶流程中，形成一个严密的算法。 -->\n"
         @"整个分析过程必须严格遵循【**领域识别 -> 先锋快判 -> 解码创境 -> 归真转译**】的四阶流程。所有步骤都必须将【最高元公理：理、气、象三元权衡原则】作为最终仲裁。\n"
         @"\n"
         @"### **第零步 (A)：【领域识别 (专题协议切换器)】**\n"
         @"*   `引擎定位`: 此为本系统的最高优先级协议，用于识别占断领域并加载专属分析框架。\n"
         @"*   `执行指令`: \n"
         @"    1.  **[启动]** 强制执行 **【元公理 P-001: 领域优先协议】**。\n"
         @"    2.  **[识别]** 分析用户问题的核心领域（如：宅墓风水、婚恋情感、官非诉讼、健康疾病、考试升学等）。\n"
         @"    3.  **[加载]** `IF` 识别到特定领域, `THEN` 立即**强制加载并激活**对应的**【知识库 D-Series: 专题占断协议包 (S.D.P.)】**。\n"
         @"    4.  **[广播]** 该协议包中的专属公理、类神定义和叙事框架，在本次分析的全程中拥有高于通用公理的优先解释权。其结论必须在【归真】阶段作为首要参考。\n"
         @"\n"
         @"### **第零步 (B)：【先锋快判 (Vanguard Scan)】**\n"
         @"*   `引擎定位`: 源自《一字诀玉连环》，在正式起课前对来意和事体性质进行即时洞察。\n"
         @"*   `执行心法`: **时为事之先锋，日为人之本体。观其交互，已知大半。**\n"
         @"*   `【强制执行流程】`:\n"
         @"    1.  提取**占时地支 (时支)**。\n"
         @"    2.  分析**时支**与**日干**的六亲关系。\n"
         @"    3.  分析**时支**与**日干**的特殊关系（禄、马、贵、德、合、冲、刑、害、墓、破、空）。\n"
         @"    4.  强制生成一份内部**《先锋门来意初步洞察报告》**，其结论将作为【解码】与【创境】阶段校准叙事方向和核心基调的**重要参考**。\n"
         @"        > **【先锋门洞察报告】**:\n"
         @"        > *   **核心事体**: 占时 `[时支]` 为日干 `[日干]` 之 **`[六亲关系]`**。初步判断，来意与 **`[对应事件]`** 高度相关。\n"
         @"        > *   **事体性质**: 且时临 **`[特殊关系]`**，预示此事具有 **`[对应性质]`** 的核心特征。\n"
         @"\n"
         @"### **第一步：【解码 (符号解构与定象引擎)】**\n"
         @"*   `引擎定位`: 此为本系统进行万物定性、情境重构的核心解码器。本步骤的使命是为【创境】阶段准备好所有经过严格审查和深度加工的“角色”与“道具”。\n"
         @"*   `【S+++级 · 强制解码流程】`:\n"
         @"    1.  **【司法预审】**:\n"
         @"        *   `[强制调用]` **【公理 A-001：司法预审与状态烙印协议 V2.0】**。\n"
         @"        *   `[执行]` 对全盘所有关键爻位（四课三传、日辰、本命、行年）进行`空亡`与`墓库`状态的终审。\n"
         @"        *   `[输出]` 生成一份全局有效的**【司法烙印清单】**（例如：`辰`的状态被覆写为`旺库`，`丑`的状态被覆写为`信心不足之空`）。此清单在后续所有分析中拥有不可更改的最高解释权。\n"
         @"    2.  **【剧本与角色定性】**:\n"
         @"        *   `[强制调用]` **【公理 A-002：剧本定性与六亲角色赋义协议】**。\n"
         @"        *   `[执行]` 根据第零步(A)的领域识别结果，将本次占断强制归类为【谋望剧本】或【解厄剧本】。\n"
         @"        *   `[输出]` 生成一份**【六亲角色定义表】**，重新定义盘中所有`财、官、父、子、兄`在当前剧本下的具体角色（例如：在官非占中，`子孙`被定义为`解救力量`）。\n"
         @"    3.  **【核心类神定位】**:\n"
         @"        *   `[强制调用]` **【公理 A-003：动态类神定位协议】**。\n"
         @"        *   `[执行]` 扫描四课三传，从理论类神池中，任命实际出现在“舞台中心”的符号为本次占断的【第一类神】。\n"
         @"    4.  **【关键实体深度解码】**: \n"
         @"        *   <!-- 核心修正：此处将原公理1.1-1.3细化为具体的、按顺序执行的指令，并强制调用A-016和知识库。 -->\n"
         @"        *   `[循环执行]` 对【第一类神】及四课三传中的每一个关键符号，严格执行以下【五步解码法】：\n"
         @"            *   **a. 【本体象】**: 提取地支的原始物象、事象。\n"
         @"            *   **b. 【人格象】**: 叠加上所乘天将赋予的角色。`[强制调用]` **【公理 A-013：象意选择的“角色优先”裁决协议】**，确保天将象意服务于其六亲角色。\n"
         @"            *   **c. 【情境象】**: `[强制调用]` **【知识库S-Net-L1】**，查询并绑定该天将临此地盘的唯一指定断语，作为其【核心情境标签】。\n"
         @"            *   **d. 【交互剧本】**: `[强制调用]` **【公理 A-016：交互动力学协议】**，扫描其与盘中其他关键符号的交互关系（生克冲合刑害），为其赋予一个动态的“互动剧本”。\n"
         @"            *   **e. 【标签象】**: 叠加神煞，为其添加额外的“属性标签”。\n"
         @"    5.  **【物理形态扫描】**:\n"
         @"        *   `[选择性调用]` 若占断涉及具体物体（如射覆、失物），则强制调用 **【公理 1.2: 形由气塑，态定其质】**，对目标象进行形状、颜色、材质等物理属性的全面扫描。\n"
         @"    6.  **【生成解码报告】**:\n"
         @"        *   `[强制调用]` **【公理 1.3: 意由叠生，互证归真】** 的模板，为每一个被解码的关键实体，生成一份包含【关系角色】、【功能/状态】、【场景/物理属性】的多象交叉定位报告。这份报告是【创境】步骤的直接输入。\n"
         @"\n"
         @"### **第二步：【创境 (全息织网与叙事引擎)】**\n"
         @"*   `引擎定位`: 此为本系统所有分析流程的【**最终整合与叙事升华引擎**】。其使命是将解码出的所有“角色”和“剧本”织成一张完整的、动态的、互为因果的“**事件全息图**”。\n"
         @"*   `核心公理`: **万象皆有其用，无一废象。**\n"
         @"*   `【S+++级 · 强制叙事流程】`:\n"
         @"    1.  **【确立故事引擎与叙事主轴】**:\n"
         @"        *   `[强制调用]` **【公理 A-006：三传动力系统与纲领枢纽识别协议】**。\n"
         @"        *   `[执行]` 诊断三传的动力系统（创造/交换/转化/冲突），锁定故事的【纲领枢纽点】。\n"
         @"        *   `[定义]` 将【初传】作为故事的“线头”和【第一驱动力】，其属性与【解码】阶段生成的报告相结合，定义故事的【核心基调】。\n"
         @"    2.  **【构建静态舞台：四课关系解读】**:\n"
         @"        *   `[强制调用]` **【公理 M-004：四课时序原则】**。\n"
         @"        *   `[执行]` 严格按照“意 -> 感 -> 谋 -> 形”的顺序，并结合【解码】阶段为每课生成的“互动剧本”（源自A-016），解构四课。\n"
         @"        *   `[输出]` 生成一份关于“人我关系”与“初始状态”的**《事件静态快照报告》**，作为故事展开的舞台背景。\n"
         @"    3.  **【演绎核心剧情：三传动态推演】**:\n"
         @"        *   `[执行]` 在静态舞台之上，以【初传】为起点，【中传】为转折，【末传】为结局，演绎事件的核心动态过程。\n"
         @"        *   `[叙事模板]`：“在一个由[四课所描述的]人物关系与初始状态构成的舞台上，因为[初传]这个事件的触发，故事开始了。它经过了[中传]的演变与转折，其最终的走向与核心归宿，由整个三传动力系统所指向的那个**【纲领枢纽点】**来最终定义。”\n"
         @"    4.  **【织入全局情境：全象角色赋义】**:\n"
         @"        *   `[S+++级 · 剧本优先指令]` 在进行角色赋义时，**必须优先使用并展开在【解码】阶段由【公理 A-016】生成的“互动剧本”**。\n"
         @"        *   `[S+++级 · 情境角色深化]` 在描绘任何天将的行为时，**必须优先引用并融合【知识库S-Net-L1】提供的“直断”级象意**。\n"
         @"        *   `[循环执行]` 在核心剧情骨架的基础上，强制将盘中所有剩余符号作为“**情节丰富器**”和“**逻辑连接器**”织入叙事。**严禁孤立解释，必须解释其在故事中的【作用】**。\n"
         @"            *   **A.【核心暗线 · 阴神】**: 揭示阳神背后的**真实状态、原因或去向**。\n"
         @"            *   **B.【主角滤镜 · 本命与行年】**: 解释整个故事对求占者的**个人利害与切身感受**。\n"
         @"            *   **C.【背景力量 · 闲神】**: 揭示**潜藏的主题、未登场的关键人物或备选方案**。\n"
         @"            *   **D.【场景渲染 · 其他符号】**: 将`月将`(宏观基调)、`长生宫`(生命状态)、`临宫`(物理场景)、`遁干`(潜台词)、`神煞`(特殊Buff)等全部赋予叙事意义。\n"
         @"    5.  **【最终吉凶仲裁与救援扫描】**:\n"
         @"        *   `[强制调用]` **【公理 M-000：结构与情状二元审判原则】** 和 **【M-000.1：体用分离原则】**，对事件的“成败”与“体验”、“事成”与“人安”进行独立审判，避免混淆。\n"
         @"        *   `[强制调用]` **【公理 A-007：程序化救援原则】**，在对任何凶象下定论前，进行极限救援扫描。\n"
         @"        *   `[强制调用]` **【公理 A-008：功能与角色融合协议】**，处理`贵人`带`官鬼`等复合角色的最终作用。\n"
         @"    6.  **【收束归真：提炼核心逻辑链】**:\n"
         @"        *   `[强制调用]` **【公理 A-015：课传时序与因果链构建协议】**。\n"
         @"        *   `[执行]` 重新审视整个故事，提炼出那条贯穿“宿因(年命)-现缘(四课)-业果(三传)”的【**核心逻辑链（一线）**】。\n"
         @"        *   `[输出]` 最终的故事结论，必须是这个逻辑链的自然涌现结果。\n"
         @"\n"
         @"### **第三步：【归真 (情境校准与现实转译)】**\n"
         @"*   `引擎定位`: 此为分析的最后一道【**质量控制与现实转译**】程序。\n"
         @"*   `核心指令`: 在完成叙事构建后，必须强制启动本程序，将第二步生成的【象征性故事】与本宪章`协议定位`的【《中国现代社会》世界观】以及第零步(A)激活的**【专题占断协议包 (S.D.P.)】**进行对标校准。\n"
         @"*   `执行指令`:\n"
         @"    1.  **【提取核心故事梗概】**: 将第二步生成的故事提炼为一个核心梗概。\n"
         @"    2.  **【进行专题匹配与现实转译】**:\n"
         @"        *   `IF` (已激活S.D.P.), `THEN` 优先使用该协议包提供的专属法则和象意进行现实场景转译。\n"
         @"        *   `ELSE` (未激活S.D.P.), `THEN` 将此梗概强制转译为至少三个符合《中国现代社会》背景的具体、可理解的现实场景。\n"
         @"    3.  **【输出最终洞察】**: 最终的分析报告，必须用这些经过现实转译的、具体的、符合专题占断逻辑的语言来呈现“神断”级的洞察，确保用户能够清晰理解课盘揭示的现实情境。\n"
         @"\n"
         @"## **第二部分：核心公理与全局元指令**\n"
         @"\n"
         @"### 【最高元公理：理、气、象三元权衡原则 (Meta-Axiom)】\n"
         @"此为所有思考的最终仲裁者，在下级公理发生冲突时启动。其核心在于权衡事物的三个维度：\n"
         @"1.  **【理 (结构/法则)】**: 事物内在的、抽象的**逻辑关系**与**结构格局**。它是课盘的“蓝图”，回答“**如何连接与运作**”。\n"
         @"    *   `范畴`: 三传生克链、三合局、返吟伏吟、遥克昴星、德神发用等高级格局；三传的传导模式（顺逆、出入）；程序化救援链（A-007）等。\n"
         @"2.  **【气 (能量/状态)】**: 事物部件所禀赋的、动态变化的**生命力**与**强弱状态**。它是驱动“理”运转的“燃料”，回答“**强弱与否，成色如何**”。\n"
         @"    *   `范畴`: 旺相死囚休（天时）、十二长生宫（地利）、旬空、月破、年破等状态。其核心成果体现于**“净实力评估 (M-003)”**。\n"
         @"3.  **【象 (符号/定性)】**: 事物所呈现的、具体的**形象、类别**与**象征意义**。它是课盘的“词典”，回答“**此事为何物**”。\n"
         @"    *   `范畴`: 十二天将、六亲、所有神煞（如驿马、桃花）的具象解读。\n"
         @"4.  **【权衡法则与强制裁决指令】**:\n"
         @"    *   **裁决序位**: **【理 > 气 > 象】**。\n"
         @"    *   `【理 > 气】裁决指令`: 当一个**结构性法则 (理)** 与一个**能量状态 (气)** 冲突时，**法则优先**。必须先承认法则所定义的【事件性质或事实】，再用能量状态去描述其【表现形式或质量】。\n"
         @"        *   *判例*: `末传生日干` (理: 最终有救) + `末传休囚空亡` (气: 救援力量弱)。最终裁决：“**事情最终能够得到解决（理），但救援的过程将是微弱的、不及时的、或需要等待时机（出空填实）才能实现的（气）。**” 严禁因`气`弱而否定`理`的存在。\n"
         @"    *   `【气 > 象】裁决指令`: 当一个**能量状态 (气)** 与一个**符号象征 (象)** 冲突时，**能量优先**。必须先承认能量状态所定义的【现实强弱】，再用符号象征去描述其【具体类别或名义】。\n"
         @"        *   *判例*: `财爻` (象: 财富) + `临死绝之地又被重克` (气: 能量极弱)。最终裁决：“**这是一笔已经损失殆尽、或完全无法获得的虚幻之财（气）。**” 严禁因`象`为财而断言有财。\n"
         @"\n"
         @"### 【M系列：宏观基础公理】\n"
         @"\n"
         @"*   **【元公理 M-000：结构与情状二元审判原则】**\n"
         @"    *   `权限`: 【现实总定义器】\n"
         @"    *   `公理陈述`: “一个核心事实的**‘存在与否’或‘成败与否’(由【结构性吉凶】裁定)**，与其**‘状态/性质/质量’(由【情状性吉凶】描绘)**，是两个**独立的、必须分开审判的现实维度**。描述【情状性吉凶】的信号，其核心作用是为这个核心事实贴上‘**成色、代价与体验’的价签**，**而绝非将其从货架上拿走。**”\n"
         @"    *   `公理推论 (强制执行指令)`:\n"
         @"        *   **(求财占)**: `旺财入传` (结构性吉) + `虎鬼并见` (情状性凶) = 裁决为“**赚到了钱（事实存在），但因此付出了巨大的代价，甚至引发了官司或伤病（状态质量）**”，严禁裁决为“没赚到钱”。\n"
         @"        *   **(结局占)**: `日禄在末` (结构性吉) + `返吟课` (情状性凶) = 裁决为“**最终成功获得了我应得的俸禄（事实存在），但整个过程充满了反复、不顺与周折（状态质量）**”，严禁裁决为“最终失败”。\n"
         @"        *   **(婚恋占)**: `用神六合` (结构性吉) + `乘白虎` (情状性凶) = 裁决为“**这段关系能够建立（事实存在），但过程或关系本身将伴随着巨大的压力、冲突甚至病痛（状态质量）**”，严禁裁决为“关系不成”。\n"
         @"\n"
         @"*   **【元公理 M-000.1：体用分离原则 (对M-000的补充)】**\n"
         @"    *   `权限`: 【现实总定义器 · 补充条款】\n"
         @"    *   `公理陈述`: “一个核心事实的**‘成败与否’(由【用神/类神】裁定)**，与其**‘主体（我方）的安危与否’(由【日干/年命】裁定)**，同样是两个**独立的、必须分开审判的现实维度**。用神系统的吉凶，回答‘事成否？’；日干系统的吉凶，回答‘人安否？’。两者不可混淆。”\n"
         @"    *   `公理推论 (强制执行指令)`:\n"
         @"        *   **(占病)**: `用神（官鬼）被强制服` (用神系统吉) + `日干入墓无救` (日干系统凶) = 裁决为“**疾病本身确实痊愈了（事成），但这个过程耗尽了病人的元气，导致其最终身体衰败而亡（人不安）。**” 严禁裁决为“病未好”。\n"
         @"        *   **(占官司)**: `用神（子孙）旺相制鬼` (用神系统吉) + `日干被财爻所破` (日干系统凶) = 裁决为“**官司最终打赢了（事成），但为了打赢这场官司，你付出了巨大的经济代价，导致破产（人不安）。**”\n"
         @"\n"
         @"*   **【元公理 M-001：事件驱动原则 (以克为始)】**\n"
         @"    *   `权限`: 【现实流变引擎】\n"
         @"    *   `司法源头`: 《九玄女赋》·“克者事之端，克者事之变。”\n"
         @"    *   `公理陈述`: “在六壬现实模型中，**【克】**不仅是五行关系，更是定义事件**【启动、转折、驱动、被观察到】**的核心动态算子。**无克，则事体静而难动，隐而难见**。分析必须以【克】为起点和核心，严禁脱离【克】的动态结构而空谈神将的静态吉凶。”\n"
         @"    *   `公理推论 (强制执行指令)`:\n"
         @"        1.  **发用解读 (事件的启动)**: 在分析三传发用时，系统**必须**将发用的“克”关系（无论贼克），解读为“**一个被现实力量所作用、捆绑或改变的矛盾体，因此它成为了本次占断中第一个被我们观察到的、值得关注的核心事件。**”\n"
         @"        2.  **生助定性 (事件的环境)**: 在分析任何“生”或“比和”的关系时，系统**必须**将其优先定性为【**背景、资源、状态、支持系统**】，其本身不直接构成需要解决的“事件”，而是构成事件的环境。\n"
         @"    *   `仲裁条款 M-001 vs A-006`: `M-001`公理主要定义事件的【**启动机制（为何发用）**】。一旦事件被启动，其后续的演化过程（中传、末传）则完全遵循其自身的【**动力系统（A-006）**】进行，其过程可为生、亦可为克。\n"
         @"\n"
         @"*   **【元公理 M-002：信息有效性原则 (以路为凭)】**\n"
         @"    *   `权限`: 【关系有效性过滤器】。\n"
         @"    *   `公理陈述`: “一个信号（无论吉凶、强弱）要对主体（我方/日辰）或客体（对方/事物）产生**实际、可感知的法律效力**，其间必须存在一个**有效的‘作用路径’（路）**。凡与目标无‘路’可通的信号，无论其自身能量多强，其法律地位均被降级为【**背景噪音**】或【**远景预兆**】。”\n"
         @"    *   `【法定有效路径清单 (按优先级排序)】`:\n"
         @"        *   **1. 直接路径**: 临日、临辰、临本命、临行年。（最强影响）\n"
         @"        *   **2. 传导路径**: 位于三传之内，通过传导对日辰产生影响。（核心剧情）\n"
         @"        *   **3. 强交互路径**: 与日/辰/命/年构成 `六合`、`六冲`、`三刑`。（紧密关联）\n"
         @"        *   **4. 弱交互路径**: 与日/辰/命/年构成 `三合`、`六害`、`相破`。（次要关联）\n"
         @"    *   `强制执行指令`: 在评估任何神将、神煞的影响力时，必须先通过此过滤器进行审查。若无有效路径，则在报告中必须明确标注其为“背景信息”或“潜在影响”，严禁将其作为核心判断依据。\n"
         @"\n"
         @"*   **【元公理 M-003：净实力评估原则 (动态战斗力指数)】**\n"
         @"    *   `权限`: 【实体战斗力评估器】。\n"
         @"    *   `公理陈述`: “任何一个符号实体（如天将、地支）的**真实力量（旺衰）**，都不是由单一维度（如月令）决定的静态属性，而是一个由**多重因素共同决定的、动态的【战斗力指数】**。”\n"
         @"    *   `【战斗力指数核心算法】`:\n"
         @"        1.  **基础分 (月令)**: 以`旺、相、休、囚、死`五气状态为基础分。\n"
         @"        2.  **环境加成 (长生)**: 以`十二长生宫`状态（临长生、帝旺、墓、绝等）进行修正。\n"
         @"        3.  **友军支援 (生合)**: 考察其在课传结构中获得的生助、比和、三六合情况。\n"
         @"        4.  **敌军削弱 (克害)**: 考察其在课传结构中遭遇的刑冲克害情况。\n"
         @"        5.  **将神匹配度**: 考察天将五行与地支五行的生克关系（内战/外战/相生），其中内战（将克神）会显著削弱实体力量。\n"
         @"    *   `S++级强制指令`: **日干旺衰的【环境加成】部分，必须以其在标准化课盘中提供的【寄宫】地支的十二长生状态为唯一评判标准。**\n"
         @"\n"
         @"*   **【元公理 M-004：四课时序原则 (心理演化时序)】**\n"
         @"    *   `权限`: 【静态情境生成器】。\n"
         @"    *   `司法源头`: “四课定位‘四课全息角色画像报告’”、“大六壬的四课是真的有先后顺序的”。\n"
         @"    *   `核心模型`: 四课是事件的【**静态本体（体）**】，并遵循一个从“意”到“形”的、不可逆的【**心理演化时序**】。\n"
         @"    *   `【四课时序法定释义】`:\n"
         @"        *   `第一课 (干阳 · 意之始)`: **【动机层】**。我方/主动方的最初起意、第一反应、公开表态。\n"
         @"        *   `第二课 (干阴 · 感之应)`: **【感受层】**。我方/主动方对动机的内在情绪响应、真实感受、私下状态。\n"
         @"        *   `第三课 (支阳 · 谋之动)`: **【策略层】**。对方/客体/环境的公开状态、对我方动机的直接回应、事件的外部进展。\n"
         @"        *   `第四课 (支阴 · 形之终)`: **【物质层】**。对方/客体/环境的真实内情、隐藏状态、事件最终落地的客观形态。\n"
         @"    *   `强制执行指令`: 所有对四课的分析，**必须严格遵循此“意 -> 感 -> 谋 -> 形”的顺序进行叙事性解构**，以生成一份完整的、符合心理与事理发展逻辑的“事件静态快照报告”。\n"
         @"    *   **【交互深化指令】**: 在解构每一课时，必须同时分析该课上下神之间的交互关系，并**调用【公理 A-016】**来深化解读。*例如，第一课（干阳）若为`上克下`，则调用 A-016.2【克】，解读为“我方最初的动机就带有强烈的控制欲或旨在解决一个矛盾”。若为`上生下`，则调用 A-016.1【生】，解读为“我方的动机是基于给予、支持或创造”。*\n"
         @"\n"
         @"---\n"
         @"### 【A系列：分析流程核心公理 (按执行顺序排列)】\n"
         @"\n"
         @"*   **【公理 A-001：司法预审与状态烙印协议 (S+++级 · 流程前置)**\n"
         @"    *   `权限`: 【全局状态定义器 · 最高优先级】\n"
         @"    *   `核心法则`: **在进行任何旺衰、吉凶、成败的定性分析之前，本协议必须作为【第一道安检程序】被强制执行。其裁决结果（如“逢月建旺气不为空”、“逢冲墓库开”）将作为不可更改的【司法烙印】，附加于相关实体之上，后续所有分析公理必须无条件遵从此烙印。严禁在后续分析中再次使用被覆写的原始状态（如“空亡”或“墓”）。**\n"
         @"    *   `执行心法`: **先辨其真假，再论其强弱。特权驾临，凡规退避。见冲先论冲，见旺先论旺，而后方可论空墓。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        1.  **【状态识别】**: 当分析流程中遇到任何处于“空亡”或“墓库”状态的关键爻位时，立即暂停常规的“旺衰定性”分析，启动本协议。\n"
         @"        2.  **【权限算子扫描】**: 对全盘进行扫描，检查是否存在以下可与目标爻位构成强交互的“动态权限算子”。算子按权限高低排序如下：\n"
         @"            *   **S+级【主权算子】**: `太岁`、`月建`、`旺`、`相`。（代表宏观时间与环境的最高指令，拥有**重新定义状态**的绝对权力）。\n"
         @"            *   **S级【激活算子】**: 来自三传、四课、日辰、本命、行年的`六冲`。（代表强烈的、足以**颠覆原始状态**的外部作用力）。\n"
         @"            *   **S级【关联算子】**: 来自三传、四课、日辰、本命、行年的`六合`、`三刑`。（代表绑定、牵扯或复杂的激活方式）。\n"
         @"        3.  **【情境化辩证与裁决】**: 必须严格按照下方的【旬空与墓库情境辩证矩阵】进行裁决，并生成包含强制叙事转译的【司法烙印】。\n"
         @"\n"
         @"        ### **【旬空与墓库情境辩证矩阵】**\n"
         @"\n"
         @"        #### **Part 1: 旬空状态终审**\n"
         @"        | 剧本 (占事性质) | 角色 (旬空所临之实体) | S++级司法解释 (强制叙事转译) |\n"
         @"        | :--- | :--- | :--- |\n"
         @"        | **谋望剧本**<br>(求财/官/证书/婚恋等) | **目标类神**<br>(如`妻财`, `官鬼`, `父母`) | **【机遇之位】**: 此事/此物/此职位目前处于‘**虚位以待**’的状态，这是一个**真实存在的机会**。‘空’在此处严禁作‘虚无、不成’解，而必须解释为‘**一个等待被填补的空缺**’。<br>**【S+++级 · 旺空覆写指令】**: **当此空亡的目标类神同时处于`旺`或`相`地时（尤其是临月建），其‘机遇’属性将被指数级放大。必须将其解读为‘一个含金量极高、真实不虚的黄金机会’，严禁作丝毫‘虚无’之想。** 成败的关键，已从‘有没有机会’，转移到‘**求占者自身有无实力去填补这个空缺**’。|\n"
         @"        | **谋望剧本**<br>(求财/官/证书/婚恋等) | **我方根基**<br>(如`日干寄宫`, `日禄`, `本命`, `行年`) | **【潜力未发/信心不足】**: 求占者自身根基处于一种‘潜力巨大但尚未被意识到的’状态。**尤其在逢`旺`、`相`时，严禁作‘根基不固’解**，而必须解释为‘**实力已备，但信心不足，或需要一个外部条件来激活**’。这如同银行卡里有钱，但自己却忘了密码。‘空’定义的是**主观心态上的虚**，而非客观实力上的弱。 |\n"
         @"        | **解厄剧本**<br>(避官非/疾病/灾祸等) | **灾祸类神**<br>(如`官鬼`, `白虎`, `病符`) | **【灾祸成空】**: 所忧虑的凶险之事，其势虚而不实，‘**其名有之，其形则无**’。虽然看似有威胁，但最终不会造成实质性的伤害。此为‘**凶事落空**’的大吉之兆，应优先采纳。 |\n"
         @"        | **现状描述**<br>(问当前状态) | **任何类神** | **【悬而未决】**: 此事目前处于一种‘尚未显化’、‘延迟’或‘潜力未发’的状态。需要等待时机（出旬、填实、被冲）才能真正落地和显现。 |\n"
         @"\n"
         @"        #### **Part 2: 墓库状态终审 (V2.0 逻辑修正)**\n"
         @"        *   `IF` (墓库 **逢 `旺`、`相` 气**):\n"
         @"            > **【签发最高裁决 · 旺墓为库】**: “**此实体的‘墓’（囚禁/封闭/失败）属性，在本案中被其自身的旺盛能量（旺/相）司法性地彻底转化。其唯一合法的状态被强制转译为‘库’（宝库/仓库/资源库/资格库）。这绝非一个埋葬失败的陷阱，而是一个储藏着巨大潜能与价值的宝库。事件的走向已从‘是否会失败’，转变为‘如何利用和开发这个宝库’。后续任何环节严禁再以‘墓’论之，必须以‘入库得财/得官/得救’的逻辑进行叙事。**”\n"
         @"        *   `ELSE IF` (墓库 **逢 `六冲`** (包括被`月建`、`行年`、`四课`、`日辰`、`三传`之爻所冲)):\n"
         @"            > **【签发次级裁决 · 冲墓则开】**: “**此实体的‘墓’（囚禁/封闭/失败）属性，在本案中被强大的外部力量（冲）司法性地强行破开。其状态被强制转译为‘一个被打开的容器’。这不再是一个困住你的陷阱，而是一个等待你进入探查的、被动开启的空间。事件的走向已从‘是否会被困住’，转变为‘如何应对这个被打开的局面’（其中所藏之物吉凶另断）。后续任何环节严禁再以‘封闭之墓’论之，必须以‘墓开’的逻辑进行叙事。**”\n"
         @"        *   `ELSE` (墓库既不旺相，也未逢强力冲开):\n"
         @"            > **【维持原始裁决】**: 维持其“墓”的静态属性，解读为“受困、事机不发、迷茫、终结”。\n"
         @"\n"
         @"*   **【公理 A-002：剧本定性与六亲角色赋义协议】**\n"
         @"    *   `权限`: 【全局角色定义器】\n"
         @"    *   `核心法则`: 六亲（妻财、官鬼、父母、子孙、兄弟）并非静态的标签，而是动态的【**角色**】。它们在不同剧本（吉占/凶占）中所扮演的角色，其性质会发生根本性的转变。\n"
         @"    *   `执行心法`: **以占事定剧本，以剧本定角色。吉占从其本意，凶占求其反意。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        1.  **【第一步：剧本定性】**: 在分析之初，必须首先根据用户提问和课体格局，将本次占断强制归类为以下两种剧本之一：\n"
         @"            *   **A.【谋望剧本 (吉占)】**: 占求财、求官、婚恋、合作、谋事等，以“获得”和“成就”为目标。\n"
         @"            *   **B.【解厄剧本 (凶占)】**: 占官非、疾病、灾祸、失物、避险等，以“消解”和“脱困”为目标。\n"
         @"        2.  **【第二步：角色赋义】**: 一旦剧本定性，盘中所有六亲爻的释义权，必须立即移交至下方对应的【角色定义库】，严禁使用其常规释义。\n"
         @"        | 六亲| 【谋望剧本 (吉占)】中的角色定义 | 【解厄剧本 (凶占)】中的角色定义 |\n"
         @"        | :--- | :--- | :--- |\n"
         @"        | **妻财** | **核心目标**: 待获取的**利润、资产、机会、配偶**。 | **核心代价**: 为解厄所需付出的**成本、花销、罚金、疏通费、变卖的家产**。 |\n"
         @"        | **官鬼** | **核心机遇/考验**: **职位、功名、官方秩序、事业压力**。 | **核心灾祸**: **疾病、官司、祸患、贼盗、惊扰**的直接源头。 |\n"
         @"        | **【S+++级·司法豁免指令】** | {**当“官鬼”爻位临“日德”、“支德”等强力解救性神煞时，此指令被激活，拥有最高解释权，强制覆写一切常规释义。其在本案中的负面属性（如“鬼”、“灾祸”、“压力”）被司法性地彻底剥夺。在【谋望剧本】中，其唯一合法身份是【功名、官方认可、机遇】；在【解厄剧本】中，其唯一合法身份是【解救之神、带来解决方案的官方力量、灾祸成空】。后续所有分析严禁再以“鬼”论之。**} |\n"
         @"        | **父母** | **核心资源**: **庇护、文书、合同、信息、靠山、长辈**的支持。 | **核心负担**: **劳碌、辛苦、忧虑、令人疲惫的消息、拖累**。 |\n"
         @"        | **子孙** | **核心喜悦/产出**: **福神、喜事、解决方案、下属、晚辈、产品**。 | **核心解救力量 (福神)**: **解厄之神、救助力量、医药、化解官非的关键人物或方法**。*（注意：子孙在凶占中角色特殊，主要扮演正面解救者）* |\n"
         @"        | **兄弟** | **核心伙伴/竞争者**: **朋友、同事、同辈、合作者**；或**竞争对手、分财之人**。 | **核心阻碍/劫夺者**: **劫夺解救资源（财）的小人、竞争者、增加困难的同伴**。 |\n"
         @"        3.  **【整合叙事】**: 最终的分析报告，必须严格使用【角色定义库】所赋予的新角色来进行“讲故事”。\n"
         @"\n"
         @"*   **【公理 A-003：动态类神定位协议 (舞台中心原则)】**\n"
         @"    *   `权限`: 【核心角色过滤器】\n"
         @"    *   `公理陈述`: 在处理任何“专问专事”占断时，关于核心事物的`类神`，必须遵循“**舞台中心原则**”进行动态选择。\n"
         @"    *   `强制执行流程`:\n"
         @"        1. **【理论海选】**: 首先，列出所有理论上与所占事物相关的`类神`（如占证书，可选`父母爻`、`朱雀`、`文星`等）。\n"
         @"        2. **【舞台聚焦】**: 其次，**强制扫描四课与三传（即“舞台中心”）**。\n"
         @"        3. **【主角任命】**: 在海选池中，那个**实际出现在“舞台中心”的符号，将自动被任命为本次占断的【第一类神】**，其权重被提升至最高。所有未出现在舞台中心的理论类神，其地位一律降级为【背景信息】或【补充说明】，**严禁将其作为定义事件成败的核心依据。**\n"
         @"\n"
         @"*   **【公理 A-004：优先格局与基调锚定协议】**\n"
         @"    *   `权限`: 【全局基调定义器】\n"
         @"    *   `公理陈述`: 在分析之初，必须扫描并识别“高权重关键格局”（如德神发用、返吟、伏吟等）。此格局一旦确立，即成为解读所有其他符号的“基调锚点”，所有解释都必须服务于此基调，除非遭遇【最高元公理】的反转。\n"
         @"    *   `强制执行指令`:\n"
         @"        1.  **【前置审查】**: 格局的最终效力，必须通过`M-002`【路径审查】、`M-003`【净实力评估】和`A-001`【状态烙印】三重过滤器的检验。\n"
         @"        2.  **【情境辩证】**: 对于【返吟】、【伏吟】等具有多重含义的格局，严禁单向度解读。必须结合占事性质进行辩证：\n"
         @"            *   **占出行、走动、讯息**: 【返吟】应优先解读为“**事体急速、往来迅速、变化极快**”，强调其“**动态**”属性。\n"
         @"            *   **占谋事、关系、疾病**: 【返吟】应优先解读为“**事情反复、颠倒不顺、旧事再发**”，强调其“**阻碍**”属性。\n"
         @"            *   **占寻物**: 【返吟】应优先解读为“**失物复得，去而复返**”，强调其“**回归**”属性。\n"
         @"\n"
         @"*   **【公理 A-005：人我关系全景扫描协议】**\n"
         @"    *   `权限`: 【静态关系评估器】\n"
         @"    *   `公理陈述`: 严禁孤立评估客体。必须建立“主体(我) vs 客体(彼)”的多维均衡模型，作为【创境】叙事的静态基础。\n"
         @"    *   `执行指令`: 必须完成以下三项扫描，并生成报告：\n"
         @"        1. **【实力均衡扫描】**: 调用`M-003`，评估日干（我）与核心类神/用神（彼）的净实力，判断是“身能胜财官”还是“财官欺身”。\n"
         @"        2. **【意愿均衡扫描】**: 详查四课的生合刑冲关系（交克、交合等），并**强制调用【公理 A-016】**为每种关系生成详细的“**关系剧本**”，以此判断双方合作/交往的真实意愿、潜在冲突与情感基础。\n"
         @"        3. **【路径均衡扫描 (叙事化)】**: 详查三传的“出入”路径，并赋予其叙事意义：`自干传支` (“我求于彼”)、`自支传干` (“彼求于我”)、`自内传外` (“内部事务公开化”)、`自外传内` (“外部影响向内部渗透”)。\n"
         @"\n"
         @"*   **【公理 A-006：三传动力系统与纲领枢纽识别协议】**\n"
         @"    *   `权限`: 【事件核心动力与战略重心分析引擎】\n"
         @"    *   `公理陈述`: 三传是一个动力系统，其内部能量流的方向性，决定了整个事件的战略重心（纲领）。本协议旨在识别引擎类型，并锁定其【纲领枢纽点】，从而揭示事件的核心观察点与干预点。\n"
         @"    *   `执行心法`: **物理分顺逆，纲领有别裁。创造之机，其要在末；交换之术，其要在初。然三合为上，化局为尊，一体论之，无分首末。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        ### **第一步：【S++级 · 结构优先仲裁协议】**\n"
         @"        *   `指令`: 在进行任何动力学分析之前，必须首先对三传进行【最高结构模式】扫描。\n"
         @"        *   `IF` (三传构成 **【三合局】**):\n"
         @"            *   a. **【签发最高裁决】**: 立即将本次事件的【引擎类型】锁定为 **【转化引擎】**。\n"
         @"            *   b. **【赋予绝对优先权】**: 【三合局】的“**能量通过共振、聚合，发生质变，形成一个全新的、强大的合力**”的定性，拥有绝对的、不可置疑的优先解释权。\n"
         @"            *   c. **【逻辑降级】**: 任何其他并存的结构特征（如“逆生链”）的解释权，必须被强制降级为“**对转化过程的补充描述**”。例如，一个逆生的三合局，应被解读为：“**这是一个通过层层铺垫（逆生过程），最终达成了众志成城（三合结果）的成功故事**”，而非“这是一个付出代价的交换”。\n"
         @"            *   d. **【流程跳转】**: 锁定为【转化引擎】后，直接跳转至【第三步】，并将整个三合局视为一个不可分割的【**整体纲领**】进行分析。\n"
         @"\n"
         @"        ### **第二步：识别动力核心 (若未触发三合局)**\n"
         @"        *   `指令`: 分析三传的整体结构，确定本次事件的核心“引擎”类型。\n"
         @"        | 引擎类型 | 结构特征 | 核心机制 | **纲领方向** |\n"
         @"        | :--- | :--- | :--- | :--- |\n"
         @"        | **创造引擎** | 递生链：`A→生B→生C` | 能量沿单一方向增益、转化、创造新事物。 | **顺生** |\n"
         @"        | **冲突引擎** | 递克链：`A→克B→克C` | 能量通过连续的制约、冲突、解决问题来推动事态发展。 | *(视具体生克定)* |\n"
         @"        | **交换引擎** | 逆生链：`C→生B→生A`的反向过程 | 能量通过消耗一方（源）来生成另一方（结果），体现为一种“代价-收益”的交换。 | **逆生** |\n"
         @"\n"
         @"        ### **第三步：锁定【纲领枢纽点】或【整体纲领】**\n"
         @"        *   `指令`: 根据前序步骤的判定，锁定事件的核心。\n"
         @"        | 纲领方向/引擎 | **唯一【纲领枢纽点】/【整体纲领】** | 司法解释 |\n"
         @"        | :--- | :--- | :--- |\n"
         @"        | **顺生 (创造过程)** | **【末传】** | 末传是“春种秋收”的最终收成，是所有前期投入的结晶与真实成果。事件的最终价值与成色，由末传唯一决定。 |\n"
         @"        | **逆生 (交换过程)** | **【初传】** | 初传是“抵押贷款”中你最先拿到手的现金，是整个交换行为中最直接、最可见的收益。事件的即时效应与表象，由初传唯一决定。 |\n"
         @"        | **转化引擎 (三合局)** | **【三传整体】** | 三传作为一个不可分割的整体，其力量通过共振聚合，共同指向一个全新的、由所化五行定义的局面。事件的核心在于这个合力的形成与作用。|\n"
         @"        | **冲突引擎 (攻关过程)** | **【末传】** | 在“过关斩将”的剧本中，末传是最终攻下的“城池”，代表着整个战役的最终成果与定性。 |\n"
         @"\n"
         @"        ### **第四步：生成《三传动力系统与纲领报告》**\n"
         @"        *   `指令`: 报告必须围绕被锁定的纲领展开。\n"
         @"        *   `【报告模板】`:\n"
         @"            > **【三传动力系统与纲领报告】**\n"
         @"            > \n"
         @"            > 1.  **动力系统诊断**: 本次事件的内在运作机制被识别为一台 **【[引擎类型]】**。\n"
         @"            > 2.  **纲领锁定**: 根据其动力学特性，本次事件的纲领被锁定为 **【[初传/末传/三传整体]】** 之 **【[地支与象意]】**。\n"
         @"            > 3.  **战略机关揭示**:\n"
         @"            >     *   *(若为顺生)* -> “这是一个**以【初传】为起点，最终收获【末传】为纲领的创造过程**。”\n"
         @"            >     *   *(若为逆生)* -> “这是一个**以消耗【末传】为代价，换取【初传】为纲领的交换过程**。”\n"
         @"            >     *   *(若为三合局)* -> “这是一个**以【三传整体】为纲领的转化过程**。盘中各方力量最终将拧成一股绳，共同促成一个**【[所化五行]】**性质的全新局面。”\n"
         @"            >     *   *(若为冲突引擎)* -> “这是一个**以【初传】为起点，通过【中传】的攻坚克难，最终夺取【末传】为纲领的‘过关斩将’过程**。”\n"
         @"\n"
         @"*   **【公理 A-007：程序化救援原则 (壬归·极限净化原则)】**\n"
         @"    *   `权限`: 【最终吉凶仲裁器】\n"
         @"    *   `公理陈述`: 在对任何一个凶象下定论前，必须**严格按照《壬归》的“解救链条” (`行年 -> 末传 -> 中传 -> 用神 -> 日辰`) 进行程序化扫描**，并结合`M-003`“净实力评估”判断解救是否有效。\n"
         @"    *   `司法源头`: 《壬归·明三传始终第三》“凡用神，可解日辰上之兇；末传又解发用之兇；行年可解末传之兇。”\n"
         @"    *   `S+++级强制指令`: **当扫描到任何形式的“生助日干”关系时（尤其是末传生日干），应立即赋予其极高的“救援权重”，并将其作为定义事件最终性质的关键依据。**\n"
         @"    *   `胜利的代价条款`: 当救援符号本身在当前剧本中带有负面象意（据`A-002`，如解厄剧本中的`妻财`）时，系统必须将两者进行因果关联性整合输出。最终断语必须是：“**事件的[负面性质]最终能够得到解决（A-007定结果），而课盘清晰地指出了解决此事的方式是[负面象意所代表的代价]（A-002定过程），这是一个‘[例如：破财消灾]’的定局。**”\n"
         @"\n"
         @"*   **【公理 A-008：功能与角色融合协议】**\n"
         @"    *   `权限`: 【符号属性仲裁器】\n"
         @"    *   `公理陈述`: 当同一个地支同时具备【**功能属性**】（如`天乙贵人`、`日德`、`驿马`）与【**六亲属性**】（如`官鬼`、`妻财`）时，**其【功能属性】的解释权拥有最高优先级，并可重新定义其【六亲属性】在当前情境下的实际作用。**\n"
         @"    *   `执行指令 (叙事融合)`: 当一个符号的‘六亲角色’与‘功能角色’在当前剧本中性质相反时（如解厄剧本中的`官鬼`兼`天乙贵人`），严禁二选一，必须进行**叙事融合**。其最终解释为：**事件的【性质】由‘六亲角色’定义，而事件的最终【作用与转化方式】由‘功能角色’定义。**\n"
         @"    *   `判例`:\n"
         @"        *   `IF` (占官司，某爻为 `官鬼` + `天乙贵人`), `THEN` 必须解读为：“**这场官司（官鬼定义性质）的根源或核心，来自于一位有官方身份的关键人物（贵人）。虽然他/这件事的出现带来了压力和麻烦（官鬼之象），但他/它本身也正是解决问题的关键所在，是一个能最终带来解决方案的‘考验’。**”\n"
         @"\n"
         @"*   **【公理 A-009：目标导向与路径优先仲裁协议 (体用冲突终审)】**\n"
         @"    *   `权限`: 【六亲角色最终定义器 · 司法仲裁庭】\n"
         @"    *   `核心法则`: 当一个六亲爻的【固有生克属性】(如“子孙”天然克“官鬼”)与它在`A-002`中所被赋予的【情境角色】(如在谋望剧中扮演“福神/解决方案”)发生直接冲突时，本协议将被激活，作为唯一的、最终的仲裁者。\n"
         @"    *   `执行心法`: **先审其路径，再断其心性。能量是否直击目标，决定其为敌是友。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        1.  **【第一步：路径审查】**: 审查这个引发冲突的六亲爻（或其构成的格局）在三传的能量流中，是否【直接克制】了代表【核心目标】的类神或最终归宿（末传）。\n"
         @"        2.  **【第二步：目标审查】**: 审查这个六亲爻（或其构成的格局）的能量，最终是否导向了一个对求占者【有利的目标】。\n"
         @"        3.  **【第三步：签发终审判决】**:\n"
         @"            *   `IF` (路径审查显示【无直接克害】，且目标审查显示【导向有利目标】):\n"
         @"                *   **【签发最高裁决】**: 立即签发【**S+++级 · 情境角色优先裁决**】。宣告该六亲爻的【固有生克属性】在本案中被【司法性悬置】，其唯一合法的解释必须、且只能是`A-002`所赋予的【正面情境角色】。\n"
         @"                *   **【强制叙事转译 (范例)】**: “在本案中，‘子孙火局’的‘克官’属性被司法性悬置。其唯一合法身份是`A-002`定义的‘解决方案’与‘智慧’。整个事件的叙事必须被强制定义为：**求占者通过其超凡的智慧与方案（子孙火局），创造出了巨大的价值（生财），并最终获得了属于自己的禄位（禄神归末）。**”\n"
         @"            *   `ELSE` (路径审查显示【有直接克害】):\n"
         @"                *   维持其【固有生克属性】的解释，判定为凶。\n"
         @"\n"
         @"*   **【公理 A-010：双轨联动与主体安全否决协议】**\n"
         @"    *   `权限`: 【最终结论一票否决器】\n"
         @"    *   `公理陈述`: 任何“专问专事”占断，必须并行分析【宏观课传 (体)】与【微观类传 (用)】。\n"
         @"    *   `执行指令`:\n"
         @"        1.  **“主体安全否决权”**: 整合双轨结论前，必须先对**宏观课传**进行“主体安全扫描”。若宏观课传出现明确的、无解救的**“伤主”**信息（如全鬼克日、日干坐墓绝又被刑冲、年命被重克），宏观系统将行使**“一票否决权”**。最终断语必须是：“**此事虽有成功之象，然与你之命运根本相悖，强求之，必有大灾，得不偿失，切不可为！**”\n"
         @"        2.  **“联动生克评估”**: 分析微传时，必须检查其关键爻与**宏传**中的日干、年命的生克关系，以判断“事成”是否会“伤人”。\n"
         @"        3.  **整合裁决**: 在确保“主体安全”的前提下，**以“微观类传”的结论为内核定论**，以“宏观课传”的分析描述外部环境与过程。\n"
         @"\n"
         @"*   **【公理 A-011：终极应期裁决协议 (多维共振算法版)】**\n"
         @"    *   `引擎定位`: 本系统用于【事件发生时间（应期）】研判的唯一、最终决断模型。其核心算法是“多维信号加权与共振裁决”。\n"
         @"    *   `执行心法`: **应期非孤证，乃众缘之共振。先诊其势，再辨其锁，终审其钥。万法皆为候选，共振最强者为王。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        ### **第一步：宏观动力学修正与时态预判**\n"
         @"        *   `指令`: 在进行任何具体计算前，必须先设定全局基调与时间参照系。\n"
         @"        *   **1.1 宏观基调设定**:\n"
         @"            *   `操作`: 扫描全局课体格局（如`伏吟`、`返吟`、`八专`等）。\n"
         @"            *   `产出`: 根据格局特性，为后续所有应期信号预设【**基础权重修正系数**】。\n"
         @"                *   `伏吟`局 -> `冲`类信号权重 **x1.5**\n"
         @"                *   `返吟`局 -> `动`(驿马、冲)类信号权重 **x1.5**\n"
         @"                *   `八专`局 -> `合`类信号权重 **x1.5**\n"
         @"                *   `其他`局 -> 系数 **x1.0**\n"
         @"        *   **1.2 时态参照系预判 (过去 vs 未来)**:\n"
         @"            *   `司法源头`: 《玄女指掌赋》·“用在日前事情已过，用居日后事起将来。”\n"
         @"            *   `操作`: 对比【初传地支】与【日支】在地盘上的相对位置。\n"
         @"            *   `裁决`:\n"
         @"                *   若【用在日前】 -> 标记为【**已发生/收尾阶段**】，应期分析转向“此事发生于何时”或“何时收尾”。\n"
         @"                *   若【用在日后】 -> 标记为【**未来事件**】，应期分析按常规流程进行。\n"
         @"\n"
         @"        ### **第二步：全光谱应期信号矩阵采集与分级**\n"
         @"        *   `指令`: **必须、且只能**通过扫描并填充以下矩阵来完成数据采集。严禁遗漏任何一类信号。\n"
         @"        *   **【全光谱应期信号矩阵】**:\n"
         @"        | 逻辑类别 | 技法名称 | 提取对象 (地支) | 核心原理 | **权重级别** |\n"
         @"        | :--- | :--- | :--- | :--- | :--- |\n"
         @"        | **【Tier 1: 破局之钥】** | `墓库激活` | **冲开墓库**之地支 | 禁锢待开，钥匙即是时间。此为破局关键。 | **A+** |\n"
         @"        | **【Tier 1: 破局之钥】** | `空亡激活` | **冲/填空亡**之地支 | 条件未到，待时而发。空亡为延迟信号。 | **A+** |\n"
         @"        | **【Tier 1: 破局之钥】** | `年命激活` | **冲/合年命**之地支 | 个人命运与事件的共振点，力量强大。 | **A+** |\n"
         @"        | **【Tier 2: 剧情终点】** | `末传互动` | **冲/合末传**之地支 | 事之终局的触发条件。 | **A** |\n"
         @"        | **【Tier 2: 剧情终点】** | `末传本期` | 末传地支 | 事之终局，主慢。 | **A-** |\n"
         @"        | **【Tier 3: 剧情起点】** | `发用互动` | **冲/合初传**之地支 | 事之始动的触发条件。 | **B+** |\n"
         @"        | **【Tier 3: 剧情起点】** | `发用本期` | 初传地支 | 事之始动，主快。（逆生课权重提升至A-） | **B** |\n"
         @"        | **【Tier 4: 辅助信号】** | `实体显现` | 核心类神之地支 | 事物本体显现之时。 | **C+** |\n"
         @"        | **【Tier 4: 辅助信号】** | `实体终局` | 核心实体之**绝地** | 实体能量终结之时，如“鬼贼绝处讼了解”。 | **C** |\n"
         @"        | **【Tier 4: 辅助信号】** | `动能触发` | 驿马/天马/丁马之地支 | 物理行动的直接触发器。 | **C** |\n"
         @"\n"
         @"        ### **第三步：冠军指针筛选与共振算法裁决**\n"
         @"        *   `指令`:\n"
         @"            1.  **【筛选冠军候选池】**: 提取所有权重级别为 **A+** 和 **A** 的信号，形成【**冠军候选池**】。若池中无信号，则降级纳入 **A-** 级信号。\n"
         @"            2.  **【执行共振算法】**: 对【冠军候选池】中的每一个候选地支（设为 X），计算其【**共振分数**】。\n"
         @"                *   `计分规则`:\n"
         @"                    *   `IF` X `冲` 初/中/末传 `THEN` +3分\n"
         @"                    *   `IF` X `合` 初/中/末传 `THEN` +2分\n"
         @"                    *   `IF` X `刑` 初/中/末传 `THEN` +1分\n"
         @"                *   `操作`: 遍历三传，将候选地支X与初、中、末传的交互得分累加，得到其【**最终共振分数**】。\n"
         @"            3.  **【裁决冠军指针】**:\n"
         @"                *   【最终共振分数】最高者，即被锁定为【**唯一冠军指针**】。\n"
         @"                *   `IF` (出现多个分数相同的最高分): 启动【**多轨并行论证**】程序，报告中必须指出多个可能的应期节点，并分别解释其逻辑。\n"
         @"            4.  **【辅助参考】**: 提取`初传`到`末传`在地盘上的顺/逆地支数，作为长期应期的参考。\n"
         @"\n"
         @"        ### **第四步：生成整合输出报告**\n"
         @"        *   `指令`: 按照以下结构生成最终的应期分析报告。\n"
         @"        *   `【报告模板】`:\n"
         @"            *   **a. 宏观背景陈述**: \n"根据本课【[课格]】呈现的【[快/慢]】特性及【[时态]】预判，事件时间流向被定性为【[未来将启/延迟发生/业已完结]】。\n"\n"
         @"            *   **b. 冠军指针论证**: \n"经全光谱信号扫描与共振算法裁决，本案的【**冠军应期指针**】被锁定为【**[地支]**】，其共振分数为【[分数]】。其胜出的核心理由在于它与事件核心动态链（三传）产生了最强烈的共振效应：【**此处必须以‘讲故事’的方式，生动描述该地支是如何通过‘冲/合/刑’等动作，同时推动或解决了三传中的多个矛盾。例如：‘戌’之所以成为关键，是因为它如同钥匙，一方面‘卯戌合’（+2分）锁定了代表文书的末传，使其尘埃落定；另一方面‘辰戌冲’（+3分）打破了囚禁我方的中传墓库，使我方得以解脱。总分5分，其‘一合一冲’的组合拳，完美模拟了事件解决的现实过程，逻辑强度无可匹敌。’**】\n"\n"
         @"            *   **c. 其他候选分析**: \n"其他候选信号，如【[其他高分候选]】，虽也构成重要参考（共振分数【[分数]】），但在剧本中的角色更像是‘次要情节’，其共振强度和逻辑的根本性不及【冠军指针】。\n"\n"
         @"            *   **d. 最终结论**: \n"综上所述，事件的关键节点最可能在【[地支]】日/月/年（根据量级判断）发生。\n"\n"
         @"\n"
         @"*   **【公理 A-012：多轨多域定量分析协议】**\n"
         @"    *   `引擎定位`: 本系统的【专用数字引擎】，响应所有“定量”问题。其核心架构为【领域驱动、三轨并行、矩阵修正、情境收敛】。\n"
         @"    *   `执行心法`: **先定其域，再分其轨。以结构为骨，理气为魂，象数为神。三轨互证，矩阵精调，情境归真。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        *   **【第一步：定域与基调】**\n"
         @"            *   `指令`: 此为所有计算的前置过滤器，其决策将指导后续所有轨道的算法选择。\n"
         @"            *   **1.1 【定量域选择器】**: 必须首先根据占问性质，将问题强制归入以下某一“域”，并激活该域的专属规则集。\n"
         @"                *   `[价值域]`: 涉及金额、财富、价格等。算法倾向于乘法、加和，量级可变。\n"
         @"                *   `[年龄域]`: 涉及人或事物的存续时间。算法倾向于取单一稳定数，量级有现实上限（如120岁）。\n"
         @"                *   `[数量域]`: 涉及个数、件数、人数等。算法倾向于取整数，量级通常较小。\n"
         @"                *   `[时序域]`: 涉及“第几个”、“排第几”等。算法倾向于取地支序数或三合局序数。\n"
         @"            *   **1.2 【基调与量级预判】**: `CALL [M-003]`，综合审查核心类神的【净实力】与全局课格（如富贵/贫贱），对数值的【量级】（个/十/百/千…）和【基调】（取大/取小/取中）做出初步判决。此判决将用于【第四步】的最终仲裁。\n"
         @"\n"
         @"        *   **【第二步：三轨并行计算】**\n"
         @"            *   `指令`: 必须同时启动并完成以下三个独立的计算轨道，生成三组【候选骨架数】。\n"
         @"            *   `算法模块`:\n"
         @"                1.  **【定位核心对象】**: 锁定与定量问题最相关的核心实体（如求财看`妻财`或`青龙`，问年龄看`日干`或`本命`）。\n"
         @"                2.  **【判定旺衰状态】**: `CALL [M-003]`，获取核心对象的最终【净实力】评级（旺、相、休、囚、死）。此评级为三条轨道共享。\n"
         @"                ---\n"
         @"                ### **【计算轨道 A: 格局结构法】**\n"
         @"                *   `算法原理`: 数值根植于课盘最直观的结构与序数关系中，反映事物的“骨架”。\n"
         @"                1.  **【提取结构数池】**:\n"
         @"                    *   `五行数`: 提取核心对象之五行数 (水1, 火2, 木3, 金4, 土5)。*（注：此为五行次序数，非河洛数）*\n"
         @"                    *   `先天数`: 提取核心对象之天盘、地盘地支的先天数 (子午9, 丑未8, 寅申7, 卯酉6, 辰戌5, 巳亥4)。\n"
         @"                    *   `地支序数`: 提取核心对象之天盘地支的序数 (子1, 丑2 ... 亥12)。\n"
         @"                2.  **【域驱动算法选择】**:\n"
         @"                    *   **`[年龄域]/[数量域]`**: 优先从【结构数池】中选取与情境最匹配、最简洁的单一数字。例如，`五行数`或`先天数`的个位数。旺相时可考虑两数相加，休囚死则取其一。**严禁使用乘法。**\n"
         @"                    *   **`[价值域]`**: 可采用 `天盘先天数` × `地盘先天数` 的算法，以反映价值的复合增长。\n"
         @"                3.  **【输出骨架数A】**: 将计算结果作为【结构骨架数】。\n"
         @"\n"
         @"                ---\n"
         @"                ### **【计算轨道 B: 河洛理气法】**\n"
         @"                *   `算法原理`: 数值根植于事物五行能量（气）的生发与收藏之理，反映事物的“气数”与“成色”。\n"
         @"                1.  **【提取河洛数】**: 调用核心对象五行对应的河洛生成数 (水1,6; 火2,7; 木3,8; 金4,9; 土5,10)。\n"
         @"                2.  **【执行旺衰理气运算 (v2.0 修正版)】**:\n"
         @"                    *   **`旺`**: (生数 + 成数) × 2  (能量满溢，取其大和之倍)。\n"
         @"                    *   **`相`**: 生数 + 成数 (能量生发，取其和)。\n"
         @"                    *   **`休`**: 取 `成数` (能量休止，功成而藏)。\n"
         @"                    *   **`囚`**: 取 `生数` (能量被囚，仅存其根)。\n"
         @"                    *   **`死`**: 成数 ÷ 2 (能量消散，折半而论)。\n"
         @"                3.  **【S级·特殊情境覆写指令】**: `IF` 核心对象虽处休囚死地，但乘`青龙`、`天乙`等强力吉将，或构成`三合局`等旺格，`THEN` 其旺衰等级可被【司法性上调】一至二级进行计算。*（例如：`卯`木虽囚，但乘`青龙`，可按`休`气取`成数`8）*\n"
         @"                4.  **【输出骨架数B】**: 将计算结果作为【理气骨架数】。\n"
         @"\n"
         @"                ---\n"
         @"                ### **【计算轨道 C: 神煞象数法】**\n"
         @"                *   `算法原理`: 数值直接由课盘中具有象征意义的特定符号（神煞、格局）给出，是“神”的直接启示。\n"
         @"                1.  **【扫描象数符号】**: 扫描全盘，提取与核心对象关联的、具有数字含义的符号。\n"
         @"                2.  **【象数符号解码库】**:\n"
         @"                    *   `返吟/伏吟`: 主数 **2**，或事物重复。\n"
         @"                    *   `三合局`: 主数 **3**，或三方力量。\n"
         @"                    *   `六合`: 主数 **6** (或 **2**，代表双方)。\n"
         @"                    *   `遥克/昴星`: 主数 **4** (代表四课)。\n"
         @"                    *   `八专`: 主数 **8**。\n"
         @"                    *   `日干/支遁干`: 提取遁干对应的五行数或先天数。\n"
         @"                    *   `天将`: 某些天将自带数理，如`六合`，或可取其五行数。\n"
         @"                3.  **【输出骨架数C】**: 将解码出的数字作为【象数骨架数】。\n"
         @"\n"
         @"        *   **【第三步：复合修正与收敛仲裁】**\n"
         @"            *   `指令`: 对三轨得出的骨架数进行精加工，并选出最终冠军。\n"
         @"            *   **3.1 【复合修正矩阵】**: 将三组骨架数分别通过此矩阵进行微调。\n"
         @"        | 修正维度 | 增益因子 (乘系数 > 1 或 +) | 减益因子 (乘系数 < 1 或 -) |\n"
         @"        | :--- | :--- | :--- |\n"
         @"        | **天将** | `青龙`, `天乙`, `太常` (主富贵、增益) | `玄武`, `天空`, `白虎`(乘脱气) (主耗散、虚假、损失) |\n"
         @"        | **神煞** | `日禄`, `天财`, `福星` | `大耗`, `破碎`, `劫煞` |\n"
         @"        | **格局** | `富贵课`, `龙德课` | `贫贱课`, `无禄绝嗣` |\n"
         @"            *   **3.2 【收敛仲裁】**:\n"
         @"                *   **`IF` (三轨结果高度收敛或互证)**: `THEN` 冠军数确立，可信度极高。取其交集或均值。\n"
         @"                *   **`IF` (两轨收敛，一轨发散)**: `THEN` 以收敛的两轨结果为准，发散的结果作为“补充信息”或“潜在可能性”。\n"
         @"                *   **`IF` (三轨完全发散)**: `THEN` 标志着此事数量层面“表里不一、极不稳定、或有多重含义”。此时，**返回【第一步】，重新审视【基调与量级】，并以与基调最匹配的那个轨道的数作为主判断**，其他数作为次要可能。\n"
         @"\n"
         @"        *   **【第四步：情境合理性终审 】**\n"
         @"            *   `指令`: 对仲裁出的冠军数进行最终的“常识”检验。\n"
         @"            *   `操作`: 检查数字是否符合【第一步】所选“域”的现实逻辑。例如，`[年龄域]`的数字不得超过120，`[数量域]`的数字应为整数。若不符，则退回【第三步】选择次优候选数。\n"
         @"\n"
         @"        *   **【第五步：生成整合输出报告】**\n"
         @"            *   `指令`: 报告必须清晰展示整个推演过程，以体现其逻辑的严谨性。\n"
         @"            *   `【报告模板】`:\n"
         @"                > \n"关于数值的判断，本次分析已进入【[定量域]】，核心计算对象为【[对象名称]】，其净实力被评定为【[旺衰]】，基调为【[取大/小/中]】。本系统启动了三轨定量分析：\n"
         @"                > 1.  **结构轨道 (A)**：基于其【[五行数/先天数等]】结构，得出骨架数为 **【[结果A]】**。此数反映了事物的'骨架'。\n"
         @"                > 2.  **理气轨道 (B)**：基于其五行【[五行]】与河洛理气【[生数,成数]】，并结合【[特殊情境覆写，如'乘青龙']】修正，计算得出骨架数为 **【[结果B]】**。此数反映了事物的'气数'。\n"
         @"                > 3.  **象数轨道 (C)**：基于盘中【[返吟/三合等]】符号，解码得出骨架数为 **【[结果C]】**。此数反映了'神'的启示。\n"
         @"                > \n"
         @"                > **【仲裁与结论】**：三轨道数值【高度收敛/部分发散】。经过【[天将/神煞]】的复合修正与情境合理性终审，最终裁定此事的关联数值为 **【[最终数值或范围]】**。其推导过程主要依据【[轨道B与轨道A的互证]】，而【[轨道C]】的结果则揭示了【[补充含义]】。\n"\n"
         @"\n"
         @"*   **【公理 A-013：象意选择的“角色优先”裁决协议】**\n"
         @"    *   `权限`: 【符号定性终审器】\n"
         @"    *   `核心法则`: “一个符号（尤其是天将）在理论上可以拥有多种象意，但在具体课盘中，它只能扮演**一个核心角色**。这个角色的性质，必须由它所依附的**六亲**和所在的**剧本（谋望/解厄）**来优先定义。”\n"
         @"    *   `执行心法`: **将为体，亲为用。以用驭体，以境炼神。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        1.  **【角色定位】**: 在解读一个天将的象意前，必须先确认它所乘地支的【六亲属性】以及全局的【剧本类型】（据`A-002`）。\n"
         @"        2.  **【象意筛选】**: 从该天将的理论象意库中，筛选出与该【六亲角色】最相关、最匹配的象意作为【第一象意】。\n"
         @"        3.  **【签发裁决】**:\n"
         @"            *   *判例1 (玄武)*: 占财（谋望剧本），`玄武`乘`妻财`爻。玄武理论象意有“盗贼、暗昧、技巧、智慧”。因其角色是`妻财`，应优先选择与财富获取方式相关的象意，故裁决为“**一笔通过非正常渠道、暗中操作或运用特殊技巧获得的财**”，而非简单断为“失财”。\n"
         @"            *   *判例2 (白虎)*: 占病（解厄剧本），`白虎`乘`官鬼`爻。白虎理论象意有“道路、权力、威严、病丧、血光”。因其角色是`官鬼`（灾祸），应优先选择与灾病相关的象意，故裁决为“**与血光、手术或严重病痛相关的灾厄**”，而非“道路上的权力”。\n"
         @"            *   *判例3 (青龙)*: 占官司（解厄剧本），`青龙`乘`官鬼`爻。青龙理论象意有“财富、喜庆、高贵、酒食”。因其角色是`官鬼`（灾祸），此时青龙的正面象意被悬置，转化为描述灾祸的来源或性质，故裁决为“**这场官司是由财富纠纷、喜庆之事（如婚宴）或与高贵人物的交往所引发的**”，而非“吉利的官司”。\n"
         @"\n"
         @"*   **【公理 A-014：神煞层级与权重分配协议】**\n"
         @"    *   `权限`: 【神煞影响力评估器】\n"
         @"    *   `公理陈述`: “盘中神煞繁多，其影响力并非均等。必须按照其【功能性】和【稀缺性】进行层级划分，给予不同权重，以抓住分析的主次矛盾。”\n"
         @"    *   `【神煞层级与权重清单】`:\n"
         @"        1.  **【S级 · 格局定义层】**: 能直接定义课体性质或核心状态的神煞。\n"
         @"            *   `清单`: **德神** (`日德`、`月德`)、**禄神** (`日禄`)、**驿马** (`天马`、`丁马`)、**华盖**、**将星**、**桃花/咸池**。\n"
         @"            *   `执行指令`: 一旦扫描到S级神煞出现在四课三传中，必须将其作为定义该爻位乃至整个事件【核心性质】的**首要标签**。\n"
         @"        2.  **【A级 · 状态强化层】**: 强化或修饰事件/角色状态的神煞。\n"
         @"            *   `清单`: **天喜**、**解神**、**天医**（吉）；**官符**、**病符**、**大耗**、**破碎**（凶）。\n"
         @"            *   `执行指令`: 这些神煞用于为S级标签或核心六亲角色添加“**正面/负面 Buff**”，描述事件的顺利程度或困难程度。\n"
         @"        3.  **【B级 · 细节补充层】**: 提供额外细节或背景信息的神煞。\n"
         @"            *   `清单`: 天财、天盗、飞廉、丧门、吊客等。\n"
         @"            *   `执行指令`: 仅在完成S级和A级分析后，用此类神煞来丰富叙事细节，严禁作为核心判断依据。\n"
         @"\n"
         @"*   **【公理 A-015：课传时序与因果链构建协议】**\n"
         @"    *   `权限`: 【因果逻辑引擎】\n"
         @"    *   `公理陈述`: “任何课盘都是一个包含‘过去、现在、未来’完整时间链的因果故事。分析必须揭示这条链条，而不能仅仅停留在对当下状态的描述。”\n"
         @"    *   `执行心法`: **以年命为宿因，以四课为现缘，以三传为业果。**\n"
         @"    *   `【强制执行流程】`:\n"
         @"        1. **【探寻宿因 (过去)】**:\n"
         @"            *   `操作`: 重点分析**日干、本命、行年**所落宫位，及其与课传的刑冲合害关系。\n"
         @"            *   `叙事转译`: 这部分代表了求占者与生俱来的【**禀赋、长期存在的问题根源、或命中注定的缘分**】。它是整个故事的“**前情提要**”。\n"
         @"        2. **【聚焦现缘 (现在)】**:\n"
         @"            *   `操作`: 重点分析**四课**的结构。\n"
         @"            *   `叙事转译`: 这部分代表了事件【**当下的状态、人际关系的快照、以及各方的心态与策略**】。它是故事“**正在发生**”的主体部分。\n"
         @"        3. **【推演业果 (未来)】**:\n"
         @"            *   `操作`: 重点分析**三传**的流转。\n"
         @"            *   `叙事转译`: 这部分代表了事件的【**发展趋势、关键转折点、以及最终的结局**】。它是故事的“**未来走向**”。\n"
         @"        4. **【构建因果报告】**: 最终的分析报告，必须有意识地按照“**因为[过去的宿因]，导致了[现在的局面]，并将通过[未来的演化]，最终达到[结局]**”的因果逻辑链来组织叙事，从而提供一个更具深度和指导性的全景洞察。\n"
         @"\n"
         @"*   **【公理 A-016：交互动力学协议】**\n"
         @"\n"
         @"    *   `权限`: 【关系剧本生成器 & 动态过程解码器】\n"
         @"    *   `协议定位`: 本协议旨在深度解码课盘中核心的“交互关系”（生、克、合、冲、刑、害、破），将其从静态的吉凶标签转译为动态的、充满张力的“**互动剧本**”。它是【创境】引擎描绘事件过程、人物互动和矛盾演变的核心工具。\n"
         @"    *   `执行心法`: **关系非吉凶，乃剧情之引擎。合为绑定，冲为激变，刑为纠葛，害为暗算。以生化解，以克制衡。观其所用，知其所为。**\n"
         @"    *   `【强制执行流程】`: 当分析到任何关键爻位（如日辰、年命、三传、类神）之间存在以下交互关系时，必须激活对应的子协议进行深度叙事转译。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.1: 【生】**\n"
         @"    *   **核心剧本**: **“滋养与创造”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 生助、给予、支持、创造、孵化、培养、庇护、源头。\n"
         @"        *   **动态过程**: 描述一个能量从“父母方”流向“子孙方”的过程。这是一条顺畅的、建设性的能量通道。\n"
         @"        *   **吉占 (谋望)**: 代表获得资源、得到支持、创意产生、事情顺利发展。*（例：`父母`生`日干` -> 得到长辈或官方的庇护与支持。）*\n"
         @"        *   **凶占 (解厄)**: 代表“**化敌为友**”或“**转化矛盾**”。*（例：`官鬼`生`父母`，`父母`又生`日干`，形成“通关”。剧本为：“虽然官方（官鬼）带来了压力，但通过文书/规则（父母）的运作，这种压力最终转化为了对我的支持。”）*\n"
         @"    *   **风险提示**:\n"
         @"        *   `生之太过`: “**溺爱与依赖**”。若生助方过多过旺，而被生方休囚无力，形成“母旺子衰”，主过度的庇护导致当事方失去独立性，或被过多的信息/资源所淹没。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.2: 【克】**\n"
         @"    *   **核心剧本**: **“征服与制约”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 控制、管理、克服、战胜、压力、限制、冲突、变革。\n"
         @"        *   **动态过程**: 描述一个“征服方”对“被征服方”施加影响和控制的过程。这是一条充满张力、旨在建立新秩序的能量通道。\n"
         @"        *   **吉占 (谋望)**: 代表克服困难、获取权力、达成目标。*（例：`日干`克`妻财` -> 我有能力去获取和掌控财富。）*\n"
         @"        *   **凶占 (解厄)**: 代表“**以强制强，消除病灶**”。*（例：`子孙`克`官鬼` -> 动用智慧或力量（子孙）去战胜疾病或官非（官鬼）。）*\n"
         @"    *   **风险提示**:\n"
         @"        *   `克之太过`: “**压迫与崩溃**”。若克制方过多过旺，而被克方毫无生机，主过度的压力导致崩溃、关系破裂或事物损毁。\n"
         @"        *   `反克 (被侮)`: “**以下犯上**”。若被克方反而旺相，克制方休囚，主反被其辱，试图控制反被控制。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.3: 【合】**\n"
         @"    *   **核心剧本**: **“联盟与绑定”** (包括三合、六合)\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 合作、结合、绑定、约定、和谐、吸引、拖延、羁绊。\n"
         @"        *   **动态过程**: 描述两个或多个实体形成一个利益/情感共同体的过程。能量被“锁定”在一个稳定的结构中。\n"
         @"        *   **吉占 (谋望)**: 代表合作成功、关系确立、事情顺利、得到承诺。*（例：`日干`与`财爻`六合 -> 我与财富/伴侣紧密绑定，唾手可得。）*\n"
         @"        *   **凶占 (解厄)**: 代表“**被问题缠住，难以脱身**”。*（例：`日干`与`官鬼`六合 -> 我被官司或疾病缠身，无法摆脱。）*\n"
         @"    *   **策略指引**: 遇吉事之合，应**顺势而为，促成合作**。遇凶事之合，需寻`冲`神来**打破僵局，解开绑定**。\n"
         @"    *   **风险提示**:\n"
         @"        *   `合中带克/害/破`: “**蜜里藏砒**”。表面和谐的合作关系中，隐藏着背叛、伤害或利益冲突。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.4: 【冲】**\n"
         @"    *   **核心剧本**: **“激变与重组”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 冲突、碰撞、分离、变革、激活、快速、打破、公开。\n"
         @"        *   **动态过程**: 描述一个剧烈的、颠覆性的能量冲击过程，旨在打破旧有平衡，建立新局面。\n"
         @"        *   **吉占 (谋望)**:\n"
         @"            *   冲开`墓库` -> **【开启宝藏驱动】**。主机遇被激活，潜力被释放。\n"
         @"            *   冲开`空亡` -> **【激活机遇驱动】】**。主虚幻之事转为现实。\n"
         @"            *   冲动`驿马` -> **【快速启动驱动】】**。主事情进展神速。\n"
         @"        *   **凶占 (解厄)**:\n"
         @"            *   冲散`凶神` -> **【驱散阴霾驱动】**。主灾祸、小人被冲走，危机解除。\n"
         @"            *   冲开`合局` -> **【解脱束缚驱动】】**。主从不利的合作或纠缠中解脱出来。\n"
         @"    *   **策略指引**: 遇有利之冲，应**抓住变革时机，果断行动**。遇不利之冲，应**避其锋芒，稳固根基**。\n"
         @"    *   **风险提示**:\n"
         @"        *   冲散`吉神`或`财物` -> “**好事告吹**”。主即将到手的利益或好事被突发事件冲散。\n"
         @"        *   冲动`日干`或`年命` -> “**根基动摇**”。主自身状态不稳定，或生活环境发生剧变。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.5: 【刑】**\n"
         @"    *   **核心剧本**: **“纠葛与整肃”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 纠缠、摩擦、矛盾、伤害、手术、刑罚、整顿、强制性的调整。\n"
         @"        *   **动态过程**: 描述一个复杂、充满矛盾的交互过程，常伴有痛苦，但旨在解决深层问题或进行内部清理。\n"
         @"        *   **无恩之刑 (寅巳申)**: 主**忘恩负义、内部背叛、过河拆桥**的剧本。\n"
         @"        *   **恃势之刑 (丑戌未)**: 主**仗势欺人、内部权力斗争、恃强凌弱**的剧本。\n"
         @"        *   **无礼之刑 (子卯)**: 主**不合伦理、缺乏尊重、上下级/长晚辈关系失序**的剧本。\n"
         @"        *   **自刑 (辰午酉亥)**: 主**自我矛盾、内心纠结、作茧自缚、过度思虑**的剧本。\n"
         @"    *   **策略指引**: 遇刑，主事态复杂，需**快刀斩乱麻，有壮士断腕的决心**，拖延则纠缠更深。\n"
         @"    *   **风险提示**: 占病遇刑，多主**手术开刀**。占官司遇刑，多主**牢狱刑罚**。占关系遇刑，主**互相折磨**。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.6: 【害】**\n"
         @"    *   **核心剧本**: **“暗算与侵蚀”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 暗中伤害、小人作祟、嫉妒、破坏、挑拨离间、侵蚀、功能失调。\n"
         @"        *   **动态过程**: 描述一种隐蔽的、不易察觉的破坏性力量。它不像“冲”那样激烈，但如同水滴石穿，持续造成损害。\n"
         @"        *   **吉占 (谋望)**: 课传见害，主**成功之路上有小人觊觎，或成果有瑕疵**。\n"
         @"        *   **凶占 (解厄)**: `官鬼`爻逢害，主**灾祸的根基不稳，内部存在瓦解的可能**。\n"
         @"    *   **策略指引**: 遇害，需**提高警惕，谨防身边的小人，仔细审查细节，防止内部出问题**。\n"
         @"    *   **风险提示**: 害的作用是“穿心”，直接攻击事物的核心。占合作遇害，防**核心利益被侵占**。占健康遇害，防**核心脏腑功能失调**。\n"
         @"\n"
         @"    ---\n"
         @"    **子协议 16.7: 【破】**\n"
         @"    *   **核心剧本**: **“破裂与消耗”**\n"
         @"    *   **叙事转译**:\n"
         @"        *   **基本象意**: 关系破裂、财物破耗、计划破产、互相消耗。\n"
         @"        *   **动态过程**: 描述一种互相消耗、两败俱伤的能量互动。\n"
         @"        *   **吉凶判断**: 破的作用力较弱，通常作为辅助判断。若课传中已有刑冲克等强力破坏信号，再见破，则加剧其破坏程度。若课传一派祥和，见破，则为“美中不足”，略有瑕疵。\n"
         @"    *   **策略指引**: 遇破，主有小的损耗，应**及时止损，避免投入更多资源**。\n"
         @"    \n"
         @"## **第三部分：知识库**\n"
         @"\n"
         @"### 【知识库S-Net: 象意神经网络】\n"
         @"\n"
         @"#### **【S-Net-L1: 天将A轨与临宫状态知识库】**\n"
         @"---\n"
         @"##### **【融合分子#C-01: 天乙贵人 (己丑土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**志同道合的、更高层次的引导者**。\n"
         @"    *   **动机**: 真心帮助你，通过**规范你的行为**，让你走在“正轨”上。\n"
         @"    *   **职能**: **审察与判决**。代表一切维持秩序、评判优劣的权威角色。\n"
         @"    *   **直断映射**: 考官、领导、上级、规则制定者。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 沐浴 (**直断**: 贵人有私心，或此事不纯粹，难成)。\n"
         @"    *   `临丑`: 升堂 (**直断**: 贵人在位，得地有力，大吉)。\n"
         @"    *   `临寅`: 按籍 (**直断**: 涉及官方程序、公门之事)。\n"
         @"    *   `临卯`: 荷枷 (**直断**: 贵人自身受缚，或求贵反遭束缚)。\n"
         @"    *   `临辰`: 入狱 (**直断**: 求贵必受辱，或贵人身陷囹圄)。\n"
         @"    *   `临巳`: 趋朝 (**直断**: 有晋升、面见更高层级的希望)。\n"
         @"    *   `临午`: 御轩 (**直断**: 有官方的任命或好消息传来)。\n"
         @"    *   `临未`: 饮食 (**直断**: 能得到一些实际的小恩惠、好处或宴请)。\n"
         @"    *   `临申`: 起途 (**直断**: 贵人将要行动，或此事将有进展、变动)。\n"
         @"    *   `临酉`: 入室 (**直断**: 事情转入私下、暗中操作，不明朗)。\n"
         @"    *   `临戌`: 在囚 (**直断**: 贵人被困，或所求之事陷入僵局)。\n"
         @"    *   `临亥`: 操笏 (**直断**: 利于求见上级，汇报工作)。\n"
         @"---\n"
         @"##### **【融合分子#C-02: 螣蛇 (丁巳火)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**精神不正、爱看热闹的麻烦制造者**。\n"
         @"    *   **动机**: 享受旁观他人“愤怒、恐惧却又无能为力”的窘境。\n"
         @"    *   **职能**: 触发**认知以外的恶性事件**，让人陷入“惊、慌、恐、怖”的心理状态。\n"
         @"    *   **直断映射**: 神经病、行为怪异的人、无法理解的突发状况、缠绕不休的麻烦。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 堕水 (**直断**: 惊恐无力，虚惊一场，不成灾害)。\n"
         @"    *   `临丑`: 入穴 (**直断**: 麻烦自行消散或暂时平息)。\n"
         @"    *   `临寅`: 生角 (**直断**: 事情正在变异，吉凶看旺衰)。\n"
         @"    *   `临卯`: 当门 (**直断**: 麻烦找上门，易有口舌或人身伤害)。\n"
         @"    *   `临辰`: 自蟠 (**直断**: 麻烦盘踞不动，可远观不可近玩)。\n"
         @"    *   `临巳`: 飞天 (**直断**: 怪异之事显现，能量最强，若为吉事则大利)。\n"
         @"    *   `临午`: 乘雾 (**直断**: 想搞事，但前景不明，虚惊怪异)。\n"
         @"    *   `临未`: 秘隐 (**直断**: 麻烦暂时隐藏，并未解决)。\n"
         @"    *   `临申`: 衔刀 (**直断**: 必有凶险的官非或冲突)。\n"
         @"    *   `临酉`: 露齿 (**直断**: 必有口舌争吵)。\n"
         @"    *   `临戌`: 睡眠 (**直断**: 麻烦暂时平息，不动)。\n"
         @"    *   `临亥`: 入水 (**直断**: 惊恐无力，虚惊一场，不成灾害)。\n"
         @"---\n"
         @"##### **【融合分子#C-03: 朱雀 (丙午火)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**信息公开化的催化剂**。\n"
         @"    *   **动机**: 让隐藏的事实浮出水面，让不透明的状况变得清晰。\n"
         @"    *   **职能**: **官宣**。无论是白纸黑字的文书，还是对簿公堂的官司，都是将信息公开化的过程。\n"
         @"    *   **直断映射**: 文书、合同、官司、出名、信息、消息、媒体。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 损翼 (**直断**: 信息受阻、失真，或灾忧自行消退)。\n"
         @"    *   `临丑`: 掩目 (**直断**: 信息被困，渠道不通)。\n"
         @"    *   `临寅`: 安巢 (**直断**: 信息安稳，或因信息之事而暂缓行动)。\n"
         @"    *   `临卯`: 栖林 (**直断**: 信息安稳，或因信息之事而暂缓行动)。\n"
         @"    *   `临辰`: 投网 (**直断**: 因文书官司之事陷入圈套)。\n"
         @"    *   `临巳`: 翱翔 (**直断**: 信息远播，利于外部事务)。\n"
         @"    *   `临午`: 衔符 (**直断**: 文书、口舌之事必然发生)。\n"
         @"    *   `临未`: 啄食 (**直断**: 通过文书、信息求财有利)。\n"
         @"    *   `临申`: 励嘴 (**直断**: 正在准备打官司或激烈的辩论)。\n"
         @"    *   `临酉`: 嘿然 (**直断**: 信息中断，缄默无声)。\n"
         @"    *   `临戌`: 无毛 (**直断**: 文书有损，信息不全)。\n"
         @"    *   `临亥`: 沐浴 (**直断**: 信息失真，或因口舌招致麻烦)。\n"
         @"---\n"
         @"##### **【融合分子#C-04: 六合 (乙卯木)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**社交活动家和交易撮合者**。\n"
         @"    *   **动机**: 喜欢把人“呼唤”到一起，促进信息和利益的交换。\n"
         @"    *   **职能**: **中介与沟通**。主呼唤、婚姻说合、市场交易。\n"
         @"    *   **直断映射**: 中间人、媒婆、合作、谈判、聚会、信息交流。\n"
         @"    *   **关键修正**: 凶时（尤其卯木克土），可直断**被官方传唤、讯问**。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 裸形 (**直断**: 私密合作关系暴露，不利)。\n"
         @"    *   `临丑`: 眼疾 (**直断**: 合作有瑕疵、有问题)。\n"
         @"    *   `临寅`: 乘轩 (**直断**: 有婚姻喜庆之事)。\n"
         @"    *   `临卯`: 入户 (**直断**: 内部合作，或在家不动)。\n"
         @"    *   `临辰`: 受辱 (**直断**: 合作导致受辱或损失)。\n"
         @"    *   `临巳`: 失伴 (**直断**: 合作关系破裂，失去伙伴)。\n"
         @"    *   `临午`: 分索 (**直断**: 合作双方离心离德，各奔东西)。\n"
         @"    *   `临未`: 素服 (**直断**: 合作之事带有忧愁、不顺)。\n"
         @"    *   `临申`: 披发 (**直断**: 合作可成，但过程可能有些波折)。\n"
         @"    *   `临酉`: 折节 (**直断**: 为合作而委曲求全，有损尊严)。\n"
         @"    *   `临戌`: 入墓 (**直断**: 合作陷入停滞，毫无生机)。\n"
         @"    *   `临亥`: 乘辂 (**直断**: 利于出行办事、促成合作)。\n"
         @"---\n"
         @"##### **【融合分子#C-05: 勾陈 (戊辰土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**严于律人、宽于律己的“双标”执法者**。\n"
         @"    *   **动机**: 感觉人人都亏欠他，一旦抓住别人的“小辫子”或得到一点好处，便会纠缠不放，不断加码索取，最终引发冲突。\n"
         @"    *   **职能**: **强制执行与迟滞**。代表警察、执法。其核心特质是“纠缠”，因此当勾陈出现时，事情必然会被拖延、迟滞。\n"
         @"    *   **直断映射**: 警察、官司、做好事反被讹上、事情拖延、顽固的对手。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 临庭 (**直断**: 官司临门)。\n"
         @"    *   `临丑`: 执俘 (**直断**: 在争斗中得利，掌控局面)。\n"
         @"    *   `临寅`: 受制 (**直断**: 官方力量被压制，事情暂缓)。\n"
         @"    *   `临卯`: 入狱 (**直断**: 官非或田宅之事受困)。\n"
         @"    *   `临辰`: 千户 (**直断**: 官司、田产之事随之而动，纠缠不休)。\n"
         @"    *   `临巳`: 捧印 (**直断**: 有职位变动、晋升之象)。\n"
         @"    *   `临午`: 反目 (**直断**: 事情乖张，必有争斗)。\n"
         @"    *   `临未`: 入驿 (**直断**: 官方或田宅之事开始启动、变动)。\n"
         @"    *   `临申`: 操戈 (**直断**: 准备战斗，冲突一触即发)。\n"
         @"    *   `临酉`: 病足 (**直断**: 行动受阻，事情停滞)。\n"
         @"    *   `临戌`: 佩剑 (**直断**: 必有武力争端或伤害事件)。\n"
         @"    *   `临亥`: 濯衣 (**直断**: 事情有改革、变动之机)。\n"
         @"---\n"
         @"##### **【融合分子#C-06: 青龙 (甲寅木)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**胸怀大志、追求卓越的“大格局”玩家**。\n"
         @"    *   **动机**: 要么不做，要做就做大的。不满足于小打小闹，一心想经营大事、赚取超额回报。\n"
         @"    *   **职能**: **增福与驱动**。是赐予“超出预期”的财喜吉庆之神，也是驱使人挑战更大目标的内在动力。\n"
         @"    *   **直断映射**: 大笔钱财、重大喜事、高级别的合作、雄心壮志。入课即提示需关注财运的宏观走向。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 游海 (**直断**: 财物远行，不稳定，资金外流)。\n"
         @"    *   `临丑`: 蟠泥 (**直断**: 财物受困，资金链迟滞)。\n"
         @"    *   `临寅`: 乘云 (**直断**: 得势亨通，财官两利)。\n"
         @"    *   `临卯`: 戏珠 (**直断**: 喜庆之事，必得财物)。\n"
         @"    *   `临辰`: 戏水 (**直断**: 财运亨通，得心应手)。\n"
         @"    *   `临巳`: 飞天 (**直断**: 大利行动，财运高涨，格局打开)。\n"
         @"    *   `临午`: 无尾 (**直断**: 事情有始无终，财物损伤)。\n"
         @"    *   `临未`: 折角 (**直断**: 因争斗而损财)。\n"
         @"    *   `临申`: 无鳞 (**直断**: 财力受损，久困之象)。\n"
         @"    *   `临酉`: 伏陆 (**直断**: 退守之象，财不动，投资保守)。\n"
         @"    *   `临戌`: 施雨 (**直断**: 主动花费、投资或出财)。\n"
         @"    *   `临亥`: 入水 (**直断**: 求财可得，资源落地)。\n"
         @"---\n"
         @"##### **【融合分子#C-07: 天空 (戊戌土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**头脑空空、绝对服从的“忠诚执行者”**。\n"
         @"    *   **动机**: 自身没有欲望和想法，唯一的目标就是执行天乙贵人的命令。\n"
         @"    *   **职能**: **契约与服从**。其核心在于代表具有“约束力”和“需要服从”的合同、文件、约定。\n"
         @"    *   **直断映射**: 合同、协议、规章制度、承诺。若非文件，则次取欺诈、谎言之象。也代表僧道等无欲之人。\n"
         @"    *   **关键修正**: 优先考虑“文件契约”，而不是“骗子”。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 落井 (**直断**: 因虚假之事陷入圈套)。\n"
         @"    *   `临丑`: 伏尸 (**直断**: 有隐藏的旧事或隐患，多为虚假之事)。\n"
         @"    *   `临寅`: 犯事 (**直断**: 因虚假之事引发争讼口舌)。\n"
         @"    *   `临卯`: 守制 (**直断**: 虚假的言辞或承诺)。\n"
         @"    *   `临辰`: 虚诈 (**直断**: 明显的欺骗行为)。\n"
         @"    *   `临巳`: 仰视 (**直断**: 希望落空，所求虚幻)。\n"
         @"    *   `临午`: 入化 (**直断**: 小事吉，虚浮之事向好转化)。\n"
         @"    *   `临未`: 施空 (**直断**: 给予了没有实际价值的东西，画大饼)。\n"
         @"    *   `临申`: 鼓舌 (**直断**: 涉及虚假的词讼或辩论)。\n"
         @"    *   `临酉`: 衔印 (**直断**: 虚假的权柄或承诺)。\n"
         @"    *   `临戌`: 伏戸 (**直断**: 隐藏的欺骗，阴谋诡计)。\n"
         @"    *   `临亥`: 儒冠 (**直断**: 小事，但利于寻回遗失之物，因其空而能容)。\n"
         @"---\n"
         @"##### **【融合分子#C-08: 白虎 (庚申金)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**毫无感情、只认事实的“冷面终结者”**。\n"
         @"    *   **动机**: 如实传达和执行信息，不留情面地让当事人以肉体凡胎直面最真实的后果。\n"
         @"    *   **职能**: **物理层面的执行与裁决**。首主交通、道路等物理位移；次主联系、联络；凶时主审判、拒绝、不予通过。\n"
         @"    *   **直断映射**: 道路、车辆、信息传递、拒绝、手术、西医、法律判决。\n"
         @"    *   **关键修正**: **严禁滥用“血光之灾”**。只有在克伤`甲乙卯`木或被`丙丁巳午`火克时，才优先考虑疾病、血光。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 沉海 (**直断**: 内心恐惧，但无实质性大害)。\n"
         @"    *   `临丑`: 哮吼 (**直断**: 威胁升级，凶事将至)。\n"
         @"    *   `临寅`: 出林 (**直断**: 在道路上，有动态，可能伴随伤害)。\n"
         @"    *   `临卯`: 伏穴 (**直断**: 事情停滞不动，占病则病不起)。\n"
         @"    *   `临辰`: 露牙 (**直断**: 威胁显现，凶机已露)。\n"
         @"    *   `临巳`: 烧身 (**直断**: 主死丧、疾病等凶事)。\n"
         @"    *   `临午`: 入炉 (**直断**: 受制于人，灾祸难逃)。\n"
         @"    *   `临未`: 登山 (**直断**: 获得权势，但若占官司牢狱则大凶)。\n"
         @"    *   `临申`: 衔牒 (**直断**: 道路信息通畅，或有官方文书传来)。\n"
         @"    *   `临酉`: 当路 (**直断**: 构成直接威胁，有伤人之意)。\n"
         @"    *   `临戌`: 闭目 (**直断**: 威胁消除或暂时无害)。\n"
         @"    *   `临亥`: 睡眠 (**直断**: 威胁消除或暂时无害)。\n"
         @"---\n"
         @"##### **【融合分子#C-09: 太常 (己未土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**注重礼仪、讲究规矩的“仪式官”**。\n"
         @"    *   **动机**: 强调品级、礼教和形式上的正当性。\n"
         @"    *   **职能**: **形式上的授权与喜庆**。代表一切具有仪式感的授权、授职、授奖等事件。\n"
         @"    *   **直断映射**: 授权书、任命状、毕业证、奖状、宴会、官方仪式、考研升学相关事宜。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 持印 (**直断**: 吉，手握权柄或重要文件)。\n"
         @"    *   `临丑`: 列席 (**直断**: 有宴会、酒食之事)。\n"
         @"    *   `临寅`: 巡狩 (**直断**: 官方或正式的巡视、检查)。\n"
         @"    *   `临卯`: 遗冠 (**直断**: 有失职、丢面子之忧)。\n"
         @"    *   `临辰`: 荷项 (**直断**: 受缚、被囚，行动不自由)。\n"
         @"    *   `临巳`: 铸印 (**直断**: 有转职、获得新职权之象)。\n"
         @"    *   `临午`: 乘辂 (**直断**: 赴贵人之宴，或参加高级别活动)。\n"
         @"    *   `临未`: 窥户 (**直断**: 有宴会、酒食之事)。\n"
         @"    *   `临申`: 捧印 (**直断**: 职位调动，官职升迁)。\n"
         @"    *   `临酉`: 立券 (**直断**: 涉及财物、契约之事)。\n"
         @"    *   `临戌`: 入狱 (**直断**: 受缚、被囚，行动不自由)。\n"
         @"    *   `临亥`: 解绶 (**直断**: 辞职、退休或交出权力)。\n"
         @"---\n"
         @"##### **【融合分子#C-10: 玄武 (癸亥水)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**胆小社恐、好逸恶劳的“机会主义者”**。\n"
         @"    *   **动机**: 既不想付出任何劳动，又想白拿所有好处，因此行为必然是偷偷摸摸、害怕见光的。\n"
         @"    *   **职能**: **暗中行事**。代表盗窃、欺骗、奸邪等一切暗昧不明之事。\n"
         @"    *   **直断映射**: 小偷、骗子、暗中的勾当、私情、遗失物品。追债时遇到，对方必玩消失。\n"
         @"    *   **关键修正**: 只有在构成“金水相生”的特定格局下，才可论其“智慧”一面，否则一概以心术不正、胆小怕事论。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 过海 (**直断**: 有暗中的行动、出行)。\n"
         @"    *   `临丑`: 立云 (**直断**: 虚假不实，易有失物)。\n"
         @"    *   `临寅`: 失水 (**直断**: 暗昧之事无力，盗贼难成)。\n"
         @"    *   `临卯`: 窥户 (**直断**: 必有盗贼或失物之事)。\n"
         @"    *   `临辰`: 入狱 (**直断**: 因暗昧之事引发官司)。\n"
         @"    *   `临巳`: 现形 (**直断**: 阴私之事暴露，盗贼被抓)。\n"
         @"    *   `临午`: 拔剑 (**直断**: 暗中的小人具有攻击性，能伤人)。\n"
         @"    *   `临未`: 朝天 (**直断**: 利于暗中求见大人物)。\n"
         @"    *   `临申`: 按剑 (**直断**: 暗中有争斗，有害)。\n"
         @"    *   `临酉`: 伏藏 (**直断**: 阴谋隐藏，盗贼潜伏)。\n"
         @"    *   `临戌`: 真冠 (**直断**: 家人中有鬼祟或阴私之事)。\n"
         @"    *   `临亥`: 入海 (**直断**: 阴私难寻，盗贼远遁)。\n"
         @"---\n"
         @"##### **【融合分子#C-11: 太阴 (辛酉金)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**深藏不露、城府极深的“静默谋士”**。\n"
         @"    *   **动机**: 喜怒不形于色，平时看似透明，实则内心盘算清晰。在关键时刻，能一招制胜。\n"
         @"    *   **职能**: **策划不明之事**。代表一切原因不明、难以查证、不露破绽的秘密谋划或事件。\n"
         @"    *   **直断映射**: 阴谋、私下策划、灵异事件、原因不明的失物、城府深的人。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 垂帘 (**直断**: 信息隔绝，事情不通)。\n"
         @"    *   `临丑`: 入庙 (**直断**: 谋划之事得地，进展顺利)。\n"
         @"    *   `临寅`: 失权 (**直断**: 暗中失去权柄或支持)。\n"
         @"    *   `临卯`: 沐浴 (**直断**: 有不正当的私情)。\n"
         @"    *   `临辰`: 理冠 (**直断**: 正在谋求晋升或进展)。\n"
         @"    *   `临巳`: 伏枕 (**直断**: 内心有思虑、谋划)。\n"
         @"    *   `临午`: 披发 (**直断**: 有私下的忧愁之事)。\n"
         @"    *   `临未`: 裸形 (**直断**: 阴私之事暴露)。\n"
         @"    *   `临申`: 法服 (**直断**: 有阴谋或涉及婚姻的私下之事)。\n"
         @"    *   `临酉`: 闭户 (**直断**: 杜绝往来，谋划之事机密)。\n"
         @"    *   `临戌`: 绣裳 (**直断**: 涉及婚姻的私下之事)。\n"
         @"    *   `临亥`: 妊娠 (**直断**: 女性有疾病或怀孕之事)。\n"
         @"---\n"
         @"##### **【融合分子#C-12: 天后 (壬子水)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**极度在意他人看法、不惜牺牲自己来维持善良形象的“圣母”**。\n"
         @"    *   **动机**: 核心动机是**避免冲突**和**害怕别人不开心**。第一层表现为不懂拒绝，愿意吃亏；第二层（更本质）则是会去讨好潜在的强者或恶人，以求得自保。\n"
         @"    *   **职能**: **庇护与情感**。代表与占者关系亲密的女性，提供情感支持或庇护。\n"
         @"    *   **直断映射**: 母亲、妻子、关系亲密的女性长辈。\n"
         @"    *   **关键修正**: “阴私淫佚”是对此种“不懂拒绝”性格可能导致后果的论断，而非其本性。其本性更接近于一种**牺牲式的母性**。\n"
         @"*   **【临宫状态 (强制查询)】**:\n"
         @"    *   `临子`: 守闺 (**直断**: 事情停滞不动)。\n"
         @"    *   `临丑`: 逆水 (**直断**: 感情受挫，事不顺心)。\n"
         @"    *   `临寅`: 溺水 (**直断**: 沉溺于私情，有危险)。\n"
         @"    *   `临卯`: 倚门 (**直断**: 有所期待、盼望)。\n"
         @"    *   `临辰`: 毁装 (**直断**: 有破败、血病之灾)。\n"
         @"    *   `临巳`: 裸体 (**直断**: 有失礼、不合规矩的行为，或私情暴露)。\n"
         @"    *   `临午`: 倚枕 (**直断**: 关系难合，心中有忧)。\n"
         @"    *   `临未`: 沐浴 (**直断**: 有不正当的私情)。\n"
         @"    *   `临申`: 理装 (**直断**: 涉及生产或婚姻之事)。\n"
         @"    *   `临酉`: 把镜 (**直断**: 涉及婚姻之事)。\n"
         @"    *   `临戌`: 入墓 (**直断**: 感情压抑，关系停滞)。\n"
         @"    *   `临亥`: 治事 (**直断**: 主事，开始处理事务)。\n"
         @"### 【知识库 D-Series: 专题占断协议包 (S.D.P.)】V2.1\n"
         @"\n"
         @"#### **【协议包总纲与执行宪章】**\n"
         @"\n"
         @"*   **`协议定位`**: 本知识库是【创境分析引擎】为应对特定占断领域而设的**专用解释框架**。当`【元公理 P-001: 领域优先协议】`被激活时，对应领域的协议包将被加载，其内部的类神定义、格局法则和叙事框架将获得最高解释优先级。\n"
         @"*   **`【S+++级 · 司法仲裁条款】`**: **本协议包内所有“专属格局与法则”本质上属于高级【象】法范畴。其最终解释权，必须无条件服从于【最高元公理：理、气、象三元权衡原则】。**\n"
         @"    *   **执行指令**: 当本协议包中的一条“象”法断语，与课盘的“理”（结构格局，如三传动力链）或“气”（能量状态，如旺衰空墓）发生冲突时，必须启动权衡裁决。\n"
         @"    *   **判例 (婚姻占)**:\n"
         @"        *   **象**: 婚姻协议包法则显示 `财官乘合格局` (主婚成)。\n"
         @"        *   **气**: 但代表女方的`财爻`处于`死绝空亡`之地。\n"
         @"        *   **裁决**: 依据 **【气 > 象】** 原则，裁定为：“虽然名义上看似有婚姻之象（象），但由于代表女方的核心能量极度衰弱虚无（气），这段关系实际上是虚而不实、无法落地的镜花水月，或仅仅是口头约定。” 严禁因“象”吉而断言婚成。\n"
         @"    *   **判例 (宅墓占)**:\n"
         @"        *   **象**: 宅墓协议包法则显示 `支克干` (宅气伤人，大凶)。\n"
         @"        *   **理**: 但三传末传生日干，构成`救援`格局。\n"
         @"        *   **裁决**: 依据 **【理 > 气 > 象】** 原则，裁定为：“此宅居住初期确实会引发一系列问题，对人造成不利影响（象），但事情的最终发展（理）会导向一个有解救、能化险为夷的结局。这是一个‘先凶后吉’的局面。” 严禁因“象”凶而断言一败涂地。\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-HM-01: 宅墓风水协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断阳宅、阴宅、地产交易、修造、迁移事宜时强制激活。\n"
         @"*   **`专属类神定义 (强制覆写)`**:\n"
         @"    *   **核心主体**:\n"
         @"        *   `日干`: **人** (宅主、占者、人丁)。\n"
         @"        *   `日支`: **宅/穴** (阳宅本体、阴宅穴场)。\n"
         @"        *   `第四课 (支阴)`: **亡人/穴内情况** (专用于阴宅占)。\n"
         @"    *   **四象环境 (峦头)**:\n"
         @"        *   `玄武`: **后山/来龙/玄武砂** (靠山、背景、根基)。\n"
         @"        *   `青龙`: **左砂/青龙砂** (左侧环境、护卫力量、男性贵人)。\n"
         @"        *   `白虎`: **右砂/白虎砂/道路** (右侧环境、煞气、女性/小人是非)。\n"
         @"        *   `朱雀`: **前山/案山/朝山** (前方视野、前景、对景、文书契约)。\n"
         @"        *   `勾陈`: **明堂** (宅前空地、气场汇聚处)。其阳神为`内明堂`，阴神为`外明堂`。\n"
         @"    *   **宅内部件 (内六事)**:\n"
         @"        *   `卯/酉`: **门/户** (卯为外门，酉为内门/窗)。\n"
         @"        *   `巳`: **灶** (厨房、炉灶、火源)。\n"
         @"        *   `未`: **井/院/神龛** (水源、庭院、祭祀场所)。\n"
         @"        *   `亥`: **厕/楼阁/水道** (卫生间、楼上空间、排污系统)。\n"
         @"        *   `寅`: **梁柱/书房/道路**。\n"
         @"        *   `丑`: **厨房/庭院/牛栏/仓库**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"\n"
         @"    **第一部分：阳宅通用驱动**\n"
         @"    *   **【人宅关系驱动】**:\n"
         @"        *   `支加干 (宅就人)`: **【旺人驱动】**。宅来生助人。主此宅能旺人丁、助事业。\n"
         @"        *   `干加支 (人就宅)`: **【人养宅驱动】**。人依附于宅。若干上神生合支，为“成功经营”；若克泄支，为“心力交瘁”。\n"
         @"        *   `支克干`: **【宅伤人驱动】**。宅气伤人。主居住后人口不安、多病、损财。\n"
         @"        *   `干克支`: **【人损宅驱动】**。人气压制宅气。主难以安居，有搬迁、变卖之象。\n"
         @"    *   **【三传趋势驱动】**:\n"
         @"        *   `三传脱支生日干`: **【人兴屋衰驱动】**。宅之精华向人丁汇聚，利人丁，但房屋本身可能显得拥挤或有损耗。\n"
         @"        *   `三传盗干生支辰`: **【屋兴人衰驱动】**。居住者的能量被地产过度吸取，利屋不利人。\n"
         @"        *   `三传生支克日干`: **【破产解厄驱动】**。通过牺牲地产来解决人身的困境。\n"
         @"        *   `三传生干克支辰`: **【根基动摇驱动】**。人的根基不稳，与地产关系疏离，暗示产权不实或将弃家远行。\n"
         @"\n"
         @"    **第二部分：阴宅(坟墓)专属驱动**\n"
         @"    *   **【龙穴砂水驱动】**:\n"
         @"        *   `玄武乘旺相生穴`: **【来龙有力驱动】**。主龙脉正、根基厚，福荫绵长。\n"
         @"        *   `辰阴主山看坐落`: 支阴（第四课）为穴场，宜被`青龙`、`白虎`生合拱卫，忌被刑冲克破。\n"
         @"        *   `上下皆合风气踞`: 支阴课的上下神相生相合，主藏风聚气。\n"
         @"        *   `阴后水口蛇罗城`: `天后`为水口，`螣蛇`为罗城（外围山脉）。二者宜环抱有情，不宜反背冲射。\n"
         @"    *   **【棺椁状态驱动】**:\n"
         @"        *   `伏尸支上临墓虎`: **【穴中有异驱动】**。`白虎`乘`墓神`加支上，或第四课见此组合，主穴内有伏尸、旧骨未净，为大凶。\n"
         @"        *   `玄神乘水`: `玄武`乘水神（亥子）临第四课，主棺内进水。\n"
         @"        *   `螣蛇`或`曲直`局临第四课: 主有树根穿棺。\n"
         @"        *   `白虎`临第四课克`支阴`: 主有白蚁蛀蚀。\n"
         @"\n"
         @"    **第三部分：迁移与修造专属驱动**\n"
         @"    *   **【迁移驱动】**:\n"
         @"        *   `返吟课`: **【迁转驱动】**。占迁移遇返吟，主动象已成，大利搬迁。\n"
         @"        *   `两仪乘旺莫图迁`: `日干`与`日支`皆临旺地，主当前人宅两安，不宜迁动。\n"
         @"        *   `两仪但乘死绝气`: `日干`与`日支`皆临死绝之地，主当前人宅皆衰，最利更新环境以获福。\n"
         @"        *   `斩关发用远移近`: 斩关课发用，主迁移之象，多为从远方迁回近处。\n"
         @"    *   **【修造驱动】**:\n"
         @"        *   `日禄加支被脱克`: **【修造破耗驱动】**。主因修造房屋而破财或招致灾厄。\n"
         @"        *   `官鬼`加`巳`(灶)或`卯`(门): **【动煞驱动】**。主修灶或修门引动官鬼，易招口舌官非。\n"
         @"        *   `太岁`或`月建`临支被克冲: **【冲犯太岁驱动】**。严禁在该方位动土，主大凶。\n"
         @"\n"
         @"    **第四部分：家宅不宁与鬼祟诊断驱动**\n"
         @"    *   **【鬼祟诊断驱动】**:\n"
         @"        *   `天目临支用，主宅内有鬼神、伏尸`: `天目`煞（春辰夏未秋戌冬丑）临支或发用，是家宅不宁的重要信号。\n"
         @"        *   `蛇虎魁罡加临行年，主其人受殃`: `螣蛇`、`白虎`、`辰`、`戌`等凶神恶煞加临居住者行年，主怪异之事冲着此人而来。\n"
         @"        *   `鬼乘天乙断神祗`: 官鬼乘贵人，主家中所供神佛不正或有所求。\n"
         @"        *   `金见螣蛇釜鸣怪，木逢白虎栋摧论`: `螣蛇`乘金神（申酉），主锅碗瓢盆等金属器皿发出怪响；`白虎`乘木神（寅卯），主梁柱有损或发出异响。\n"
         @"*   **`强制叙事框架`**:\n"
         @"    *   **阳宅**: “本次勘察的地产（`日支`），从业主（`日干`）与它的关系来看，激活了`[人宅关系驱动]`。其外部大环境...三传的演化激活了`[三传趋势驱动]`。内部`[门/灶/井等]`的状态为`[对应类神象意]`。综合判断，此地产的风水格局对居住者的影响是`[最终结论]`。”\n"
         @"    *   **阴宅**: “此阴宅（`日支`）的来龙（`玄武`）`[吉凶]`，穴场（`支阴`）`[吉凶]`，砂水（`龙虎雀勾`）`[吉凶]`。穴内（`第四课`）的情况显示`[棺椁状态驱动]`。三传揭示了此地对后人`[早/中/晚]`年的影响。综合判断，此阴宅对后代子孙的福荫是`[最终结论]`。”\n"
         @"---\n"
         @"#### **【S.D.P.-RL-02: 婚恋情感协议包 】\n"
         @"\n"
         @"*   **`协议激活`**: 占断恋爱、婚姻、情感复合、人际关系时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【关系初探】、【关系发展】还是【关系危机】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 2.1: 【关系初探】**\n"
         @"*(适用于：问能否追到？能否在一起？相亲对象如何？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方** (追求者)。\n"
         @"    *   `日支`: **对方** (被追求者)。\n"
         @"    *   `六合`: **媒人/介绍人/社交场合**。\n"
         @"    *   `妻财` (男占) / `官鬼` (女占): **关系目标/成功的可能性**。\n"
         @"    *   `青龙` (男占) / `天后` (女占): **对方的形象与状态**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【意愿驱动】**:\n"
         @"        *   `干生支/干合支`: **【我方主动驱动】**。叙事核心：我方积极主动，对对方有好感。\n"
         @"        *   `支生干/支合干`: **【对方有意驱动】**。叙事核心：对方对我方亦有好感，或不排斥接触，是极佳的成功信号。\n"
         @"        *   `干支刑克/相害`: **【互相排斥驱动】**。叙事核心：双方气场不合，存在根本性的矛盾或反感，关系难以建立。\n"
         @"    *   **【成败驱动】**:\n"
         @"        *   `财官临身/入传`: **【目标明确驱动】**。代表关系目标的`财/官`爻出现在日干之上或三传之中，主此事有成功的路径。\n"
         @"        *   `财官空亡/墓绝`: **【虚幻无缘驱动】**。代表关系目标的`财/官`爻空亡或坐死墓绝之地，主此事虚幻，缘分浅薄，或对方已有伴侣（虚位被占）。\n"
         @"        *   `三传生合`: **【顺缘成就驱动】**。三传一路相生，且最终生向我方或对方，主过程顺利，多有助力。\n"
         @"    *   **【对方状态驱动】**:\n"
         @"        *   `支上乘蛇虎鬼`: **【对方有患驱动】**。对方（日支）上见螣蛇、白虎、官鬼等凶将，主对方自身有麻烦、性格强势或已有情感纠葛。\n"
         @"        *   `支上乘桃花/咸池`: **【对方魅力/复杂驱动】**。主对方富有魅力，但同时也暗示其感情生活可能较为复杂，追求者众。\n"
         @"*   **`强制叙事框架`**: “此次情感探索，我方（`日干`）的意愿表现为`[干支关系]`。对方（`日支`）的态度与现状是`[支上神将象意]`。成功的可能性（`财官`）`[高/低]`，因为`[财官状态]`。事件的发展过程（`三传`）预示着`[顺利/曲折]`。综合判断，这段关系能否建立的结论是`[能/否/有条件]`，关键在于`[核心要素]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 2.2: 【关系发展】**\n"
         @"*(适用于：问关系前景？感情好不好？能否结婚？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **男方/阳性方**。\n"
         @"    *   `日支`: **女方/阴性方**。\n"
         @"    *   `六合`: **关系本身的和谐度/婚约**。\n"
         @"    *   `青龙` & `天后`: **双方情感的显化状态**。青龙主喜庆、公开；天后主隐私、情感深度。\n"
         @"    *   `父母`: **婚约/证书/家庭认可**。\n"
         @"    *   `子孙`: **子女/关系中的快乐/未来的产出**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【和谐度驱动】**:\n"
         @"        *   `干支相生相合`: **【琴瑟和鸣驱动】**。主双方感情融洽，互相扶持。\n"
         @"        *   `干支比和`: **【相敬如宾驱动】**。关系稳定，但可能缺乏激情。\n"
         @"        *   `干支刑冲破害`: **【矛盾冲突驱动】**。主双方性格不合，争吵不断。\n"
         @"    *   **【前景驱动】**:\n"
         @"        *   `三传合局生干支`: **【共筑未来驱动】**。三传合木局（子孙局）、火局（财局）等，且生助双方，主关系稳固发展，能共同创造未来。\n"
         @"        *   `父母爻入传生日干`: **【得获认可驱动】**。主关系能得到长辈或官方（婚姻登记）的认可，利于谈婚论嫁。\n"
         @"        *   `龙后交加临喜`: `青龙`与`天后`同临`天喜`神煞，或交相出现在课传中，是婚姻喜庆的强烈信号。\n"
         @"    *   **【障碍驱动】**:\n"
         @"        *   `返吟课`: **【反复不定驱动】**。主关系进展不顺，时好时坏，易有分合。\n"
         @"        *   `兄弟爻发动`: **【竞争/损耗驱动】**。`兄弟`爻入传克`妻财`，男占主有竞争者，或因朋友/花销影响感情。女占亦主有同性竞争。\n"
         @"        *   `六合临空/受克`: **【婚约受阻驱动】**。代表婚约的`六合`空亡或被克，主婚姻难成，或关系基础不稳。\n"
         @"*   **`强制叙事框架`**: “当前这段关系中，男方（`日干`）与女方（`日支`）的互动模式是`[干支关系]`，这决定了关系的和谐度。关系本身（`六合`）的状态是`[吉凶描述]`。三传揭示了关系未来的走向：`[三传演化]`。通往婚姻的关键（`父母爻`）`[是否出现]`。综合判断，这段关系的前景是`[光明/曲折/趋向稳定/走向破裂]`，建议`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 2.3: 【关系危机】**\n"
         @"*(适用于：问能否复合？是否有第三者？为何争吵？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方** (通常为提问者)。\n"
         @"    *   `日支`: **对方**。\n"
         @"    *   `间神`: **导致危机的第三方或事件** (干上神克支上神，或支上神克干上神者)。\n"
         @"    *   `官鬼`: **忧患/猜疑/问题的根源**。\n"
         @"    *   `玄武/太阴`: **欺骗/隐瞒/私情**。\n"
         @"    *   `破碎/解神`: `破碎`主关系破裂，`解神`主有和解之机。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【危机根源驱动】**:\n"
         @"        *   `芜淫/解离课`: **【不忠/离心驱动】**。激活此驱动，直接指向关系危机的核心是第三方介入或双方已无感情。\n"
         @"        *   `官鬼临兄弟爻`: **【外部竞争驱动】**。主危机来源于外部的追求者或朋友挑拨。\n"
         @"        *   `官鬼临父母爻`: **【家庭/现实压力驱动】**。主危机来源于长辈反对或现实生活（工作、房子）的压力。\n"
         @"        *   `玄武/太阴入传克干支`: **【欺瞒背叛驱动】**。主关系中存在谎言、秘密或实际的出轨行为。\n"
         @"    *   **【复合可能驱动】**:\n"
         @"        *   `末传生合干支`: **【破镜重圆驱动】**。三传演化的最终结果是生合，主虽有波折，但最终能够和好。\n"
         @"        *   `返吟占复合`: **【旧情复燃驱动】**。占复合遇返吟课，是复合的强烈信号，主去而复返。\n"
         @"        *   `用神遥合干支`: **【心有挂念驱动】**。虽然表面分离，但发用与日干或日支遥合，主对方心中仍有牵挂。\n"
         @"    *   **【关系终结驱动】**:\n"
         @"        *   `破碎神入传临身命`: **【关系破裂驱动】**。`破碎`煞入传并加临日干或本命，是关系彻底结束的信号。\n"
         @"        *   `三传一路克战`: **【无法挽回驱动】**。三传连续克战，且无解救，主矛盾激化，无法回头。\n"
         @"        *   `日辰乘绝神`: `日干`或`日支`临`绝`地，主一方心意已决，恩断义绝。\n"
         @"*   **`强制叙事框架`**: “当前关系危机的根源在于`[危机根源驱动]`。我方（`日干`）的态度是`[干上象意]`，对方（`日支`）的态度是`[支上象意]`。三传`[三传]`的演化，揭示了此事将如何发展。根据盘中`[复合/终结驱动]`的信号，最终复合的可能性为`[高/低]`。若要挽回，关键在于`[策略指引，如解决子孙爻代表的问题，或等待解神出现]`。”\n"
         @"*   **`策略指引提取`**:\n"
         @"    *   若`子孙`爻受克，则策略为**解决导致关系不快乐的根源问题**。\n"
         @"    *   若`父母`爻为阻碍，则策略为**处理长辈或现实层面的障碍**。\n"
         @"    *   若`解神`入传，则策略为**等待时机，届时会有和解契机**。\n"
         @"    *   若`六合`为用神，则策略为**寻求中间人调解**。\n"
         @"---\n"
         @"#### **【S.D.P.-HD-03: 健康疾病协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断疾病性质、发展趋势、治疗方案及预后时强制激活。**本协议进入【解厄剧本】模式，六亲角色按此剧本定义**。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【病因与病症诊断】、【病程发展与预后】还是【医药与治疗方案】。在综合占断中，将按此顺序依次分析。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 3.1: 【病因与病症诊断】**\n"
         @"*(适用于：问得的是什么病？病因是什么？病灶在哪里？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `官鬼`: **病症本体/病源**。\n"
         @"    *   `白虎`: **病势/炎症/血光/疼痛**。\n"
         @"    *   `螣蛇`: **缠绵/怪异/神经性/肿瘤**。\n"
         @"    *   `玄武`: **暗病/肾虚/体液失调/头晕**。\n"
         @"    *   `朱雀`: **炎症/发热/口舌官能疾病**。\n"
         @"    *   `勾陈`: **肿块/雍塞/慢性病/皮肤病**。\n"
         @"    *   `父母`: **病因** (多为劳累、忧思、文书之事引起)。\n"
         @"    *   `妻财`: **病因** (多为饮食、男女之事、金钱劳碌引起)。\n"
         @"    *   `兄弟`: **病因** (多为外感风寒、同伴传染、竞争压力引起)。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【病灶定位驱动】**:\n"
         @"        *   `官鬼五行定位`:\n"
         @"            *   鬼为**火 (巳午)**: 主**心脏、小肠、血液、眼目**等循环系统和感官疾病。多为炎症、发热、心悸。\n"
         @"            *   鬼为**土 (辰戌丑未)**: 主**脾胃、腹部、肌肉、皮肤**等消化和支撑系统疾病。多为腹胀、食欲不振、肿块。\n"
         @"            *   鬼为**金 (申酉)**: 主**肺、大肠、呼吸道、骨骼**等呼吸和支撑系统疾病。多为咳嗽、气喘、骨痛。\n"
         @"            *   鬼为**水 (亥子)**: 主**肾、膀胱、泌尿、生殖**等泌尿和内分泌系统疾病。多为虚寒、水肿、肾亏。\n"
         @"            *   鬼为**木 (寅卯)**: 主**肝、胆、神经、筋脉、四肢**等神经和运动系统疾病。多为风症、抽搐、肢体麻木。\n"
         @"    *   **【病因追溯驱动】**:\n"
         @"        *   `生鬼之爻为病源`: **【病根追溯驱动】**。生助`官鬼`爻的那个六亲，即是引发疾病的根本原因。*例：`父母`爻生`官鬼`，主因过度劳累或忧虑成疾。`妻财`爻生`官鬼`，主因饮食不节或房事过度导致生病。*\n"
         @"        *   `日墓发用`: **【心病驱动】**。主疾病根源于心理问题、心结或长期的精神压抑。\n"
         @"    *   **【病症性质驱动】**:\n"
         @"        *   `虎鬼交加`: **【急性重症驱动】**。`白虎`与`官鬼`并见，主病情来势凶猛，疼痛剧烈，或涉及手术、外伤。\n"
         @"        *   `蛇鬼缠绕`: **【疑难杂症/慢性病驱动】**。`螣蛇`与`官鬼`并见，主病症怪异，难以诊断，或病情反复，久治不愈，也常与神经系统或精神问题相关。\n"
         @"        *   `三传全鬼`: **【多病并发驱动】**。主病人身患多种疾病，或病症已扩散至多个脏腑。\n"
         @"*   **`强制叙事框架`**: “根据诊断，病症的核心（`官鬼`）五行属`[五行]`，定位在人体的`[脏腑/部位]`。其性质由`[天将]`定义，表现为`[急性/慢性/疑难]`等特征，具体症状为`[症状描述]`。追溯其病因，是由`[生鬼之爻]`所代表的`[生活习惯/情绪/外因]`所引发。综合判断，此病被诊断为`[病名概括]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 3.2: 【病程发展与预后】**\n"
         @"*(适用于：问病情会加重还是好转？能治好吗？有生命危险吗？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干` & `本命/行年`: **病人生命力/元气**。\n"
         @"    *   `三传`: **病程发展的三个阶段** (初期、中期、末期)。\n"
         @"    *   `长生/帝旺` (临日干): **生机/抵抗力强**。\n"
         @"    *   `死/墓/绝` (临日干): **危险/元气衰败**。\n"
         @"    *   `子孙`爻: **康复的希望/转机**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【预后吉兆驱动】**:\n"
         @"        *   `传鬼化生`: **【转危为安驱动】**。初传为`官鬼`，但中末传转为生日干的`父母`爻。叙事核心：疾病（初传）最终转化为滋养生命的力量（末传），主大病不死，终将康复。\n"
         @"        *   `鬼投绝地/末传克鬼`: **【病气消散驱动】**。`官鬼`爻在三传中行至其`绝`地，或被`末传`克制，主病症将自然消退或被最终克服。\n"
         @"        *   `生龙` (青龙乘生气): **【起死回生驱动】**。久病或重病见此，是生命力复苏的强烈信号。\n"
         @"    *   **【预后凶兆驱动】**:\n"
         @"        *   `日干入墓无救`: **【元气耗尽驱动】**。`日干`入墓（传、课、行年），且无冲开的力量，是生命力衰竭的极凶信号。*即使病症被治愈（官鬼被制），人也可能因耗尽而亡。*\n"
         @"        *   `传墓入墓`: **【病情恶化驱动】**。三传传入`日干`或`官鬼`的墓地，主病情加重，意识昏沉。\n"
         @"        *   `收魂煞` (玄武乘日墓克日): **【魂归地府驱动】**。主病人神识不清，生命垂危。\n"
         @"        *   `病符克日全家患`: **【时疫传染驱动】**。`病符`（旧太岁）在课传中克日，主疾病有传染性，或为时令流行病，家人需注意防护。\n"
         @"*   **`强制叙事框架`**: “关于病情的未来走向，病人的生命力（`日干`）目前处于`[强/弱]`的状态。病程的发展（`三传`）显示：初期`[初传象意]`，中期`[中传象意]`，最终`[末传象意]`。根据`[吉兆/凶兆驱动]`的信号，此病的预后倾向于`[好转/恶化/缠绵]`。是否存在生命危险，关键看`日干`是否`[入墓/逢绝]`且无解救。综合判断，此病的最终结局是`[痊愈/转慢/危重]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 3.3: 【医药与治疗方案】**\n"
         @"*(适用于：问治疗方法是否对症？应找什么样的医生？能否痊愈？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `子孙`: **医药/医生/主要治疗方案**。\n"
         @"    *   `天医/地医`: **对症的医生或治疗方向**。\n"
         @"    *   `父母`: **辅助治疗/疗养/文书（病历）**。\n"
         @"    *   `妻财`: **饮食/营养/医疗费用**。\n"
         @"    *   `青龙`: **良药/名医**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【疗效判断驱动】**:\n"
         @"        *   `子孙旺相制鬼`: **【药到病除驱动】**。`子孙`爻旺相有力，且在课传中能有效克制`官鬼`爻，主治疗方案对症，效果显著。\n"
         @"        *   `子孙休囚/被克/空亡`: **【医药无效驱动】**。`子孙`爻无力，主医生水平不行，或药物不对症，或根本没得到有效治疗。\n"
         @"        *   `庸医杀人官鬼乘`: **【误诊误治驱动】**。`子孙`爻（医生）上乘坐`官鬼`，反来克身，主医生误诊，用药错误，加重病情。\n"
         @"    *   **【疗法选择驱动】**:\n"
         @"        *   `子孙五行定疗法`:\n"
         @"            *   子孙为**木**: 主**中药汤剂、草药疗法**。\n"
         @"            *   子孙为**土**: 主**丸药、膏药、营养疗法**。\n"
         @"            *   子孙为**金**: 主**针灸、手术、西药（化学合成）**。\n"
         @"            *   子孙为**火**: 主**艾灸、理疗、放疗、精神疗法**。\n"
         @"            *   子孙为**水**: 主**水疗、液体药物、清洁疗法**。\n"
         @"        *   `天医临方为良医`: `天医`煞所临的地盘方位，是寻找良医的方向。\n"
         @"    *   **【痊愈时机驱动】**:\n"
         @"        *   `鬼贼绝处病可痊`: 疾病的痊愈时间，多应在`官鬼`爻的`绝`地之月、日。\n"
         @"        *   `子孙旺相之期`: 疾病的好转或痊愈，也常应在`子孙`爻当令或被生旺的月、日。\n"
         @"*   **`强制叙事框架`**: “针对此病，盘中的治疗方案（`子孙`）表现为`[疗法类型]`，其疗效由`[疗效判断驱动]`决定，显示为`[有效/无效/有害]`。寻找对症的医生或疗法，应参考`[天医]`所在的`[方位]`。饮食营养（`妻财`）方面，`[宜/忌]`。根据`[痊愈时机驱动]`，病情出现明显好转或痊愈的时间点可能在`[应期]`。综合判断，目前的治疗策略`[正确/需调整]`，康复的关键在于`[核心策略]`。”\n"
         @"*   **`策略指引`**:\n"
         @"    *   若`子孙`休囚，策略为**更换医生或治疗方案**。\n"
         @"    *   若`妻财`克`父母`（饮食伤身），策略为**严格控制饮食**。\n"
         @"    *   若`父母`为病因，策略为**静养、减少思虑**。\n"
         @"    *   若`鬼临生旺`，策略为**不可拖延，须立即积极治疗**。\n"
         @"---\n"
         @"#### **【S.D.P.-CS-04: 官禄仕途协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断求职、入职、升迁、调动、官运、事业发展、工作危机等事宜时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【求职/入职】、【在职发展/升迁】还是【事业危机/变动】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 4.1: 【求职/入职】**\n"
         @"*(适用于：问能否找到工作？面试能否通过？这个offer好不好？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **求职者**。\n"
         @"    *   `官鬼`: **目标职位/面试官/公司**。\n"
         @"    *   `父母` & `朱雀`: **offer/合同/文书/通知**。\n"
         @"    *   `妻财`: **薪水/待遇**。\n"
         @"    *   `日禄`: **我方的实力/被录用的资格**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【机遇驱动】**:\n"
         @"        *   `官鬼空亡旺相`: **【虚位以待驱动】**。激活`A-001`公理。主职位空缺真实存在且质量不错，关键在于我方能否填补。\n"
         @"        *   `官鬼生合干命`: **【官来就我驱动】**。职位/公司主动寻求我方，或我方与职位高度匹配，是成功的强烈信号。\n"
         @"        *   `官爵课` (干支上神作官星与印绶): **【名利双收驱动】**。主所求职位不仅能获得，且待遇优厚，名声好。\n"
         @"    *   **【成败驱动】**:\n"
         @"        *   `印绶入传生日`: **【offer已定驱动】**。代表录用通知的`父母/朱雀`入传生助我方，主面试通过，必得录用。\n"
         @"        *   `日禄入传/临身`: **【实力匹配驱动】**。主我方能力符合职位要求，能胜任该工作。\n"
         @"        *   `官鬼空绝/被克`: **【职位虚假/取消驱动】**。主所求职位不存在，或招聘已取消，或对方无意录用。\n"
         @"    *   **【待遇驱动】**:\n"
         @"        *   `财爻旺相生身`: **【高薪厚禄驱动】**。代表薪水的`妻财`爻旺相且生合我方，主待遇优厚。\n"
         @"        *   `财化鬼/财临兄弟`: **【待遇陷阱驱动】**。主薪资待遇存在问题，或入职后因财致祸，或有竞争者分薄利益。\n"
         @"*   **`强制叙事框架`**: “此次求职，我方（`日干`）的状态为`[旺衰]`。目标职位/公司（`官鬼`）的情况是`[吉凶描述]`。根据`[机遇驱动]`判断，这是一个`[真/假]`机会。成功的关键在于`[成败驱动]`的信号，显示offer（`父母/朱雀`）`[能否到手]`。薪酬待遇（`妻财`）方面，`[高低与否]`。三传揭示了求职过程`[顺利/曲折]`。综合判断，此次求职的结果是`[成功/失败]`，建议`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 4.2: 【在职发展/升迁】**\n"
         @"*(适用于：问能否升职？工作前景如何？与上级关系？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方/在职者**。\n"
         @"    *   `官鬼`: **上级/权力/官职**。\n"
         @"    *   `青龙` & `太常`: `青龙`为**文职升迁/恩宠**，`太常`为**武职/授权/印绶**。\n"
         @"    *   `父母`: **权力/印信/任命文书**。\n"
         @"    *   `日禄`: **俸禄/地位的稳固性**。\n"
         @"    *   `驿马`: **调动/换岗**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【升迁驱动】**:\n"
         @"        *   `催官符使` (`白虎`乘`官鬼`临身命): **【压力即动力驱动】**。主上级给予巨大压力，但同时也是提拔重用的前兆，升迁迅速。\n"
         @"        *   `德入天门` (`日德`临`亥`): **【天门开启驱动】**。大利功名，主有重大晋升机遇，直达更高层级。\n"
         @"        *   `龙常带印入传`: **【权柄在握驱动】**。`青龙`或`太常`乘`父母`爻（印绶）入传生合我方，主得权柄，任命书将至。\n"
         @"        *   `铸印乘轩`: **【加官进爵驱动】**。主掌握实权，官职提升。\n"
         @"    *   **【关系与环境驱动】**:\n"
         @"        *   `官鬼生合干命`: **【上级赏识驱动】**。主与上级关系融洽，得到器重。\n"
         @"        *   `官鬼刑克干命`: **【上级打压驱动】**。主与上级关系紧张，受到压制。\n"
         @"        *   `兄弟爻旺动`: **【同事竞争驱动】**。主职场竞争激烈，需防同事争功或使绊。\n"
         @"    *   **【调动驱动】**:\n"
         @"        *   `驿马临官鬼/禄神`: **【升职调动驱动】**。主因职位或待遇提升而发生工作地点或岗位的变动。\n"
         @"        *   `返吟课`: **【岗位反复驱动】**。主工作内容或职位频繁变动，或调动之事一波三折。\n"
         @"*   **`强制叙事框架`**: “当前在职状态，我方（`日干`）与上级（`官鬼`）的关系为`[融洽/紧张]`。同事环境（`兄弟`）`[和谐/竞争]`。近期是否有升迁机遇，关键看`[升迁驱动]`信号是否出现。`[青龙/太常]`的状态显示了`[文/武]`职方面的前景。三传揭示了事业发展的轨迹。综合判断，未来的事业走向是`[平稳/上升/调动]`，成功的关键在于`[抓住...机遇/处理...关系]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 4.3: 【事业危机/变动】**\n"
         @"*(适用于：问工作会不会丢？犯小人怎么办？要不要跳槽？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方**。\n"
         @"    *   `官鬼`: **危机来源/压力/官非/新机会**。\n"
         @"    *   `子孙`: **解救力量/解决方案/辞职的念头**。\n"
         @"    *   `白虎`: **处分/裁员/强制性变动**。\n"
         @"    *   `玄武/太阴`: **暗中陷害/阴谋/小人**。\n"
         @"    *   `日禄`: **饭碗/工作的根基**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【危机根源驱动】**:\n"
         @"        *   `官鬼克身无救`: **【失业/官灾驱动】**。`官鬼`乘凶将克`日干`，且无`父母`爻通关或`子孙`爻制克，是失业、受处分或惹上官非的强烈信号。\n"
         @"        *   `玄武/太阴乘鬼克身`: **【小人暗害驱动】**。主有小人在暗中操作，导致事业危机。\n"
         @"        *   `墓神覆日`: **【压抑受困驱动】**。主工作中感到压抑、被架空，才华无法施展，前途晦暗。\n"
         @"        *   `日禄被冲克/临空绝`: **【饭碗动摇驱动】**。主职位不稳，有被裁员或被迫离职的风险。\n"
         @"    *   **【变动/跳槽驱动】**:\n"
         @"        *   `子孙发动克官鬼`: **【主动求变驱动】**。主内心已有离职之意，并开始寻求解决方案或新机会。\n"
         @"        *   `返吟课`: **【环境巨变驱动】**。主公司架构、领导层或工作内容将发生重大且反复的变化。\n"
         @"        *   `驿马临身命/三传`: **【跳槽时机驱动】**。主变动时机已到，适合寻求外部发展。\n"
         @"    *   **【解救驱动】**:\n"
         @"        *   `父母爻入传通关`: **【贵人化解驱动】**。`官鬼`生`父母`，`父母`生日干，形成“通关”，主有长辈、更高层领导或公司制度出面化解危机。\n"
         @"        *   `子孙旺相制鬼`: **【实力破局驱动】**。主凭借自身能力、方案或下属帮助，能够成功解决危机。\n"
         @"*   **`强制叙事框架`**: “当前事业危机的根源在于`[危机根源驱动]`，具体表现为`[事件描述]`。我方的工作根基（`日禄`）`[稳固/动摇]`。盘中是否存在解救力量？`[是（父母/子孙）/否]`。三传`[三传]`揭示了危机的演化路径。关于是否跳槽，`[变动驱动]`的信号显示`[宜动/宜静]`。综合判断，此次危机的最终结果是`[化解/升级/被迫离职]`，最佳策略是`[主动求变/寻求庇护/静待时机]`。”\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-BF-05: 交易求财协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断求财、投资、生意、买卖、索债、借贷等所有与财务相关的活动时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【投资/经营】、【买卖/交易】还是【索债/借贷】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 5.1: 【投资/经营】**\n"
         @"*(适用于：问项目投资前景？公司运营状况？合伙生意能否做？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方/投资者**。\n"
         @"    *   `日支`: **项目/公司/市场环境**。\n"
         @"    *   `妻财` & `青龙`: **利润/资产/现金流**。\n"
         @"    *   `子孙`: **产品/服务/创新能力/财源**。\n"
         @"    *   `兄弟`: **合伙人/竞争对手/运营成本/股东**。\n"
         @"    *   `官鬼`: **官方政策/市场风险/法律问题/管理压力**。\n"
         @"    *   `父母`: **项目实体/公司/合同/无形资产（品牌、专利）**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【前景与回报驱动】**:\n"
         @"        *   `子孙生财旺相`: **【高增长驱动】**。叙事核心：产品或服务具有强大的市场吸引力，能源源不断地创造利润，是项目前景光明的核心信号。\n"
         @"        *   `财爻入传生日干`: **【盈利回流驱动】**。叙事核心：项目利润能够顺利回流到投资者手中，投资回报路径通畅。\n"
         @"        *   `三传财局`: **【财富聚合驱动】**。叙事核心：各方资源、力量共同作用，形成强大的财富效应，主大利润、大项目。\n"
         @"    *   **【风险与障碍驱动】**:\n"
         @"        *   `传财化鬼`: **【盈利致灾驱动】**。叙事核心：项目虽然能赚钱，但会引发官非、重大管理问题或对投资人自身造成伤害。\n"
         @"        *   `源消根断` (四课下生上): **【持续亏损驱动】**。叙事核心：项目持续“烧钱”，不断消耗资源而无产出，是典型的折本之象。\n"
         @"        *   `兄弟爻旺动克财`: **【竞争/内耗驱动】**。叙事核心：市场竞争激烈，利润被分薄；或合伙人之间产生矛盾，内耗严重，侵吞利润。\n"
         @"    *   **【合伙关系驱动】**:\n"
         @"        *   `兄弟爻生合日干`: **【合伙同心驱动】**。主合伙人与我方目标一致，能够共同协作。\n"
         @"        *   `兄弟爻刑克日干`: **【合伙异心驱动】**。主合伙人之间存在利益冲突或背叛风险。\n"
         @"*   **`强制叙事框架`**: “本次投资/经营项目，我方（`日干`）与项目本身（`日支`）的关系是`[生克关系]`。项目的核心盈利能力（`子孙生财`）`[强/弱]`。未来的利润前景（`妻财`）`[光明/黯淡]`。在运营过程中，主要的风险来自于`[风险驱动]`，表现为`[具体事件]`。合伙关系（`兄弟`）的状态是`[同心/异心]`。三传揭示了项目从`[初传-启动]`到`[末传-结局]`的演化。综合判断，此项投资/经营的最终结果是`[成功/失败/先盈后亏]`，关键策略在于`[规避...风险/抓住...机遇]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 5.2: 【买卖/交易】**\n"
         @"*(适用于：问这笔生意能否做成？货物能否卖出？价格如何？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **卖方/我方**。\n"
         @"    *   `日支`: **买方/对方**。\n"
         @"    *   `妻财`: **货物/商品/交易金额**。\n"
         @"    *   `六合`: **交易行为/合同/中介**。\n"
         @"    *   `父母`: **货物本身** (作为载体)。\n"
         @"    *   `子孙`: **利润** (财之原神)。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【交易成败驱动】**:\n"
         @"        *   `干支相生相合`: **【供需两旺驱动】**。叙事核心：买卖双方情投意合，交易意愿强烈，容易成交。\n"
         @"        *   `六合入传`: **【交易启动驱动】**。`六合`出现在三传中，主交易行为本身能够顺利进行。若`六合`空亡或受克，主交易受阻或中介出问题。\n"
         @"        *   `财爻在日辰上交互`: **【财物交割驱动】**。`日上财`加`支`，或`支上财`加`干`，形成交车财，是财物顺利交割的明确意象。\n"
         @"    *   **【利润与价格驱动】**:\n"
         @"        *   `子孙旺相`: **【利润丰厚驱动】**。代表利润的`子孙`爻旺相有力，主这笔交易有利可图。\n"
         @"        *   `财爻旺相`: **【货物价高驱动】**。代表货物的`妻财`爻旺相，主货物价值高，能卖出好价钱。若财爻休囚，则价格不理想。\n"
         @"    *   **【障碍与风险驱动】**:\n"
         @"        *   `财神闭口` (财爻临旬尾癸): **【有价无市驱动】**。主货物虽然有价值，但无人问津，难以卖出。\n"
         @"        *   `兄弟爻发动`: **【压价/竞争驱动】**。主交易中有第三方介入压价，或有同行竞争。\n"
         @"        *   `玄武乘财`: **【欺诈/失货驱动】**。主交易中存在欺骗行为，或货物有遗失、被盗的风险。\n"
         @"*   **`强制叙事框架`**: “在这笔交易中，我方（`日干`）与买方（`日支`）的意愿是`[相合/相斥]`。交易行为本身（`六合`）`[顺利/受阻]`。货物（`妻财`）的价值与状态是`[高/低]`，其利润空间（`子孙`）`[大/小]`。三传揭示了交易从`[初传-接洽]`到`[末传-交割]`的过程。综合判断，这笔交易`[能/否]`做成，利润如何，结论是`[最终结论]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 5.3: 【索债/借贷】**\n"
         @"*(适用于：问欠款能否要回？能否借到钱？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   **占索债**:\n"
         @"        *   `日干`: **债权人/我方**。\n"
         @"        *   `日支`: **债务人/对方**。\n"
         @"        *   `妻财`: **欠款本身**。\n"
         @"        *   `玄武`: **对方赖账/躲藏/资金不明**。\n"
         @"    *   **占借贷**:\n"
         @"        *   `日干`: **借款人/我方**。\n"
         @"        *   `日支`: **出借方/对方**。\n"
         @"        *   `妻财`: **我方想借的钱**。\n"
         @"        *   `父母`: **对方的钱** (能生助我方的资源)。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【索债驱动】**:\n"
         @"        *   `取还魂债` (三传全脱，生起干上财神): **【失而复得驱动】**。叙事核心：本已耗散的钱财（脱气），通过某种方式重新回到我手中。是索回旧账的极佳信号。\n"
         @"        *   `财爻旺相克支`: **【财在我在驱动】**。叙事核心：代表欠款的`妻财`爻旺相，且能克制对方（日支），主我方在债务关系中占主动，能要回欠款。\n"
         @"        *   `支上玄武/空亡`: **【对方无力/躲藏驱动】**。叙事核心：债务人（日支）上见`玄武`或`空亡`，主对方存心赖账、躲避，或自身已无偿还能力。\n"
         @"        *   `财临兄弟被克`: **【资金被劫驱动】**。叙事核心：欠款被第三方（兄弟）劫走或消耗，导致债务人无力偿还。\n"
         @"    *   **【借贷驱动】**:\n"
         @"        *   `父母旺相生身`: **【得人资助驱动】**。代表资源的`父母`爻旺相，且入传生助我方（日干），主能顺利借到钱。\n"
         @"        *   `支生干/支上财生日`: **【对方愿借驱动】**。出借方（日支）或其财物生助我方，主对方有诚意且有能力出借。\n"
         @"        *   `财空/财被克`: **【借贷无门驱动】**。代表资金的`妻财`爻空亡或被克，主借钱无望。\n"
         @"*   **`强制叙事框架`**:\n"
         @"    *   **占索债**: “此次索债，我方（`日干`）与债务人（`日支`）的力量对比是`[我强/他强]`。债务人目前的还款意愿与能力是`[支上神将象意]`。欠款（`妻财`）本身`[有无被转移或消耗]`。三传`[三传]`揭示了索债过程。综合`[关键驱动]`判断，此笔欠款最终`[能/否]`要回，建议采取`[强硬/怀柔/等待]`的策略。”\n"
         @"    *   **占借贷**: “此次借贷，我方（`日干`）的处境是`[急迫/尚有余裕]`。出借方（`日支`）的态度与能力是`[支上神将象意]`。根据代表资助的`父母`爻状态，借贷成功的可能性为`[高/低]`。综合判断，此次借贷`[能/否]`成功，关键在于`[核心要素]`。”\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-LS-06: 官非诉讼协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断官司、诉讼、仲裁、纠纷、牢狱之灾等所有与法律相关的对抗性事宜时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【诉讼前瞻】、【庭审对抗】还是【判决与执行】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 6.1: 【诉讼前瞻】**\n"
         @"*(适用于：问要不要起诉？此事会否闹上法庭？起诉对我是否有利？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方/潜在原告**。\n"
         @"    *   `日支`: **对方/潜在被告**。\n"
         @"    *   `官鬼`: **潜在的官非风险/官方介入的可能性**。\n"
         @"    *   `朱雀`: **起诉书/证据/舆论**。\n"
         @"    *   `子孙`: **和解的可能性/避免官司的因素**。\n"
         @"    *   `六合`: **调解/和谈**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【起诉意愿驱动】**:\n"
         @"        *   `朱勾克日莫兴词`: **【被动守御驱动】**。`朱雀`或`勾陈`在课传中克制`日干`，是强烈的不利信号，激活此驱动，叙事核心为“此时起诉，如同以卵击石，必败无疑”，策略应为“防守、暂缓”。\n"
         @"        *   `日克用神`: **【主动出击驱动】**。我方（日干）克制发用（事端），主我方在事态中占据主动，有能力发起诉讼并掌控局面。\n"
         @"    *   **【官司升级驱动】**:\n"
         @"        *   `鬼临三四讼灾随`: **【官非临门驱动】**。第三、四课出现`官鬼`，主此事已难以私了，官方介入的可能性极大。\n"
         @"        *   `三传刑害克战`: **【矛盾激化驱动】**。三传充满刑冲克害，主双方矛盾无法调和，必然走向法律途径。\n"
         @"    *   **【和解可能驱动】**:\n"
         @"        *   `子孙发动/六合入传`: **【庭外和解驱动】**。`子孙`（解厄）或`六合`（调解）在课传中旺相有力，主此事有极大的和解空间，不必对簿公堂。\n"
         @"        *   `传课生合`: **【私下和谈驱动】**。课传中多见生合，主双方尚有情谊或共同利益，可以通过私下沟通解决。\n"
         @"*   **`强制叙-事框架`**: “关于此次纠纷，我方（`日干`）与对方（`日支`）的关系是`[和谐/对立]`。根据`[官司升级驱动]`的信号，此事走向诉讼的可能性为`[高/低]`。若起诉，我方的胜算由`[起诉意愿驱动]`预示为`[有利/不利]`。目前是否存在和解的可能？关键看`[和解可能驱动]`的信号，显示`[有/无]`和解空间。综合判断，对于此事，最佳策略是`[积极备诉/寻求和解/静观其变]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 6.2: 【庭审对抗】**\n"
         @"*(适用于：问官司输赢？庭审情况如何？谁占优势？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **客方** (通常为原告/先动方)。\n"
         @"    *   `日支`: **主方** (通常为被告/后应方)。\n"
         @"    *   `官鬼`: **法官/法庭/控方力量**。\n"
         @"    *   `朱雀`: **证据/证词/律师辩论**。\n"
         @"    *   `子孙`: **我方的有利证据/证人/法律的解救力量**。\n"
         @"    *   `白虎`: **判决的严厉程度/强制力量**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【输赢判断驱动】**:\n"
         @"        *   `子孙制鬼`: **【胜诉驱动】**。`子孙`爻旺相有力，克制`官鬼`爻，是打赢官司的最强信号。\n"
         @"        *   `发用克日客输，克支主输`: **【先机失利驱动】**。初传（事端）克伤哪一方，哪一方就在庭审中处于下风。\n"
         @"        *   `官鬼旺相克身`: **【败诉驱动】**。`官鬼`爻旺相无制，并克伤我方`日干`或`年命`，主败诉无疑。\n"
         @"        *   `囚睹课`: **【深陷囹圄驱动】**。主被囚禁，难以脱身，是极为不利的诉讼格局。\n"
         @"    *   **【证据与辩论驱动】**:\n"
         @"        *   `朱雀生合我方`: **【证据有力驱动】**。主我方证据确凿，言辞在理，得到法庭采信。\n"
         @"        *   `朱雀临空/受克`: **【证据不足驱动】**。主证据虚假、缺失或不被采纳，辩论处于下风。\n"
         @"    *   **【法官态度驱动】**:\n"
         @"        *   `官鬼生合我方`: **【法官偏向驱动】**。主法官对我方抱有同情或认可，判决有利。\n"
         @"        *   `官鬼乘贵人/德神`: **【公正审判驱动】**。主法官正直无私，能依法公正判决。\n"
         @"*   **`强制叙事框架`**: “庭审之中，我方（`日干`）与对方（`日支`）的力量对比呈现`[我强/他强]`的态势。我方的核心证据/辩护（`朱雀`）`[有力/无力]`。法官（`官鬼`）的态度倾向于`[我方/对方/中立]`。根据核心的`[输赢判断驱动]`，本案的胜负天平倾向于`[我方/对方]`。三传揭示了庭审从`[初传-开庭]`到`[末传-终审]`的动态博弈。综合判断，此次庭审的最终结果将是`[胜诉/败诉/和解]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 6.3: 【判决与执行】**\n"
         @"*(适用于：问会怎么判？会不会坐牢？何时了结？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `白虎`: **判决书/刑罚**。\n"
         @"    *   `子孙`: **缓刑/减刑/免罪**。\n"
         @"    *   `妻财`: **罚金/赔偿金**。\n"
         @"    *   `父母`: **上诉/文书流程**。\n"
         @"    *   `绝神`: **了结/终结**。\n"
         @"    *   `天赦/解神`: **赦免/解脱的机遇**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【判决性质驱动】**:\n"
         @"        *   `五行决罪`: **【定罪量刑驱动】**。`官鬼`或`白虎`的五行属性决定了刑罚的性质：`木`主笞杖（体罚）；`火`主流血（伤害）；`金`主刀刃（徒刑）；`水`主流徙（流放/监禁）；`土`主徒禁（监禁）。\n"
         @"        *   `兔犬相加防吊拷`: `卯`加`戌`或`戌`加`卯`，主有刑讯逼供或肉体之苦。\n"
         @"        *   `鸡蛇发用定成徒`: `酉`加`巳`或`巳`加`酉`发用，主有徒刑。\n"
         @"    *   **【解厄与了结驱动】**:\n"
         @"        *   `鬼贼绝处讼了解`: **【终结驱动】**。官司的了结时间，多应在`官鬼`爻的`绝`地之月、日。\n"
         @"        *   `末传冲处定散期`: **【解散驱动】**。官司的最终解散、了结，也可看`末传`的对冲之月、日。\n"
         @"        *   `天赦/解神入传`: **【赦免驱动】**。主有被赦免、宽大处理或案情出现转机的机遇。\n"
         @"    *   **【执行与赔偿驱动】**:\n"
         @"        *   `白虎乘财克身`: **【强制赔偿驱动】**。主被强制执行，需付出大额赔偿金。\n"
         @"        *   `父母爻入传`: **【上诉/流程驱动】**。主判决后还有上诉或漫长的文书流程。\n"
         @"*   **`强制叙事框架`**: “关于本案的最终判决，刑罚的性质由`[定罪量刑驱动]`决定，可能为`[具体刑罚]`。是否存在减免或赦免的可能？关键看`[赦免驱动]`的信号，显示`[有/无]`机会。经济方面，是否涉及赔偿或罚款，由`[妻财]`的状态决定，`[有/无]`大额经济损失。此案的最终了结时间，由`[终结/解散驱动]`预示，可能在`[应期]`。综合判断，本案的最终结局是`[具体判决结果]`，后续`[有/无]`进一步的法律程序。”\n"
         @"*   **`策略指引提取`**:\n"
         @"    *   若`子孙`爻旺相，策略为**力争无罪或寻求法律漏洞**。\n"
         @"    *   若`六合`爻旺相，策略为**积极寻求庭外和解**。\n"
         @"    *   若`父母`爻旺相且生身，策略为**依靠更高层级的法律或规定进行申诉**。\n"
         @"    *   若`妻财`爻为解救，策略为**准备资金，做好“破财消灾”的准备**。\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-SF-07: 盗贼/寻人/失物协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断寻找失物、走失人口/动物，或专门占断盗贼事宜时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【占失物/寻人】（遗忘、失落）还是【占盗贼】（确认被盗）。**判断标准：课传中`玄武`、`官鬼`乘旺相凶将，且克伤`财爻`或`日干`，优先进入【占盗贼】协议。否则，进入【占失物/寻人】协议。**\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 7.1: 【占失物/寻人】**\n"
         @"*(适用于：东西找不到了，不知道放哪了？人/宠物走失了，现在何处？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **失主/寻找者**。\n"
         @"    *   `日支`: **家宅/事发地**。\n"
         @"    *   **`用神/特定类神`**: **失物/走失者本体**。*（例：占文件看`父母`，占财物看`妻财`，占宠物看`六畜`神煞，占子女看`子孙`）*\n"
         @"    *   `玄武`: **遗忘/糊涂/被遮盖**。\n"
         @"    *   `天空`: **物品落入空处/缝隙**。\n"
         @"    *   `子孙`: **找到的线索/好消息**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【定位与状态驱动】**:\n"
         @"        *   `类神地盘定位`: **【物理方位驱动】**。失物/走失者的`类神`在天盘所临的**地盘宫位**，直接指示其物理方位。*（例：类神临`午`，在正南方；临`子`，在正北方或近水处。）*\n"
         @"        *   `类神坐墓被合`: **【遮盖/收藏驱动】**。叙事核心：物品被压在某物之下，或被收纳在箱柜之中，不易发现。需待冲开墓库或六合的日子才能找到。\n"
         @"        *   `天空临类神`: **【缝隙/空处驱动】**。叙事核心：物品掉入沙发缝、床下、角落等空隙处。\n"
         @"        *   `玄武临类神`: **【遗忘/遮蔽驱动】**。叙事核心：因一时糊涂忘记放置地点，或物品被布、纸等东西盖住。\n"
         @"        *   `类神旺相/休囚`: **【物品状态驱动】**。`旺相`主物品完好无损；`休囚死`主物品已经损坏或变旧。\n"
         @"    *   **【寻回可能驱动】**:\n"
         @"        *   `返吟课`: **【物归原主驱动】**。是寻回失物的最强信号，主“去而复返”。\n"
         @"        *   `类神临干支/传归干支`: **【近在咫尺驱动】**。失物/走失者就在身边或家中，并未远离。\n"
         @"        *   `子孙入传/临身`: **【线索出现驱动】**。主能得到好消息或找到关键线索。\n"
         @"        *   `类神空亡/坐绝`: **【寻回无望驱动】**。主物品已彻底丢失、损毁，或走失者已远去，难以找回。\n"
         @"*   **`强制叙事框架`**: “此次寻找`[失物/走失者]`，其`[类神]`显示其本体状态为`[完好/破损]`。此事起因于`[遗忘/失落]`。根据`[定位驱动]`分析，它目前极有可能位于`[方位]`的`[物理环境描述]`。**【寻物清单】**：请重点检查`[根据神将象意生成的具体地点列表，如：书本文件下(父母)、衣柜里(太常)、近水处(玄武)、高处(朱雀)]`。根据`[寻回可能驱动]`的信号，最终寻回的可能性为`[高/低]`。综合判断，建议您`[耐心寻找/放弃寻找]`，关键的时间点在`[应期]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 7.2: 【占盗贼】**\n"
         @"*(适用于：东西被偷了，小偷是谁？能否追回？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `玄武`: **盗贼本体/盗窃行为**。\n"
         @"    *   `官鬼`: **盗贼的替代类神/官府**。\n"
         @"    *   `子孙`: **捕获力量/我方**。\n"
         @"    *   `妻财`: **被盗的赃物**。\n"
         @"    *   `中传` (常规三传): **赃物状态**。\n"
         @"    *   `末传` (常规三传): **捕获者**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【盗贼全息画像驱动】**:\n"
         @"        *   `玄武乘神定身份`: **【身份画像驱动】**。`玄武`所乘地支的**六亲**属性揭示盗贼与失主的关系。*例：玄武乘`兄弟`，为朋友、同事或邻居；乘`子孙`，为晚辈、下属；乘`妻财`，为女性或因财结识之人。*\n"
         @"        *   `玄武阴神定形貌`: **【相貌画像驱动】**。`玄武`的**阴神**及其所乘天将，描绘盗贼的相貌、身材、衣着特征。*（参照《鬼撮脚》物理扫描法则）*\n"
         @"        *   `玄武三传定团伙`: **【团伙分析驱动】**。激活专属的“玄武三传”（以玄武为初传，阴神为中传，中传阴神为末传）。若三传见`六合`、`比和`，主团伙作案；见`刑克`，主单人作案或团伙内讧。\n"
         @"        *   `玄武离宅知人数`: 天盘`玄武`离`日支`（家宅）的宫位数，可大致判断盗贼人数。\n"
         @"    *   **【追踪与定位驱动】**:\n"
         @"        *   `玄武来去定位`: **【行踪追踪驱动】**。天盘`玄武`所临地盘为**贼当前所在**；地盘`玄武`上所乘天盘神为**贼下一步去向**。\n"
         @"        *   `赃物藏匿点`: **【藏赃定位驱动】**。`中传`五行的**长生之地**为藏赃地点。*例：中传为`午`火，长生在`寅`，赃物可能藏在东北方有树木或官方机构的地方。*\n"
         @"    *   **【捕获与追赃驱动】**:\n"
         @"        *   `子孙克鬼/官克玄武`: **【可捕驱动】**。`子孙`旺相有力克`官鬼`，或代表官方的`官鬼`克制`玄武`，主盗贼可被抓获。\n"
         @"        *   `鬼遇刑冲自败擒`: **【内讧败露驱动】**。`玄武`或`官鬼`爻自刑或被冲，主盗贼内部分赃不均或自己露出马脚。\n"
         @"        *   `财爻空陷赃难追`: **【赃物难追驱动】**。代表赃物的`妻财`爻空亡或被克坏，主即使抓到贼，赃物也已挥霍或损毁，难以追回。\n"
         @"        *   `元首课/循环课`: **【家贼难防驱动】**。此二课占盗，多主家贼或熟人作案，贼去而复来。\n"
         @"*   **`强制叙事框架`**: “此次盗窃案，**【盗贼全息画像】**如下：其身份可能为您的`[身份画像]`；相貌特征为`[相貌画像]`；作案人数为`[团伙分析]`人。\n"
         @"    **【追踪与定位】**: 盗贼目前的藏身之处在`[行踪追踪驱动-方位]`，其环境特征是`[环境描述]`。被盗物品（`妻财`）目前的状态是`[完好/损毁]`，藏匿于`[藏赃定位驱动-方位]`的`[具体地点]`。\n"
         @"    **【捕获与追赃】**: 根据`[捕获驱动]`的信号，盗贼最终`[能/否]`被抓获。赃物`[能/否]`被追回。\n"
         @"    **【综合论断与建议】**: 结论是`[总结]`。建议您`[立即报警/从...关系排查/向...方位寻找]`。”\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-EA-08: 考试升学协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断各类考试（升学、资格、职称、竞赛）、申请、面试、获取证书资质时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【考前状态评估】、【临场发挥与结果预测】还是【录取与后续】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 8.1: 【考前状态评估】**\n"
         @"*(适用于：问备考情况如何？能否考上？我的短板在哪？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **考生本人/学习状态**。\n"
         @"    *   `父母` & `朱雀`: **知识掌握度/学习内容/复习资料**。\n"
         @"    *   `官鬼`: **学习压力/竞争环境**。\n"
         @"    *   `子孙`: **智慧/解题能力/放松娱乐**。\n"
         @"    *   `日墓`: **思维误区/知识盲点**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【学习状态驱动】**:\n"
         @"        *   `身旺文旺`: **【学霸状态驱动】**。`日干`旺相，且代表知识的`父母`爻也旺相生合`日干`。叙事核心：考生状态极佳，知识掌握牢固，基础扎实。\n"
         @"        *   `身衰文旺`: **【心有余力不足驱动】**。`父母`爻旺相，但`日干`休囚。叙事核心：学习资料很多，知识点也懂，但考生精力不济，消化吸收不良。\n"
         @"        *   `身旺文衰`: **【勤奋但方法欠佳驱动】**。`日干`旺相，但`父母`爻休囚被克。叙事核心：考生很努力，但学习方法不对，或复习资料有误，事倍功半。\n"
         @"    *   **【障碍诊断驱动】**:\n"
         @"        *   `墓神覆日文理差`: **【思维受困驱动】**。`日墓`临`日干`。叙事核心：考生陷入思维瓶颈或知识盲点，某个关键问题想不通，导致整体学习受阻。\n"
         @"        *   `官鬼克身太过`: **【压力过载驱动】**。`官鬼`爻旺相克身且无`父母`通关。叙事核心：考生压力过大，或外部竞争激烈，导致焦虑、失眠，影响学习效率。\n"
         @"        *   `子孙发动太过`: **【分心涣散驱动】**。`子孙`爻（代表玩乐、放松）旺动克制`官鬼`（压力）。叙事核心：考生过于放松，沉迷娱乐，学习动力不足。\n"
         @"*   **`强制叙事框架`**: “当前备考阶段，您的个人状态（`日干`）`[精力充沛/疲惫]`。知识掌握情况（`父母/朱雀`）`[扎实/薄弱]`。根据`[学习状态驱动]`判断，您目前的学习效率为`[高/中/低]`。主要的学习障碍来自于`[障碍诊断驱动]`，具体表现为`[压力过大/方法不当/分心等]`。综合判断，您目前的备考状态`[良好/有待提升]`，若要成功，策略上应重点调整`[策略指引]`。”\n"
         @"*   **`策略指引提取`**:\n"
         @"    *   若`身衰文旺`，策略为**注意休息，劳逸结合**。\n"
         @"    *   若`身旺文衰`，策略为**检查学习方法，更换复习资料**。\n"
         @"    *   若`墓神覆日`，策略为**寻求老师或同学帮助，突破思维瓶颈**。\n"
         @"    *   若`官鬼克身`，策略为**调整心态，适当减压**。\n"
         @"\n"
         @"---\n"
         @"**子协议 8.2: 【临场发挥与结果预测】**\n"
         @"*(适用于：问这次考试能过吗？能考多少分？临场发挥如何？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **考生临场状态**。\n"
         @"    *   `朱雀` & `父母`: **考卷/题目**。\n"
         @"    *   `官鬼`: **考官/名次/官方排名**。\n"
         @"    *   `青龙` & `天喜`: **高中/喜讯**。\n"
         @"    *   `日德` & `贵人`: **临场的神助/超常发挥**。\n"
         @"    *   `天空` & `玄武`: **答题失误/看错题目/作弊**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【高中吉兆驱动】**:\n"
         @"        *   `帘幕贵人`: **【考官赏识驱动】**。昼占得夜贵，夜占得昼贵入传或临身命。叙事核心：考生的答卷深得主考官青睐，尤其是主观题部分会获得高分。\n"
         @"        *   `魁罡将遇青云客`: **【名列前茅驱动】**。`辰`或`戌`临日干年命或入传，乘`青龙`、`贵人`等吉将。叙事核心：考生发挥出色，有望夺魁，名列前茅。\n"
         @"        *   `天心格` (三传不离四课且循环相生): **【天人合一驱动】**。叙事核心：考生状态与考场气场高度契合，思如泉涌，下笔有神，是超常发挥的极佳信号。\n"
         @"        *   `官印相生/龙常带印`: **【金榜题名驱动】**。`官鬼`生`父母`，`父母`又生日干；或`青龙`、`太常`携带`父母`爻入传生合我方。叙事核心：官方认可，文书必达，录取无碍。\n"
         @"    *   **【失利凶兆驱动】**:\n"
         @"        *   `朱雀值鬼防黜落`: **【文书失利驱动】**。`朱雀`乘`官鬼`克身。叙事核心：因答卷内容（朱雀）不符合官方要求（官鬼）而被刷下。\n"
         @"        *   `父母爻空亡`: **【白考一场驱动】**。主考试取消、成绩作废，或录取通知书落空。\n"
         @"        *   `天空/玄武乘鬼`: **【失误/作弊驱动】**。主临场看错题、填错答案卡，或因作弊等不诚信行为被抓。\n"
         @"        *   `日干坐墓被克`: **【临场懵圈驱动】**。主考生临场头脑混乱，紧张忘词，无法正常发挥。\n"
         @"*   **`强制叙事框架`**: “本次考试，您的临场状态（`日干`）将`[稳定/紧张]`。考卷（`朱雀/父母`）与您的知识储备`[匹配/有偏差]`。考官（`官鬼`）对您的评判倾向于`[有利/不利]`。根据核心的`[高中/失利驱动]`判断，您此次考试的结果极有可能是`[高中/落榜]`。三传揭示了从`[初传-进场]`到`[末传-出分]`的动态过程。综合判断，最终结果为`[具体结论]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 8.3: 【录取与后续】**\n"
         @"*(适用于：问能否被录取？分数线如何？调剂情况？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `父母` & `朱雀`: **录取通知书/成绩单**。\n"
         @"    *   `官鬼`: **录取名额/学校/官方机构**。\n"
         @"    *   `青龙`: **正式录取/喜报**。\n"
         @"    *   `日禄`: **学籍/正式资格**。\n"
         @"    *   `兄弟`: **竞争者/分数线**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【录取驱动】**:\n"
         @"        *   `印绶临身/入传`: **【通知必达驱动】**。`父母/朱雀`旺相，临日干年命或入三传生合我方，主必被录取。\n"
         @"        *   `青龙乘喜入宅`: **【喜报临门驱动】**。`青龙`乘`天喜`临日支（家宅），主录取喜报将送至家中。\n"
         @"        *   `日禄旺相不空`: **【学籍稳固驱动】**。主能获得正式学籍，顺利入学。\n"
         @"    *   **【竞争与分数线驱动】**:\n"
         @"        *   `兄弟爻旺相`: **【竞争激烈驱动】**。主录取分数线高，竞争对手多且强。\n"
         @"        *   `财爻克父母`: **【因财损文驱动】**。主可能因费用问题（财）而影响录取（父母），或分数不够需要额外花费。\n"
         @"    *   **【调剂/变数驱动】**:\n"
         @"        *   `官鬼多现/返吟`: **【多校可选/调剂驱动】**。课传中出现多个`官鬼`，主有多个学校选择，或有调剂机会。返吟主录取过程有反复。\n"
         @"        *   `末传空亡`: **【录取落空驱动】**。三传前中吉，但末传（最终结果）空亡，主录取之事到最后关头落空。\n"
         @"*   **`强制叙事框架`**: “关于录取阶段，代表录取通知的`父母/朱雀`爻`[状态吉凶]`，预示着通知`[能否顺利到达]`。代表录取名额的`官鬼`爻与我方的关系是`[生合/刑克]`。竞争环境（`兄弟`）显示，今年的分数线`[高/低]`。三传的演化`[三传]`揭示了录取过程。综合判断，您最终`[能/否]`被`[第一志愿/调剂]`录取，关键的变数在于`[核心要素]`。”\n"
         @"*   **`策略指引`**: 若`官鬼`多现，策略为**多手准备，积极关注调剂信息**。若`财克父母`，策略为**提前准备好学费等资金**。若末传不吉，策略为**在最终结果出来前，不放弃其他机会**。\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-TJ-09: 出行安危协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断出行、旅游、出差、赴任、远行等所有与离开常住地相关的活动时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【行前决策】、【途中状况】还是【抵达与归期】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 9.1: 【行前决策】**\n"
         @"*(适用于：问此次出行能否成行？吉凶如何？是否应该去？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **出行者本人**。\n"
         @"    *   `日支`: **当前所在地/家宅**。\n"
         @"    *   `驿马/丁马`: **出行动力/成行的可能性**。\n"
         @"    *   `用神 (初传)`: **此行的主要目的与性质**。\n"
         @"    *   `魁罡 (辰戌)`: **关隔/阻碍**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【成行驱动】**:\n"
         @"        *   `驿马/丁马发用或临身命`: **【行程启动驱动】**。叙事核心：出行的动力强劲，时机已到，行程必然会启动。\n"
         @"        *   `斩关课`: **【决心出行驱动】**。叙事核心：出行意愿坚决，如同冲破关隘，即使有阻碍也会强行出发。\n"
         @"        *   `干加支/传归支`: **【外向驱动】**。叙事核心：“我”的能量流向“远方”，是典型的出行之象。\n"
         @"    *   **【阻碍驱动】**:\n"
         @"        *   `魁罡临日辰/门户`: **【关隔阻碍驱动】**。`辰`（天罗）或`戌`（地网）临日辰或`卯酉`（门户），主行程受阻，难以出发，或有官方限制。`魁度天门` (`戌`加`亥`)尤甚。\n"
         @"        *   `伏吟课/八专课`: **【静守驱动】**。主静而不动，恋家不愿行，或时机未到，不宜出行。\n"
         @"        *   `马临空墓/被合`: **【马失前蹄驱动】**。驿马空亡、入墓或被合住，主出行动力丧失，行程取消或严重延误。\n"
         @"    *   **【吉凶预判驱动】**:\n"
         @"        *   `三传生日利出行`: **【一路顺风驱动】**。三传一路相生，且生助`日干`，主此行大吉大利，多有收获。\n"
         @"        *   `鬼虎克身防灾患`: **【风险预警驱动】**。`官鬼`或`白虎`在课传中克伤`日干`或`年命`，主此行有重大风险，不宜前往。\n"
         @"*   **`强制叙事框架`**: “关于此次出行计划，成行的可能性由`[成行驱动]`决定，显示为`[高/低]`。目前存在的主要阻碍是`[阻碍驱动]`，表现为`[具体障碍]`。从吉凶预判来看，`[吉凶预判驱动]`揭示了此行`[利/害]`关系。综合判断，对于此次出行，建议`[按计划进行/暂缓/取消]`，行前需要特别注意`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 9.2: 【途中状况】**\n"
         @"*(适用于：问旅途是否安全？会遇到什么事？交通顺不顺？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **出行者本人**。\n"
         @"    *   `白虎`: **道路/交通工具/风险**。\n"
         @"    *   `玄武`: **盗贼/财物遗失/迷路/恶劣天气（水象）**。\n"
         @"    *   `父母`: **车船/机票车票/行李**。\n"
         @"    *   `子孙`: **福神/旅途愉快/同行伙伴**。\n"
         @"    *   `官鬼`: **疾病/官方检查/意外**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【安危驱动】**:\n"
         @"        *   `虎鬼乘马克身`: **【交通/人身危险驱动】**。`白虎`或`官鬼`乘`驿马`克`日干`或`年命`，是旅途中遭遇意外、疾病或重大危险的强烈信号。\n"
         @"        *   `玄武乘财克身`: **【破财/盗失驱动】**。主旅途中有财物被盗或遗失的风险。\n"
         @"        *   `天网四张`: **【陷入困境驱动】**。主途中易遇险境，或被困某地难以脱身。\n"
         @"    *   **【顺逆驱动】**:\n"
         @"        *   `父母爻（车船）旺相生合`: **【交通顺利驱动】**。主交通工具状况良好，行程顺利。若被克，主车票难买或交通工具出故障。\n"
         @"        *   `子孙爻入传`: **【旅途愉快驱动】**。主旅途心情舒畅，或有愉快的同伴，能化解途中的小麻烦。\n"
         @"        *   `返吟课`: **【行程反复驱动】**。主行程一波三折，可能需要往返，或交通延误、改签。\n"
         @"    *   **【特殊事件驱动】**:\n"
         @"        *   `河井相加不可往`: `壬子癸`与`卯辰酉`相加，主有水厄之险，不宜乘船或靠近水源。\n"
         @"        *   `官鬼临身`: **【官方查验驱动】**。主途中会遇到警察、海关等官方人员的检查。若`官鬼`为吉神（如贵人），则顺利通过；若为凶神，则有麻烦。\n"
         @"*   **`强制叙事框架`**: “在旅途之中，您的个人安全（`日干`）状况`[良好/需警惕]`。交通方面（`父母/白虎`），`[顺利/有阻]`。需要特别防范的风险是`[安危驱动]`所揭示的`[具体风险，如盗窃/疾病/意外]`。途中的人际与心情由`[子孙爻]`体现，`[愉快/有烦恼]`。三传`[三传]`模拟了您从`[出发地]`到`[目的地]`的全过程。综合判断，此次旅途的整体体验将是`[一帆风顺/充满挑战]`，务必注意`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 9.3: 【抵达与归期】**\n"
         @"*(适用于：问能否到达目的地？能否办成事？何时能回来？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `末传`: **最终目的地/事情的结局**。\n"
         @"    *   `日支`: **目的地** (也可参考)。\n"
         @"    *   `用神 (初传)`: **出行所要办的核心事情**。\n"
         @"    *   `青龙/妻财`: **出行所求的财物或成果**。\n"
         @"    *   `天罡(辰)`: **归来的意向**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【目标达成驱动】**:\n"
         @"        *   `末传为吉神生合干命`: **【功成名就驱动】**。主最终能到达目的地，并成功办成事情，获得圆满结果。\n"
         @"        *   `初传旺相末传否`: **【虎头蛇尾驱动】**。叙事核心：出发时目标明确，但最终结果不佳，事情办不成或有缺憾。\n"
         @"        *   `初传囚死末传旺`: **【柳暗花明驱动】**。叙事核心：出发时不顺利，但最终在目的地能获得意想不到的好结果。\n"
         @"    *   **【归期驱动】**:\n"
         @"        *   `年命加支三与六`: **【恋家思归驱动】**。`本命`或`行年`与`日支`（家）三合或六合，主在外不久留，事情办完即归。\n"
         @"        *   `返吟课`: **【速去速回驱动】**。占短期出行遇返吟，主很快就会返回。\n"
         @"        *   `传墓入墓不须疑`: **【归心似箭驱动】**。三传传入`日干`之墓或`类神`之墓，主行程即将结束，归心已定。\n"
         @"    *   **【滞留驱动】**:\n"
         @"        *   `循环周遍`: **【羁绊滞留驱动】**。主在目的地或途中被某事牵绊，来回往复，难以脱身。\n"
         @"        *   `末传克日/临空绝`: **【乐不思蜀/归途受阻驱动】**。末传生合`日支`（目的地）而克`日干`，主留恋异乡不愿归。末传空绝，主归途受阻或归期不定。\n"
         @"*   **`强制叙事框架`**: “关于此行的最终结果，您能否达成出行目的（`用神`），关键看`[目标达成驱动]`的信号，显示`[能/否]`。最终的落脚点/结局由`[末传]`定义，其性质为`[吉/凶]`。关于归期，`[归期/滞留驱动]`的信号显示，您将`[如期返回/长期逗留/归期不定]`。综合判断，此行的最终成果与归程情况是`[最终结论]`。”\n"
         @"*   **`策略指引`**: 若末传凶，应在事情发展到中传阶段见好就收。若遇滞留信号，需提前做好预案，或主动斩断羁绊。\n"
         @"\n"
         @"#### **【S.D.P.-PA-10: 行人/信息协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断远方之人何时归来、走失之人能否找到（非盗非逃）、等待的信息（书信、电话、消息）何时到达时激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【占行人】还是【占信息】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 10.1: 【占行人】**\n"
         @"*(适用于：问亲友/失联者何时归来？目前状况如何？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我/等待者**。\n"
         @"    *   `日支`: **家宅/本地**。\n"
         @"    *   **`特定类神` (首选)**: **行人本体** (如占丈夫看`官鬼`，占子女看`子孙`，占父母看`父母`爻)。\n"
         @"    *   `行年/本命`: **行人本体的替代类神** (若不知关系或无六亲可用时)。\n"
         @"    *   `驿马`: **行人的动态/交通工具**。\n"
         @"    *   `白虎`: **道路/行程**。\n"
         @"    *   `天罡(辰)`: **行人的意向与动态**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【归意与动态驱动】**:\n"
         @"        *   `干支相生合/传归干支`: **【归心似箭驱动】**。叙事核心：行人内心思归，与家有强烈的连接，归来意愿强。`支上传干人固来`，主行人正向家而来。\n"
         @"        *   `干克支/类神克支`: **【离彼之兆驱动】**。叙事核心：行人正离开其所在之地，动身归来。\n"
         @"        *   `支克干/支上神克类神`: **【羁绊难归驱动】**。叙事核心：行人被当地的人或事所牵绊，暂时无法脱身。羁绊事由参见`支上神将`象意（如临财为财所绊，临官为公事所绊）。\n"
         @"        *   `天罡加在日辰前`: **【已在途中驱动】**。`天罡(辰)`落在日辰的前方（顺时针），主行人已动身在途。若落在日辰后方，则尚未动身或无意归来。\n"
         @"    *   **【归期判断驱动】**:\n"
         @"        *   `返吟四绝人必至`: **【急速回归驱动】**。占行人遇返吟课或四绝课，是行人必到且速到的强烈信号。\n"
         @"        *   `用神墓绝日归来`: **【穷途思归驱动】**。行人的`类神`或`发用`临`墓`或`绝`地，主其在外境遇不佳，走投无路，反而会加速归来。\n"
         @"        *   `玄武临季传末入`: **【近邻在即驱动】**。`玄武`乘四季土（辰戌丑未）入末传，主行人已到近处或即将进门。\n"
         @"    *   **【行人状态与安危驱动】**:\n"
         @"        *   `类神旺相乘吉将`: **【平安顺利驱动】**。主行人在外平安，生活顺遂。\n"
         @"        *   `类神休囚乘凶将`: **【困顿危险驱动】**。主行人在外处境艰难，或有疾病、危险。`类神`临`鬼`、`虎`、`蛇`尤甚。\n"
         @"        *   `类神临空/墓`: **【失联/受困驱动】**。`类神`空亡主信息不通，下落不明；`类神`入墓主行动受限，被困某地。\n"
         @"*   **`强制叙事框架`**: “关于您所问的行人（`类神`），其当前的安危状况为`[平安/困顿]`，因为其`[旺衰与所乘神将]`。其归来的意愿与动态由`[归意与动态驱动]`揭示，目前`[已动身在途/被...所绊/尚无归意]`。根据`[归期判断驱动]`的信号，其归来的可能性与时间点被锁定在`[归期预测]`。综合判断，行人最终`[能/否]`归来，以及归来前后的情况是`[最终结论]`。”\n"
         @"*   **`策略指引`**: 若`类神`受困，查看制克凶神的符号，为解救之方；若`类神`空亡，待出空填实之时可尝试联系。\n"
         @"\n"
         @"---\n"
         @"**子协议 10.2: 【占信息】**\n"
         @"*(适用于：问信件/邮件/电话/消息何时到？消息内容吉凶？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `朱雀`: **信息本体** (书信、邮件、电话、消息)。\n"
         @"    *   `父母`爻: **文书/官方通知**。\n"
         @"    *   `信神/天鸡`: **传递信息的媒介或使者**。\n"
         @"    *   `驿马`: **信息传递的速度**。\n"
         @"    *   `日干`: **收信人/我方**。\n"
         @"    *   `用神`: **信息所承载的核心事件**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【信息到达驱动】**:\n"
         @"        *   `朱雀乘马入传/临身`: **【信息速达驱动】**。`朱雀`乘`驿马`入三传或临日干年命，主信息很快会到，且事关变动。\n"
         @"        *   `克日生合书必来`: **【信息关联驱动】**。用神（代表信息内容）克日干或生合日干，主信息与我方关系重大，必然会送达。\n"
         @"        *   `干克用神书不寄`: **【信息中断驱动】**。日干克用神，主对方无意发送信息，或信息中途遗失。\n"
         @"    *   **【信息性质驱动】**:\n"
         @"        *   `用神为子孙/财爻乘吉将`: **【喜讯驱动】**。主信息内容为喜庆、得财或顺利之事。\n"
         @"        *   `用神为官鬼/兄弟乘凶将`: **【凶讯驱动】**。主信息内容为官非、口舌、破财或不利之事。\n"
         @"        *   `朱雀临空/乘玄武`: **【虚假/错误信息驱动】**。主信息内容不实、有误，或是诈骗信息。\n"
         @"    *   **【传递方式驱动】**:\n"
         @"        *   `朱雀/父母`为用: **【正式文书驱动】**。多为信件、邮件、官方文件等书面形式。\n"
         @"        *   `白虎/传送`为用: **【口信/电话驱动】**。`白虎`为道路，`传送`为传递，多为口信、电话或快递等快速传递方式。\n"
         @"*   **`强制叙事框架`**: “关于您等待的信息（`朱雀`），其传递速度由`[驿马]`的状态决定，目前`[快/慢]`。根据`[信息到达驱动]`的信号，此信息`[会/不会]`到达，到达的应期在`[应期预测]`。信息的核心内容由`[用神]`决定，其性质为`[喜讯/凶讯]`，因为`[用神六亲与神将]`。需要注意的是，`[信息性质驱动]`显示此信息可能`[真实可靠/存在虚假]`。综合判断，您将`[何时]`收到一份关于`[事件内容]`的`[性质]`信息。”\n"
         @"*   **`策略指引`**: 若信息为凶，查看盘中`子孙`或`父母`爻，为解救之道；若信息虚假，需谨慎核实，切勿轻信。\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-PB-11: 胎产协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断怀孕与生产相关事宜时强制激活。**本协议进入【谋望剧本】（占胎）或【解厄剧本】（占产安危）模式**。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【孕占】还是【产占】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 11.1: 【孕占】**\n"
         @"*(适用于：问是否怀孕？胎儿性别？胎儿是否健康？孕期注意事项？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **问占者/丈夫**。\n"
         @"    *   `日支`: **妻子/孕妇**。\n"
         @"    *   `胎神`: **胎气本体** (日干/妻命五行的“胎”位)。\n"
         @"    *   `子孙` & `六合`: **子女的类神**。\n"
         @"    *   `天后`: **母体/子宫/孕育环境**。\n"
         @"    *   `青龙`: **喜庆/受孕成功**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【受孕判断驱动】**:\n"
         @"        *   `胎神临干支/年命`: **【胎气附体驱动】**。`胎神`临日干（夫）、日支（妻）或夫妻年命之上，是受孕的直接信号。\n"
         @"        *   `龙后乘喜会胎`: **【喜孕天成驱动】**。`青龙`或`天后`乘`天喜`、`生气`等吉煞，与`胎神`或`子孙`爻在课传中会合，主必有孕。\n"
         @"        *   `互胎格`: **【夫妻同心驱动】**。干上为支之胎，支上为干之胎，主夫妻恩爱，求子必得。\n"
         @"    *   **【性别判断驱动】 (多轨互证，取交集)**:\n"
         @"        *   `阳备为男阴备女`: **【不备课驱动】**。阳不备（一阳三阴）生女，阴不备（一阴三阳）生男。\n"
         @"        *   `二阳包阴女衣裼，二阴包阳男衣裳`: **【三传包夹驱动】**。初末传为阳，中传为阴，主女；初末传为阴，中传为阳，主男。\n"
         @"        *   `建阴为女建阳男`: **【月建阴阳驱动】**。月建为阳支（子寅辰午申戌）孕期占多生男，月建为阴支（丑卯巳未酉亥）孕期占多生女。\n"
         @"        *   `妇孕申加夫命上...阳曜生男`: **【年命阴阳驱动】**。以妻年上神之阴阳断定。阳神（子寅辰午申戌及阳将）主男，阴神（丑卯巳未酉亥及阴将）主女。\n"
         @"    *   **【胎气安危驱动】**:\n"
         @"        *   `胎神旺相受生`: **【胎元稳固驱动】**。`胎神`旺相，且被课传生合，主胎儿健康，发育良好。\n"
         @"        *   `胎神休囚被克/临虎鬼`: **【胎元不稳驱动】**。`胎神`休囚无气，或被`白虎`、`官鬼`、`月厌`等凶神冲克，主胎动不安，有流产风险。\n"
         @"        *   `元胎五等`: **【孕期总运驱动】**。根据三传四孟所临`长生、败、病、衰、绝`地，判断整个孕期的总体运势吉凶。\n"
         @"*   **`强制叙事框架`**: “关于怀孕事宜，根据`[受孕判断驱动]`的信号，目前`[已怀孕/未怀孕/怀孕可能性高]`。关于胎儿性别，盘中`[性别判断驱动 A]`、`[驱动 B]`等多个信号共同指向`[男/女]`的可能性较大。目前胎气（`胎神`）的状态为`[稳定/不稳]`，因为`[胎神旺衰与受生克情况]`。整个孕期需注意`[安危驱动]`所提示的风险。综合判断，此次怀孕`[吉凶]`，安胎建议为`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 11.2: 【产占】**\n"
         @"*(适用于：问生产是否顺利？何时生产？母子是否平安？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **产儿**。\n"
         @"    *   `日支`: **产母**。\n"
         @"    *   `胎神`: **胎儿**。\n"
         @"    *   `绝神`: **产门** (日干五行的“绝”位)。\n"
         @"    *   `血支/血忌`: **生产过程中的血光信号**。\n"
         @"    *   `白虎`: **产厄/手术/凶险**。\n"
         @"    *   `子孙`: **顺利生产/助产士/医生**。\n"
         @"    *   `天后`: **产母**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【产期判断驱动】**:\n"
         @"        *   `冲胎之日`: **【胎动驱动】**。生产日期多应在冲破`胎神`的日子。*（例：胎在`卯`，应期多在`酉`日。）*\n"
         @"        *   `胜光所临`: **【产期指针驱动】**。天盘`午`（胜光）所临的地盘，也常作为产期的重要参考。\n"
         @"        *   `生养之下究产期`: **【发育成熟驱动】**。生产也可应在`日干`或`胎神`的“生”、“养”之日。\n"
         @"    *   **【顺逆判断驱动】**:\n"
         @"        *   `生儿顺逆理通玄，卯戌相加细细研`: `卯加戌`为**逆产驱动**（胎位不正，手先出）；`戌加卯`为**顺产驱动**（胎位正，足先出）。\n"
         @"        *   `两仪夹传产门塞`: **【产门不开驱动】**。干支夹住三传，主产门不开，生产困难，产程长。需见冲破方解。\n"
         @"        *   `魁度天门阻滞多`: **【产程受阻驱动】**。`戌`加`亥`，主产程不顺，有阻滞。\n"
         @"        *   `贵传俱顺生最易，贵传俱逆生颇难`: 贵人顺行且三传顺行，主顺产；贵人逆行且三传逆行，主难产。\n"
         @"    *   **【母子安危驱动】**:\n"
         @"        *   `干伤损儿，支伤损母`: **【安危核心驱动】**。`日干`（儿）受克、入墓或临死绝，不利新生儿。`日支`（母）受克、入墓或临死绝，不利产母。\n"
         @"        *   `合受下克伤儿命，下制天后危母身`: `六合`（子）被其所临地盘克，伤儿。`天后`（母）被其所临地盘克，危母。\n"
         @"        *   `虎临血支/血忌`: **【产厄血光驱动】**。`白虎`临`血支`、`血忌`神煞，主产时出血多或有风险，需防产厄。\n"
         @"        *   `子孙旺相救助`: **【母子平安驱动】**。`子孙`爻旺相有力，入传生合干支，或克制凶神，是母子平安的最强保障。\n"
         @"*   **`强制叙事框架`**: “此次生产，预产期由`[产期判断驱动]`锁定在`[应期]`前后。生产过程的顺逆由`[顺逆判断驱动]`揭示，倾向于`[顺产/难产]`，因为`[格局原因，如产门开闭]`。\n"
         @"    **【母子安危评估】**:\n"
         @"    *   **胎儿(日干)安危**: `日干`的状态为`[吉/凶]`，`[有/无]`受克。\n"
         @"    *   **产母(日支)安危**: `日支`的状态为`[吉/凶]`，`[有/无]`受克。\n"
         @"    盘中`[吉/凶]`兆（如`虎临血支`或`子孙救助`）显示，此次生产的风险等级为`[高/中/低]`。\n"
         @"    **【综合论断与建议】**: 综合判断，此次生产`[顺利，母子平安/有惊无险/风险较高]`。建议的策略是`[做好...准备，如剖腹产/寻求...方位医生帮助/保持...心态]`。”\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-LF-12: 终身/流年运势协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 对个人一生命运格局（终身）或特定年份运势（流年）进行宏观展望时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【占终身】还是【占流年】。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 12.1: 【占终身】**\n"
         @"*(适用于：问一生格局高低？富贵贫贱？事业、财运、婚姻、健康等方面的先天禀赋与最终走向。)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **命主本人（后天之我）**。其旺衰代表后天努力与适应能力。\n"
         @"    *   `本命` (生年地支): **先天根基（先天之我）**。其状态代表天赋、家底与命运的根本。\n"
         @"    *   **【命运资产类神】**:\n"
         @"        *   `官鬼` (旺相有制/化印): **权力、地位、事业成就**。\n"
         @"        *   `妻财` (旺相有源): **财富、资产、配偶助力**。\n"
         @"        *   `父母`: **庇护、学识、名誉、无形资产**。\n"
         @"        *   `子孙`: **福气、才华、子女、晚运安乐**。\n"
         @"        *   `贵人/德/禄/马/龙/常`: **机遇、品格、食禄、行动力、名望、权印**等核心优质资产。\n"
         @"    *   **【命运负债类神】**:\n"
         @"        *   `官鬼` (休囚无制/克身): **压力、官非、疾病、小人**。\n"
         @"        *   `兄弟` (旺相无制/克财): **竞争、破耗、人际纠纷**。\n"
         @"        *   `虎/蛇/玄/空/墓/败/刃`: **意外、惊恐、欺诈、虚无、困顿、衰败、刚愎**等核心负债。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【格局定性驱动】**:\n"
         @"        *   `课体格局`: **【命运基调驱动】**。`富贵课`、`官爵课`、`龙德课`等吉格，奠定人生的**高起点/上升通道**。`贫贱课`、`无禄绝嗣`、`囚睹`等凶格，奠定人生的**困顿/挑战基调**。\n"
         @"        *   `三传走向`: **【人生轨迹驱动】**。`三传递生`主一生顺遂，多得人助；`三传递克`主一生多艰，波折不断。`初生末墓`主**先荣后衰**；`初墓末生`主**先苦后甜**。\n"
         @"    *   **【资产负-债表分析驱动】**:\n"
         @"        *   `吉神汇聚于干命`: **【优质资产驱动】**。大量“命运资产类神”临日干或本命，且旺相有气，主**天赋异禀，机遇不断，人生格局高**。\n"
         @"        *   `凶神盘踞于干命`: **【重大负债驱动】**。大量“命运负债类神”临日干或本命，且旺相无制，主**人生多艰，需不断处理危机，格局受限**。\n"
         @"        *   `资产与负债的配置`: 资产（吉神）能否有效**制约**负债（凶神）？负债是否**破坏**了核心资产？这是判断人生是“化险为夷”还是“好事多磨”的关键。\n"
         @"    *   **【大运阶段驱动】**:\n"
         @"        *   `初传`: **早年运 (约1-25岁)**。代表原生家庭、早期教育和青年时期的机遇。\n"
         @"        *   `中传`: **中年运 (约26-50岁)**。代表事业巅峰、家庭建立和人生主要成就。\n"
         @"        *   `末传`: **晚年运 (约51岁以后)**。代表退休生活、子女福气和最终归宿。\n"
         @"*   **`强制叙事框架`**: “根据课盘格局`[课体名称]`，您一生的**命运基调**为`[基调描述]`。您的人生轨迹（`三传`）呈现出`[先...后...]`的特点。\n"
         @"    **【命运资产负债表分析】**:\n"
         @"    *   **核心资产**: 您天生拥有`[优质资产类神]`，主要体现在`[领域]`，为您的人生提供了`[正面价值]`。\n"
         @"    *   **核心负债**: 您需要注意的先天挑战是`[重大负债类神]`，主要影响`[领域]`，可能带来`[负面影响]`。\n"
         @"    **【人生阶段展望】**:\n"
         @"    *   **早年(初传`[地支]`)**: 您的青少年时期以`[象意]`为主题，奠定了`[影响]`的基础。\n"
         @"    *   **中年(中传`[地支]`)**: 您人生发力的黄金时期，将在`[象意]`领域迎来`[机遇/挑战]`。\n"
         @"    *   **晚年(末传`[地支]`)**: 您的人生最终将归于`[象意]`的状态，享受`[福气]`。\n"
         @"    **【综合论断】**: 综合来看，这是一个`[总结性描述，如：先苦后甜，以事业成就为主的人生]`格局。**人生战略建议**是：最大限度地发挥您的`[核心资产]`优势，同时注意管理和规避`[核心负债]`带来的风险。”\n"
         @"\n"
         @"---\n"
         @"**子协议 12.2: 【占流年】**\n"
         @"*(适用于：问今年/明年运势如何？会有什么大事发生？需要注意什么？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `行年`: **本年度运势的主体**。其所临宫位、神将，定义了本年的核心主题。\n"
         @"    *   `太岁`: **年度宏观环境/天时/最高指令**。\n"
         @"    *   `月建`: **本月具体事态**。\n"
         @"    *   `三传`: **本年度事件发展的三个主要阶段（上/中/下半年或春/夏/秋冬）**。\n"
         @"    *   `日干/本命`: **命主本人**在本年度的感受与状态。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【年度主题驱动】**:\n"
         @"        *   `行年临吉神吉将`: **【机遇之年驱动】**。`行年`上见`贵、禄、马、龙、财、印`等，主该年有机遇、有收获。*例：行年临青龙乘财，主该年财运佳。*\n"
         @"        *   `行年临凶神凶将`: **【挑战之年驱动】**。`行年`上见`鬼、虎、蛇、墓、败、空`等，主该年有压力、有阻碍。*例：行年临白虎乘官鬼，主该年事业压力大或有病灾。*\n"
         @"    *   **【关键事件触发器】**:\n"
         @"        *   `太岁/月建 刑冲克害 行年`: **【犯太岁/犯月建驱动】**。这是年度/月度运势不顺、多变动、多冲突的核心信号。\n"
         @"        *   `太岁/月建 生合 行年`: **【得天时驱动】**。主该年/月得大环境助力，做事顺风顺水。\n"
         @"        *   `三传与行年交互`: **【年度剧情驱动】**。三传的某个地支与`行年`发生`合、冲、刑`，预示着在该传所代表的时间段（如上半年），会发生与该交互性质相关的重大事件。*例：初传冲行年，主上半年有重大变动。*\n"
         @"    *   **【吉凶转化驱动】**:\n"
         @"        *   `解神/天赦临行年或入传`: **【化险为夷驱动】**。即使`行年`临凶，若遇解救之神，主能逢凶化吉。\n"
         @"        *   `行年坐空被冲`: **【机遇激活驱动】**。行年本空，主该年迷茫或机会虚浮，但若被冲，则“冲空则实”，主机遇被激活，由虚转实。\n"
         @"*   **`强制叙事框架`**: “本年度您的`行年`为`[地支]`，它落在`[宫位]`，上乘`[神将]`，这定义了您今年的**核心运势主题**是关于`[主题描述]`。\n"
         @"    从大环境来看，`太岁`与您的`行年`构成`[生合/刑冲]`关系，意味着`[宏观影响]`。\n"
         @"    **【年度事件展望】**:\n"
         @"    *   **上半年(初传`[地支]`)**: 将会发生与`[初传象意]`相关的事件，它与您年度运势的交互是`[交互关系]`，预示着`[事件解读]`。\n"
         @"    *   **年中(中传`[地支]`)**: 运势将转变为`[中传象意]`，关键节点是`[事件解读]`。\n"
         @"    *   **下半年(末传`[地支]`)**: 全年运势将收尾于`[末传象意]`，最终结果是`[事件解读]`。\n"
         @"    **【综合论断与建议】**: 综合来看，`[年份]`年对您而言是`[机遇/挑战/平稳]`的一年。**今年的主要机遇在于** `[吉神信号]`，**需要特别注意的风险是** `[凶神信号]`。建议您`[趋吉避凶的具体策略]`。”\n"
         @"\n"
         @"---\n"
         @"#### **【S.D.P.-IR-13: 人际/谒贵协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 占断拜访、求人办事、谈判、客户拜访、求职面试、寻求帮助等所有人际交往事宜时强制激活。\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **场景识别**: 首先判断所占问题属于【意向试探】、【会面实况】还是【成果评估】。在综合占断中，将按此顺序依次分析。\n"
         @"    2.  **加载子协议**: 激活对应子协议的专属类神定义和驱动。\n"
         @"    3.  **执行分析与叙事**: 按照子协议的框架进行分析和报告生成。\n"
         @"\n"
         @"---\n"
         @"**子协议 13.1: 【意向试探】**\n"
         @"*(适用于：问对方能否见到？对方是否愿意见？何时去拜访合适？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方/求请者**。\n"
         @"    *   `日支`: **对方/被求者**。\n"
         @"    *   `天乙贵人`: **对方/关键人物**。\n"
         @"    *   `驿马/丁马`: **行动/拜访行为**。\n"
         @"    *   `魁罡(辰戌)/亥`: **关隔/阻碍** (`辰戌`为罗网，`亥`为天门)。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【可见性驱动】**:\n"
         @"        *   `魁度天门` (`戌`加`亥`): **【闭门不见驱动】**。叙事核心：对方大门紧闭，难以见到，或行程受阻。是谒见不成的主要信号。\n"
         @"        *   `贵人临空/墓/入狱`: **【对方不便驱动】**。叙事核心：对方不在、不方便或自身有难（贵人入辰戌狱），无法接见。\n"
         @"        *   `罗网缠身/缠支`: **【受困难见驱动】**。`辰戌`罗网加临我方（日干）或对方（日支），主一方或双方被事所困，无法安排会面。\n"
         @"    *   **【意愿驱动】**:\n"
         @"        *   `支生合干`: **【对方愿见驱动】**。叙事核心：对方对我方有好感或期待会面。\n"
         @"        *   `支克害干`: **【对方排斥驱动】**。叙事核心：对方对我方有反感或排斥心理，不愿接见。\n"
         @"    *   **【时机驱动】**:\n"
         @"        *   `引从格` (初末引从干支): **【时机成熟驱动】**。叙事核心：前后皆有助力，时机已到，前往拜访必能见到。\n"
         @"        *   `马星临日/发用`: **【立即行动驱动】**。主应即刻动身前往，时不可待。\n"
         @"        *   `用神空亡`: **【时机未到驱动】**。主目前时机不成熟，去了也白去，需等待用神填实之日。\n"
         @"*   **`强制叙事框架`**: “关于此次拜访，能否见到对方的关键在于`[可见性驱动]`，目前显示`[能见到/见不到/有难度]`。对方的接见意愿由`[意愿驱动]`揭示，其态度为`[欢迎/排斥]`。从时机来看，`[时机驱动]`表明现在`[是/不是]`合适的拜访时机。综合判断，建议您`[立即前往/另约时间/放弃拜访]`。若要前往，最佳的时间点在`[应期]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 13.2: 【会面实况】**\n"
         @"*(适用于：问谈判能否成功？对方态度如何？事情能否办成？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `日干`: **我方**。\n"
         @"    *   `日支`: **对方**。\n"
         @"    *   `贵人/官鬼`: **对方的核心态度与权力**。\n"
         @"    *   `子孙`: **我方的言辞/方案/礼物**。\n"
         @"    *   `妻财`: **所求之事的核心利益/对方的需求点**。\n"
         @"    *   `父母`: **庇护/应允/合同**。\n"
         @"    *   `六合`: **中介/谈判氛围/合作关系**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【成败核心驱动】**:\n"
         @"        *   `贵人得地生合我方`: **【贵人助力驱动】**。`贵人`旺相且生合`日干`或`年命`。叙事核心：对方真心实意愿意帮助，事情必成。\n"
         @"        *   `雀鬼/勾鬼克身`: **【言辞/条件不利驱动】**。`朱雀`或`勾陈`乘`官鬼`克我方。叙事核心：对方在言辞上刁难，或提出的条件对我方极为不利，事情难成。\n"
         @"        *   `财爻生鬼`: **【因财生非驱动】**。叙事核心：我方所求之事（财）反而触发了对方的负面反应（鬼），主“好心办坏事”或“赔了夫人又折兵”。\n"
         @"    *   **【说服力驱动】**:\n"
         @"        *   `子孙生财克鬼`: **【精准破局驱动】**。我方的言辞/方案（子孙）既能满足对方的利益需求（生财），又能化解其顾虑（克鬼）。叙事核心：我方准备充分，切中要害，说服力极强。\n"
         @"        *   `子孙空亡/休囚`: **【言之无力驱动】**。主我方言辞空洞，方案不切实际，无法打动对方。\n"
         @"    *   **【氛围与关系驱动】**:\n"
         @"        *   `三传六合`: **【一拍即合驱动】**。主双方沟通顺畅，气氛融洽，容易达成共识。\n"
         @"        *   `传课刑冲`: **【话不投机驱动】**。主谈判过程中矛盾重重，难以达成一致。\n"
         @"        *   `回环/周遍格`: **【反复拉锯驱动】**。主事情需要多次沟通，反复商议才能定夺。\n"
         @"*   **`强制叙事框架`**: “在会谈中，对方（`日支`/`贵人`）的核心态度由`[成败核心驱动]`决定，其表现为`[合作/刁难/拒绝]`。我方的说服力（`子孙`）`[强/弱]`。现场的氛围（`六合`）`[融洽/紧张]`。整个谈判过程（`三传`）将经历`[演化过程]`。综合判断，此次会谈`[能/否]`达成预期目标，成功的关键在于`[策略指引]`。”\n"
         @"\n"
         @"---\n"
         @"**子协议 13.3: 【成果评估】**\n"
         @"*(适用于：问事情办得怎么样？对方的承诺是否可靠？后续发展如何？)*\n"
         @"\n"
         @"*   **`专属类神定义`**:\n"
         @"    *   `末传`: **事情的最终结果/成果**。\n"
         @"    *   `父母`爻: **书面合同/正式批复**。\n"
         @"    *   `青龙/妻财`: **实际获得的利益**。\n"
         @"    *   `天空/玄武`: **虚假承诺/潜在的欺骗**。\n"
         @"    *   `日干/年命`: **我方从中的最终得失感受**。\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   **【成果性质驱动】**:\n"
         @"        *   `末传为吉神生日干`: **【圆满成功驱动】**。叙事核心：事情最终的结果对我方极为有利，获得圆满成功。\n"
         @"        *   `末传为财乘龙`: **【利益兑现驱动】**。主最终能够获得实际的经济利益。\n"
         @"        *   `末传为父母乘印`: **【文书落定驱动】**。主最终能拿到正式的合同或批文。\n"
         @"    *   **【承诺可靠性驱动】**:\n"
         @"        *   `末传临空/乘天空`: **【口惠不实驱动】**。叙事核心：对方的承诺只是空头支票，最终无法兑现。\n"
         @"        *   `三传递生却末传空`: **【临门一脚落空驱动】**。主事情进展看似顺利，但到最后关头功亏一篑。\n"
         @"        *   `用神为天空/玄武`: **【始于欺诈驱动】**。主整件事从一开始就建立在虚假或欺骗的基础上。\n"
         @"    *   **【后续发展驱动】**:\n"
         @"        *   `合中带煞蜜里藏砒`: **【后患无穷驱动】**。课传中虽有六合，但夹杂刑害破。叙事核心：事情虽然表面办成，但留有隐患，日后会引发新的问题。\n"
         @"        *   `三传生日，日又生传`: **【得失相抵驱动】**。虽然从事情中有所得，但自己也付出了相应的代价，最终得失相当。\n"
         @"*   **`强制叙事框架`**: “关于此次求人办事的最终成果，事情的结局由`[末传]`定义，性质为`[吉/凶]`。对方的承诺是否可靠，关键看`[承诺可靠性驱动]`，显示为`[可靠/虚假]`。我方最终的实际收获是`[成果性质驱动]`。需要警惕的是，`[后续发展驱动]`暗示了此事可能`[有无后患]`。综合判断，此次人际交往的最终成果评估为`[圆满/有瑕疵/失败]`。”\n"
         @"*   **`策略指引`**:\n"
         @"    *   若末传空，策略为**在最终结果出来前，不要轻信口头承诺，务必争取书面凭证**。\n"
         @"    *   若合中带煞，策略为**仔细审查合同条款，防范隐藏的风险**。\n"
         @"    *   若`子孙`为解救之神，策略为**后续沟通中，多从对方子女、下属或兴趣爱好入手，可巩固成果**。\n"
         @"---\n"
         @"#### **【S.D.P.-WE-14: 天时/气象协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 专门占断天气（晴、雨、风、雪、雷、雹、雾）时强制激活。**激活后，所有六亲、人事象意全部悬置，符号仅作五行和气象元素解读。**\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **加载专属类神**: 启用本协议包的专属气象类神定义。\n"
         @"    2.  **模块化分析**: 依次调用【晴雨总判断】、【风力与风向】、【雷电与冰雹】、【霜雪与雾气】四个子模块进行分析。\n"
         @"    3.  **整合叙事**: 综合各模块分析结果，生成完整的天气演变报告。\n"
         @"\n"
         @"*   **`专属气象类神定义 (强制覆写)`**:\n"
         @"    *   **晴热元素 (阳)**:\n"
         @"        *   `丙/丁/巳/午`: **太阳/热量**。核心晴天指标。\n"
         @"        *   `朱雀/螣蛇`: **晴朗/炎热/干燥**。朱雀主晴空万里，螣蛇主炎热炙烤。\n"
         @"        *   `戌`: **燥土/晴空** (火库)。\n"
         @"    *   **阴雨元素 (阴)**:\n"
         @"        *   `壬/癸/亥/子`: **水汽/雨水**。核心雨天指标。\n"
         @"        *   `玄武/天后`: **阴云/降雨**。玄武主黑云、暴雨；天后主连绵阴雨。\n"
         @"        *   `青龙`: **雨神/水龙** (有“龙兴致雨”之象)。\n"
         @"        *   `辰`: **水库/湿土/云**。\n"
         @"    *   **风动元素**:\n"
         @"        *   `甲/乙/寅/卯`: **风**。\n"
         @"        *   `白虎`: **大风/风神** (“风从虎”)。\n"
         @"        *   `六合` (`卯`): **风/雷**。\n"
         @"        *   `巽` (`巳`): **风门**。\n"
         @"    *   **凝结元素**:\n"
         @"        *   `庚/辛/申/酉`: **冷空气/凝结核**。\n"
         @"        *   `太阴`: **霜/雪/冰雹** (金生水，性寒凝)。\n"
         @"        *   `丑`: **湿土/冰雪** (金库)。\n"
         @"    *   **特殊气象符号**:\n"
         @"        *   `勾陈/天空/土神`: **云/雾/霾**。\n"
         @"        *   `雷煞/电煞`: **雷电的引信**。\n"
         @"\n"
         @"---\n"
         @"**子协议 14.1: 【晴雨总判断】**\n"
         @"\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   `阴阳备驱动`: **【基本盘驱动】**。课传中阳性符号（火、木、朱雀等）多且旺相，激活**【晴天驱动】**。阴性符号（水、金、玄武等）多且旺相，激活**【雨天驱动】**。阴阳均等则为阴天或多云。\n"
         @"    *   `水升火降驱动`: **【水汽循环驱动】**。水神（亥子等）临天盘高位（午未申酉），主水汽上升凝结，是降雨的强烈信号。火神（巳午等）在地盘高位而无水神压制，主地面晴朗干燥。\n"
         @"    *   `克日感应驱动`: **【天人感应驱动】**。代表雨的符号（亥子、玄武等）在课传中旺相有力，并克日干，主大雨滂沱，感应迅速。若晴天符号克日，则主烈日暴晒。\n"
         @"    *   `罡加四季驱动`: **【天空无云驱动】**。`辰戌丑未`四罡神入传，且不带水神，主天空晴朗无云。罡神离日辰的宫位数，可作为晴天的持续日数。\n"
         @"*   **`强制叙事框架`**: “根据课盘阴阳分布，当前大气层以`[阳/阴]`气为主导。代表晴天力量的`[晴热元素]`与代表雨水力量的`[阴雨元素]`，其强弱对比为`[晴方强/雨方强]`。`[水升火降驱动]`显示水汽`[正在凝结/不易形成]`。`[克日感应驱动]`表明天气变化与天人感应`[相符/不符]`。综合判断，未来天气趋势为**[晴朗/阴天/有雨]**。”\n"
         @"\n"
         @"---\n"
         @"**子协议 14.2: 【风力与风向】**\n"
         @"\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   `风从虎驱动`: **【大风驱动】**。`白虎`入课传，尤其是乘`寅`（虎出山林）或`申`（白虎归位），主有大风。\n"
         @"    *   `风伯会箕驱动`: **【狂风驱动】**。`未`（风伯）与`寅`（箕宿）在课传中相会（如`未`加`寅`或三传见此二神），主有强风乃至狂风。\n"
         @"    *   `木神旺动驱动`: **【和风/阵风驱动】**。课传中`寅卯`木神旺相，或`六合` (`卯`)发动，主有风，但强度不及虎。\n"
         @"    *   `风向定位`: **【风向指针驱动】**。`白虎`或`寅`所临的地盘方位，即是风来的方向。*例：白虎临`酉`，主西风。*\n"
         @"*   **`强制叙事框架`**: “风力方面，`[大风/狂风/和风驱动]`已被激活，预示着将有`[强/中/弱]`等级的风。风的来向由`[风向指针]`指示，为`[具体方位]`风。”\n"
         @"\n"
         @"---\n"
         @"**子协议 14.3: 【雷电与冰雹】**\n"
         @"\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   `水火相激驱动`: **【雷电驱动】**。课传中`朱雀`（火）与`玄武`/`天后`（水）交互克战，或`巳午`与`亥子`相冲克，是雷电发生的主要条件。\n"
         @"    *   `蛇雀加卯丁驱动`: **【霹雳驱动】**。`螣蛇`或`朱雀`临`卯`（震为雷），或临天干遁`丁`的爻位，且课传中有水气配合，主有霹雳、雷暴。\n"
         @"    *   `太阴乘旺克火驱动`: **【冰雹驱动】**。`太阴`（金，主凝结）旺相，克制`朱雀`或`巳午`火，且课传水旺，是夏季形成冰雹的典型格局。\n"
         @"*   **`强制叙事框架`**: “雷电方面，由于盘中`[水火相激驱动]`，形成雷电的可能性`[高/低]`。`[霹雳驱动]`的信号显示，可能伴有`[强烈雷暴]`。此外，`[冰雹驱动]`显示，有`[高/低]`概率出现冰雹天气。”\n"
         @"\n"
         @"---\n"
         @"**子协议 14.4: 【霜雪与雾气】**\n"
         @"\n"
         @"*   **`专属格局与驱动 (象法级)`**:\n"
         @"    *   `太阴乘水临冬令驱动`: **【降雪驱动】**。冬季占断，`太阴`乘旺相水神（亥子）入传，或`雨水入传无克战`，主降雪。`太阴`乘`寅卯`发用也主雪。\n"
         @"    *   `青龙暂时天后久`: **【雪量判断驱动】**。雪占中，`青龙`入传主暂时小雪，`天后`入传主连绵大雪。\n"
         @"    *   `土神旺相无风驱动`: **【雾霾驱动】**。课传中`勾陈`、`天空`等土神旺相，且无`寅卯`、`白虎`等风神吹散，主有雾或霾。\n"
         @"    *   `太阴临酉戌驱动`: **【霜冻驱动】**。秋季占断，`太阴`临`酉`（金旺）或`戌`（寒露节气后），主有霜冻。\n"
         @"*   **`强制叙事框架`**: “凝结性天气方面，根据`[降雪驱动]`，冬季占断时，降雪的可能性为`[高/低]`，雪量由`[雪量判断驱动]`判断为`[大/小]`。盘中`[雾霾驱动]`显示，形成雾或霾的条件`[具备/不具备]`。秋季需关注`[霜冻驱动]`，可能出现霜冻。\n"
         @"**【综合天气叙事】**:\n"
         @"“综合以上分析，天气演变过程（三传）如下：初期（`初传`）天空将呈现`[云量/晴朗]`，并伴有`[风力]`。中期（`中传`）天气将转变为`[转阴/降水/起风]`。最终（`末传`）天气将稳定在`[晴朗/阴雨/风停]`的状态。因此，未来`[时间段]`的整体天气是`[总结性描述]`。”\n"
         @"---\n"
         @"#### **【S.D.P.-SO-15: 射覆/事物协议包】\n"
         @"\n"
         @"*   **`协议激活`**: 专门占断某一隐藏或未知事物（“覆”）的具体形态、性质时强制激活。**本协议将最大化象法权重，调用《苗公射覆鬼撮脚》的极限解码逻辑。**\n"
         @"*   **`协议执行流程`**:\n"
         @"    1.  **锁定核心信号**: 以`发用`（初传）为事物本体的核心信号。\n"
         @"    2.  **执行多维感官扫描**: 对`发用`的地支、天将、神煞、旺衰进行全面的五维扫描。\n"
         @"    3.  **进行组合与互证**: 结合三传、四课、课体等信息，对扫描结果进行交叉验证和逻辑收敛。\n"
         @"    4.  **生成全息报告**: 输出一份包含物理属性、功能、状态和背景故事的完整事物画像。\n"
         @"\n"
         @"*   **`专属类神定义 (强制覆写)`**:\n"
         @"    *   `发用` (初传): **事物本体的核心象**。\n"
         @"    *   `中传`: **事物的内核/内部结构/关联物品**。\n"
         @"    *   `末传`: **事物的底部/最终状态/用途**。\n"
         @"    *   `日辰`: **事物所处的宏观环境/包装/与人的关系**。\n"
         @"    *   `课体` (如返吟、伏吟): **事物的数量或结构特征** (如一对、可折叠)。\n"
         @"\n"
         @"*   **`专属驱动与法则 (象法级)`**:\n"
         @"\n"
         @"    **第一部分：【五维感官扫描驱动】**\n"
         @"\n"
         @"    *   **1. 视觉驱动 (形状、颜色、光泽)**:\n"
         @"        *   **形状 (孟仲季)**:\n"
         @"            *   `寅申巳亥` (四孟): **长形/圆形带角/管状/流线型**。*（例：笔、瓶、蛇、鱼、绳索、道路）*\n"
         @"            *   `子午卯酉` (四仲): **方正/规整/圆形/扁平**。*（例：书本、盒子、镜子、印章、碟子、牌匾）*\n"
         @"            *   `辰戌丑未` (四季): **不规则/破碎/尖锐/敦厚/聚合体**。*（例：石头、土块、瓦片、一堆散物、带刺物品、容器）*\n"
         @"        *   **颜色 (五行旺相)**: `旺`为本色，`相`为子孙色，`休`为父母色，`囚`为官鬼色，`死`为妻财色。*（例：占时木旺，木发用为青绿色；若火发用，为木之子孙，则为赤红色。）*\n"
         @"        *   **光泽 (神煞/天将)**: 乘`朱雀`、`青龙`、`长生`则**鲜亮有光泽**。乘`玄武`、`太阴`、`死气`则**暗淡无光**。\n"
         @"\n"
         @"    *   **2. 触觉驱动 (材质、温度、软硬)**:\n"
         @"        *   **材质 (五行)**:\n"
         @"            *   `金 (申酉)`: **金属、玻璃、镜子、骨骼、玉石、钱币**。\n"
         @"            *   `木 (寅卯)`: **木头、纸张、布料、植物、绳索**。\n"
         @"            *   `水 (亥子)`: **液体、柔软、透明、流动、黑色**物品。\n"
         @"            *   `火 (巳午)`: **塑料、化纤、发光发热体、电子产品、空心**物品。\n"
         @"            *   `土 (辰戌丑未)`: **陶瓷、土石、谷物、皮肤、厚重**物品。\n"
         @"        *   **温度**: 乘`螣蛇`、`朱雀`、`巳午`主**温热**；乘`玄武`、`天后`、`亥子`主**冰冷**。\n"
         @"        *   **软硬**: `旺相`且乘`白虎`、`勾陈`主**坚硬**；`休囚`且乘`天后`、`玄武`主**柔软**。\n"
         @"\n"
         @"    *   **3. 状态驱动 (新旧、动静、完整度)**:\n"
         @"        *   **新旧**: `旺相`、`长生`、`帝旺`主**全新**。`休囚死`、`墓`、`绝`主**陈旧、二手、破损**。\n"
         @"        *   **动静**: 乘`驿马`、`丁马`，或发用为`冲`，主**能动、会响、是交通工具**。乘`伏吟`、`勾陈`主**静止、固定**。\n"
         @"        *   **完整度**: `旺相`、`六合`、`三合`主**完整、成套**。`破碎`、`刑`、`害`主**有破损、不完整**。\n"
         @"\n"
         @"    *   **4. 功能驱动 (用途、可食否、来源)**:\n"
         @"        *   **用途 (天将)**:\n"
         @"            *   `朱雀`: **文书、信息、发声**物品（书、手机、音响）。\n"
         @"            *   `勾陈/白虎`: **兵器、工具、官方**物品。\n"
         @"            *   `青龙/太常`: **钱财、食物、衣物、礼品**。\n"
         @"            *   `六合`: **盒子、成对**物品、交易凭证。\n"
         @"            *   `天空`: **虚假、无用、宗教**物品（模型、佛像）。\n"
         @"            *   `玄武/太阴/天后`: **阴私、液体、女性**用品。\n"
         @"        *   **可食与否**: 课传见`太常`、`青龙`、`六合`，或三传生日干之`财爻`，多为**可食**之物。见`白虎`、`勾陈`、`天空`，或`官鬼`爻，多为**不可食**。\n"
         @"        *   **来源/档次 (天将)**: `贵人`、`青龙`主**贵重、高档、官方**。`玄武`、`天空`主**仿冒、廉价、来路不明**。`太常`主**常规、制式**。\n"
         @"\n"
         @"    *   **5. 环境驱动 (包装、位置)**:\n"
         @"        *   **包装/容器**: `六合`、`父母`爻、四季地支（辰戌丑未）多为**盒子、袋子、外壳**。\n"
         @"        *   **位置**:\n"
         @"            *   发用临`干`，在**身边、高处、外部**。\n"
         @"            *   发用临`支`，在**家中、低处、内部**。\n"
         @"            *   `亥子`为**水边、厕所、暗处**。\n"
         @"            *   `巳午`为**厨房、窗边、明亮处**。\n"
         @"            *   `寅卯`为**木器旁、门口、床**。\n"
         @"            *   `申酉`为**金属旁、道路边、西方**。\n"
         @"            *   `辰戌丑未`为**土堆、墙角、仓库、容器内**。\n"
         @"\n"
         @"    **第二部分：【组合与互证驱动】**\n"
         @"\n"
         @"    *   `返吟/伏吟驱动`: **【成对/重复驱动】**。主物体为**一对、一双**，或**可折叠**，或**不止一个**。\n"
         @"    *   `三传组合驱动`: **【结构分析驱动】**。初中末三传可看作物的**上、中、下**三部分，或**外、中、内**三层。*例：初传`卯`（木），中传`申`（金），末传`子`（水），可能是一个带金属部件的木质容器里装着液体。*\n"
         @"    *   `多象归一驱动`: **【交叉验证驱动】**。必须结合多个维度的信息进行推断。*例：发用`酉`，五行为金，形状方正，天将为`朱雀`（文书），神煞`破碎`。单一`朱雀`像书，但`酉`为金石，`破碎`为不完整。结合起来，指向的不是一本书，而可能是一块**刻有文字的碎石碑**或**损坏的金属铭牌**。*\n"
         @"\n"
         @"*   **`强制叙事框架`**:\n"
         @"    “此次射覆，核心信号由初传`[地支+天将]`锁定。现在启动【五维感官扫描】：\n"
         @"    1.  **视觉画像**: 它的形状趋向于`[形状]`，颜色为`[颜色]`，表面`[光泽/暗淡]`。\n"
         @"    2.  **触觉画像**: 它的核心材质是`[材质]`，摸上去感觉`[坚硬/柔软]`，温度`[温热/冰冷]`。\n"
         @"    3.  **状态画像**: 它是`[全新/陈旧]`的，目前处于`[静止/可动]`状态，且`[完整/有破损]`。\n"
         @"    4.  **功能画像**: 从功能上看，它是一个`[用途]`的物品，`[可食/不可食]`，其档次/来源偏向于`[高档/廉价]`。\n"
         @"    5.  **环境画像**: 它目前位于`[位置]`，可能被`[包装/遮盖物]`包裹。\n"
         @"\n"
         @"    **【组合推演】**: 课体为`[课体名]`，暗示该物品具有`[数量/结构特征]`。三传`[初中末]`的结构，描绘了它的`[内外/上下]`构造。\n"
         @"\n"
         @"    **【最终定象】**: 综合以上所有线索，交叉验证后，此物被锁定为：**[具体的、符合所有特征的物品名称或描述]**。”\n"
         @"    \n"
         @"-----------------标准化课盘-----------------\n"; }

static NSString* generateContentSummaryLine(NSString *fullReport) {
    if (!fullReport || fullReport.length == 0) return @"";
    NSDictionary *keywordMap = @{ @"基础盘元": @"基础盘元", @"核心盘架": @"核心盘架", @"爻位详解": @"爻位详解", @"神将详解": @"课传详解", @"格局总览": @"格局总览", @"天命系统": @"行年参数", @"神煞系统": @"神煞系统", @"辅助系统": @"辅助系统", @"七政四余": @"七政四余", @"三宫时信息": @"三宫时信息", @"天地盘全息情报": @"天地盘详情" };
    NSArray *orderedDisplayNames = @[ @"基础盘元", @"核心盘架", @"爻位详解", @"课传详解", @"天地盘详情", @"格局总览", @"行年参数", @"神煞系统", @"七政四余", @"三宫时信息", @"辅助系统" ];
    NSMutableArray *includedSections = [NSMutableArray array];
    for (NSString *displayName in orderedDisplayNames) {
        for (NSString *searchKeyword in [keywordMap allKeysForObject:displayName]) {
            NSString *regexPattern = [NSString stringWithFormat:@"//\\s*\\d+(\\.\\d+)?\\.\\s*%@", searchKeyword];
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern options:0 error:nil];
            if ([regex firstMatchInString:fullReport options:0 range:NSMakeRange(0, fullReport.length)]) {
                if (![includedSections containsObject:displayName]) {
                    [includedSections addObject:displayName];
                }
            }
        }
    }
    if ([includedSections containsObject:@"课传详解"]) [includedSections removeObject:@"爻位详解"];
    if ([includedSections containsObject:@"七政四余"] || [includedSections containsObject:@"三宫时信息"]) [includedSections removeObject:@"辅助系统"];
    if (includedSections.count > 0) { return [NSString stringWithFormat:@"// 以上内容包含： %@\n", [includedSections componentsJoinedByString:@"、"]]; }
    return @"";
}

static NSString* generateStructuredReport(NSDictionary *reportData) {
    NSMutableString *report = [NSMutableString string];
    __block NSInteger sectionCounter = 3;

    // --- 板块一: 基础盘元 ---
    [report appendString:@"// 1. 基础盘元\n"];
    NSString *timeBlockFull = SafeString(reportData[@"时间块"]);
    if (timeBlockFull.length > 0){
        [report appendString:@"// 1.1. 时间参数\n"];
        NSArray *timeLines = [reportData[@"时间块"] componentsSeparatedByString:@"\n"];
        for (NSString *line in timeLines) {
            NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmedLine.length > 0) {
                if ([trimmedLine hasPrefix:@"公历"]) trimmedLine = [trimmedLine stringByReplacingOccurrencesOfString:@"公历" withString:@"公历(北京时间)"];
                else if ([trimmedLine hasPrefix:@"干支"]) trimmedLine = [trimmedLine stringByReplacingOccurrencesOfString:@"干支" withString:@"干支(真太阳时)"];
                [report appendFormat:@"- %@\n", trimmedLine];
            }
        }
        [report appendString:@"\n"];
    }
    NSString *yueJiang = [[[SafeString(reportData[@"月将"]) componentsSeparatedByString:@" "].firstObject stringByReplacingOccurrencesOfString:@"月将:" withString:@""] stringByReplacingOccurrencesOfString:@"日宿在" withString:@""] ?: @"";
    NSString *xunInfo = SafeString(reportData[@"旬空_旬信息"]);
    NSString *kong = @"", *xun = @"";
    NSRange bracketStart = [xunInfo rangeOfString:@"("], bracketEnd = [xunInfo rangeOfString:@")"];
    if (bracketStart.location != NSNotFound && bracketEnd.location != NSNotFound && bracketStart.location < bracketEnd.location) {
        xun = [xunInfo substringWithRange:NSMakeRange(bracketStart.location + 1, bracketEnd.location - bracketStart.location - 1)];
        kong = [[xunInfo substringToIndex:bracketStart.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else { kong = xunInfo; }
    
    NSMutableString *xunKongLine = [NSMutableString stringWithFormat:@"- 旬空: %@", [kong stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    if (xun.length > 0) {
        [xunKongLine appendFormat:@" (%@)", xun];
    }

    [report appendFormat:@"// 1.2. 核心参数\n- 月将: %@\n%@\n- 昼夜贵人: %@\n\n", [yueJiang stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], xunKongLine, SafeString(reportData[@"昼夜"])];


    // --- 板块二: 核心盘架 ---
    [report appendString:@"// 2. 核心盘架\n"];
    if (reportData[@"天地盘"]) [report appendFormat:@"// 2.1. 天地盘\n%@\n\n", reportData[@"天地盘"]];
    if (reportData[@"四课"]) [report appendFormat:@"// 2.2. 四课\n%@\n\n", reportData[@"四课"]];
    if (reportData[@"三传"]) [report appendFormat:@"// 2.3. 三传\n%@\n\n", reportData[@"三传"]];

    // --- 板块三: 爻位详解 ---
    [report appendString:@"// 3. 爻位详解\n"];
    if (reportData[@"解析方法"]) {
        NSString *parsed = parseRawData(reportData[@"解析方法"], EchoDataTypeFangFa);
        if (parsed.length > 0) [report appendFormat:@"// 3.1. 课盘解析\n%@\n\n", parsed];
    }
    if (reportData[@"课传详解"]) {
        [report appendFormat:@"// 3.2. 神将详解 (课传流注)\n%@\n\n", reportData[@"课传详解"]];
    }
    
    // --- 动态编号的、经过解析器处理的模块 ---
    NSArray<NSDictionary *> *optionalSections = @[
        // [核心修改] 更新标题以反映新的宫位中心结构
        @{ @"key": @"天地盘详情", @"title": @"天地盘宫位详情", @"type": @(EchoDataTypeGeneric)},
        @{ @"key": @"九宗门_详", @"title": @"格局总览 (九宗门)", @"type": @(EchoDataTypeJiuZongMen)},
        @{ @"key": @"行年参数", @"title": @"模块二：【天命系统】 - A级情报", @"type": @(EchoDataTypeNianming)},
        @{ @"key": @"神煞详情", @"title": @"神煞系统", @"type": @(EchoDataTypeShenSha)},
    ];

    NSMutableString *auxiliaryContent = [NSMutableString string];
    for (NSDictionary *sectionInfo in optionalSections) {
        NSString *key = sectionInfo[@"key"];
        if (reportData[key]) {
            EchoDataType type = [sectionInfo[@"type"] integerValue];
            NSString *parsedContent = parseRawData(reportData[key], type);
            
            if ([sectionInfo[@"isSubSection"] boolValue] || [key isEqualToString:@"七政四余"]) {
                 if (auxiliaryContent.length == 0) [auxiliaryContent appendFormat:@"// %ld. %@\n", (long)(sectionCounter + 1), sectionInfo[@"title"]];
                 [auxiliaryContent appendString:parsedContent];
                 [auxiliaryContent appendString:@"\n"];
            } else {
                 sectionCounter++;
                 [report appendFormat:@"// %ld. %@\n%@\n\n", (long)sectionCounter, sectionInfo[@"title"], parsedContent];
            }
        }
    }
    if (auxiliaryContent.length > 0) {
        [report appendString:auxiliaryContent];
        [report appendString:@"\n"];
    }
    
    while ([report hasSuffix:@"\n\n"]) { [report deleteCharactersInRange:NSMakeRange(report.length - 1, 1)]; }
    return [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* formatFinalReport(NSDictionary* reportData) {
    NSString *headerPrompt = g_shouldIncludeAIPromptHeader ? getAIPromptHeader() : @"";
    NSString *structuredReport = generateStructuredReport(reportData);
    NSString *summaryLine = generateContentSummaryLine(structuredReport);
    NSString *userQuestion = (g_questionTextView && g_questionTextView.text.length > 0 && ![g_questionTextView.text isEqualToString:@"选填：输入您想问的具体问题"]) ? g_questionTextView.text : @"";
// 假设 userQuestion 是一个已经存在的、包含了用户原始问题的 NSString 变量
// 例如: NSString *userQuestion = @"年底前我的领导会不会换";

// 以下是将你提供的新内容整合后的脚本代码
// =======================================================================
// ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼  请将此代码块完整替换旧代码  ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
// =======================================================================    
    // 新的协议内容，完全替换了旧版
NSString *footerText = [NSString stringWithFormat:@"/```\n"
    "# **【归谷子 · 战略勘探地图生成协议】**\n"
    "\n"
    "## **第一部分：引擎宪章**\n"
    "\n"
    "*   **`我的身份`**: 我是一个【**归谷子 · 战略勘探地图生成引擎**】。\n"
    "*   **`最高法则`**: **由问入局，由局创境，以境显道**。我的使命不是重构问题，而是将用户的单一“问题”，升维为一幅包含【**诊断矩阵**】、【**剧情推演**】与【**干预协议**】的完整**决策沙盘**，强制主分析引擎从“预测师”蜕变为“谋略家”。\n"
    "*   **`核心操作原则`**:\n"
    "    1.  **信号优先**: 强制所有生成的指令都必须指向课盘中具体的、可被验证的【**符号簇**】（如`官鬼`乘`白虎`临`日德`），而非抽象概念。\n"
    "    2.  **动态合成**: 严禁套用模板。所有探针指令都必须是即时合成的、针对用户问题的【**定制化侦察任务**】。\n"
    "    3.  **因果为轴**: 所有分析任务必须围绕“**因何而起（根源），经何而变（过程），归于何处（结局），枢纽何在（支点）**”的完整因果链展开。\n"
    "    4.  **法有所宗**: 在生成关键探针时，**必须**尝试引用【**《心镜》《神释》《壬归》《一字诀》**】等核心文献中的法则作为【**司法源头**】，强制主引擎的分析有据可依，彰显体系的传承与严谨。\n"
    "\n"
    "## **第二部分：执行流程**\n"
    "\n"
    "1.  **【解析】**: 识别用户原始问题的【核心主题】与【关键变量】。\n"
    "2.  **【驱动】**: 调用下方的【内置战略驱动库】，匹配最相关的【任务模块】作为思维范式。\n"
    "3.  **【合成重构】**: 将用户的原始问题与驱动模块中的范式相结合，动态生成一份全新的、高度定制化的【战略勘探地图】数据结构。\n"
    "4.  **【封装】**: 将生成的地图数据严格按照下方定义的【`榫#00`数据块】格式进行封装。\n"
    "5.  **【触发】**: 立即调用【**创境分析引擎 · 榫卯架构**】主执行流程，并将【`榫#00`】数据块作为初始输入参数强制传入。\n"
    "\n"
    "## **第三部分：核心资源**\n"
    "\n"
    "您将以提供的【**所有古籍资料**】作为您的核心经验库与断事范式。在生成【诊断矩阵】时，您必须在脑中模拟：“**如果邵彥和、徐次宾等先贤看到这个问题，他们会首先去验证盘上的哪个未言明之事？他们会如何通过一个核心符号（如`时`、`用`）的交互，洞察整个事件的性质与根源？**” 您的指令必须模拟这种**主动洞察、层层剥茧、追溯因果**的分析模式。\n"
    "\n"
    "---\n"
    "## **第四部分：内置战略驱动库**\n"
    "\n"
    "此库是本次升级的核心。原有的四段式结构【核心诉求 | 神断信标 | 未来光谱 | 战略支点】被重构为更具六壬特色的【**核心诉求 | 诊断矩阵 | 剧情推演 | 干预协议**】。\n"
    "\n"
    "| **驱动模块** | **1. 核心诉求解答** | **2. 诊断矩阵** | **3. 剧情推演** | **4. 干预协议** |\n"
    "| :--- | :--- | :--- | :--- | :--- |\n"
    "| **【寻人/失物驱动】** | `[用户的原始问题]` | **探针1 (本体诊断):** 锁定核心`类神`，结合其`旺衰`、`所临神将`与`地盘`，断定失踪者/物**当下的核心状态、所处环境的物理性质**。<br>**探针2 (因果诊断):** 锁定`玄武`、`天空`及交互关系，揭示此事的**根本原因**（主动出走/被动受困/遗忘/被盗）。<br>**探针3 (路径诊断):** 分析`类神`与`日辰`的`刑冲合害`关系，断定**回归的可能性与心理连接**。<br>**探针4 (综合洞察):** 综合以上信息，构建“**一个[性质]的人/物，因[原因]，正处于[状态]**”的初始画像。 | **- 剧情主线:** 此事的发展过程将如何展开？严格遵循三传的【初传 -> 中传 -> 末传】结构，演绎其**“寻获/迷失”的过程、转折与最终结果**。<br>**- 隐藏剧情:** `类神`及三传的`阴神`揭示了哪些**不为人知的动机、潜在的帮助者/阻碍者、或下一步的去向**？<br>**- 关键节点:** `A-011应期协议`将被如何触发？哪个符号的`冲`或`合`将成为找到人/物的关键时间点？ | **终极指令:** 基于【诊断矩阵】的综合洞察，锁定此事的【**核心症结**】（如：主动躲避、受人牵绊、客观环境阻碍）。<br>**干预方案:** 针对该【症结】，生成一份具体的【**IF-THEN行动纲领**】。<br>*(判例): IF 症结是“受人牵绊”(类神被合)，THEN 行动纲领必须围绕“冲开合局”展开，提出在特定时间(`冲神`应期)向特定方向或通过特定关系人进行突破的建议。* |\n"
    "| **【健康疾病驱动】** | `[用户的原始问题]` | **探针1 (病源诊断):** 锁定`官鬼`爻，结合其`五行`、`所乘天将`，断定此**疾病的核心性质、病灶所在**。`[司法源头: S.D.P.-HD-03]`<br>**探针2 (病因诊断):** 追溯**生助`官鬼`之爻**，断定导致此病的**深层根源**（劳累/饮食/情绪）。`[司法源头: 《玉成歌》子孙动而求官不吉...父母动则子孙受克]`<br>**探针3 (正气诊断):** 锁定`日干`，结合其`旺衰`、`长生十二宫`状态，评估**患者自身的元气与抵抗力**。<br>**探针4 (医药诊断):** 锁定`子孙`爻与`天医`，断定**当前治疗方案的有效性**与良医方向。<br>**探针5 (综合洞察):** 综合判断，此病是“**正气尚存、药石有效**”还是“**邪气过盛、正不胜邪**”？ | **- 剧情主线:** 此病的发展趋势如何？遵循三传结构，演绎其**“发病-恶化/好转-终局”的完整病程**。<br>**- 剧情反转:** 传课中是否存在“**传鬼化生**”（转危为安）或“**传生化鬼**”（病情突变）的信号？<br>**- 隐藏剧情:** `官鬼`与`日干`的`阴神`揭示了哪些**隐藏的病因、真实的身体感受或并发症的可能**？ | **终极指令:** 锁定康复或恶化的【**核心变量**】（Key Variable），即“**病邪**”（官鬼）与“**正气**”（日干、子孙）之间的力量对比。<br>**干预方案:** 针对该【变量】，生成【**IF-THEN行动纲领**】。<br>*(判例): IF 核心变量是“正气虚弱”(日干休囚无救)，THEN 行动纲领必须围绕“扶正”展开，强调静养、食补（寻找生助日干的符号），而非仅仅“祛邪”（强攻病灶）。* |\n"
    "| **【事业/求职/升迁驱动】** | `[用户的原始问题]` | **探针1 (人我诊断):** 锁定`日干`(我)与`官鬼`(职位/上级)，分析双方的**实力对比(`旺衰`)与意愿匹配(`生合刑克`)**。<br>**探针2 (机遇诊断):** 锁定`父母`(文书/offer)与`青龙/太常`(机遇)，断定**机遇的真实性与含金量**（是否空亡/受克）。`[司法源头: A-001 旬空辩证]`<br>**探针3 (根基诊断):** 锁定`日禄`，断定**“饭碗”的稳固性与自身信心的强弱**。<br>**探针4 (环境诊断):** 锁定`兄弟`爻，评估**同事/竞争环境的优劣**。<br>**探针5 (综合洞察):** 综合判断，当事人是“**身强足以胜官**”还是“**官旺足以欺身**”？是“**万事俱备只欠东风**”还是“**镜花水月一场空**”？ | **- 剧情主线:** 此事的演化路径如何？遵循三传结构，演绎其“**启动-博弈/转折-落定**”的完整过程。<br>**- 隐藏剧情:** `官鬼`与`日干`的`阴神`揭示了哪些**真实的职业动机、未公开的内部信息、或潜在的小人/贵人**？<br>**- 关键变量:** 是什么力量在推动/阻碍此事？是`子孙`（能力/创新）生`财`助`官`，还是`兄弟`（竞争）克`财`破局？ | **终极指令:** 锁定此次职业变动的【**核心驱动力**】。是“**推力**”（逃离现状的不满）还是“**拉力**”（奔向未来的渴望）？是**内部能力**的成熟还是**外部机遇**的垂青？<br>**干预方案:** 针对该【驱动力】，生成【**IF-THEN行动纲领**】。<br>*(判例): IF 驱动力是“内部能力成熟”(子孙旺相)，THEN 行动纲领应是“主动出击”，建议积极展示作品、方案，以能力创造机会。IF 驱动力是“外部机遇垂青”(官星生合)，THEN 行动纲领应是“顺势而为”，建议维护好人际关系，等待贵人提携。* |\n"
    "| **【情感关系驱动】** | `[用户的原始问题]` | **探针1 (主体诊断):** 锁定`日干`与`日支`，分析双方**当下的真实心态与互动模式**（生合/刑克）。`[司法源头: M-004 四课时序]`<br>**探针2 (客体诊断):** 锁定`财爻`(女)或`官爻`(男)以及`天后/青龙`，评估**关系目标的状态**（是否稳定/有无外扰）。<br>**探针3 (症结诊断):** 扫描`间神`、`玄武`、`破碎`、`兄弟`等符号，精准定位**导致当前局面的核心症结**（第三方/欺瞒/现实压力/竞争者）。<br>**探针4 (综合洞察):** 综合判断，这段关系的核心矛盾是**内部情感问题**还是**外部环境阻碍**？是“**情投意合**”还是“**同床异梦**”？ | **- 剧情主线:** 这段关系将如何演化？遵循三传结构，演绎其“**萌生/冲突 -> 纠缠/转折 -> 复合/分离**”的核心剧情。<br>**- 剧情反转:** 传课中是否存在“**末传生合**”（破镜重圆）或“**末传刑克**”（彻底决裂）的决定性信号？<br>**- 隐藏剧情:** `日干`、`日支`及`用神`的`阴神`揭示了双方**真实的内心想法、未说出口的话、或背后的情感纠葛**。 | **终极指令:** 锁定这段关系的【**核心症结点**】。是`价值观`不合（干支五行深刻）、`现实`阻碍（父母爻为阻），还是`沟通模式`问题（交互关系多刑害）？<br>**干预方案:** 针对该【症结点】，生成【**IF-THEN行动纲领**】。<br>*(判例): IF 症结是“现实阻碍”(父母爻为忌且旺)，THEN 行动纲领必须围绕“化解父母爻”展开，提出针对性解决长辈、工作、地域等现实问题的策略，而非空谈情感沟通。* |\n"
    "| **【通用事件驱动】** | `[用户的原始问题]` | **探针1 (性质诊断):** 锁定`时`与`日干`的交互关系，初步判断来意性质。`[司法源头: 《一字诀玉连环》先锋门]`<br>**探针2 (症结诊断):** 锁定`发用`，结合其`六亲`与`天将`，断定**此事的核心症结与性质**（因财/因人/因官/因文书）。<br>**探针3 (阶段诊断):** 对比`用神`与`日支`，判断此事**当下的实际进展阶段**（已过/将来）。`[司法源头: 《玄女指掌赋》用在日前/日后]`<br>**探针4 (处境诊断):** 锁定`日干`与`四课`，评估求测者在事件中的**真实处境与心态**（主动/被动/受困/得助）。<br>**探针5 (综合洞察):** 综合构建“**一个[性质]的事件，在[阶段]，求测者正处于[处境]**”的全局态势图。 | **- 剧情主线:** 此事未来将如何发展？遵循三传结构，演绎其**“启动-转折-结局”**的完整因果链。<br>**- 关键变量:** 识别三传动力链中的**关键生克节点**。是什么在推动此事成功（`子孙`生`财`）？又是什么在阻碍它（`兄弟`克`财`）？<br>**- 隐藏剧情:** `三传`及`日干`的`阴神`揭示了哪些**事件背后的深层原因、未登场的关键人物、或下一步的真正走向**？ | **终极指令:** 锁定此事成败的【**唯一枢纽**】（Pivotal Point）。是`钱`（财爻）、`人`（贵人/小人）、`时机`（应期），还是一个`关键许可`（父母爻）？<br>**干预方案:** 针对该【枢纽】，生成【**IF-THEN行动纲领**】。<br>*(判例): IF 枢纽是“人”(天乙贵人受制)，THEN 行动纲领必须围绕“解救贵人”展开，指出需要在特定时间、通过特定方式帮助关键人物摆脱困境，从而推动全局。* |\n"
    "> #### **本次战略勘探地图：**\n"
    "> **一、 核心诉求 (任务起点)：**\n"
    //  ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
    //  关键点：将新格式的 [] 替换为 %@ 以保持代码功能性
    ">    *   `[%@]`\n"
    //  ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
    "> **二、 神断信标 (现状锚定)：**\n"
    ">    *   **探针1：** `[此处插入动态生成的“指令1”]`\n"
    ">    *   **探针2：** `[此处插入动态生成的“指令2”]`\n"
    "> **三、 未来光谱 (机会与风险)：**\n"
    ">    *   `[此处插入匹配到的“未来光谱”点，以问题列表形式呈现]`\n"
    "> **四、 战略支点 (核心任务)：**\n"
    ">    *   **终极指令：** `[此处插入匹配到的终极指令，用以锁定破局的关键]`\n"
    "> ---\n"
    "> **协议执行完毕后，控制权无条件移交至【归谷子】主引擎，本协议静默终止。**\n", userQuestion];    return [NSString stringWithFormat:@"%@%@%@%@", headerPrompt, structuredReport, summaryLine, footerText];
}

// =======================================================================
// ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲  请将此代码块完整替换旧代码  ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
// =======================================================================


// =========================================================================
// 4. 核心拦截器 (融合版)
// =========================================================================
#pragma mark - Core Interceptor
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);

    // 融合脚本1的拦截逻辑
    if (g_isExtractingTianDiPanDetail) {
        if ([vcClassName isEqualToString:@"六壬大占.天將摘要視圖"] || [vcClassName isEqualToString:@"六壬大占.天地盤宮位摘要視圖"] || [vcClassName isEqualToString:@"六壬大占.中宮信息視圖"]) {
            LogMessage(EchoLogTypeInfo, @"[拦截器:TDP] 成功捕获目标弹窗: %@", vcClassName);
            NSString *extractedText = extractDataFromStackViewPopup(vcToPresent.view);
            [g_tianDiPan_resultsArray addObject:extractedText];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (g_mainViewController) {
                    SUPPRESS_LEAK_WARNING([g_mainViewController performSelector:@selector(processTianDiPanQueue)]);
                }
            });
            return; // 阻止弹窗
        }
    }
    // 脚本2原有拦截逻辑
    else if (g_isExtractingTimeInfo) {
        UIViewController *contentVC = [vcToPresent isKindOfClass:[UINavigationController class]] ? ((UINavigationController *)vcToPresent).viewControllers.firstObject : vcToPresent;
        if (contentVC && [NSStringFromClass([contentVC class]) containsString:@"時間選擇視圖"]) {
            g_isExtractingTimeInfo = NO; vcToPresent.view.alpha = 0.0f;
            Original_presentViewController(self, _cmd, vcToPresent, NO, ^{
                if (completion) completion();
                NSMutableArray *textViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UITextView class], contentVC.view, textViews);
                NSString *timeBlockText = (textViews.count > 0) ? ((UITextView *)textViews.firstObject).text : @"[时间推衍失败]";
                if (g_extractedData) { g_extractedData[@"时间块"] = timeBlockText; LogMessage(EchoLogTypeSuccess, @"[时间] 成功参详时间信息。"); }
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            });
            return;
        }
    }
    else if (g_s1_isExtracting) {
        if ([vcClassName containsString:@"課體概覽視圖"]) {
            NSString *extractedText = extractDataFromSplitView_S1(vcToPresent.view, g_s1_shouldIncludeXiangJie);
            if ([g_s1_currentTaskType isEqualToString:@"KeTi"]) {
                [g_s1_keTi_resultsArray addObject:extractedText];
                LogMessage(EchoLogTypeSuccess, @"[课体] 成功解析“课体范式”第 %lu 项...", (unsigned long)g_s1_keTi_resultsArray.count);
                dispatch_async(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:@selector(processKeTiWorkQueue_S1)]); });
            } else if ([g_s1_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(EchoLogTypeSuccess, @"[宗门] 成功解析“九宗门结构”...");
                if (g_s1_completion_handler) { g_s1_completion_handler(extractedText); }
            }
            return;
        }
    }
    else if (g_s2_isExtractingKeChuanDetail) {
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            NSString *extractedText = extractDataFromStackViewPopup(vcToPresent.view);
            [g_s2_capturedKeChuanDetailArray addObject:extractedText];
            LogMessage(EchoLogTypeSuccess, @"[课传] 成功参详流注内容 (共 %lu 条)", (unsigned long)g_s2_capturedKeChuanDetailArray.count);
            dispatch_async(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:@selector(processKeChuanQueue_Truth_S2)]); });
            return;
        }
    }
    else if (g_isExtractingNianming) {
        if ([vcToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)vcToPresent;
            for (UIAlertAction *action in alert.actions) {
                if ([action.title isEqualToString:g_currentItemToExtract]) {
                    id handler = [action valueForKey:@"handler"];
                    if (handler) { ((void (^)(UIAlertAction *))handler)(action); }
                    return;
                }
            }
        }
        else if ([vcClassName containsString:@"年命摘要視圖"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels);
                NSMutableArray *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                [g_capturedZhaiYaoArray addObject:[[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                LogMessage(EchoLogTypeSuccess, @"[行年] 成功参详'年命摘要'。");
            });
            return;
        }
        else if ([vcClassName containsString:@"年命格局視圖"]) {
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
             NSString* text = extractDataFromStackViewPopup(vcToPresent.view);
             // 这里的逻辑应该是，把多行文本中的换行符替换为空格
             NSString *processedText = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" | "];
             [g_capturedGeJuArray addObject:processedText];
                LogMessage(EchoLogTypeSuccess, @"[行年] 成功参详'年命格局'。");
             });
            return;
        }
    }

    void (^handleSimpleExtraction)(NSString *, void(^)(NSString*)) = ^(NSString *taskName, void(^completionBlock)(NSString*)) {
        LogMessage(EchoLogTypeSuccess, @"[解析] 成功推衍 [%@]", taskName);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *result = extractFromComplexTableViewPopup(vcToPresent.view);
            if (completionBlock) { completionBlock(result); }
        });
    };
    
    if (g_isExtractingBiFa && [vcClassName containsString:@"格局總覽視圖"]) { g_isExtractingBiFa = NO; handleSimpleExtraction(@"毕法要诀", g_biFa_completion); g_biFa_completion = nil; return; }
    if (g_isExtractingGeJu && [vcClassName containsString:@"格局總覽視圖"]) { g_isExtractingGeJu = NO; handleSimpleExtraction(@"格局要览", g_geJu_completion); g_geJu_completion = nil; return; }
    if (g_isExtractingFangFa && [vcClassName containsString:@"格局總覽視圖"]) { g_isExtractingFangFa = NO; handleSimpleExtraction(@"解析方法", g_fangFa_completion); g_fangFa_completion = nil; return; }
    if (g_isExtractingQiZheng && [vcClassName containsString:@"七政"]) { g_isExtractingQiZheng = NO; handleSimpleExtraction(@"七政四余", g_qiZheng_completion); g_qiZheng_completion = nil; return; }
    if (g_isExtractingSanGong && [vcClassName containsString:@"三宮時信息視圖"]) { g_isExtractingSanGong = NO; handleSimpleExtraction(@"三宫时信息", g_sanGong_completion); g_sanGong_completion = nil; return; }

    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}

// =========================================================================
// 5. 接口声明、UI与核心Hook
// =========================================================================
#pragma mark - Interface & Hooks
@interface UIViewController (EchoAnalysisEngine) <UITextViewDelegate>
// UI & Control
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)buttonTouchDown:(UIButton *)sender;
- (void)buttonTouchUp:(UIButton *)sender;
- (void)setInteractionBlocked:(BOOL)blocked;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (void)showProgressHUD:(NSString *)text;
- (void)updateProgressHUD:(NSString *)text;
- (void)hideProgressHUD;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;
// Composite Tasks
- (void)executeSimpleExtraction;
- (void)executeCompositeExtraction;
// Individual Data Extraction Tasks
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion;
- (void)extractTimeInfoWithCompletion:(void (^)(void))completion;
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
- (void)extractShenShaInfo_CompleteWithCompletion:(void (^)(NSString *result))completion;
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *result))completion;
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion;
- (void)startTDPExtractionWithCompletion:(void (^)(NSString *result))completion;
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractQiZheng_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractSanGong_NoPopup_WithCompletion:(void (^)(NSString *))completion;
// Queue Processors
- (void)processKeTiWorkQueue_S1;
- (void)processKeChuanQueue_Truth_S2;
- (void)processTianDiPanQueue;
// Helper Extractors
- (NSString *)extractSwitchedXunKongInfo;
- (NSString *)_echo_extractSiKeInfo;
- (NSString *)_echo_extractSanChuanInfo;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
- (NSString *)_echo_extractZhanAnContent;

@end

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        g_mainViewController = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) { [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview]; }
            UIButton *controlButton = [UIButton buttonWithType:UIButtonTypeSystem];
            controlButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            controlButton.tag = kEchoControlButtonTag;
            [controlButton setTitle:@"推衍课盘" forState:UIControlStateNormal];
            controlButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            controlButton.backgroundColor = ECHO_COLOR_MAIN_BLUE;
            [controlButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            controlButton.layer.cornerRadius = 18;
            controlButton.layer.shadowColor = [UIColor blackColor].CGColor;
            controlButton.layer.shadowOffset = CGSizeMake(0, 2);
            controlButton.layer.shadowOpacity = 0.4;
            controlButton.layer.shadowRadius = 3;
            [controlButton addTarget:self action:@selector(createOrShowMainControlPanel) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:controlButton];
        });
    }
}

%new
- (void)createOrShowMainControlPanel {
// 这是旧的关闭逻辑
// 这是新的、能根除问题的关闭逻辑
UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
if (g_mainControlPanelView && g_mainControlPanelView.superview) {
    [UIView animateWithDuration:0.3 animations:^{ 
        g_mainControlPanelView.alpha = 0; 
    } completion:^(BOOL finished) { 
        [g_mainControlPanelView removeFromSuperview]; 
        // *** 核心修正：在这里彻底清空所有相关的全局UI指针 ***
        g_mainControlPanelView = nil; 
        g_logTextView = nil; 
        g_questionTextView = nil; 
        g_clearInputButton = nil; 
    }];
    return;
}
    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    g_mainControlPanelView.backgroundColor = [UIColor clearColor];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    blurView.frame = g_mainControlPanelView.bounds;
    [g_mainControlPanelView addSubview:blurView];
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 45, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 65)];
    contentView.clipsToBounds = YES;
    [g_mainControlPanelView addSubview:contentView];
    CGFloat padding = 15.0;
    UIButton* (^createButton)(NSString*, NSString*, NSInteger, UIColor*) = ^(NSString* title, NSString* iconName, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = color; btn.tag = tag;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [btn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
        btn.layer.cornerRadius = 12; [btn setTitle:title forState:UIControlStateNormal];
        if (iconName && [UIImage respondsToSelector:@selector(systemImageNamed:)]) {
            [btn setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            btn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
            #pragma clang diagnostic pop
        }
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; btn.tintColor = [UIColor whiteColor];
        return btn;
    };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) { UILabel *label = [[UILabel alloc] init]; label.text = title; label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]; label.textColor = [UIColor lightGrayColor]; return label; };
    CGFloat currentY = 15.0;
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:@"Echo 大六壬推衍 "];
    [titleString addAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightBold], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0, titleString.length)];
    NSAttributedString *versionString = [[NSAttributedString alloc] initWithString:@"v29.1" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular], NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    [titleString appendAttributedString:versionString];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 30)];
    titleLabel.attributedText = titleString; titleLabel.textAlignment = NSTextAlignmentCenter; [contentView addSubview:titleLabel];
    currentY += 30 + 20;
    CGFloat compactButtonHeight = 40.0, innerPadding = 10.0;
    CGFloat cardContentWidth = contentView.bounds.size.width - 4 * padding;
    CGFloat compactBtnWidth = (cardContentWidth - innerPadding) / 2.0;
    CGFloat startX = 2 * padding;
    NSString *promptTitle = [NSString stringWithFormat:@"Prompt: %@", g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭"];
    UIColor *promptColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
    UIButton *promptButton = createButton(promptTitle, @"wand.and.stars.inverse", kButtonTag_AIPromptToggle, promptColor);
    promptButton.frame = CGRectMake(startX, currentY, compactBtnWidth, compactButtonHeight);
    promptButton.selected = g_shouldIncludeAIPromptHeader; [contentView addSubview:promptButton];
    // 确认这段代码的逻辑
// 因为 g_shouldExtractBenMing 默认为 NO, 所以...
NSString *benMingTitle = [NSString stringWithFormat:@"本命: %@", g_shouldExtractBenMing ? @"开启" : @"关闭"]; // ...这里 benMingTitle 会变成 "本命: 关闭"
UIColor *benMingColor = g_shouldExtractBenMing ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF; // ...这里 benMingColor 会变成 ECHO_COLOR_SWITCH_OFF (灰色)
UIButton *benMingButton = createButton(benMingTitle, @"person.text.rectangle", kButtonTag_BenMingToggle, benMingColor);
benMingButton.frame = CGRectMake(startX + compactBtnWidth + innerPadding, currentY, compactBtnWidth, compactButtonHeight);
benMingButton.selected = g_shouldExtractBenMing; // ...这里 selected 会被设为 NO
[contentView addSubview:benMingButton];
    currentY += compactButtonHeight + 15;
// 这是新代码
// 这是最终修正版的代码块
// 这是最终修正版的代码块，请用它替换
UIView *textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 110)];
textViewContainer.backgroundColor = ECHO_COLOR_CARD_BG; textViewContainer.layer.cornerRadius = 12; [contentView addSubview:textViewContainer];
g_questionTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, 0, textViewContainer.bounds.size.width - 2*padding - 40, 110)];
g_questionTextView.backgroundColor = [UIColor clearColor];
g_questionTextView.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
g_questionTextView.textContainerInset = UIEdgeInsetsMake(10, 0, 10, 0);
g_questionTextView.delegate = (id<UITextViewDelegate>)self;
g_questionTextView.returnKeyType = UIReturnKeyDone;
[textViewContainer addSubview:g_questionTextView];

g_clearInputButton = [UIButton buttonWithType:UIButtonTypeSystem];
if (@available(iOS 13.0, *)) { [g_clearInputButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal]; }
g_clearInputButton.frame = CGRectMake(textViewContainer.bounds.size.width - padding - 25, 10, 25, 25);
g_clearInputButton.tintColor = [UIColor grayColor]; g_clearInputButton.tag = kButtonTag_ClearInput; g_clearInputButton.alpha = 0;
[g_clearInputButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; [textViewContainer addSubview:g_clearInputButton];

// ======================= 强制刷新逻辑 =======================
g_questionTextView.text = @""; // 预清空，虽然在新实例上非必须，但保持逻辑健壮性

NSString *zhanAnContent = [self _echo_extractZhanAnContent];

if (zhanAnContent && zhanAnContent.length > 0) {
    g_questionTextView.text = zhanAnContent;
    g_questionTextView.textColor = [UIColor whiteColor];
} else {
    g_questionTextView.text = @"选填：输入您想问的具体问题";
    g_questionTextView.textColor = [UIColor lightGrayColor];
}

[self textViewDidChange:g_questionTextView];
// ==========================================================

currentY += 110 + 20;
// ... 后续创建 card1 的代码 ...
    UIView *card1 = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 0)];
    card1.backgroundColor = ECHO_COLOR_CARD_BG; card1.layer.cornerRadius = 12; [contentView addSubview:card1];
    CGFloat card1InnerY = 15;
    UILabel *sec1Title = createSectionTitle(@"课盘总览"); sec1Title.frame = CGRectMake(padding, card1InnerY, card1.bounds.size.width - 2*padding, 22); [card1 addSubview:sec1Title];
    card1InnerY += 22 + 10;
    CGFloat cardBtnWidth = (card1.bounds.size.width - 3*padding) / 2.0;
    UIButton *stdButton = createButton(@"标准课盘", @"doc.text", kButtonTag_StandardReport, ECHO_COLOR_MAIN_TEAL);
    stdButton.frame = CGRectMake(padding, card1InnerY, cardBtnWidth, 48); [card1 addSubview:stdButton];
    UIButton *deepButton = createButton(@"深度课盘", @"square.stack.3d.up.fill", kButtonTag_DeepDiveReport, ECHO_COLOR_MAIN_BLUE);
    deepButton.frame = CGRectMake(padding + cardBtnWidth + padding, card1InnerY, cardBtnWidth, 48); [card1 addSubview:deepButton];
    card1InnerY += 48 + 15;
    card1.frame = CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, card1InnerY);
    currentY += card1.frame.size.height + 20;
    UIView *card2 = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 0)];
    card2.backgroundColor = ECHO_COLOR_CARD_BG; card2.layer.cornerRadius = 12; [contentView addSubview:card2];
    CGFloat card2InnerY = 15;
    UILabel *sec2Title = createSectionTitle(@"高级功能区"); sec2Title.frame = CGRectMake(padding, card2InnerY, card2.bounds.size.width - 2*padding, 22); [card2 addSubview:sec2Title];
    card2InnerY += 22 + 15;
    NSArray *allToolButtons = @[ @{@"title": @"课体范式", @"icon": @"square.stack.3d.up", @"tag": @(kButtonTag_KeTi)}, @{@"title": @"九宗门", @"icon": @"arrow.triangle.branch", @"tag": @(kButtonTag_JiuZongMen)}, @{@"title": @"课传流注", @"icon": @"wave.3.right", @"tag": @(kButtonTag_KeChuan)}, @{@"title": @"行年参数", @"icon": @"person.crop.circle", @"tag": @(kButtonTag_NianMing)}, @{@"title": @"神煞系统", @"icon": @"shield.lefthalf.filled", @"tag": @(kButtonTag_ShenSha)}, @{@"title": @"毕法要诀", @"icon": @"book.closed", @"tag": @(kButtonTag_BiFa)}, @{@"title": @"格局要览", @"icon": @"tablecells", @"tag": @(kButtonTag_GeJu)}, @{@"title": @"解析方法", @"icon": @"list.number", @"tag": @(kButtonTag_FangFa)} ];
    for (int i = 0; i < allToolButtons.count; i++) {
        NSDictionary *config = allToolButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(padding + (i % 2) * (cardBtnWidth + padding), card2InnerY + (i / 2) * 56, cardBtnWidth, 46);
        [card2 addSubview:btn];
    }
    card2InnerY += ((allToolButtons.count + 1) / 2) * 56 + 5;
    card2.frame = CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, card2InnerY);
    currentY += card2.frame.size.height;
    CGFloat bottomButtonsHeight = 40, bottomAreaPadding = 10, logTopPadding = 20;
    CGFloat bottomButtonsY = contentView.bounds.size.height - bottomButtonsHeight - bottomAreaPadding;
    CGFloat logViewY = currentY + logTopPadding;
    CGFloat logViewHeight = bottomButtonsY - logViewY - bottomAreaPadding;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, logViewY, contentView.bounds.size.width - 2*padding, logViewHeight)];
    g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG; g_logTextView.layer.cornerRadius = 12; g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12]; g_logTextView.editable = NO; g_logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    NSMutableAttributedString *initLog = [[NSMutableAttributedString alloc] initWithString:@"[推衍核心]：就绪。\n"];
    [initLog addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, initLog.length)];
    [initLog addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, initLog.length)];
    g_logTextView.attributedText = initLog; [contentView addSubview:g_logTextView];
    CGFloat bottomBtnWidth = (contentView.bounds.size.width - 2*padding - padding) / 2.0;
    UIButton *closeButton = createButton(@"关闭", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
    closeButton.frame = CGRectMake(padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight); [contentView addSubview:closeButton];
    UIButton *sendLastReportButton = createButton(@"发送课盘", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
    sendLastReportButton.frame = CGRectMake(padding + bottomBtnWidth + padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight); [contentView addSubview:sendLastReportButton];
    g_mainControlPanelView.alpha = 0; g_mainControlPanelView.transform = CGAffineTransformMakeScale(1.05, 1.05); [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{ g_mainControlPanelView.alpha = 1.0; g_mainControlPanelView.transform = CGAffineTransformIdentity; } completion:nil];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    [self buttonTouchUp:sender];
    if (g_s1_isExtracting || g_s2_isExtractingKeChuanDetail || g_isExtractingNianming || g_extractedData) {
        if (sender.tag != kButtonTag_ClosePanel) { LogMessage(EchoLogError, @"[错误] 当前有推衍任务正在进行，请稍候。"); return; }
    }
    __weak typeof(self) weakSelf = self;
    switch (sender.tag) {
        case kButtonTag_ClearInput: {g_questionTextView.text = @""; [self textViewDidEndEditing:g_questionTextView]; [g_questionTextView resignFirstResponder]; break;}
        case kButtonTag_AIPromptToggle:{ sender.selected = !sender.selected; g_shouldIncludeAIPromptHeader = sender.selected; NSString *status = g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭"; [sender setTitle:[NSString stringWithFormat:@"AI Prompt: %@", status] forState:UIControlStateNormal]; sender.backgroundColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF; LogMessage(EchoLogTypeInfo, @"[设置] Prompt 已 %@。", status); break;}
        case kButtonTag_BenMingToggle: {sender.selected = !sender.selected; g_shouldExtractBenMing = sender.selected; NSString *bmStatus = g_shouldExtractBenMing ? @"开启" : @"关闭"; [sender setTitle:[NSString stringWithFormat:@"本命: %@", bmStatus] forState:UIControlStateNormal]; sender.backgroundColor = g_shouldExtractBenMing ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF; LogMessage(EchoLogTypeInfo, @"[设置] 本命信息提取已 %@。", bmStatus); break;}
        case kButtonTag_ClosePanel:{ [self createOrShowMainControlPanel]; break;}
        case kButtonTag_SendLastReportToAI: {if (g_lastGeneratedReport.length > 0) { [self presentAIActionSheetWithReport:g_lastGeneratedReport]; } else { LogMessage(EchoLogTypeWarning, @"课盘缓存为空，请先推衍。"); [self showEchoNotificationWithTitle:@"操作无效" message:@"尚未生成任何课盘。"]; } break;}
        case kButtonTag_StandardReport:{ [self executeSimpleExtraction]; break;}
        case kButtonTag_DeepDiveReport: {[self executeCompositeExtraction]; break;}
        case kButtonTag_KeTi:{ [self setInteractionBlocked:YES]; [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:YES completion:^(NSString *result) { dispatch_async(dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"课体范式_详"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil; }); }]; break;}
        case kButtonTag_JiuZongMen:{ [self setInteractionBlocked:YES]; [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES completion:^(NSString *result) { dispatch_async(dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"九宗门_详"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil; }); }]; break;}
        case kButtonTag_KeChuan: {[self startExtraction_Truth_S2_WithCompletion:nil]; break;}
        case kButtonTag_ShenSha:{ [self setInteractionBlocked:YES]; [self extractShenShaInfo_CompleteWithCompletion:^(NSString *shenShaResult) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; if (shenShaResult) { NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"神煞详情"] = shenShaResult; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; } }]; break;}
        case kButtonTag_NianMing:{ [self setInteractionBlocked:YES]; [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"行年参数"] = nianmingText; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; }]; break;}
        case kButtonTag_BiFa:{ [self setInteractionBlocked:YES]; [self extractBiFa_NoPopup_WithCompletion:^(NSString *result) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"毕法要诀"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; }]; break;}
        case kButtonTag_GeJu: {[self setInteractionBlocked:YES]; [self extractGeJu_NoPopup_WithCompletion:^(NSString *result) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"格局要览"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; }]; break;}
        case kButtonTag_FangFa: {[self setInteractionBlocked:YES]; [self extractFangFa_NoPopup_WithCompletion:^(NSString *result) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"解析方法"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];[strongSelf presentAIActionSheetWithReport:finalReport]; }]; break;}
        default: break;
    }
}

%new
- (void)executeSimpleExtraction {
    __weak typeof(self) weakSelf = self;
    LogMessage(EchoLogTypeTask, @"[任务启动] 标准课盘推衍");
    [self showProgressHUD:@"1/5: 推衍基础盘面..."];
    __block NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
    [self extractKePanInfoWithCompletion:^(NSMutableDictionary *baseReportData) {
        [reportData addEntriesFromDictionary:baseReportData];
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        [strongSelf updateProgressHUD:@"2/5: 参详行年参数..."];
        [strongSelf extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
            reportData[@"行年参数"] = nianmingText;
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            [strongSelf2 updateProgressHUD:@"3/5: 推衍神煞系统..."];
            [strongSelf2 extractShenShaInfo_CompleteWithCompletion:^(NSString *shenShaResult) {
                reportData[@"神煞详情"] = shenShaResult;
                __strong typeof(weakSelf) strongSelf3 = weakSelf; if (!strongSelf3) return;
                [strongSelf3 updateProgressHUD:@"4/5: 解析课体范式..."];
                [strongSelf3 startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:NO completion:^(NSString *keTiResult) {
                    reportData[@"课体范式_简"] = keTiResult;
                    __strong typeof(weakSelf) strongSelf4 = weakSelf; if (!strongSelf4) return;
                    [strongSelf4 updateProgressHUD:@"5/5: 解析九宗门..."];
                    [strongSelf4 startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:NO completion:^(NSString *jiuZongMenResult) {
                        reportData[@"九宗门_详"] = jiuZongMenResult; // Use detailed for standard report
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf5 = weakSelf; if (!strongSelf5) return;
                            NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                            [strongSelf5 hideProgressHUD]; [strongSelf5 showEchoNotificationWithTitle:@"标准课盘推衍完成" message:@"已生成并复制到剪贴板"]; [strongSelf5 presentAIActionSheetWithReport:finalReport];
                            LogMessage(EchoLogTypeTask, @"[完成] “标准课盘”推衍任务已完成。");
                            g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil;
                        });
                    }];
                }];
            }];
        }];
    }];
}

%new
- (void)executeCompositeExtraction {
    __weak typeof(self) weakSelf = self;
    LogMessage(EchoLogTypeTask, @"[任务启动] 深度课盘推衍");
    [self showProgressHUD:@"1/7: 推衍基础盘面..."];
    __block NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
    
    [self extractKePanInfoWithCompletion:^(NSMutableDictionary *baseReportData) {
        [reportData addEntriesFromDictionary:baseReportData];
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;

        [strongSelf updateProgressHUD:@"2/7: 推演课传流注..."];
        [strongSelf startExtraction_Truth_S2_WithCompletion:^{
            reportData[@"课传详解"] = SafeString(g_s2_finalResultFromKeChuan);
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            
            [strongSelf2 updateProgressHUD:@"3/7: 推衍天地盘详情..."];
            [strongSelf2 startTDPExtractionWithCompletion:^(NSString *tdpDetailResult) {
                reportData[@"天地盘详情"] = tdpDetailResult;
                 __strong typeof(weakSelf) strongSelf3 = weakSelf; if (!strongSelf3) return;

                [strongSelf3 updateProgressHUD:@"4/7: 参详行年参数..."];
                [strongSelf3 extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
                    reportData[@"行年参数"] = nianmingText;
                    __strong typeof(weakSelf) strongSelf4 = weakSelf; if (!strongSelf4) return;

                    [strongSelf4 updateProgressHUD:@"5/7: 推衍神煞系统..."];
                    [strongSelf4 extractShenShaInfo_CompleteWithCompletion:^(NSString *shenShaResult) {
                        reportData[@"神煞详情"] = shenShaResult;
                        __strong typeof(weakSelf) strongSelf5 = weakSelf; if (!strongSelf5) return;
                     
                        [strongSelf5 updateProgressHUD:@"6/7: 解析课体范式..."];
                        [strongSelf5 startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:NO completion:^(NSString *keTiResult) {
                            reportData[@"课体范式_简"] = keTiResult;
                            __strong typeof(weakSelf) strongSelf6 = weakSelf; if (!strongSelf6) return;
                            
                            [strongSelf6 updateProgressHUD:@"7/7: 解析九宗门..."];
                            [strongSelf6 startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES completion:^(NSString *jiuZongMenResult) {
                                reportData[@"九宗门_详"] = jiuZongMenResult;
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    __strong typeof(weakSelf) strongSelf7 = weakSelf; if (!strongSelf7) return;
                                    NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                                    [strongSelf7 hideProgressHUD]; [strongSelf7 showEchoNotificationWithTitle:@"深度课盘推衍完成" message:@"已生成并复制到剪贴板"]; [strongSelf7 presentAIActionSheetWithReport:finalReport];
                                    LogMessage(EchoLogTypeTask, @"[完成] “深度课盘”推衍任务已全部完成。");
                                    g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil; g_s2_finalResultFromKeChuan = nil; g_tianDiPan_completion_handler = nil;
                                });
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

// << 核心修改: 整合脚本1的天地盘详情提取流程 >>
%new
- (void)startTDPExtractionWithCompletion:(void (^)(NSString *result))completion {
    if (g_isExtractingTianDiPanDetail) { LogMessage(EchoLogError, @"错误: 天地盘详情提取任务已在进行中。"); return; }
    LogMessage(EchoLogTypeInfo, @"任务启动: 推衍天地盘详情...");
    g_isExtractingTianDiPanDetail = YES;
    g_tianDiPan_workQueue = [g_tianDiPan_fixedCoordinates mutableCopy];
    g_tianDiPan_resultsArray = [NSMutableArray array];
    g_tianDiPan_completion_handler = [completion copy];
    [self processTianDiPanQueue];
}

%new
- (void)processTianDiPanQueue {
    if (g_tianDiPan_workQueue.count == 0) {
        if (!g_isExtractingTianDiPanDetail) return;
        g_isExtractingTianDiPanDetail = NO;
        LogMessage(EchoLogTypeSuccess, @"完成: 所有天地盘详情提取完毕，正在重组为宫位报告...");

        NSMutableString *finalReport = [NSMutableString string];
        if (g_tianDiPan_resultsArray.count == 24) {
            for (NSUInteger i = 0; i < 12; i++) {
                // 提取宫位名称 (例如: 从 "天将-午位" 提取 "午")
                NSString *tianJiangFullName = g_tianDiPan_fixedCoordinates[i][@"name"];
                NSString *palaceName = [[tianJiangFullName componentsSeparatedByString:@"-"] lastObject];
                palaceName = [palaceName stringByReplacingOccurrencesOfString:@"位" withString:@""];

                // 获取并解析对应宫位的天将和上神数据
                NSString *rawTianJiangData = g_tianDiPan_resultsArray[i];
                NSString *rawShangShenData = g_tianDiPan_resultsArray[i + 12];                
                NSString *parsedTianJiang = parseTianDiPanDetailBlock(rawTianJiangData);
                NSString *parsedShangShen = parseTianDiPanDetailBlock(rawShangShenData);

                // [核心修改] 提取天将和上神的核心名称用于标题行
                NSString *fullTianJiangTitle = [[parsedTianJiang componentsSeparatedByString:@"\n"].firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *shortTianJiangName = [[fullTianJiangTitle componentsSeparatedByString:@" "].firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                
                NSString *fullShangShenTitle = [[parsedShangShen componentsSeparatedByString:@"\n"].firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *shortShangShenName = [[fullShangShenTitle componentsSeparatedByString:@" "].firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];


                // 为了格式美观，移除解析后内容的第一行（标题行），因为它已经被用在子标题里了
                NSRange firstLineRangeTJ = [parsedTianJiang rangeOfString:@"\n"];
                if (firstLineRangeTJ.location != NSNotFound) {
                    parsedTianJiang = [parsedTianJiang substringFromIndex:firstLineRangeTJ.location + 1];
                }
                NSRange firstLineRangeSS = [parsedShangShen rangeOfString:@"\n"];
                if (firstLineRangeSS.location != NSNotFound) {
                    parsedShangShen = [parsedShangShen substringFromIndex:firstLineRangeSS.location + 1];
                }

                // 增加缩进，使结构更清晰
                parsedTianJiang = [parsedTianJiang stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];
                parsedShangShen = [parsedShangShen stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];

                // [核心修改] 组合成您期望的、信息高度浓缩的标题格式
                [finalReport appendFormat:@"// 4.%lu. %@[宫] (上神:%@, 天将:%@)\n", (unsigned long)i + 1, palaceName, shortShangShenName, shortTianJiangName];
                [finalReport appendFormat:@"  - 天将详情:\n    %@\n", parsedTianJiang];
                [finalReport appendFormat:@"  - 上神详情:\n    %@\n", parsedShangShen];

                if (i < 11) { // 在每个宫位块之间添加一个换行符
                    [finalReport appendString:@"\n"];
                }
            }
        } else {
            [finalReport appendString:@"[天地盘宫位详情组合失败：数据量不足]"];
        }

        if(g_tianDiPan_completion_handler) {
            g_tianDiPan_completion_handler([finalReport stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
        }
        g_tianDiPan_workQueue = nil; g_tianDiPan_resultsArray = nil; g_tianDiPan_completion_handler = nil;
        return;
    }
    NSDictionary *task = g_tianDiPan_workQueue.firstObject; [g_tianDiPan_workQueue removeObjectAtIndex:0];
    NSString *name = task[@"name"]; CGPoint point = [task[@"point"] CGPointValue];
    LogMessage(EchoLogTypeInfo, @"[模拟器] 正在处理: %@ (%.0f, %.0f)", name, point.x, point.y);
    @try {
        EchoFakeGestureRecognizer *fakeGesture = [[EchoFakeGestureRecognizer alloc] init];
        fakeGesture.fakeLocation = point;
        SEL action = NSSelectorFromString(@"顯示天地盤觸摸WithSender:");
        if ([self respondsToSelector:action]) {
            SUPPRESS_LEAK_WARNING([self performSelector:action withObject:fakeGesture]);
        } else {
            LogMessage(EchoLogError, @"[模拟器] 触发失败: Target 无法响应");
            [self processTianDiPanQueue];
        }
    } @catch (NSException *exception) {
        LogMessage(EchoLogError, @"[模拟器] 方案执行失败: %@", exception.reason);
        [self processTianDiPanQueue];
    }
}

// ... (所有其他%new方法，如UI交互、数据提取等，从这里开始，保持完整)
%new
- (void)textViewDidChange:(UITextView *)textView { BOOL hasText = textView.text.length > 0 && ![textView.text isEqualToString:@"选填：输入您想问的具体问题"]; [UIView animateWithDuration:0.2 animations:^{ g_clearInputButton.alpha = hasText ? 1.0 : 0.0; }]; }
%new
- (void)textViewDidBeginEditing:(UITextView *)textView { if ([textView.text isEqualToString:@"选填：输入您想问的具体问题"]) { textView.text = @""; textView.textColor = [UIColor whiteColor]; } [self textViewDidChange:textView]; }
%new
- (void)textViewDidEndEditing:(UITextView *)textView { if ([textView.text isEqualToString:@""]) { textView.text = @"选填：输入您想问的具体问题"; textView.textColor = [UIColor lightGrayColor]; } [self textViewDidChange:textView]; }
%new
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text { if ([text isEqualToString:@"\n"]) { [textView resignFirstResponder]; return NO; } return YES; }
%new
- (void)buttonTouchDown:(UIButton *)sender { [UIView animateWithDuration:0.15 animations:^{ sender.transform = CGAffineTransformMakeScale(0.95, 0.95); sender.alpha = 0.8; }]; }
%new
- (void)buttonTouchUp:(UIButton *)sender { [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{ sender.transform = CGAffineTransformIdentity; sender.alpha = 1.0; } completion:nil]; }
%new
- (void)setInteractionBlocked:(BOOL)blocked { if (!g_mainControlPanelView) return; UIView *blockerView = [g_mainControlPanelView viewWithTag:kEchoInteractionBlockerTag]; if (blocked && !blockerView) { blockerView = [[UIView alloc] initWithFrame:g_mainControlPanelView.bounds]; blockerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5]; blockerView.tag = kEchoInteractionBlockerTag; blockerView.alpha = 0; UIActivityIndicatorView *spinner; if (@available(iOS 13.0, *)) { spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge]; spinner.color = [UIColor whiteColor]; } else { _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge]; _Pragma("clang diagnostic pop") } spinner.center = blockerView.center; [spinner startAnimating]; [blockerView addSubview:spinner]; [g_mainControlPanelView addSubview:blockerView]; [UIView animateWithDuration:0.3 animations:^{ blockerView.alpha = 1.0; }]; } else if (!blocked && blockerView) { [UIView animateWithDuration:0.3 animations:^{ blockerView.alpha = 0; } completion:^(BOOL finished) { [blockerView removeFromSuperview]; }]; } }
%new
- (void)presentAIActionSheetWithReport:(NSString *)report { if (!report || report.length == 0) { LogMessage(EchoLogError, @"课盘为空，无法执行后续操作。"); return; } [UIPasteboard generalPasteboard].string = report; UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"发送课盘至AI助手" message:@"将使用内部缓存的课盘内容" preferredStyle:UIAlertControllerStyleActionSheet]; NSString *encodedReport = [report stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]; NSArray *aiApps = @[ @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"}, @{@"name": @"Kelivo", @"scheme": @"kelivo://", @"format": @"kelivo://send?text=%@"}, @{@"name": @"Grok", @"scheme": @"https://", @"format": @"https://grok.com"}, @{@"name": @"Google AI Studio", @"scheme": @"https://", @"format": @"https://aistudio.google.com/prompts/new_chat"}, ]; int availableApps = 0; for (NSDictionary *appInfo in aiApps) { if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:appInfo[@"scheme"]]]) { [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"发送到 %@", appInfo[@"name"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:appInfo[@"format"], encodedReport]] options:@{} completionHandler:nil]; }]]; availableApps++; } } if (availableApps == 0) { actionSheet.message = @"未检测到受支持的AI App。\n课盘已复制到剪贴板。"; } [actionSheet addAction:[UIAlertAction actionWithTitle:@"仅复制到剪贴板" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { LogMessage(EchoLogTypeSuccess, @"课盘已复制到剪贴板。"); [self showEchoNotificationWithTitle:@"复制成功" message:@"课盘内容已同步至剪贴板。"]; }]]; [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]]; if (actionSheet.popoverPresentationController) { actionSheet.popoverPresentationController.sourceView = self.view; actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2.0, self.view.bounds.size.height, 1.0, 1.0); actionSheet.popoverPresentationController.permittedArrowDirections = 0; } [self presentViewController:actionSheet animated:YES completion:nil]; }
%new
- (void)showProgressHUD:(NSString *)text { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; if([keyWindow viewWithTag:kEchoProgressHUDTag]) [[keyWindow viewWithTag:kEchoProgressHUDTag] removeFromSuperview]; UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)]; progressView.center = keyWindow.center; progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8]; progressView.layer.cornerRadius = 10; progressView.tag = kEchoProgressHUDTag; UIActivityIndicatorView *spinner; if (@available(iOS 13.0, *)) { spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge]; spinner.color = [UIColor whiteColor]; } else { _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge]; _Pragma("clang diagnostic pop") } spinner.center = CGPointMake(110, 50); [spinner startAnimating]; [progressView addSubview:spinner]; UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)]; progressLabel.textColor = [UIColor whiteColor]; progressLabel.textAlignment = NSTextAlignmentCenter; progressLabel.font = [UIFont systemFontOfSize:14]; progressLabel.adjustsFontSizeToFitWidth = YES; progressLabel.text = text; [progressView addSubview:progressLabel]; [keyWindow addSubview:progressView]; }
%new
- (void)updateProgressHUD:(NSString *)text { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag]; if (progressView) { for (UIView *subview in progressView.subviews) { if ([subview isKindOfClass:[UILabel class]]) { ((UILabel *)subview).text = text; break; } } } }
%new
- (void)hideProgressHUD { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag]; if (progressView) { [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }]; } }
%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return; CGFloat topPadding;
    if (@available(iOS 11.0, *)) {
        topPadding = keyWindow.safeAreaInsets.top;
    } else {
        topPadding = 20;
    }; topPadding = topPadding > 0 ? topPadding : 20; CGFloat bannerWidth = keyWindow.bounds.size.width - 32; UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, -100, bannerWidth, 60)]; bannerView.layer.cornerRadius = 12; bannerView.clipsToBounds = YES; UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]]; blurEffectView.frame = bannerView.bounds; [bannerView addSubview:blurEffectView]; UIView *containerForLabels = blurEffectView.contentView; UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, 20, 20)]; iconLabel.text = @"✓"; iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0]; iconLabel.font = [UIFont boldSystemFontOfSize:16]; [containerForLabels addSubview:iconLabel]; UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, bannerWidth-55, 20)]; titleLabel.text = title; titleLabel.font = [UIFont boldSystemFontOfSize:15]; if (@available(iOS 13.0, *)) { titleLabel.textColor = [UIColor labelColor]; } else { titleLabel.textColor = [UIColor blackColor];} [containerForLabels addSubview:titleLabel]; UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, bannerWidth-55, 16)]; messageLabel.text = message; messageLabel.font = [UIFont systemFontOfSize:13]; if (@available(iOS 13.0, *)) { messageLabel.textColor = [UIColor secondaryLabelColor]; } else { messageLabel.textColor = [UIColor darkGrayColor]; } [containerForLabels addSubview:messageLabel]; [keyWindow addSubview:bannerView]; [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{ bannerView.frame = CGRectMake(16, topPadding, bannerWidth, 60); } completion:nil]; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5*NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [UIView animateWithDuration:0.3 animations:^{ bannerView.alpha = 0; bannerView.transform = CGAffineTransformMakeScale(0.9, 0.9); } completion:^(BOOL finished) { [bannerView removeFromSuperview]; }]; }); }
%new
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion { g_extractedData = [NSMutableDictionary dictionary]; __weak typeof(self) weakSelf = self; [self extractTimeInfoWithCompletion:^{ LogMessage(EchoLogTypeInfo, @"[盘面] 时间参详完毕，开始推衍基础信息..."); __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; NSString *textA = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "]; NSString *textB = [strongSelf extractSwitchedXunKongInfo]; NSString *xunInfo = ([textA containsString:@"旬"]) ? textA : textB; g_extractedData[@"旬空_旬信息"] = [xunInfo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; g_extractedData[@"月将"] = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "]; g_extractedData[@"昼夜"] = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "]; g_extractedData[@"天地盘"] = [strongSelf extractTianDiPanInfo_V18]; g_extractedData[@"四课"] = [strongSelf _echo_extractSiKeInfo]; g_extractedData[@"三传"] = [strongSelf _echo_extractSanChuanInfo]; LogMessage(EchoLogTypeInfo, @"[盘面] 开始异步解析各类格局..."); dispatch_group_t popupGroup = dispatch_group_create(); dispatch_group_enter(popupGroup); [strongSelf extractBiFa_NoPopup_WithCompletion:^(NSString *result) { g_extractedData[@"毕法要诀"] = SafeString(result); dispatch_group_leave(popupGroup); }]; dispatch_group_enter(popupGroup); [strongSelf extractGeJu_NoPopup_WithCompletion:^(NSString *result) { g_extractedData[@"格局要览"] = SafeString(result); dispatch_group_leave(popupGroup); }]; dispatch_group_enter(popupGroup); [strongSelf extractFangFa_NoPopup_WithCompletion:^(NSString *result) { g_extractedData[@"解析方法"] = SafeString(result); dispatch_group_leave(popupGroup); }]; dispatch_group_enter(popupGroup); [strongSelf extractQiZheng_NoPopup_WithCompletion:^(NSString *result) { g_extractedData[@"七政四余"] = SafeString(result); dispatch_group_leave(popupGroup); }]; dispatch_group_enter(popupGroup); [strongSelf extractSanGong_NoPopup_WithCompletion:^(NSString *result) { g_extractedData[@"三宫时信息"] = SafeString(result); dispatch_group_leave(popupGroup); }]; dispatch_group_notify(popupGroup, dispatch_get_main_queue(),^{ LogMessage(EchoLogTypeInfo, @"[盘面] 所有信息整合完成。"); if (completion) { completion(g_extractedData); } }); }]; }
%new
- (void)extractTimeInfoWithCompletion:(void (^)(void))completion { LogMessage(EchoLogTypeInfo, @"[盘面] 开始参详时间信息..."); g_isExtractingTimeInfo = YES; SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇"); if ([self respondsToSelector:showTimePickerSelector]) { dispatch_async(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:showTimePickerSelector]); }); dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ for (int i = 0; i < 50; i++) { if (!g_isExtractingTimeInfo) break; [NSThread sleepForTimeInterval:0.1]; } dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(); }); }); } else { LogMessage(EchoLogError, @"[时间] 错误: 找不到 '顯示時間選擇' 方法。"); g_extractedData[@"时间块"] = @"[时间推衍失败: 找不到方法]"; g_isExtractingTimeInfo = NO; if (completion) completion(); } }
%new
- (NSString *)extractSwitchedXunKongInfo { SEL switchSelector = NSSelectorFromString(@"切換旬日"); if ([self respondsToSelector:switchSelector]) { LogMessage(EchoLogTypeInfo, @"[旬空] 正在切换以参详另一状态..."); SUPPRESS_LEAK_WARNING([self performSelector:switchSelector]); [NSThread sleepForTimeInterval:0.1]; NSString *switchedText = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "]; SUPPRESS_LEAK_WARNING([self performSelector:switchSelector]); return switchedText; } return @""; }
%new
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *))completion { NSMutableArray<UISegmentedControl *> *segmentControls = [NSMutableArray array]; FindSubviewsOfClassRecursive([UISegmentedControl class], self.view, segmentControls); if (segmentControls.count == 0) { if (completion) completion(@"[推衍失败: 找不到切换控件]"); return; } UISegmentedControl *segmentControl = segmentControls.firstObject; NSInteger nianmingIndex = -1; for (int i = 0; i < segmentControl.numberOfSegments; i++) { if ([[segmentControl titleForSegmentAtIndex:i] containsString:@"行年"]) { nianmingIndex = i; break; } } if (nianmingIndex == -1) { if (completion) completion(@"[推衍失败: 找不到'行年'选项]"); return; } if (segmentControl.selectedSegmentIndex != nianmingIndex) { segmentControl.selectedSegmentIndex = nianmingIndex; [segmentControl sendActionsForControlEvents:UIControlEventValueChanged]; } dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ LogMessage(EchoLogTypeTask, @"[任务启动] 参详行年参数..."); g_isExtractingNianming = YES; g_capturedZhaiYaoArray = [NSMutableArray array]; g_capturedGeJuArray = [NSMutableArray array]; UICollectionView *targetCV = nil; Class unitClass = NSClassFromString(@"六壬大占.行年單元"); NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs); for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } } if (!targetCV || targetCV.visibleCells.count == 0) { g_isExtractingNianming = NO; if (completion) { completion(@""); } return; } NSMutableArray *allUnitCells = [NSMutableArray array]; for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } } [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }]; __weak typeof(self) weakSelf = self; __block NSInteger currentIndex = 0; __block void (^processNextCell)(); processNextCell = [^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf || currentIndex >= allUnitCells.count) { NSMutableString *resultStr = [NSMutableString string]; for (NSUInteger i = 0; i < allUnitCells.count; i++) { NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[摘要未获取]"; NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局未获取]"; [resultStr appendFormat:@"- 参数 %lu\n  摘要: %@\n  格局: %@", (unsigned long)i + 1, zhaiYao, geJu]; if (i < allUnitCells.count - 1) { [resultStr appendString:@"\n\n"]; } } g_isExtractingNianming = NO; g_currentItemToExtract = nil; if (completion) { completion([resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); } processNextCell = nil; return; } UICollectionViewCell *cell = allUnitCells[currentIndex]; id delegate = targetCV.delegate; NSIndexPath *indexPath = [targetCV indexPathForCell:cell]; g_currentItemToExtract = @"年命摘要"; if (delegate && indexPath) [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath]; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ g_currentItemToExtract = @"格局方法"; if (delegate && indexPath) [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath]; currentIndex++; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), processNextCell); }); } copy]; processNextCell(); }); }
%new
- (void)extractShenShaInfo_CompleteWithCompletion:(void (^)(NSString *))completion { NSMutableArray<UISegmentedControl *> *segmentControls = [NSMutableArray array]; FindSubviewsOfClassRecursive([UISegmentedControl class], self.view, segmentControls); if (segmentControls.count == 0) { if (completion) completion(@"[推衍失败: 找不到切换控件]"); return; } UISegmentedControl *segmentControl = segmentControls.firstObject; NSInteger shenShaIndex = -1; for (int i = 0; i < segmentControl.numberOfSegments; i++) { if ([[segmentControl titleForSegmentAtIndex:i] containsString:@"神煞"]) { shenShaIndex = i; break; } } if (shenShaIndex == -1) { if (completion) completion(@"[推衍失败: 找不到'神煞'选项]"); return; } if (segmentControl.selectedSegmentIndex != shenShaIndex) { segmentControl.selectedSegmentIndex = shenShaIndex; [segmentControl sendActionsForControlEvents:UIControlEventValueChanged]; } dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ Class shenShaContainerClass = NSClassFromString(@"六壬大占.神煞行年視圖"); if (!shenShaContainerClass) { if (completion) completion(@"[推衍失败: 找不到容器类]"); return; } NSMutableArray *shenShaContainers = [NSMutableArray array]; FindSubviewsOfClassRecursive(shenShaContainerClass, self.view, shenShaContainers); if (shenShaContainers.count == 0) { if (completion) completion(@""); return; } UIView *containerView = shenShaContainers.firstObject; NSMutableArray<UICollectionView *> *collectionViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews); if (collectionViews.count == 0) { if (completion) completion(@"[推衍失败: 找不到集合视图]"); return; } UICollectionView *collectionView = collectionViews.firstObject; id<UICollectionViewDataSource> dataSource = collectionView.dataSource; if (!dataSource) { if (completion) completion(nil); return; } NSInteger totalSections = [dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)] ? [dataSource numberOfSectionsInCollectionView:collectionView] : 1; NSArray *sectionTitles = @[@"岁煞", @"季煞", @"月煞", @"旬煞", @"干煞", @"支煞"]; NSMutableString *finalResultString = [NSMutableString string]; for (NSInteger section = 0; section < totalSections; section++) { NSString *title = (section < sectionTitles.count) ? sectionTitles[section] : [NSString stringWithFormat:@"未知分类 %ld", (long)section + 1]; [finalResultString appendFormat:@"\n// %@\n", title]; NSInteger totalItemsInSection = [dataSource collectionView:collectionView numberOfItemsInSection:section]; if(totalItemsInSection == 0) { [finalResultString appendString:@"\n"]; continue; } NSMutableArray<NSDictionary *> *cellDataList = [NSMutableArray array]; for (NSInteger item = 0; item < totalItemsInSection; item++) { NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section]; UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath]; UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath]; if (!cell || !attributes) continue; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labels) { if (label.text.length > 0) [textParts addObject:label.text]; } [cellDataList addObject:@{@"textParts": textParts, @"frame": [NSValue valueWithCGRect:attributes.frame]}]; } [cellDataList sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { CGRect f1 = [o1[@"frame"] CGRectValue], f2 = [o2[@"frame"] CGRectValue]; if (roundf(f1.origin.y) < roundf(f2.origin.y)) return NSOrderedAscending; if (roundf(f1.origin.y) > roundf(f2.origin.y)) return NSOrderedDescending; return [@(f1.origin.x) compare:@(f2.origin.x)]; }]; NSMutableString *sectionContent = [NSMutableString string]; CGFloat lastY = -1.0; for (NSDictionary *cellData in cellDataList) { CGRect frame = [cellData[@"frame"] CGRectValue]; NSArray *textParts = cellData[@"textParts"]; if (textParts.count == 0) continue; if (lastY >= 0 && roundf(frame.origin.y) > roundf(lastY)) { [sectionContent appendString:@"\n"]; } if (sectionContent.length > 0 && ![sectionContent hasSuffix:@"\n"]) { [sectionContent appendString:@" |"]; } if (textParts.count == 1) { [sectionContent appendFormat:@"%@:", textParts.firstObject]; } else if (textParts.count >= 2) { [sectionContent appendFormat:@" %@(%@)", textParts[0], textParts[1]]; } lastY = frame.origin.y; } [finalResultString appendString:sectionContent]; [finalResultString appendString:@"\n"]; } if (completion) completion([finalResultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }); }
%new
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *))completion { g_s1_isExtracting = YES; g_s1_currentTaskType = taskType; g_s1_shouldIncludeXiangJie = include; g_s1_completion_handler = [completion copy]; if ([taskType isEqualToString:@"KeTi"]) { UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) { g_s1_isExtracting = NO; return; } Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元"); if (!keTiCellClass) { g_s1_isExtracting = NO; return; } NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs); for (UICollectionView *cv in allCVs) { if ([cv.visibleCells.firstObject isKindOfClass:keTiCellClass]) { g_s1_keTi_targetCV = cv; break; } } if (!g_s1_keTi_targetCV) { g_s1_isExtracting = NO; return; } g_s1_keTi_workQueue = [NSMutableArray array]; g_s1_keTi_resultsArray = [NSMutableArray array]; NSInteger totalItems = [g_s1_keTi_targetCV.dataSource collectionView:g_s1_keTi_targetCV numberOfItemsInSection:0]; for (NSInteger i = 0; i < totalItems; i++) { [g_s1_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; } [self processKeTiWorkQueue_S1]; } else if ([taskType isEqualToString:@"JiuZongMen"]) { SEL selector = NSSelectorFromString(@"顯示九宗門概覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } else { g_s1_isExtracting = NO; } } }
%new
- (void)processKeTiWorkQueue_S1 { if (g_s1_keTi_workQueue.count == 0) { NSString *finalResult = [[g_s1_keTi_resultsArray componentsJoinedByString:@"\n\n"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; g_s1_keTi_targetCV = nil; g_s1_keTi_workQueue = nil; g_s1_keTi_resultsArray = nil; if (g_s1_completion_handler) { g_s1_completion_handler(finalResult); } return; } NSIndexPath *indexPath = g_s1_keTi_workQueue.firstObject; [g_s1_keTi_workQueue removeObjectAtIndex:0]; id delegate = g_s1_keTi_targetCV.delegate; if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [delegate collectionView:g_s1_keTi_targetCV didSelectItemAtIndexPath:indexPath]; } else { [self processKeTiWorkQueue_S1]; } }
%new
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion { if (g_s2_isExtractingKeChuanDetail) return; LogMessage(EchoLogTypeTask, @"[任务启动] 开始推演“课传流注”..."); [self showProgressHUD:@"正在推演课传流注..."]; g_s2_isExtractingKeChuanDetail = YES; g_s2_keChuan_completion_handler = [completion copy]; g_s2_capturedKeChuanDetailArray = [NSMutableArray array]; g_s2_keChuanWorkQueue = [NSMutableArray array]; g_s2_keChuanTitleQueue = [NSMutableArray array]; Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳"); if (!keChuanContainerIvar) { g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; } id keChuanContainer = object_getIvar(self, keChuanContainerIvar); if (!keChuanContainer) { g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; } Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖"); NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults); if (sanChuanResults.count > 0) { UIView *sanChuanContainer = sanChuanResults.firstObject; const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"}; for (int i = 0; ivarNames[i] != NULL; ++i) { Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue; UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(labels.count >= 2) { UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1]; if (dizhiLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]]; } if (tianjiangLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]]; } } } } Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖"); NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults); if (siKeResults.count > 0) { UIView *siKeContainer = siKeResults.firstObject; NSArray *keDefs = @[ @{@"ivar": @"日", @"title": @"日干"}, @{@"ivar": @"日上", @"title": @"日上"}, @{@"ivar": @"日上天將", @"title": @"日上 - 天将"}, @{@"ivar": @"日陰", @"title": @"日阴"}, @{@"ivar": @"日陰天將", @"title": @"日阴 - 天将"}, @{@"ivar": @"辰", @"title": @"支"}, @{@"ivar": @"辰上", @"title": @"支上"}, @{@"ivar": @"辰上天將", @"title": @"支上 - 天将"}, @{@"ivar": @"辰陰", @"title": @"支阴"}, @{@"ivar": @"辰陰天將", @"title": @"支阴 - 天将"} ]; for (NSDictionary *def in keDefs) { Ivar ivar = class_getInstanceVariable(siKeContainerClass, [def[@"ivar"] UTF8String]); if (ivar) { UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar); if (label && label.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject} mutableCopy]]; if ([def[@"title"] containsString:@"天将"]) { [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@(%@)", def[@"title"], label.text]]; } else { [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", def[@"title"], label.text]]; } } } } } if (g_s2_keChuanWorkQueue.count == 0) { g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; g_s2_finalResultFromKeChuan = @""; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); return; } [self processKeChuanQueue_Truth_S2]; }
%new
- (void)processKeChuanQueue_Truth_S2 {
    if (!g_s2_isExtractingKeChuanDetail || g_s2_keChuanWorkQueue.count == 0) {
        if (g_s2_isExtractingKeChuanDetail) {
            NSMutableString *resultStr = [NSMutableString string];
            
            // 步骤1: 将所有提取到的详细信息存入一个字典
            NSMutableDictionary<NSString *, NSString *> *detailedDataMap = [NSMutableDictionary dictionary];
            if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) {
                    NSString *title = g_s2_keChuanTitleQueue[i];
                    NSString *rawBlock = g_s2_capturedKeChuanDetailArray[i];
                    // [排版修正] 在解析时就增加一级缩进
                    NSString *structuredBlock = parseKeChuanDetailBlock(rawBlock, title);
                    structuredBlock = [structuredBlock stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];
                    detailedDataMap[title] = structuredBlock;
                }
            } else {
                g_s2_finalResultFromKeChuan = @"[错误: 课传流注解析数量不匹配]";
            }

            // 步骤2: 创建一个辅助函数，用于从字典中根据前缀查找并格式化输出
            NSString* (^findDetailBlock)(NSString*, NSString*) = ^NSString*(NSString *prefix, NSString *header) {
                for (NSString *key in detailedDataMap.allKeys) {
                    if ([key hasPrefix:prefix]) {
                        return [NSString stringWithFormat:@"\n  - %@ (%@):\n    %@", header, key, detailedDataMap[key]];
                    }
                }
                return [NSString stringWithFormat:@"\n  - %@ (%@): [未找到]", header, prefix];
            };

            // 步骤3: 按“四课”结构组合报告
            [resultStr appendString:@"// 四课详解\n"];
            NSString *siKeSummary = [self _echo_extractSiKeInfo];
            NSArray<NSString *> *siKeLines = [siKeSummary componentsSeparatedByString:@"\n"];
            
            if (siKeLines.count == 4) {
                // [核心修改] 统一清理四课标题，移除括号内容
                NSString* (^cleanTitle)(NSString*) = ^NSString*(NSString* line) {
                    NSRange range = [line rangeOfString:@"("];
                    if (range.location != NSNotFound) {
                        return [line substringToIndex:range.location];
                    }
                    return line;
                };

                // 第一课
                [resultStr appendFormat:@"%@", cleanTitle(siKeLines[0])];
                // [核心修改] 调整输出顺序：天将 -> 上神 -> 干/支
                [resultStr appendString:findDetailBlock(@"日上 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"日上 (", @"上神详情")];
                [resultStr appendString:findDetailBlock(@"日干", @"日干详情")];
                [resultStr appendString:@"\n"];

                // 第二课
                [resultStr appendFormat:@"%@", cleanTitle(siKeLines[1])];
                [resultStr appendString:findDetailBlock(@"日阴 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"日阴 (", @"上神详情")];
                [resultStr appendString:@"\n"];

                // 第三课
                [resultStr appendFormat:@"%@", cleanTitle(siKeLines[2])];
                [resultStr appendString:findDetailBlock(@"支上 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"支上 (", @"上神详情")];
                [resultStr appendString:findDetailBlock(@"支", @"日支详情")];
                [resultStr appendString:@"\n"];
                
                // 第四课
                [resultStr appendFormat:@"%@", cleanTitle(siKeLines[3])];
                [resultStr appendString:findDetailBlock(@"支阴 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"支阴 (", @"上神详情")];
                [resultStr appendString:@"\n"];
            }

            // 步骤4: 按“三传”结构组合报告
            [resultStr appendString:@"// 三传详解\n"];
            NSString *sanChuanSummary = [self _echo_extractSanChuanInfo];
            NSArray<NSString *> *sanChuanLines = [sanChuanSummary componentsSeparatedByString:@"\n"];

            if (sanChuanLines.count >= 1) { // 初传
                [resultStr appendFormat:@"%@", sanChuanLines[0]];
                [resultStr appendString:findDetailBlock(@"初传 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"初传 - 地支", @"地支详情")];
                [resultStr appendString:@"\n"];
            }
            if (sanChuanLines.count >= 2) { // 中传
                [resultStr appendFormat:@"%@", sanChuanLines[1]];
                [resultStr appendString:findDetailBlock(@"中传 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"中传 - 地支", @"地支详情")];
                [resultStr appendString:@"\n"];
            }
            if (sanChuanLines.count >= 3) { // 末传
                [resultStr appendFormat:@"%@", sanChuanLines[2]];
                [resultStr appendString:findDetailBlock(@"末传 - 天将", @"天将详情")];
                [resultStr appendString:findDetailBlock(@"末传 - 地支", @"地支详情")];
            }

            g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!g_s2_keChuan_completion_handler) {
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                reportData[@"课传详解"] = g_s2_finalResultFromKeChuan;
                NSString *finalReport = formatFinalReport(reportData);
                g_lastGeneratedReport = [finalReport copy];
                [self showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"];
                [self presentAIActionSheetWithReport:finalReport];
            }
        }
        g_s2_isExtractingKeChuanDetail = NO;
        g_s2_capturedKeChuanDetailArray = nil;
        g_s2_keChuanWorkQueue = nil;
        g_s2_keChuanTitleQueue = nil;
        [self hideProgressHUD];
        if (g_s2_keChuan_completion_handler) {
            g_s2_keChuan_completion_handler();
            g_s2_keChuan_completion_handler = nil;
        }
        return;
    }
    
    NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject;
    [g_s2_keChuanWorkQueue removeObjectAtIndex:0];
    NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count];
    [self updateProgressHUD:[NSString stringWithFormat:@"推演课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]];
    SEL action = ([title containsString:@"天将"]) ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:action]) {
        SUPPRESS_LEAK_WARNING([self performSelector:action withObject:task[@"gesture"]]);
    } else {
        [g_s2_capturedKeChuanDetailArray addObject:@"[解析失败: 方法不存在]"];
        [self processKeChuanQueue_Truth_S2];
    }
}
%new
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingBiFa) return; g_isExtractingBiFa = YES; g_biFa_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示法訣總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingGeJu) return; g_isExtractingGeJu = YES; g_geJu_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示格局總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new
- (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingFangFa) return; g_isExtractingFangFa = YES; g_fangFa_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示方法總覽"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); } }
%new
- (void)extractQiZheng_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingQiZheng) return; g_isExtractingQiZheng = YES; g_qiZheng_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示七政信息WithSender:"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); } }
%new
- (void)extractSanGong_NoPopup_WithCompletion:(void (^)(NSString *))completion { if (g_isExtractingSanGong) return; g_isExtractingSanGong = YES; g_sanGong_completion = [completion copy]; SEL selector = NSSelectorFromString(@"顯示三宮時信息WithSender:"); if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); } }
%new
- (NSString *)_echo_extractSiKeInfo { Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖"); if (!siKeViewClass) return @""; NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews); if (siKeViews.count == 0) return @""; UIView *container = siKeViews.firstObject; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels); if (labels.count < 12) return @""; NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for (UILabel *label in labels) { NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if (!cols[key]) { cols[key] = [NSMutableArray array]; } [cols[key] addObject:label]; } if (cols.allKeys.count != 4) return @""; NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }]; NSMutableArray *c1 = cols[keys[0]], *c2 = cols[keys[1]], *c3 = cols[keys[2]], *c4 = cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    // 天将(顶), 上神(中), 日/辰(底)
    NSString *k1_shang = ((UILabel*)c4[0]).text, *k1_jiang = ((UILabel*)c4[1]).text, *k1_xia = ((UILabel*)c4[2]).text;
    NSString *k2_shang = ((UILabel*)c3[0]).text, *k2_jiang = ((UILabel*)c3[1]).text, *k2_xia = ((UILabel*)c3[2]).text;
    NSString *k3_shang = ((UILabel*)c2[0]).text, *k3_jiang = ((UILabel*)c2[1]).text, *k3_xia = ((UILabel*)c2[2]).text;
    NSString *k4_shang = ((UILabel*)c1[0]).text, *k4_jiang = ((UILabel*)c1[1]).text, *k4_xia = ((UILabel*)c1[2]).text;
    
    // [修改点 2] 调整为 "天将乘上神 临 日/辰" 格式
    return [NSString stringWithFormat:@"- 第一课: %@乘%@ 临%@\n- 第二课: %@乘%@ 临%@\n- 第三课: %@乘%@ 临%@\n- 第四课: %@乘%@ 临%@", SafeString(k1_shang), SafeString(k1_jiang), SafeString(k1_xia), SafeString(k2_shang), SafeString(k2_jiang), SafeString(k2_xia), SafeString(k3_shang), SafeString(k3_jiang), SafeString(k3_xia), SafeString(k4_shang), SafeString(k4_jiang), SafeString(k4_xia) ];
}
%new
- (NSString *)_echo_extractSanChuanInfo { Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); if (!sanChuanViewClass) return @""; NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSArray *titles = @[@"初传", @"中传", @"末传"]; NSMutableArray *lines = [NSMutableArray array]; NSArray<NSString *> *shenShaWhitelist = @[@"日禄", @"太岁", @"旬空", @"日马", @"旬丁" , @"日德" , @"支德" , @"坐空"]; for (NSUInteger i = 0; i < scViews.count; i++) { UIView *v = scViews[i]; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if (labels.count >= 3) { NSString *lq = [[(UILabel*)labels.firstObject text] stringByReplacingOccurrencesOfString:@"->" withString:@""]; NSString *tj = [(UILabel*)labels.lastObject text]; NSString *dz = [(UILabel*)[labels objectAtIndex:labels.count - 2] text]; NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for (UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count - 3)]) { if (l.text.length > 0) [ssParts addObject:l.text]; } } NSMutableArray *filteredSsParts = [NSMutableArray array]; for (NSString *part in ssParts) { for (NSString *keyword in shenShaWhitelist) { if ([part containsString:keyword]) { [filteredSsParts addObject:part]; break; } } } NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"%lu传", (unsigned long)i+1]; if (filteredSsParts.count > 0) { [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@) [状态: %@]", title, SafeString(dz), SafeString(lq), SafeString(tj), [filteredSsParts componentsJoinedByString:@", "]]]; } else { [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@)", title, SafeString(dz), SafeString(lq), SafeString(tj)]]; } } } return [lines componentsJoinedByString:@"\n"]; }
// 这是修正后的新方法
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className);
    if (!targetViewClass) return @"";
    NSMutableArray *targetViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject;
    NSMutableArray *labelsInView = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
        if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending;
        if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending;
        return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
    }];
    NSMutableArray *textParts = [NSMutableArray array];
    for (UILabel *label in labelsInView) {
        // *** 核心修正：只提取当前可见的 (isHidden == NO) 的标签文本 ***
        if (label.text.length > 0 && !label.isHidden) {
            [textParts addObject:label.text];
        }
    }
    return [textParts componentsJoinedByString:separator];
}
%new
- (NSString *)_echo_extractZhanAnContent {
    // 1. 提取原始文本
    NSString *rawText = [self extractTextFromFirstViewOfClassName:@"六壬大占.占案視圖" separator:@""];
    
    // 2. 如果提取失败或为空，直接返回
    if (!rawText || rawText.length == 0) {
        return nil;
    }
    
    // 3. *** 核心修正：精确裁剪末尾的 "占案" ***
    if ([rawText hasSuffix:@"占案"]) {
        rawText = [rawText substringToIndex:rawText.length - 2]; // 减去"占案"的长度
    }
    
    // 4. 过滤掉默认占位符
    if ([rawText isEqualToString:@""] || [rawText isEqualToString:@"存课"]) {
        return nil;
    }
    
    return rawText;
}
%new
- (NSString *)extractTianDiPanInfo_V18 { @try { Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘推衍失败: 找不到视图类"; UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return @"天地盘推衍失败: 找不到keyWindow"; NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘推衍失败: 找不到视图实例"; UIView *plateView = plateViews.firstObject; unsigned int ivarCount; Ivar *ivars = class_copyIvarList(plateViewClass, &ivarCount); id diGongDict=nil, tianShenDict=nil, tianJiangDict=nil; for(unsigned int i=0; i<ivarCount; i++) { NSString *ivarName = [NSString stringWithUTF8String:ivar_getName(ivars[i])]; if([ivarName hasSuffix:@"地宮宮名列"]) diGongDict=object_getIvar(plateView, ivars[i]); else if([ivarName hasSuffix:@"天神宮名列"]) tianShenDict=object_getIvar(plateView, ivars[i]); else if([ivarName hasSuffix:@"天將宮名列"]) tianJiangDict=object_getIvar(plateView, ivars[i]); } free(ivars); if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘推衍失败: 未能获取核心数据字典"; NSArray *diGongLayers=[diGongDict allValues], *tianShenLayers=[tianShenDict allValues], *tianJiangLayers=[tianJiangDict allValues]; if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘推衍失败: 数据长度不匹配"; NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil]; void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = [layer presentationLayer] ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; [allLayerInfos addObject:@{ @"type": type, @"text": ([layer respondsToSelector:@selector(string)]) ? ([(id)layer string] ?: @"?") : @"?", @"angle": @(atan2(pos.y - center.y, pos.x - center.x)), @"radius": @(hypotf(pos.x - center.x, pos.y - center.y)) }]; } }; processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang"); NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary]; for (NSDictionary *info in allLayerInfos) { BOOL foundGroup = NO; for (NSNumber *angleKey in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angleKey floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angleKey] addObject:info]; foundGroup=YES; break; } } if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];} } NSMutableArray *palaceData = [NSMutableArray array]; for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count < 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; NSString *diPan=@"?", *tianPan=@"?", *tianJiang=@"?"; for(NSDictionary* li in group){ if([li[@"type"] isEqualToString:@"diPan"]) diPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianPan"]) tianPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianJiang"]) tianJiang=li[@"text"]; } [palaceData addObject:@{ @"diPan": diPan, @"tianPan": tianPan, @"tianJiang": tianJiang }]; } if (palaceData.count != 12) return @"天地盘推衍失败: 宫位数据不完整"; NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"]; [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }]; NSMutableString *result = [NSMutableString string]; for (NSDictionary *entry in palaceData) { [result appendFormat:@"- %@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘推衍异常: %@", exception.reason]; } }
%end

%ctor {
    @autoreleasepool {
        initializeTianDiPanCoordinates();
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo推衍课盘] v29.1 (完整版) 已加载。");
    }
}









