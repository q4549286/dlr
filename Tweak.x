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

static NSString* parseAndFilterFangFaBlock(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSMutableString *workingContent = [rawContent mutableCopy];
NSArray<NSString *> *blockRemovalMarkers = @[
    @"发用事端→", // <-- 新增这一行
    @"三传事体→",
    @"日辰关系→",
    @"日辰上乘"
];
for (NSString *marker in blockRemovalMarkers) {
        NSRange markerRange = [workingContent rangeOfString:marker];
        if (markerRange.location != NSNotFound) { workingContent = [[workingContent substringToIndex:markerRange.location] mutableCopy]; }
    }
    NSArray<NSString *> *boilerplateSentences = @[ @"凡看来情，以占之正时，详其与日之生克刑合，则于所占事体，可先有所主，故曰先锋门。", @"此以用神所乘所临，以及与日之生合刑墓等断事发之机。", @"此以三传之进退顺逆、有气无气、顺生逆克等而定事情之大体。", @"此以日辰对较而定主客彼我之关系，大体日为我，辰为彼；日为人，辰为宅；日为尊，辰为卑；日为老，辰为幼；日为夫，辰为妻；日为官，辰为民；出行则日为陆为车，辰则为水为舟；日为出，为南向，为前方，辰则为入，为北向，为后方；占病则以日为人，以辰为病；占产则以日为子，以辰为母；占农则以日为农夫，以辰为谷物；占猎则以日为猎师，以辰为鸟兽。故日辰之位，随占不同，总要依类而推之，方无差谬。", @"此以用神之旺相并天乙前后断事情之迟速，并以用神所合之岁月节候而定事体之远近，复以天上季神所临定成事之期。" ];
    for (NSString *sentence in boilerplateSentences) { [workingContent replaceOccurrencesOfString:sentence withString:@"" options:0 range:NSMakeRange(0, workingContent.length)]; }
    NSArray<NSString *> *conclusionPatterns = @[ @"(主|恐|利|不利|则|此主|凡事|又当|故当|当以|大有生意|凶祸更甚|凶祸消磨|其势悖逆|用昼将|唯不利|岁无成|而不能由己|可致福禄重重|情多窒且塞|事虽顺而有耗散之患|生归日辰则无虞|理势自然).*?($|。|，)", @"(^|，|。)\\s*(主|恐|利|不利|则|此主|凡事|又当|故当|当以|不堪期|却无气|事虽新起)[^，。]*" ];
    for (NSString *pattern in conclusionPatterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil]; NSString *previous;
        do { previous = [workingContent copy]; [regex replaceMatchesInString:workingContent options:0 range:NSMakeRange(0, workingContent.length) withTemplate:@""]; }
        while (![previous isEqualToString:workingContent]);
    }
    [workingContent replaceOccurrencesOfString:@"\n" withString:@" " options:0 range:NSMakeRange(0, workingContent.length)];
    NSArray *conjunctionsToRemove = @[@"但", @"又，"];
    for (NSString *conj in conjunctionsToRemove) { [workingContent replaceOccurrencesOfString:[NSString stringWithFormat:@"%@ ", conj] withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, workingContent.length)]; }
    while ([workingContent containsString:@"  "]) { [workingContent replaceOccurrencesOfString:@"  " withString:@" " options:0 range:NSMakeRange(0, workingContent.length)]; }
    [workingContent replaceOccurrencesOfString:@"\\s*([，。])\\s*" withString:@"$1" options:NSRegularExpressionSearch range:NSMakeRange(0, workingContent.length)];
    [workingContent replaceOccurrencesOfString:@"[，。]{2,}" withString:@"。" options:NSRegularExpressionSearch range:NSMakeRange(0, workingContent.length)];
    if ([workingContent hasPrefix:@"，"] || [workingContent hasPrefix:@"。"]) { if(workingContent.length > 0) [workingContent deleteCharactersInRange:NSMakeRange(0, 1)]; }
    NSArray<NSString *> *finalSentences = [[workingContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsSeparatedByString:@"。"];
    NSMutableString *finalResult = [NSMutableString string];
    for (NSString *sentence in finalSentences) {
        NSString *trimmedSentence = [sentence stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,，"]];
        if (trimmedSentence.length > 0) { [finalResult appendFormat:@"%@。\n", trimmedSentence]; }
    }
    return [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
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

static NSString* parseKeChuanDetailBlock(NSString *rawText, NSString *objectTitle) {
    if (!rawText || rawText.length == 0) return @"";
    NSMutableString *structuredResult = [NSMutableString string]; NSArray<NSString *> *lines = [rawText componentsSeparatedByString:@"\n"]; NSMutableArray<NSString *> *processedLines = [NSMutableArray array];
    BOOL isTianJiangObject = (objectTitle && [objectTitle containsString:@"天将"]);
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0 || [processedLines containsObject:trimmedLine]) continue;
        if (objectTitle && [objectTitle containsString:@"日干"]) {
            NSRegularExpression *riGanWangshuaiRegex = [NSRegularExpression regularExpressionWithPattern:@"寄(.)得([^，。]*)" options:0 error:nil];
            NSTextCheckingResult *riGanMatch = [riGanWangshuaiRegex firstMatchInString:trimmedLine options:0 range:NSMakeRange(0, trimmedLine.length)];
            if (riGanMatch && [structuredResult rangeOfString:@"日干旺衰:"].location == NSNotFound) {
                NSString *jiChen = [trimmedLine substringWithRange:[riGanMatch rangeAtIndex:1]];
                NSString *deQi   = [[trimmedLine substringWithRange:[riGanMatch rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                [structuredResult appendFormat:@"  - 日干旺衰: %@ (因寄%@)\n", deQi, jiChen];
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
    NSDictionary<NSString *, NSString *> *keywordMap = @{ @"乘": @"乘将关系", @"临": @"临宫状态", @"遁干": @"遁干A+", @"德 :": @"德S+", @"空 :": @"空A+",  @"墓 :": @"墓A+",@"合 :": @"合A+", @"刑 :": @"刑C-", @"冲 :": @"冲B+", @"害 :": @"害C-", @"破 :": @"破D", @"阳神为": @"阳神A+", @"阴神为": @"阴神A+", @"杂象": @"杂象B+", };
    BOOL inZaxiang = NO;
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0 || [processedLines containsObject:trimmedLine]) continue;
        if (inZaxiang) { [structuredResult appendFormat:@"    - %@\n", trimmedLine]; [processedLines addObject:trimmedLine]; continue; }
        for (NSString *keyword in keywordMap.allKeys) {
            if ([trimmedLine hasPrefix:keyword]) {
                NSString *value = extractValueAfterKeyword(trimmedLine, keyword); NSString *label = keywordMap[keyword];
                if ([label isEqualToString:@"遁干A+"]) { value = [[[[value stringByReplacingOccurrencesOfString:@"初建:" withString:@"遁干:"]
                   stringByReplacingOccurrencesOfString:@"复建:" withString:@"遁时:"]
                   stringByReplacingOccurrencesOfString:@"丁" withString:@"丁神"]
                   stringByReplacingOccurrencesOfString:@"癸" withString:@"闭口"];}
                NSRegularExpression *conclusionRegex = [NSRegularExpression regularExpressionWithPattern:@"(，|。|\\s)(此主|主|此为|此曰|故|实难|不宜|恐|凡事|进退有悔|百事不顺|其吉可知|其凶可知).*$" options:0 error:nil];
                value = [conclusionRegex stringByReplacingMatchesInString:value options:0 range:NSMakeRange(0, value.length) withTemplate:@""];
                if ([label hasPrefix:@"刑"] || [label hasPrefix:@"冲"] || [label hasPrefix:@"害"] || [label hasPrefix:@"破"]) { NSArray *parts = [value componentsSeparatedByString:@" "]; if (parts.count > 0) value = parts[0]; }
                if ([label hasPrefix:@"杂象"]) { inZaxiang = YES; }
                value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" ,，。"]];
                if (value.length > 0) {
                     if ([label isEqualToString:@"杂象B+"]) { [structuredResult appendString:@"  - 杂象(只参与取象禁止对吉凶产生干涉):\n"]; }
                     else { [structuredResult appendFormat:@"  - %@: %@\n", label, value]; }
                }
                [processedLines addObject:trimmedLine]; break;
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
static NSString* _parseTianJiangDetailInternal(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSArray<NSString *> *lines = [rawContent componentsSeparatedByString:@"\n"];
    NSMutableString *result = [NSMutableString string];
    if (lines.count > 0) { [result appendFormat:@"%@\n", lines[0]]; }
    NSArray *keywords = @[@"乘", @"临", @"阳神为", @"阴神为"];
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        BOOL isObjectiveFact = NO;
        for (NSString *key in keywords) { if ([trimmedLine hasPrefix:key]) { isObjectiveFact = YES; break; } }
        if (isObjectiveFact) {
            NSRange conclusionRange = [trimmedLine rangeOfString:@"。"];
            NSString *cleanLine = (conclusionRange.location != NSNotFound) ? [trimmedLine substringToIndex:conclusionRange.location] : trimmedLine;
            [result appendFormat:@"- %@\n", cleanLine];
        }
    }
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// 新增的上神详情专属解析器
static NSString* _parseShangShenDetailInternal(NSString *rawContent) {
    if (!rawContent || rawContent.length == 0) return @"";
    NSArray<NSString *> *lines = [rawContent componentsSeparatedByString:@"\n"];
    NSMutableString *result = [NSMutableString string];
    NSArray *blacklist = @[@"神象", @"诗象", @"星宿", @"禽类", @"身象", @"人类", @"物类", @"方所", @"事类", @"数象"];
    BOOL isFirstTextualLine = YES;
    for (NSString *line in lines) {
        NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmedLine.length == 0) continue;
        BOOL isBlacklisted = NO;
        for (NSString *key in blacklist) { if ([trimmedLine hasPrefix:key]) { isBlacklisted = YES; break; } }
        if (isBlacklisted) continue;
        // 修正逻辑：只移除第一行且不包含特定字符的行
        if (isFirstTextualLine) {
            isFirstTextualLine = NO; // 只判断一次
            // 判断是否是纯描述性文字
            if (![trimmedLine containsString:@"("] && ![trimmedLine containsString:@" "] && ![trimmedLine containsString:@":"]) {
                continue;
            }
        }
        if ([trimmedLine hasPrefix:@"一、"] || [trimmedLine hasPrefix:@"二、"]) continue;
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
static NSString *getAIPromptHeader() { return @"# 【四经合一 · 终极统一场论】\n\n-----标准化课盘-----\n"; }

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
    [report appendFormat:@"// 1.2. 核心参数\n- 月将: %@\n- 旬空: %@ (%@)\n- 昼夜贵人: %@\n\n", [yueJiang stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], kong, xun, SafeString(reportData[@"昼夜"])];

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
    // 将 type 改为 EchoDataTypeGeneric
    @{ @"key": @"天地盘详情", @"title": @"天地盘全息情报", @"type": @(EchoDataTypeGeneric)}, 
        @{ @"key": @"九宗门_详", @"title": @"格局总览 (九宗门)", @"type": @(EchoDataTypeJiuZongMen)},
        @{ @"key": @"行年参数", @"title": @"模块二：【天命系统】 - A级情报", @"type": @(EchoDataTypeNianming)},
        @{ @"key": @"神煞详情", @"title": @"神煞系统", @"type": @(EchoDataTypeShenSha)},
   //     @{ @"key": @"七政四余", @"title": @"辅助系统", @"type": @(EchoDataTypeQiZheng)},
   //     @{ @"key": @"三宫时信息", @"title": @"辅助系统", @"type": @(EchoDataTypeSanGong), @"isSubSection": @YES},
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
        LogMessage(EchoLogTypeSuccess, @"完成: 所有天地盘详情提取完毕。");
// [修复点 1: 在合并前逐个解析天地盘详情]
NSMutableString *finalReport = [NSMutableString string];
for (NSUInteger i = 0; i < g_tianDiPan_fixedCoordinates.count; i++) {
    NSDictionary *itemInfo = g_tianDiPan_fixedCoordinates[i];
    NSString *itemName = itemInfo[@"name"];
    NSString *itemType = [itemInfo[@"type"] isEqualToString:@"tianJiang"] ? @"天将详情" : @"上神详情";
    NSString *rawItemData = (i < g_tianDiPan_resultsArray.count) ? g_tianDiPan_resultsArray[i] : @"[数据提取失败]";
    
    // 在这里，对每一块原始数据调用解析器！
    NSString *parsedItemData = parseTianDiPanDetailBlock(rawItemData);
    
    // 使用解析后的数据来构建报告
    [finalReport appendFormat:@"-- [%@: %@] --\n%@\n\n", itemType, itemName, parsedItemData];
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
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion { if (g_s2_isExtractingKeChuanDetail) return; LogMessage(EchoLogTypeTask, @"[任务启动] 开始推演“课传流注”..."); [self showProgressHUD:@"正在推演课传流注..."]; g_s2_isExtractingKeChuanDetail = YES; g_s2_keChuan_completion_handler = [completion copy]; g_s2_capturedKeChuanDetailArray = [NSMutableArray array]; g_s2_keChuanWorkQueue = [NSMutableArray array]; g_s2_keChuanTitleQueue = [NSMutableArray array]; Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳"); if (!keChuanContainerIvar) { g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; } id keChuanContainer = object_getIvar(self, keChuanContainerIvar); if (!keChuanContainer) { g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; } Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖"); NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults); if (sanChuanResults.count > 0) { UIView *sanChuanContainer = sanChuanResults.firstObject; const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"}; for (int i = 0; ivarNames[i] != NULL; ++i) { Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue; UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; if(labels.count >= 2) { UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1]; if (dizhiLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]]; } if (tianjiangLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]]; } } } } Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖"); NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults); if (siKeResults.count > 0) { UIView *siKeContainer = siKeResults.firstObject; NSArray *keDefs = @[ @{@"ivar": @"日", @"title": @"日干"}, @{@"ivar": @"日上", @"title": @"日上"}, @{@"ivar": @"日上天將", @"title": @"日上 - 天将"}, @{@"ivar": @"日陰", @"title": @"日阴"}, @{@"ivar": @"日陰天將", @"title": @"日阴 - 天将"}, @{@"ivar": @"辰", @"title": @"支辰"}, @{@"ivar": @"辰上", @"title": @"辰上"}, @{@"ivar": @"辰上天將", @"title": @"辰上 - 天将"}, @{@"ivar": @"辰陰", @"title": @"辰阴"}, @{@"ivar": @"辰陰天將", @"title": @"辰阴 - 天将"} ]; for (NSDictionary *def in keDefs) { Ivar ivar = class_getInstanceVariable(siKeContainerClass, [def[@"ivar"] UTF8String]); if (ivar) { UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar); if (label && label.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject} mutableCopy]]; if ([def[@"title"] containsString:@"天将"]) { [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@(%@)", def[@"title"], label.text]]; } else { [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", def[@"title"], label.text]]; } } } } } if (g_s2_keChuanWorkQueue.count == 0) { g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; g_s2_finalResultFromKeChuan = @""; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); return; } [self processKeChuanQueue_Truth_S2]; }
%new
- (void)processKeChuanQueue_Truth_S2 { if (!g_s2_isExtractingKeChuanDetail || g_s2_keChuanWorkQueue.count == 0) { if (g_s2_isExtractingKeChuanDetail) { NSMutableString *resultStr = [NSMutableString string]; if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) { for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) { NSString *title = g_s2_keChuanTitleQueue[i]; NSString *rawBlock = g_s2_capturedKeChuanDetailArray[i]; NSString *structuredBlock = parseKeChuanDetailBlock(rawBlock, title); [resultStr appendFormat:@"- 对象: %@\n%@\n\n", title, structuredBlock]; } g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (!g_s2_keChuan_completion_handler) { NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"课传详解"] = g_s2_finalResultFromKeChuan; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [self showEchoNotificationWithTitle:@"推衍完成" message:@"课盘已生成并复制到剪贴板"]; [self presentAIActionSheetWithReport:finalReport]; } } else { g_s2_finalResultFromKeChuan = @"[错误: 课传流注解析数量不匹配]"; } } g_s2_isExtractingKeChuanDetail = NO; g_s2_capturedKeChuanDetailArray = nil; g_s2_keChuanWorkQueue = nil; g_s2_keChuanTitleQueue = nil; [self hideProgressHUD]; if (g_s2_keChuan_completion_handler) { g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; } return; } NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject; [g_s2_keChuanWorkQueue removeObjectAtIndex:0]; NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count]; [self updateProgressHUD:[NSString stringWithFormat:@"推演课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]]; SEL action = ([title containsString:@"天将"]) ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:"); if ([self respondsToSelector:action]) { SUPPRESS_LEAK_WARNING([self performSelector:action withObject:task[@"gesture"]]); } else { [g_s2_capturedKeChuanDetailArray addObject:@"[解析失败: 方法不存在]"]; [self processKeChuanQueue_Truth_S2]; } }
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
- (NSString *)_echo_extractSiKeInfo { Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖"); if (!siKeViewClass) return @""; NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews); if (siKeViews.count == 0) return @""; UIView *container = siKeViews.firstObject; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels); if (labels.count < 12) return @""; NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for (UILabel *label in labels) { NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if (!cols[key]) { cols[key] = [NSMutableArray array]; } [cols[key] addObject:label]; } if (cols.allKeys.count != 4) return @""; NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }]; NSMutableArray *c1 = cols[keys[0]], *c2 = cols[keys[1]], *c3 = cols[keys[2]], *c4 = cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }]; NSString *k1_shang = ((UILabel*)c4[0]).text, *k1_jiang = ((UILabel*)c4[1]).text, *k1_xia = ((UILabel*)c4[2]).text; NSString *k2_shang = ((UILabel*)c3[0]).text, *k2_jiang = ((UILabel*)c3[1]).text, *k2_xia = ((UILabel*)c3[2]).text; NSString *k3_shang = ((UILabel*)c2[0]).text, *k3_jiang = ((UILabel*)c2[1]).text, *k3_xia = ((UILabel*)c2[2]).text; NSString *k4_shang = ((UILabel*)c1[0]).text, *k4_jiang = ((UILabel*)c1[1]).text, *k4_xia = ((UILabel*)c1[2]).text; return [NSString stringWithFormat:@"- 第一课(日干): %@ 上 %@，%@乘%@\n- 第二课(日上): %@ 上 %@，%@乘%@\n- 第三课(支辰): %@ 上 %@，%@乘%@\n- 第四课(辰上): %@ 上 %@，%@乘%@", SafeString(k1_xia), SafeString(k1_shang), SafeString(k1_shang), SafeString(k1_jiang), SafeString(k2_xia), SafeString(k2_shang), SafeString(k2_shang), SafeString(k2_jiang), SafeString(k3_xia), SafeString(k3_shang), SafeString(k3_shang), SafeString(k3_jiang), SafeString(k4_xia), SafeString(k4_shang), SafeString(k4_shang), SafeString(k4_jiang) ]; }
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




