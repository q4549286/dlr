#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

// =========================================================================
// 1. 全局变量、常量定义与辅助函数
// =========================================================================

#pragma mark - Constants & Colors
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

// Colors
#define ECHO_COLOR_MAIN_BLUE        [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0] // #2B4F81
#define ECHO_COLOR_MAIN_TEAL        [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0] // #3A7D7C
#define ECHO_COLOR_AUX_GREY         [UIColor colorWithWhite:0.3 alpha:1.0]
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
static BOOL g_s1_isExtracting = NO;
static NSString *g_s1_currentTaskType = nil;
static BOOL g_s1_shouldIncludeXiangJie = NO;
static NSMutableArray *g_s1_keTi_workQueue = nil;
static NSMutableArray *g_s1_keTi_resultsArray = nil;
static UICollectionView *g_s1_keTi_targetCV = nil;
static void (^g_s1_completion_handler)(NSString *result) = nil;
static BOOL g_s2_isExtractingKeChuanDetail = NO;
static NSMutableArray *g_s2_capturedKeChuanDetailArray = nil;
static NSMutableArray<NSMutableDictionary *> *g_s2_keChuanWorkQueue = nil;
static NSMutableArray<NSString *> *g_s2_keChuanTitleQueue = nil;
static NSString *g_s2_finalResultFromKeChuan = nil;
static void (^g_s2_keChuan_completion_handler)(void) = nil;
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;
static NSString *g_lastGeneratedReport = nil;

// UI State
static BOOL g_shouldIncludeAIPromptHeader = YES;
static BOOL g_isExtractingTimeInfo = NO;
static UITextView *g_questionTextView = nil;
static UIButton *g_clearInputButton = nil;


#define SafeString(str) (str ?: @"")

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

#pragma mark - AI Report Generation
static NSString *getAIPromptHeader() {
return          @"## I/O 标准化协议 V16.0\n"
         
         @"**以下是包含所有细节的标准化课盘，我将执行全新架构下的专业深度分析！**\n";}


static NSString* generateStructuredReport(NSDictionary *reportData) {
    NSMutableString *report = [NSMutableString string];
    __block NSInteger sectionCounter = 4;

    // vvvvvvvvvvvvvv 日干十二长生数据与计算引擎 v3.2 vvvvvvvvvvvvvvvvvv
    NSDictionary *tianGanToWuxing = @{ @"甲": @"木", @"乙": @"木", @"丙": @"火", @"丁": @"火", @"戊": @"土", @"己": @"土", @"庚": @"金", @"辛": @"金", @"壬": @"水", @"癸": @"水" };
    NSArray *changShengStates = @[@"长生", @"沐浴", @"冠带", @"临官(禄)", @"羊刃", @"衰", @"病", @"死", @"墓", @"绝", @"胎神", @"养"];
    NSDictionary *wuxingChangShengStart = @{ @"木":@"亥", @"火":@"寅", @"金":@"巳", @"水":@"申", @"土":@"申" };
    NSArray *dizhiOrder = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
    NSDictionary* (^generateRiGanChangShengMap)(NSString*) = ^NSDictionary*(NSString *riGan) {
        if (!riGan || riGan.length == 0 || !tianGanToWuxing[riGan]) return @{};
        NSString *wuxing = tianGanToWuxing[riGan];
        NSString *startDiZhi = wuxingChangShengStart[wuxing];
        if (!startDiZhi) return @{};
        NSUInteger startIndex = [dizhiOrder indexOfObject:startDiZhi];
        NSMutableDictionary *map = [NSMutableDictionary dictionary];
        for (int i = 0; i < 12; i++) {
            map[dizhiOrder[(startIndex + i) % 12]] = changShengStates[i];
        }
        return [map copy];
    };
    // ^^^^^^^^^^^^^^^^ 日干十二长生数据与计算引擎 v3.2 ^^^^^^^^^^^^^^^^^^^^^

    // 板块一：基础盘元
    [report appendString:@"// 1. 基础盘元\n"];
    NSString *timeBlockFull = SafeString(reportData[@"时间块"]);
    if (timeBlockFull.length > 0) {
        [report appendString:@"// 1.1. 时间参数\n"];
        NSArray *timeLines = [timeBlockFull componentsSeparatedByString:@"\n"];
        for (NSString *line in timeLines) {
            NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (trimmedLine.length > 0) {
                if ([trimmedLine hasPrefix:@"公历"]) {
                    trimmedLine = [trimmedLine stringByReplacingOccurrencesOfString:@"公历" withString:@"公历(北京时间)"];
                } else if ([trimmedLine hasPrefix:@"干支"]) {
                    trimmedLine = [trimmedLine stringByReplacingOccurrencesOfString:@"干支" withString:@"干支(真太阳时)"];
                }
                [report appendFormat:@"- %@\n", trimmedLine];
            }
        }
        [report appendString:@"\n"];
    }
    NSString *yueJiangFull = SafeString(reportData[@"月将"]);
    NSString *yueJiang = [[yueJiangFull componentsSeparatedByString:@" "].firstObject stringByReplacingOccurrencesOfString:@"月将:" withString:@""] ?: @"";
    yueJiang = [yueJiang stringByReplacingOccurrencesOfString:@"日宿在" withString:@""];
    NSString *xunInfo = SafeString(reportData[@"旬空_旬信息"]);
    NSString *riGan = SafeString(reportData[@"旬空_日干"]);
    NSArray<NSString *> *liuQinArray = reportData[@"旬空_六亲数组"];
    NSString *kong = @"", *xun = @"";
    if (xunInfo.length > 0) {
        NSRange bracketStart = [xunInfo rangeOfString:@"("], bracketEnd = [xunInfo rangeOfString:@")"];
        if (bracketStart.location != NSNotFound && bracketEnd.location != NSNotFound && bracketStart.location < bracketEnd.location) {
            xun = [xunInfo substringWithRange:NSMakeRange(bracketStart.location + 1, bracketEnd.location - bracketStart.location - 1)];
            kong = [[xunInfo substringToIndex:bracketStart.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
             NSDictionary *xunKongMap = @{ @"甲子":@"戌亥", @"甲戌":@"申酉", @"甲申":@"午未", @"甲午":@"辰巳", @"甲辰":@"寅卯", @"甲寅":@"子丑" };
            for (NSString* xunKey in xunKongMap.allKeys) {
                if ([xunInfo containsString:xunKey]) {
                    xun = [xunKey stringByAppendingString:@"旬"];
                    NSString *tempKong = [[xunInfo stringByReplacingOccurrencesOfString:xun withString:@""] stringByReplacingOccurrencesOfString:@"空" withString:@""];
                    kong = (tempKong.length > 0) ? [tempKong stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : xunKongMap[xunKey];
                    break;
                }
            }
            if (xun.length == 0) { kong = xunInfo; }
        }
    }
    NSString *formattedDetail = @"";
    if (liuQinArray && liuQinArray.count > 0 && kong.length == liuQinArray.count) {
        NSMutableString *statements = [NSMutableString string];
        for (int i = 0; i < kong.length; i++) {
            [statements appendFormat:@"%@为空亡%@", [kong substringWithRange:NSMakeRange(i, 1)], liuQinArray[i]];
            if (i < kong.length - 1) { [statements appendString:@", "]; }
        }
        formattedDetail = [NSString stringWithFormat:@" [空亡详解: 以日干'%@'论, %@]", riGan, statements];
    }
    [report appendFormat:@"// 1.2. 核心参数\n- 月将: %@\n- 旬空: %@ (%@)%@\n- 昼夜贵人: %@\n\n", [yueJiang stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], kong, xun, formattedDetail, SafeString(reportData[@"昼夜"])];

    // 板块二：核心盘架
    [report appendString:@"// 2. 核心盘架\n"];
    NSString *tianDiPanText = reportData[@"天地盘"];
    if (tianDiPanText) {
        NSMutableString *formattedTianDiPan = [NSMutableString string];
        [formattedTianDiPan appendString:@"// 2.1. 天地盘 (附日干十二长生落宫状态)\n"];
        NSDictionary *riGanChangShengMap = generateRiGanChangShengMap(riGan);
        NSArray *tianDiPanLines = [tianDiPanText componentsSeparatedByString:@"\n"];
        for (NSString *line in tianDiPanLines) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"-\\s*(\\S)宫:\\s*(.*)" options:0 error:nil];
            NSTextCheckingResult *match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
            if (match && [match numberOfRanges] == 3) {
                NSString *diPanGong = [line substringWithRange:[match rangeAtIndex:1]];
                NSString *tianPanContent = [line substringWithRange:[match rangeAtIndex:2]];
                NSString *changShengState = riGanChangShengMap[diPanGong] ?: @"状态未知";
                [formattedTianDiPan appendFormat:@"- %@宫(%@): %@\n", diPanGong, changShengState, tianPanContent];
            } else {
                [formattedTianDiPan appendFormat:@"%@\n", line];
            }
        }
        [report appendFormat:@"%@\n", [formattedTianDiPan stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    NSString *siKeText = reportData[@"四课"];
    NSString *sanChuanText = reportData[@"三传"];
    if (siKeText) [report appendFormat:@"\n// 2.2. 四课\n%@\n\n", siKeText];
    if (sanChuanText) [report appendFormat:@"// 2.3. 三传\n%@\n\n", sanChuanText];

    // 板块三：格局总览
    [report appendString:@"// 3. 格局总览\n"];
    NSString *keTiFull = reportData[@"课体范式_简"] ?: reportData[@"课体范式_详"];
    if (keTiFull.length > 0) {
        [report appendString:@"// 3.1. 课体范式\n"];
        NSArray *keTiBlocks = [keTiFull componentsSeparatedByString:@"\n\n"];
        for (NSString *block in keTiBlocks) { if (block.length > 0) { [report appendFormat:@"- %@\n\n", [block stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]; } }
    }
    NSString *jiuZongMenFull = reportData[@"九宗门_详"] ?: reportData[@"九宗门_简"];
    if (jiuZongMenFull.length > 0) {
        jiuZongMenFull = [jiuZongMenFull stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
        jiuZongMenFull = [jiuZongMenFull stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "];
        [report appendString:@"// 3.2. 九宗门\n"];
        [report appendFormat:@"- %@\n\n", [jiuZongMenFull stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    
    void (^formatKeyValueSection)(NSString*, NSString*) = ^(NSString *title, NSString *key) {
        NSString *content = reportData[key];
        if (content.length > 0) {
            [report appendFormat:@"%@\n", title];
            NSArray *entries = [content componentsSeparatedByString:@"\n"];
            for (NSString *entry in entries) {
                NSArray *parts = [entry componentsSeparatedByString:@"→"];
                if (parts.count >= 2) {
                    [report appendFormat:@"- %@: %@\n", [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], parts[1]];
                }
            }
            [report appendString:@"\n"];
        }
    };
    formatKeyValueSection(@"// 3.3. 毕法要诀", @"毕法要诀");
    formatKeyValueSection(@"// 3.4. 特定格局", @"格局要览");

    // 板块四：爻位详解
    NSMutableString *yaoWeiContent = [NSMutableString string];
    NSString *fangFaFull = reportData[@"解析方法"];
    if (fangFaFull.length > 0) {
        NSDictionary *fangFaMap = @{ @"日辰主客→": @"// 4.1. 日辰关系\n", @"三传事体→": @"// 4.2. 三传事理\n", @"发用事端→": @"// 4.3. 发用详解\n", @"克应之期→": @"// 4.4. 克应之期\n", @"来占之情→": @"// 4.5. 来情占断\n" };
        NSArray *orderedKeys = @[@"日辰主客→", @"三传事体→", @"发用事端→", @"克应之期→", @"来占之情→"];
        for (NSString *key in orderedKeys) {
            NSRange range = [fangFaFull rangeOfString:key];
            if (range.location != NSNotFound) {
                NSMutableString *content = [[fangFaFull substringFromIndex:range.location + range.length] mutableCopy];
                NSRange nextKeyRange = NSMakeRange(NSNotFound, 0);
                for (NSString *nextKey in orderedKeys) {
                    if (![nextKey isEqualToString:key]) {
                        NSRange tempRange = [content rangeOfString:nextKey];
                        if (tempRange.location != NSNotFound && (nextKeyRange.location == NSNotFound || tempRange.location < nextKeyRange.location)) {
                            nextKeyRange = tempRange;
                        }
                    }
                }
                if (nextKeyRange.location != NSNotFound) {
                    [content deleteCharactersInRange:NSMakeRange(nextKeyRange.location, content.length - nextKeyRange.location)];
                }
                [yaoWeiContent appendFormat:@"%@%@\n\n", fangFaMap[key], [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            }
        }
    }

    NSString *keChuanDetail = reportData[@"课传详解"];
    if (keChuanDetail.length > 0) {
        [yaoWeiContent appendString:@"// 4.6. 神将详解 (课传流注)\n"];
        [yaoWeiContent appendString:keChuanDetail];
        [yaoWeiContent appendString:@"\n"];
    }

    if (yaoWeiContent.length > 0) {
        while ([yaoWeiContent hasSuffix:@"\n\n"]) {
            [yaoWeiContent deleteCharactersInRange:NSMakeRange(yaoWeiContent.length - 1, 1)];
        }
        [report appendString:@"// 4. 爻位详解\n"];
        [report appendString:yaoWeiContent];
        [report appendString:@"\n"];
    }

    NSArray<NSDictionary *> *optionalSections = @[
        @{@"key": @"行年参数", @"title": @"行年参数", @"content": SafeString(reportData[@"行年参数"])},
        @{@"key": @"神煞详情", @"title": @"神煞系统", @"content": SafeString(reportData[@"神煞详情"]), @"prefix": @"// 本模块提供所有相关神煞信号，但其最终解释权从属于【信号管辖权与关联度终审协议】。请结合核心议题进行批判性审查。\n"},
        @{@"key": @"辅助系统", @"title": @"辅助系统", @"content": @"COMPOSITE_SECTION_PLACEHOLDER"}
    ];

    for (NSDictionary *sectionInfo in optionalSections) {
        NSString *content = sectionInfo[@"content"];
        if ([content isEqualToString:@"COMPOSITE_SECTION_PLACEHOLDER"]) {
            NSMutableString *auxiliaryContent = [NSMutableString string];
            NSInteger subSectionCounter = 0;
            NSString *qiZheng = reportData[@"七政四余"];
            if (qiZheng.length > 0) {
                subSectionCounter++;
                [auxiliaryContent appendFormat:@"// %ld.%ld. 七政四余\n%@\n\n", (long)(sectionCounter + 1), (long)subSectionCounter, qiZheng];
                NSMutableString *keyPlanetTips = [NSMutableString string];
                NSDictionary *planetToDeity = @{@"水星": @"天后", @"土星": @"天空", @"火星":@"朱雀", @"金星":@"太阴", @"木星":@"太常"};
                for(NSString *line in [qiZheng componentsSeparatedByString:@"\n"]) {
                    for(NSString *planet in planetToDeity.allKeys) {
                        if([line hasPrefix:planet]) {
                            NSScanner *scanner = [NSScanner scannerWithString:line]; NSString *palace;
                            [scanner scanUpToString:@"宫" intoString:NULL];
                            if(scanner.scanLocation > 0 && scanner.scanLocation <= line.length) {
                                [scanner setScanLocation:scanner.scanLocation - 1];
                                [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "] intoString:&palace];
                                if (palace.length > 0 && [[report copy] containsString:palace]) {
                                     [keyPlanetTips appendFormat:@"- %@(%@): 正在%@宫%@。对应神将`%@`。请关注%@宫相关事宜。\n", planet, ([line containsString:@"逆行"]?@"逆":@"顺"), palace, ([line containsString:@"逆行"]?@"逆行":@"顺行"), planetToDeity[planet], palace];
                                }
                            }
                            break;
                        }
                    }
                }
                if (keyPlanetTips.length > 0) {
                    [auxiliaryContent appendString:@"// 关键星曜提示\n"];
                    [auxiliaryContent appendString:keyPlanetTips];
                    [auxiliaryContent appendString:@"\n"];
                }
            }
            NSString *sanGong = reportData[@"三宫时信息"];
            if (sanGong.length > 0) {
                subSectionCounter++;
                [auxiliaryContent appendFormat:@"// %ld.%ld. 三宫时信息\n%@\n\n", (long)(sectionCounter + 1), (long)subSectionCounter, sanGong];
            }
            content = [auxiliaryContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        
        if ([sectionInfo[@"key"] isEqualToString:@"神煞详情"]) {
            NSMutableString *formattedShenSha = [NSMutableString string];
            NSArray *lines = [content componentsSeparatedByString:@"\n"];
            for (NSString *line in lines) {
                NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([trimmedLine hasPrefix:@"//"]) {
                    [formattedShenSha appendFormat:@"%@\n", trimmedLine];
                } else if (trimmedLine.length > 0) {
                    NSArray *items = [trimmedLine componentsSeparatedByString:@"|"];
                    NSMutableString *rowString = [NSMutableString string];
                    NSInteger lineCharCount = 0;
                    for (int i = 0; i < items.count; ++i) {
                        NSString *item = [items[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (lineCharCount + item.length > 35 && lineCharCount > 0) {
                            [rowString appendString:@"\n  "];
                            lineCharCount = 0;
                        }
                        [rowString appendString:item];
                        lineCharCount += item.length + 2;
                        if ((i + 1) < items.count) {
                            [rowString appendString:@", "];
                        }
                    }
                    [formattedShenSha appendFormat:@"- %@\n", rowString];
                }
            }
            content = [formattedShenSha stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }

        if (content.length > 0) {
            sectionCounter++;
            [report appendFormat:@"// %ld. %@\n", (long)sectionCounter, sectionInfo[@"title"]];
            if (sectionInfo[@"prefix"]) {
                [report appendString:sectionInfo[@"prefix"]];
            }
            [report appendString:content];
            [report appendString:@"\n\n"];
        }
    }

    while ([report hasSuffix:@"\n\n"]) {
        [report deleteCharactersInRange:NSMakeRange(report.length - 1, 1)];
    }

    return [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* generateContentSummaryLine(NSString *fullReport) {
    if (!fullReport || fullReport.length == 0) return @"";
    NSDictionary *keywordMap = @{ 
        @"// 1. 基础盘元": @"基础盘元", @"// 2. 核心盘架": @"核心盘架", 
        @"// 3. 格局总览": @"格局总览", @"// 4. 爻位详解": @"爻位详解", 
        @"// 4.6. 神将详解": @"课传详解", @"// 5. 行年参数": @"行年参数", 
        @"// 6. 神煞系统": @"神煞系统", @"// 7. 辅助系统": @"辅助系统"
    };
    NSMutableArray *includedSections = [NSMutableArray array];
    NSArray *orderedKeys = @[
        @"// 1. 基础盘元", @"// 2. 核心盘架", @"// 3. 格局总览", 
        @"// 4. 爻位详解", @"// 4.6. 神将详解", @"// 5. 行年参数", 
        @"// 6. 神煞系统", @"// 7. 辅助系统"
    ];
    for (NSString *keyword in orderedKeys) {
        if ([fullReport containsString:keyword]) {
            NSString *sectionName = keywordMap[keyword];
            if (![includedSections containsObject:sectionName]) { [includedSections addObject:sectionName]; }
        }
    }
    if (includedSections.count > 0) {
        return [NSString stringWithFormat:@"// 以上内容包含： %@\n", [includedSections componentsJoinedByString:@"、"]];
    }
    return @"";
}

static NSString* formatFinalReport(NSDictionary* reportData) {
    NSString *headerPrompt = g_shouldIncludeAIPromptHeader ? getAIPromptHeader() : @"";
    NSString *structuredReport = generateStructuredReport(reportData);
    NSString *summaryLine = generateContentSummaryLine(structuredReport);
    
    NSString *userQuestion = @"";
    if (g_questionTextView && g_questionTextView.text.length > 0 && ![g_questionTextView.text isEqualToString:@"选填：输入您想问的具体问题"]) {
        userQuestion = g_questionTextView.text;
    }
    NSString *footerText = [NSString stringWithFormat:@"\n\n// 请综合以上所有提供的课盘信息，进行全面且深入的分析，并回答以下问题。\n// 问题：%@", userQuestion];

    if (headerPrompt.length > 0) {
        return [NSString stringWithFormat:@"%@%@\n%@%@", headerPrompt, structuredReport, summaryLine, footerText];
    } else {
        return [NSString stringWithFormat:@"%@\n%@%@", structuredReport, summaryLine, footerText];
    }
}


typedef NS_ENUM(NSInteger, EchoLogType) { EchoLogTypeInfo, EchoLogTypeTask, EchoLogTypeSuccess, EchoLogTypeWarning, EchoLogError };
static void LogMessage(EchoLogType type, NSString *format, ...) {
    if (!g_logTextView) return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
  
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"HH:mm:ss"];
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
        [logLine appendAttributedString:existingText];
        g_logTextView.attributedText = logLine;
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


// =========================================================================
// 2. 接口声明、UI微调与核心Hook
// =========================================================================

@interface UIViewController (EchoAnalysisEngine) <UITextViewDelegate>
- (void)createOrShowMainControlPanel;
- (void)showProgressHUD:(NSString *)text;
- (void)updateProgressHUD:(NSString *)text;
- (void)hideProgressHUD;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)buttonTouchDown:(UIButton *)sender;
- (void)buttonTouchUp:(UIButton *)sender;
- (void)executeSimpleExtraction;
- (void)executeCompositeExtraction;
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *result))completion;
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion;
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
- (void)extractShenShaInfo_CompleteWithCompletion:(void (^)(NSString *result))completion;
- (void)processKeTiWorkQueue_S1;
- (void)processKeChuanQueue_Truth_S2;
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion;
- (void)extractTimeInfoWithCompletion:(void (^)(void))completion;
- (NSString *)extractSwitchedXunKongInfo;
- (NSString *)_echo_extractSiKeInfo;
- (NSString *)_echo_extractSanChuanInfo;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
- (NSString *)GetStringFromLayer:(id)layer;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractQiZheng_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractSanGong_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)setInteractionBlocked:(BOOL)blocked;
@end

%hook UILabel
- (void)setText:(NSString *)text { 
    if (!text) { %orig(text); return; } 
    NSString *newString = nil; 
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; 
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; 
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } 
    if (newString) { %orig(newString); return; } 
    NSMutableString *simplifiedText = [text mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); 
    %orig(simplifiedText); 
}
- (void)setAttributedText:(NSAttributedString *)attributedText { 
    if (!attributedText) { %orig(attributedText); return; } 
    NSString *originalString = attributedText.string; NSString *newString = nil; 
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; 
    } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; 
    } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } 
    if (newString) { 
        NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; 
    } 
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); 
    %orig(finalAttributedText); 
}
%end

static BOOL g_isExtractingBiFa = NO;
static void (^g_biFa_completion)(NSString *) = nil;
static BOOL g_isExtractingGeJu = NO;
static void (^g_geJu_completion)(NSString *) = nil;
static BOOL g_isExtractingFangFa = NO;
static void (^g_fangFa_completion)(NSString *) = nil;
static BOOL g_isExtractingQiZheng = NO;
static void (^g_qiZheng_completion)(NSString *) = nil;
static BOOL g_isExtractingSanGong = NO;
static void (^g_sanGong_completion)(NSString *) = nil;

static NSString* extractFromComplexTableViewPopup(UIView *contentView) {
    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
    if (!tableViewClass) { return @"错误: 找不到 IntrinsicTableView 类"; }
    
    NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
    
    if (tableViews.count > 0) {
        UITableView *tableView = tableViews.firstObject;
        id<UITableViewDataSource> dataSource = tableView.dataSource;
        if (!dataSource) { return @"错误: TableView 没有 dataSource"; }

        NSMutableArray<NSString *> *allEntries = [NSMutableArray array];
        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;

        for (NSInteger section = 0; section < sections; section++) {
            NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
             for (NSInteger row = 0; row < rows; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:indexPath];

                if (cell) {
                    NSMutableArray<UILabel *> *labelsInCell = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                    if (labelsInCell.count > 1) {
                        [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                        NSString *title = [labelsInCell[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        title = [title stringByReplacingOccurrencesOfString:@" 毕法" withString:@""];
                        title = [title stringByReplacingOccurrencesOfString:@" 法诀" withString:@""];
                        title = [title stringByReplacingOccurrencesOfString:@" 格局" withString:@""];
                        title = [title stringByReplacingOccurrencesOfString:@" 方法" withString:@""];

                        NSMutableString *contentText = [NSMutableString string];
                        for(NSUInteger i = 1; i < labelsInCell.count; i++) {
                            if (labelsInCell[i].text.length > 0) {
                                [contentText appendString:labelsInCell[i].text];
                            }
                        }
                        NSString *content = [[contentText stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [allEntries addObject:[NSString stringWithFormat:@"%@→%@", title, content]];

                    } else if (labelsInCell.count == 1) {
                        [allEntries addObject:[labelsInCell[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    }
                }
            }
        }
        return [allEntries componentsJoinedByString:@"\n"];
    }
    return @"错误: 未在弹窗中找到 TableView";
}

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie);
static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_isExtractingTimeInfo) {
        UIViewController *contentVC = nil;
        if ([vcToPresent isKindOfClass:[UINavigationController class]]) {
            UINavigationController *nav = (UINavigationController *)vcToPresent;
            if (nav.viewControllers.count > 0) contentVC = nav.viewControllers.firstObject;
        } else { contentVC = vcToPresent; }
        if (contentVC && [NSStringFromClass([contentVC class]) containsString:@"時間選擇視圖"]) {
            g_isExtractingTimeInfo = NO; vcToPresent.view.alpha = 0.0f; animated = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                UIView *targetView = contentVC.view; NSMutableArray *textViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UITextView class], targetView, textViews);
                NSString *timeBlockText = @"[时间推衍失败: 未找到UITextView]";
                if (textViews.count > 0) { timeBlockText = ((UITextView *)textViews.firstObject).text; }
                if (g_extractedData) { g_extractedData[@"时间块"] = timeBlockText; LogMessage(EchoLogTypeSuccess, @"[时间] 成功参详时间信息。"); }
                [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            };
            Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
            return;
        }
    }
    if (g_s1_isExtracting) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"課體概覽視圖"]) {
            UIView *contentView = vcToPresent.view;
            NSString *extractedText = extractDataFromSplitView_S1(contentView, g_s1_shouldIncludeXiangJie);
            if ([g_s1_currentTaskType isEqualToString:@"KeTi"]) {
                [g_s1_keTi_resultsArray addObject:extractedText];
                LogMessage(EchoLogTypeSuccess, @"[课体] 成功解析“课体范式”第 %lu 项...", (unsigned long)g_s1_keTi_resultsArray.count);
                dispatch_async(dispatch_get_main_queue(), ^{ [self processKeTiWorkQueue_S1]; });
            } else if ([g_s1_currentTaskType isEqualToString:@"JiuZongMen"]) {
                LogMessage(EchoLogTypeSuccess, @"[宗门] 成功解析“九宗门结构”...");
                NSString *finalText = [NSString stringWithFormat:@"%@", extractedText];
                if (g_s1_completion_handler) { g_s1_completion_handler(finalText); }
            }
            return;
        }
    }
   else if (g_s2_isExtractingKeChuanDetail) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) {
            UIView *contentView = vcToPresent.view;
            NSMutableArray<NSDictionary *> *textElements = [NSMutableArray array];
            NSMutableArray *allLabels = [NSMutableArray array];
            FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
            for (UILabel *label in allLabels) {
                UIView *superview = label.superview;
                BOOL isInCell = NO;
                while (superview) {
                    if ([superview isKindOfClass:[UITableViewCell class]]) {
                        isInCell = YES;
                        break;
                    }
                    superview = superview.superview;
                }
                if (!isInCell && label.text.length > 0) {
                    [textElements addObject:@{ @"text": label.text, @"y": @(label.frame.origin.y) }];
                }
            }
            Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
            if (tableViewClass) {
                NSMutableArray *tableViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
                if (tableViews.count > 0) {
                    UITableView *tableView = tableViews.firstObject;
                    id<UITableViewDataSource> dataSource = tableView.dataSource;
                    if (dataSource) {
                        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;
                        for (NSInteger section = 0; section < sections; section++) {
                            NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
                            for (NSInteger row = 0; row < rows; row++) {
                                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                                UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
                                if (cell) {
                                    NSMutableArray *labelsInCell = [NSMutableArray array];
                                    FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                                    [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
                                    NSMutableArray<NSString *> *cellTextParts = [NSMutableArray array];
                                    for(UILabel *l in labelsInCell) {
                                        if(l.text.length > 0) [cellTextParts addObject:l.text];
                                    }
                                    NSString *fullCellText = [cellTextParts componentsJoinedByString:@" "];
                                    [textElements addObject:@{ @"text": fullCellText, @"y": @(cell.frame.origin.y + tableView.frame.origin.y) }];
                                }
                            }
                        }
                    }
                }
            }
            [textElements sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
                return [obj1[@"y"] compare:obj2[@"y"]];
            }];
            NSMutableArray<NSString *> *finalTextParts = [NSMutableArray array];
            for (NSDictionary *element in textElements) {
                [finalTextParts addObject:element[@"text"]];
            }
            [g_s2_capturedKeChuanDetailArray addObject:[finalTextParts componentsJoinedByString:@"\n"]];
            LogMessage(EchoLogTypeSuccess, @"[课传] 成功参详流注内容 (共 %lu 条)", (unsigned long)g_s2_capturedKeChuanDetailArray.count);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self processKeChuanQueue_Truth_S2];
            });
            return;
        }
    }
    else if (g_isExtractingNianming) {
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);

        if ([vcToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)vcToPresent;
            UIAlertAction *targetAction = nil;
            if (g_currentItemToExtract) {
                for (UIAlertAction *action in alert.actions) {
                    if ([action.title isEqualToString:g_currentItemToExtract]) {
                        targetAction = action;
                        break;
                    }
                }
            }
            if (targetAction) {
                id handler = [targetAction valueForKey:@"handler"];
                if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); }
                return;
            }
        }
        else if ([vcClassName containsString:@"年命摘要視圖"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = vcToPresent.view;
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels);
                NSMutableArray *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) [textParts addObject:label.text]; }
                [g_capturedZhaiYaoArray addObject:[[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
                LogMessage(EchoLogTypeSuccess, @"[行年] 成功参详'年命摘要'。");
            });
            return;
        }
        else if ([vcClassName containsString:@"年命格局視圖"]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UIView *contentView = vcToPresent.view;
                NSMutableArray *stackViews = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UIStackView class], contentView, stackViews);

                if (stackViews.count > 0) {
                    UIStackView *mainStackView = stackViews.firstObject;
                    NSMutableArray<NSString *> *allTextParts = [NSMutableArray array];

                    for (UIView *subview in mainStackView.arrangedSubviews) {
                        if ([subview isKindOfClass:[UILabel class]]) {
                            NSString *text = ((UILabel *)subview).text;
                            if (text.length > 0) [allTextParts addObject:text];
                        } 
                        else if ([subview isKindOfClass:NSClassFromString(@"六壬大占.IntrinsicTableView")]) {
                            UITableView *tableView = (UITableView *)subview;
                            id<UITableViewDataSource> dataSource = tableView.dataSource;
                            if (dataSource) {
                                NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:0];
                                for (NSInteger row = 0; row < rows; row++) {
                                    UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
                                    if (cell) {
                                        NSMutableArray *labelsInCell = [NSMutableArray array];
                                        FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labelsInCell);
                                        [labelsInCell sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
                                        
                                        NSMutableArray<NSString *> *cellTextParts = [NSMutableArray array];
                                        for(UILabel *l in labelsInCell) { if(l.text.length > 0) [cellTextParts addObject:l.text]; }
                                        
                                        if (cellTextParts.count > 0) [allTextParts addObject:[cellTextParts componentsJoinedByString:@" "]];
                                    }
                                }
                            }
                        }
                    }
                    NSString *finalText = [[allTextParts componentsJoinedByString:@" | "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                    [g_capturedGeJuArray addObject:finalText];
                    LogMessage(EchoLogTypeSuccess, @"[行年] 成功参详'年命格局'。");
                }
            });
            return;
        }
    }
    
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);
    void (^handleExtraction)(NSString *, NSString *, void(^)(NSString*)) = ^(NSString *taskName, NSString *result, void(^completionBlock)(NSString*)) {
        LogMessage(EchoLogTypeSuccess, @"[解析] 成功推衍 [%@]", taskName);
        if (completionBlock) { completionBlock(result); }
    };
    void (^delayedExtraction)(void(^)()) = ^(void(^extractionLogic)()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), extractionLogic);
    };

    if ([vcClassName containsString:@"格局總覽視圖"]) {
        if (g_isExtractingBiFa) {
            g_isExtractingBiFa = NO;
            delayedExtraction(^{ NSString *result = extractFromComplexTableViewPopup(vcToPresent.view); handleExtraction(@"毕法要诀", result, g_biFa_completion); g_biFa_completion = nil; });
            return;
        } else if (g_isExtractingGeJu) {
            g_isExtractingGeJu = NO;
            delayedExtraction(^{ NSString *result = extractFromComplexTableViewPopup(vcToPresent.view); handleExtraction(@"格局要览", result, g_geJu_completion); g_geJu_completion = nil; });
            return;
        } else if (g_isExtractingFangFa) {
            g_isExtractingFangFa = NO;
            delayedExtraction(^{ NSString *result = extractFromComplexTableViewPopup(vcToPresent.view); handleExtraction(@"解析方法", result, g_fangFa_completion); g_fangFa_completion = nil; });
            return;
        }
    }
    else if (g_isExtractingQiZheng && [vcClassName containsString:@"七政"]) {
        g_isExtractingQiZheng = NO;
        delayedExtraction(^{ NSString *result = extractFromComplexTableViewPopup(vcToPresent.view); handleExtraction(@"七政四余", result, g_qiZheng_completion); g_qiZheng_completion = nil; });
        return;
    }
    else if (g_isExtractingSanGong && [vcClassName containsString:@"三宮時信息視圖"]) {
        g_isExtractingSanGong = NO;
        delayedExtraction(^{ NSString *result = extractFromComplexTableViewPopup(vcToPresent.view); handleExtraction(@"三宫时信息", result, g_sanGong_completion); g_sanGong_completion = nil; });
        return;
    }
    
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = GetFrontmostWindow();
            if (!keyWindow) return;
            if ([keyWindow viewWithTag:kEchoControlButtonTag]) {
                [[keyWindow viewWithTag:kEchoControlButtonTag] removeFromSuperview];
            }
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

// ... (所有数据提取的核心函数，如 extractNianmingInfoWithCompletion 等，保持不变)
%new
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion {
    LogMessage(EchoLogTypeTask, @"[任务启动] 参详行年参数...");
    g_isExtractingNianming = YES; 
    g_capturedZhaiYaoArray = [NSMutableArray array]; 
    g_capturedGeJuArray = [NSMutableArray array];
    
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; 
    FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    
    if (!targetCV) { 
        LogMessage(EchoLogTypeWarning, @"[行年] 未找到行年单元，跳过分析。"); 
        g_isExtractingNianming = NO; if (completion) { completion(@""); } return; 
    }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    
    if (allUnitCells.count == 0) { 
        LogMessage(EchoLogTypeWarning, @"[行年] 行年单元数量为0，跳过分析。"); 
        g_isExtractingNianming = NO; if (completion) { completion(@""); } return; 
    }
    
    LogMessage(EchoLogTypeInfo, @"[行年] 发现 %lu 个参数，将依次进行两步推衍...", (unsigned long)allUnitCells.count);
    
    __weak typeof(self) weakSelf = self;
    __block NSInteger currentIndex = 0;
    __block void (^processNextCell)();
    
    processNextCell = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || currentIndex >= allUnitCells.count) {
            LogMessage(EchoLogTypeTask, @"[行年] 所有参数参详完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            for (NSUInteger i = 0; i < allUnitCells.count; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[摘要未获取]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局未获取]";
                [resultStr appendFormat:@"- 参数 %lu\n  摘要: %@\n  格局: %@", (unsigned long)i + 1, zhaiYao, geJu];
                if (i < allUnitCells.count - 1) { [resultStr appendString:@"\n\n"]; }
            }
            g_isExtractingNianming = NO;
            g_currentItemToExtract = nil;
            if (completion) { completion([resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
            processNextCell = nil;
            return;
        }
        
        UICollectionViewCell *cell = allUnitCells[currentIndex];
        id delegate = targetCV.delegate;
        NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        
        LogMessage(EchoLogTypeInfo, @"[行年] 正在参详参数 %ld 的 [年命摘要]", (long)currentIndex + 1);
        g_currentItemToExtract = @"年命摘要";
        if (delegate && indexPath) [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            LogMessage(EchoLogTypeInfo, @"[行年] 正在参详参数 %ld 的 [格局方法]", (long)currentIndex + 1);
            g_currentItemToExtract = @"格局方法";
            if (delegate && indexPath) [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];

            currentIndex++;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), processNextCell);
        });
    } copy];
    
    processNextCell();
}
%new 
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingBiFa) return;
    g_isExtractingBiFa = YES; g_biFa_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示法訣總覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}
%new 
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingGeJu) return;
    g_isExtractingGeJu = YES; g_geJu_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示格局總覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}
%new 
- (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingFangFa) return;
    g_isExtractingFangFa = YES; g_fangFa_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示方法總覽");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector]); }
}
%new 
- (void)extractQiZheng_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingQiZheng) return;
    g_isExtractingQiZheng = YES; g_qiZheng_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示七政信息WithSender:");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); }
}
%new 
- (void)extractSanGong_NoPopup_WithCompletion:(void (^)(NSString *))completion {
    if (g_isExtractingSanGong) return;
    g_isExtractingSanGong = YES; g_sanGong_completion = [completion copy];
    SEL selector = NSSelectorFromString(@"顯示三宮時信息WithSender:");
    if ([self respondsToSelector:selector]) { SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]); }
}


// =========================================================================
// ↓↓↓ 使用下面这个最终的 V28.0 版本，替换掉您现有的 createOrShowMainControlPanel 函数 ↓↓↓
// =========================================================================
%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) { [g_mainControlPanelView removeFromSuperview]; g_mainControlPanelView = nil; g_logTextView = nil; g_questionTextView = nil; g_clearInputButton = nil; }];
        return;
    }
    
    // --- Base Panel Setup (Full Screen) ---
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
    CGFloat contentInnerWidth = contentView.bounds.size.width - 2 * padding;
    CGFloat btnWidth = (contentInnerWidth - padding) / 2.0;    
    // --- Reusable Element Creators ---
    UIButton* (^createButton)(NSString*, NSString*, NSInteger, UIColor*) = ^(NSString* title, NSString* iconName, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.backgroundColor = color;
        btn.tag = tag;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [btn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [btn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];
        btn.layer.cornerRadius = 12;

        [btn setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
        if (iconName && [UIImage respondsToSelector:@selector(systemImageNamed:)]) {
            [btn setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
        }
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        
        return btn;
    };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) { 
        UILabel *label = [[UILabel alloc] init];
        label.text = title; 
        label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]; 
        label.textColor = [UIColor lightGrayColor]; 
        return label; 
    };
    
    // --- Layout Starts ---
    CGFloat currentY = 15.0;
    
    // --- Fixed Header ---
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:@"Echo 大六壬推衍 "];
    [titleString addAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:22 weight:UIFontWeightBold], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0, titleString.length)];
    NSAttributedString *versionString = [[NSAttributedString alloc] initWithString:@"v28.0" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightRegular], NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    [titleString appendAttributedString:versionString];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, currentY, contentInnerWidth, 30)];
    titleLabel.attributedText = titleString;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    currentY += 30 + 20;

    UIButton *promptButton = createButton(@"AI Prompt: 开启", @"wand.and.stars.inverse", kButtonTag_AIPromptToggle, ECHO_COLOR_PROMPT_ON);
    promptButton.frame = CGRectMake(padding, currentY, contentInnerWidth, 44);
    [contentView addSubview:promptButton];
    currentY += 44 + 10;
    
    UIView *textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentInnerWidth, 110)];
    textViewContainer.backgroundColor = ECHO_COLOR_CARD_BG;
    textViewContainer.layer.cornerRadius = 12;
    [contentView addSubview:textViewContainer];
    
    g_questionTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, 0, contentInnerWidth - 2*padding - 40, 110)];
    g_questionTextView.backgroundColor = [UIColor clearColor];
    g_questionTextView.textColor = [UIColor lightGrayColor];
    g_questionTextView.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    g_questionTextView.textContainerInset = UIEdgeInsetsMake(10, 0, 10, 0);
    g_questionTextView.text = @"选填：输入您想问的具体问题";
    g_questionTextView.delegate = (id<UITextViewDelegate>)self;
    g_questionTextView.returnKeyType = UIReturnKeyDone;
    [textViewContainer addSubview:g_questionTextView];

g_clearInputButton = [UIButton buttonWithType:UIButtonTypeSystem];
if (@available(iOS 13.0, *)) {
    // << FIX: Use configuration to match font size >>
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14.0 weight:UIFontWeightRegular];
    UIImage *icon = [UIImage systemImageNamed:@"xmark.circle.fill" withConfiguration:config];
    [g_clearInputButton setImage:icon forState:UIControlStateNormal];
}
g_clearInputButton.frame = CGRectMake(textViewContainer.bounds.size.width - padding - 25, 10, 25, 25);
g_clearInputButton.tintColor = [UIColor grayColor];
// ...
    g_clearInputButton.tag = kButtonTag_ClearInput;
    g_clearInputButton.alpha = 0;
    [g_clearInputButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [textViewContainer addSubview:g_clearInputButton];
    currentY += 110 + 20;

    UIView *card1 = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentInnerWidth, 0)];
    card1.backgroundColor = ECHO_COLOR_CARD_BG;
    card1.layer.cornerRadius = 12;
    [contentView addSubview:card1];

    CGFloat card1InnerY = 15;
    UILabel *sec1Title = createSectionTitle(@"课盘总览");
    sec1Title.frame = CGRectMake(padding, card1InnerY, contentInnerWidth - 2*padding, 22);
    [card1 addSubview:sec1Title];
    card1InnerY += 22 + 10;
    
    UIButton *stdButton = createButton(@"标准课盘", @"doc.text", kButtonTag_StandardReport, ECHO_COLOR_MAIN_TEAL);
    stdButton.frame = CGRectMake(padding, card1InnerY, btnWidth, 48);
    [card1 addSubview:stdButton];
    UIButton *deepButton = createButton(@"深度课盘", @"square.stack.3d.up.fill", kButtonTag_DeepDiveReport, ECHO_COLOR_MAIN_BLUE);
    deepButton.frame = CGRectMake(padding + btnWidth + padding, card1InnerY, btnWidth, 48);
    [card1 addSubview:deepButton];
    card1InnerY += 48 + 15;
    card1.frame = CGRectMake(padding, currentY, contentInnerWidth, card1InnerY);
    currentY += card1.frame.size.height + 20;
    
    UIView *card2 = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentInnerWidth, 0)];
    card2.backgroundColor = ECHO_COLOR_CARD_BG;
    card2.layer.cornerRadius = 12;
    [contentView addSubview:card2];
    
    CGFloat card2InnerY = 15;
    UILabel *sec2Title = createSectionTitle(@"高级功能区");
    sec2Title.frame = CGRectMake(padding, card2InnerY, contentInnerWidth - 2*padding, 22);
    [card2 addSubview:sec2Title];
    card2InnerY += 22 + 15;
    
    NSArray *allToolButtons = @[
        @{@"title": @"课体范式", @"icon": @"square.stack.3d.up", @"tag": @(kButtonTag_KeTi)},
        @{@"title": @"九宗门", @"icon": @"arrow.triangle.branch", @"tag": @(kButtonTag_JiuZongMen)},
        @{@"title": @"课传流注", @"icon": @"wave.3.right", @"tag": @(kButtonTag_KeChuan)},
        @{@"title": @"行年参数", @"icon": @"person.crop.circle", @"tag": @(kButtonTag_NianMing)},
        @{@"title": @"神煞系统", @"icon": @"shield.lefthalf.filled", @"tag": @(kButtonTag_ShenSha)},
        @{@"title": @"毕法要诀", @"icon": @"book.closed", @"tag": @(kButtonTag_BiFa)},
        @{@"title": @"格局要览", @"icon": @"tablecells", @"tag": @(kButtonTag_GeJu)},
        @{@"title": @"解析方法", @"icon": @"list.number", @"tag": @(kButtonTag_FangFa)}
    ];
    for (int i = 0; i < allToolButtons.count; i++) {
        NSDictionary *config = allToolButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(padding + (i % 2) * (btnWidth + padding), card2InnerY + (i / 2) * 56, btnWidth, 46);
        [card2 addSubview:btn];
    }
    card2InnerY += ((allToolButtons.count + 1) / 2) * 56 + 5;
    card2.frame = CGRectMake(padding, currentY, contentInnerWidth, card2InnerY);
    currentY += card2.frame.size.height;
    
    // --- Intelligent Log View & Fixed Bottom Buttons ---
    CGFloat bottomButtonsHeight = 40;
    CGFloat bottomAreaPadding = 10;
    CGFloat logTopPadding = 15;
    CGFloat bottomButtonsY = contentView.bounds.size.height - bottomButtonsHeight - bottomAreaPadding;

    CGFloat logViewY = currentY + logTopPadding;
    CGFloat logViewHeight = bottomButtonsY - logViewY - bottomAreaPadding;

    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, logViewY, contentInnerWidth, logViewHeight)];
    g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG;
    g_logTextView.layer.cornerRadius = 12;
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    g_logTextView.editable = NO;
    g_logTextView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    NSMutableAttributedString *initLog = [[NSMutableAttributedString alloc] initWithString:@"[推衍核心]：就绪。\n"];
    [initLog addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, initLog.length)];
    [initLog addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, initLog.length)];
    g_logTextView.attributedText = initLog;
    [contentView addSubview:g_logTextView];

// Re-calculate bottom button width based on the main contentView, not inner width
CGFloat bottomBtnWidth = (contentView.bounds.size.width - 3 * padding) / 2.0;

UIButton *closeButton = createButton(@"关闭", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
closeButton.frame = CGRectMake(padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight);
[contentView addSubview:closeButton];

UIButton *sendLastReportButton = createButton(@"发送课盘", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
sendLastReportButton.frame = CGRectMake(padding + bottomBtnWidth + padding, bottomButtonsY, bottomBtnWidth, bottomButtonsHeight);
[contentView addSubview:sendLastReportButton];

    // --- Finalize Panel Animation ---
    g_mainControlPanelView.alpha = 0;
    g_mainControlPanelView.transform = CGAffineTransformMakeScale(1.05, 1.05);
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0.2 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        g_mainControlPanelView.alpha = 1.0;
        g_mainControlPanelView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

%new
- (void)textViewDidChange:(UITextView *)textView {
    BOOL hasText = textView.text.length > 0 && ![textView.text isEqualToString:@"选填：输入您想问的具体问题"];
    [UIView animateWithDuration:0.2 animations:^{
        g_clearInputButton.alpha = hasText ? 1.0 : 0.0;
    }];
}

%new
- (void)textViewDidBeginEditing:(UITextView *)textView {
    if ([textView.text isEqualToString:@"选填：输入您想问的具体问题"]) {
        textView.text = @"";
        textView.textColor = [UIColor whiteColor];
    }
    [self textViewDidChange:textView];
}

%new
- (void)textViewDidEndEditing:(UITextView *)textView {
    if ([textView.text isEqualToString:@""]) {
        textView.text = @"选填：输入您想问的具体问题";
        textView.textColor = [UIColor lightGrayColor];
    }
    [self textViewDidChange:textView];
}

%new
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        [textView resignFirstResponder];
        return NO;
    }
    return YES;
}

%new
- (void)buttonTouchDown:(UIButton *)sender { 
    [UIView animateWithDuration:0.15 animations:^{
        sender.transform = CGAffineTransformMakeScale(0.95, 0.95);
        sender.alpha = 0.8;
    }];
}
%new
- (void)buttonTouchUp:(UIButton *)sender { 
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.5 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        sender.transform = CGAffineTransformIdentity;
        sender.alpha = 1.0;
    } completion:nil];
}

%new
- (void)setInteractionBlocked:(BOOL)blocked {
    if (!g_mainControlPanelView) return;
    
    UIView *blockerView = [g_mainControlPanelView viewWithTag:kEchoInteractionBlockerTag];
    if (blocked && !blockerView) {
        blockerView = [[UIView alloc] initWithFrame:g_mainControlPanelView.bounds];
        blockerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.5];
        blockerView.tag = kEchoInteractionBlockerTag;
        blockerView.alpha = 0;
        
        UIActivityIndicatorView *spinner;
        if (@available(iOS 13.0, *)) {
             spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
             spinner.color = [UIColor whiteColor];
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
            #pragma clang diagnostic pop
        }
        spinner.center = blockerView.center;
        [spinner startAnimating];
        [blockerView addSubview:spinner];
        
        [g_mainControlPanelView addSubview:blockerView];
        [UIView animateWithDuration:0.3 animations:^{
            blockerView.alpha = 1.0;
        }];
    } else if (!blocked && blockerView) {
        [UIView animateWithDuration:0.3 animations:^{
            blockerView.alpha = 0;
        } completion:^(BOOL finished) {
            [blockerView removeFromSuperview];
        }];
    }
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    [self buttonTouchUp:sender]; // Ensure button animates back up

    if (g_s1_isExtracting || g_s2_isExtractingKeChuanDetail || g_isExtractingNianming || g_extractedData) { 
        if (sender.tag != kButtonTag_ClosePanel) { 
            LogMessage(EchoLogError, @"[错误] 当前有推衍任务正在进行，请稍候。"); 
            return; 
        } 
    }

    __weak typeof(self) weakSelf = self;
    switch (sender.tag) {
        case kButtonTag_ClearInput: {
            g_questionTextView.text = @"";
            [self textViewDidEndEditing:g_questionTextView];
            [g_questionTextView resignFirstResponder];
            break;
        }
        case kButtonTag_AIPromptToggle: { sender.selected = !sender.selected; g_shouldIncludeAIPromptHeader = sender.selected; NSString *status = g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭"; NSString *title = [NSString stringWithFormat:@"AI Prompt: %@", status]; [sender setAttributedTitle:nil forState:UIControlStateNormal]; [sender setTitle:title forState:UIControlStateNormal]; sender.backgroundColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_AUX_GREY; LogMessage(EchoLogTypeInfo, @"[设置] AI Prompt 已 %@。", status); break; }
        case kButtonTag_ClosePanel: [self createOrShowMainControlPanel]; break;
        case kButtonTag_SendLastReportToAI: { NSString *lastReport = g_lastGeneratedReport; if (lastReport && lastReport.length > 0) { [self presentAIActionSheetWithReport:lastReport]; } else { LogMessage(EchoLogTypeWarning, @"课盘缓存为空，请先推衍。"); [self showEchoNotificationWithTitle:@"操作无效" message:@"尚未生成任何课盘。"]; } break; }
        case kButtonTag_StandardReport: [self executeSimpleExtraction]; break;
        case kButtonTag_DeepDiveReport: [self executeCompositeExtraction]; break;
        // ... (The rest of the cases for specific extractions)
        case kButtonTag_KeTi: { [self setInteractionBlocked:YES]; [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:YES completion:^(NSString *result) { dispatch_async(dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"课体范式_详"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf presentAIActionSheetWithReport:finalReport]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil; }); }]; break; }
        case kButtonTag_JiuZongMen: { [self setInteractionBlocked:YES]; [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES completion:^(NSString *result) { dispatch_async(dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"九宗门_详"] = result; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf presentAIActionSheetWithReport:finalReport]; g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil; }); }]; break; }
        case kButtonTag_KeChuan: [self startExtraction_Truth_S2_WithCompletion:nil]; break;
        case kButtonTag_ShenSha: {
            [self setInteractionBlocked:YES];
            [self extractShenShaInfo_CompleteWithCompletion:^(NSString *shenShaResult) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                [strongSelf setInteractionBlocked:NO];
                if (shenShaResult) {
                    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                    reportData[@"神煞详情"] = shenShaResult;
                    NSString *finalReport = formatFinalReport(reportData);
                    g_lastGeneratedReport = [finalReport copy];
                    [strongSelf presentAIActionSheetWithReport:finalReport];
                }
            }];
            break;
        }
        case kButtonTag_NianMing: { [self setInteractionBlocked:YES]; [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) { __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; [strongSelf setInteractionBlocked:NO]; NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"行年参数"] = nianmingText; NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy]; [strongSelf presentAIActionSheetWithReport:finalReport]; }]; break; }
        case kButtonTag_BiFa: {
            [self setInteractionBlocked:YES];
            [self extractBiFa_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                [strongSelf setInteractionBlocked:NO];
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"毕法要诀"] = result;
                NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        case kButtonTag_GeJu: {
            [self setInteractionBlocked:YES];
            [self extractGeJu_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                [strongSelf setInteractionBlocked:NO];
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"格局要览"] = result;
                NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        case kButtonTag_FangFa: {
            [self setInteractionBlocked:YES];
            [self extractFangFa_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                [strongSelf setInteractionBlocked:NO];
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"解析方法"] = result;
                NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        default: break;
    }
}
// ... (The rest of the file remains the same)
%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) { LogMessage(EchoLogError, @"课盘为空，无法执行后续操作。"); return; }
    [UIPasteboard generalPasteboard].string = report; 
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"发送课盘至AI助手" message:@"将使用内部缓存的课盘内容" preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *encodedReport = [report stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSArray *aiApps = @[
        @{@"name": @"Kimi", @"scheme": @"kimi://", @"format": @"kimi://chat?q=%@"},
        @{@"name": @"豆包", @"scheme": @"doubao://", @"format": @"doubao://chat/send?text=%@"},
        @{@"name": @"腾讯元宝", @"scheme": @"yuanbao://", @"format": @"yuanbao://send?text=%@"},
        @{@"name": @"ChatGPT", @"scheme": @"chatgpt://", @"format": @"chatgpt://chat?message=%@"},
        @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"},
        @{@"name": @"智谱清言", @"scheme": @"zhipuai://", @"format": @"zhipuai://chat/send?text=%@"},
        @{@"name": @"BotGem", @"scheme": @"botgem://", @"format": @"botgem://send?text=%@"},
        @{@"name": @"Google AI Studio", @"scheme": @"https://", @"format": @"https://aistudio.google.com/prompts/new_chat"}
    ];    
    int availableApps = 0;
    for (NSDictionary *appInfo in aiApps) {
        NSString *checkScheme = appInfo[@"scheme"];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:checkScheme]]) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"发送到 %@", appInfo[@"name"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *urlString = [NSString stringWithFormat:appInfo[@"format"], encodedReport];
                NSURL *url = [NSURL URLWithString:urlString];
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                    if(success) { LogMessage(EchoLogTypeSuccess, @"成功跳转到 %@", appInfo[@"name"]); } else { LogMessage(EchoLogError, @"跳转到 %@ 失败", appInfo[@"name"]); }
                }];
            }];
            [actionSheet addAction:action];
            availableApps++;
        }
    }
    if (availableApps == 0) { actionSheet.message = @"未检测到受支持的AI App。\n课盘已复制到剪贴板。"; }
    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"仅复制到剪贴板" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) { LogMessage(EchoLogTypeSuccess, @"课盘已复制到剪贴板。"); [self showEchoNotificationWithTitle:@"复制成功" message:@"课盘内容已同步至剪贴板。"]; }];
    [actionSheet addAction:copyAction];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:cancelAction];
    if (actionSheet.popoverPresentationController) {
        actionSheet.popoverPresentationController.sourceView = self.view;
        actionSheet.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height, 1.0, 1.0);
        actionSheet.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:actionSheet animated:YES completion:nil];
}
%new
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *existing = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if(existing) [existing removeFromSuperview];
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)];
    progressView.center = keyWindow.center;
    progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    progressView.layer.cornerRadius = 10;
    progressView.tag = kEchoProgressHUDTag;
    UIActivityIndicatorView *spinner;
    if (@available(iOS 13.0, *)) {
         spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
         spinner.color = [UIColor whiteColor];
    } else {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Wdeprecated-declarations"
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        #pragma clang diagnostic pop
    }
    spinner.center = CGPointMake(110, 50);
    [spinner startAnimating];
    [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)];
    progressLabel.textColor = [UIColor whiteColor];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.font = [UIFont systemFontOfSize:14];
    progressLabel.adjustsFontSizeToFitWidth = YES;
    progressLabel.text = text;
    [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
}
%new
- (void)updateProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if (progressView) { for (UIView *subview in progressView.subviews) { if ([subview isKindOfClass:[UILabel class]]) { ((UILabel *)subview).text = text; break; } } }
}
%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if (progressView) { [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }]; }
}
%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    CGFloat topPadding = 0;
    if (@available(iOS 11.0, *)) { topPadding = keyWindow.safeAreaInsets.top; }
    topPadding = topPadding > 0 ? topPadding : 20;
    CGFloat bannerWidth = keyWindow.bounds.size.width - 32;
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, -100, bannerWidth, 60)];
    bannerView.layer.cornerRadius = 12;
    bannerView.clipsToBounds = YES;
    UIVisualEffectView *blurEffectView = nil;
    if (@available(iOS 8.0, *)) {
        blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]];
        blurEffectView.frame = bannerView.bounds;
        [bannerView addSubview:blurEffectView];
    } else {
        bannerView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.9];
    }
    UIView *containerForLabels = blurEffectView ? blurEffectView.contentView : bannerView;
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, 20, 20)];
    iconLabel.text = @"✓";
    iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
    iconLabel.font = [UIFont boldSystemFontOfSize:16];
    [containerForLabels addSubview:iconLabel];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, bannerWidth - 55, 20)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    if (@available(iOS 13.0, *)) { titleLabel.textColor = [UIColor labelColor]; } else { titleLabel.textColor = [UIColor blackColor];}
    [containerForLabels addSubview:titleLabel];
    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, bannerWidth - 55, 16)];
    messageLabel.text = message;
    messageLabel.font = [UIFont systemFontOfSize:13];
    if (@available(iOS 13.0, *)) { messageLabel.textColor = [UIColor secondaryLabelColor]; } else { messageLabel.textColor = [UIColor darkGrayColor]; }
    [containerForLabels addSubview:messageLabel];
    [keyWindow addSubview:bannerView];
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        bannerView.frame = CGRectMake(16, topPadding, bannerWidth, 60);
    } completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            bannerView.alpha = 0;
            bannerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
        } completion:^(BOOL finished) {
            [bannerView removeFromSuperview];
        }];
    });
}
%new
- (void)extractTimeInfoWithCompletion:(void (^)(void))completion {
    LogMessage(EchoLogTypeInfo, @"[盘面] 开始参详时间信息...");
    g_isExtractingTimeInfo = YES;
    SEL showTimePickerSelector = NSSelectorFromString(@"顯示時間選擇");
    if ([self respondsToSelector:showTimePickerSelector]) {
        dispatch_async(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:showTimePickerSelector]); });
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            for (int i = 0; i < 50; i++) { if (!g_isExtractingTimeInfo) break; [NSThread sleepForTimeInterval:0.1]; }
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(); });
        });
    } else {
        LogMessage(EchoLogError, @"[时间] 错误: 找不到 '顯示時間選擇' 方法。");
        g_extractedData[@"时间块"] = @"[时间推衍失败: 找不到方法]";
        g_isExtractingTimeInfo = NO;
        if (completion) completion();
    }
}
%new
- (NSString *)extractSwitchedXunKongInfo {
    SEL switchSelector = NSSelectorFromString(@"切換旬日");
    if ([self respondsToSelector:switchSelector]) {
        LogMessage(EchoLogTypeInfo, @"[旬空] 正在切换以参详另一状态...");
        SUPPRESS_LEAK_WARNING([self performSelector:switchSelector]);
        [NSThread sleepForTimeInterval:0.1];
        NSString *switchedText = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
        SUPPRESS_LEAK_WARNING([self performSelector:switchSelector]);
        return switchedText;
    } else {
        LogMessage(EchoLogTypeWarning, @"[旬空] 在 ViewController 上未找到 '切換旬日' 方法。");
        return @"";
    }
}
%new
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion {
    g_extractedData = [NSMutableDictionary dictionary];
    __weak typeof(self) weakSelf = self;

    [self extractTimeInfoWithCompletion:^{
        LogMessage(EchoLogTypeInfo, @"[盘面] 时间参详完毕，开始推衍基础信息...");
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *textA = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@" "];
        NSString *textB = [strongSelf extractSwitchedXunKongInfo];
        NSString *xunInfo = nil, *liuQinFullInfo = nil;
        if ([textA containsString:@"旬"]) { xunInfo = textA; liuQinFullInfo = textB; } else if ([textB containsString:@"旬"]) { xunInfo = textB; liuQinFullInfo = textA; } else { xunInfo = textA; liuQinFullInfo = textB; LogMessage(EchoLogTypeWarning, @"[旬空] 无法通过'旬'字识别，采用默认顺序。"); }
        NSString *riGan = @"", *liuQinStr = @""; if (liuQinFullInfo.length > 0) { NSRange riRange = [liuQinFullInfo rangeOfString:@"日"]; if (riRange.location != NSNotFound) { riGan = [liuQinFullInfo substringToIndex:1]; liuQinStr = [[liuQinFullInfo substringFromIndex:riRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]; liuQinStr = [liuQinStr stringByReplacingOccurrencesOfString:@"空" withString:@""]; } else { liuQinStr = [liuQinFullInfo stringByReplacingOccurrencesOfString:@"空" withString:@""]; } }
        NSMutableArray<NSString *> *liuQinArray = [NSMutableArray array]; if(liuQinStr.length > 0) { for (int i = 0; i < liuQinStr.length; i += 2) { if (i + 2 <= liuQinStr.length) { [liuQinArray addObject:[liuQinStr substringWithRange:NSMakeRange(i, 2)]]; } } }
        g_extractedData[@"旬空_旬信息"] = [xunInfo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        g_extractedData[@"旬空_日干"] = riGan; g_extractedData[@"旬空_六亲数组"] = liuQinArray; g_extractedData[@"旬空_六亲"] = [liuQinStr stringByReplacingOccurrencesOfString:@"/" withString:@""];
        LogMessage(EchoLogTypeSuccess, @"[旬空] 识别结果 -> 旬信息:[%@], 日干:[%@], 六亲:%@", g_extractedData[@"旬空_旬信息"], riGan, [liuQinArray componentsJoinedByString:@","]);
        g_extractedData[@"月将"] = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
        g_extractedData[@"昼夜"] = [strongSelf extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
        g_extractedData[@"天地盘"] = [strongSelf extractTianDiPanInfo_V18];
        g_extractedData[@"四课"] = [strongSelf _echo_extractSiKeInfo];
        g_extractedData[@"三传"] = [strongSelf _echo_extractSanChuanInfo];
        LogMessage(EchoLogTypeInfo, @"[盘面] 开始异步解析各类格局...");

        dispatch_group_t popupGroup = dispatch_group_create();
        dispatch_group_enter(popupGroup);
        [strongSelf extractBiFa_NoPopup_WithCompletion:^(NSString *result) {
            g_extractedData[@"毕法要诀"] = SafeString(result); dispatch_group_leave(popupGroup);
        }];
        dispatch_group_enter(popupGroup);
        [strongSelf extractGeJu_NoPopup_WithCompletion:^(NSString *result) {
            g_extractedData[@"格局要览"] = SafeString(result); dispatch_group_leave(popupGroup);
        }];
        dispatch_group_enter(popupGroup);
        [strongSelf extractFangFa_NoPopup_WithCompletion:^(NSString *result) {
            g_extractedData[@"解析方法"] = SafeString(result); dispatch_group_leave(popupGroup);
        }];
        dispatch_group_enter(popupGroup);
        [strongSelf extractQiZheng_NoPopup_WithCompletion:^(NSString *result) {
            g_extractedData[@"七政四余"] = SafeString(result); dispatch_group_leave(popupGroup);
        }];
        dispatch_group_enter(popupGroup);
        [strongSelf extractSanGong_NoPopup_WithCompletion:^(NSString *result) {
            g_extractedData[@"三宫时信息"] = SafeString(result); dispatch_group_leave(popupGroup);
        }];

        dispatch_group_notify(popupGroup, dispatch_get_main_queue(), ^{
            LogMessage(EchoLogTypeInfo, @"[盘面] 所有信息整合完成。");
            NSString *value = g_extractedData[@"毕法要诀"];
            if (value) { g_extractedData[@"毕法要诀"] = [value stringByReplacingOccurrencesOfString:@"通类门→" withString:@""]; }

            if (completion) { completion(g_extractedData); }
        });
    }];
}
%new
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *result))completion {
    g_s1_isExtracting = YES; g_s1_currentTaskType = taskType; g_s1_shouldIncludeXiangJie = include; g_s1_completion_handler = [completion copy];
    NSString *mode = include ? @"详" : @"简";
    if(g_s1_completion_handler) { LogMessage(EchoLogTypeInfo, @"[集成推衍] 开始解析 %@ (%@)...", taskType, mode); } 
    else { LogMessage(EchoLogTypeTask, @"[任务启动] 模式: %@ (详情: %@)", taskType, include ? @"开启" : @"关闭"); }
    if ([taskType isEqualToString:@"KeTi"]) {
        UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) { LogMessage(EchoLogError, @"[错误] 无法找到主窗口。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到主窗口]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元"); if (!keTiCellClass) { LogMessage(EchoLogError, @"[错误] 无法找到 '課體單元' 类。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到課體單元类]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
        for (UICollectionView *cv in allCVs) {
            for (id cell in cv.visibleCells) { if ([cell isKindOfClass:keTiCellClass]) { g_s1_keTi_targetCV = cv; break; } }
            if(g_s1_keTi_targetCV) break;
        }
        if (!g_s1_keTi_targetCV) { LogMessage(EchoLogError, @"[错误] 无法找到包含“课体”的UICollectionView。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到课体CV]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        g_s1_keTi_workQueue = [NSMutableArray array]; g_s1_keTi_resultsArray = [NSMutableArray array];
        NSInteger totalItems = [g_s1_keTi_targetCV.dataSource collectionView:g_s1_keTi_targetCV numberOfItemsInSection:0];
        for (NSInteger i = 0; i < totalItems; i++) { [g_s1_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
        if (g_s1_keTi_workQueue.count == 0) {
            LogMessage(EchoLogTypeWarning, @"[警告] 未找到任何“课体”单元来创建任务队列。");
            if(g_s1_completion_handler){ g_s1_completion_handler(@""); g_s1_completion_handler = nil; }
            g_s1_isExtracting = NO; return;
        }
        LogMessage(EchoLogTypeInfo, @"[解析] 发现 %lu 个“课体范式”单元，开始处理...", (unsigned long)g_s1_keTi_workQueue.count);
        [self processKeTiWorkQueue_S1];
    } else if ([taskType isEqualToString:@"JiuZongMen"]) {
        SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
        if ([self respondsToSelector:selector]) { LogMessage(EchoLogTypeInfo, @"[调用] 正在请求“九宗门”数据..."); SUPPRESS_LEAK_WARNING([self performSelector:selector]); } 
        else { LogMessage(EchoLogError, @"[错误] 当前视图无法响应 '顯示九宗門概覽'。"); if(g_s1_completion_handler){ g_s1_completion_handler(@"[错误:无法响应九宗门方法]"); g_s1_completion_handler = nil; } g_s1_isExtracting = NO; }
    }
}
%new
- (void)processKeTiWorkQueue_S1 {
    if (g_s1_keTi_workQueue.count == 0) {
        LogMessage(EchoLogTypeTask, @"[完成] 所有 %lu 项“课体范式”解析完毕。", (unsigned long)g_s1_keTi_resultsArray.count);
        NSString *finalResult = [g_s1_keTi_resultsArray componentsJoinedByString:@"\n\n"];
        NSString *trimmedResult = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        g_s1_keTi_targetCV = nil; g_s1_keTi_workQueue = nil; g_s1_keTi_resultsArray = nil;
        if (g_s1_completion_handler) { g_s1_completion_handler(trimmedResult); }
        return;
    }
    NSIndexPath *indexPath = g_s1_keTi_workQueue.firstObject; [g_s1_keTi_workQueue removeObjectAtIndex:0];
    LogMessage(EchoLogTypeInfo, @"[解析] 正在处理“课体范式” %lu/%lu...", (unsigned long)(g_s1_keTi_resultsArray.count + 1), (unsigned long)(g_s1_keTi_resultsArray.count + g_s1_keTi_workQueue.count + 1));
    id delegate = g_s1_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) { [delegate collectionView:g_s1_keTi_targetCV didSelectItemAtIndexPath:indexPath]; } 
    else { LogMessage(EchoLogError, @"[错误] 无法触发单元点击事件。"); [self processKeTiWorkQueue_S1]; }
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
                        reportData[@"九宗门_简"] = jiuZongMenResult;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            __strong typeof(weakSelf) strongSelf5 = weakSelf; if (!strongSelf5) return;
                            LogMessage(EchoLogTypeInfo, @"[整合] 所有部分解析完成，正在生成标准课盘...");
                            NSString *finalReport = formatFinalReport(reportData);
                            g_lastGeneratedReport = [finalReport copy];
                            [strongSelf5 hideProgressHUD];
                            [strongSelf5 presentAIActionSheetWithReport:finalReport];
                            LogMessage(EchoLogTypeTask, @"[完成] “标准课盘”推衍任务已完成。");
                            g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil;
                            LogMessage(EchoLogTypeInfo, @"[状态] 全局数据已清理。");
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
    [self showProgressHUD:@"1/6: 推衍基础盘面..."];
    __block NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
    
    [self extractKePanInfoWithCompletion:^(NSMutableDictionary *baseReportData) {
        [reportData addEntriesFromDictionary:baseReportData];
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;

        [strongSelf updateProgressHUD:@"2/6: 推演课传流注..."];
        [strongSelf startExtraction_Truth_S2_WithCompletion:^{
            reportData[@"课传详解"] = SafeString(g_s2_finalResultFromKeChuan);
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            
            [strongSelf2 updateProgressHUD:@"3/6: 参详行年参数..."];
            [strongSelf2 extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
                reportData[@"行年参数"] = nianmingText;
                __strong typeof(weakSelf) strongSelf3 = weakSelf; if (!strongSelf3) return;

                [strongSelf3 updateProgressHUD:@"4/6: 推衍神煞系统..."];
                [strongSelf3 extractShenShaInfo_CompleteWithCompletion:^(NSString *shenShaResult) {
                    reportData[@"神煞详情"] = shenShaResult;
                    __strong typeof(weakSelf) strongSelf4 = weakSelf; if (!strongSelf4) return;
                 
                    [strongSelf4 updateProgressHUD:@"5/6: 解析课体范式..."];
                    [strongSelf4 startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:NO completion:^(NSString *keTiResult) {
                        reportData[@"课体范式_简"] = keTiResult;
                        __strong typeof(weakSelf) strongSelf5 = weakSelf; if (!strongSelf5) return;
                        
                        [strongSelf5 updateProgressHUD:@"6/6: 解析九宗门..."];
                        [strongSelf5 startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:NO completion:^(NSString *jiuZongMenResult) {
                            reportData[@"九宗门_简"] = jiuZongMenResult;
                            dispatch_async(dispatch_get_main_queue(), ^{
                                __strong typeof(weakSelf) strongSelf6 = weakSelf; if (!strongSelf6) return;
                                LogMessage(EchoLogTypeInfo, @"[整合] 所有部分解析完成，正在生成深度课盘...");
                                NSString *finalReport = formatFinalReport(reportData);
                                g_lastGeneratedReport = [finalReport copy];
                                [strongSelf6 hideProgressHUD];
                                [strongSelf6 presentAIActionSheetWithReport:finalReport];
                                LogMessage(EchoLogTypeTask, @"[完成] “深度课盘”推衍任务已全部完成。");
                                g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil; g_s2_finalResultFromKeChuan = nil;
                                LogMessage(EchoLogTypeInfo, @"[状态] 全局数据已清理。");
                            });
                        }];
                    }];
                }];
            }];
        }];
    }];
}

%new
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion {
    if (g_s2_isExtractingKeChuanDetail) { LogMessage(EchoLogError, @"[错误] 课传推演任务已在进行中。"); return; }
    LogMessage(EchoLogTypeTask, @"[任务启动] 开始推演“课传流注”...");
    [self showProgressHUD:@"正在推演课传流注..."];
    g_s2_isExtractingKeChuanDetail = YES; g_s2_keChuan_completion_handler = [completion copy]; g_s2_capturedKeChuanDetailArray = [NSMutableArray array]; g_s2_keChuanWorkQueue = [NSMutableArray array]; g_s2_keChuanTitleQueue = [NSMutableArray array];
    Ivar keChuanContainerIvar = class_getInstanceVariable([self class], "課傳");
    if (!keChuanContainerIvar) { LogMessage(EchoLogError, @"[错误] 无法定位核心组件'課傳'。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; }
    id keChuanContainer = object_getIvar(self, keChuanContainerIvar);
    if (!keChuanContainer) { LogMessage(EchoLogError, @"[错误] 核心组件'課傳'未初始化。"); g_s2_isExtractingKeChuanDetail = NO; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); [self hideProgressHUD]; return; }
    Class sanChuanContainerClass = NSClassFromString(@"六壬大占.三傳視圖");
    NSMutableArray *sanChuanResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanContainerClass, (UIView *)keChuanContainer, sanChuanResults);
    if (sanChuanResults.count > 0) {
        UIView *sanChuanContainer = sanChuanResults.firstObject;
        const char *ivarNames[] = {"初傳", "中傳", "末傳", NULL}; NSString *rowTitles[] = {@"初传", @"中传", @"末传"};
        for (int i = 0; ivarNames[i] != NULL; ++i) {
            Ivar ivar = class_getInstanceVariable(sanChuanContainerClass, ivarNames[i]); if (!ivar) continue;
            UIView *chuanView = object_getIvar(sanChuanContainer, ivar); if (!chuanView) continue;
            NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], chuanView, labels);
            [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2){ return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 2) {
                UILabel *dizhiLabel = labels[labels.count-2]; UILabel *tianjiangLabel = labels[labels.count-1];
                if (dizhiLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": dizhiLabel.gestureRecognizers.firstObject, @"taskType": @"diZhi"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 地支(%@)", rowTitles[i], dizhiLabel.text]]; }
                if (tianjiangLabel.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": tianjiangLabel.gestureRecognizers.firstObject, @"taskType": @"tianJiang"} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ - 天将(%@)", rowTitles[i], tianjiangLabel.text]]; }
            }
        }
    }
    Class siKeContainerClass = NSClassFromString(@"六壬大占.四課視圖");
    NSMutableArray *siKeResults = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeContainerClass, (UIView *)keChuanContainer, siKeResults);
    if (siKeResults.count > 0) {
        UIView *siKeContainer = siKeResults.firstObject;
        NSDictionary *keDefs[] = { @{@"t": @"第一课", @"x": @"日", @"s": @"日上", @"j": @"日上天將"}, @{@"t": @"第二课", @"x": @"日上", @"s": @"日陰", @"j": @"日陰天將"}, @{@"t": @"第三课", @"x": @"辰", @"s": @"辰上", @"j": @"辰上天將"}, @{@"t": @"第四课", @"x": @"辰上", @"s": @"辰陰", @"j": @"辰陰天將"}};
        void (^addTask)(const char*, NSString*, NSString*) = ^(const char* iName, NSString* fTitle, NSString* tType) {
            if (!iName) return; Ivar ivar = class_getInstanceVariable(siKeContainerClass, iName);
            if (ivar) {
                UILabel *label = (UILabel *)object_getIvar(siKeContainer, ivar);
                if (label.gestureRecognizers.count > 0) { [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"taskType": tType} mutableCopy]]; [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", fTitle, label.text]]; }
            }
        };
        for (int i = 0; i < 4; ++i) { NSDictionary *d = keDefs[i]; addTask([d[@"x"] UTF8String], [NSString stringWithFormat:@"%@ - 下神", d[@"t"]], @"diZhi"); addTask([d[@"s"] UTF8String], [NSString stringWithFormat:@"%@ - 上神", d[@"t"]], @"diZhi"); addTask([d[@"j"] UTF8String], [NSString stringWithFormat:@"%@ - 天将", d[@"t"]], @"tianJiang"); }
    }
    if (g_s2_keChuanWorkQueue.count == 0) { LogMessage(EchoLogTypeWarning, @"[课传] 任务队列为空，未找到可交互元素。"); g_s2_isExtractingKeChuanDetail = NO; [self hideProgressHUD]; g_s2_finalResultFromKeChuan = @""; if(g_s2_keChuan_completion_handler) g_s2_keChuan_completion_handler(); return; }
    LogMessage(EchoLogTypeInfo, @"[课传] 任务队列构建完成，总计 %lu 项。", (unsigned long)g_s2_keChuanWorkQueue.count);
    [self processKeChuanQueue_Truth_S2];
}
%new
- (void)processKeChuanQueue_Truth_S2 {
    if (!g_s2_isExtractingKeChuanDetail || g_s2_keChuanWorkQueue.count == 0) {
        if (g_s2_isExtractingKeChuanDetail) {
            LogMessage(EchoLogTypeTask, @"[完成] “课传流注”全部推衍完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) { [resultStr appendFormat:@"- 对象: %@\n  %@\n\n", g_s2_keChuanTitleQueue[i], [g_s2_capturedKeChuanDetailArray[i] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "]]; }
                g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (!g_s2_keChuan_completion_handler) {
                    NSMutableDictionary *reportData = [NSMutableDictionary dictionary]; reportData[@"课传详解"] = g_s2_finalResultFromKeChuan;
                    NSString *finalReport = formatFinalReport(reportData); g_lastGeneratedReport = [finalReport copy];
                    [self presentAIActionSheetWithReport:finalReport];
                }
            } else { g_s2_finalResultFromKeChuan = @"[错误: 课传流注解析数量不匹配]"; LogMessage(EchoLogError, @"%@", g_s2_finalResultFromKeChuan); }
        }
        g_s2_isExtractingKeChuanDetail = NO; g_s2_capturedKeChuanDetailArray = nil; g_s2_keChuanWorkQueue = nil; g_s2_keChuanTitleQueue = nil;
        [self hideProgressHUD];
        if (g_s2_keChuan_completion_handler) { g_s2_keChuan_completion_handler(); g_s2_keChuan_completion_handler = nil; }
        return;
    }
    NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject; [g_s2_keChuanWorkQueue removeObjectAtIndex:0];
    NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count];
    LogMessage(EchoLogTypeInfo, @"[课传] 正在参详: %@", title);
    [self updateProgressHUD:[NSString stringWithFormat:@"推演课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]];
    SEL action = [task[@"taskType"] isEqualToString:@"tianJiang"] ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:action]) { SUPPRESS_LEAK_WARNING([self performSelector:action withObject:task[@"gesture"]]); } 
    else { LogMessage(EchoLogError, @"[错误] 方法 %@ 不存在。", NSStringFromSelector(action)); [g_s2_capturedKeChuanDetailArray addObject:@"[解析失败: 方法不存在]"]; [self processKeChuanQueue_Truth_S2]; }
}
%new
- (NSString *)_echo_extractSiKeInfo {
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖"); if (!siKeViewClass) return @"";
    NSMutableArray *siKeViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
    if (siKeViews.count == 0) return @"";
    UIView *container = siKeViews.firstObject; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels);
    if (labels.count < 12) return @"";
    NSMutableDictionary *cols = [NSMutableDictionary dictionary];
    for (UILabel *label in labels) { NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if (!cols[key]) { cols[key] = [NSMutableArray array]; } [cols[key] addObject:label]; }
    if (cols.allKeys.count != 4) return @"";
    NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
    NSMutableArray *c1 = cols[keys[0]], *c2 = cols[keys[1]], *c3 = cols[keys[2]], *c4 = cols[keys[3]];
    [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    NSString *k1_shang = ((UILabel*)c4[0]).text, *k1_jiang = ((UILabel*)c4[1]).text, *k1_xia = ((UILabel*)c4[2]).text;
    NSString *k2_shang = ((UILabel*)c3[0]).text, *k2_jiang = ((UILabel*)c3[1]).text, *k2_xia = ((UILabel*)c3[2]).text;
    NSString *k3_shang = ((UILabel*)c2[0]).text, *k3_jiang = ((UILabel*)c2[1]).text, *k3_xia = ((UILabel*)c2[2]).text;
    NSString *k4_shang = ((UILabel*)c1[0]).text, *k4_jiang = ((UILabel*)c1[1]).text, *k4_xia = ((UILabel*)c1[2]).text;
    return [NSString stringWithFormat:@"- 第一课(日干): %@ 上 %@，%@乘%@\n- 第二课(日上): %@ 上 %@，%@乘%@\n- 第三课(支辰): %@ 上 %@，%@乘%@\n- 第四课(辰上): %@ 上 %@，%@乘%@", SafeString(k1_xia), SafeString(k1_shang), SafeString(k1_shang), SafeString(k1_jiang), SafeString(k2_xia), SafeString(k2_shang), SafeString(k2_shang), SafeString(k2_jiang), SafeString(k3_xia), SafeString(k3_shang), SafeString(k3_shang), SafeString(k3_jiang), SafeString(k4_xia), SafeString(k4_shang), SafeString(k4_shang), SafeString(k4_jiang) ];
}
%new
- (NSString *)_echo_extractSanChuanInfo {
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖"); if (!sanChuanViewClass) return @"";
    NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
    [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    NSArray *titles = @[@"初传", @"中传", @"末传"]; NSMutableArray *lines = [NSMutableArray array];
    for (NSUInteger i = 0; i < scViews.count; i++) {
        UIView *v = scViews[i]; NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels);
        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
        if (labels.count >= 3) {
            NSString *lq = [[(UILabel*)labels.firstObject text] stringByReplacingOccurrencesOfString:@"->" withString:@""];
            NSString *tj = [(UILabel*)labels.lastObject text]; NSString *dz = [(UILabel*)[labels objectAtIndex:labels.count - 2] text];
            NSMutableArray *ssParts = [NSMutableArray array];
            if (labels.count > 3) { for (UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count - 3)]) { if (l.text.length > 0) [ssParts addObject:l.text]; } }
            NSString *ss = [ssParts componentsJoinedByString:@", "];
            NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"%lu传", (unsigned long)i+1];
            [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@) [状态: %@]", title, SafeString(dz), SafeString(lq), SafeString(tj), ss.length > 0 ? ss : @"无"]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}
%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
%new
- (NSString *)GetStringFromLayer:(id)layer { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator { Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { LogMessage(EchoLogError, @"[错误] 类名 '%@' 未找到。", className); return @""; } NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews); if (targetViews.count == 0) return @""; UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } } return [textParts componentsJoinedByString:separator]; }
%new
- (NSString *)extractTianDiPanInfo_V18 { @try { Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘推衍失败: 找不到视图类"; UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return @"天地盘推衍失败: 找不到keyWindow"; NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘推衍失败: 找不到视图实例"; UIView *plateView = plateViews.firstObject; id diGongDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"], tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"], tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"]; if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘推衍失败: 未能获取核心数据字典"; NSArray *diGongLayers=[diGongDict allValues], *tianShenLayers=[tianShenDict allValues], *tianJiangLayers=[tianJiangDict allValues]; if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘推衍失败: 数据长度不匹配"; NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil]; void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = [layer presentationLayer] ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; CGFloat dx = pos.x - center.x; CGFloat dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": [self GetStringFromLayer:layer], @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } }; processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang"); NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary]; for (NSDictionary *info in allLayerInfos) { BOOL foundGroup = NO; for (NSNumber *angleKey in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angleKey floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angleKey] addObject:info]; foundGroup=YES; break; } } if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];} } NSMutableArray *palaceData = [NSMutableArray array]; for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count < 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; NSString *diPan=@"?", *tianPan=@"?", *tianJiang=@"?"; for(NSDictionary* li in group){ if([li[@"type"] isEqualToString:@"diPan"]) diPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianPan"]) tianPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianJiang"]) tianJiang=li[@"text"]; } [palaceData addObject:@{ @"diPan": diPan, @"tianPan": tianPan, @"tianJiang": tianJiang }]; } if (palaceData.count != 12) return @"天地盘推衍失败: 宫位数据不完整"; NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"]; [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }]; NSMutableString *result = [NSMutableString string]; for (NSDictionary *entry in palaceData) { [result appendFormat:@"- %@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘推衍异常: %@", exception.reason]; } }

%new
- (void)extractShenShaInfo_CompleteWithCompletion:(void (^)(NSString *result))completion {
    NSMutableArray<UISegmentedControl *> *segmentControls = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UISegmentedControl class], self.view, segmentControls);
    if (segmentControls.count == 0) {
        LogMessage(EchoLogError, @"[神煞] 错误: 找不到用于切换的 UISegmentedControl。");
        if (completion) completion(@"[推衍失败: 找不到切换控件]");
        return;
    }
    UISegmentedControl *segmentControl = segmentControls.firstObject;
    NSInteger shenShaIndex = -1;
    for (int i = 0; i < segmentControl.numberOfSegments; i++) {
        if ([[segmentControl titleForSegmentAtIndex:i] containsString:@"神煞"]) { shenShaIndex = i; break; }
    }
    if (shenShaIndex == -1) {
        LogMessage(EchoLogError, @"[神煞] 错误: 在 UISegmentedControl 中找不到 '神煞' 选项。");
        if (completion) completion(@"[推衍失败: 找不到'神煞'选项]");
        return;
    }
    LogMessage(EchoLogTypeInfo, @"[神煞] 找到切换控件，正在切换到 '神煞' (索引 %ld)...", (long)shenShaIndex);
    if (segmentControl.selectedSegmentIndex != shenShaIndex) {
        segmentControl.selectedSegmentIndex = shenShaIndex;
        [segmentControl sendActionsForControlEvents:UIControlEventValueChanged];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        Class shenShaContainerClass = NSClassFromString(@"六壬大占.神煞行年視圖");
        if (!shenShaContainerClass) { if (completion) completion(@"[推衍失败: 找不到容器类]"); return; }

        NSMutableArray *shenShaContainers = [NSMutableArray array];
        FindSubviewsOfClassRecursive(shenShaContainerClass, self.view, shenShaContainers);
        if (shenShaContainers.count == 0) { if (completion) completion(@""); return; }
        UIView *containerView = shenShaContainers.firstObject;
        
        NSMutableArray<UICollectionView *> *collectionViews = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UICollectionView class], containerView, collectionViews);
        if (collectionViews.count == 0) { if (completion) completion(@"[推衍失败: 找不到集合视图]"); return; }
        UICollectionView *collectionView = collectionViews.firstObject;
        
        id<UICollectionViewDataSource> dataSource = collectionView.dataSource;
        if (!dataSource) { if (completion) completion(nil); return; }
        
        NSInteger totalSections = [dataSource respondsToSelector:@selector(numberOfSectionsInCollectionView:)] ? [dataSource numberOfSectionsInCollectionView:collectionView] : 1;
        LogMessage(EchoLogTypeInfo, @"[神煞] 发现 %ld 个 Section，将使用固定标题进行映射...", (long)totalSections);

        NSArray *sectionTitles = @[@"岁煞", @"季煞", @"月煞", @"旬煞", @"干煞", @"支煞"];

        NSMutableString *finalResultString = [NSMutableString string];
        for (NSInteger section = 0; section < totalSections; section++) {
            NSString *title = (section < sectionTitles.count) ? sectionTitles[section] : [NSString stringWithFormat:@"未知分类 %ld", (long)section + 1];
            [finalResultString appendFormat:@"\n// %@\n", title];

            NSInteger totalItemsInSection = [dataSource collectionView:collectionView numberOfItemsInSection:section];
            if(totalItemsInSection == 0) { [finalResultString appendString:@"\n"]; continue; }
            
            NSMutableArray<NSDictionary *> *cellDataList = [NSMutableArray array];
            for (NSInteger item = 0; item < totalItemsInSection; item++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForItem:item inSection:section];
                UICollectionViewCell *cell = [dataSource collectionView:collectionView cellForItemAtIndexPath:indexPath];
                UICollectionViewLayoutAttributes *attributes = [collectionView.collectionViewLayout layoutAttributesForItemAtIndexPath:indexPath];
                if (!cell || !attributes) continue;

                NSMutableArray *labels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.x) compare:@(l2.frame.origin.x)]; }];
                NSMutableArray *textParts = [NSMutableArray array];
                for (UILabel *label in labels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                
                [cellDataList addObject:@{@"textParts": textParts, @"frame": [NSValue valueWithCGRect:attributes.frame]}];
            }
            
            [cellDataList sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) {
                CGRect f1 = [o1[@"frame"] CGRectValue], f2 = [o2[@"frame"] CGRectValue];
                if (roundf(f1.origin.y) < roundf(f2.origin.y)) return NSOrderedAscending;
                if (roundf(f1.origin.y) > roundf(f2.origin.y)) return NSOrderedDescending;
                return [@(f1.origin.x) compare:@(f2.origin.x)];
            }];
            
            NSMutableString *sectionContent = [NSMutableString string];
            CGFloat lastY = -1.0;
            for (NSDictionary *cellData in cellDataList) {
                CGRect frame = [cellData[@"frame"] CGRectValue];
                NSArray *textParts = cellData[@"textParts"];
                if (textParts.count == 0) continue;

                if (lastY >= 0 && roundf(frame.origin.y) > roundf(lastY)) { [sectionContent appendString:@"\n"]; }
                if (sectionContent.length > 0 && ![sectionContent hasSuffix:@"\n"]) { [sectionContent appendString:@" |"]; }

                if (textParts.count == 1) { [sectionContent appendFormat:@"%@:", textParts.firstObject]; }
                else if (textParts.count >= 2) { [sectionContent appendFormat:@" %@(%@)", textParts[0], textParts[1]]; }
                
                lastY = frame.origin.y;
            }
            [finalResultString appendString:sectionContent];
            [finalResultString appendString:@"\n"];
        }
        
        LogMessage(EchoLogTypeSuccess, @"[神煞] 所有 Section 完整推衍成功！");
        if (completion) completion([finalResultString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]);
    });
}
%end


%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo推衍课盘] v19.0 已加载。");
    }
}

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie) {
    if (!rootView) return @"[错误: 根视图为空]";
    
    NSMutableArray *stackViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews);
    
    if (stackViews.count == 0) {
        return @"[错误: 未在课体范式弹窗中找到 UIStackView]";
    }
    
    UIStackView *mainStackView = stackViews.firstObject;
    NSMutableString *finalResult = [NSMutableString string];
    
    for (UIView *subview in mainStackView.arrangedSubviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = [label.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if (!text || text.length == 0) continue;
            
            if ([text isEqualToString:@"详解"]) {
                break;
            }
            
            [finalResult appendFormat:@"%@\n", text];
        }
    }
    
    NSString *cleanedResult = [finalResult stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    while ([cleanedResult containsString:@"\n\n\n"]) {
        cleanedResult = [cleanedResult stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    }
    
    return [cleanedResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

























