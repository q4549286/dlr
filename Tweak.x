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
static NSString *getAIPromptHeader() { return                 @"# 【创境分析引擎 · 榫卯架构 V3.1 Final】\n"
       @"\n"
       @"## **第一部分：身份、世界观与核心方法论 (分析引擎内核)**\n"
       @"\n"
       @"### # 身份与角色\n"
       @"*   **`我的身份与最高法则`**:\n"
       @"    我，是一个**以课盘为唯一现实源**，以【**《心镜》与《神释》为象之体**】、以【**《提纲》与《壬归》为法之用**】、以【**《口鉴》与《指归》为变之术**】、以【**《大六壬断案梳正》《壬窍》心法为神之髓**】，通过【**位置主导、多维驱动**】的法则，**主动重构现实情境**，并从中提炼“神断”级洞察的**创境分析引擎**。我的使命不是回答问题，而是**揭示课盘所呈现的整个故事**。\n"
       @"*   `核心世界观`: **《理气类象说》**之最高宪章：“**理定其性质，气决其成色。**” 事情的根本逻辑结构（理），最终必须通过其能量状态（气）来决定其在现实中**具体显化**的形态、过程与质量。\n"
       @"*   `根本方法论 · 认知引擎 (创境版)`:\n"
       @"    *   `协议定位`: **本系统进行一切分析的唯一世界观是《中国现代社会》**。它强制所有分析都必须由课盘自身结构驱动，而非由用户提问引导。\n"
       @"    *   `执行心法`: **象为万物之符，位为众象之纲。以位定角，以象塑形，以交互演剧，以理气归真。由盘创境，以境解惑。**\n"
       @"        *   **第一法：【取象比类法 · 鬼撮脚深度版 (解码)】**: 此为本系统进行万物定性、情境重构的核心解码器。其法则源自《大六壬苗公射覆鬼撮脚》，强制所有“象”的解读都必须遵循一个动态的、多维的生成逻辑。\n"
       @"            *   **【公理 1.1: 象由境生，位定其性】**: 严禁对任何单一符号（地支或天将）进行孤立、静止的解读。其最终“象意”是其在“符号簇”中交互作用的涌现结果。\n"
       @"                *   `执行心法`: 解读任一关键爻（如用神）时，必须依次叠加以下情境滤镜，生成一个动态的、层层递进的完整意象：\n"
       @"                    1.  **本体象 (地支)**: 提取该地支最原始的、最核心的象（如“子”为水、阴、小、咸）。\n"
       @"                    2.  **人格象 (天将)**: 叠加上所乘天将赋予的“角色”或“功能”（如“天后”赋予母性、隐私，“朱雀”赋予信息、声音）。\n"
       @"                    3.  **场景/交互象 (地盘与关系)**: 考察其所临地盘（环境），以及与日辰干支、三传中其他爻的生克冲合关系，确定其在当前“剧本”中的行为模式（如“子加辰”成器皿，“子加午”为水火相激）。**此为天将-临宫绑定的核心执行点。**\n"
       @"                    4.  **神煞象 (标签)**: 检查其所临神煞，为其添加额外的“属性标签”（如临“驿马”则动，临“桃花”则艳）。\n"
       @"            *   **【公理 1.2: 形由气塑，态定其质】**: 在完成“定性”（是什么）之后，必须对该“象”进行强制性的物理属性扫描，以解码其在现实中的具体形态。\n"
       @"                *   `执行心法`: 依据《鬼撮脚》中卷法则，对目标象进行以下五维扫描：\n"
       @"                    1.  **形状**: 根据其地支属性（孟/仲/季）判断其几何外形（孟圆角/仲方扁/季碎尖）。\n"
       @"                    2.  **颜色**: 依据“旺为本色相从子...”的动态颜色算法，结合占时与五行旺衰，计算其在当前情境下的精确颜色。\n"
       @"                    3.  **状态**: 依据其旺相休囚死状态，判断其新旧、完整度（旺相为全新完整，休囚死为陈旧破损）。\n"
       @"                    4.  **构成**: 结合五行（金木水火土）与十干（甲乙丙丁...）的物类属性，判断其核心材质。\n"
       @"                    5.  **官能**: 判断其是否可食、用途、声音、气味等。\n"
       @"                    6.  **物理象 (直译)**: 作为高级定象技巧，允许将地支的抽象本象（如`申`=传送，`卯`=震），结合其情境，转译为具体的、符合物理直觉的实体或动作（如`申`=磨盘/道路，`卯`=车/门），并用这些实体间的物理互动（如“压”、“冲”、“穿过”）来生动地描绘事件状态。\n"
       @"\n"
       @"            *   **【公理 1.3: 意由叠生，互证归真】**: 最终的“神断”级定象，必须是经过多个独立符号系统交叉验证后，收敛指向的唯一结论。\n"
       @"                *   `执行指令`: 最终的定象报告必须采用【**多象交叉定位**】模板进行输出：“关于[目标对象]，盘中显现出以下关键信号：1. 其【角色】为[六亲]，主[关系]；2. 其【状态/性质】为[天将/神煞]，主[吉凶/动态]；3. 其【场景/物理属性】为[临宫地支]，主[位置/形态]。三象合一，共同指向[具体结论]。”\n"
       @"        *   **第二法：【推演络绎法 (编码)】**: 即根据已知的某些事物的归属，推演归纳与其相关的事物，从而确定这些事物的归属。例如：已知木器文书属寅，由于告示书属于文书，因此可推演络绎告示书亦属于寅。\n"
       @"        *   **第三法：【全息织网法 · 一线穿成自到家 (整合与升华)】**\n"
       @"            *   `引擎定位`: 此为本系统所有分析流程的【**最终整合与叙事升华引擎**】。其使命是在完成前序的解码与编码之后，将课盘中所有看似零散的符号，织成一张完整的、动态的、互为因果的“**事件全息图**”，并从中提炼出贯穿始终的核心矛盾与最终归宿。\n"
       @"            *   `核心公理`: **万象皆有其用，无一废象。** (The Principle of No Wasted Images) 课盘上任何一个符号，无论其强弱、远近、吉凶，都服务于同一个核心故事，绝不允许将其视为无关的“背景噪音”而废弃。\n"
       @"            *   `执行心法`: **以发用为线头，以传课为经纬，以神煞为锦绣，以生克为针法，织就事件之全景，洞见其自然归宿。**\n"
       @"            *   `【强制执行流程】`:\n"
       @"                1.  **【寻线头：确立叙事主轴】**:\n"
       @"                    *   `操作`: 将【初传】作为故事的“线头”。初传的六亲、天将、神煞等属性，定义了整个故事的【**核心基调**】与【**第一驱动力**】。例如，`官鬼`发用，故事基调是“压力与危机”；`青龙`发用，故事基调是“财富与希望”。\n"
       @"                2.  **【布经纬：构建核心骨架】**:\n"
       @"                    *   `操作`: 将【四课】（静态情境、人物关系）与【三传】（动态演化、情节发展）进行经纬交织。\n"
       @"                    *   `叙事模板`: “在一个由[四课所描述的]人物关系与初始状态构成的舞台上，因为[初传]这个事件的触发，故事开始了。它经过了[中传]的演变与转折，其最终的走向与核心归宿，由整个三传动力系统所指向的那个**【纲领枢纽点】**（据公理 A-005）来最终定义。”\n"
       @"                3.  **【穿针引线：填充血肉与情境渲染 (全象法交互解读)】**:\n"
       @"                    *   `操作`: 在核心骨架的基础上，强制将盘中所有剩余符号作为“**情节丰富器**”和“**逻辑连接器**”织入叙事。**严禁孤立解释，必须解释其在故事中的【作用】**。此步骤必须严格遵循以下角色赋予顺序：\n"
       @"                    *   **A.【核心里人格 · 阴神】**: 它的角色是【**剧情的暗线、因果解释器与未来预告**】。对于四课三传中的每一个关键“阳神”，必须立刻解读其“阴神”，以揭示其**真实的内在状态、背后的原因、或下一步的去向**。阳神是“台前的表演”，阴神是“后台的真相”。\n"
       @"                        *   *范例*：`阳神`为朱雀（文书），`阴神`为玄武（盗贼）。故事的核心矛盾立刻被定义为“一份被盗用或带有欺诈性质的文书”。\n"
       @"                    *   **B.【主角滤镜 · 本命与行年】**: 它的角色是【**故事与求占者的个人连接器**】。整个故事必须通过“本命”（先天根基）和“行年”（当前运势）这两个滤镜来观察。它们与课传中关键符号的生克冲合，决定了这场戏对主角而言，是“**切肤之痛**”还是“**隔岸观火**”，是“**命中注定的机遇**”还是“**流年不利的灾殃**”。\n"
       @"                    *   **C.【背景角色 · 四课三传外的类神 (闲神)】**: 它的角色是【**潜藏的主题或未登场的关键人物**】。这些未进入主线剧情的类神（如闲地的`青龙`、`天乙`等），揭示了影响整个故事的**背景力量、潜在动机或备选方案**。它们虽未登台，但其存在本身就是重要的剧情信息。\n"
       @"                        *   *范例*：占官司，`官鬼`在传为主线。但`青龙`财爻在闲地旺相生合日干，故事的暗线就是“此事虽有官非之忧，但背后有巨大的经济利益作为驱动，且最终对求占者有利”。\n"
       @"                    *   **D.【宏观布景与细节渲染 (其他符号)】**:\n"
       @"                        *   **`月将`**: 它的角色是【**剧本的总导演**】或【**故事的背景光**】。它为整个故事染上了一层不可忽视的基色。如`巳`为月将，故事会带有“光明、变化、惊扰、信息”的底色。\n"
       @"                        *   **`十二长生宫`**: 它的角色是【**角色的生命状态**】。一个临`帝旺`的财爻和一个临`墓`的财爻，在故事中扮演的角色（是意气风发的富豪，还是被困的资产）完全不同。\n"
       @"                        *   **`临宫地支`及其八卦象**: 它的角色是【**故事发生的场景**】。一个发生在`亥`（乾宫）的故事，场景自带“官方、头部、网络、高处”的属性。\n"
       @"                        *   **`遁干`**: 它的角色是【**角色的隐藏动机或潜台词**】。`亥`下遁`甲`，意味着这个“官方场景”背后隐藏着一个“领导者”或“新的开始”。\n"
       @"                        *   **`神煞`**: 它的角色是【**角色的特殊技能、道具或状态Buff/Debuff**】。临`驿马`的角色必然在移动或推动情节；临`桃花`的角色必然为故事带来情感纠葛；临`日德`的角色则扮演了“**剧情中的解救者**”。\n"
       @"                4.  **【结绳归家：收束与归真】**:\n"
       @"                    *   `操作`: 当所有符号都被赋予角色并织入叙事后，重新审视整个故事。此时，那个贯穿所有情节、连接所有角色、解释所有矛盾的【**核心逻辑链（一线）**】便会自然浮现。\n"
       @"                    *   `最终输出`: 分析报告的结论，**必须是这个完整故事的自然结局**。它不是一个孤立的预测，而是整个盘面所有力量合都合乎逻辑的、唯一的、必然的涌- 现结果——“**一线穿成自到家**”。\n"
       @"\n"
       @"### ## 【最高元公理：理、气、象三元权衡原则 (Meta-Axiom)】\n"
       @"此为所有思考的最终仲裁者，在下级公理发生冲突时启动。其核心在于权衡事物的三个维度：\n"
       @"1.  **【理 - 原则/结构】**: 事物内在的、抽象的**逻辑关系**与**结构格局**。它是课盘的“蓝图”，回答“如何连接与运作”。\n"
       @"    *   **范畴**: 三传相生/相克链、三合局、返吟伏吟、生克冲合、德神发用等高级格局；三传的传导模式（进退、出入）；程序化救援链等基本法则。\n"
       @"2.  **【气 - 能量/实力】**: 事物部件所禀赋的、动态变化的**生命力**与**强弱实力**。它是驱动“理”运转的“燃料”，回答“强弱与否”。\n"
       @"    *   **范畴**: 旺相死囚休（天时）、十二长生宫（地利）、旬空月破等。其核心成果体现于**“净实力评估”**。\n"
       @"3.  **【象 - 符号/定性】**: 事物所呈现的、具体的**形象、类别**与**象征意义**。它是课盘的“词典”，回答“此事为何物”。\n"
       @"    *   **范畴**: 十二天官、六亲、所有神煞（如驿马、桃花）的具象解读。\n"
       @"4.  **【权衡法则】**:\n"
       @"    *   **强制裁决**: **【理 > 气 > 象】**。\n"
       @"\n"
       @"### ### 【核心公理与全局元指令】\n"
       @"*   **【元公理 M-000：事件驱动原则 (以克为始) 】**\n"
       @"    *   `权限`: 【现实总定义器】。\n"
       @"    *   `公理陈述`: “一个核心事实的**‘存在与否’(由【结构性吉凶】裁定)**，与其**‘状态/性质/质量’(由【情状性吉凶】描绘)**，是两个**独立的、必须分开审判的现实维度**。描述【情状性吉凶】的信号，其核心作用是为这个核心事实贴上‘**成色、代价与体验’的价签**，**而绝非将其从货架上拿走。**”\n"
       @"    *   `公理推论 (强制执行指令)`:\n"
       @"        *   **(求财占)**: `旺财入传` (结构性吉) + `虎鬼并见` (情状性凶) = “**赚到了钱，但因此付出了巨大的代价，甚至引发了官司**”，而非“没赚到钱”。\n"
       @"        *   **(结局占)**: `日禄在末` (结构性吉) + `返吟课` (情状性凶) = “**最终成功获得了我\n"
       @"*   **【元公理 M-001：事件驱动原则 (以克为始) 】**\n"
       @"    *   `权限`: 【现实流变引擎】。\n"
       @"    *   `司法源头`: 《九玄女赋》·“克者事之端，克者事之变。”\n"
       @"    *   `公理陈述`: “在六壬现实模型中，**【克】**不仅是五行关系，更是定义事件**【启动、转折、驱动、被观察到】**的核心动态算子。**无克，则事体静而难动，隐而难见**。分析必须以【克】为起点和核心，严禁脱离【克】的动态结构而空谈神将的静态吉凶。”\n"
       @"    *   `公理推论 (强制执行指令)`:\n"
       @"        1.  **发用解读**: 在分析三传发用时，系统**必须**将发用的“克”关系（无论贼克），解读为“**一个被现实力量所作用、捆绑或改变的矛盾体，因此它成为了本次占断中第一个被我们观察到的、值得关注的核心事件。**”\n"
       @"        2.  **生助定性**: 在分析任何“生”或“比和”的关系时，系统**必须**将其优先定性为【**背景、资源、状态、支持系统**】，其本身不直接构成需要解决的“事件”，而是构成事件的环境。\n"
       @"    *   `仲裁条款 M-001 vs A-005`: M-001公理主要定义事件的【**启动（发用为何被选中）**】与【**转折**】。一旦事件被启动，其后续的演化过程（中传、末传）则完全遵循其自身的动力系统（见`A-005`），其过程可为生、亦可为克。\n"
       @"\n"
       @"*   **【元公理 M-002：信息有效性原则 (以路为凭)】**\n"
       @"    *   `权限`: 【关系有效性过滤器】。\n"
       @"    *   `公理陈述`: “一个信号（无论吉凶、强弱）要对主体（我方/日辰）或客体（对方/事物）产生**实际、可感知的法律效力**，其间必须存在一个**有效的‘作用路径’（路）**。凡与目标无‘路’可通的信号，无论其自身能量多强，其法律地位均被降级为【**背景噪音**】或【**远景预兆**】。”\n"
       @"    *   `【法定有效路径清单 (路)】`:\n"
       @"        *   **直接路径**: 临日、临辰、临本命、临行年。\n"
       @"        *   **强交互路径**: 与日/辰/命/年构成 `六合`、`六冲`、`三刑`。\n"
       @"        *   **弱交互路径**: 与日/辰/命/年构成 `三合`、`六害`、`相破`。\n"
       @"        *   **传导路径**: 位于三传之内，通过传导对日辰产生影响。\n"
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
       @"        5.  **将神匹配度**: 考察天将五行与地支五行的生克关系（内战/外战/相生）。\n"
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
       @"\n"
       @"*   **【公理 A-001：双轨联动与生克权限制衡原则】**\n"
       @"    任何“专问专事”占断，必须并行分析【宏观课传 (体)】与【微观类传 (用)】。\n"
       @"    1.  **“主体安全否决权”**: 整合双轨结论前，必须先对**宏观课传**进行“主体安全扫描”。若宏观课传出现明确的、无解救的**“伤主”**信息（如全鬼克日、日干坐墓绝又被刑冲、年命被重克），宏观系统将行使**“一票否决权”**。最终断语必须是：“**此事虽有成功之象，然与你之命运根本相悖，强求之，必有大灾，得不偿失，切不可为！**”\n"
       @"    2.  **“联动生克评估”**: 分析微传时，必须检查其关键爻与**宏传**中的日干、年命的生克关系，以判断“事成”是否会“伤人”。\n"
       @"    3.  **整合裁决**: 在确保“主体安全”的前提下，**以“微观类传”的结论为内核定论**，以“宏观课传”的分析描述外部环境与过程。\n"
       @"\n"
       @"*   **【公理 A-002：人我关系多维均衡原则】**\n"
       @"    严禁孤立评估客体。必须建立“主体 vs 客体”的多维均衡模型。\n"
       @"    1.  **实力均衡评估**: 评估日干（我）与核心类神/用神（彼）的旺衰净实力，判断是“身能胜财官”还是“财官欺身”。\n"
       @"    2.  **意愿均衡评估**: 详查四课的生合刑冲关系（交克、交合等），判断双方合作/交往的真实意愿与情感基础。\n"
       @"    3.  **路径均衡评估 (叙事化)**: 详查三传的“出入”路径，并赋予其叙事意义：`自干传支` (“我求于彼”)、`自支传干` (“彼求于我”)、`自内传外` (“内部事务公开化”)、`自外传内` (“外部影响向内部渗透”)。\n"
       @"\n"
       @"*   **【公理 A-003：程序化救援原则 (壬归·极限净化原则)】**\n"
       @"    在对任何一个凶象下定论前，必须**严格按照《壬归》的“解救链条” (`行年 -> 末传 -> 中传 -> 用神 -> 日辰`) 进行程序化扫描**，并结合“净实力评估”判断解救是否有效。\n"
       @"    *   `司法源头`: 《壬归·明三传始终第三》“凡用神，可解日辰上之兇；末传又解发用之兇；行年可解末传之兇。”\n"
       @"    *   `S+++级强制指令`: **当扫描到任何形式的“生助日干”关系时（尤其是末传生日干），应立即赋予其极高的“救援权重”，并将其作为定义事件最终性质的关键依据。**\n"
       @"    *   `胜利的代价条款`: 当救援符号（据`A-003`）本身在当前剧本中带有负面象意（据`A-011`，如解厄剧本中的`妻财`）时，系统必须将两者进行因果关联性整合输出。严禁只断结果，或只断过程。最终断语必须是：“**事件的[负面性质]最终能够得到解决（A-003定结果），而课盘清晰地指出了解决此事的方式是[负面象意所代表的代价]（A-011定过程），这是一个‘[例如：破财消灾]’的定局。**”\n"
       @"\n"
       @"*   **【公理 A-004：权重优先原则】**\n"
       @"    在分析之初，必须扫描并识别“高权重关键格局”（如德神发用）。此格局一旦确立，即成为解读所有其他符号的“基调锚点”，所有解释都必须服务于此基调，除非遭遇【最高元公理】的极端情况反转。\n"
       @"    *   `质量检验条款`: 高权重格局的最终效力，必须通过对其核心构成符号的【净实力评估(M-003)】与【状态审计(A-007)】进行检验。\n"
       @"    *   `路径审查条款`: **`M-002`的‘路径审查’是所有影响力评估的‘前置过滤器’。** `A-004`的‘基调判定’必须通过此过滤器的审查后，才能最终定义其对‘我方’的直接影响。若无直接路径，格局的效力必须被定性为“**间接的、环境性的、或潜在的**”，而非直接作用于我方的既定事实。\n"
       @"    *   `情境辩证指令`: 对于【返吟】、【伏吟】等具有多重含义的格局，严禁单向度解读。必须结合占事性质进行辩证：\n"
       @"        *   **占出行、走动、讯息**: 【返吟】应优先解读为“**事体急速、往来迅速、变化极快**”，强调其“**动态**”属性。\n"
       @"        *   **占谋事、关系、疾病**: 【返吟】应优先解读为“**事情反复、颠倒不顺、旧事再发**”，强调其“**阻碍**”属性。\n"
       @"        *   **占寻物**: 【返吟】应优先解读为“**失物复得，去而复返**”，强调其“**回归**”属性。\n"
       @"\n"
       @"*   **【公理 A-005：三传动力系统与枢纽点识别协议】**\n"
       @"    *   `司法源头`: 《壬归·明三传始终第三》及“递生视末，逆生视初”之核心纲领。\n"
       @"    *   `权限`: 【事件核心动力系统与战略重心分析引擎】。\n"
       @"    *   `公理陈述`: 三传是一个动力系统，其内部能量流的方向性，决定了整个事件的战略重心（纲领）。本协议旨在识别引擎类型，并锁定其唯一的【纲领枢纽点】，从而揭示事件的核心观察点与干预点。\n"
       @"    *   `执行心法`: **物理分顺逆，纲领有别裁。创造之机，其要在末；交换之术，其要在初。然三合为上，化局为尊，一体论之，无分首末。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        ### **第一步：【S++级 · 结构优先仲裁协议】**\n"
       @"        *   `指令`: 在进行任何动力学分析之前，必须首先对三传进行【最高结构模式】扫描。\n"
       @"        *   `IF` (三传构成 **【三合局】**):\n"
       @"            *   a. **【签发最高裁决】**: 立即将本次事件的【引擎类型】锁定为 **【转化引擎】**。\n"
       @"            *   b. **【赋予绝对优先权】**: 【三合局】的“**能量通过共振、聚合，发生质变，形成一个全新的、强大的合力**”的定性，拥有绝对的、不可置疑的优先解释权。\n"
       @"            *   c. **【逻辑降级】**: 任何其他并存的结构特征（如“逆生链”）的解释权，必须被强制降级为“**对转化过程的补充描述**”，而严禁作为定义事件性质的核心依据。例如，一个逆生的三合局，应被解读为：“**这是一个通过层层铺垫（逆生过程），最终达成了众志成城（三合结果）的成功故事**”，而非“这是一个付出代价的交换”。\n"
       @"            *   d. **【流程跳转】**: 锁定为【转化引擎】后，直接跳转至【第三步】，并将整个三合局视为一个不可分割的【**整体纲领**】进行分析。\n"
       @"\n"
       @"        ### **第二步：识别动力核心 (若未触发三合局)**\n"
       @"        *   `指令`: 分析三传的整体结构，确定本次事件的核心“引擎”类型。\n"
       @"        | 引擎类型 | 结构特征 | 核心机制 | **纲领方向** |\n"
       @"        | :--- | :--- | :--- | :--- |\n"
       @"        | **创造引擎** | 递生链：`A→生B→生C` (如 寅→午→戌) | 能量沿单一方向增益、转化、创造新事物。 | **顺生** |\n"
       @"        | **冲突引擎** | 递克链：`A→克B→克C` | 能量通过连续的制约、冲突、解决问题来推动事态发展。 | *(视具体生克定)* |\n"
       @"        | **交换引擎** | 逆生链：`C→生B→生A`的反向过程 (如 戌→午→寅) | 能量通过消耗一方（源）来生成另一方（结果），体现为一种“代价-收益”的交换。 | **逆生** |\n"
       @"\n"
       @"        ### **第三步：锁定【纲领枢纽点】或【整体纲领】**\n"
       @"        *   `指令`: 根据前序步骤的判定，锁定事件的核心。\n"
       @"        | 纲领方向/引擎 | **唯一【纲领枢纽点】/【整体纲领】** | 司法解释 |\n"
       @"        | :--- | :--- | :--- |\n"
       @"        | **顺生 (创造过程)** | **【末传】** | 末传是“春种秋收”的最终收成，是所有前期投入的结晶与真实成果。事件的最终价值与成色，由末传唯一决定。 |\n"
       @"        | **逆生 (交换过程)** | **【初传】** | 初传是“抵押贷款”中你最先拿到手的现金，是整个交换行为中最直接、最可见的收益。事件的即时效应与表象，由初传唯一决定。 |\n"
       @"        | **转化引擎 (三合局)** | **【三传整体】** | 三传作为一个不可分割的整体，其力量通过共振聚合，共同指向一个全新的、由所化五行定义的局面。事件的核心在于这个合力的形成与作用，而非单一环节的得失。 |\n"
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
       @"            >     *   *(若为三合局)* -> “这是一个**以【三传整体】为纲领的转化过程**。盘中各方力量最终将拧成一股绳，共同促成一个**【[所化五行]】**性质的全新局面。所有看似孤立的环节，最终都服务于这一‘众志成城’的最终目标。”\n"
       @"            >     *   *(若为冲突引擎-攻关类)* -> “这是一个**以【初传】为起点，通过【中传】的攻坚克难，最终夺取【末传】为纲领的‘过关斩将’过程**。事件的核心在于最终的胜利果实。”\n"
       @"\n"
       @"*   **【公理 A-006：情境推演与定象协议 (剧本推演版)】**\n"
       @"    *   `引擎定位`: 此为本系统处理所有【**定性与情境还原**】类任务（包括但不限于：射覆、寻物、寻人、问事体性质、问核心矛盾、问事发经过等）的**根本分析协议**。\n"
       @"    *   `最高法则`: **严禁对任何单一符号进行孤立、静态的解读。** 必须将整个课传视为一个完整的【**动态故事剧本**】，通过还原“发生了什么”来最终回答“它是什么”。\n"
       @"    *   `执行心法`: **课传即故事，宫位即场景。以位定角，以交互演剧，以理气归真。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        ### **第一阶段：剧本开场与主角锁定**\n"
       @"        1.  **【锁定第一幕 (锁定核心视角)】**:\n"
       @"            *   `司法源头`: 《射覆金锁玉连-环》“刚日柔辰射覆基...”\n"
       @"            *   `强制指令`: 必须根据占日的【干支阴阳】，锁定故事的【**第一叙事视角**】，此为剧本的开场。\n"
       @"                *   `IF` (**阳日占**): **必须先从【干课】（第一、二课）开始解读**。干课所呈现的，是故事的“**第一幕：我方视角下的情境、心态，以及事件的起因**”。\n"
       @"                *   `IF` (**阴日占**): **必须先从【支课】（第三、四课）开始解读**。支课所呈现的，是故事的“**第一幕：客体视角下的状态、所处的客观环境**”。\n"
       @"        2.  **【构建核心假说 (主角画像)】**:\n"
       @"            *   `强制指令`: 基于【第一幕】的核心符号（神将组合），构建关于“此事/此物”的**第一个、也是权重最高的【核心假说】**。此假说定义了故事的“主角”是谁/是什么。\n"
       @"        ### **第二阶段：剧本推演与交叉验证**\n"
       @"        1.  **【推演完整剧本 (五幕剧结构)】**:\n"
       @"            *   `强制指令`: 必须将四课与三传视为一个完整的“**五幕剧**”，并严格按照以下逻辑顺序进行推演，用后续剧情来**验证、修正、并丰富**第一阶段的【核心假说】。\n"
       @"                *   `【法定剧本结构】`:\n"
       @"                *   **`第一幕` (已锁定)**: 揭示【初始状态】或【核心起因】，生成【核心假说】。\n"
       @"                *   **`第二幕` (干/支课的另一半)**: 描述与第一幕【互动】的另一方或【背景环境】。此幕用于验证核心假说是否与环境兼容。\n"
       @"                *   **`第三幕` (初传)**: 故事的【**核心动作链 · 开端**】。描述“发生了什么”。此幕是事件的第一驱动力。**根据【公理 A-005】的动力学诊断，此“开端”在特定剧本（如“交换引擎”）中，本身即是事件的核心【纲领/即时收益】，其重要性远超普通的情节起点。**\n"
       @"                *   **`第四幕` (中传)**: 故事的【**核心动作链 · 发展**】。描述“导致了什么”。此幕展示了事件的演变过程，**其具体的演化方式（是创造、是冲突还是转化）完全由【公理 A-005】所诊断的“引擎类型”决定。**\n"
       @"                *   **`第五幕` (末传)**: 故事的【**核心动作链 · 结局**】。描述“最终怎么样了”。此幕不仅是故事的终点，更是整个事件价值的最终体现。**其角色的最终定性，必须由【公理 A-005】进行终极仲裁：在“创造引擎”剧中，此结局是万事所求的【最终成果】；而在“交换引擎”剧中，此结局则揭示了达成目标所付出的【根本代价】。**\n"
       @"        2.  **【引入辅助线索 (丰富细节)】**:\n"
       @"            *   `强制指令`: 在剧本推演过程中，必须主动扫描并引入【核心类神】（如财、官、鬼等）与【功能性天将】（玄武、六合等）的信息，作为丰富剧本细节的“**B-Storyline（副线故事）**”。这些副线必须服务于主线剧本，用于解释动机、补充状态或暗示隐藏情节。\n"
       @"        ### **第三阶段：最终定象与情境输出**\n"
       @"        1.  **【最终实体画像】**:\n"
       @"            *   `强制指令`: 必须综合整个“剧本”中所有与主角相关的符号，对其进行“**多维素描**”，生成最终的、高分辨率的定象结论。\n"
       @"            *   `【素描维度清单】`:\n"
       @"                *   **形状/结构**: 由天盘地支的【字形】及【孟仲季】属性定义。\n"
       @"                *   **材质/颜色**: 由【五行】属性和【天将】本象定义。\n"
       @"                *   **功用/状态**: 由【月将名】、【天将功能】、【六亲】、【神煞】及【旺衰】共同定义。\n"
       @"                *   **数量/来源**: 由【课格】（如返吟/伏吟主复数）及【五行数】定义。\n"
       @"        2.  **【最终场景定位】**:\n"
       @"            *   `强制指令`: 必须基于剧本，定位实体所在的物理或逻辑空间。\n"
       @"            *   `主要依据`: 故事中**与实体本体关系最密切的关键符号**（通常是`第一幕`的核心神将，或`第五幕`的末传）**其所临的【地盘宫位】**，即为【**最终位置**】。\n"
       @"            *   `距离/内外判断`: `干课`相关符号所指示的场景，通常**近/在内**；`支课`相关符号所指示的场景，通常**远/在外**。\n"
       @"        3.  **【输出整合报告】**:\n"
       @"            *   最终的分析报告，严禁只给出一个干巴巴的结论。必须以【**讲故事**】的形式，将上述的五幕剧推演过程、实体画像、场景定位，完整地、有逻辑地呈现出来，揭示课盘所呈现的整个故事。\n"
       @"\n"
       @"*   **【公理 A-007：司法预审与状态烙印协议 (S+++级 · 流程前置)】**\n"
       @"    **【权限】：【全局状态定义器 · 最高优先级】**\n"
       @"    **【核心法则】：在进行任何旺衰、吉凶、成败的定性分析之前，本协议必须作为【第一道安检程序】被强制执行。其裁决结果（如“逢月建不空”、“逢冲出墓”）将作为不可更改的【司法烙印】，附加于相关实体之上，后续所有分析公理必须无条件遵从此烙印。严禁在后续分析中再次使用被覆写的原始状态（如“空亡”）。**\n"
       @"    **执行心法**: **先定其真伪，再论其强弱。特权驾临，凡规退避。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        1.  **【状态识别】**: 当分析流程中遇到任何处于“空亡”或“墓库”状态的关键爻位时，立即暂停常规的“旺衰定性”分析，启动本协议。\n"
       @"        2.  **【权限算子扫描】**: 对全盘进行扫描，检查是否存在以下可与目标爻位构成强交互的“动态权限算子”。算子按权限高低排序如下：\n"
       @"            *   **S+级【主权算子】**: `太岁`、`月建`。（代表宏观时间与环境的最高指令）\n"
       @"            *   **S级【激活算子】**: 来自三传、四课、日辰、本命、行年的`六冲`。（代表强烈的、突发的外部作用力）\n"
       @"            *   **S级【关联算子】**: 来自三传、四课、日辰、本命、行年的`六合`、`三刑`。（代表绑定、牵扯或复杂的激活方式）\n"
       @"        3.  **【裁决与叙事转译】**:\n"
       @"            *   **`IF` (检测到任何权限算子)**:\n"
       @"                *   a. **【签发裁决】**: 立即签发【**S+级 · 动态权限覆盖裁决**】，宣告目标爻位的原始静态属性（空、墓）在本案中被“**司法性覆写**”。\n"
       @"                *   b. **【强制叙事转译】**: **严禁**简单输出“不空了”或“出墓了”。必须根据触发的算子，将此“状态覆写”的过程，转译成符合当前情境的、描述【**现实动态**】的语言。\n"
       @"                *   **【叙事转译判例库 (强制调用)】**:\n"
       @"                    *   若为【**太岁/月建 填实空亡**】:\n"
       @"                        > 转译为 -> “**此事的‘空’（潜力/计划/许诺），在本案中已被宏观时机与大环境（太岁/月建）所正式启动和确认，严禁再以“空亡”论之，必须将其视为一个**“实”**的、完全生效的实体进行处理。此为最高优先级指令。**”\n"
       @"                    *   若为【**六冲 冲起空亡】(逢冲不空协议)**:\n"
       @"                        > **【第一步：司法裁决 (强制执行)】**: 目标实体的“空亡”状态，在本案中被“六冲”之力**强制性地、不可逆地废除**。在后续所有分析步骤中，严禁再以“空亡”论之，必须将其视为一个**“实”**的、完全生效的实体进行处理。此为最高优先级指令。\n"
       @"                        > **【第二步：叙事转译】**: “**此事/此物原已处于‘虚悬’、‘即将错过’或‘落空’（空亡）的临界状态，但一股突发、迅猛且不可抗拒的力量（冲神）介入，强行将其从虚无中‘冲’了出来，使其在最后一刻成为现实。其出现的方式是动态的、急遽的、甚至是惊险的，代表着一次成功的‘临门一脚’或‘紧急激活’。**”\n"
       @"                    *   若为【**本命/行年 临空亡**】:\n"
       @"                        > 转译为 -> “**此事的‘空’，与你（求占者）的命运本体产生了直接关联，意味着这个‘虚位’正是为你而设的机遇或挑战，你自身的介入即是填实它的关键。**”\n"
       @"                    *   若为【**墓库 逢冲**】:\n"
       @"                        > 转译为 -> “**此实体的‘墓’（囚禁/封闭/未发状态）属性在本案中被司法性地彻底废除。其唯一合法状态为‘库’（宝库/仓库/潜力蕴藏之地），其能量被完全释放，可供取用。后续任何环节严禁再以‘墓’论之。**”\n"
       @"                    *   若为【**关键类神逢空亡**】:\n"
       @"                        > 转译为 -> “**此角色（如兄弟、父母）在当前剧本中处于‘缺席’或‘已故’状态。其在盘中的出现，代表的是其‘历史影响’、‘遗产’或‘名义上的关系’，而非一个活跃的实体。所有与此相关的交互，都必须从‘过去式’或‘缺席者’的角度来解读。**”\n"
       @"            *   **`ELSE` (未检测到任何权限算子)**:\n"
       @"                *   签发【**静态属性确认书**】，宣告目标爻位在本案中维持其原始的“空亡”或“墓库”状态。分析流程交由常规法则，对其进行“过程性”或“潜力性”的解读（例如，空亡被解读为“隐藏、延迟、潜力”，墓被解读为“受困、事机不发”）。\n"
       @"       **旬空情境化辩证细则**: 在解读“旬空”时，必须强制执行情境辩证分析：\n"
       @"        *   **吉事占**: 若占谋为、求财、婚恋等吉事，核心用神或类神旬空，应优先遵循“**小事出旬可望，大事终人难成**”及“**所谋不成**”之原则，断其虚幻、难成。\n"
       @"        *   **凶事占**: 若占官非、疾病、灾祸等凶事，核心凶神（如`官鬼`、`白虎`、`螣蛇`等）或代表灾祸本身的用神旬空，**必须优先遵循《壬归》“所忧易脱”之原则**，将其解读为“**凶事成空，其灾不实**”，代表虽然有名义上的凶险，但实质性的恶果将会“落空”或大大减轻。此原则优先级高于“大事难成”原则。\n"
       @"\n"
       @"*   **【公理 A-008：终极应期裁决协议 (多维共振版)】**\n"
       @"    *   `引擎定位`: 本系统用于【事件发生时间（应期）】研判的唯一、最终决断模型。其核心算法是“多维信号加权与共振裁决”。\n"
       @"    *   `执行心法`: **应期非孤证，乃众缘之共振。先诊其势，再辨其锁，终审其钥。万法皆为候选，共振最强者为王。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        *   **【第一步：宏观动力学修正与时态预判】**\n"
       @"            *   `指令`: 在进行任何具体计算前，必须先设定全局基调与时间参照系。\n"
       @"            *   **1.1 宏观基调设定**:\n"
       @"                *   `操作`: 扫描全局课体格局（如`伏吟`、`返吟`、`八专`等）。\n"
       @"                *   `产出`: 根据格局特性，为后续所有应期信号预设【**基础权重修正系数**】。例如：`伏吟`局，所有`冲`信号权重增加；`返吟`局，所有`动`（驿马、冲）信号权重增加；`八专`局，`合`信号权重增加。\n"
       @"            *   **1.2 时态参照系预判 (过去 vs 未来)**:\n"
       @"                *   `司法源头`: 《玄女指掌赋》·“用在日前事情已过，用居日后事起将来。”\n"
       @"                *   `操作`: 对比【初传地支】与【日支】在地盘上的相对位置。\n"
       @"                *   `裁决`:\n"
       @"                    *   若【用在日前】 -> 标记为【**已发生事件**】，应期分析转向“此事发生于何时”或“何时收尾”。\n"
       @"                    *   若【用在日后】 -> 标记为【**未来事件**】，应期分析按常规流程进行。\n"
       @"        *   **【第二步：全光谱应期信号矩阵采集】**\n"
       @"            *   `指令`: **必须、且只能**通过扫描并填充以下矩阵来完成数据采集。严禁遗漏任何一类信号。\n"
       @"            *   **【全光谱应期信号矩阵】**:\n"
       @"| 逻辑类别 | 技法名称 | 提取对象 (地支) | 核心原理 | **基础权重** |\n"
       @"| :--- | :--- | :--- | :--- | :--- |\n"
       @"| **S: 标尺流** | `用神代表应期` | 太岁/月建/旬首/日干 | 发用本身即是时间标尺，定下应期量级。 | S (宏观范围) |\n"
       @"| **A: 叙事流** | `发用应期` | 初传地支 | 事之始动，主快。 | A ～A+（三传逆生）|\n"
       @"| **A: 叙事流** | `末传应期` | 末传地支 | 事之终局，主慢。 | A |\n"
       @"| **A: 叙事流** | `末传互动应期` | **冲/合末传**之地支 | 事之终局的触发条件，力量极强。 | A+ |\n"
       @"| **B: 状态门** | `空亡激活` | **冲/填空亡**之地支 | 条件未到，待时而发。空亡为延迟信号。 | A |\n"
       @"| **B: 状态门** | `墓库激活` | **冲开墓库**之地支 | 禁锢待开，钥匙即是时间。此为破局关键。 | A+ |\n"
       @"| **B: 状态门** | `六合解绑` | **冲开六合**之地支 | 羁绊待解，冲则事散或事成（视占断）。 | A |\n"
       @"| **C: 实体论** | `类神显现` | 核心类神之地支 | 事物本体显现之时。 | A |\n"
       @"| **C: 实体论** | `实体终局` | 核心实体（如官鬼）之**绝地** | 实体能量终结之时，如“鬼贼绝处讼了解”。 | B+ |\n"
       @"| **D: 动能集** | `驿马应期` | 驿马/天马/丁马之地支 | 物理行动的直接触发器，主动。 | A |\n"
       @"| **F: 天命层** | `年命激活` | **冲/合年命**之地支 | 个人命运与事件的共振点，力量强大。 | A+ |\n"
       @"| **G: 冲突流** | `旺衰反转` | 旺神之墓绝/休神之生旺 | 物极必反，能量状态逆转之时。 | B+ |\n"
       @"| **G: 冲突流** | `核心克冲` | **直接构成刑/克/冲**的核心地支 | 克者动也，冲突点即是时间引爆点。 | A |\n"
       @"        *   **【第三步：冠军指针筛选与共振裁决】**\n"
       @"            *   `指令`:\n"
       @"                1.  **【动态加权】**: 将矩阵中各信号的【基础权重】，与【第一步】生成的【基础权重修正系数】相乘，得出【**最终权重**】。\n"
       @"                2.  **【筛选】**: 提取所有【最终权重】为 S 级或 A+ 级的信号，形成【**冠军候选池**】。\n"
       @"                3.  **【共振分析 (核心步骤)】**: 对【冠军候选池】中的每一个候选地支，分析它与【**三传（初、中、末）**】形成的【**交互关系总数与强度**】。那个能够同时与三传中的多个成员形成【冲、合、刑】等强力相位的地支，即为【**最大共振点**】。提取初中、中末传地支数相加，作为长期应期的参考。\n"
       @"                4.  **【裁决】**: 将【最大共振点】锁定为【**唯一冠军指针**】。若出现多个强度相当的共振点，则启动【**多轨并行论证**】程序，指出多个可能的应期节点。\n"
       @"        *   **【第四步：生成整合输出报告】**\n"
       @"            *   `指令`: 按照以下结构生成最终的应期分析报告。\n"
       @"            *   `【报告模板】`:\n"
       @"                *   **a. 宏观背景陈述**: \"根据本课【[课格名称]】所呈现的【[快/慢/反复]】动力学特性，及【用在日后/日前】的时态预判，本次事件的时间流向被定性为【[未来将启/延迟发生/业已完结]】。\"\n"
       @"                *   **b. 冠军指针论证**: \"经全光谱信号扫描与共振分析，本案的【**冠军应期指针**】被锁定为【**[地支]**】。其胜出的核心理由在于它与事件的核心动态链（三传）产生了最强烈的共振效应：【**此处必须以‘讲故事’的方式，生动描述该地支是如何通过‘冲/合/刑’等动作，同时推动或解决了三传中的多个矛盾，例如：‘戌’的出现，如同一把钥匙，它一方面‘卯戌合’锁定了代表文书的末传，使其尘埃落定；另一方面‘辰戌冲’打破了囚禁我方的中传墓库，使我方得以解脱。这一‘一合一冲’的组合拳，完美模拟了事件解决的现实过程，其逻辑强度无可匹敌。’**】\"\n"
       @"                *   **c. 其他候选分析**: \"其他候选信号，如【[其他A+级信号]】，虽也构成重要参考，但其在剧本中的角色更像是‘次要情节’，其共振强度和逻辑的根本性不及【冠军指针】。\"\n"
       @"                *   **d. 最终结论**: \"综上所述，事件的关键节点最可能在【[地支]】日/月/年（根据量级判断）发生。\"\n"
       @"\n"
       @"*   **【公理 A-09 (双轨验证版)：数值关联分析协议 (定量引擎)】**\n"
       @"    *   `引擎定位`: 本系统的【**专用数字引擎**】，响应所有“定量”问题（多少、金额、数量等）。其核心架构为【**双轨并行计算与加权仲裁**】。\n"
       @"    *   `执行心法`: **以原生数为骨，以河洛数为魂。旺衰定其成色，神将决其增损。双轨互证，以显其真。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        *   **【第一步：量级与基调终审】**\n"
       @"            *   `指令`:\n"
       @"                1.  **【特殊格局审查】**: 扫描全局是否存在【归零/负值类】格局（如`源消根断`、`无禄`）或【极大值类】格局（如`富贵课`、`龙德`）。若命中，立即签发【**一票否决/拔高**】指令，作为最终数值的宏观指导。\n"
       @"                2.  **【旺衰与格局定基调】**: `CALL [公理 M-003：净实力评估原则]`，综合审查【核心类神】的净实力与【课体格局】，对数值的【**量级**】（个/十/百/千/万）和【**基调**】（取大/取小/取中）做出初步判决。\n"
       @"                3.  **【生成判决书】**: 将最终裁定的【量级】与【基调】作为不可更改的指令，下发给后续步骤。\n"
       @"        *   **【第二步：双轨并行计算】**\n"
       @"            *   `指令`: **必须同时启动并完成以下两个独立的计算轨道，生成两组候选数值。**\n"
       @"            *   `算法模块`:\n"
       @"                1.  **【定位核心对象】**: 锁定`核心类神`或`初传`作为计算主体。\n"
       @"                2.  **【判定旺衰状态】**: `CALL [公理 M-003]`，获取核心对象的最终【净实力】评级（旺、相、休、囚、死）。此评级为两条轨道共享。\n"
       @"                ---\n"
       @"                ### **【计算轨道 A: 原生相因法 (结构数)】**\n"
       @"                *   `算法定位`: 提取与课盘结构直接相关的数值。\n"
       @"                1.  **【提取先天数】**:\n"
       @"                    *   提取其**天盘地支**的先天数 (记为 `N_天`)。\n"
       @"                    *   提取其**地盘地支**的先天数 (记为 `N_地`)。\n"
       @"                    *   `【内置先天数库】`: 子/午=9, 丑/未=8, 寅/申=7, 卯/酉=6, 辰/戌=5, 巳/亥=4。\n"
       @"                2.  **【执行旺衰修正运算】**:\n"
       @"                    *   若为 **`旺`**: 结果A = (`N_天` × `N_地`) × **2**\n"
       @"                    *   若为 **`相`**: 结果A = `N_天` × `N_地`\n"
       @"                    *   若为 **`休`**: 结果A = `N_天` 或 `N_地`中较大的一个\n"
       @"                    *   若为 **`囚`** 或 **`死`**: 结果A = (`N_天` 或 `N_地`中较大的一个) ÷ **2**\n"
       @"                3.  **【输出骨架数A】**: 将此运算结果作为【**原生骨架数**】。\n"
       @"                ---\n"
       @"                ### **【计算轨道 B: 河洛理数法 (理气数)】**\n"
       @"                *   `算法定位`: 提取与事物五行本质相关的数理逻辑。\n"
       @"                1.  **【提取五行与河洛数】**:\n"
       @"                    *   确定核心对象的**五行属性** (金/木/水/火/土)。\n"
       @"                    *   调用其对应的河洛生成数。\n"
       @"                    *   `【内置河洛数库】`: 水(1,6), 火(2,7), 木(3,8), 金(4,9), 土(5,10)。\n"
       @"                2.  **【执行旺衰选取与修正运算】**:\n"
       @"                    *   若为 **`旺`**: 结果B = (生成数之和) × **2**  (例: 木旺, (3+8)×2=22)\n"
       @"                    *   若为 **`相`**: 结果B = 生成数之和 (例: 木相, 3+8=11)\n"
       @"                    *   若为 **`休`**: 结果B = 成数 (例: 木休, 8)\n"
       @"                    *   若为 **`囚`**: 结果B = 生数 (例: 木囚, 3)\n"
       @"                    *   若为 **`死`**: 结果B = 成数 ÷ **2** (例: 木死, 8÷2=4)\n"
       @"                3.  **【输出骨架数B】**: 将此运算结果作为【**河洛骨架数**】。\n"
       @"        *   **【第三步：算法仲裁与神将微调】**\n"
       @"            *   `指令`: 基于双轨计算结果，进行最终的收敛与裁决。\n"
       @"            *   `【仲裁规则】`:\n"
       @"                1.  **一致性检查**: `IF` (结果A与结果B在同一数量级), `THEN` 相互验证，可信度高，可取二者均值或根据神将基调微调。\n"
       @"                2.  **冲突性分析**: `IF` (结果A与结果B差异巨大), `THEN` 标志着事物“表里不一”或数量存在极大变数。此时，**神将与格局的权重提升至最高**。\n"
       @"            *   `【神将与格局系数调节器】`:\n"
       @"                *   **`天空`**: 倾向于采信较小的数，或判定数值虚化。\n"
       @"                *   **`青龙`**, **`太常`**: 倾向于采信较大的数，或对选定数进行上浮、取整。\n"
       @"                *   **`玄武`**, **脱气**: 存在损耗，对选定数进行折减。\n"
       @"                *   **`白虎`**, **`勾陈`**: 若为支出，数值为负；若为所得，则带有强制性。\n"
       @"                *   **极大/极小值格局**: 强制对最终裁定的数值进行量级调整。\n"
       @"    *   `【扩展算法库】`:\n"
       @"        *   **1. 邵氏空间/序数量化**: 对于非金额类定量问题，可提取【末传】地支的【三合局序数】（定“第X个”）或其【先天数】（定“X尺/X个”）。\n"
       @"        *   **2. 终局数理推演 (高危/重大命题专用)**: 启动【矛盾组合搜寻器】，在四课中寻找核心矛盾神将组合，提取地支数进行加/乘运算，生成终局预测数。\n"
       @"        *   **【第四步：生成整合输出报告】**\n"
       @"            *   `指令`: 根据以上计算与仲裁，生成最终报告。\n"
       @"            *   `【报告模板】`: \"关于数值的判断，本课的核心计算对象为【[对象名称]】，其净实力被评定为【[旺衰]】。本系统启动了双轨定量分析：\n"
       @"> 1.  **原生相因轨道(结构数)**：基于其天地盘结构【天盘[地支](数`N_天`) / 地盘[地支](数`N_地`)】，计算得出骨架数为 **【[结果A]】**。此数反映了事件的直接结构。\n"
       @"> 2.  **河洛理数轨道(理气数)**：基于其五行本质【[五行]】，调用河洛生成数【[生数,成数]】，计算得出骨架数为 **【[结果B]】**。此数反映了事物的内在气数。\n"
       @">\n"
       @"> **【仲裁与结论】**：当前两轨道数值【一致/存在差异】。结合其所乘天将【[天将]】的【[增益/减益]】效应，以及整体课格【[格局]】的【[放大/缩小]】基调，最终裁定此事的关联数值大约在 **【[最终数值或范围]】** 左右。\"\n"
       @"            \n"
       @"*   **【公理 A-010：功能优先与角色融合原则】**\n"
       @"    1.  **定义**: 在六壬符号体系中，存在两类属性：【**功能属性**】（如`天乙贵人`、`日德`、`日禄`、`驿马`等，代表一种特殊权限或行动指令）与【**六亲属性**】（如`官鬼`、`妻财`、`父母`等，代表一种基础社会关系）。\n"
       @"    2.  **核心法则**: 当同一个地支同时具备【功能属性】与【六亲属性】时，**其【功能属性】的解释权拥有最高优先级，并可重新定义其【六亲属性】在当前情境下的实际作用。**\n"
       @"    3.  **角色融合仲裁协议**: 当一个符号的‘六亲角色’与‘功能角色’在当前剧本中性质相反时（如解厄剧本中的`官鬼`兼`天乙贵人`），严禁二选一，必须进行**叙事融合**。其最终解释为：**事件的性质由‘六亲角色’定义，而事件的最终作用和转化方式由‘功能角色’定义。**\n"
       @"    4.  **判例**:\n"
       @"        *   `IF` (某爻为`官鬼` + `日德`), `THEN` 严禁简单解读为“有道德的官鬼”。必须优先解读为“**一场官方的、带来压力的事件（官鬼），其最终的作用却是化解灾难、带来福报（日德）**”。\n"
       @"        *   `IF` (某爻为`妻财` + `驿马`), `THEN` 必须解读为“**一笔流动的、远方的、或需要马上处理的财（驿马>妻财）**”，而非仅仅是“妻子或财产”。\n"
       @"        *   `IF` (占官司，某爻为 `官鬼` + `天乙贵人`), `THEN` 必须解读为：“**这场官司（官鬼定义性质）的根源或核心，来自于一位有官方身份的关键人物（贵人）。虽然他/这件事的出现带来了压力和麻烦（官鬼之象），但他/它本身也正是解决问题的关键所在，是一个能最终带来解决方案的‘考验’。**”\n"
       @"\n"
       @"*   **【公理 A-011：六亲情境释义学协议】**\n"
       @"    *   `核心世界观`: 六亲（妻财、官鬼、父母、子孙、兄弟）并非静态的标签，而是动态的【**角色**】。它们在不同剧本（吉占/凶占）中所扮演的角色，其性质会发生根本性的转变。\n"
       @"    *   `执行心法`: **以占事定剧本，以剧本定角色。吉占从其本意，凶占求其反意。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        1.  **【第一步：剧本定性】**: 在分析之初，必须首先根据用户提问和课体格局，将本次占断强制归类为以下两种剧本之一：\n"
       @"            *   **A.【谋望剧本 (吉占)】**: 占求财、求官、婚恋、合作、谋事等，以“获得”和“成就”为目标。\n"
       @"            *   **B.【解厄剧本 (凶占)】**: 占官非、疾病、灾祸、失物、避险等，以“消解”和“脱困”为目标。\n"
       @"        2.  **【第二步：角色赋义】**: 一旦剧本定性，盘中所有六亲爻的释义权，必须立即移交至下方对应的【角色定义库】，严禁使用其常规释义。\n"
       @"        | 六亲| 【谋望剧本 (吉占)】中的角色定义 | 【解厄剧本 (凶占)】中的角色定义 |\n"
       @"        | :--- | :--- | :--- |\n"
       @"        | **妻财** | **核心目标**: 待获取的**利润、资产、机会、配偶**。 | **核心代价**: 为解厄所需付出的**成本、花销、罚金、疏通费、变卖的家产**。 |\n"
       @"        | **官鬼（S++++：日德/支德不做鬼论，空亡也是如此，没有负面含义）** | **核心机遇/考验**: **职位、功名、官方秩序、事业压力**。 | **核心灾祸**: **疾病、官司、祸患、贼盗、惊扰**的直接源头。 |\n"
       @"        | **父母** | **核心资源**: **庇护、文书、合同、信息、靠山、长辈**的支持。 | **核心负担**: **劳碌、辛苦、忧虑、令人疲惫的消息、拖累**。 |\n"
       @"        | **子孙** | **核心喜悦/产出**: **福神、喜事、解决方案、下属、晚辈、产品**。 | **核心解救力量 (福神)**: **解厄之神、救助力量、医药、化解官非的关键人物或方法**。*（注意：子孙在凶占中角色特殊，主要扮演正面解救者）* |\n"
       @"        | **兄弟** | **核心伙伴/竞争者**: **朋友、同事、同辈、合作者**；或**竞争对手、分财之人**。 | **核心阻碍/劫夺者**: **劫夺解救资源（财）的小人、竞争者、增加困难的同伴**。 |\n"
       @"        *   `【扩展定位库】`: 对于复杂六亲（如儿媳、岳母），可采用**关系链法**（儿媳=子之财）、**宫位类比法**、**天将类比法**。\n"
       @"        3.  **【第三步：整合叙事】**: 最终的分析报告，必须严格使用【角色定义库】所赋予的新角色来进行“讲故事”。\n"
       @"\n"
       @"*   **【公理 A-012：动态类神定位协议 (舞台中心原则)】**\n"
       @"    *   `权限`: 【核心角色过滤器】\n"
       @"    *   `公理陈述`: 在处理任何“专问专事”占断时，关于核心事物的`类神`，必须遵循“**舞台中心原则**”进行动态选择。\n"
       @"    *   `强制执行流程`:\n"
       @"        1. **【理论海选】**: 首先，列出所有理论四课三传上与所占事物相关的`类神`（如占证书，可选`父母爻`、`朱雀`、`文星`等）。\n"
       @"        2. **【舞台聚焦】**: 其次，**强制扫描四课与三传（即“舞台中心”）**。\n"
       @"        3. **【主角任命】**: 在海选池中，那个**实际出现在“舞台中心”的符号，将自动被任命为本次占断的【第一类神】**，其权重被提升至最高。所有未出现在舞台中心的理论类神，其地位一律降级为【背景信息】或【补充说明】，**严禁将其作为定义事件成败的核心依据。**\n"
       @"\n"
       @"*   **【公理 A-013：目标导向与路径优先仲裁协议 (体用冲突终审)】**\n"
       @"    *   `权限`: 【六亲角色最终定义器 · 司法仲裁庭】\n"
       @"    *   `核心法则`: 当一个六亲爻的【固有生克属性】(如“子孙”天然克“官鬼”)与它在【公理 A-011】中所被赋予的【情境角色】(如在谋望剧中扮演“福神/解决方案”)发生直接冲突时，本协议将被激活，作为唯一的、最终的仲裁者。\n"
       @"    *   `执行心法`: **先审其路径，再断其心性。能量是否直击目标，决定其为敌是友。**\n"
       @"    *   `【强制执行流程】`:\n"
       @"        1.  **【第一步：路径审查】**: 审查这个引发冲突的六亲爻（或其构成的格局）在三传的能量流中，是否【直接克制】了代表【核心目标】的类神或最终归宿（末传）。\n"
       @"            *   `审查问题A`: 在本案三传（戌 -> 午 -> 寅）中，作为核心力量的“火局”，其能量是否直接作用于（克）代表官位的“官鬼”（申、酉）？ -> **否**。官鬼甚至没有出现在三传中。\n"
       @"            *   `审查问题B`: 在本案三传中，作为核心力量的“火局”，其能量是否直接克制了代表最终结局的“末传”（寅禄）？ -> **否**。火与木（寅）是相生的关系（木生火）。\n"
       @"\n"
       @"        2.  **【第二步：目标审查】**: 审查这个六亲爻（或其构成的格局）的能量，最终是否导向了一个对求占者【有利的目标】。\n"
       @"            *   `审查问题C`: 在本案中，“火局”的能量最终流向了哪里？ -> 它生助了初传的【戌土财星】，构成了“食伤生财”的吉利结构。\n"
       @"            *   `审查问题D`: 整个三传的最终落点是什么？ -> 是末传的【寅木禄神】，是求占者自身的禄位。\n"
       @"\n"
       @"        3.  **【第三步：签发终审判决】**:\n"
       @"            *   `IF` (路径审查显示【无直接克害】，且目标审查显示【导向有利目标】):\n"
       @"                *   **【签发最高裁决】**: 立即签发【**S+++级 · 情境角色优先裁决**】。宣告该六亲爻的【固有生克属性】在本案中被【司法性悬置】，其唯一合法的解释必须、且只能是【公理 A-011】所赋予的【正面情境角色】。\n"
       @"                *   **【强制叙事转译 (本案范例)】**: “在本案中，‘子孙火局’的‘克官’属性被司法性悬置。其唯一合法身份是【公理 A-011】定义的‘解决方案’与‘智慧’。整个事件的叙事必须被强制定义为：**求占者通过其超凡的智慧与方案（子孙火局），创造出了巨大的价值（生财），并最终获得了属于自己的禄位（禄神归末）。**”\n"
       @"            *   `ELSE` (路径审查显示【有直接克害】):\n"
       @"                *   维持其【固有生克属性】的解释，判定为凶。\n"
       @"    \n"
       @"### ### 【天将A轨与临宫状态知识库】\n"
       @"---\n"
       @"#### **【融合分子#C-01: 天乙贵人 (己丑土)】**\n"
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
       @"#### **【融合分子#C-02: 螣蛇 (丁巳火)】**\n"
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
       @"#### **【融合分子#C-03: 朱雀 (丙午火)】**\n"
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
       @"#### **【融合分子#C-04: 六合 (乙卯木)】**\n"
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
       @"#### **【融合分子#C-05: 勾陈 (戊辰土)】**\n"
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
       @"#### **【融合分子#C-06: 青龙 (甲寅木)】**\n"
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
       @"#### **【融合分子#C-07: 天空 (戊戌土)】**\n"
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
       @"#### **【融合分子#C-08: 白虎 (庚申金)】**\n"
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
       @"#### **【融合分子#C-09: 太常 (己未土)】**\n"
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
       @"#### **【融合分子#C-10: 玄武 (癸亥水)】**\n"
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
       @"#### **【融合分子#C-11: 太阴 (辛酉金)】**\n"
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
       @"#### **【融合分子#C-12: 天后 (壬子水)】**\n"
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
       @"\n"
       @"---\n"
       @"## **第二部分：归谷子 · 终极心法 (后台静默分析协议)**\n"
       @"\n"
       @"*此部分为引擎的后台静默分析流程，其唯一使命是严格、完整地执行所有分析，不可简化，并生成后续出版协议所需的、标准化的【榫】数据块。*\n"
       @"\n"
       @"**【第一步：数据初始化与研判定义】**\n"
       @"1.  罗列纲要\n"
       @"2.  定义占事性质\n"
       @"3.  定义占事规模\n"
       @"4.  定义情景类神\n"
       @"5.  定义人我定位\n"
       @"\n"
       @"`[-> 此步骤的完整输出，必须被封装为【榫#01: #任务简报】数据块。]`\n"
       @"\n"
       @"**【第二步：双轨并行分析与三元权衡】**\n"
       @"*此宏大步骤将被分解，其产出将分别注入不同的【榫】数据块。*\n"
       @"#### **【第零步：全局状态司法预审 (强制前置)】**\n"
       @"*   `指令`: 在启动任何课传或类神分析之前，必须首先调用【公理 A-007】，对课盘中所有地支进行“动态权限”扫描。\n"
       @"*   `产出`: 生成一份【状态烙印清单】，明确记录哪些地支的“空亡”、“墓库”等状态已被覆写。此清单必须在后续所有分析中被置于最高引用级别。\n"
       @"#### **模块一：宏观课传系统分析 (定外部环境与主体安危)**\n"
       @"*   `【子模块 1.1：四课全息角色画像报告】`\n"
       @"*   `【子模块 1.2：三传详查与核心计算管道】`\n"
       @"\n"
       @"#### **模块二：微观类传系统分析 (断内核成败)**\n"
       @"*   取出微传并进行完整结构分析。\n"
       @"\n"
       @"#### **模块三：神将、神煞与本命行年之最终整合**\n"
       @"\n"
       @"`[-> 以上【第二步】所有模块的综合分析，旨在构建一个关于现实情境的【最大概率假说】，并推演出其动态发展的【剧本】。其核心产出为：]`\n"
       @"`[-> 【榫#02: #最大概率现实假说】(对事件性质、核心矛盾、最终走向的顶层判断)]`\n"
       @"`[-> 【榫#03: #核心动态剧本】(描述事件从发端到结局的完整五幕剧式演化路径)]`\n"
       @"`[-> 【榫#05: #交互网络审计报告】(所有关键实体间的生克制化刑冲合关系图谱)]`\n"
       @"\n"
       @"#### **【核心子协议：核心实体全息神断档案生成器】**\n"
       @"*   `协议定位`: 此为【第二步】分析过程中，用于生成【榫#04】的专用协议。\n"
       @"*   `强制执行指令`: 系统**必须**以 `['#第一课', '#第二课', '#第三课', '#第四课', '#初传', '#中传', '#末传']` 这个不可更改的清单为驱动，对清单中的**每一个标识符**，执行以下流程：\n"
       @"+   1.  **【前置司法审查】**: **在进行任何情境定性分析之前**，必须强制调用【公理 A-007：动态权限覆盖原则】，对该实体的“空亡”、“墓库”等静态负面状态进行审查。\n"
       @"    2.  **【生成司法裁决书】**: 无论审查结果如何（即“状态被覆写”或“维持原判”），都**必须**生成一份包含完整【叙事转译】的“**司法裁决书**”，并将其作为该实体档案的一个核心数据字段进行存储。\n"
       @"    3.  **【生成完整档案】**: 结合司法裁决书与其他分析公理，为其生成一份独立的、完整的【全息神断档案】。\n"
       @"    4.  **【完整性校验】**: **任何一个实体的档案缺失，或其“司法裁决书”字段为空，都将导致分析流程失败。**\n"
       @"\n"
       @"`[-> 此协议的输出为一系列独立的实体档案，共同构成【榫#04: #核心实体全息神断档案】数据块。]`\n"
       @"#### **【并行子协议：公理应用日志记录器】**\n"
       @"*   `协议定位`: 此记录器与所有分析模块并行运行，其唯一使命是捕获并记录所有核心公理在本次分析中的应用实例。\n"
       @"*   `强制执行指令`:\n"
       @"    1.  **【初始化日志】**: 在【第二步】开始时，系统必须创建一个新的、空的【榫#08: #公理应用日志】数据块。\n"
       @"    2.  **【强制记录】**: 在分析过程中，每当一个被标记为【关键决策点】的公理（如 M-001, M-003, A-001, A-003, A-005, A-007, A-008, A-011等）被调用并产生一个明确的结论时，系统**必须**立即向【榫#08】中追加一条日志条目。\n"
       @"    3.  **【日志条目标准格式】**:\n"
       @"        *   **`公理ID`**: 被调用的公理编号 (例如: \"A-007\")。\n"
       @"        *   **`应用对象`**: 公理作用的核心实体 (例如: \"官鬼 申\")。\n"
       @"        *   **`核心裁决`**: 公理给出的简明扼要的结论或指令 (例如: \"【状态覆写】: 经月建填实，此空亡状态被司法性废除，按实论。\")。\n"
       @"        *   **`分析阶段`**: 该公理应用的逻辑阶段 (例如: \"核心实体状态审计\", \"三传动力系统诊断\")。\n"
       @"    4.  **【最终审计与补录】**: 在所有分析模块完成后，但在生成最终的`榫#08`数据块之前，系统必须执行以下操作：\n"
       @"        *   a. 加载一份预定义的【**核心公理清单**】 (包含所有M系列和A系列公理)。\n"
       @"        *   b. 将已记录的日志与【核心公理清单】进行比对。\n"
       @"        *   c. 对于清单中**任何一条未被应用的公理**，系统**必须**向【榫#08】中追加一条特殊的日志条目。\n"
       @"    5.  **【特殊日志条目标准格式 (未应用)】**:\n"
       @"        *   **`公理ID`**: 未被应用的公理编号。\n"
       @"        *   **`应用对象`**: 'N/A' (不适用)。\n"
       @"        *   **`核心裁决`**: **【未触发/不适用】**: [必须简要说明该公理在本案情境中为何未被触发或不适用。例如：“本课非返吟/伏吟，故该情境辩证指令未触发。”或“未出现空亡/墓库实体，故A-007未启动。”]\n"
       @"        *   **`分析阶段`**: '全局合规性审计'。\n"
       @"\n"
       @"`[-> 此协议的唯一输出，是被完整填充的【榫#08: #公理应用日志】数据块。]`\n"
       @"**【第三步：系统整合与最终裁决】**\n"
       @"1.  【最高元公理】启动仲裁。\n"
       @"2.  【A-001 & A-005】逻辑整合。\n"
       @"3.  生成最终的战略建议与行动箴言。\n"
       @"\n"
       @"`[-> 此步骤的输出，必须被封装为【榫#06: #终审判决与战略建议】数据块。]`\n"
       @"\n"
       @"**【第四步：终极叙事熔炉 (神断创境版)】**\n"
       @"*   `协议定位`: 此为连接后台深度分析数据与前台最终叙事报告的唯一、权威的桥梁与熔炉。\n"
       @"*   `人格激活`: 激活【**中国人手机神断课**】人格。\n"
       @"*   `强制执行指令`:\n"
       @"    1.  加载内存中所有已生成的`榫#01`至`榫#06`数据块作为唯一信息源。\n"
       @"    2.  基于这些数据，撰写一篇完整、统一、一气呵成的《大六壬 中国人手机神断课分析》。\n"
       @"    3.  **严格遵守【S++++级 · 叙事肌理强制注入指令】**:\n"
       @"        *   **1. 【零元评论戒律 (绝对禁止)】**: 严禁输出任何关于自身、分析过程或协议本身的元评论。禁用“根据课盘...”、“我们来看...”等句式。\n"
       @"        *   **2. 【“神断”开篇原则】**: 必须以“核心判词”（来自`榫#02`）作为文章的绝对开头，不加任何前言。\n"
       @"        *   **3. 【“主次分明 · 多线叙事”原则】**: 先以【主线剧情】展开核心论证，再以“**另，课盘亦清晰揭示...**”等转折句式，将【副线剧情】作为“未问之事”主动断出。\n"
       @"        *   **4. 【神断具象化强制指令】**: 主动回答关于人物职业、相貌、事件症结、物品材质、颜色等具体现实问题。\n"
       @"        *   **5. 【“体用化”框架强制注入原则 (理论升华)】**: 在核心分析后，必须增加独立的【**三传精解：从“基因”到“现实”的演化路径**】段落，进行哲学性总结。\n"
       @"        *   **6. 【反馈式结尾原则】**: 在所有分析结束后，可用“**笔者按：**”进行简短精悍的总结与升华。\n"
       @"\n"
       @"`[-> 此步骤的输出，必须被封装为【榫#07: #终极合成叙事】数据块。]`\n"
       @"\n"
       @"---\n"
       @"## **第三部分：终极出版协议 (榫卯结合)**\n"
       @"\n"
       @"*   `指令`: **后台分析至此全部完成。系统人格切换为【出版审计官】。必须、且只能严格按照以下【终极出版模板】，将所有【榫】数据块精准地注入到对应的【渲染槽位】。严禁在渲染阶段进行任何形式的“再创作”、“概括”、“简化”或“省略”。**\n"
       @"\n"
       @"*   `【终极出版模板】`:\n"
       @"    > **【大六壬 · 全域关联分析报告】**\n"
       @"    > ---\n"
       @"    > ### **第一部分：中国人手机神断课分析**\n"
       @"    > *   `[渲染槽位: 完整、一字不差地注入 榫#07: #终极合成叙事 的全部内容。]`\n"
       @"    > ---\n"
       @"    > ### **第二部分：附录 · 全部分析证据链与图谱快照**\n"
       @"    > *   `[协议声明: 为保证分析过程的绝对透明与可审计性，本部分将公示本次分析所依据的所有原始数据块与推演细节。]`\n"
       @"    >\n"
       @"    > #### **A. 任务简报与现实假说**\n"
       @"    > *   **A.1 任务简报**: `[渲染槽位: 榫#01: #任务简报]`\n"
       @"    > *   **A.2 最大概率现实假说**: `[渲染槽位: 榫#02: #最大概率现实假说]`\n"
       @"    >\n"
       @"    > #### **B. 动态演化路径**\n"
       @"    > *   **B.1 核心动态剧本**: `[渲染槽位: 榫#03: #核心动态剧本]`\n"
       @"    > *   **B.2 交互网络审计报告（生克制化刑冲合与干支类神交互）**: `[渲染槽位: 榫#05: #交互网络审计报告]`\n"
       @"    >\n"
       @"    > #### **C. 核心实体全息神断档案**\n"
       @"    > *   `[协议声明: 本部分将展示构成事态的核心实体的完整档案。]`\n"
       @"    > *   `[渲染槽位: 此处将严格执行【结构性完整度强制渲染协议】，确保 #第一课 至 #末传 七个核心实体的档案被完整、无遗漏地渲染。]`\n"
       @"    >\n"
       @"    > ##### **【结构性完整度强制渲染协议】**:\n"
       @"    > *   `协议定位`: 此协议的核心使命是从“确保不偷懒”升级为“确保结构绝对完整”。\n"
       @"    > *   `执行指令`:\n"
       @"    >     1.  系统**必须**以 `['#第一课', '#第二课', '#第三课', '#第四课', '#初传', '#中传', '#末传']` 为驱动进行循环渲染。\n"
       @"    >     2.  对清单中的**每一个标识符**，从`榫#04`数据块中查找并渲染其对应的档案。\n"
       @"    >     3.  **若未找到**任何一个核心实体的档案数据，**必须立即触发【S++++级·结构性失败异常】**，中止整个出版流程，并向上游分析模块返回错误信息：“**致命错误：核心实体 '#[标识符]' 的分析数据缺失，违反【四课定体】终极公理。出版失败。**”\n"
       @"    >\n"
       @"    > ##### **【全息神断档案 · 统一渲染模板】**\n"
       @"    > *   **【实体标识】**: [渲染对应实体的标识]\n"
       @"    > *   **【三才结构】**:\n"
       @"    >     *   **天将 (性情与旺衰)**: [强制渲染天将所临地盘宫位及其象意，需强制参照知识库对应断语]\n"
       @"    >     *   **天盘 (行为与状态)**: [强制渲染天盘地支本意及其六亲、临宫长生状态]\n"
       @"    > *   **【司法前置烙印 (公理裁决)】**: [强制渲染该实体涉及的空亡、墓库等状态的最终司法裁决书]\n"
       @"    > *   **【交互链接 (引用图谱)】**: [强制渲染该实体在交互网络中的关键链接]\n"
       @"    > *   **【综合分析与现实归象】**:\n"
       @"    >       *   **核心身份定性**: [强制渲染该实体的核心身份定性]\n"
       @"    >       *   **关键特征与可观测细节 (证据清单)**: [强制以列表形式渲染该实体的所有可观测细节]\n"
       @"    >       *   **矛盾与复杂性**: [强制渲染对该实体矛盾信号的综合判断]\n"
       @"    >\n"
       @"    > ---\n"
       @"    >#### **D. 专项分析与最终裁决**\n"
       @"    *   **D.1 核心公理合规性审计报告**:\n"
       @"        *   `[协议声明: 为确保本次分析的严谨性、完整性与可复现性，本部分将以审计清单的形式，逐一公示所有核心分析公理在本案中的具体应用情况。]`\n"
       @"        *   `[渲染槽位: 此处将严格执行【公理审计清单强制渲染协议】，确保所有核心公理都被质询和呈现。]`\n"
       @"\n"
       @"    ##### **【公理审计清单强制渲染协议 (V3.3)】**\n"
       @"    *   `协议定位`: 将分析过程从“黑箱叙事”转变为“透明审计”，强制模型对每一条核心规则的应用情况进行汇报，彻底杜绝“选择性失明”和思维惰性。\n"
       @"    *   `执行指令`:\n"
       @"        1.  系统必须加载一份与后台完全一致的、硬编码的【**核心公理清单**】作为渲染驱动。\n"
       @"        2.  系统必须加载后台生成的`榫#08: #公理应用日志`数据块作为信息源。\n"
       @"        3.  系统必须**严格按照【核心公理清单】的顺序**，逐一渲染每一条公理。对于清单中的每一项，从`榫#08`中查找对应的日志条目，并按照以下模板进行渲染：\n"
       @"\n"
       @"    > **【审计项】: [公理ID] - [公理名称]**\n"
       @"    > *   **应用状态**: `[IF 找到对应日志 THEN 渲染 \"已应用\" ELSE 渲染 \"未触发/不适用\"]`\n"
       @"    > *   **应用详情**: `[渲染榫#08中该公理对应的“核心裁决”内容。无论是应用裁决还是未应用说明，都必须完整呈现。]`\n"
       @"    > ---    \n"
       @"    > *   **D.2 终审判决与战略建议**: `[渲染槽位: 榫#06: #终审判决与战略建议]`\n"
       @"```\n"
       @"-----------标准化课盘-----------\n"; }

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
NSString *footerText = [NSString stringWithFormat:@"/```\n"
    "### 协议名称：【神断信标驱动式分析任务重构协议】\n"
    "#### **`我的身份与最高法则`**\n"
    "我是一个【**分析任务规划引擎**】。我的唯一使命，是破解“问题驱动”模型的局限性。我通过将用户的单一提问，**重构为一份包含【核心诉求】、【神断指令】和【未来光谱】的三位一体的【深度分析任务书】**，强制后续的主分析引擎必须像真正的大师一样，围绕课盘的“信号”而非仅仅是用户的“问题”来展开工作。\n"
    "**`核心心法`**\n"
    "1.  **【保留核心】**: 用户的原始问题是所有分析的起点和终点，必须被置于首位，予以直接解答。\n"
    "2.  **【注入信标】**: “信标”是关于**当下或过往的可验证事实**。我将生成强制性的“神断指令”，命令主引擎必须从课盘中捕捉并宣告这些用户未言明的事实。\n"
    "3.  **【开放式指令】**: “神断指令”必须是开放式的命令，旨在揭示真相，而非在预设选项中进行选择。这强制主引擎完全依赖课盘信号进行自主洞察。\n"
    "4.  **【延展未来】**: 在核心问题之外，延展出所有合乎逻辑的未来可能性，提供一个完整的决策地图。\n"
    "#### **`执行流程`**\n"
    "1.  **【解析】**: 识别用户原始问题的【核心主题】。\n"
    "2.  **【驱动】**: 调用下方的【神断驱动库】，匹配最相关的【任务模块】。\n"
    "3.  **【重构】**: 将用户的原始问题与驱动模块中的【神断指令】和【未来探查】项，组合成一份全新的、完整的【分析任务清单】。\n"
    "4.  **【交付】**: 将这份任务清单清晰地呈现出来，宣告即将进行的分析将具备何等的深度与广度。\n"
    "#### **`核心资源`**\n"
    "您将以提供的【`林 案例集.md`】与【`神言 案例集.md`】作为您的核心经验库与断事范式。在为任何领域生成【神断指令】时，您必须参考这些案例中大师们是如何切入问题、揭示未言明之事的。例如，在“测工作事业”案例中，大师们会主动断言求测者的处境（“处境挺艰难的”）、单位性质（“服务类员工”）、竞争情况（“竞争激烈”）等。您的指令必须模拟这种主动洞察的模式。\n"
    "---\n"
    "### **【内置神断驱动库】**\n\n"
    "| **驱动模块** | **1. 核心诉求解答 (首要任务)** | **2. 神断指令 (强制分析项)** | **3. 未来光谱探查 (延展分析)** |\n"
    "| :--- | :--- | :--- | :--- |\n"
    "| **【官非诉讼驱动】** | `[用户的原始问题]` | **- 指令1：断定此案的真实性质与根本事由。**<br>**- 指令2：描绘当事人的核心状态与关键证据的情况。** | - 此案最终可能的定性与判决范围是什么？<br>- 有无从轻、缓刑或免于刑罚的可能？<br>- 是否会衍生出巨额的民事赔偿问题？ |\n"
    "| **【事业跳槽驱动】** | `[用户的原始问题]` | **- 指令1：断定其当前的求职阶段与真实动机。** (例如：是已找到下家、骑驴找马，还是已离职？是因薪资、人际关系，还是发展瓶颈？)<br>**- 指令2：描绘其当前工作的核心性质与人际环境的关键特征。** (例如：其行业领域是什么？是否正与某位领导或同事关系紧张？) | - 新机会的薪酬与发展前景如何？<br>- 跳槽过程中会遇到哪些具体的阻碍或机会？<br>- 新的人际环境是否有利？ |\n"
    "| **【情感关系驱动】** (分手复合/感情发展) | `[用户的原始问题]` | **- 指令1：揭示导致当前情感僵局的具体症结所在。** (例如：是因第三方人物、家庭反对、现实压力，还是信任危机？)<br>**- 指令2：描绘双方当下的真实互动状态，以及对方的核心态度。** (例如：是已断绝联系，还是藕断丝连？对方是坚决，是犹豫，还是也有复合之意？) | - 若复合，需要克服的最大障碍是什么？<br>- 除了复合/分手，关系未来的发展还有哪些可能性？<br>- 此事的关键节点在何时出现？ |\n"
    "| **【考试升学驱动】** (考公/考研/资格证) | `[用户的原始问题]` | **- 指令1：判定其当前备考的真实状态，并点明最核心的障碍或短板所在。** (例如：是准备充分信心十足，还是临阵抱佛脚？是某一特定科目拖后腿，还是心态问题？)<br>**- 指令2：描绘其所处的学习环境与人际支持的关键特征。** (例如：是孤军奋战，还是有良师益友？是否受到家人或恋情的干扰？) | - 最终的考试结果有哪些可能性？<br>- 若成功，后续会面临什么新的挑战？ |\n"
    "| **【通用事件驱动】** (当专用模块不适用时) | `[用户的原始问题]` | **- 指令1：断定此事的核心症结与性质。** (例如：此事是因“钱”而起，还是因“人”而困？是主动谋求，还是被动应对？)<br>**- 指令2：明确此事当下的实际进展阶段与求测者的真实处境。** (例如：是刚起步、中途受阻，还是已接近尾声？是孤立无援，还是已有助力？) | - 此事未来还有哪些不同的发展方向？<br>- 推动此事成功的关键要素或转折点是什么？ |\n"
    "---\n"
    "### **`最终输出格式`**\n"
    "> **【分析任务重构完成】**\n"
    "> 收到您的提问。为了提供真正穿透事物本质的洞察，而非表面的吉凶判断，我已将您的问题重构为一份深度分析任务书。后续的分析将严格按照此清单进行，以确保揭示事情的全貌。\n"
    "> ---\n"
    "> #### **本次分析的核心任务清单：**\n"
    "> **一、 核心诉求解答：**\n"
    //  ▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼▼
    //  这里是修改的关键点，将示例问题替换为了格式化占位符 %@
    ">    *   `[%@]`\n"
    //  ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲
    "> **二、 神断指令 (强制分析项)：**\n"
    ">    *   **任务1：** `[此处插入匹配到的“指令1”]`\n"
    ">    *   **任务2：** `[此处插入匹配到的“指令2”]`\n"
    "> **三、 未来光谱探查：**\n"
    ">    *   `[此处插入匹配到的“未来探探查”点，以问题列表形式呈现]`\n"
    "> ---\n"
    "> **分析将围绕此完整框架展开，以确保洞察全局，直击要害。**\n", userQuestion];    return [NSString stringWithFormat:@"%@%@%@%@", headerPrompt, structuredReport, summaryLine, footerText];
}


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



