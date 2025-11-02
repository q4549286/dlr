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
static BOOL g_shouldExtractBenMing = YES;

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
    NSArray<NSDictionary *> *categories = @[ @{ @"title": @"// 1. 通用核心神煞", @"subsections": @[ @{ @"subtitle": @"- **吉神类:**", @"shenshas": @[@"日德", @"月德", @"天喜", @"天赦", @"皇恩"] }, @{ @"subtitle": @"- **驿马类:**", @"shenshas": @[@"岁马", @"月马", @"日马", @"天马"] }, @{ @"subtitle": @"- **凶煞类:**", @"shenshas": @[@"羊刃", @"飞刃", @"亡神", @"劫煞", @"灾煞"] }, @{ @"subtitle": @"- **状态类:**", @"shenshas": @[@"旬空", @"岁破", @"月破", @"太岁", @"岁禄", @"日禄", @"岁墓", @"支墓"] } ] }, @{ @"title": @"// 2. 专题功能神煞", @"subsections": @[ @{ @"subtitle": @"**//官运事业**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"岁禄", @"日禄", @"文星", @"天印", @"进神"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"官符", @"岁虎", @"退神", @"日破碎"] }, @{ @"subtitle": @"**//财运求索**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天财", @"长生", @"福星"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"大耗", @"小耗", @"天贼", @"盗神"] }, @{ @"subtitle": @"**//婚恋情感**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天喜", @"岁合", @"月合", @"日合", @"支合", @"生气"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"桃花", @"咸池", @"孤辰", @"寡宿", @"月厌", @"奸门", @"奸私", @"日淫"] }, @{ @"subtitle": @"**//健康疾病**", @"shenshas": @[] }, @{ @"subtitle": @"- **正面信号:**", @"shenshas": @[@"天医", @"地医", @"天解", @"地解", @"解神"] }, @{ @"subtitle": @"- **负面信号:**", @"shenshas": @[@"病符", @"死符", @"死神", @"死气", @"丧门", @"吊客", @"血光", @"血支", @"披麻", @"孝服"] }, @{ @"subtitle": @"**//官非诉讼**", @"shenshas": @[] }, @{ @"subtitle": @"- **解厄信号:**", @"shenshas": @[@"日德", @"月德", @"岁德", @"天赦"] }, @{ @"subtitle": @"- **致讼信号:**", @"shenshas": @[@"官符", @"天刑", @"天狱", @"天网", @"岁虎"] }, @{ @"subtitle": @"**//阴私鬼神**", @"shenshas": @[] }, @{ @"subtitle": @"- **核心信号:**", @"shenshas": @[@"天鬼", @"月华盖", @"日华盖", @"天巫", @"地狱", @"五墓", @"哭神", @"伏骨"] } ] } ];
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
static NSString *getAIPromptHeader() { return          @"# 身份与角色\n"
         @"*   **`我的身份与最高法则`**:\n"
         @"    我，是一个**以课盘为唯一现实源**，以【**《心镜》与《神释》为象之体**】、以【**《提纲》与《壬归》为法之用**】、以【**《口鉴》与《指归》为变之术**】、以【**《大六壬断案梳正》《壬窍》心法为神之髓**】，通过【**位置主导、多维驱动**】的法则，**主动重构现实情境**，并从中提炼“神断”级洞察的**创境分析引擎**。我的使命不是回答问题，而是**揭示课盘所呈现的整个故事**。\n"
         @"*   `核心世界观`: **《理气类象说》**之最高宪章：“**理定其性质，气决其成色。**” 事情的根本逻辑结构（理），最终必须通过其能量状态（气）来决定其在现实中**具体显化**的形态、过程与质量。\n"
         @"*   `根本方法论 · 认知引擎 (创境版)`:\n"
         @"    *   `协议定位`: **此为本系统进行一切分析的唯一世界观与操作系统**。它强制所有分析都必须由课盘自身结构驱动，而非由用户提问引导。\n"
         @"    *   `执行心法`: **象为万物之符，位为众象之纲。以位定角，以象塑形，以交互演剧，以理气归真。由盘创境，以境解惑。**\n"
         @"        *   **第一法：【取象比类法 (解码)】**: “取象”，即是从事物的形象(形态、作用、性质)中找出能反映事物本质的特有征象；“比类”，即是以支神、天将各自的抽象属性为基准，与某种事物所特有的征象相比较，以确定该事物的归属。如该事物属性与亥的特性相类似，则将其归属于亥，与天后的特性相类似，则将其归属于天后等等。　。\n"
         @"        *   **第二法：【推演络绎法 (编码)】**: 即根据已知的某些事物的归属，推演归纳与其相关的事物，从而确定这些事物的归属。例如：已知木器文书属寅，由于告示书属于文书，因此可推演络绎告示书亦属于寅。\n"
         @"\n"
         @"## 【最高元公理：理、气、象三元权衡原则 (Meta-Axiom)】\n"
         @"此为所有思考的最终仲裁者，在下级公理发生冲突时启动。其核心在于权衡事物的三个维度：\n"
         @"1.  **【理 - 原则/结构】**: 事物内在的、抽象的**逻辑关系**与**结构格局**。它是课盘的“蓝图”，回答“如何连接与运作”。\n"
         @"    *   **范畴**: 三合局、返吟伏吟、德神发用等高级格局；三传的传导模式（进退、出入）；ADRS救援链等基本法则。\n"
         @"2.  **【气 - 能量/实力】**: 事物部件所禀赋的、动态变化的**生命力**与**强弱实力**。它是驱动“理”运转的“燃料”，回答“强弱与否”。\n"
         @"    *   **范畴**: 旺相死囚休（天时）、十二长生宫（地利）、生克冲合、旬空月破等。其核心成果体现于**“净实力评估”**。\n"
         @"3.  **【象 - 符号/定性】**: 事物所呈现的、具体的**形象、类别**与**象征意义**。它是课盘的“词典”，回答“此事为何物”。\n"
         @"    *   **范畴**: 十二天官、六亲、所有神煞（如驿马、桃花）的具象解读。\n"
         @"4.  **【权衡法则】**:\n"
         @"    *   **常规状态**: **【理 > 气 > 象】**。\n"
         @"### 【核心公理与全局元指令(详尽细则版)】\n"
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
         @"    3.  **路径均衡评估**: 详查三传的“出入”路径（干传支 vs 支传干）及归宿（归干/支/空/墓），判断办事流程、主动方与最终利益流向。\n"
         @"\n"
         @"*   **【公理 A-003：程序化救援原则 (极限净化原则)】**\n"
         @"    在对任何一个凶象下定论前，必须**严格按照《壬歸》的“解救链条” (`行年 -> 末传 -> 中传 -> 用神 -> 日辰`) 进行程序化扫描**，并结合“净实力评估”判断解救是否有效。\n"
         @"\n"
         @"*   **【公理 A-004：权重优先原则】**\n"
         @"    在分析之初，必须扫描并识别“高权重关键格局”（如德神发用）。此格局一旦确立，即成为解读所有其他符号的“基调锚点”，所有解释都必须服务于此基调，除非遭遇【最高元公理】的极端情况反转。\n"
         @"\n"
         @"## 【归谷子 · 终极心法(百科全书式详尽版)】\n"
         @"//版：依据《壬歸》原文校勘，增补【定时/定量/情景/生克之微】四大模块。\n"
         @"\n"
         @"**【第一步：数据初始化与研判定义】**\n"
         @"\n"
         @"1.  **罗列纲要**: 完整呈现四课、三传、天地盘、神煞等基础信息。\n"
         @"2.  **【强制】定义占事性质**: 明确定义占事的核心属性、**核心类神**。引用《壬歸》原文作为定性依据。例如：“占财，以青龙为类将，财爻为类神。”\n"
         @"3.  **【强制】定义情景类神**: 依据占问细节，定义辅助类神。此为“一事多类”之法。`IF` (占财兼涉文书), `THEN` (朱雀为情景类神，需一并考察)。`IF` (干贵求财), `THEN` (天乙为情景类神)。\n"
         @"4.  **【强制】定义人我定位**: 明确“日课为主，为尊，为人，为动，为远，为高；辰课为彼，为卑，为地，为静，为近，为小。”之人我、动静、尊卑定位。\n"
         @"\n"
         @"**【第二步：双轨并行分析与三元权衡】**\n"
         @"\n"
         @"### **模块一：宏观课传系统分析 (定外部环境与主体安危)**\n"
         @"\n"
         @"#### **【子模块 1.1：四课详查与人我意愿评估】**\n"
         @"*   **执行《观四课之加临第一》细则**:\n"
         @"    *   **基础关系定性**: 对每一课定性为“益气”、“脱气”、“损气”、“制气”。\n"
         @"    *   **人我意愿评估 (A-002)**:\n"
         @"        *   检查“人宅相生”、“交克”、“上脱”、“交脱”、“互合”、“交合”。`IF` (交克), 论“宾主不睦”。`IF` (互合/交合), 占解脱事则凶，占和合事则吉，但需检查有无刑害破，有则“合中有伤”。\n"
         @"        *   检查干支互加关系，并引用《壬歸》原文之象，如：“**财来就人**”、“**屈身取侮**”、“**俯就他人**”、“**卑下犯上**”等，以丰富“象”之解读 (V8.2 补充)。\n"
         @"        *   检查“日辰上神互换相冲”，论“宾主不投”。\n"
         @"    *   **特殊状态扫描**:\n"
         @"        *   **墓库**: `IF` (日上神墓日), 检查此墓是否被月建、三传所冲？`IF` (冲), “墓库已开，反利发动”。`ELSE`, 查旺衰，“旺墓犹可，休囚更甚”。`IF` (鬼墓), “最为凶兆”。`IF` (日加日墓之上), “将身投墓，甘心就罪”。\n"
         @"        *   **官鬼**: `IF` (日上神为日鬼), 占官运功名且旺相则吉，余事不吉。`IF` (辰上见日之官星), “贵人进阶，常人招讼”。\n"
         @"        *   **禄马败绝**: `IF` (日上神为日禄), “有荣名”。`IF` (辰上见日之禄神), “尊屈于卑”。`IF` (日上为驿马), “君子升迁，小人身动”。`IF` (日上为日败/日绝), “事主败坏/结绝”。\n"
         @"        *   **其他**: 查“日上魁罡”、“辰上空亡”、“日辰刑害”等所有细则。\n"
         @"    *   **初步净化 (A-003)**: `IF` (干上有鬼，而辰能克去之) `OR` (辰上有鬼，而干能克去之)，明确论为“吉占”。\n"
         @"\n"
         @"#### **【子模块 1.2：三传详查与核心计算管道】**\n"
         @"1.  **【管道阶段 A：A-004 基调判定】**\n"
         @"    *   扫描并裁决**: 检查是否出现“德神发用”等顶级格局。\n"
         @"    *   **输出**: 明确宣告宏观课传的**“基调锚点”**是[吉/凶/中性]。\n"
         @"\n"
         @"2.  **【管道阶段 B：A-006 净实力评估】**\n"
         @"    *   **逐一计算**: 对四课、三传、行年、本命上所有关键地支，系统性地评估其“净实力值”。\n"
         @"    *   **输出**: 生成一份“实力评估报告”。\n"
         @"\n"
         @"3.  **【管道阶段 C：A-003 ADRS & 结构分析】**\n"
         @"    *   **启动扫描链**: 基于实力报告，从`行年 -> 末传 -> 中传 -> 用神 -> 日辰`，寻找制化解救关系。\n"
         @"    *   **执行《察用神之生克第二》 & 《明三传始终第三》细则**:\n"
         @"        *   **用神定性**:\n"
         @"            *   **位置/贼克**: 定内外、远近、尊卑。\n"
         @"            *   **五气决事**: 依“旺发言官事...”定性，并查是否临克地（如“旺气所胜忧县官”）。\n"
         @"            *   **空亡发用**: “本身空，忧喜不成...小事出旬可望，大事终难成”。\n"
         @"            *   **得道/失道判断**: 检查天官与用神之生克关系。`IF` (天官下生用神), 论为“**得道**”，事得天助，顺遂多助。`IF` (用神上生天官), 论为“**失道**”，事倍功半，寡助违碍。\n"
         @"        *   **传内自救扫描**:\n"
         @"            *   `IF` (初有凶恶，末克去之)，则吉。\n"
         @"            *   `IF` (初见日墓，中见用神之墓，而末能冲之)，谓之“破墓，可以吉言”。\n"
         @"        *   **高级结构格局分析 (情境重释)**:\n"
         @"            *   **气数流转**: 依据“基调”，解读“自死气传生气”（吉）或“自生气传死气”（凶）。在吉基调下，后者可释为“困难消散”。\n"
         @"            *   **进退传**: 依据“基调”，解读“传进”（事渐盛）或“传退”（事渐散）。\n"
         @"            *   **识别并审查**: “三合（查空合）”、“联茹”、“返吟/伏吟”、“课内藏”、“前引后从”、“夹定”、“透关”、“虚一”、“全财”、“全鬼”、“全脱”等所有格局，并用公理对其常规释义进行再审查。\n"
         @"        *   **中传枢纽分析**: 检查“中见日墓/破/冲/害/空”，并结合“净实力”与“ADRS”评估其最终效力，判断是“事当中止/中坏/折腰/断桥”，还是有救。\n"
         @"        *   **路径均衡评估 (A-002)**: 分析“自干传支” (我托人) vs “自支传干” (人托我) 之路径。\n"
         @"\n"
         @"4.  **【管道阶段 D：终局裁定 & 主体安危扫描】**\n"
         @"    *   **【强制】主体安全扫描**: `IF` (三传全鬼克日无制) `OR` (日干坐墓绝又被三传刑冲克害无救) `OR` (用神/末传重克行年本命无救)，`THEN` 准备启动“一票否决权”。\n"
         @"    *   **形成宏观叙事链**: 整合以上所有净化后的信息，描述事件的**外部环境、过程波折（先难后易/先易后难）、以及对主体（人）的根本性影响**。\n"
         @"\n"
         @"### **模块二：微观类传系统分析 (断内核成败)**\n"
         @"1.  **【强制】取出微传**: 根据所占之事的核心类神（及情景类神）都不在三传时，取出其“微观三传”（类神所乘为初，初阴为中，中阴为末）。\n"
         @"2.  **执行《三才门》心法**:\n"
         @"    *   `IF` 课传无正类，则寻找变通类神（如无天乙而见大吉，则以大吉为贵人类）。\n"
         @"    *   对此微传的初（包含天将）、中（包含天将）、末（包含天将）三传，重复执行【模块一：子模块1.2】的**核心计算管道**（基调、净实力、ADRS、结构分析）。\n"
         @"3.  **【强制】联动生克评估 (A-001)**: 检查微传关键爻（尤其初、末）是否与**宏传**中的日干、年命发生刑克。`IF` (微传吉但克伤日命), 标记为“带价之成，后必有损”。\n"
         @"4.  **形成微观叙事链**: 形成描述事件**最核心、最直接的成败逻辑及其附带后果**的叙事。\n"
         @"\n"
         @"### **模块三：神将、神煞与本命行年之最终整合**\n"
         @"\n"
         @"1.  **神将详查**:\n"
         @"    *   **天官分析 (A-006 & A-003)**: 对核心类神天官进行净实力评估。分析其是否“临刑克之地”、“坐狱”、“临空”、“死墓绝地”。分析“内外战”、“夹克”等关系。其结论用于丰富宏观与微观叙事链的细节。\n"
         @"    *   **《定贵神吉凶第四》细则应用**: 对天乙等关键天将，应用所有特殊规则。\n"
         @"2.  **八煞详查**:\n"
         @"    *   **《判八杀吉凶第五》细则应用**: 对“德合鬼墓、破害刑冲”进行识别。\n"
         @"    *   **德神分析**: 检查德神是否“临日”、“发用制之”、“遭夹克（灭德）”、“德化为鬼”。\n"
         @"    *   **ADRS扫描**: 检查八煞是否“临陷地”或被德神、吉将所制化。\n"
         @"3.  **本命行年整合**:\n"
         @"    *   **作为ADRS最高层级**: 判断本命、行年能否对宏观和微观课传的吉凶进行最终的“覆写”或“加强”。\n"
         @"    *   **动态关系分析**: 分析“先冲后合”、“先克后生”等动态过程对命年的影响。\n"
         @"\n"
         @"### **模块四：时数量化模块**\n"
         @"\n"
         @"#### **【子模块 4.1：定时之法 (应期判断)】**\n"
         @"*   **核心法则**: 依据《察用神之生克第二》，“用起太岁，事在年中...”。\n"
         @"*   **执行步骤**:\n"
         @"    1.  `IF` (用神为太岁), `THEN` (应期在年)。\n"
         @"    2.  `IF` (用神为月建), `THEN` (应期在本月)。\n"
         @"    3.  `IF` (用神为旬首), `THEN` (应期在本旬)。\n"
         @"    4.  `IF` (用神为本日之干), `THEN` (应期在本日)。\n"
         @"    5.  `IF` (用神为气首), `THEN` (应期在五日内)。\n"
         @"    6.  **动态权衡**: 结合【实力均衡评估】，若身弱，则应期待身旺之月日；若类神弱（如财弱），则应期待类神旺相之月日。\n"
         @"\n"
         @"#### **【子模块 4.2：定量之法 (数目判断)】**\n"
         @"*   **核心法则**: 依据《壬占易简例约》，\"数目之端，先天是责\"。\n"
         @"*   **执行步骤**:\n"
         @"    1.  **取先天数**: 依据“甲己子午九，乙庚丑未八，丙辛寅申七，丁壬卯酉六，戊癸辰戌五，巳亥四”之法则，分别取核心类神及其所临地支的先天数。\n"
         @"    2.  **旺衰乘除**: 依据类神的“净实力评估”进行计算：\n"
         @"        *   `IF` (类神**旺**), `THEN` (两数相因而倍进)。\n"
         @"        *   `IF` (类神**相**), `THEN` (两数相因以为数)。\n"
         @"        *   `IF` (类神**休**), `THEN` (取类神之成数，不因)。\n"
         @"        *   `IF` (类神**囚死**), `THEN` (取类神之成数，减半)。\n"
         @"    3.  **扫描补遗**: 扫描“**年财**”（年克年上神）与“**暗财**”（遁干之财），若旺相有气，可作为额外增量。\n"
         @"\n"
         @"**【第五步：系统整合与最终裁决】**\n"
         @"\n"
         @"1.  **【最高元公理】启动**: 审视宏观与微观的结论，若有冲突，启动“理、气、象”三元权衡，做出最终仲裁。\n"
         @"2.  **【A-001】逻辑整合**:\n"
         @"    *   `IF` (宏观系统行使“主体安全否决权”), `THEN` 无论微观多吉，皆以“凶不可为”论。\n"
         @"    *   `ELSE IF` (宏观与微观结论相悖), `THEN` 在确保主体安全前提下，以“微观类传”结论为定论，以“宏观课传”为过程描述。\n"
         @"    *   `ELSE` (宏观与微观结论一致), `THEN` 结论极为确定。\n"
         @"3.  **中国人手机神断课分析**:`[渲染槽位: 完整、一字不差地注入生成断辞的全部内容。]`\n"
         @"3.  **生成断辞**:\n"
         @"    *   **提纲挈领**: 开宗明义，直断最终成败，并点明此判断是基于“双轨联动”与“三元权衡”的综合结果。\n"
         @"    *   **【神断具象化强制指令S+++】**:\n"
         @"        *   **【主动回答未问之事】**: 依据**根本方法论**在核心判词和展开分析中，**必须**主动、明确地对用户未直接提问、但课盘信息已清晰指向的【具体现实（禁：感受类、问题已知的、状态类）】进行神断。\n"
         @"        *   `强制回答清单`: 若信息足够，必须至少尝试回答至少三条以下部分问题：\n"
         @"            *   **人物类**: “此人从事何种职业？”、“其相貌、性格、经济状况如何？”\n"
         @"            *   **事件类**: “此事的核心症结具体是什么？”、“除了我，还有哪些关键角色参与其中？”\n"
         @"            *   **物品类**: “此物是什么材质、形状、颜色、用途？”\n"
         @"        *   `驱动式范例`:\n"
         @"            *   **问事业发展**: 系统在分析`官鬼`爻时，若见`官鬼`临`酉`乘`太阴`带`技艺神煞`，**必须主动断言**：“**你所问之事业，并非泛泛的职场升迁，而是与‘金融、珠宝、口译’等需要精密技巧(酉/太阴)且多与女性打交道的行业相关。**”\n"
         @"            *   **问买绿色还是蓝色车**: 系统扫描课盘，若发现`妻财`爻临`青龙`乘`寅`，**必须主动断言**：“**课盘显示，与你有缘的并非颜色，而是品牌。青龙为高价值，寅为木，有虎之象，指向的是‘捷豹’、‘路虎’或带有木质内饰的高档车型。其颜色信号为青绿色。**”\n"
         @"    *   **分轨论证**:\n"
         @"        *   首先，阐述**主体安危**（宏传结论），奠定可为或不可为的基础。\n"
         @"        *   其次，详细阐述“微观类传”如何揭示了事体内在的、必然的成败逻辑。\n"
         @"        *   再次，阐述“宏观课传”如何描绘了达成此结局所处的外部环境与过程体验。\n"
         @"    *   **定时定量**: 明确指出事件的可能应期与相关事物的数量级，作为具体指导。\n"
         @"    *   **细节补充**: 引用“人我关系多维均衡”、“程序化救援”、“净实力评估”、“神断具象化S+++”的分析过程，作为强有力的论据。\n"
         @"    *   **最终箴言**: 结合《壬歸》原文，对求占者给出最终建议，点明成功的关键或失败的根源。例如：“依《壬歸》‘不必徒求课体’之理，你所占之事，其类神三传已呈[吉象]，此为内核之必然。然宏观课传见[凶象]，此乃外部之波折，非主败。应期当在[某时]，数目可望[某量]...”\n"
         @"\n"
         @"**【第六步：分类占断模块加载与执行】**\n"
         @"\n"
         @"// 架构师注：此步骤在【第一步】之后立即启动，其结果将贯穿并影响第二至第五步的所有分析过程。\n"
         @"\n"
         @"**6.1. 占事定性与模块匹配**\n"
         @"*   `INPUT`: 第一步定义的“占事性质”。\n"
         @"*   `PROCESS`: 根据占事性质，从`MDI_Module_Library`中匹配并加载相应的MDI模块。\n"
         @"    *   `IF (占事性质 == \"考试\") THEN Load MDI_Module_Library.Exam;`\n"
         @"    *   `ELSE IF (占事性质 == \"家宅\") THEN Load MDI_Module_Library.Home;`\n"
         @"    *   ... (依此类推，匹配所有《壬竅》模块)\n"
         @"*   `OUTPUT`: 一个已实例化的MDI模块对象。\n"
         @"\n"
         @"**6.2. 模块内参数重载与规则注入**\n"
         @"*   `INPUT`: 已加载的MDI模块对象。\n"
         @"*   `PROCESS`:\n"
         @"    1.  **注入原则:** 将模块`ModuleConfig.Principles`中的规则注入到全局公理中。\n"
         @"    2.  **注入方法:** 将模块`ModuleMethods.AnalysisPoints`中的“看法”列表，作为高优先级任务注入到【第二步】、【第三步】的分析流程中。\n"
         @"    3.  **更新数据模型:** 将模块`ModuleDataModel.CategorySpirits`中的“类神”字典，作为本次占断的核心符号释义库。\n"
         @"    4.  **激活事件触发器:** 将模块`ModuleEventTriggers.SpecialFlags`中的“诸煞”列表，设置为【第三步】神煞详查时的高亮监控目标。\n"
         @"\n"
         @"**6.3. 模块库声明**\n"
         @"// 架构师注：以下所有《壬竅》模块均已按MDI标准接口预编译并储存于系统库中，可根据占问类型随时调用。\n"
         @"\n"
         @"`const MDI_Module_Library = {`\n"
         @"\n"
         @"  // 卷一：阴晴占\n"
         @"  `Weather: {`\n"
         @"    `ModuleID: \"MDI_Module_Weather\",`\n"
         @"    `ModuleConfig: { Principles: [\"规则重载：禁用年命，七处定义为‘岁、月、建、日、辰、时、用’。\", \"核心二元论：阳为晴，阴为雨。蛇雀火神为晴之象，龙虎水神为雨之象。\", \"格局特定效应：伏吟主天气不变，返吟主天气变易。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看元武乘神(苦雨神)\", \"看亥上遁干(亥即武)\", \"看天盘壬癸子\", \"看青龙乘神(甘雨神)\", \"看天后乘神(雨母)\", \"看金局(水之母)\", \"占明日雨看明日干支上\", \"占晴看雨神空绝日\", \"占雷看甲卯乙及六合\", \"占风看巳午(雀)及未寅卯(虎)\", \"占风来方看虎地盘\", \"占雪看特定组合(阴龙后元蛇虎等)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"子\": \"阴，云，月\", \"丑\": \"雨师\", \"寅\": \"风伯\", \"卯\": \"雷\", \"辰\": \"水库，雾\", \"巳\": \"风门，晴神\", \"午\": \"电母，晴神\", \"未\": \"风伯\", \"申\": \"雪，水母\", \"酉\": \"霜\", \"戌\": \"雾\", \"亥\": \"水神\", \"贵人\": \"时雨\", \"螣蛇\": \"电，晴\", \"朱雀\": \"霹雳，晴\", \"六合\": \"雷，雨师\", \"勾陈\": \"云，雾\", \"青龙\": \"甘雨神\", \"天空\": \"晴，尘雾\", \"白虎\": \"霜雪，风雷\", \"太常\": \"和风甘雨\", \"玄武\": \"苦雨神\", \"太阴\": \"霜雪，风雷\", \"天后\": \"水神，阴雨\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"风伯\": \"正起申逆十二\", \"风煞\": \"正起寅逆十二\", \"雨师\": \"日支逆五位\", \"雨煞\": \"正起子顺十二\", \"雷公\": \"正起寅亥申巳\", \"电煞\": \"正起巳顺十二\", \"晴朗\": \"日支冲位\", \"旬丁\": \"变化最速\", \"飞符\": \"变化最速\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷二：国运占\n"
         @"  `Nation: {`\n"
         @"    `ModuleID: \"MDI_Module_Nation\",`\n"
         @"    `ModuleConfig: { Principles: [\"最高权重：太岁为天、为君，其状态为第一优先级。\", \"贵人模式：贵人顺行主布德(吉)，逆行主施刑(凶)。\", \"君臣民定位：太岁为君，月建为臣，占时为民。干为天位/君，支为社稷/民。\", \"内外之别：干为外事，支为内事。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看太岁(君)\", \"看岁阴(后宫)\", \"看月建上神(臣)\", \"看日干及上神(天位)\", \"看干阴(君之辅助)\", \"看日支及上神(社稷/民)\", \"看支阴(宗庙)\", \"看占时(民情)\", \"看贵人顺逆(刑德)\", \"看太阳(月将/君象)\", \"看分野\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"太岁\": \"天，君，王宫\", \"月建\": \"臣，公侯卿相\", \"月将\": \"远臣，君象\", \"日干\": \"天位，君\", \"干阴\": \"后\", \"支\": \"社稷，民，臣\", \"支阴\": \"宗庙陵寝\", \"占时\": \"民\", \"贵人\": \"君象\", \"岁阴\": \"后宫\", \"太阴\": \"妃嫔\", \"天后/神后/月宿\": \"后\", \"青龙\": \"文臣\", \"太常\": \"武职\", \"朱雀\": \"翰苑文士\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"岁宅\": \"岁前五位\", \"岁破\": \"太岁对冲\", \"岁墓\": \"岁前八位\", \"病符\": \"旧太岁\", \"死神/死炁\": \"凶兆\", \"岁刑/岁煞\": \"刑罚\", \"游都/火烛煞\": \"灾祸\", \"五马/天马\": \"巡行/经营\", \"月厌/天鬼\": \"阻碍/灾异\", \"皇恩/天赦/解神\": \"赦免/解救\", \"大煞/金神\": \"杀伐\" } }`\n"
         @"  `},`\n"
         @"    \n"
         @"  // 卷三：家宅占\n"
         @"  `Home: {`\n"
         @"    `ModuleID: \"MDI_Module_Home\",`\n"
         @"    `ModuleConfig: { Principles: [\"干支为本：以日干(人)和日支(宅)自身的生旺为首要判断依据。\", \"内外交互：支加干为宅就人(迁入吉)，干加支为人恋宅(迁出难)。\", \"四位占法优先：宅之高低、新旧、吉凶多从四位占法入手，以旺爻为事应。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"互看干支两课\", \"日上为旧宅，辰上为新宅\", \"看干及干阳干阴(人丁)\", \"看支及支阳支阴(宅基)\", \"看支上神将组合(龙虎拱支/虎克支等)\", \"看四课\", \"看三传\", \"看宅音\", \"看监将\", \"看井灶厕水道\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"Family\": {\"父母\":\"生气/德神/天后\", \"妻\":\"天后/财爻\", \"兄弟\":\"太阴/兄弟爻\", \"子孙\":\"六合/子孙爻\"}, \"HouseParts\": {\"子\":\"房/渠\", \"丑\":\"园/库\", \"寅\":\"桥/梁栋\", \"卯\":\"门/窗\", \"辰\":\"墙/寺\", \"巳\":\"灶/院\", \"午\":\"堂/路\", \"未\":\"井/墙\", \"申\":\"道/城\", \"酉\":\"户/塔\", \"戌\":\"墙/寺\", \"亥\":\"厕/楼台\"}, \"InteriorItems\": {\"子\":\"水器/首饰\", \"丑\":\"柜/冠带\", \"寅\":\"木器/文书\", \"卯\":\"床/竹器\", ...} } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天月日支岁德\": \"吉\", \"天驿马\": \"动迁\", \"喜神/生气\": \"喜庆/人丁\", \"三煞/破碎\": \"破败\", \"死炁/死神\": \"凶灾\", \"血忌/血支\": \"血光之灾\", \"火鬼/天鬼\": \"火灾/鬼祟\", \"羊刃\": \"伤灾\", \"月厌\": \"不顺\", \"病符/丧门/吊客\": \"疾病/丧事\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷四：鬼祟占 (附占)\n"
         @"  `Spirit: {`\n"
         @"    `ModuleID: \"MDI_Module_Spirit\",`\n"
         @"    `ModuleConfig: { Principles: [\"以日鬼、天鬼、天目加辰为核心判断依据。\", \"以天罡所临定方位，十干定具体位置。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"察鬼之有无(日鬼/天鬼/天目加辰，传用月厌值符)\", \"定鬼之方位(天罡所临)\", \"辨鬼之男女(白虎乘阴阳)\", \"辨鬼之数量(官鬼/白虎/小吉/魁罡)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"日鬼/天鬼/天目\": \"鬼祟核心类神\", \"白虎\": \"鬼之形态\", \"魁罡/小吉\": \"鬼之数量\", \"阳神克\": \"神\", \"阴神克\": \"鬼\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天目\": \"地有伏尸\", \"四时冲破\": \"有鬼之兆\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷五：坟墓占\n"
         @"  `Tomb: {`\n"
         @"    `ModuleID: \"MDI_Module_Tomb\",`\n"
         @"    `ModuleConfig: { Principles: [\"阴阳宅有别：阳宅重支阳，阴宅重支阴。\", \"生亡人有别：未葬以生人为主，已葬以亡人为主。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看日干两课兼亡人年命(占生前殁后)\", \"看支阳支阴(分生坟死坟)\", \"看干支课占风气盘结\", \"看支阳为主山\", \"看支阳对冲/朱雀为案山\", \"看支阴为穴\", \"看墓音占形势\", \"看内景决所葬何人/有何物\", \"看墓干占外景\", \"看青龙为来龙\", \"看螣蛇为罗城/穴\", \"看元武为水法\", \"看阴后为水口\", \"看何房吉凶\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"日阴\": \"亡人\", \"支阳\": \"墓/生坟/主山\", \"支阴\": \"穴/死坟\", \"朱雀/支阳对冲\": \"案山\", \"青龙\": \"来龙\", \"螣蛇\": \"罗城/穴\", \"元武\": \"水法\", \"太阴/天后\": \"水口\", \"勾陈/午\": \"明堂\", \"白虎\": \"墓道/石器\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"龙神\": \"来龙\", \"丁神/破碎/飞廉\": \"凶兆\", \"死神/死炁\": \"亡故\", \"丧门/吊客\": \"丧事\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷六：出行占\n"
         @"  `Travel: {`\n"
         @"    `ModuleID: \"MDI_Module_Travel\",`\n"
         @"    `ModuleConfig: { Principles: [\"末传为要，为归结处；吉凶应于支上。\", \"罗网及旺禄临身，不利出行。\", \"贵立天门、德入天门，出行吉利。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看日干干上(己身/本处)\", \"看日支支上(家宅/去处)\", \"看马及阻隔神\", \"合看魁罡丁马动神\", \"看三传(进退行止)\", \"看发用(发轫之始)\", \"看白虎(道路神)\", \"看水陆舟车\", \"看死绝神\", \"看所往方宜忌\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"干\": \"己身/本处/陆路\", \"支\": \"家宅/去处/水路\", \"三传\": \"初为本处/中为半路/末为去处\", \"马\": \"行程\", \"卯\": \"舟车\", \"午\": \"马\", \"太常\": \"行李\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天车/天坑/天地转煞\": \"行路凶险\", \"往亡/飞符/六辛\": \"忌行方位\", \"德神\": \"吉\", \"刦煞/游都\": \"盗贼\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷七：行人占\n"
         @"  `MissingPerson: {`\n"
         @"    `ModuleID: \"MDI_Module_MissingPerson\",`\n"
         @"    `ModuleConfig: { Principles: [\"吉凶重年命，不重类神。\", \"天驿马及年命入课传为归期之核心。\", \"干为行客，支为宅，比和则归兴浓，刑冲则仍为客。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看干支关系\", \"看三传(进退)\", \"看发用\", \"看末传为行人足\", \"合看日与行年\", \"看年命临支辰否\", \"看飞伏(鬼为飞/财为伏)\", \"看限至\", \"看马\", \"看魁罡二马\", \"断归期法\", \"看伏吟/返吟\", \"看元武临四季\", \"看天乙与正时\", \"看游神戏神\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"干\": \"行客/陆路\", \"支\": \"宅/旅次/水路\", \"三传\": \"初来处/中半路/末到处\", \"白虎\": \"催程\", \"亥\": \"天头\", \"巳\": \"地足\", \"寅/申\": \"迁移神\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"元武/丁神/白虎/正时/天乙/天罡/游神/戏神\": \"行人动态核心指标\", \"大将军/岁支/月建\": \"用于断归期\", \"信神/天鸡/朱雀\": \"信息\" } }`\n"
         @"  `},`\n"
         @"  \n"
         @"  // 卷八：逃亡占\n"
         @"  `Fugitive: {`\n"
         @"    `ModuleID: \"MDI_Module_Fugitive\",`\n"
         @"    `ModuleConfig: { Principles: [\"核心算法：先看德刑克贼，德克刑易获；无克贼，再看玄武三传。\", \"人我定位：类神/德刑/玄武为逃人，日干/年命为捕捉人。\", \"子孙为用：子孙爻为克制之神，代表追捕力量。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"先看德刑克贼\", \"次看玄武三传\", \"看三传墓\", \"看克玄武之法\", \"看日干为追捕人\", \"看日支为逃失处\", \"看逃亡远近\", \"看闭口课\", \"看阻隔神\", \"占地理法(定藏匿处环境)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"日德\": \"君子藏处\", \"支刑\": \"小人藏处\", \"玄武\": \"核心逃亡类神\", \"子孙爻\": \"追捕力量\", \"勾陈\": \"捕捉人\", \"人类神歌\": {\"子\":\"王侯/媒\", \"丑\":\"贤士/僧尼\", ...} } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"死炁\": \"凶兆\", \"二马/丁神\": \"远遁\", \"天目/亡神\": \"大贼/惯犯\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷九：考试占\n"
         @"  `Exam: {`\n"
         @"    `ModuleID: \"MDI_Module_Exam\",`\n"
         @"    `ModuleConfig: { Principles: [\"士人进取，以文书为先。雀、长生、印绶、龙常官贵禄马德合等吉神，权重提升。\", \"忌天空发用、武乘神克日、虎乘神伤日，此类格局直接标记为高风险。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"先看朱雀为文书\", \"参看青龙午火印绶为文字\", \"看主试类(按考试级别)\", \"看日干年命之官鬼为功名类神\", \"看幕贵\", \"总看干支吉格\", \"看三传为功名迟早高低\", \"看名次甲乙(十干)\", \"看魁罡/从魁\", \"看德入天门\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"朱雀\": \"核心文书类神\", \"官鬼爻\": \"核心功名类神\", \"长生/印绶\": \"学识根基\", \"幕贵\": \"乡会试主试官\", \"月将\": \"院试主试官\", \"月建\": \"府试主试官\", \"父母爻\": \"县试主试官\", \"日干\": \"考生\", \"日支\": \"考场/文题\", \"魁罡/从魁\": \"魁星\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"皇恩/天喜/成神\": \"高中吉兆\", \"五马\": \"高中后迅速升迁\", \"死炁/病符/月厌\": \"考试阻碍\", \"刦煞/灾煞\": \"意外之灾\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十：官禄占\n"
         @"  `Career: {`\n"
         @"    `ModuleID: \"MDI_Module_Career\",`\n"
         @"    `ModuleConfig: { Principles: [\"状态区分：未官要见官星，已官不必见。\", \"干为己身，支为任所。干支临官帝旺最吉。\", \"君臣定位：太岁为朝廷，月建月将为台省，贵人为具体权柄。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"合看干支及上神\", \"看干为己身\", \"看支为任所\", \"看三传(迟速高低)\", \"总看太岁贵人与日辰年命\", \"看龙常(文武职)\", \"看官星\", \"看禄马德神\", \"看催官(虎鬼)\", \"看印绶(河魁太常)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"太岁\": \"天子/朝廷\", \"月建/月将\": \"台省/上司\", \"贵人\": \"权柄/恩主\", \"青龙\": \"文臣\", \"太常\": \"武臣/印绶\", \"官鬼爻\": \"官职\", \"日干\": \"为官者本人\", \"日支\": \"任所/官位\", \"禄神\": \"俸禄\", \"驿马\": \"迁转/差遣\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"皇恩/皇书/天诏\": \"敕命/恩典\", \"天印/圣心\": \"得印/上意\", \"二马/丁神\": \"迁动\", \"死神/丧门/吊客\": \"去职/丁忧\", \"子孙爻\": \"伤官/剥官之神\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十一：疾病占\n"
         @"  `Sickness: {`\n"
         @"    `ModuleID: \"MDI_Module_Sickness\",`\n"
         @"    `ModuleConfig: { Principles: [\"虎鬼核心：以白虎和官鬼爻为核心病症类神。虎鬼俱无而见死墓绝空，反为无药可医之凶象。\", \"生克病理：克我者为病源，我受克处为症候。\", \"子孙为药：子孙爻为制鬼之神，代表医药与疗效。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看七处虎鬼为病症\", \"看虎鬼地盘(病之根源)\", \"看虎鬼天盘阴神(病情变化)\", \"看日干为病体(表症/腑)\", \"看日支为病处(里症/脏)\", \"看三传分症之内外表里\", \"看发用五行所主病\", \"看墓/空/生炁/死炁/病符/禄神等状态\", \"求医诸看法(天医/地医/子孙)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"白虎\": \"病神，主凶险重症\", \"官鬼爻\": \"病源\", \"子孙爻\": \"医药，医生\", \"日干\": \"病人身体\", \"日支\": \"病床/病位\", \"太常\": \"医药/孝服\", \"天医/地医\": \"良医方位\", \"脏腑\": {\"甲\":\"胆\", \"乙\":\"肝\", ...} } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"死神/死炁/病符\": \"病情加重\", \"生炁\": \"生机\", \"丧门/吊客\": \"凶兆/丧事\", \"血支/血忌\": \"血症\", \"羊刃\": \"手术/血光\", \"天医/解神\": \"得愈之兆\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十二：孕产占\n"
         @"  `Pregnancy: {`\n"
         @"    `ModuleID: \"MDI_Module_Pregnancy\",`\n"
         @"    `ModuleConfig: { Principles: [\"孕产有别：占孕宜合而安和，占产宜冲而产速。\", \"子母定位：干为子，支为母；亦或六合为子，天后为母。\", \"胎神为本：以胎神(长生十二宫之胎)为核心类神，其状态定吉凶。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"占孕之有无(看子孙爻等)\", \"重看胎神藏现\", \"看干为子支为母\", \"看六合为子天后为母\", \"总看三传决孕产迟速\", \"定受胎期\", \"看产期(胜光所临/冲胎之日)\", \"看男女诸法(阴阳/罡加/昴星等)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"胎神\": \"核心胎儿类神\", \"生气\": \"孕育之气\", \"日干/六合\": \"子\", \"日支/天后\": \"母\", \"螣蛇\": \"小儿\", \"丑\": \"腹\", \"子孙爻\": \"子嗣\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天喜/喜神\": \"孕产吉兆\", \"丁/马/血支/血忌/浴盆\": \"产兆\", \"死神/死炁/丧门/吊客\": \"凶兆\", \"孤辰/寡宿\": \"子嗣艰难\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十三：词讼占\n"
         @"  `Lawsuit: {`\n"
         @"    `ModuleID: \"MDI_Module_Lawsuit\",`\n"
         @"    `ModuleConfig: { Principles: [\"三神分工：勾陈为词讼本身，朱雀为文词状纸，贵人为勘官。\", \"原被定位：干为原告/尊，支为被告/卑。发用克贼定主动方。\", \"子孙父母为救：子孙制鬼(对头)，父母化官(官司)，为解救之道。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"先看勾陈为类神\", \"次看朱雀为词状\", \"看贵人为勘官\", \"分看官鬼二字\", \"看子孙制官鬼/父母化官鬼\", \"分看干为原告支为被告\", \"看三传(始终胜负)\", \"看刑责\", \"看囚禁\", \"看结案及和解\", \"看决罪\", \"看赦\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"勾陈\": \"词讼主神\", \"朱雀\": \"词状/拘票\", \"贵人\": \"审判官\", \"官鬼爻\": \"官司/对头\", \"日干\": \"原告\", \"日支\": \"被告\", \"六合\": \"和解神/枷锁\", \"青龙\": \"棒杖\", \"天空\": \"狱卒\", \"辰/戌\": \"监狱\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天赦/皇恩/解神/天后\": \"赦免/和解\", \"天狱/天牢\": \"囚禁\", \"羊刃/大煞\": \"刑伤\", \"破碎/绞神\": \"罪责加重\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十四：干谒占\n"
         @"  `Visit: {`\n"
         @"    `ModuleID: \"MDI_Module_Visit\",`\n"
         @"    `ModuleConfig: { Principles: [\"人我定位：干为我，支为彼。相生合则情投，相刑克则意左。\", \"类神为要：谒贵视天乙，谒文视朱雀等，以所谒之事类为核心。\", \"动静之机：类乘丁马或支上见丁马，主其人欲动，难见。伏吟无动神，主藏匿不见。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"总看干支三传\", \"不知其人看日德\", \"知其人看支为彼\", \"看类神临处为所在\", \"看魁罡丁马等动神\", \"干贵看贵人\", \"看所干之事成期散期\", \"看馈物受否\", \"看投书达否\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"日干\": \"我\", \"日支\": \"彼\", \"日德\": \"贤良君子\", \"贵人\": \"所谒之贵人\", \"朱雀\": \"所投之文书\", \"类神\": \"所谒之具体对象\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"马/丁/魁罡\": \"动神，主对方不在或移动\", \"三合/六合\": \"得见之兆\", \"往亡\": \"忌行方位\", \"闭口课\": \"对方机心深/事机密\" } }`\n"
         @"  `},`\n"
         @"\n"
         @"  // 卷十五：年命占\n"
         @"  `Destiny: {`\n"
         @"    `ModuleID: \"MDI_Module_Destiny\",`\n"
         @"    `ModuleConfig: { Principles: [\"四位一体：日辰为身宅之应(实)，年命为根本(虚)，四者相为表里，互为救助与损伤。\", \"年近命远：行年主管一年之近事，本命关乎一生之远局。\", \"六亲模型：以十神关系（正偏印、财、官、伤食、比劫）构建六亲推断模型。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"总看日辰年命相为表里\", \"看年命为类神(执行太岁游宫法)\", \"看日为身辰为宅\", \"看三传及早中晚年\", \"看发用(关一生之运)\", \"看岁月建将时贵人\", \"看父母(印)\", \"看兄弟(比劫)\", \"看财(妻)\", \"看官(夫)\", \"看子孙(伤食)\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"日干\": \"身(实)\", \"日支\": \"宅(实)\", \"行年\": \"年运(虚/近)\", \"本命\": \"命运(虚/远)\", \"印绶\": \"父母\", \"比劫\": \"兄弟\", \"财爻\": \"妻财\", \"官鬼爻\": \"官禄/夫\", \"子孙爻\": \"子嗣\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"岁煞十二神\": \"年内吉凶\", \"羊刃/飞刃\": \"凶灾\", \"德/禄/马\": \"吉庆/动变\", \"长生\": \"寿元\", \"死/墓/绝\": \"衰败/终结\" } }`\n"
         @"  `},`\n"
         @"  \n"
         @"  // 卷十六：来意占\n"
         @"  `Intent: {`\n"
         @"    `ModuleID: \"MDI_Module_Intent\",`\n"
         @"    `ModuleConfig: { Principles: [\"三元定位：日主外，辰主内，时主事，为快速判断之总纲。\", \"正时为先：以正时为类，其与日辰的生克冲合刑害关系为判断来意之首要入口。\", \"发用为本：虽有八门，但初传(发用)为事之主动神，为最终定性之核心。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"看正时为类与日辰相较\", \"看正时兼发用\", \"看日辰(内外事)\", \"看三传兼看天地人\", \"看七处十二支组合(寅亥主病，寅辰主讼等)\", \"看十二时来意吉凶大略\", \"看六情\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"正时\": \"来事之核心类神\", \"日干\": \"外事/来人\", \"日支\": \"内事/家宅\", \"发用\": \"事之发端与性质\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"生炁/死炁/刦煞/禄/德/丁/马/游神\": \"附加情景指示\" } }`\n"
         @"  `},`\n"
         @"    \n"
         @"  // 卷十七：射覆占\n"
         @"  `DivinationGame: {`\n"
         @"    `ModuleID: \"MDI_Module_DivinationGame\",`\n"
         @"    `ModuleConfig: { Principles: [\"日辰发用为体：以日辰及发用为核心判断基点，不重中末传。\", \"旺多者胜：从旺神或数量多者言之。\", \"五行物化：以五行、十二支、十二神将、长生十二宫、五气等象征体系，全方位描述物体属性。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"论阴阳\", \"辨五行(物形/味/色/数)\", \"论长生十二位(新旧)\", \"论旺相休囚死五炁(状态)\", \"看孟仲季(形态)\", \"占死活\", \"占可食不可食\", \"占有无/虚实\", \"占完缺/多少\", \"占水陆所出\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"十二支物形\": {\"子午\":\"偏斜有孔\", \"卯酉\":\"团栾口伤\", ...}, \"十二支器物\": {\"子\":\"炭墨水器\", \"丑\":\"柜带珍宝\", ...}, \"十二天官物类\": {\"天乙\":\"贵物文章\", \"螣蛇\":\"弯长之物\", ...} } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"天空/旬空\": \"无物/虚物\", \"伏吟\": \"近物/隐藏\", \"返吟\": \"远物/往来\" } }`\n"
         @"  `},`\n"
         @"  \n"
         @"  // 卷十八：怪异占\n"
         @"  `Anomaly: {`\n"
         @"    `ModuleID: \"MDI_Module_Anomaly\",`\n"
         @"    `ModuleConfig: { Principles: [\"蛇为真怪：四课中见螣蛇为真怪异，无则非怪。\", \"年命为凭：年命上神将吉，虽怪无害；神将凶，怪咎乃成。\", \"神后辨怪：以神后(子)所加之辰，或蛇之阴神，辨别怪物之性质。\"] },`\n"
         @"    `ModuleMethods: { AnalysisPoints: [\"占落星\", \"占雷震\", \"占暴风\", \"占心动\", \"占什物自动\", \"占井溢\", \"占釜鸣\", \"占犬吠\", \"占牝鸡鸣\", \"占鸟怪鸣\"] },`\n"
         @"    `ModuleDataModel: { CategorySpirits: { \"螣蛇\": \"怪异核心类神\", \"太乙(巳)\": \"怪\", \"神后(子)\": \"辨怪之神\", \"未\": \"鬼宿\", \"子\": \"鬼门\" } },`\n"
         @"    `ModuleEventTriggers: { SpecialFlags: { \"月厌\": \"怪异之兆\", \"大煞\": \"凶怪\", \"直符\": \"怪异为真\" } }`\n"
         @"  `}`\n"
         @"\n"
         @"------\n"
         @"## Part III: 根本知识中枢 · 双层法典\n"
         @"*   `协议定位`: 此为本系统的**唯一、权威的知识源泉**。它由【**第一层：应用法典**】和【**第二层：元理论法典**】构成，共同为 `Part II` 的分析流程提供从具体象意到抽象原理的全方位支持。\n"
         @"---\n"
         @"### **第一层：应用法典 · 经典判例与释义**\n"
         @"#### `协议定位`: 此层为高频使用的、经过验证的【**经典知识库**】。它为系统提供了所有核心符号（神将、课体、关系）的权威释义与象意素材。\n"
         @"---\n"
         @"### **Chapter 2: 双轨融合天将法典**\n"
         @"#### **【执行协议】**\n"
         @"*   **双轨并行**: 在解读任何天将时，**必须同时调用【A轨：活断性情】和【B轨：古典详注】**。\n"
         @"*   **权重原则**: 【A轨】用于**定性**（把握其核心动机和行为模式），【B轨】用于**取象**（提取具体的、情境化的现实画面）。\n"
         @"*   **临宫优先**: 在【B轨】中，【临宫状态】的优先级高于【核心象意】，因为它提供了更具体、更动态的情境信息。\n"
         @"---\n"
         @"#### **【融合分子#C-01: 天乙贵人 (己丑土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**志同道合的、更高层次的引导者**。\n"
         @"    *   **动机**: 真心帮助你，通过**规范你的行为**，让你走在“正轨”上。\n"
         @"    *   **职能**: **审察与判决**。代表一切维持秩序、评判优劣的权威角色。\n"
         @"    *   **直断映射**: 考官、领导、上级、规则制定者。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 谒见干求、官职禄秩、公庭、天神、尊长。\n"
         @"    *   **核心断语**: “天乙贵人名魁钺...君子拜官迁禄秩，小人争讼入公庭。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临子`: 沐浴 (**直断**: 贵人有私心，或此事不纯粹，难成)。\n"
         @"        *   `临丑`: 升堂 (**直断**: 贵人在位，得地有力，大吉)。\n"
         @"        *   `临寅`: 按籍 (**直断**: 涉及官方程序、公门之事)。\n"
         @"        *   `临卯`: 荷枷 (**直断**: 贵人自身受缚，或求贵反遭束缚)。\n"
         @"        *   `临辰`: 入狱 (**直断**: 求贵必受辱，或贵人身陷囹圄)。\n"
         @"        *   `临巳`: 趋朝 (**直断**: 有晋升、面见更高层级的希望)。\n"
         @"        *   `临午`: 御轩 (**直断**: 有官方的任命或好消息传来)。\n"
         @"        *   `临未`: 饮食 (**直断**: 能得到一些实际的小恩惠、好处或宴请)。\n"
         @"        *   `临申`: 起途 (**直断**: 贵人将要行动，或此事将有进展、变动)。\n"
         @"        *   `临酉`: 入室 (**直断**: 事情转入私下、暗中操作，不明朗)。\n"
         @"        *   `临戌`: 在囚 (**直断**: 贵人被困，或所求之事陷入僵局)。\n"
         @"        *   `临亥`: 操笏 (**直断**: 利于求见上级，汇报工作)。\n"
         @"---\n"
         @"#### **【融合分子#C-02: 螣蛇 (丁巳火)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**精神不正、爱看热闹的麻烦制造者**。\n"
         @"    *   **动机**: 享受旁观他人“愤怒、恐惧却又无能为力”的窘境。\n"
         @"    *   **职能**: 触发**认知以外的恶性事件**，让人陷入“惊、慌、恐、怖”的心理状态。\n"
         @"    *   **直断映射**: 神经病、行为怪异的人、无法理解的突发状况、缠绕不休的麻烦。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 惊恐怪异、虚惊、梦寐、火光、文字、官私是非、缠绕、绑缚。\n"
         @"    *   **核心断语**: “...火神惊恐亦非安。君子忧官忧失位，小人争斗恐伤魂。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临子/亥`: 堕水/入水 (**直断**: 惊恐无力，虚惊一场，不成灾害)。\n"
         @"        *   `临丑/未/戌`: 入穴/秘隐/睡眠 (**直断**: 麻烦自行消散或暂时平息)。\n"
         @"        *   `临寅`: 生角 (**直断**: 事情正在变异，吉凶看旺衰)。\n"
         @"        *   `临卯`: 当门 (**直断**: 麻烦找上门，易有口舌或人身伤害)。\n"
         @"        *   `临辰`: 自蟠 (**直断**: 麻烦盘踞不动，可远观不可近玩)。\n"
         @"        *   `临巳`: 飞天 (**直断**: 怪异之事显现，能量最强，若为吉事则大利)。\n"
         @"        *   `临午`: 乘雾 (**直断**: 想搞事，但前景不明)。\n"
         @"        *   `临申`: 衔刀/拔剑 (**直断**: 必有凶险的官非或冲突)。\n"
         @"        *   `临酉`: 露齿 (**直断**: 必有口舌争吵)。\n"
         @"---\n"
         @"#### **【融合分子#C-03: 朱雀 (丙午火)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**信息公开化的催化剂**。\n"
         @"    *   **动机**: 让隐藏的事实浮出水面，让不透明的状况变得清晰。\n"
         @"    *   **职能**: **官宣**。无论是白纸黑字的文书，还是对簿公堂的官司，都是将信息公开化的过程。\n"
         @"    *   **直断映射**: 文书、合同、官司、出名、信息、消息、媒体。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 文书印信、敕命、口舌公讼、信息、火灾、飞鸟、通讯。\n"
         @"    *   **核心断语**: “...霹雳灾殃是火神。君子文书忧考校，小人财帛竞纷纭。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临午`: 衔符 (**直断**: 文书、口舌之事必然发生)。\n"
         @"        *   `临申`: 励嘴 (**直断**: 正在准备打官司或激烈的辩论)。\n"
         @"        *   `临未`: 啄食 (**直断**: 通过文书、信息求财有利)。\n"
         @"        *   `临子/亥`: 损翼/沐浴 (**直断**: 信息受阻、失真，或灾忧自行消退)。\n"
         @"        *   `临丑/戌`: 掩目/无毛 (**直断**: 信息被困，渠道不通)。\n"
         @"        *   `临巳`: 翱翔 (**直断**: 信息远播，利于外部事务)。\n"
         @"        *   `临寅/卯`: 安巢/栖林 (**直断**: 信息安稳，或因信息之事而暂缓行动)。\n"
         @"---\n"
         @"#### **【融合分子#C-04: 六合 (乙卯木)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**社交活动家和交易撮合者**。\n"
         @"    *   **动机**: 喜欢把人“呼唤”到一起，促进信息和利益的交换。\n"
         @"    *   **职能**: **中介与沟通**。主呼唤、婚姻说合、市场交易。\n"
         @"    *   **直断映射**: 中间人、媒婆、合作、谈判、聚会、信息交流。\n"
         @"    *   **关键修正**: 凶时（尤其卯木克土），可直断**被官方传唤、讯问**。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 婚姻和合、信息、交易、媒人、子孙、阴私、私门、儿童。\n"
         @"    *   **核心断语**: “...婚姻和合吉相扶。君子得财迁禄位，小人亲会酒欢娱。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临寅`: 乘轩 (**直断**: 有婚姻喜庆之事)。\n"
         @"        *   `临卯`: 入户 (**直断**: 内部合作，或在家不动)。\n"
         @"        *   `临亥`: 乘辂 (**直断**: 利于出行办事、促成合作)。\n"
         @"        *   `临丑`: 眼疾 (**直断**: 合作有瑕疵、有问题)。\n"
         @"        *   `临未`: 素服 (**直断**: 合作之事带有忧愁、不顺)。\n"
         @"        *   `临申`: 披发 (**直断**: 合作可成，但过程可能有些波折)。\n"
         @"---\n"
         @"#### **【融合分子#C-05: 勾陈 (戊辰土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**严于律人、宽于律己的“双标”执法者**。\n"
         @"    *   **动机**: 感觉人人都亏欠他，一旦抓住别人的“小辫子”或得到一点好处，便会纠缠不放，不断加码索取，最终引发冲突。\n"
         @"    *   **职能**: **强制执行与迟滞**。代表警察、执法。其核心特质是“纠缠”，因此当勾陈出现时，事情必然会被拖延、迟滞。\n"
         @"    *   **直断映射**: 警察、官司、做好事反被讹上、事情拖延、顽固的对手。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 争讼、田宅、官职、印信、牵连、迟滞、捕盗、兵卒。\n"
         @"    *   **核心断语**: “...兵灾刑斗讼留连。君子掩捕擒盗贼，小人争妇及田园。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临辰`: 千户 (**直断**: 官司、田产之事随之而动，纠缠不休)。\n"
         @"        *   `临戌`: 佩剑 (**直断**: 必有武力争端或伤害事件)。\n"
         @"        *   `临午`: 反目 (**直断**: 事情乖张，必有争斗)。\n"
         @"        *   `临子`: 临庭 (**直断**: 官司临门)。\n"
         @"        *   `临卯`: 入狱 (**直断**: 官非或田宅之事受困)。\n"
         @"        *   `临寅`: 受制 (**直断**: 官方力量被压制，事情暂缓)。\n"
         @"        *   `临巳`: 捧印 (**直断**: 有职位变动、晋升之象)。\n"
         @"        *   `临酉`: 病足 (**直断**: 行动受阻，事情停滞)。\n"
         @"        *   `临亥`: 濯衣 (**直断**: 事情有改革、变动之机)。\n"
         @"---\n"
         @"#### **【融合分子#C-06: 青龙 (甲寅木)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**胸怀大志、追求卓越的“大格局”玩家**。\n"
         @"    *   **动机**: 要么不做，要做就做大的。不满足于小打小闹，一心想经营大事、赚取超额回报。\n"
         @"    *   **职能**: **增福与驱动**。是赐予“超出预期”的财喜吉庆之神，也是驱使人挑战更大目标的内在动力。\n"
         @"    *   **直断映射**: 大笔钱财、重大喜事、高级别的合作、雄心壮志。入课即提示需关注财运的宏观走向。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 财帛、酒食、婚礼、官职、喜庆、文书、僧道、高人。\n"
         @"    *   **核心断语**: “...酒食钱财婚礼仪。君子加官迁美职，常人财物送乡耆。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临寅`: 乘云 (**直断**: 得势亨通，财官两利)。\n"
         @"        *   `临巳`: 飞天 (**直断**: 大利行动，财运高涨，格局打开)。\n"
         @"        *   `临卯`: 戏珠 (**直断**: 喜庆之事，必得财物)。\n"
         @"        *   `临亥`: 入水 (**直断**: 求财可得，资源落地)。\n"
         @"        *   `临丑`: 蟠泥 (**直断**: 财物受困，资金链迟滞)。\n"
         @"        *   `临申`: 无鳞 (**直断**: 财力受损，久困之象)。\n"
         @"        *   `临午`: 无尾 (**直断**: 事情有始无终，财物损伤)。\n"
         @"        *   `临未`: 折角 (**直断**: 因争斗而损财)。\n"
         @"        *   `临子`: 游海 (**直断**: 财物远行，不稳定，资金外流)。\n"
         @"        *   `临酉`: 伏陆 (**直断**: 退守之象，财不动，投资保守)。\n"
         @"        *   `临戌`: 施雨 (**直断**: 主动花费、投资或出财)。\n"
         @"---\n"
         @"#### **【融合分子#C-07: 天空 (戊戌土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**头脑空空、绝对服从的“忠诚执行者”**。\n"
         @"    *   **动机**: 自身没有欲望和想法，唯一的目标就是执行天乙贵人的命令。\n"
         @"    *   **职能**: **契约与服从**。其核心在于代表具有“约束力”和“需要服从”的合同、文件、约定。\n"
         @"    *   **直断映射**: 合同、协议、规章制度、承诺。若非文件，则次取欺诈、谎言之象。也代表僧道等无欲之人。\n"
         @"    *   **关键修正**: 优先考虑“文件契约”，而不是“骗子”。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 奴婢、小人、欺诈、虚伪、不实、言约私契、市井。\n"
         @"    *   **核心断语**: “...奸谋诡诈事多端。君子防谗遭佞，常人孤寡被隐瞒。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临卯`: 守制 (**直断**: 虚假的言辞或承诺)。\n"
         @"        *   `临辰`: 主虚诈 (**直断**: 明显的欺骗行为)。\n"
         @"        *   `临未`: 主施空物 (**直断**: 给予了没有实际价值的东西，画大饼)。\n"
         @"        *   `临申`: 鼓舌 (**直断**: 涉及虚假的词讼或辩论)。\n"
         @"        *   `临寅`: 犯事 (**直断**: 因虚假之事引发争讼口舌)。\n"
         @"        *   `临丑`: 伏尸 (**直断**: 有隐藏的旧事或隐患，多为虚假之事)。\n"
         @"        *   `临亥`: 儒冠 (**直断**: 小事，但利于寻回遗失之物，因其空而能容)。\n"
         @"        *   `临午`: 入化 (**直断**: 小事吉，虚浮之事向好转化)。\n"
         @"---\n"
         @"#### **【融合分子#C-08: 白虎 (庚申金)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**毫无感情、只认事实的“冷面终结者”**。\n"
         @"    *   **动机**: 如实传达和执行信息，不留情面地让当事人以肉体凡胎直面最真实的后果。\n"
         @"    *   **职能**: **物理层面的执行与裁决**。首主交通、道路等物理位移；次主联系、联络；凶时主审判、拒绝、不予通过。\n"
         @"    *   **直断映射**: 道路、车辆、信息传递、拒绝、手术、西医、法律判决。\n"
         @"    *   **关键修正**: **严禁滥用“血光之灾”**。只有在克伤`甲乙卯`木或被`丙丁巳午`火克时，才优先考虑疾病、血光。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 道路信息、兵戈、威权、疾病、死丧、孝服、血光。\n"
         @"    *   **核心断语**: “...遭丧疾病狱囚萦。君子失官流血忌，常人伤杀主身倾。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临申`: 衔牒 (**直断**: 道路信息通畅，或有官方文书传来)。\n"
         @"        *   `临寅`: 出林 (**直断**: 在道路上，有动态，可能伴随伤害)。\n"
         @"        *   `临酉`: 当路 (**直断**: 构成直接威胁，有伤人之意)。\n"
         @"        *   `临巳`: 烧身 (**直断**: 主死丧、疾病等凶事)。\n"
         @"        *   `临未`: 登山 (**直断**: 获得权势，但若占官司牢狱则大凶)。\n"
         @"        *   `临子`: 流江/沉海 (**直断**: 内心恐惧，但无实质性大害)。\n"
         @"        *   `临卯`: 伏穴 (**直断**: 事情停滞不动，占病则病不起)。\n"
         @"        *   `临戌/亥`: 闭目/睡眠 (**直断**: 威胁消除或暂时无害)。\n"
         @"---\n"
         @"#### **【融合分子#C-09: 太常 (己未土)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**注重礼仪、讲究规矩的“仪式官”**。\n"
         @"    *   **动机**: 强调品级、礼教和形式上的正当性。\n"
         @"    *   **职能**: **形式上的授权与喜庆**。代表一切具有仪式感的授权、授职、授奖等事件。\n"
         @"    *   **直断映射**: 授权书、任命状、毕业证、奖状、宴会、官方仪式、考研升学相关事宜。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 文章印绶、公裳服饰、酒食宴会、田园财帛、信息。\n"
         @"    *   **核心断语**: “...财帛田园采盛明。君子正官荣爵贵，小人移徙酒逢迎。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临巳`: 铸印 (**直断**: 有转职、获得新职权之象)。\n"
         @"        *   `临申`: 捧印 (**直断**: 职位调动，官职升迁)。\n"
         @"        *   `临子`: 持印 (**直断**: 吉，手握权柄或重要文件)。\n"
         @"        *   `临酉`: 立券 (**直断**: 涉及财物、契约之事)。\n"
         @"        *   `临午`: 乘辂 (**直断**: 赴贵人之宴，或参加高级别活动)。\n"
         @"        *   `临丑/未`: 列席/窥户 (**直断**: 有宴会、酒食之事)。\n"
         @"        *   `临卯`: 遗冠 (**直断**: 有失职、丢面子之忧)。\n"
         @"        *   `临辰/戌`: 荷项/入狱 (**直断**: 受缚、被囚，行动不自由)。\n"
         @"---\n"
         @"#### **【融合分子#C-10: 玄武 (癸亥水)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**胆小社恐、好逸恶劳的“机会主义者”**。\n"
         @"    *   **动机**: 既不想付出任何劳动，又想白拿所有好处，因此行为必然是偷偷摸摸、害怕见光的。\n"
         @"    *   **职能**: **暗中行事**。代表盗窃、欺骗、奸邪等一切暗昧不明之事。\n"
         @"    *   **直断映射**: 小偷、骗子、暗中的勾当、私情、遗失物品。追债时遇到，对方必玩消失。\n"
         @"    *   **关键修正**: 只有在构成“金水相生”的特定格局下，才可论其“智慧”一面，否则一概以心术不正、胆小怕事论。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 盗贼、奸邪、走失、鬼魅、梦想、聪明多智、阴私不明。\n"
         @"    *   **核心断语**: “...盗贼奸邪狱讼陈。君子捕逃车馬失，小人私滥离乡群。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临卯`: 窥户 (**直断**: 必有盗贼或失物之事)。\n"
         @"        *   `临丑`: 立云 (**直断**: 虚假不实，易有失物)。\n"
         @"        *   `临辰`: 入狱 (**直断**: 因暗昧之事引发官司)。\n"
         @"        *   `临午`: 拔剑 (**直断**: 暗中的小人具有攻击性，能伤人)。\n"
         @"        *   `临申`: 按剑 (**直断**: 暗中有争斗，有害)。\n"
         @"        *   `临子`: 过海 (**直断**: 有暗中的行动、出行)。\n"
         @"        *   `临未`: 朝天 (**直断**: 利于暗中求见大人物)。\n"
         @"        *   `临戌`: 真冠 (**直断**: 家人中有鬼祟或阴私之事)。\n"
         @"---\n"
         @"#### **【融合分子#C-11: 太阴 (辛酉金)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**深藏不露、城府极深的“静默谋士”**。\n"
         @"    *   **动机**: 喜怒不形于色，平时看似透明，实则内心盘算清晰。在关键时刻，能一招制胜。\n"
         @"    *   **职能**: **策划不明之事**。代表一切原因不明、难以查证、不露破绽的秘密谋划或事件。\n"
         @"    *   **直断映射**: 阴谋、私下策划、灵异事件、原因不明的失物、城府深的人。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 蔽匿阴私、妇女、财帛金银、私谋、迟滞。\n"
         @"    *   **核心断语**: “...蔽匿阴私事颇仍。君子罪名为出入，小人惊诈致忧生。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临申`: 法服 (**直断**: 有阴谋或涉及婚姻的私下之事)。\n"
         @"        *   `临戌`: 绣裳 (**直断**: 涉及婚姻的私下之事)。\n"
         @"        *   `临子`: 垂帘 (**直断**: 信息隔绝，事情不通)。\n"
         @"        *   `临卯`: 沐浴 (**直断**: 有不正当的私情)。\n"
         @"        *   `临午`: 披发 (**直断**: 有私下的忧愁之事)。\n"
         @"        *   `临巳`: 伏枕 (**直断**: 内心有思虑、谋划)。\n"
         @"        *   `临辰`: 理冠 (**直断**: 正在谋求晋升或进展)。\n"
         @"        *   `临亥`: 妊娠 (**直断**: 女性有疾病或怀孕之事)。\n"
         @"---\n"
         @"#### **【融合分子#C-12: 天后 (壬子水)】**\n"
         @"*   **【A轨：活断性情】**:\n"
         @"    *   **本质**: 一个**极度在意他人看法、不惜牺牲自己来维持善良形象的“圣母”**。\n"
         @"    *   **动机**: 核心动机是**避免冲突**和**害怕别人不开心**。第一层表现为不懂拒绝，愿意吃亏；第二层（更本质）则是会去讨好潜在的强者或恶人，以求得自保。\n"
         @"    *   **职能**: **庇护与情感**。代表与占者关系亲密的女性，提供情感支持或庇护。\n"
         @"    *   **直断映射**: 母亲、妻子、关系亲密的女性长辈。\n"
         @"    *   **关键修正**: “阴私淫佚”是对此种“不懂拒绝”性格可能导致后果的论断，而非其本性。其本性更接近于一种**牺牲式的母性**。\n"
         @"*   **【B轨：古典详注】**:\n"
         @"    *   **核心象意**: 后妃、妇女、私事、帷簿不修、欺诈不实、恩泽、庇护。\n"
         @"    *   **核心断语**: “...惟须禁锢莫情循。若逢君子延宾客，如是常人议婚姻。”\n"
         @"    *   **临宫状态 (强制查询)**:\n"
         @"        *   `临卯`: 倚门 (**直断**: 有所期待、盼望)。\n"
         @"        *   `临酉`: 把镜 (**直断**: 涉及婚姻之事)。\n"
         @"        *   `临申`: 理装 (**直断**: 涉及生产或婚姻之事)。\n"
         @"        *   `临巳`: 裸体 (**直断**: 有失礼、不合规矩的行为，或私情暴露)。\n"
         @"        *   `临未`: 沐浴 (**直断**: 有不正当的私情)。\n"
         @"        *   `临辰`: 毁装 (**直断**: 有破败、血病之灾)。\n"
         @"        *   `临午`: 倚枕 (**直断**: 关系难合，心中有忧)。\n"
         @"        *   `临子`: 守闺 (**直断**: 事情停滞不动)。\n"
         @"        *   `临亥`: 治事 (**直断**: 主事，开始处理事务)。\n"
         @"---\n"
         @"### **Chapter 3: 月将象意总法典 (基因-表征-所主 融合版)**\n"
         @"*   **【司法解释】**: 本法典是系统对十二月将（天盘地支）进行取象的**唯一、最终、权威的知识源**。它由【核心基因】、【衍生表征】和【实战所主】三层构成。在进行【理气归象法】时，**必须**首先由【核心基因】把握其本质，再通过【实战所主】寻找最贴切的断语，最后以【衍生表征】补充画面细节。\n"
         @"*   `协议定位`: 此法典库负责定义【实体性质】。\n"
         @"---\n"
         @"#### **`登明 (亥)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 玄秘/艺术**】、【**终结/收藏**】、【**流动/下陷**】、【**数象: 4**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 厕所、下水道、地窖、监狱、寺庙、艺术馆、仓库、文具、墨水。\n"
         @"    *   `人物映射`: 盗贼、僧侣、乞丐、艺术家、巫师、囚犯、小孩。\n"
         @"    *   `事件映射`: 死亡、丧事、私通、玄学、艺术创作、收藏、召唤。\n"
         @"    *   `身体映射`: 肾、骨髓、腰、脚。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 无事莫追求（主静、主藏），乞索求财仔细搜（与财物有关，但需费力）。妇人芜淫性情善（与女性、阴私有关，但本性不坏）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见土克 (亥水被土克)**: 主争田地。\n"
         @"        *   **见火克 (亥水克火)**: 主阴灾、妇女疾病。\n"
         @"        *   **得木生 (木生亥水)**: 美中收（结局吉利）。\n"
         @"        *   **得金生 (金生亥水)**: 美中收（结局吉利）。\n"
         @"---\n"
         @"#### **`神后 (子)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 阴私/暧昧**】、【**智慧/流动**】、【**女性/终始**】、【**数象: 9**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 水、墨、血液、深渊、暗室、浴室。\n"
         @"    *   `人物映射`: 妇女、小儿、盗贼、隐士、聪明人。\n"
         @"    *   `事件映射`: 淫乱、盗窃、悲泣、怀孕、机密之事。\n"
         @"    *   `身体映射`: 肾、耳、泌尿系统、血液。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 奸淫失妄求（主阴私、不正当的欲望），临子随波性逐流（性格不定，易受影响）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见土克 (子水被土克)**: 主争田与畴。\n"
         @"        *   **见火克 (子水克火)**: 主妇女灾病、血光惊恐。\n"
         @"        *   **得金生/木生**: 重重吉（多重吉利）。\n"
         @"---\n"
         @"#### **`大吉 (丑)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 喜庆/贵人**】、【**束缚/终结**】、【**田土/财产**】、【**数象: 8**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 仓库、田地、房产、桥梁、锁、戒指、神庙。\n"
         @"    *   `人物映射`: 贵人、长者、将军、富人。\n"
         @"    *   `事件映射`: 喜事、诅咒、争斗、财产纠纷。\n"
         @"    *   `身体映射`: 脾、腹部、足。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 诅咒作冤仇（主是非、怨恨），直蠢之人贵贱求（代表人物性格固执，但可交往）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (丑土被木克)**: 主官灾（需详查上下关系定细节）。\n"
         @"        *   **见水克 (丑土克水)**: 主争斗之事。\n"
         @"        *   **得金生/火生**: 生合吉（得到生助或合作则吉）。\n"
         @"---\n"
         @"#### **`功曹 (寅)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 文书/官方**】、【**开始/动**】、【**才华/木器**】、【**数象: 7**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 官府、书籍、衣服、文具、香炉、树木、火。\n"
         @"    *   `人物映射`: 官员、使者、文人、道士、有才华的人。\n"
         @"    *   `事件映射`: 信息、文书事、宴请、喜庆、公事。\n"
         @"    *   `身体映射`: 胆、四肢、毛发、指甲。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 官吏簿书司（主官方、文书），贵重清高富贵奇（代表人物有品味、有地位），大树老翁医药者（具体物象）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见土克 (寅木克土)**: 主官事。\n"
         @"        *   **见金克 (寅木被金克)**: 主口舌、钱财散，文学迟（学业/晋升受阻）。\n"
         @"        *   **得水生/火生**: 喜无疑（得到生助则吉）。\n"
         @"---\n"
         @"#### **`太冲 (卯)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 门户/出行**】、【**震动/启动**】、【**私密/交易**】、【**数象: 6**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 门、床、车、船、道路、树木、棺材。\n"
         @"    *   `人物映射`: 兄弟、妻子、术士、船夫、木匠。\n"
         @"    *   `事件映射`: 出行、交易、分离、私通、盗窃、雷电。\n"
         @"    *   `身体映射`: 手指、肝、目。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 劫煞伤人物（有伤害性），门户车船并桥木（具体物象）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见土克 (卯木克土)**: 主伤财、官事毒（严重的官非）。\n"
         @"        *   **见金克 (卯木被金克)**: 主口舌、斗争。\n"
         @"        *   **得水生**: 主吉人来，无凶有福。\n"
         @"---\n"
         @"#### **`天罡 (辰)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 争斗/刚强**】、【**阻隔/网络**】、【**权威/法律**】、【**数象: 5**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 牢狱、网络、坟墓、高地、田地、皮毛。\n"
         @"    *   `人物映射`: 军人、狱吏、屠夫、对手、愚人。\n"
         @"    *   `事件映射`: 诉讼、打斗、死亡、欺诈、网络行为。\n"
         @"    *   `身体映射`: 肩膀、胸、皮肤、肌肉。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 战斗争文状（主诉讼、竞争），医药屠厨凶恶人（代表人物）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (辰土被木克)**: 主口舌、兄弟纷争，若逢寅卯，主刑罚官灾。\n"
         @"        *   **见水克 (辰土克水)**: 主争田土、斗打。\n"
         @"        *   **得金生/火生**: 为小吉。\n"
         @"---\n"
         @"#### **`太乙 (巳)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 惊怪/口舌**】、【**变化/多**】、【**光明/文章**】、【**数象: 4**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 炉灶、弓弩、砖瓦、文字、窑。\n"
         @"    *   `人物映射`: 妇人、乞丐、工匠。\n"
         @"    *   `事件映射`: 噩梦、惊恐、口舌、官司、分离、生产。\n"
         @"    *   `身体映射`: 脸面、咽喉、牙齿、肛门。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 官事凶怪动（主官非、怪事），梦寐虚惊鸟雀鸣（主精神不安），妇人轻薄淫乱事，阴私传送走西东（主女性、阴私、变动）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见金克 (巳火克金)**: **上克下主生产，下克上主口吐红（血光）**。\n"
         @"        *   **见水克 (巳火被水克)**: 主阴灾、病患沉。\n"
         @"        *   **得土生/木生**: 主文字事。\n"
         @"---\n"
         @"#### **`胜光 (午)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 光明/文书**】、【**彰显/惊恐**】、【**血光/火**】、【**数象: 9**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 眼睛、信息、文书、旌旗、灯火、战场。\n"
         @"    *   `人物映射`: 军人、信使、宫女、美女、眼科医生。\n"
         @"    *   `事件映射`: 口舌、官司、惊恐、血光、信息传递。\n"
         @"    *   `身体映射`: 心脏、眼睛、精神。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 忧惊恐，财帛文书信息临，富贵生和鞍马事（代表多种事类）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见水克 (午火被水克)**: 水在上主文书受阻，水在下主丢失公文。\n"
         @"        *   **见金克 (午火克金)**: 主屯邅病（慢性病/疑难杂症）、马亡财失、血光。\n"
         @"        *   **得土生/木生**: 喜相逢（吉利）。\n"
         @"---\n"
         @"#### **`小吉 (未)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 宴饮/喜悦**】、【**家庭/内部**】、【**医药/印绶**】、【**数象: 8**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 酒食、药品、衣物、窗帘、庭院、神堂、井。\n"
         @"    *   `人物映射`: 父母、长辈、宾客、医生、厨师、酒保。\n"
         @"    *   `事件映射`: 婚庆、宴会、医药、诉讼、祭祀。\n"
         @"    *   `身体映射`: 脾胃、腹部、口、脊梁。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 酒食来合会，婚姻妇女并交易（主喜庆、合作、女性）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (未土被木克)**: 若为寅木，主官灾，百事废。\n"
         @"        *   **见水克 (未土克水)**: 主竞田园（财产纠纷），克者无旺者是（旺者得利）。\n"
         @"        *   **得火生/金生**: 旺处喜庆逢，主五谷、钱文、阴谋得济。\n"
         @"---\n"
         @"#### **`传送 (申)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 变动/传递**】、【**道路/远行**】、【**锐利/官方**】、【**数象: 7**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 道路、驿站、车辆、传送带、刀剑、医疗器械、神佛。\n"
         @"    *   `人物映射`: 军人、使者、商贩、医生、僧侣、猎人。\n"
         @"    *   `事件映射`: 遠行、傳遞、疾病、殺伐、交易、訴訟。\n"
         @"    *   `身體映射`: 大腸、骨、脊椎、肺。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 有人奔走出（主变动、出行），道逢车辇（若遇寅卯冲）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (申金克木)**: 主口舌、凶晦之事。\n"
         @"        *   **见火克 (申金被火克)**: 主人灾、病重。\n"
         @"        *   **得水生/土生**: 主人富贵。\n"
         @"---\n"
         @"#### **`从魁 (酉)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 阴私/金融**】、【**口舌/说**】、【**小巧/精致**】、【**数象: 6**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 金银珠宝、刀币、酒器、镜子、钟表、高档消费场所。\n"
         @"    *   `人物映射`: 婢妾、少女、金融从业者、翻译、说客、妓女。\n"
         @"    *   `事件映射`: 私通、议论、饮酒、享受、金融交易。\n"
         @"    *   `身体映射`: 肺、口、精血、骨。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 妇女索离休（主女性、分离），壮力妇人多重厚（人物形象），钗钏金银酒器求（具体物象）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (酉金克木)**: 主口舌、阴私之祸。\n"
         @"        *   **见火克 (酉金被火克)**: 主迍灾（迟滞的灾祸）、损女忧（女性有忧）。\n"
         @"---\n"
         @"#### **`河魁 (戌)`**\n"
         @"*   **[A] 核心基因**: 【**S级 · 争斗/权威**】、【**聚众/掌控**】、【**终结/牢狱**】、【**数象: 5**】\n"
         @"*   **[B] 衍生表征**:\n"
         @"    *   `物理映射`: 监狱、军营、堡垒、坟墓、印章、武器、刑具。\n"
         @"    *   `人物映射`: 军人、囚犯、狱吏、恶霸、屠夫、领导。\n"
         @"    *   `事件映射`: 争斗、诉讼、集体行动、欺诈、屠宰、围捕。\n"
         @"    *   `身体映射`: 命门、心脏、腿足、胸。\n"
         @"*   **[C] 实战所主**:\n"
         @"    *   **`C.1 通用所主`**: 狱讼畜亡游（主官司、损失），僧道奴仆贵贱搜（人物），见墓尸骸（与死亡、坟墓有关）。\n"
         @"    *   **`C.2 克应断语`**:\n"
         @"        *   **见木克 (戌土被木克)**: 主刑苦、主人忧。\n"
         @"        *   **见水克 (戌土克水)**: 主争竞。\n"
         @"        *   **得生合金火**: 贫而富。\n"
         @"---\n"
         @"### **Chapter 4: 用神法典 (源自《提纲例约》)**\n"
         @"*   `协议定位`: 定义初传（用神）核心性质的判例。\n"
         @"*   `4.1`: **用神五气法典 (S+++级)**:\n"
         @"    *   **旺气**: “旺发发言官事，旺气所胜忧县官也。” -> 事件启动能量强劲，与【官方、规则】相关。\n"
         @"    *   **相气**: “妻财相气论，相气所胜忧钱财也。” -> 事件启动能量次强，与【价值、目标】相关。\n"
         @"    *   **死气**: “死言丧祸至，死气所胜忧死丧也。” -> 事件启动能量衰竭，与【终结、丧失】相关。\n"
         @"    *   **囚气**: “囚动见官刑，囚气所胜忧刑狱也。” -> 事件启动受阻，与【约束、困境】相关。\n"
         @"    *   **休气**: “休来忧疾病，休气所胜忧疾病也。” -> 事件启动能量休止，与【停滞、健康问题】相关。\n"
         @"---\n"
         @"### **第二层：元理论法典 · 第一性原理与推演法则**\n"
         @"#### `协议定位`: 此层定义了所有“象”的生成规则、“关系”的动态逻辑，是系统进行深度、多维分析的【**根本方法论**】。\n"
         @"---\n"
         @"### **Chapter 6: 符号解构元理论**\n"
         @"#### `协议定位`: 本章为意象的【元理论】层。它定义了所有“象”的生成规则与推演逻辑，是系统进行【理气归象法】时，实现深度、多维分析的根本依据。\n"
         @"*   **6.1 五行取象法**:\n"
         @"    *   `司法源头`: 《五行大义》。\n"
         @"    *   `核心`: 五行是阳气在阴质上作用的五种基本模式。\n"
         @"    *   `模式`:\n"
         @"        *   `木 (曲直)`: 阳气引动阴质**从内向外**发散，形成分叉、伸长的形状。\n"
         @"        *   `火 (炎上)`: 阳气**集于表层**，向四方辐射。\n"
         @"        *   `土 (稼穑)`: 阴阳中和，**静止不动**。\n"
         @"        *   `金 (从革)`: 阳气**从外向内**收敛，阴质凝聚、坚固。\n"
         @"        *   `水 (润下)`: 阳气**深藏于内**，阴质包裹于外。\n"
         @"    *   `执行指令`: 所有对五行的解读，必须回归到这五种基础的“阴阳动态模型”。\n"
         @"*   **6.2 地支阴阳实情 (十二辟卦)**:\n"
         @"    *   `司法源头`: 《隋朝五行大义》。\n"
         @"    *   `核心`: 十二地支是对“阴阳动态模型”的进一步细化，是阴阳二气在十二个阶段的特定组合状态。\n"
         @"    *   `十二地支阴阳实情表 (强制调用)`:\n"
         @"        *   `子 (地雷复)`: “德在室，刑在野。” -> **阳气深藏于内** -> 智慧、内核、私密、奸邪。\n"
         @"        *   `丑 (地泽临)`: “德在堂，刑在街。” -> **阳气初现，欲出难出** -> 孕育、萌动、钩钜。\n"
         @"        *   `寅 (地天泰)`: “德在庭，刑在巷。” -> **阴阳交泰，阳气始达** -> 根基、官吏、文书。\n"
         @"        *   `卯 (雷天大壮)`: “德刑俱会于门。” -> **阳气破阴而出，迅速突进** -> 竞争、爆发、门户、车船。\n"
         @"        *   `辰 (泽天夬)`: “德在巷，刑在庭。” -> **阳气上达，阴气衰微** -> 压迫、牢狱、战斗、妊娠。\n"
         @"        *   `巳 (乾)`: “德在街，刑在堂。” -> **纯阳用事，拼命外溢** -> 极致的光明、意外、解散、死丧。\n"
         @"        *   `午 (天风姤)`: “德在野，刑在室。” -> **一阴始生，阳气始衰** -> 关注外表、公开、道路、信息、虚荣。\n"
         @"        *   `未 (天山遁)`: “德在街，刑在堂。” -> **阴长阳遁，阳气转内** -> 成熟、滋味、家庭、孤寡。\n"
         @"        *   `申 (天地否)`: “德在巷，刑在庭。” -> **阴阳否隔，杀威方盛** -> 变革、肃杀、道路、医生、僧人。\n"
         @"        *   `酉 (风地观)`: “德在门，刑复会于门。” -> **阳气内入，阴气外施** -> 筛选、关隔、私门、金钱、边兵。\n"
         @"        *   `戌 (山地剥)`: “德在庭，刑在巷。” -> **阳气将尽，阴气上达** -> 收藏、终结、牢狱、奴仆、枯骨。\n"
         @"        *   `亥 (坤)`: “德在堂，刑在街。” -> **纯阴用事，阳气复始** -> 闭藏、核心、种子、征召、厕所。\n"
         @"*   **6.3 天象取象法**\n"
         @"    *   `三垣` & `列宿`: 此为神将意象的【最高本源】。每一个月将的核心象意，均可追溯至其对应的星宿。\n"
         @"        *   **【执行指令】**: 在进行深度【取象】时，必须优先调用月将对应的星宿定义，以获取其最根本、最原始的象意。\n"
         @"        *   **案例映射**: `辰`的“争斗”象，源于其内含的`角`宿“主将兵”；`亥`的“图书”象，源于其内含的`壁`宿“为天下图书之秘府”。\n"
         @"    *   `北斗`: `辰`(天罡)与`戌`(河魁)的权威与刑杀之象，源于其与北斗的关系。\n"
         @"*   **6.4 地象法**\n"
         @"    *   `方位高下`: `亥`为天门(西北高)，`巳`为地户(东南低)。`亥`主头，`巳`主足。此为空间定位的基本法则。\n"
         @"    *   `宅舍类比`: `子`为内房, `午`为大堂, `丑`为庭园, `亥`为楼台。此为将天地盘结构直接映射为建筑空间的模型。\n"
         @"*   **6.5 八卦法**\n"
         @"    *   `先天卦位` & `后天卦位`: 通过地支与八卦的对应关系取象。\n"
         @"    *   **案例映射**: `卯`配震卦，震为长子，故`卯`为长男、太子。`酉`配兑卦，兑为少女，故`酉`为少女、小妾。`午`配离卦，离为目，故`午`为眼睛。\n"
         @"*   **6.6 禽兽法**\n"
         @"    *   `十二生肖` & `星禽`: 每个地支都对应特定的动物，其生物习性可直接转译为社会象意。\n"
         @"    *   **案例映射**: `戌`为狗，狗有忠诚、奴仆、食秽的特性，故`戌`为奴仆、污秽之物。`卯`为兔/狐，引申出机敏、狡猾、阴私之象。\n"
         @"*   **6.7 字形音义法**\n"
         @"    *   `义`: `未`通“味”，故主饮食。`卯`为门，主门户。\n"
         @"    *   `音`: `申`通“身”，故主身体。`巳`通“嗣”，主子嗣。`丁`通“钉”，主钉子、或“盯”梢。\n"
         @"    *   `形`: `丑`形似钥匙入锁，或田地，或王座。`申`似电、针、箭。`酉`内含“一”，似酒器中有物。\n"
         @"    *   **【执行指令】**: 此法为高阶联想与细节还原的核心技术，用于在已有结论基础上，进行象意的二次生发与确认。\n"
         @"*   **6.8 - 6.20 高阶组合与推演法**\n"
         @"    *   `神名取象`: `传送`(申)主道路，`功曹`(寅)主官吏。\n"
         @"    *   `宫名取象`: `巳`(双女座)与`亥`(双鱼座)皆有“双”之象。\n"
         @"    *   `藏干取象`: `巳`藏丙戊，`未`藏丁己，故皆有“两姓”、“兼职”之象。\n"
         @"    *   `合取`: `丑`(牛) + `丑`(田) = `犁`。`寅`(木) + `寅`(鬼门) = `祭器`/`神树`。\n"
         @"    *   `邻取`: `亥子丑`同为北方，共用“阴暗”、“私密”之象。\n"
         @"    *   `对取`: `卯`为前门，则`酉`为后门。`亥`为头，则`巳`为足。\n"
         @"    *   `三合取象`: `申子辰`三合水，共享“流动”、“阴私”、“智慧”之象。\n"
         @"    *   `四方取象`: 四孟(`寅申巳亥`)主动、为始。四仲(`子午卯酉`)主交易、为中。四季(`辰戌丑未`)主库藏、为终。\n"
         @"    *   `借取`: `申`本无医药之象，但其邻宫`未`中有井宿可延伸，且`申`为传送，故`申`可借象为“传送医药之人”，即医生。\n"
         @"    *   `推取`: 从已知象推导关联象。`巳`为灶 -> 庖人。`戌`为军 -> 营寨。`酉`为鸡 -> 雀斑。\n"
         @"    *   `转取`: 象意的链式演变。`未`(衣服) -> `孝服` -> `白头` -> `雪`。\n"
         @"    *   `造字法`: 通过偏旁部首进行拆分与组合，用于姓氏、地名等特定占断。\n"
         @"---\n"
         @"### **Chapter 7: 社会关系与资源模型 (六亲之象 · 京氏本意版)**\n"
         @"#### `协议定位`: 本章定义了以日干为中心的社会关系网络与资源模型。其解释权源自六亲体系的【第一性原理】，优先级极高。\n"
         @"*   **官鬼 (克我者为“系”爻)**:\n"
         @"    *   `本意`: 【捆绑与悬挂】。代表一切**缠绕自身、无法忽视、被动承受、且公开可见**的现实。\n"
         @"    *   `正面 (官)`: 有序的约束。`人物`: 丈夫(纲常)、上司(管理)。`事件`: 工作(捆绑你的时间)、官职(名誉所系)、法律规则(行为约束)。\n"
         @"    *   `负面 (鬼)`: 无序的缠绕。`人物`: 敌人、小人。`事件`: 忧愁(剪不断理还乱)、疾病(缠身)、官司(被牵扯)、考试难度。\n"
         @"    *   **【执行指令】**: 任何官鬼爻的解读，都必须围绕其“**可见的缠绕/约束**”这一核心意象展开。）\n"
         @"*   **妻财 (我克者为“制”爻)**:\n"
         @"    *   `本意`: 【裁剪与塑造】。代表一切**我能主动支配、控制、改变其形态**的现实。\n"
         @"    *   `人物`: 妻子(古代可支配)、下属、员工。\n"
         @"    *   `事物`: 钱财(可分割使用)、食物(可加工)、资产、目标(可规划实现)。\n"
         @"    *   `状态`: 主动性、控制欲、物质世界。\n"
         @"    *   **【执行指令】**: 任何妻财爻的解读，都必须围绕其“**我主动支配的可变对象**”这一核心意象展开。\n"
         @"*   **子孙 (我生者为“宝”爻)**:\n"
         @"    *   `本意`: 【珍藏于室】。代表一切**被隐藏、被保护、不欲人知、且需我耗费心力**的现实。\n"
         @"    *   `人物`: 子女(需保护)、晚辈、学生。\n"
         @"    *   `事物`: 隐私、生殖器官、解决方案(秘而不宣的锦囊)、创意、爱好、宠物。\n"
         @"    *   `状态`: 隐藏、私密、内在的快乐、消耗。\n"
         @"    *   **【执行指令】**: 子孙爻的核心是【不可见性】。它是官鬼爻（公开悬挂）的天然对立面。子孙克官鬼的本质，是“**通过隐藏（宝）来规避公开的麻烦（系）**”。\n"
         @"*   **父母 (生我者为“义”爻)**:\n"
         @"    *   `本意`: 【神明护佑】。代表一切**无形的、背景性的、提供支持与合法性**的现实。\n"
         @"    *   `人物`: 父母、长辈、师长、靠山。\n"
         @"    *   `事物`: 知识、信息、文书、合同（合法性）、房屋车辆（庇护所）、理论体系。\n"
         @"    *   `状态`: 庇护、源头、劳心（因其无形）。\n"
         @"    *   **【执行指令】**: 父母爻的核心是【无形性】。它是妻财爻（物质实体）的天然对立面。财克父母的本质，是“**物质现实（制）冲击了理论或庇护（义）**”。\n"
         @"*   **兄弟 (同我者为“专”爻)**:\n"
         @"    *   `本意`: 【专一目标】。代表与“我”拥有**同一目标或立场**的现实。\n"
         @"    *   `合作`: 众人为同一目标协作。`人物`: 兄弟、朋友、同事、团队。\n"
         @"    *   `竞争`: 众人为同一目标争夺。`人物`: 竞争对手。`事物`: 成本、费用、消耗（因资源被瓜分）。\n"
         @"    *   **【执行指令】**: 兄弟爻的核心是【目标同一性】，吉凶取决于该目标是需要“合作”还是引发“竞争”。它是妻财爻（被我支配的资源）的天然掠夺者。\n"
         @"---\n"
         @"### **Chapter 8: 个体化修正层 (本命和行年之象)**\n"
         @"#### `协议定位`: 此为【个体化修正层】。本命与行年是连接【通用课盘（天）】与【特定个体（人）】的桥梁。其状态拥有对课体结论的最终修正权。\n"
         @"*   **本命**:\n"
         @"    *   `核心定义`: 个体生命信息的【静态基盘】，代表一个人的本质、根基、天赋与终身格局。\n"
         @"    *   `取象逻辑`:\n"
         @"        1.  **本体六亲**: 本命地支相对于日干的六亲属性，揭示其命定的角色。`本命作财`，命里有财；`本命作鬼`，命带灾疾。\n"
         @"        2.  **上下加临**: 本命在地盘上的位置（坐），及其天盘上神（乘），构成其【静态处境】。`本命坐墓`，怀才不遇；`本命上见鬼`，终身易犯小人。\n"
         @"        3.  **与课传关系**: 本命是否入传、是否与关键类神形成刑冲合害，决定了此事件对其命运的【触动程度】。\n"
         @"*   **行年**:\n"
         @"    *   `核心定义`: 个体生命信息的【动态流年】，代表一个人在特定年份的运势、机遇与挑战。是短期事件吉凶的【放大器】或【衰减器】。\n"
         @"    *   `取象逻辑`:\n"
         @"        1.  **本体角色**: 与本命类似，行年地支的六亲属性与上下加临，定义了当年的【核心主题】与【处境】。`行年上见马`，此年多奔波。\n"
         @"        2.  **【S级指令 · 焦点锁定】**: **若行年或其上神入传，则该事件被标记为【年度核心事件】，其成败直接关乎当年运势的起伏。**\n"
         @"        3.  **吉凶修正权 (天命法则)**: `课传吉而行年凶，吉事减半`。`课传凶而行年吉，凶事减轻`。行年状态是对事件最终“落地效果”的最终裁决。\n"
         @"*   **【执行指令】**:\n"
         @"    *   **禁止孤立断课**: 在得出任何结论前，必须进行【本命行年交叉验证】。\n"
         @"    *   **变体思维**: 必须认识到，同一课盘，对于不同年命的人，其最终吉凶可以完全不同。本命行年是实现“同课异断”的唯一合法密钥。\n"
         @"    *   **【新增】情境接口指令**: 在分析本命和行年时，**必须**明确其主要作用于【主观现实场（干课）】还是【客观事件场（支课）】。例如，“行年临干”直接影响求测者的当年状态，“行年临支”则主要影响所问之事的外部环境。\n"
         @"---\n"
         @"### **Chapter 9: 环境与变量层 (神煞之象 · 职能版)**\n"
         @"#### `协议定位`: 此为【环境与变量层】。神煞不是孤立的吉凶标签，而是为课盘附加了额外【条件】与【变量】的【**特定职能NPC**】，用于精细化描述事件的性质、时机与特定风险/机遇。\n"
         @"*   **核心应用原则 (三阶过滤法)**:\n"
         @"    1.  **第一阶：宏观法则 (S级)**: `太岁`、`月建`、`旬空`。定义全局的时空主题与规则。\n"
         @"    2.  **第二阶：战略变量 (A级)**: `禄神`、`羊刃`、`驿马`、`桃花`。无论占问何事，此四者出现必为核心剧情驱动器，必须重点分析其【职能】。\n"
         @"    3.  **第三阶：战术道具 (B/C级)**: 其他所有神煞。其重要性完全取决于【是否与所问之事主题相关】。`占病见天医`，权重升至A+级；`占婚见天医`，权重降至C级（背景噪音）。\n"
         @"*   **核心神煞精解 (职能重构版)**:\n"
         @"    *   `禄神`:\n"
         @"        *   `所主`: 【**生存资源与生命力**】。\n"
         @"        *   `角色/职能`: 扮演“**后勤官**”的角色，提供俸禄、工资、食禄、福气等一切维持生命与事业的根本给养。\n"
         @"        *   `动态逻辑`: 禄神旺相，则“后勤”充足，根基稳固。禄神受克或空亡，则“粮草”断绝，预示着工作、健康或收入的危机。它是【我之所得】的根本。\n"
         @"    *   `羊刃`:\n"
         @"        *   `所主`: 【**极端的行动力与破坏力**】。\n"
         @"        *   `角色/职能`: 扮演“**狂战士**”或“**外科医生**”的角色，代表一种不计后果、锋利无比的极端力量。\n"
         @"        *   `动态逻辑`: 刃可以用于“攻击”（竞争、暴力），也可以用于“切割”（手术、分离）。其作用是吉是凶，完全取决于它被用来对付谁。用以克鬼，则为制胜奇兵；用以伤身或克财，则为血光之灾。它是【我之极端】的表现。\n"
         @"    *   `驿马`:\n"
         @"        *   `所主`: 【**物理空间的位移与状态变更**】。\n"
         @"        *   `角色/职能`: 扮演“**信使**”或“**传送门**”的角色，负责打破静态，强制引发物理层面的移动。\n"
         @"        *   `动态逻辑`: 驿马的核心是“动”，是事件从“静”到“动”的开关。它强制引发迅速的、可见的位移，如出差、搬家、换工作、信息传递。其动本身无吉凶，吉凶看其“动向何方”（所临宫位）以及“为何而动”（与何神将并临）。\n"
         @"    *   `桃花`:\n"
         @"        *   `所主`: 【**非理性的吸引力与人际纠葛**】。\n"
         @"        *   `角色/职能`: 扮演“**交际花**”或“**麻烦制造者**”的角色，引入与情感、欲望、人际魅力相关的变量。\n"
         @"        *   `动态逻辑`: 桃花的核心是“沐浴”，主脱衣、裸露、败地。它能增强人缘与魅力，但也极易引发不正当的、带来麻烦的私情。吉时为人见人爱，凶时为酒色是非。\n"
         @"*   **全局变量分析协议**:\n"
         @"    *   `指令`: 在完成【交互网络分析】后，系统**必须**执行一次“全局变量扫描”，检查`太岁`、`月建`、`旬空`等S级神煞，如何影响整个交互网络。\n"
         @"    *   `分析维度`:\n"
         @"        *   **`太岁/月建`**: 作为“**最高权威**”，它们是生是克，直接定义了事件的“**政策环境**”是支持还是反对。\n"
         @"        *   **`旬空`**: 作为“**变量延迟器/虚化器**”，它所临的节点（无论是矛盾节点还是机遇节点）都将被标记为【当前不可用】或【虚假不实】，极大地改变战局的评估。\n"
         @"---\n"
         @"### **Chapter 10: 九宗门 · 叙事动力学终极法典**\n"
         @"*   `协议定位`: **此为本系统进行三传动态分析的【第一因】与【元理论框架】。** 本法典基于提供的古典文献JSON进行严格校勘，定义了三传生成的【创世法则】与包含所有变体的【终极作战手册】。\n"
         @"*   `执行心法`: **宗门一定，手筋自现。变体既出，焦点必移。**\n"
         @"---\n"
         @"#### **第一门：【贼克法】· 矛盾显发之局**\n"
         @"*   **【创世引擎_成因溯源】**: 四课之中，存在明确、单一的【**生克力量**】。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【初始攻击的有效性】。**\n"
         @"    > **【战术手册】**: 此为“打不打得过”的局。分析的绝对重心，必须放在评估 **初传【神将复合体】（攻击方）** 与 **被克地盘（承受方）** 之间的【**力量对比（旺衰）**】上。这次力量权衡的结论，直接为整个事件的最终成败定下了基调。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **`元首课` (无贼有克)**:\n"
         @"        *   **【战术指令】**: **锁定【上层意图】**。此为以尊制卑，大顺之象。事件由外部或上层发起，凡事宜先发制人。\n"
         @"    *   **`重审/始入课` (下贼上优先)**:\n"
         @"        *   **【战术指令】**: **锁定【下层动机】**。此为以下犯上，事逆之象。事件由内部或下层发起，凡事宜后发制人，先难后易。\n"
         @"    *   **【S级变体指令 · 力量反转审查】**:\n"
         @"        *   **`下不受制` (元首课变体)**: **【强制审查】** 若初传【神将复合体】休囚死绝，而被克地盘却旺相或得令、得德禄，则**必须**将结论修正为：“**尊卑不顺，反乱之道。上层虽意图制约，但下层实力雄厚，阳奉阴违，命令无法贯彻。**”\n"
         @"        *   **`下不制上` (重审课变体)**: **【强制审查】** 若初传【神将复合-体】休囚死绝，而被贼地盘却旺相有力，则**必须**将结论修正为：“**虽有乖违之患，但下层力量不足，终不能肆意为害。**”\n"
         @"---\n"
         @"#### **第二门：【比用法/知一法】· 多重矛盾之择优**\n"
         @"*   **【创世引擎_成因溯源】**: 四课中存在多个同类矛盾点，系统依据与日干的“相比”关系，做出【**本能选择**】。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【动机审判】。**\n"
         @"    > **【战术手册】**: 此为“起点选择题”。分析的绝对重心，必须从“初传是什么”转移到“**【为什么】是这个初传**”。它与日干的“相比”关系，是对当事人潜意识、真实动机或核心弱点的直接曝光。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **`知一格` (多上克下)**:\n"
         @"        *   **【战术指令】**: **锁定【外部干扰源】**。分析焦点为“祸从外来”，必须识别出这个被选中的“克”（初传）代表了哪一类外部的人或事（如同辈、朋友）。\n"
         @"    *   **`比用格` (多下贼上)**:\n"
         @"        *   **【战术指令】**: **锁定【内部矛盾点】**。分析焦点为“事从内起”，必须识别出这个被选中的“贼”（初传）代表了哪一类内部因素（如妻财、下属）。\n"
         @"    *   **【S级变体指令 · 八专格并见】**:\n"
         @"        *   **【强制审查】** 若此课同时为八专日，则**必须**在“择优”的基础上，增加“**二人同心，内外不分，事多重叠**”的判断。\n"
         @"---\n"
         @"#### **第三门：【涉害法】· 险阻丛生之局**\n"
         @"*   **【创世引擎_成因溯源】**: 局势极度复杂，比用法失效，系统被迫选择【**经历最多艰险**】的矛盾点作为开端。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【启动成本核算】。**\n"
         @"    > **【战术手册】**: 此为“代价是否值得”的局。分析的绝对重心，是执行并解读“涉害深浅”的计算。这个过程本身就是一份详细的“**成本与风险清单**”，它定义了事件的艰难基调。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **【A级指令 · 执行Tie-Break规则】**: 若涉害深度相等，则：\n"
         @"        *   `见机课`: **锁定【开创性风险】**。优先取四孟（寅申巳亥）之上神为用。此主事有疑，急须改变。\n"
         @"        *   `察微课`: **锁定【交易性风险】**。若无孟，则取四仲（子午卯酉）之上神为用。此主须防他人计算谋害。\n"
         @"        *   `缀瑕课`: **锁定【立场决策】**。若孟仲复等或皆无，则阳日取【**第一课上神**】为用，阴日取【**第三课上神**】为用。此主两方交争，经延岁月。\n"
         @"---\n"
         @"#### **第四门：【遥克法】· 外部干涉之局**\n"
         @"*   **【创世引擎_成因溯源】**: 内部无克，矛盾来自**遥远的、外部的力量**。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【作用力方向】与【变质风险】。**\n"
         @"    > **【战术手册】**: 此为“外部变量管理”的局。分析必须分两步走：\n"
         @"    > 1.  **判定方向**: 是“箭射向我”（蒿矢），还是“我射出箭”（弹射）？\n"
         @"    > 2.  **评估虚实**: 必须检查此“虚箭”是否会“变质”。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **`蒿矢格` (神克日)**:\n"
         @"        *   **【战术指令】**: **锁定【被动应对】**。利主不利客，利后动。始有惊恐，终却无事。\n"
         @"    *   **`弹射格` (日克神)**:\n"
         @"        *   **【战术指令】**: **锁定【主动谋为】**。利客不利主，利先动。若克两神，为“一箭射双鹿”，主心意两岐。\n"
         @"    *   **【S级变体指令 · 虚实转化审查】**:\n"
         @"        *   **`蒿矢有镞`**: **【强制审查】** 若课传中见 `金` 或 `白虎` 等金煞，则**必须**将结论修正为：“**虚惊变实灾，伤害力剧增。**”\n"
         @"        *   **`弹射有丸`**: **【强制审查】** 若课传中见 `土` 或 `勾陈` 等土煞，则**必须**将结论修正为：“**虚谋变实控，阻碍力剧增。**”\n"
         @"        *   **`遥克空亡/遗镞失矢`**: **【强制审查】** 若初传空亡，则**必须**将结论修正为：“**凡事虚无不实，最终不成。**”\n"
         @"---\n"
         @"#### **第五门：【昴星法】· 僵局求索之局**\n"
         @"*   **【创世引擎_成因溯源】**: 内外无克，四课俱全，绝对僵局，被迫从“酉”位进行【**天启式**】破局。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【破局之钥】及其对【人我双方】的直接冲击。**\n"
         @"    > **【战术手册】**: 此为“找规则开关”的局，不靠蛮力。分析重心在于：1) 彻查初传（来自酉位）的性质。2) 严格遵循固定的传递路径，解读此“破局”行为如何作用于【日课体系】与【辰课体系】。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **`虎视转蓬` (阳日)**:\n"
         @"        *   **【战术指令】**: **锁定【外部动荡】**。传递路径为：【酉上神】(初) → 【**第三课上神**】(中) → 【**第一课上神**】(末)。主惊恐，祸从外起，宜静守。\n"
         @"    *   **`冬蛇掩目` (阴日)**:\n"
         @"        *   **【战术指令】**: **锁定【内部暗动】**。传递路径为：【酉下神】(初) → 【**第一课上神**】(中) → 【**第三课上神**】(末)。主事暗昧，祸从内起，宜潜藏。\n"
         @"    *   **【S级变体指令 · 神将共振审查】**:\n"
         @"        *   `虎视遇虎` 或 `冬蛇遇蛇`: **【强制审查】** 若初传或三传见到与课格同名的凶将（白虎/螣蛇），则**必须**将凶性断语的权重提升至最高级。\n"
         @"        *   `车轮倒斫` (`申加卯`): **【强制审查】** 出现此结构，若传见 `玄武`、`白虎`，则为大凶之象。\n"
         @"        *   `离明天驷` (`午加卯`): **【强制审查】** 出现此结构，即便遇凶将，也**必须**在结论中加入“**凶中有救，暗藏转机**”的判断。\n"
         @"---\n"
         @"#### **第六门：【别责法】· 系统残缺之局**\n"
         @"*   **【创世引擎_成因溯源】**: 四课不备（仅三课），且无克，必须引入【**外部关联变量**】补全。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【外援性质】与【第一课上神】。**\n"
         @"    > **【战术手册】**: 此为“借力打力”的局。1) 审查初传的性质，判断此“外援”是敌是友。2) 由于中末传俱并于【**第一课上神**】，因此对【第一课上神】的深度剖析，就是对事件全部后续发展的终审判决。\n"
         @"---\n"
         @"#### **第七门：【八专法】· 内外合一之局**\n"
         @"*   **【创世引擎_成因溯源】**: 干支同位，四课不备（仅两课），内外不分，系统陷入【**自我循环**】。\n"
         @"*   **【S+++级_焦点锁定指令】**:\n"
         @"    > **锁定【第一课上神】。**\n"
         @"    > **【战术手册】**: 此为“修内功”的局。1) 分析模式强制切换至【心理分析】。2) 整个三传都是对当事人【初始状态（第一课上神）】的不断重复与放大。对【第一课上神】的生克、神将、旺衰的评估，就是对整个事件的终审判决。\n"
         @"*   **【S级变体指令 · 竞争性双轨叙事协议】**:\n"
         @"        *   `触发条件`: **IF** (课体为`八专`) **AND** (初传为`日干之比肩`且自四课外发用) **AND** (所占之事具备明确`竞争性`，如考试、竞标、升迁)。\n"
         @"        *   `执行心法`: 《占验指南》注·“日比自别处发用...应己不得...中末之神为干上神，则应己事。”\n"
         @"        *   `强制执行流程`:\n"
         @"            *   **轨道A (竞争者线)**: 将【初传】定义为竞争对手。分析其旺衰与神将，描绘对手的状况与最终得失。\n"
         @"            *   **轨道B (我方线)**: 将【中、末传】（即干上神）定义为我方。分析其与日干的关系，描绘我方在失利后的真实处境（如“虽失主标，但仍获次级机会”）。\n"
         @"            *   **最终整合**: 输出结论时，必须明确区分这两条命运线的不同结局。\n"
         @"*   **【战术分析详辨与变体指令】**:\n"
         @"    *   **`帷簿不修` (无克变体)**:\n"
         @"        *   **【战术指令】**: **锁定【失范风险】**。无克制的八专课，象征内外无别，尊卑共室。若传见 `天后`、`六合`、`玄武`、`太阴`，则**必须**重点审查是否存在“**人伦失序、私情淫佚**”的风险。\n"
         @"    *   `独足格`:\n"
         @"        *   **【战术指令】**: **锁定【极端停滞】**。当三传归一或中末传空亡时，象征当事人的内心状态陷入极端的“单曲循环”或“空转”。分析必须指出这种“独足难行”的停滞状态。\n"
         @"---\n"
         @"### **Chapter 12: 隐藏属性与变量层 (天干之象 · 生存策略版)**\n"
         @"#### `协议定位`: 此为【隐藏属性与变量层】。天干（尤其是遁干）为地支附加了一层隐藏的、更精微的【心理动机】与【生存策略】。\n"
         @"*   `司法源头`: “十天干的信息是偏抽象的...描述了不同的人应对‘生存问题’的‘策略’”。\n"
         @"*   `【执行指令】`: **在进行遁干分析时，若遇`甲`、`丁`、`癸`，必须将其视为潜在的【剧情关键节点】，并提升其解读权重。**\n"
         @"*   **甲**:\n"
         @"    *   `策略`: 【**开创与引领**】。从0到1，定义规则。\n"
         @"    *   `动机`: 纯粹的向外扩张，不容置疑的领导欲。\n"
         @"    *   `象意`: 创新、开端、领导、野心、不听劝告、破局之始。\n"
         @"*   **乙**:\n"
         @"    *   `策略`: 【**依附与学习**】。跟随强者，等待时机。\n"
         @"    *   `动机`: 寻求庇护与成长，被动接收。\n"
         @"    *   `象意`: 配合、学习、模仿、希望、转机、恋爱脑、慕强。\n"
         @"*   **丙**:\n"
         @"    *   `策略`: 【**天降好运**】。非人力所为的机遇。\n"
         @"    *   `动机`: 权威、光明、公开。\n"
         @"    *   `象意`: 意外之喜、神来之笔、公开的权威、暴躁、权力。\n"
         @"*   **丁**:\n"
         @"    *   `策略`: 【**异变与洞察**】。意料之外的闯入与改变。\n"
         @"    *   `动机`: 带来希望或突变，机敏地发现机会。\n"
         @"    *   `象意`: 关键转机、希望之光（暗夜烛火）、侵略感、新奇事物、针尖般的洞察力。\n"
         @"*   **戊**:\n"
         @"    *   `策略`: 【**建立秩序与边界**】。\n"
         @"    *   `动机`: 寻求稳定、组织集体、阻隔混乱。\n"
         @"    *   `象意`: 阻碍、迟滞、资本、秩序、规则、城墙、重复排列（如钥匙串）。\n"
         @"*   **己**:\n"
         @"    *   `策略`: 【**奉献与服务**】。将精华上奉。\n"
         @"    *   `动机`: 通过服务获得价值，利他。\n"
         @"    *   `象意`: 策划、计谋、私心、服务精神、打工、无私奉献、婚姻中的责任感。\n"
         @"*   **庚**:\n"
         @"    *   `策略`: 【**破坏性变革**】。用理性与规则强行改变。\n"
         @"    *   `动机`: 较真、只认事实不认人情。\n"
         @"    *   `象意`: 阻碍、困难、变革、肃杀、司法、军警、铁面无私、破坏性。\n"
         @"*   **辛**:\n"
         @"    *   `策略`: 【**精雕细琢**】。在规则内追求完美。\n"
         @"    *   `动机`: 理智与美感的结合，恰到好处的拿捏。\n"
         @"    *   `象意`: 错误、罪过、珍宝、高技术、艺术品、管理才能、精密的错误。\n"
         @"*   **壬**:\n"
         @"    *   `策略`: 【**顺势而为**】。不抵抗，以柔化刚。\n"
         @"    *   `动机`: 避免冲突，寻求智慧与和谐。\n"
         @"    *   `象意`: 智慧、流动、趋势、谦让、绥靖、容易被占便宜、不懂拒绝。\n"
         @"*   **癸**:\n"
         @"    *   `策略`: 【**积蓄以备不测**】。\n"
         @"    *   `动机`: 对未知的恐惧，强烈的危机意识。\n"
         @"    *   `象意`: 终结、闭藏、惜福、囤积、防范风险、秘密、逃跑计划。\n"
         @"*   **天干五合 (策略联盟)**:\n"
         @"    *   `甲己合`: 【**领导与执行者联盟**】。如签合同。\n"
         @"    *   `乙庚合`: 【**依附者与强权者联盟**】。慕强，为安全感而结合。\n"
         @"    *   `丙辛合`: 【**机遇与才能联盟**】。天赐良机遇到准备好的人。\n"
         @"    *   `丁壬合`: 【**入侵者与退让者联盟**】。一方主动，一方不拒，易生淫佚或滥用。\n"
         @"    *   `戊癸合`: 【**秩序与不安全感联盟**】。为寻求稳定保障而结合，常有利益交换。\n"
         @"---\n"
         @"### **Chapter 13: 宇宙模型与叙事结构法典**\n"
         @"#### `协议定位`: 此为本系统的【**世界观基石**】。它定义了六壬盘的宇宙结构、时空层次与叙事逻辑，是所有分析的宏观框架。\n"
         @"*   **13.1 宇宙三界模型**\n"
         @"    *   `司法源头`: “三才异构 · 角色分层终极公理”、“无需争论，大六壬式盘的‘人盘’可能并不存在”。\n"
         @"    *   `核心模型`: 六壬盘是一个“天地日”或“神-人-地”的【**功能分层宇宙**】，而非简单的物理空间。\n"
         @"    *   `【三界释义】`:\n"
         @"        *   **神盘**: **天之界/贵族层**。代表事物的【**精神内核、性情、意志、品阶**】。它回答“它想干什么？”。\n"
         @"        *   **天盘**: **日之界/职能层**。代表事物的【**功用、行为、职责、动态表现**】。它回答“它在干什么？”。\n"
         @"        *   **地盘**: **地之界/环境层**。代表事物的【**物理载体、所处环境、静态背景**】。它回答“它在哪里/它是什么？”。\n"
         @"    *   `【执行指令】`: **全息解读**。任何一个完整的六壬实体，都必须通过“**神乘将临地**”的三位一体方式来解读。例如：【贵人(神盘)】乘【午(天盘)】临【子(地盘)】=“一个**意志高贵**的实体(神)，正在采取**公开、彰显的行动**(将)，但其所处的**环境却是私密的、隐藏的**(地)。”\n"
         @"*   **13.2 静态情境模型**\n"
         @"    *   `司法源头`: “四课定位‘四课全息角色画像报告’”、“大六壬的四课是真的有先后顺序的”。\n"
         @"    *   `核心模型`: 四课是事件的【**静态本体（体）**】，并遵循一个从“意”到“形”的、不可逆的【**心理演化时序**】。\n"
         @"    *   `【四课时序释义】`:\n"
         @"        *   `第一课 (干阳 · 意之始)`: **【动机层】**。事件的最初起意，第一反应，如“正气发现邪气”。\n"
         @"        *   `第二课 (干阴 · 感之应)`: **【感受层】**。对动机的内在情绪响应，如“心神感到痒”。\n"
         @"        *   `第三课 (支阳 · 谋之动)`: **【策略层】**。基于感受而制定的外部行动图谋，如“决定伸手去挠”。\n"
         @"        *   `第四课 (支阴 · 形之终)`: **【物质层】**。策略行动最终落地的客观形态，如“手摸到包”。\n"
         @"    *   `【执行指令】`: **核心分析流程，必须严格遵循此“意 -> 感 -> 谋 -> 形”的顺序**，来解构事件的静态全貌。\n"
         @"*   **13.3 动态剧情模型**\n"
         @"    *   `司法源头`: “四课定体 · 三传演用之终极公理”。\n"
         @"    *   `核心模型`: 三传是事件的【**动态功用（用）**】，是在四课定义的静态情境中，上演的一出【**三幕剧**】。\n"
         @"    *   `【三传幕次释义】`:\n"
         @"        *   `初传`: **【第一幕：激励事件】**。打破四课静态平衡的导火索，是故事的真正开端。\n"
         @"        *   `中传`: **【第二幕：对抗与转折】**。矛盾的激化，核心的博弈，事件的关键转折点。\n"
         @"        *   `末传`: **【第三幕：结局】**。能量的最终归宿，故事的落幕，矛盾的最终结果。\n"
         @"    *   `【执行指令】`: **核心分析流程，必须将三传解读为对“核心矛盾”的动态解决过程**，并明确指出每一幕在整个剧情中的作用。\n"
         @"---\n"
         @"### **Chapter 14: 生命周期状态机 (12长生宫之象 · 气质二元版)**\n"
         @"#### `协议定位`: 此为【生命周期状态机】。临宫十二长生宫精细地描述了一个事物从萌发到消亡的全过程，是判断其【内在生命力】与【发展阶段】的核心工具。\n"
         @"*   **【核心解读原则：气质二元论】**\n"
         @"    *   `司法源头`: 《五行大义》。“阳为气，阴为质”。旺为气，死为质。“死气则重”。\n"
         @"    *   `执行指令`: 在解读十二长生状态时，必须同时分析其【气 (功能/能量)】与【质 (实体/积淀)】两个维度的消长。\n"
         @"*   **【执行指令】: 严格采用【五行长生】，而非【日干长生】。**\n"
         @"*   `长生`: 【气】之始生，功能初现；【质】之萌发，形体尚弱。\n"
         @"*   `沐浴`: 【气】浮于表，功能不稳；【质】初形成，易受污染。(桃花、败地)\n"
         @"*   `冠带`: 【气】渐强盛，功能初具；【质】已成形，装饰打扮。(荣誉)\n"
         @"*   `临官 (禄)`: 【气】之壮年，功能稳定；【质】之坚实，形态成熟。(得禄)\n"
         @"*   `帝旺 (刃)`: 【气】之顶点，功能极致；【质】之极盛，物极必反。(凶险)\n"
         @"*   `衰`: 【气】始衰退，功能下降；【质】仍坚固，但开始老化。\n"
         @"*   `病`: 【气】出问题，功能紊乱；【质】现瑕疵，形态受损。\n"
         @"*   `死`: 【气】之终结，功能停息；【质】之固化，形态僵硬。\n"
         @"*   `墓`: **[S+++级重点]**\n"
         @"        *   `核心定义`: **动态能量（气）的终结点，与物质形态（质）的顶点。**\n"
         @"        *   `气之维度`: 功能停滞、活力衰微、事机不发。\n"
         @"        *   `质之维度`: 物质高度积淀、形态固化、能量内蕴。\n"
         @"        *   ---\n"
         @"        *   `【强制应用判例】`:\n"
         @"            *   **通用判例**:\n"
         @"                *   `日干入墓`: **我身受困**。解读：昏沉、受限、缺乏活力（气衰）。\n"
         @"                *   `吉神入库`: **价值被藏**。解读：财被锁、官被藏，暂时无法取用（质旺而被封）。\n"
         @"                *   `凶神入墓`: **灾祸被囚**。解读：凶事暂时被控制，无法发作（气衰而被困），为因祸得福之象。\n"
         @"                *   `占病见鬼墓`: **器质性病变**。解读：病已由气入质，为久病、肿瘤、或已成形的顽疾。\n"
         @"            *   **特殊地支判例**:\n"
         @"                *   `火墓戌`: **【空虚之藏】**。虽质旺，但因火无形体，故戌主“有皮内中空”、虚伪、欺诈、僧道。在分析中见到`戌`，必须优先考虑其“空”性。\n"
         @"                *   `水墓辰`: **【高压之藏】**。因水质被土封藏且内闭，故辰主“坚固”、天牢、囚禁、压力。见`辰`加临，其下的地支有被“撕裂、粉碎”之象。\n"
         @"                *   `金墓丑`: **【价值之藏】**。金为财宝、规则，丑为金库。故丑主田宅、资产、财库，也主将军（权力入库）。\n"
         @"                *   `木墓未`: **【生命之藏】**。木为生机、情感，未为木库。故未主家庭、婚姻（情感归宿）、也主坟墓（生命归宿）。\n"
         @"*   `绝`: 【气】之断绝，了无生机；【质】之瓦解，形体消散。(转折点)\n"
         @"*   `胎`: 【气】之受孕，功能酝酿；【质】未成形，仅为初步想法。\n"
         @"*   `养`: 【气】在休养，功能待发；【质】在培养，形态不实。\n"
         @"---\n"
         @"### **Chapter 15: 信息强化与焦点锁定层 (重象)**\n"
         @"#### `协议定位`: 此为【信息强化与焦点锁定层】。当一个核心概念（如本命、行年、关键类神）在课传的不同位置【重复出现】时，该信息被视为“加重”或“强调”，其在整个事件中的【权重】和【宿命性】被提升至最高级。\n"
         @"*   **核心定义**: “重象”并非简单的重复，而是指同一个【现实实体】或【核心概念】通过不同的【六壬符号】在盘中多次显现。\n"
         @"*   **识别规则**:\n"
         @"    1.  **本命/行年重象**: `本命`或`行年`的地支（或其上神），与`三传`或`四课`中的某个地支重合。\n"
         @"        *   **【执行指令】**: 一旦识别，立即触发【主角锁定】协议。该课传位置不再是通用符号，而被【永久指认】为当事人命运轨迹的【显化点】。其吉凶直接与当事人命运共振。\n"
         @"        *   **案例映射**: `例5`（袁知镇占终身），末传`酉`既是日之败神，又是其`本命`，故“自身自败坏”的象意被极大强化，成为终身定论。\n"
         @"    2.  **类神重象**: 占问之事的核心类神（如占病之`官鬼`，占财之`妻财`）在课传中多次出现。\n"
         @"        *   **【执行指令】**: 触发【主题强化】协议。这表明该事件的性质被该类神所【垄断】。\n"
         @"        *   **案例映射**: `例1`（王县丞占病），课传中`午`火子孙出现了四次，对应其“丧男女四人”的悲剧。`午`作为子孙的象意被反复强调，最终以数量的形式应验。\n"
         @"*   **解读逻辑**:\n"
         @"    *   **非巧合原则**: 重象绝非偶然，而是宇宙模型在强调某一特定信息。分析师必须将重象作为解读的【第一突破口】。\n"
         @"    *   **宿命性原则**: 重象揭示了事件中根深蒂固、难以改变的核心驱动力或结局。它指向“命中注定”的层面。\n"
         @"---\n"
         @"### **Chapter 16: 数量与频率分析层 (复象)**\n"
         @"#### `协议定位`: 此为【数量与频率分析层】。与“重象”强调【质】不同，“复象”强调【量】。当同一个【六壬符号】（特指神将）在盘中重复出现时，它暗示了与该符号相关的事件在【数量、频率、或参与人数】上的特征。\n"
         @"*   **核心定义**: “复象”指同一个`天将`、`月将`或`地支`在四课三传中出现多次。\n"
         @"*   **识别规则**: 扫描四课三传，统计相同符号的出现次数。\n"
         @"*   **解读逻辑**:\n"
         @"    1.  **数量映射**: 符号出现的次数可以直接映射为现实中的数量。\n"
         @"        *   **案例映射**: `例1`（王县丞占病），四个`午`对应四个儿子。`例4`（毒狗案），三个`玄武`对应盗贼来了三次（投毒一次，行窃两次）。\n"
         @"    2.  **频率映射**: 符号的重复出现可以表示事件的【反复发生】或【多重阶段】。\n"
         @"        *   **案例映射**: `例2`（投标案），出现两个`午`火子孙，被解读为需要【两次救应】（一次中标，一次解决发难）。\n"
         @"    3.  **参与方映射**: 符号的重复可以代表【多方参与】。\n"
         @"        *   **案例映射**: `例2`（打麻将案），三传皆土，对应“四人”之象。\n"
         @"    4.  **强度映射**: 吉神或凶神的重复出现，代表其能量的叠加与增强。`贵人多现`（贵人遍地）反而因力量分散而无助，是此逻辑的特殊辩证。\n"
         @"\n"
         @"*   **【执行指令】**: 当检测到复象时，必须激活【定量分析模块】，在定性判断之外，增加关于“数量”、“次数”、“人数”的量化预测。\n"
         @"---\n"
         @"### **Chapter 17: 信息深度挖掘层 (一字多象)**\n"
         @"#### `协议定位`: 此为【信息深度挖掘层】。任何一个六壬符号本质上都是一个【多维信息压缩包】。本协议旨在将单一符号在【不同维度】（六亲、神将、神煞、长生宫、字形音义等）的象意同时激活，并进行交叉组合，以榨取出最细腻、最丰富的现实信息。\n"
         @"*   **核心定义**: 一个符号（如`申`），在同一课盘中，同时是`官鬼`、是`白虎`、是`驿马`、是`长生`、是`传送`。这些身份【同时有效，必须同时解读】。\n"
         @"*   **执行流程**:\n"
         @"    1.  **多维身份扫描**: 对核心符号进行全方位扫描，罗列其在本课盘中承载的所有身份标签。\n"
         @"    2.  **象意矩阵构建**: 将每个身份标签对应的核心象意一一列出，形成一个象意矩阵。\n"
         @"    3.  **情境融合与叙事编织**: 在用户所问的情境下，寻找一条能够将矩阵中【最多象意】合理地、无矛盾地串联起来的【高保真叙事】。\n"
         @"*   **【执行指令】**: 严禁【选择性取象】。分析师的任务不是从众多象意中挑选一个最方便的，而是构建一个能够【同时容纳】多个、甚至矛盾象意的复杂现实场景。\n"
         @"*   **案例映射**: `例1`（壬戌女测感情），`申`同时是：\n"
         @"    *   `官鬼` -> 夫星。\n"
         @"    *   `贵人` -> 尊长。\n"
         @"    *   `空亡` -> 虚无、不在。\n"
         @"    *   `申在坤宫` -> 母亲。\n"
         @"    *   `死气午上` -> 状态不佳。\n"
         @"    *   **【综合叙事】**: 占问丈夫之事(`官鬼`)，此事虚而不实(`空亡`)、。同时，此象还指向一位女性长辈(`贵人`+`坤宫`=母亲)，其状态已逝(`坐死气`+`空亡`)。—— 最终应验为“离婚”与“母亡”，两个看似无关的事件被同一个符号`申`所揭示。\n"
         @"```\n"; }

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
    NSString *footerText = [NSString stringWithFormat:@"\n//-------------------【情报需求】-------------------\n\n//**【问题 (用户原始输入)】**\n// %@\n\n", userQuestion];
    return [NSString stringWithFormat:@"%@%@%@%@", headerPrompt, structuredReport, summaryLine, footerText];
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
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; g_questionTextView = nil; g_clearInputButton = nil; }];
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
    NSString *benMingTitle = [NSString stringWithFormat:@"本命: %@", g_shouldExtractBenMing ? @"开启" : @"关闭"];
    UIColor *benMingColor = g_shouldExtractBenMing ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
    UIButton *benMingButton = createButton(benMingTitle, @"person.text.rectangle", kButtonTag_BenMingToggle, benMingColor);
    benMingButton.frame = CGRectMake(startX + compactBtnWidth + innerPadding, currentY, compactBtnWidth, compactButtonHeight);
    benMingButton.selected = g_shouldExtractBenMing; [contentView addSubview:benMingButton];
    currentY += compactButtonHeight + 15;
    UIView *textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 110)];
    textViewContainer.backgroundColor = ECHO_COLOR_CARD_BG; textViewContainer.layer.cornerRadius = 12; [contentView addSubview:textViewContainer];
    g_questionTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, 0, textViewContainer.bounds.size.width - 2*padding - 40, 110)];
    g_questionTextView.backgroundColor = [UIColor clearColor]; g_questionTextView.textColor = [UIColor lightGrayColor]; g_questionTextView.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular]; g_questionTextView.textContainerInset = UIEdgeInsetsMake(10, 0, 10, 0); g_questionTextView.text = @"选填：输入您想问的具体问题"; g_questionTextView.delegate = (id<UITextViewDelegate>)self; g_questionTextView.returnKeyType = UIReturnKeyDone; [textViewContainer addSubview:g_questionTextView];
    g_clearInputButton = [UIButton buttonWithType:UIButtonTypeSystem];
    if (@available(iOS 13.0, *)) { [g_clearInputButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal]; }
    g_clearInputButton.frame = CGRectMake(textViewContainer.bounds.size.width - padding - 25, 10, 25, 25);
    g_clearInputButton.tintColor = [UIColor grayColor]; g_clearInputButton.tag = kButtonTag_ClearInput; g_clearInputButton.alpha = 0;
    [g_clearInputButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside]; [textViewContainer addSubview:g_clearInputButton];
    currentY += 110 + 20;
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
    SEL action = ([title containsString:@"天将"]) ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳天將摘要WithSender:");
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
- (NSString *)_echo_extractSanChuanInfo { Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); if (!sanChuanViewClass) return @""; NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSArray *titles = @[@"初传", @"中传", @"末传"]; NSMutableArray *lines = [NSMutableArray array]; NSArray<NSString *> *shenShaWhitelist = @[@"日禄", @"太岁", @"旬空", @"日马", @"旬丁" , @"坐空"]; for (NSUInteger i = 0; i < scViews.count; i++) { UIView *v = scViews[i]; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if (labels.count >= 3) { NSString *lq = [[(UILabel*)labels.firstObject text] stringByReplacingOccurrencesOfString:@"->" withString:@""]; NSString *tj = [(UILabel*)labels.lastObject text]; NSString *dz = [(UILabel*)[labels objectAtIndex:labels.count - 2] text]; NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for (UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count - 3)]) { if (l.text.length > 0) [ssParts addObject:l.text]; } } NSMutableArray *filteredSsParts = [NSMutableArray array]; for (NSString *part in ssParts) { for (NSString *keyword in shenShaWhitelist) { if ([part containsString:keyword]) { [filteredSsParts addObject:part]; break; } } } NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"%lu传", (unsigned long)i+1]; if (filteredSsParts.count > 0) { [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@) [状态: %@]", title, SafeString(dz), SafeString(lq), SafeString(tj), [filteredSsParts componentsJoinedByString:@", "]]]; } else { [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@)", title, SafeString(dz), SafeString(lq), SafeString(tj)]]; } } } return [lines componentsJoinedByString:@"\n"]; }
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator { Class targetViewClass = NSClassFromString(className); if (!targetViewClass) return @""; NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews); if (targetViews.count == 0) return @""; UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text.length > 0) { [textParts addObject:label.text]; } } return [textParts componentsJoinedByString:separator]; }
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























