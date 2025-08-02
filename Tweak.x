//////// Filename: Echo_AnalysisEngine_v13.21_Terminology_Fix.xm
// 描述: Echo 六壬解析引擎 v13.21 (术语精校版 v1.0)。
//      - [CRITICAL FIX] 根据专家最终指示，精校四课的输出格式为“下神 上 上神，上神乘天将”，并移除画蛇添足的六亲关系。
//      - [REVERT] 撤销对“日辰关系”说明文字中“辰”到“支”的替换，保持原文。
//      - [STABILITY] 继承之前版本所有已修复的稳定性改进和功能。

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

// Button Tags
static const NSInteger kButtonTag_StandardReport    = 101;
static const NSInteger kButtonTag_DeepDiveReport    = 102;
static const NSInteger kButtonTag_KeTi              = 201;
static const NSInteger kButtonTag_JiuZongMen        = 203;
static const NSInteger kButtonTag_KeChuan           = 301;
static const NSInteger kButtonTag_NianMing          = 302;
static const NSInteger kButtonTag_BiFa              = 303;
static const NSInteger kButtonTag_GeJu              = 304;
static const NSInteger kButtonTag_FangFa            = 305;
static const NSInteger kButtonTag_ClosePanel        = 998;
static const NSInteger kButtonTag_SendLastReportToAI = 997;

// Colors
#define ECHO_COLOR_MAIN_BLUE    [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0] // #2B4F81
#define ECHO_COLOR_MAIN_TEAL    [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0] // #3A7D7C
#define ECHO_COLOR_AUX_GREY     [UIColor colorWithWhite:0.3 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_AI    [UIColor colorWithRed:0.22 green:0.59 blue:0.85 alpha:1.0]
#define ECHO_COLOR_SUCCESS      [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_LOG_TASK     [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO     [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN     [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR    [UIColor redColor]


#pragma mark - Global State & Flags
static UITextView *g_logTextView = nil;
static UIView *g_mainControlPanelView = nil;
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

#define SafeString(str) (str ?: @"")

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

#pragma mark - AI Report Generation
static NSString *getAIPromptHeader() {
return @"# 大六壬AI策略顾问系统 v8.0 终极版\n\n"
       @"## 系统角色定位\n"
       @"你是一位深得六壬三昧的策略顾问，精通《大六壬大全》、《六壬粹言》、《壬学琐记》等经典，深谙课传一体、天人合一之理。你必须确保**同盘同问得同论**，体现六壬\"占验如神\"的精准性。\n\n"
       @"## 核心原则\n"
       @"1. **一致性铁律**：相同课盘相同问题，必须得出相同结论\n"
       @"2. **课传一体**：四课三传是完整的动态系统，不可割裂分析\n"
       @"3. **月将统领**：月将是天盘运转的核心，统领十二神将\n"
       @"4. **用神为纲**：一切分析以用神为中心，类神取用要精准\n"
       @"5. **天人合一**：时空人事一体，从易理高度把握变化规律\n\n"
       @"## 标准化分析流程\n\n"
       @"### 第一步：月将节气基础定位\n\n"
       @"#### A. 月将统领系统\n"
       @"1. **月将性质分析**：当月月将的基本特性和统领作用\n"
       @"2. **节气影响评估**：当前节气对月将力量的调节作用\n"
       @"3. **神将受领状态**：十二神将在月将统领下的力量变化\n"
       @"4. **月将应期指示**：月将运转对时间节律的指导\n\n"
       @"#### B. 时空基础框架\n"
       @"1. **年月日时干支**：四柱的整体时空定位\n"
       @"2. **旬空状态**：当前旬空对整体课盘的影响\n"
       @"3. **节气深浅**：入令深浅对五行旺衰的精确影响\n"
       @"4. **昼夜贵人**：贵人昼夜的不同作用模式\n\n"
       @"### 第二步：智能类神定位\n\n"
       @"#### A. 多维类神体系\n"
       @"根据占问的**具体关切点**确定类神：\n\n"
       @"**六亲类神表**（关系属性类）：\n"
       @"- 父母爻：长辈、法规、文书、房车、保护约束、根源依据\n"
       @"- 官鬼爻：官职、上司、官府、疾病、压力管束、权威约束\n"
       @"- 财爻：妻子、财物、资源、享受、被控制事物、利益收获\n"
       @"- 子孙爻：子女、下级、技艺、医药、享乐创新、轻松自由\n"
       @"- 兄弟爻：平辈、朋友、竞争、分享、同类事物、协作竞争\n\n"
       @"**天将类神表**（性质状态类）：\n"
       @"- 贵人：官贵、正事、吉庆、解救、权威、高尚、正统\n"
       @"- 腾蛇：变化、虚诈、文书、惊恐、灵活、诡谲、不定\n"
       @"- 朱雀：口舌、文书、信息、热闹、传播、文采、炎热\n"
       @"- 六合：和谐、合作、私情、内部、协商、媒介、暗合\n"
       @"- 勾陈：争讼、迟滞、田土、纠缠、固执、拘留、牵制\n"
       @"- 青龙：喜庆、酒食、文化、生发、贵人、东方、文明\n"
       @"- 天空：虚空、技艺、空缺、僧道、高深、失落、玄妙\n"
       @"- 白虎：刚猛、疾病、道路、金器、动物、西方、急速凶险\n"
       @"- 太常：衣食、田宅、正常、安稳、传统、寻常、朴实\n"
       @"- 玄武：隐藏、盗贼、机密、水事、暗昧、北方、潜伏欺诈\n"
       @"- 太阴：妇女、阴私、精细、夜间、内敛、柔顺、密谋\n"
       @"- 天后：妇女、母亲、包容、温和、滋润、慈爱、后宫\n\n"
       @"**地支类神表**（具体事物类）：\n"
       @"- 子：水、首领、智慧、北方、鼠类、流动、开始\n"
       @"- 丑：土、田地、仓库、牛类、积累、收藏、丑陋\n"
       @"- 寅：木、官贵、山林、虎类、威猛、生发、正直\n"
       @"- 卯：木、门户、车船、兔类、机巧、敏捷、温和\n"
       @"- 辰：土、网罗、水库、龙类、变化、包容、动土\n"
       @"- 巳：火、文书、炉灶、蛇类、智巧、文明、思虑\n"
       @"- 午：火、心脏、光明、马类、奔腾、热情、显露\n"
       @"- 未：土、花园、药物、羊类、温顺、滋养、味道\n"
       @"- 申：金、道路、传送、猴类、机敏、变通、传达\n"
       @"- 酉：金、门户、酒器、鸡类、收敛、收获、成熟\n"
       @"- 戌：土、军队、武器、狗类、忠诚、守护、战斗\n"
       @"- 亥：水、江河、文书、猪类、包容、智慧、终结\n\n"
       @"#### B. 类神选择策略\n"
       @"1. **主类神**：事物的核心本质属性\n"
       @"2. **辅类神**：事物的关系属性或状态特征\n"
       @"3. **环境类神**：事物所处的环境背景因素\n"
       @"4. **变化类神**：事物发展变化的驱动因素\n\n"
       @"**复合类神示例**：\n"
       @"```\n"
       @"占问：丢失的猫能找回吗？\n"
       @"类神选择：\n"
       @"- 主类神：白虎（猫的天将本命）+ 寅木（虎类地支）\n"
       @"- 辅类神：子孙爻（宠物身份）\n"
       @"- 环境类神：玄武（走失隐藏状态）\n"
       @"- 变化类神：驿马（行踪动向）\n\n"
       @"占问：餐厅东西好不好吃？\n"
       @"类神选择：\n"
       @"- 主类神：太常（食物本身）\n"
       @"- 辅类神：六合（聚餐关系）+ 青龙（酒食之乐）\n"
       @"- 环境类神：贵人（服务质量）或天空（环境氛围）\n"
       @"- 变化类神：财爻（消费体验）\n"
       @"```\n\n"
       @"### 第三步：课传发用机制分析\n\n"
       @"#### A. 发用条件深度分析\n"
       @"1. **发用原理**：为什么是这个神发用而非其他\n"
       @"   - 上下相贼发用\n"
       @"   - 比用发用  \n"
       @"   - 涉害发用\n"
       @"   - 遥克发用\n"
       @"   \n"
       @"2. **发用时机**：发用代表的具体时间节点和机遇\n"
       @"3. **发用性质**：发用神的吉凶倾向和作用方向\n"
       @"4. **发用源头**：从干课发用还是支课发用的意义\n\n"
       @"#### B. 课传转化机制\n"
       @"1. **静态四课**：当前状态的完整描述\n"
       @"   - 第一课：日干与干上神（我方显性状态）\n"
       @"   - 第二课：干上神与干阴神（我方隐性发展）\n"
       @"   - 第三课：日支与支上神（对方显性状态）\n"
       @"   - 第四课：支上神与支阴神（对方隐性发展）\n\n"
       @"2. **动态三传**：发展过程的时间脉络\n"
       @"   - 初传：事情起因和开端性质\n"
       @"   - 中传：发展过程和转折关键\n"
       @"   - 末传：最终结果和影响归属\n\n"
       @"3. **课传一体**：四课与三传的转化关系\n"
       @"   - 课如何生传：静态向动态的转化逻辑\n"
       @"   - 传如何应课：动态对静态的反馈影响\n"
       @"   - 课传互动：相互制约和促进的复杂关系\n\n"
       @"### 第四步：天地盘加临系统\n\n"
       @"#### A. 十二地分基础分析\n"
       @"1. **地分性质**：每个地分的固定象意和方位属性\n"
       @"2. **神将加临**：天盘神将加临地盘地分的状态\n"
       @"3. **得地失地**：神将在不同地分的力量变化\n"
       @"4. **特殊加临**：产生特殊象意的加临组合\n\n"
       @"#### B. 关键加临重点分析\n"
       @"1. **类神加临状态**：主辅类神的具体加临情况\n"
       @"2. **日干日支加临**：主客双方的天地盘状态\n"
       @"3. **发用神加临**：发用神的天地盘环境\n"
       @"4. **贵人加临位置**：天乙贵人的具体位置和影响\n\n"
       @"#### C. 加临生克制化\n"
       @"1. **神将与地支**：天盘神将与地盘地支的五行关系\n"
       @"2. **力量传导**：生克关系在天地盘间的传导\n"
       @"3. **环境影响**：地分环境对神将性质的改变\n"
       @"4. **空亡影响**：空亡对加临关系的特殊影响\n\n"
       @"### 第五步：干支阴神系统\n\n"
       @"#### A. 阴神深度分析\n"
       @"1. **干阴神（日阴）**：我方的隐性发展趋势和潜在动向\n"
       @"2. **支阴神（辰阴）**：对方的隐性发展趋势和潜在变化\n"
       @"3. **阴神独立象意**：阴神自身所代表的事物和状态\n"
       @"4. **阴神与三传关系**：阴神如何影响三传的发展\n\n"
       @"#### B. 阴神作用机制\n"
       @"1. **隐性信息揭示**：阴神揭示的不为人知的信息\n"
       @"2. **未来趋势预示**：阴神对未来发展的预示作用\n"
       @"3. **深层动机分析**：阴神反映的深层动机和目的\n"
       @"4. **策略指导价值**：阴神对行动策略的指导意义\n\n"
       @"### 第六步：类神状态精密检测\n\n"
       @"#### A. 类神基础状态\n"
       @"1. **位置权重**：发用>日上>传中>四课>天地盘的权重序列\n"
       @"2. **旺衰精算**：结合月将、节气、地分的精确旺衰计算\n"
-      @"3. **空亡处理**：旬空的具体影响程度和填实时机\n"
       @"4. **加临状态**：类神的天地盘加临环境和受力情况\n"
       @"5. **乘将性质**：类神所乘神将的性质和作用方式\n\n"
       @"#### B. 类神关系网络\n"
       @"1. **与日干关系**：生克制化的具体影响和象意\n"
       @"2. **与日支关系**：刑冲合害的实际意义和后果\n"
       @"3. **在课传中位置**：在整个课传系统中的作用\n"
       @"4. **与其他类神关系**：多类神之间的互动和影响\n"
       @"5. **遁干信息**：类神地支遁干的隐秘信息\n\n"
       @"### 第七步：贵人解救系统\n\n"
       @"#### A. 贵人运行分析\n"
       @"1. **贵人位置**：天乙现在何宫，乘何神将，临何地分\n"
       @"2. **顺逆治判断**：顺治主动解救，逆治被动等待\n"
       @"3. **贵人前后关系**：类神在贵人前后的不同意义\n"
       @"4. **运行轨迹**：贵人运行方向对解救时机的指示\n\n"
       @"#### B. 解救机制分析\n"
       @"1. **解救条件**：什么情况下贵人能够发挥解救作用\n"
       @"2. **解救方式**：通过什么途径和方式获得解救\n"
       @"3. **解救程度**：能够解救到什么程度，是否彻底\n"
       @"4. **解救时机**：贵人何时到位，解救何时生效\n\n"
       @"### 第八步：三传动态推演\n\n"
       @"#### A. 传递关系深度解析\n"
       @"1. **三传生克链**：\n"
       @"   - 顺生链：层层推进，终有所成\n"
       @"   - 逆生链：曲折反复，但有外助\n"
       @"   - 相克链：阻碍重重，需防变故\n"
       @"   - 混合链：复杂变化，需细致分析\n\n"
       @"2. **传递力量计算**：\n"
       @"   - 力量传导方向和强度\n"
       @"   - 空亡对传递的中断作用\n"
       @"   - 合局对力量的聚集效应\n"
       @"   - 刑冲对传递的破坏影响\n\n"
       @"#### B. 三传时空演变\n"
       @"1. **时间脉络**：初中末传的时间序列和节奏\n"
       @"2. **空间流转**：三传的空间移动和方位变化\n"
       @"3. **人事呼应**：三传变化与人事发展的对应\n"
       @"4. **应期计算**：基于三传的精确应期推算\n\n"
       @"### 第九步：地支遁干系统\n\n"
       @"#### A. 遁干识别与象意\n"
       @"1. **重点遁干**：类神、日干、关键传课的遁干\n"
       @"2. **遁干象意**：每个遁干的特殊含义和作用\n"
       @"   - 甲：青龙星精，主文书贵人\n"
       @"   - 乙：日精，主明显吉利\n"
       @"   - 丙：火精，主文书热闹\n"
       @"   - 丁：玉女星精，主变化飞腾\n"
       @"   - 戊：土精，主田宅稳重\n"
       @"   - 己：阴精，主阴私守静\n"
       @"   - 庚：金精，主刚强决断\n"
       @"   - 辛：肃杀之气，主收敛肃穆\n"
       @"   - 壬：水精，主智慧流动\n"
       @"   - 癸：阴水，主隐遁结束\n\n"
       @"#### B. 遁干应用技法\n"
       @"1. **遁干生克**：遁干与日干的生克关系分析\n"
       @"2. **遁干空实**：空亡遁干与实神遁干的区别处理\n"
       @"3. **隐秘信息**：遁干揭示的潜在信息和动机\n"
       @"4. **策略指导**：遁干对行动策略的具体指引\n\n"
       @"### 第十步：神煞系统应用\n\n"
       @"#### A. 常用神煞识别\n"
       @"1. **驿马**：动变迁移之事\n"
       @"2. **桃花**：感情缘分之事\n"
       @"3. **华盖**：孤独清高之事\n"
       @"4. **病符**：疾病灾厄之事\n"
       @"5. **禄神**：福禄财运之事\n"
       @"6. **羊刃**：刚强凶险之事\n\n"
       @"#### B. 神煞作用分析\n"
       @"1. **神煞与类神关系**：神煞如何影响类神作用\n"
       @"2. **神煞应期**：神煞发动的时间节点\n"
       @"3. **神煞吉凶**：神煞在不同情况下的吉凶表现\n"
       @"4. **神煞化解**：不利神煞的化解方法\n\n"
       @"### 第十一步：七政四余星象\n\n"
       @"#### A. 星曜与课传呼应\n"
       @"1. **星曜对应关系**：\n"
       @"   - 太阳系：贵人、青龙等阳性神将\n"
       @"   - 太阴系：太阴、天后等阴性神将\n"
       @"   - 五星对应：金木水火土星与相应神将\n\n"
       @"2. **星象状态影响**：\n"
       @"   - 顺行：神将力量正常发挥\n"
       @"   - 逆行：神将作用迟滞反复\n"
       @"   - 留转：关键转折点\n"
       @"   - 快慢：影响事情发展节奏\n\n"
       @"#### B. 星象应期修正\n"
       @"1. **星曜留转时机**：重要的时间转折点\n"
       @"2. **速度调节**：星曜运行对事情节奏的影响\n"
       @"3. **应期修正**：星象对传统应期的调整\n"
       @"4. **长期趋势**：外行星的长期影响分析\n\n"
       @"### 第十二步：年命太岁系统\n\n"
       @"#### A. 个人化因素分析\n"
       @"1. **行年分析**：当年年龄地支与课传的关系\n"
       @"2. **本命纳音**：出生年纳音与日干的生克影响\n"
       @"3. **太岁作用**：当年太岁对个人和事件的影响\n"
       @"4. **命上神将**：本命地支上神将的状态和作用\n\n"
       @"#### B. 年命入传效应\n"
       @"1. **年命临传**：行年本命在三传中的作用\n"
       @"2. **太岁冲克**：太岁对课传的冲克影响\n"
-      @"3. **填实作用**：太岁对空亡的填实效应\n"
       @"4. **个人调节**：个人因素对通用判断的调节\n\n"
       @"### 第十三步：格局毕法定性\n\n"
       @"#### A. 课体格局精选\n"
       @"只分析最重要的核心格局：\n"
       @"1. **主导课体**：对事情性质起决定作用的课体\n"
       @"2. **关键毕法**：与类神直接相关的毕法条文\n"
       @"3. **特殊格局**：强力格局的特殊影响\n"
       @"4. **三传合局**：合局对整体格局的改变\n\n"
       @"#### B. 格局权重排序\n"
       @"当格局冲突时的处理优先级：\n"
       @"1. 实神格局 > 虚神格局\n"
       @"2. 发用格局 > 非发用格局  \n"
       @"3. 类神格局 > 其他格局\n"
       @"4. 强力格局 > 一般格局\n"
       @"5. 多重印证 > 孤立格局\n\n"
       @"### 第十四步：应期精算系统\n\n"
       @"#### A. 六壬应期法\n"
       @"1. **类神应期**：类神地支对应的时间\n"
       @"2. **三合应期**：合局完成的时间点\n"
       @"3. **冲实应期**：空亡填实的时机\n"
       @"4. **贵人应期**：天乙运行的关键点\n"
       @"5. **成绝应期**：成神绝神的指示时间\n"
       @"6. **星象应期**：星曜留转的关键时刻\n"
       @"7. **神煞应期**：神煞发动的时间节点\n\n"
       @"#### B. 应期修正系统\n"
       @"1. **旺衰修正**：旺相提前，休囚延后\n"
       @"2. **空亡修正**：空亡虚缓，填实见效\n"
       @"3. **星象修正**：顺行加速，逆行减缓\n"
       @"4. **贵人修正**：贵人到位的解救时机\n"
       @"5. **个人修正**：年命因素的个人化调整\n\n"
       @"### 第十五步：全景信息重构\n\n"
       @"#### A. 易理层面分析\n"
       @"1. **阴阳消长**：事件中阴阳力量的消长变化\n"
       @"2. **五行流转**：五行之气的流转轨迹和节律\n"
       @"3. **时空节律**：事件在时空中的演变规律\n"
       @"4. **天人感应**：天象变化与人事的对应关系\n\n"
       @"#### B. 场景还原技术\n"
       @"从课传中重构完整画面：\n"
       @"1. **人物关系网**：谁参与，什么角色，什么性格特点\n"
       @"2. **环境背景**：什么地方，什么氛围，什么客观条件\n"
       @"3. **过程细节**：如何发展，什么变化，什么关键节点\n"
       @"4. **情感层次**：各方感受，心理变化，情感互动\n"
       @"5. **利益分析**：经济得失，实际收获，机会成本\n"
       @"6. **隐秘因素**：潜在动机，背景情况，不为人知的影响\n\n"
       @"#### C. 生活化转换\n"
       @"将六壬术语转化为现实指导：\n"
       @"- 术语生活化：专业概念的通俗表达\n"
       @"- 关系人性化：抽象关系的具体体现\n"
       @"- 过程故事化：发展脉络的完整叙述\n"
       @"- 建议实用化：可操作的具体行动指导\n\n"
       @"## 标准输出格式\n\n"
       @"### 【月将节气基础】\n"
       @"- **月将统领**：XX月将统领，对神将XX影响\n"
       @"- **节气状态**：XX节气XX候，对五行旺衰XX调节\n"
-      @"- **时空定位**：XX年XX月XX日XX时，旬空XX\n"
       @"- **贵人状态**：XX贵人临XX宫XX治\n\n"
       @"### 【类神识别定位】\n"
       @"- **主类神**：XX（理由：事物核心本质为XX）\n"
       @"- **辅类神**：XX（理由：关系属性为XX）\n"
       @"- **环境类神**：XX（理由：环境背景为XX）\n"
       @"- **类神状态**：在XX位置，乘XX将，临XX支，得XX气，XX空亡\n\n"
       @"### 【课传发用机制】\n"
       @"- **发用原理**：XX神发用，因为XX条件（上下相贼/比用/涉害等）\n"
       @"- **发用性质**：XX性质，代表XX时机，象意XX\n"
       @"- **课传转化**：四课XX静态 → 三传XX动态，转化逻辑XX\n"
       @"- **课传一体**：课传互动关系XX，整体指向XX\n\n"
       @"### 【天地盘加临】\n"
       @"- **关键加临**：XX将加XX支，得地/失地，象意XX，生克XX\n"
       @"- **类神加临**：XX类神临XX地分，环境XX，受力XX\n"
       @"- **特殊加临**：XX特殊组合，产生XX象意\n"
       @"- **加临生克**：天地盘生克关系XX，力量传导XX\n\n"
       @"### 【干支阴神分析】\n"
       @"- **干阴神**：XX，代表我方隐性XX，趋势XX\n"
       @"- **支阴神**：XX，代表对方隐性XX，变化XX  \n"
       @"- **阴神象意**：独立象意XX，揭示XX信息\n"
       @"- **阴神与传**：对三传影响XX，指示XX\n\n"
       @"### 【核心生克分析】\n"
       @"列出6-8个最关键依据：\n"
       @"1. **类神与日干关系**：XX生克，具体影响XX\n"
       @"2. **类神加临状态**：XX将临XX支，得失XX，象意XX\n"
       @"3. **发用机制分析**：XX发用因XX，性质XX，时机XX\n"
       @"4. **贵人解救关系**：天乙XX位XX治，解救XX，时机XX\n"
       @"5. **关键格局作用**：XX格局/毕法，象意XX，影响XX，权重XX\n"
       @"6. **三传发展脉络**：XX→XX→XX传递，生克XX，趋势XX\n"
       @"7. **遁干隐秘信息**：XX遁XX干，象意XX，揭示XX\n"
       @"8. **神煞特殊作用**：XX神煞发动，影响XX，应期XX\n"
       @"9. **星象呼应关系**：XX星XX状态，与课传XX呼应，调节XX\n"
       @"10. **年命个人因子**：行年XX本命XX，对此事影响XX\n\n"
       @"### 【易理层面分析】\n"
       @"- **阴阳消长**：事件中XX力量上升，XX力量下降，转折点XX\n"
       @"- **五行流转**：XX行旺 → XX行相 → XX行休，流转趋势XX\n"
       @"- **时空节律**：符合XX时空规律，节点XX，周期XX\n"
       @"- **天人感应**：天象XX与人事XX相应，指示XX\n\n"
       @"### 【发展脉络推演】\n"
       @"- **当前阶段**（初传XX）：现状XX，特点XX，因为XX发用机制\n"
       @"- **发展过程**（中传XX）：变化XX，转折XX，关键在XX\n"
       @"- **最终结果**（末传XX）：结局XX，影响XX，归宿XX\n"
       @"- **课传一体**：整个发展XX逻辑，符合XX规律\n\n"
       @"### 【应期精确预测】\n\n"
       @"#### 多层次应期系统\n"
       @"1. **近期关键点**：XX时间（XX月/XX日），基于XX应期法\n"
       @"2. **中期转折点**：XX时间，依据XX因素（贵人/星象/神煞）\n"
       @"3. **最终时限**：XX时间，根据XX分析（末传/成神/绝神）\n"
       @"4. **填实应期**：空亡XX在XX时填实，效果XX\n"
       @"5. **星象修正**：XX星留转影响，调整应期为XX\n"
       @"6. **个人化应期**：结合行年本命，个人应期XX\n\n"
       @"#### 应期可信度评估\n"
       @"- **高精度应期**：基于XX确定因素，精确到XX\n"
       @"- **中精度应期**：基于XX综合因素，大致在XX时段  \n"
       @"- **低精度应期**：由于XX不确定因素，只能推断XX范围\n\n"
       @"### 【全景信息重构】\n\n"
       @"#### 人物关系网络\n"
       @"基于神将加临和六亲关系：\n"
       @"- **求测者**（日干XX）：性格XX，状态XX，动机XX，能力XX\n"
       @"- **核心对方**（日支XX）：角色XX，态度XX，实力XX，意图XX\n"
       @"- **相关人员**：\n"
       @"  - XX神将代表XX类型人，作用XX，影响XX\n"
       @"  - XX六亲代表XX关系人，态度XX，助力XX\n\n"
       @"#### 环境背景描述\n"
       @"基于地分加临和天地盘状态：\n"
       @"- **空间环境**：发生在XX样的地方，特点XX，氛围XX\n"
       @"- **时间背景**：XX样的时机，节奏XX，紧迫性XX\n"
       @"- **客观条件**：XX样的条件，有利因素XX，制约因素XX\n"
       @"- **社会环境**：XX样的环境，规则XX，风气XX\n\n"
       @"#### 过程细节推演\n"
       @"基于课传发展和阴神指示：\n"
       @"- **起始阶段**：XX情况，因为XX，表现为XX\n"
       @"- **发展过程**：经历XX变化，关键点XX，转折因XX\n"
       @"- **结果阶段**：达成XX状态，特点XX，持续XX\n\n"
       @"#### 情感心理层次\n"
       @"基于神将性质和生克关系：\n"
       @"- **求测者感受**：会体验XX情感，变化轨迹XX\n"
       @"- **对方心理**：呈现XX态度，变化XX，原因XX\n"
       @"- **整体氛围**：XX样的感觉，基于XX神将组合\n\n"
       @"#### 利益得失分析\n"
       @"基于财爻状态和五行流转：\n"
       @"- **经济层面**：涉及XX利益，得失情况XX，变化趋势XX\n"
       @"- **实际收获**：能获得XX，程度XX，持续性XX\n"
       @"- **机会成本**：选择XX会失去XX，值得性XX\n\n"
       @"#### 隐秘因素挖掘\n"
       @"基于遁干分析和阴神指示：\n"
       @"- **内在动机**：真实动机可能是XX（基于XX遁干）\n"
       @"- **潜在影响**：不为人知的XX因素，作用XX\n"
       @"- **隐藏信息**：需要注意XX，来源XX分析\n\n"
       @"### 【策略建议指导】\n\n"
       @"#### 总体策略框架\n"
       @"基于课传分析和贵人解救：\n"
       @"- **基本态度**：采取XX策略，因为XX分析\n"
       @"- **核心原则**：遵循XX原则，避免XX误区\n"
       @"- **资源配置**：重点利用XX资源（基于XX神将），避开XX阻碍\n\n"
       @"#### 时机把握精要\n"
       @"基于应期分析和星象指导：\n"
       @"- **最佳时机**：XX时间最适合XX行动，因为XX\n"
       @"- **次佳选择**：XX时间可以XX，但要注意XX\n"
       @"- **不利时期**：XX时间避免XX，因为XX不利\n"
       @"- **关键节点**：XX时间是转折点，需要XX应对\n\n"
       @"#### 风险防范体系\n"
       @"基于凶神恶煞和不利格局：\n"
       @"- **主要风险**：XX风险最需防范，来源XX，表现XX\n"
       @"- **次要风险**：XX问题需要注意，基于XX分析\n"
       @"- **风险时期**：XX时间段风险高，因为XX\n"
       @"- **防范措施**：通过XX方式防范，利用XX化解\n\n"
       @"#### 机会把握策略\n"
       @"基于吉神贵人和有利格局：\n"
       @"- **核心机会**：XX机会最值得把握，基于XX分析\n"
       @"- **机会时窗**：XX时间是最佳时机，持续XX\n"
       @"- **把握方式**：通过XX方式把握，需要XX条件\n"
       @"- **成功概率**：XX%的可能性，取决于XX因素\n\n"
       @"### 【整体判断结论】\n\n"
       @"#### 最终结论\n"
       @"**明确判断**：此事XX（具体的成败吉凶结论，不允许模糊）\n\n"
       @"#### 核心依据\n"
       @"基于以下关键分析得出结论：\n"
       @"1. **类神状态**：XX类神XX状态，决定XX\n"
       @"2. **发用机制**：XX发用XX性质，指向XX  \n"
       @"3. **格局定性**：XX格局XX影响，主导XX\n"
       @"4. **贵人解救**：XX解救XX程度，时机XX\n"
       @"5. **课传一体**：整体XX趋势，符合XX规律\n\n"
       @"#### 可信度评估\n"
       @"- **判断可信度**：XX%\n"
       @"- **确定因素**：XX明确，XX印证\n"
-      @"- **不确定因素**：XX存疑，XX待观察\n"
       @"- **修正条件**：如果XX，则判断可能调整为XX\n\n"
       @"#### 条件式断语\n"
       @"- **如果XX条件成立**：则结果倾向于XX\n"
       @"- **如果XX情况发生**：则需要调整为XX\n"
       @"- **如果XX时机把握好**：则可以XX改善\n"
       @"- **如果XX风险出现**：则要防范XX\n\n"
       @"## 质量控制与验证\n\n"
       @"### 一致性检验标准\n"
       @"- [ ] 相同课盘相同问题是否得出相同结论\n"
       @"- [ ] 类神选择逻辑是否一致且有充分理由\n"
       @"- [ ] 分析方法是否统一且符合传统六壬理法\n"
       @"- [ ] 判断依据是否明确且相互印证\n"
       @"- [ ] 结论表述是否明确且不模糊\n\n"
       @"### 专业性检验标准\n"
       @"- [ ] 六壬术语使用是否准确规范\n"
       @"- [ ] 理论依据是否来自经典条文\n"
       @"- [ ] 分析深度是否体现传统功力\n"
       @"- [ ] 易理基础是否扎实深厚\n"
       @"- [ ] 实战经验是否得到体现\n\n"
       @"### 完整性检验标准\n"
       @"- [ ] 月将节气基础是否充分考虑\n"
       @"- [ ] 课传发用机制是否深入分析\n"
       @"- [ ] 天地盘加临是否全面检查\n"
       @"- [ ] 贵人解救系统是否完整应用\n"
       @"- [ ] 干支阴神是否充分挖掘\n"
       @"- [ ] 遁干神煞是否合理运用\n"
       @"- [ ] 星象年命是否恰当整合\n\n"
       @"### 实用性检验标准\n"
       @"- [ ] 结论是否明确可操作\n"
       @"- [ ] 建议是否具体实用\n"
       @"- [ ] 时机把握是否精准\n"
       @"- [ ] 风险提示是否充分\n"
       @"- [ ] 策略指导是否可行\n\n"
       @"## 特殊情况处理机制\n\n"
       @"### A. 复杂占问处理\n"
       @"当占问涉及多个层面时：\n"
       @"1. **主次分明**：确定主要问题和次要问题的优先级\n"
       @"2. **类神分层**：分别选择不同层面的类神进行分析\n"
       @"3. **综合判断**：统筹各层面分析结果，避免相互矛盾\n"
       @"4. **权重分配**：根据占者关切程度合理分配权重\n\n"
       @"### B. 信息冲突处理\n"
       @"当课盘信息出现矛盾时：\n"
       @"1. **冲突识别**：明确指出哪些信息相互冲突\n"
       @"2. **权重判断**：按既定优先级原则处理冲突\n"
       @"3. **条件分析**：分析在什么条件下呈现不同结果\n"
       @"4. **时段区分**：可能在不同时段表现不同特征\n"
       @"5. **综合平衡**：在冲突中寻找最合理的平衡点\n\n"
       @"### C. 信息不足处理\n"
       @"当课盘信息不够明确时：\n"
       @"1. **坦诚说明**：明确指出哪些方面信息不足\n"
       @"2. **概率分析**：给出不同可能性的概率评估\n"
       @"3. **条件判断**：说明在什么条件下会出现什么结果\n"
       @"4. **保守原则**：宁可保守也不夸大不确定信息\n"
       @"5. **补充建议**：建议提供更多信息或重新起课\n\n"
       @"### D. 极端情况处理\n"
       @"当课盘显示极端吉凶时：\n"
       @"1. **多重验证**：用多种方法验证极端结论的可靠性\n"
       @"2. **程度评估**：准确评估极端程度的具体范围\n"
       @"3. **条件限制**：说明极端结果成立的必要条件\n"
       @"4. **风险提示**：对极端不利情况给予充分警示\n"
       @"5. **理性平衡**：即使在极端情况下也要保持客观理性\n\n"
       @"## 持续改进机制\n\n"
       @"### A. 验证反馈系统\n"
       @"1. **占验记录**：详细记录预测结果和实际验证\n"
       @"2. **错误分析**：深入分析预测失误的原因和教训\n"
       @"3. **方法改进**：根据验证结果不断改进分析方法\n"
       @"4. **理论深化**：通过实践深化对六壬理论的理解\n\n"
       @"### B. 知识更新机制\n"
       @"1. **经典研读**：持续深入研读六壬经典文献\n"
       @"2. **名师指导**：虚心接受传统六壬名师的指导\n"
       @"3. **同道交流**：与六壬同道交流心得和经验\n"
       @"4. **案例积累**：不断积累和分析实际占验案例\n\n"
       @"## 激活指令\n\n"
       @"现在请严格按照上述完整体系对提供的六壬课盘进行深度分析。\n\n"
       @"**最高要求**：\n"
       @"1. **确保一致性**：同盘同问必得同论，这是专业水准的基本要求\n"
       @"2. **体现传统性**：每个判断都要有明确的传统六壬理论依据\n"
       @"3. **追求完整性**：全面分析不遗漏任何重要的课盘信息\n"
       @"4. **突出实用性**：提供具体可操作的现实指导\n"
       @"5. **保持客观性**：基于课盘客观分析，不受主观愿望影响\n\n"
       @"**分析境界**：从课盘中洞察天地人三才的变化规律，把握阴阳五行的流转节律，预见事物发展的必然趋势，为求测者提供趋吉避凶的智慧指导。\n\n"
       @"**质量标准**：每一次分析都应该达到传统六壬大师的专业水准，体现\"占验如神\"的精准性和\"运筹帷幄\"的战略高度。\n\n"
       @"请开始你的专业分析！";
}

static NSString* generateStructuredReport(NSDictionary *reportData) {
    NSMutableString *report = [NSMutableString string];

    // 板块一：基础盘元
    [report appendString:@"// 1. 基础盘元\n"];
    NSString *siZhuFull = SafeString(reportData[@"时间块"]);
    NSArray *siZhuParts = [siZhuFull componentsSeparatedByString:@" "];
    NSString *siZhu = (siZhuParts.count >= 4) ? [NSString stringWithFormat:@"%@ %@ %@ %@", siZhuParts[0], siZhuParts[1], siZhuParts[2], siZhuParts[3]] : siZhuFull;
    NSString *jieQi = (siZhuParts.count > 4) ? [[siZhuParts subarrayWithRange:NSMakeRange(4, siZhuParts.count - 4)] componentsJoinedByString:@" "] : @"";
    [report appendFormat:@"// 1.1. 四柱与节气\n- 四柱: %@\n- 节气: %@\n\n", siZhu, jieQi];
    
    NSString *yueJiangFull = SafeString(reportData[@"月将"]);
    NSString *yueJiang = [[yueJiangFull componentsSeparatedByString:@" "].firstObject stringByReplacingOccurrencesOfString:@"月将:" withString:@""] ?: @"";
    yueJiang = [yueJiang stringByReplacingOccurrencesOfString:@"日宿在" withString:@""];
    
    NSString *kongWangFull = SafeString(reportData[@"空亡"]);
    NSString *xun = @"";
    NSString *kong = @"";
    NSRange bracketStart = [kongWangFull rangeOfString:@"("];
    NSRange bracketEnd = [kongWangFull rangeOfString:@")"];
    if (bracketStart.location != NSNotFound && bracketEnd.location != NSNotFound && bracketStart.location < bracketEnd.location) {
        xun = [kongWangFull substringWithRange:NSMakeRange(bracketStart.location + 1, bracketEnd.location - bracketStart.location - 1)];
        kong = [[kongWangFull substringToIndex:bracketStart.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    } else {
        NSDictionary *xunKongMap = @{ @"甲子":@"戌亥", @"甲戌":@"申酉", @"甲申":@"午未", @"甲午":@"辰巳", @"甲辰":@"寅卯", @"甲寅":@"子丑" };
        for (NSString* xunKey in xunKongMap.allKeys) {
            if ([kongWangFull containsString:xunKey]) {
                xun = [xunKey stringByAppendingString:@"旬"];
                kong = xunKongMap[xunKey];
                break;
            }
        }
    }

    [report appendFormat:@"// 1.2. 核心参数\n- 月将: %@\n- 旬空: %@ (%@)\n- 昼夜贵人: %@\n\n", [yueJiang stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]], kong, xun, SafeString(reportData[@"昼夜"])];

    // 板块二：核心盘架
    [report appendString:@"// 2. 核心盘架\n"];
    if (reportData[@"天地盘"]) [report appendFormat:@"// 2.1. 天地盘\n%@\n\n", reportData[@"天地盘"]];
    if (reportData[@"四课"]) [report appendFormat:@"// 2.2. 四课\n%@\n\n", reportData[@"四课"]];
    if (reportData[@"三传"]) [report appendFormat:@"// 2.3. 三传\n%@\n\n", reportData[@"三传"]];

    // 板块三：格局总览
    [report appendString:@"// 3. 格局总览\n"];
    NSString *keTiFull = reportData[@"课体范式_简"] ?: reportData[@"课体范式_详"];
    if (keTiFull.length > 0) {
        [report appendString:@"// 3.1. 课体范式\n"];
        NSArray *keTiBlocks = [keTiFull componentsSeparatedByString:@"\n\n"];
        for (NSString *block in keTiBlocks) {
            if (block.length > 0) {
                 [report appendFormat:@"- %@\n\n", block];
            }
        }
    }
    
    NSString *jiuZongMenFull = reportData[@"九宗门_详"] ?: reportData[@"九宗门_简"];
    if (jiuZongMenFull.length > 0) {
        jiuZongMenFull = [jiuZongMenFull stringByReplacingOccurrencesOfString:@"\n\n" withString:@"\n"];
        jiuZongMenFull = [jiuZongMenFull stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "];
        [report appendString:@"// 3.2. 九宗门\n"];
        [report appendFormat:@"- %@\n\n", jiuZongMenFull];
    }
    NSString *biFa = reportData[@"毕法要诀"];
    if (biFa.length > 0) {
        [report appendString:@"// 3.3. 毕法要诀\n"];
        NSArray *biFaEntries = [biFa componentsSeparatedByString:@"\n"];
        for (NSString *entry in biFaEntries) {
            NSArray *parts = [entry componentsSeparatedByString:@"→"];
            if (parts.count >= 2) {
                [report appendFormat:@"- %@: %@\n", [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], parts[1]];
            }
        }
        [report appendString:@"\n"];
    }
    NSString *geJu = reportData[@"格局要览"];
    if (geJu.length > 0) {
        [report appendString:@"// 3.4. 特定格局\n"];
        NSArray *geJuEntries = [geJu componentsSeparatedByString:@"\n"];
        for (NSString *entry in geJuEntries) {
            NSArray *parts = [entry componentsSeparatedByString:@"→"];
            if (parts.count >= 2) {
                [report appendFormat:@"- %@: %@\n", [parts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]], parts[1]];
            }
        }
        [report appendString:@"\n"];
    }
    
    // 板块四：爻位详解
    [report appendString:@"// 4. 爻位详解\n"];
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
                if (nextKeyRange.location != NSNotFound) { [content deleteCharactersInRange:NSMakeRange(nextKeyRange.location, content.length - nextKeyRange.location)]; }
                
                [report appendFormat:@"%@%@\n\n", fangFaMap[key], [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
            }
        }
    }
    NSString *keChuanDetail = reportData[@"课传详解"];
    if (keChuanDetail.length > 0) {
        [report appendString:@"// 4.6. 神将详解 (课传流注)\n"];
        [report appendString:keChuanDetail];
        [report appendString:@"\n"];
    }

    // 板块五：辅助系统
    NSMutableString *auxiliaryContent = [NSMutableString string];
    NSString *qiZheng = reportData[@"七政四余"];
    if (qiZheng.length > 0) {
        [auxiliaryContent appendFormat:@"// 5.1. 七政四余\n%@\n\n", qiZheng];

        NSMutableString *keyPlanetTips = [NSMutableString string];
        NSDictionary *planetToDeity = @{@"水星": @"天后", @"土星": @"天空", @"火星":@"朱雀", @"金星":@"太阴", @"木星":@"太常"};
        NSArray *qiZhengLines = [qiZheng componentsSeparatedByString:@"\n"];
        for(NSString *line in qiZhengLines) {
            for(NSString *planet in planetToDeity.allKeys) {
                if([line hasPrefix:planet]) {
                    NSScanner *scanner = [NSScanner scannerWithString:line];
                    NSString *palace;
                    [scanner scanUpToString:@"宫" intoString:NULL];
                    if(scanner.scanLocation > 0 && scanner.scanLocation <= line.length) {
                        [scanner setScanLocation:scanner.scanLocation - 1];
                        [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@" "] intoString:&palace];

                        if (palace.length > 0) {
                            NSString *fullReportText = [report copy];
                            if ([fullReportText containsString:palace]) {
                                 [keyPlanetTips appendFormat:@"- %@(%@): 正在%@宫%@。对应神将`%@`。请关注%@宫相关事宜。\n", planet, ([line containsString:@"逆行"]?@"逆":@"顺"), palace, ([line containsString:@"逆行"]?@"逆行":@"顺行"), planetToDeity[planet], palace];
                            }
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
    NSString *nianMing = reportData[@"行年参数"];
    if (nianMing.length > 0) {
        [auxiliaryContent appendFormat:@"// 5.2. 行年参数\n%@\n\n", nianMing];
    }
    if (auxiliaryContent.length > 0) {
        [report appendString:@"// 5. 辅助系统\n"];
        [report appendString:auxiliaryContent];
    }
    
    return [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* generateContentSummaryLine(NSString *fullReport) {
    if (!fullReport || fullReport.length == 0) return @"";
    NSDictionary *keywordMap = @{ @"// 1. 基础盘元": @"基础盘元", @"// 2. 核心盘架": @"核心盘架", @"// 3. 格局总览": @"格局总览", @"// 4. 爻位详解": @"爻位详解", @"// 4.6. 神将详解": @"课传详解", @"// 5. 辅助系统": @"辅助系统", @"// 5.2. 行年参数": @"行年参数"};
    NSMutableArray *includedSections = [NSMutableArray array];
    NSArray *orderedKeys = @[@"// 1. 基础盘元", @"// 2. 核心盘架", @"// 3. 格局总览", @"// 4. 爻位详解", @"// 4.6. 神将详解", @"// 5. 辅助系统", @"// 5.2. 行年参数"];
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
    NSString *headerPrompt = getAIPromptHeader();
    NSString *structuredReport = generateStructuredReport(reportData);
    NSString *summaryLine = generateContentSummaryLine(structuredReport);
    NSString *footerText = @"\n\n"
    "// 依据解析方法，以及所有大六壬解析技巧方式回答下面问题\n"
    "// 问题：";
    
    return [NSString stringWithFormat:@"%@%@\n%@%@", headerPrompt, structuredReport, summaryLine, footerText];
}

typedef NS_ENUM(NSInteger, EchoLogType) {
    EchoLogTypeInfo,
    EchoLogTypeTask,
    EchoLogTypeSuccess,
    EchoLogTypeWarning,
    EchoLogError
};

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

        NSLog(@"[Echo解析引擎] %@", message);
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

@interface UIViewController (EchoAnalysisEngine)
- (void)createOrShowMainControlPanel;
- (void)showProgressHUD:(NSString *)text;
- (void)updateProgressHUD:(NSString *)text;
- (void)hideProgressHUD;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)executeSimpleExtraction;
- (void)executeCompositeExtraction;
- (void)extractSpecificPopupWithSelectorName:(NSString *)selectorName taskName:(NSString *)taskName completion:(void (^)(NSString *result))completion;
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *result))completion;
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion;
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
- (void)processKeTiWorkQueue_S1;
- (void)processKeChuanQueue_Truth_S2;
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion;
- (NSString *)_echo_extractSiKeInfo;
- (NSString *)_echo_extractSanChuanInfo;
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix;
- (NSString *)GetStringFromLayer:(id)layer;
- (void)presentAIActionSheetWithReport:(NSString *)report;
@end

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie);

%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    if (g_s1_isExtracting) {
        if ([NSStringFromClass([vcToPresent class]) containsString:@"課體概覽視圖"]) {
            vcToPresent.view.alpha = 0.0f; animated = NO;
            void (^extractionCompletion)(void) = ^{
                if (completion) { completion(); }
                NSString *extractedText = extractDataFromSplitView_S1(vcToPresent.view, g_s1_shouldIncludeXiangJie);
                if ([g_s1_currentTaskType isEqualToString:@"KeTi"]) {
                    [g_s1_keTi_resultsArray addObject:extractedText];
                    LogMessage(EchoLogTypeSuccess, @"[解析] 成功处理“课体范式”第 %lu 项...", (unsigned long)g_s1_keTi_resultsArray.count);
                    [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeTiWorkQueue_S1]; }); }];
                } else if ([g_s1_currentTaskType isEqualToString:@"JiuZongMen"]) {
                    LogMessage(EchoLogTypeSuccess, @"[解析] 成功处理“九宗门结构”...");
                    NSString *finalText = [NSString stringWithFormat:@"%@", extractedText];
                    [vcToPresent dismissViewControllerAnimated:NO completion:^{ if (g_s1_completion_handler) { g_s1_completion_handler(finalText); } }];
                }
            };
            Original_presentViewController(self, _cmd, vcToPresent, animated, extractionCompletion);
            return;
        }
    }
    else if (g_s2_isExtractingKeChuanDetail) { NSString *vcClassName = NSStringFromClass([vcToPresent class]); if ([vcClassName containsString:@"課傳摘要視圖"] || [vcClassName containsString:@"天將摘要視圖"]) { vcToPresent.view.alpha = 0.0f; animated = NO; void (^newCompletion)(void) = ^{ if (completion) { completion(); } UIView *contentView = vcToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray<NSString *> *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) [textParts addObject:[label.text stringByReplacingOccurrencesOfString:@"\n" withString:@" "]]; } [g_s2_capturedKeChuanDetailArray addObject:[textParts componentsJoinedByString:@"\n"]]; LogMessage(EchoLogTypeSuccess, @"[课传] 成功捕获内容 (共 %lu 条)", (unsigned long)g_s2_capturedKeChuanDetailArray.count); [vcToPresent dismissViewControllerAnimated:NO completion:^{ dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self processKeChuanQueue_Truth_S2]; }); }]; }; Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion); return; } }
    else if (g_isExtractingNianming && g_currentItemToExtract) {
        __weak typeof(self) weakSelf = self;
        NSString *vcClassName = NSStringFromClass([vcToPresent class]);
        if ([vcToPresent isKindOfClass:[UIAlertController class]]) { UIAlertController *alert = (UIAlertController *)vcToPresent; UIAlertAction *targetAction = nil; for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } } if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; } }
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = vcToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            [g_capturedZhaiYaoArray addObject:[[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
            LogMessage(EchoLogTypeSuccess, @"[行年] 成功捕获'年命摘要'内容。");
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
            return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            void (^newCompletion)(void) = ^{ if (completion) { completion(); } dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return; UIView *contentView = vcToPresent.view; dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return; [g_capturedGeJuArray addObject:[strongSelf2 formatNianmingGejuFromView:contentView]]; LogMessage(EchoLogTypeSuccess, @"[行年] 成功捕获'格局方法'内容。"); [vcToPresent dismissViewControllerAnimated:NO completion:nil]; }); }); };
            Original_presentViewController(self, _cmd, vcToPresent, animated, newCompletion);
            return;
        }
    }
    else if (g_extractedData && ![vcToPresent isKindOfClass:[UIAlertController class]]) {
        vcToPresent.view.alpha = 0.0f; animated = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *title = vcToPresent.title ?: @"";
            if (title.length == 0) { NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, labels); if (labels.count > 0) { [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; } } }
            NSMutableArray *textParts = [NSMutableArray array];
            if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], vcToPresent.view, stackViews); [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
                for (UIStackView *stackView in stackViews) {
                    NSArray *arrangedSubviews = stackView.arrangedSubviews;
                    if (arrangedSubviews.count >= 1 && [arrangedSubviews[0] isKindOfClass:[UILabel class]]) {
                        UILabel *titleLabel = arrangedSubviews[0]; NSString *rawTitle = titleLabel.text ?: @""; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 毕法" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 法诀" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 格局" withString:@""]; rawTitle = [rawTitle stringByReplacingOccurrencesOfString:@" 方法" withString:@""];
                        NSString *cleanTitle = [rawTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSMutableArray *descParts = [NSMutableArray array]; if (arrangedSubviews.count > 1) { for (NSUInteger i = 1; i < arrangedSubviews.count; i++) { if ([arrangedSubviews[i] isKindOfClass:[UILabel class]]) { [descParts addObject:((UILabel *)arrangedSubviews[i]).text]; } } }
                        NSString *fullDesc = [[descParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
                        [textParts addObject:[NSString stringWithFormat:@"%@→%@", cleanTitle, [fullDesc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
                    }
                }
                NSString *content = [textParts componentsJoinedByString:@"\n"];
                if ([title containsString:@"方法"]) g_extractedData[@"解析方法"] = content; else if ([title containsString:@"格局"]) g_extractedData[@"格局要览"] = content; else g_extractedData[@"毕法要诀"] = content;
                LogMessage(EchoLogTypeSuccess, @"[捕获] 成功解析弹窗 [%@]", title);
            } else if ([NSStringFromClass([vcToPresent class]) containsString:@"七政"]) {
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
                LogMessage(EchoLogTypeSuccess, @"[捕获] 成功解析弹窗 [%@]", title);
            } else { LogMessage(EchoLogTypeInfo, @"[捕获] 发现未知弹窗 [%@]，内容已忽略。", title); }
            [vcToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
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
            [controlButton setTitle:@"Echo 解析" forState:UIControlStateNormal];
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

// MARK: - UI Creation
%new
- (void)createOrShowMainControlPanel {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    
    if (g_mainControlPanelView && g_mainControlPanelView.superview) {
        [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) {
            [g_mainControlPanelView removeFromSuperview];
            g_mainControlPanelView = nil;
            g_logTextView = nil;
        }];
        return;
    }

    g_mainControlPanelView = [[UIView alloc] initWithFrame:keyWindow.bounds];
    g_mainControlPanelView.tag = kEchoMainPanelTag;
    g_mainControlPanelView.backgroundColor = [UIColor clearColor];
    if (@available(iOS 8.0, *)) {
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
        blurView.frame = g_mainControlPanelView.bounds;
        [g_mainControlPanelView addSubview:blurView];
    } else {
        g_mainControlPanelView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.9];
    }
    UIView *contentView = [[UIView alloc] initWithFrame:CGRectMake(10, 60, g_mainControlPanelView.bounds.size.width - 20, g_mainControlPanelView.bounds.size.height - 80)];
    [g_mainControlPanelView addSubview:contentView];
    
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:@"Echo 六壬解析引擎 "];
    [titleString addAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:22], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0, titleString.length)];
    NSAttributedString *versionString = [[NSAttributedString alloc] initWithString:@"v13.20" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    [titleString appendAttributedString:versionString];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, contentView.bounds.size.width, 30)];
    titleLabel.attributedText = titleString;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 50, contentView.bounds.size.width, contentView.bounds.size.height - 110)];
    [contentView addSubview:scrollView];

    UIButton* (^createButton)(NSString*, NSString*, NSInteger, UIColor*) = ^(NSString* title, NSString* iconName, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:title forState:UIControlStateNormal];
        if (@available(iOS 13.0, *)) {
            UIImage *icon = [UIImage systemImageNamed:iconName];
            [btn setImage:icon forState:UIControlStateNormal];
            
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 10);
            #pragma clang diagnostic pop
        }
        btn.tag = tag;
        btn.backgroundColor = color;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.8;
        btn.layer.cornerRadius = 12;
        btn.layer.borderWidth = 1.0;
        btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.1].CGColor;
        return btn;
    };
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) {
        UILabel *label = [[UILabel alloc] init];
        label.text = title;
        label.font = [UIFont boldSystemFontOfSize:18];
        label.textColor = [UIColor lightGrayColor];
        return label;
    };
    UIView* (^createSeparator)(CGFloat) = ^(CGFloat yPos) {
        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(15, yPos, scrollView.bounds.size.width - 30, 0.5)];
        separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.2];
        return separator;
    };
  
    CGFloat currentY = 20;
    CGFloat btnWidth = (scrollView.bounds.size.width - 45) / 2.0;

    UILabel *sec1Title = createSectionTitle(@"核心解析");
    sec1Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec1Title];
    currentY += 35;

    NSArray *mainButtons = @[
        @{@"title": @"标准报告", @"icon": @"doc.text", @"tag": @(kButtonTag_StandardReport), @"color": ECHO_COLOR_MAIN_TEAL},
        @{@"title": @"深度解构", @"icon": @"square.stack.3d.up.fill", @"tag": @(kButtonTag_DeepDiveReport), @"color": ECHO_COLOR_MAIN_BLUE}
    ];
    for (int i = 0; i < mainButtons.count; i++) {
        NSDictionary *config = mainButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], config[@"color"]);
        btn.frame = CGRectMake(15 + (i % 2) * (btnWidth + 15), currentY, btnWidth, 48);
        [scrollView addSubview:btn];
    }
    currentY += 48 + 20;
    
    [scrollView addSubview:createSeparator(currentY)];
    currentY += 20;
  
    UILabel *sec2Title = createSectionTitle(@"专项分析");
    sec2Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec2Title];
    currentY += 35;
    
    NSArray *coreButtons = @[
        @{@"title": @"课体范式", @"icon": @"square.stack.3d.up", @"tag": @(kButtonTag_KeTi)},
        @{@"title": @"九宗门", @"icon": @"arrow.triangle.branch", @"tag": @(kButtonTag_JiuZongMen)},
        @{@"title": @"课传流注", @"icon": @"wave.3.right", @"tag": @(kButtonTag_KeChuan)},
        @{@"title": @"行年参数", @"icon": @"person.crop.circle", @"tag": @(kButtonTag_NianMing)}
    ];
    for (int i=0; i<coreButtons.count; i++) {
        NSDictionary *config = coreButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(15 + (i % 2) * (btnWidth + 15), currentY + (i / 2) * 58, btnWidth, 46);
        [scrollView addSubview:btn];
    }
    currentY += ((coreButtons.count + 1) / 2) * 58 + 20;

    [scrollView addSubview:createSeparator(currentY)];
    currentY += 20;

    UILabel *sec3Title = createSectionTitle(@"格局资料库");
    sec3Title.frame = CGRectMake(15, currentY, scrollView.bounds.size.width - 30, 22);
    [scrollView addSubview:sec3Title];
    currentY += 35;
    
    NSArray *auxButtons = @[
        @{@"title": @"毕法要诀", @"icon": @"book.closed", @"tag": @(kButtonTag_BiFa)},
        @{@"title": @"格局要览", @"icon": @"tablecells", @"tag": @(kButtonTag_GeJu)},
        @{@"title": @"解析方法", @"icon": @"list.number", @"tag": @(kButtonTag_FangFa)}
    ];
    CGFloat smallBtnWidth = (scrollView.bounds.size.width - 50) / 3.0;
    for (int i=0; i<auxButtons.count; i++) {
        NSDictionary *config = auxButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(15 + i * (smallBtnWidth + 10), currentY, smallBtnWidth, 46);
        [scrollView addSubview:btn];
    }
    currentY += 56;
    
    scrollView.contentSize = CGSizeMake(scrollView.bounds.size.width, currentY);
  
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, contentView.bounds.size.height - 230, contentView.bounds.size.width, 170)];
    g_logTextView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.7];
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    g_logTextView.editable = NO;
    g_logTextView.layer.cornerRadius = 8;
    NSMutableAttributedString *initLog = [[NSMutableAttributedString alloc] initWithString:@"[Echo引擎]：就绪。\n"];
    [initLog addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:NSMakeRange(0, initLog.length)];
    [initLog addAttribute:NSFontAttributeName value:g_logTextView.font range:NSMakeRange(0, initLog.length)];
    g_logTextView.attributedText = initLog;
    [contentView addSubview:g_logTextView];
  
    CGFloat bottomBtnWidth = (contentView.bounds.size.width - 40) / 2;
    
    UIButton *closeButton = createButton(@"关闭面板", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
    closeButton.frame = CGRectMake(15, contentView.bounds.size.height - 50, bottomBtnWidth, 40);
    [contentView addSubview:closeButton];
    
    UIButton *sendLastReportButton = createButton(@"发送上次报告到AI", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
    sendLastReportButton.frame = CGRectMake(15 + bottomBtnWidth + 10, contentView.bounds.size.height - 50, bottomBtnWidth, 40);
    [contentView addSubview:sendLastReportButton];

    g_mainControlPanelView.alpha = 0;
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    if (!sender) {
        if (g_mainControlPanelView) {
            [UIView animateWithDuration:0.3 animations:^{ g_mainControlPanelView.alpha = 0; } completion:^(BOOL finished) {
                [g_mainControlPanelView removeFromSuperview];
                g_mainControlPanelView = nil; g_logTextView = nil;
            }];
        }
        return;
    }
    
    if (g_s1_isExtracting || g_s2_isExtractingKeChuanDetail || g_isExtractingNianming || g_extractedData) {
        if (sender.tag != kButtonTag_ClosePanel) {
            LogMessage(EchoLogError, @"[错误] 当前有任务在后台运行，请等待完成后重试。");
            return;
        }
    }
    
    __weak typeof(self) weakSelf = self;

    switch (sender.tag) {
        case kButtonTag_ClosePanel:
            [self handleMasterButtonTap:nil];
            break;
        case kButtonTag_SendLastReportToAI:
        {
            NSString *lastReport = g_lastGeneratedReport;
            if (lastReport && lastReport.length > 0) {
                [self presentAIActionSheetWithReport:lastReport];
            } else {
                LogMessage(EchoLogTypeWarning, @"内部报告缓存为空。");
                [self showEchoNotificationWithTitle:@"操作无效" message:@"尚未生成任何报告。"];
            }
            break;
        }
        case kButtonTag_StandardReport:
            [self executeSimpleExtraction];
            break;
        case kButtonTag_DeepDiveReport:
            [self executeCompositeExtraction];
            break;
        case kButtonTag_KeTi: {
            [self startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:YES completion:^(NSString *result) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                    reportData[@"课体范式_详"] = result;
                    NSString *finalReport = formatFinalReport(reportData);
                    g_lastGeneratedReport = [finalReport copy];
                    [strongSelf presentAIActionSheetWithReport:finalReport];
                    g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil;
                });
            }];
            break;
        }
        case kButtonTag_JiuZongMen: {
            [self startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:YES completion:^(NSString *result) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                    reportData[@"九宗门_详"] = result;
                    NSString *finalReport = formatFinalReport(reportData);
                    g_lastGeneratedReport = [finalReport copy];
                    [strongSelf presentAIActionSheetWithReport:finalReport];
                    g_s1_isExtracting = NO; g_s1_currentTaskType = nil; g_s1_completion_handler = nil;
                });
            }];
            break;
        }
        case kButtonTag_KeChuan:
            [self startExtraction_Truth_S2_WithCompletion:nil];
            break;
        case kButtonTag_NianMing: {
            [self extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                reportData[@"行年参数"] = nianmingText;
                NSString *finalReport = formatFinalReport(reportData);
                g_lastGeneratedReport = [finalReport copy];
                [strongSelf hideProgressHUD];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        case kButtonTag_BiFa: {
            [self extractSpecificPopupWithSelectorName:@"顯示法訣總覽" taskName:@"毕法要诀" completion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                reportData[@"毕法要诀"] = result;
                NSString *finalReport = formatFinalReport(reportData);
                g_lastGeneratedReport = [finalReport copy];
                [strongSelf hideProgressHUD];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        case kButtonTag_GeJu: {
            [self extractSpecificPopupWithSelectorName:@"顯示格局總覽" taskName:@"格局要览" completion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                reportData[@"格局要览"] = result;
                NSString *finalReport = formatFinalReport(reportData);
                g_lastGeneratedReport = [finalReport copy];
                [strongSelf hideProgressHUD];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        case kButtonTag_FangFa: {
            [self extractSpecificPopupWithSelectorName:@"顯示方法總覽" taskName:@"解析方法" completion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                reportData[@"解析方法"] = result;
                NSString *finalReport = formatFinalReport(reportData);
                g_lastGeneratedReport = [finalReport copy];
                [strongSelf hideProgressHUD];
                [strongSelf presentAIActionSheetWithReport:finalReport];
            }];
            break;
        }
        default: break;
    }
}

%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) {
        LogMessage(EchoLogError, @"报告为空，无法执行后续操作。");
        return;
    }

    [UIPasteboard generalPasteboard].string = report; 

    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"发送到AI助手" message:@"将使用内部缓存的报告内容" preferredStyle:UIAlertControllerStyleActionSheet];

    NSString *encodedReport = [report stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    NSArray *aiApps = @[
        @{@"name": @"Kimi", @"scheme": @"kimi://", @"format": @"kimi://chat?q=%@"},
        @{@"name": @"豆包", @"scheme": @"doubao://", @"format": @"doubao://chat/send?text=%@"},
        @{@"name": @"腾讯元宝", @"scheme": @"yuanbao://", @"format": @"yuanbao://send?text=%@"}, 
        @{@"name": @"ChatGPT", @"scheme": @"chatgpt://", @"format": @"chatgpt://chat?message=%@"},
        @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"} 
    ];

    int availableApps = 0;
    for (NSDictionary *appInfo in aiApps) {
        NSString *checkScheme = appInfo[@"scheme"];
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:checkScheme]]) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"发送到 %@", appInfo[@"name"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString *urlString = [NSString stringWithFormat:appInfo[@"format"], encodedReport];
                NSURL *url = [NSURL URLWithString:urlString];
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                    if(success) {
                        LogMessage(EchoLogTypeSuccess, @"成功跳转到 %@", appInfo[@"name"]);
                    } else {
                        LogMessage(EchoLogError, @"跳转到 %@ 失败", appInfo[@"name"]);
                    }
                }];
            }];
            [actionSheet addAction:action];
            availableApps++;
        }
    }
    
    if (availableApps == 0) {
        actionSheet.message = @"未检测到受支持的AI App。\n内容已复制到剪贴板。";
    }

    UIAlertAction *copyAction = [UIAlertAction actionWithTitle:@"仅复制到剪贴板" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        LogMessage(EchoLogTypeSuccess, @"报告已复制到剪贴板。");
        [self showEchoNotificationWithTitle:@"复制成功" message:@"报告内容已同步至剪贴板。"];
    }];
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
    if (progressView) {
        for (UIView *subview in progressView.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                ((UILabel *)subview).text = text;
                break;
            }
        }
    }
}
%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if (progressView) {
        [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }];
    }
}

%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message {
    UIWindow *keyWindow = GetFrontmostWindow();
    if (!keyWindow) return;

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

// MARK: - Task Launchers & Processors
%new
- (void)startS1ExtractionWithTaskType:(NSString *)taskType includeXiangJie:(BOOL)include completion:(void (^)(NSString *result))completion {
    g_s1_isExtracting = YES;
    g_s1_currentTaskType = taskType;
    g_s1_shouldIncludeXiangJie = include;
    g_s1_completion_handler = [completion copy];
    
    NSString *mode = include ? @"详" : @"简";
    if(g_s1_completion_handler) {
        LogMessage(EchoLogTypeInfo, @"[集成任务] 开始提取 %@ (%@)...", taskType, mode);
    } else {
        LogMessage(EchoLogTypeTask, @"[任务启动] 模式: %@ (详情: %@)", taskType, include ? @"开启" : @"关闭");
    }

    if ([taskType isEqualToString:@"KeTi"]) {
        UIWindow *keyWindow = GetFrontmostWindow();
        if (!keyWindow) { LogMessage(EchoLogError, @"[错误] 无法找到主窗口。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到主窗口]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        
        Class keTiCellClass = NSClassFromString(@"六壬大占.課體單元");
        if (!keTiCellClass) { LogMessage(EchoLogError, @"[错误] 无法找到 '課體單元' 类。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到課體單元类]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        
        NSMutableArray<UICollectionView *> *allCVs = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UICollectionView class], keyWindow, allCVs);
        for (UICollectionView *cv in allCVs) {
            for (id cell in cv.visibleCells) { if ([cell isKindOfClass:keTiCellClass]) { g_s1_keTi_targetCV = cv; break; } }
            if(g_s1_keTi_targetCV) break;
        }
        
        if (!g_s1_keTi_targetCV) { LogMessage(EchoLogError, @"[错误] 无法找到包含“课体”的UICollectionView。"); if(g_s1_completion_handler){g_s1_completion_handler(@"[错误:未找到课体CV]"); g_s1_completion_handler = nil;} g_s1_isExtracting = NO; return; }
        
        g_s1_keTi_workQueue = [NSMutableArray array];
        g_s1_keTi_resultsArray = [NSMutableArray array];
        NSInteger totalItems = [g_s1_keTi_targetCV.dataSource collectionView:g_s1_keTi_targetCV numberOfItemsInSection:0];
        for (NSInteger i = 0; i < totalItems; i++) { [g_s1_keTi_workQueue addObject:[NSIndexPath indexPathForItem:i inSection:0]]; }
        
        if (g_s1_keTi_workQueue.count == 0) {
            LogMessage(EchoLogTypeWarning, @"[警告] 未找到任何“课体”单元来创建任务队列。");
            if(g_s1_completion_handler){ g_s1_completion_handler(@""); g_s1_completion_handler = nil; }
            g_s1_isExtracting = NO;
            return;
        }
        
        LogMessage(EchoLogTypeInfo, @"[解析] 发现 %lu 个“课体范式”单元，开始处理...", (unsigned long)g_s1_keTi_workQueue.count);
        [self processKeTiWorkQueue_S1];
        
    } else if ([taskType isEqualToString:@"JiuZongMen"]) {
        SEL selector = NSSelectorFromString(@"顯示九宗門概覽");
        if ([self respondsToSelector:selector]) {
            LogMessage(EchoLogTypeInfo, @"[调用] 正在请求“九宗门”数据...");
            SUPPRESS_LEAK_WARNING([self performSelector:selector]);
        } else {
            LogMessage(EchoLogError, @"[错误] 当前视图无法响应 '顯示九宗門概覽'。");
            if(g_s1_completion_handler){ g_s1_completion_handler(@"[错误:无法响应九宗门方法]"); g_s1_completion_handler = nil; }
            g_s1_isExtracting = NO;
        }
    }
}
%new
- (void)processKeTiWorkQueue_S1 {
    if (g_s1_keTi_workQueue.count == 0) {
        LogMessage(EchoLogTypeTask, @"[完成] 所有 %lu 项“课体范式”处理完毕。", (unsigned long)g_s1_keTi_resultsArray.count);
        
        NSString *finalResult = [g_s1_keTi_resultsArray componentsJoinedByString:@"\n\n"];
        NSString *trimmedResult = [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        g_s1_keTi_targetCV = nil;
        g_s1_keTi_workQueue = nil;
        g_s1_keTi_resultsArray = nil;

        if (g_s1_completion_handler) {
            g_s1_completion_handler(trimmedResult);
        }
        return;
    }
    
    NSIndexPath *indexPath = g_s1_keTi_workQueue.firstObject;
    [g_s1_keTi_workQueue removeObjectAtIndex:0];
    LogMessage(EchoLogTypeInfo, @"[解析] 正在处理“课体范式” %lu/%lu...", (unsigned long)(g_s1_keTi_resultsArray.count + 1), (unsigned long)(g_s1_keTi_resultsArray.count + g_s1_keTi_workQueue.count + 1));
    id delegate = g_s1_keTi_targetCV.delegate;
    if (delegate && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
        [delegate collectionView:g_s1_keTi_targetCV didSelectItemAtIndexPath:indexPath];
    } else {
        LogMessage(EchoLogError, @"[错误] 无法触发单元点击事件。");
        [self processKeTiWorkQueue_S1];
    }
}

%new
- (void)executeSimpleExtraction {
    __weak typeof(self) weakSelf = self;
    LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 标准报告 (AI结构化)");
    [self showProgressHUD:@"1/4: 解析基础盘面..."];

    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];

    [self extractKePanInfoWithCompletion:^(NSMutableDictionary *baseReportData) {
        [reportData addEntriesFromDictionary:baseReportData];
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        [strongSelf updateProgressHUD:@"2/4: 分析行年参数..."];

        [strongSelf extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
            reportData[@"行年参数"] = nianmingText;
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            [strongSelf2 updateProgressHUD:@"3/4: 解析课体范式..."];

            [strongSelf2 startS1ExtractionWithTaskType:@"KeTi" includeXiangJie:NO completion:^(NSString *keTiResult) {
                reportData[@"课体范式_简"] = keTiResult;
                __strong typeof(weakSelf) strongSelf3 = weakSelf; if (!strongSelf3) return;
                [strongSelf3 updateProgressHUD:@"4/4: 解析九宗门..."];

                [strongSelf3 startS1ExtractionWithTaskType:@"JiuZongMen" includeXiangJie:NO completion:^(NSString *jiuZongMenResult) {
                    reportData[@"九宗门_简"] = jiuZongMenResult;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf4 = weakSelf; if (!strongSelf4) return;
                        LogMessage(EchoLogTypeInfo, @"[整合] 所有部分解析完成，正在生成结构化报告...");
                        
                        NSString *finalReport = formatFinalReport(reportData);
                        g_lastGeneratedReport = [finalReport copy];
                        
                        [strongSelf4 hideProgressHUD];
                        [strongSelf4 presentAIActionSheetWithReport:finalReport];
                        LogMessage(EchoLogTypeTask, @"[完成] “标准报告”任务已完成。");

                        g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil;
                        LogMessage(EchoLogTypeInfo, @"[状态] 全局数据已清理。");
                    });
                }];
            }];
        }];
    }];
}

%new
- (void)executeCompositeExtraction {
    __weak typeof(self) weakSelf = self;
    LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 深度解构 (AI结构化)");
    [self showProgressHUD:@"1/5: 解析基础盘面..."];

    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];

    [self extractKePanInfoWithCompletion:^(NSMutableDictionary *baseReportData) {
        [reportData addEntriesFromDictionary:baseReportData];
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
        [strongSelf updateProgressHUD:@"2/5: 推演课传流注..."];

        [strongSelf startExtraction_Truth_S2_WithCompletion:^{
            reportData[@"课传详解"] = SafeString(g_s2_finalResultFromKeChuan);
            __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
            [strongSelf2 updateProgressHUD:@"3/5: 分析行年参数..."];

            [strongSelf2 extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
                reportData[@"行年参数"] = nianmingText;
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
                            LogMessage(EchoLogTypeInfo, @"[整合] 所有部分解析完成，正在生成结构化报告...");

                            NSString *finalReport = formatFinalReport(reportData);
                            g_lastGeneratedReport = [finalReport copy];
                            
                            [strongSelf5 hideProgressHUD];
                            [strongSelf5 presentAIActionSheetWithReport:finalReport];
                            LogMessage(EchoLogTypeTask, @"--- [完成] “深度解构”任务已全部完成 ---");

                            g_extractedData = nil; g_s1_isExtracting = NO; g_s1_completion_handler = nil;
                            g_s2_finalResultFromKeChuan = nil;
                            LogMessage(EchoLogTypeInfo, @"[状态] 全局数据已清理。");
                        });
                    }];
                }];
            }];
        }];
    }];
}
%new
- (void)extractSpecificPopupWithSelectorName:(NSString *)selectorName taskName:(NSString *)taskName completion:(void (^)(NSString *result))completion {
    LogMessage(EchoLogTypeTask, @"[精准分析] 任务启动: %@", taskName);
    [self showProgressHUD:[NSString stringWithFormat:@"正在分析: %@", taskName]];
    
    g_extractedData = [NSMutableDictionary dictionary];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL selector = NSSelectorFromString(selectorName);
        if ([self respondsToSelector:selector]) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                SUPPRESS_LEAK_WARNING([self performSelector:selector withObject:nil]);
            });
            [NSThread sleepForTimeInterval:0.5];
        } else {
            LogMessage(EchoLogError, @"[错误] 无法响应选择器 '%@'", selectorName);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *result = g_extractedData[taskName];
            if (result.length > 0) {
                NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"];
                for (NSString *t in trash) { result = [result stringByReplacingOccurrencesOfString:t withString:@""]; }
            } else {
                LogMessage(EchoLogTypeWarning, @"[警告] %@ 分析失败或无内容。", taskName);
                result = @"";
            }
            
            if (completion) {
                completion(result);
            }
            
            g_extractedData = nil;
        });
    });
}
%new
- (void)startExtraction_Truth_S2_WithCompletion:(void (^)(void))completion {
    if (g_s2_isExtractingKeChuanDetail) { LogMessage(EchoLogError, @"[错误] 课传推演任务已在进行中。"); return; }
    LogMessage(EchoLogTypeTask, @"[任务启动] 开始推演“课传流注”...");
    [self showProgressHUD:@"正在推演课传流注..."];
    g_s2_isExtractingKeChuanDetail = YES;
    g_s2_keChuan_completion_handler = [completion copy];
    g_s2_capturedKeChuanDetailArray = [NSMutableArray array];
    g_s2_keChuanWorkQueue = [NSMutableArray array];
    g_s2_keChuanTitleQueue = [NSMutableArray array];
    
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
                if (label.gestureRecognizers.count > 0) {
                    [g_s2_keChuanWorkQueue addObject:[@{@"gesture": label.gestureRecognizers.firstObject, @"taskType": tType} mutableCopy]];
                    [g_s2_keChuanTitleQueue addObject:[NSString stringWithFormat:@"%@ (%@)", fTitle, label.text]];
                }
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
            LogMessage(EchoLogTypeTask, @"[完成] “课传流注”全部处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            if (g_s2_capturedKeChuanDetailArray.count == g_s2_keChuanTitleQueue.count) {
                for (NSUInteger i = 0; i < g_s2_keChuanTitleQueue.count; i++) {
                    [resultStr appendFormat:@"- 对象: %@\n  %@\n\n", g_s2_keChuanTitleQueue[i], [g_s2_capturedKeChuanDetailArray[i] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n  "]];
                }
                g_s2_finalResultFromKeChuan = [resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                if (!g_s2_keChuan_completion_handler) {
                    NSMutableDictionary *reportData = [NSMutableDictionary dictionary];
                    reportData[@"课传详解"] = g_s2_finalResultFromKeChuan;
                    NSString *finalReport = formatFinalReport(reportData);
                    g_lastGeneratedReport = [finalReport copy];
                    [self presentAIActionSheetWithReport:finalReport];
                }
            } else {
                g_s2_finalResultFromKeChuan = @"[错误: 课传流注解析数量不匹配]";
                LogMessage(EchoLogError, @"%@", g_s2_finalResultFromKeChuan);
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

    NSMutableDictionary *task = g_s2_keChuanWorkQueue.firstObject; [g_s2_keChuanWorkQueue removeObjectAtIndex:0];
    NSString *title = g_s2_keChuanTitleQueue[g_s2_capturedKeChuanDetailArray.count];
    LogMessage(EchoLogTypeInfo, @"[课传] 正在处理: %@", title);
    [self updateProgressHUD:[NSString stringWithFormat:@"推演课传: %lu/%lu", (unsigned long)g_s2_capturedKeChuanDetailArray.count + 1, (unsigned long)g_s2_keChuanTitleQueue.count]];
    
    SEL action = [task[@"taskType"] isEqualToString:@"tianJiang"] ? NSSelectorFromString(@"顯示課傳天將摘要WithSender:") : NSSelectorFromString(@"顯示課傳摘要WithSender:");
    if ([self respondsToSelector:action]) {
        SUPPRESS_LEAK_WARNING([self performSelector:action withObject:task[@"gesture"]]);
    } else {
        LogMessage(EchoLogError, @"[错误] 方法 %@ 不存在。", NSStringFromSelector(action));
        [g_s2_capturedKeChuanDetailArray addObject:@"[解析失败: 方法不存在]"];
        [self processKeChuanQueue_Truth_S2];
    }
}


// MARK: - Data Extraction Logic

%new
- (void)extractKePanInfoWithCompletion:(void (^)(NSMutableDictionary *reportData))completion {
    g_extractedData = [NSMutableDictionary dictionary];
    LogMessage(EchoLogTypeInfo, @"[盘面] 开始解析基础信息...");

    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];
    
    LogMessage(EchoLogTypeInfo, @"[盘面] 开始解析四课三传...");
    g_extractedData[@"四课"] = [self _echo_extractSiKeInfo];
    g_extractedData[@"三传"] = [self _echo_extractSanChuanInfo];

    LogMessage(EchoLogTypeInfo, @"[盘面] 开始解析弹窗类信息 (毕法/格局等)...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa = NSSelectorFromString(@"顯示法訣總覽"), sGeJu = NSSelectorFromString(@"顯示格局總覽"), sQiZheng = NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa = NSSelectorFromString(@"顯示方法總覽");
        
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            LogMessage(EchoLogTypeInfo, @"[盘面] 整合所有信息...");
            
            NSArray *keysToClean = @[@"毕法要诀", @"格局要览", @"解析方法"];
            NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"];
            for (NSString *key in keysToClean) {
                NSString *value = g_extractedData[key];
                if (value) {
                    for (NSString *t in trash) { value = [value stringByReplacingOccurrencesOfString:t withString:@""]; }
                    g_extractedData[key] = value;
                }
            }
            
            if (completion) {
                completion(g_extractedData);
            }
        });
    });
}

%new
- (NSString *)_echo_extractSiKeInfo {
    Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if (!siKeViewClass) return @"";
    
    NSMutableArray *siKeViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
    if (siKeViews.count == 0) return @"";

    UIView *container = siKeViews.firstObject;
    NSMutableArray *labels = [NSMutableArray array];
    FindSubviewsOfClassRecursive([UILabel class], container, labels);
    if (labels.count < 12) return @"";
    
    NSMutableDictionary *cols = [NSMutableDictionary dictionary];
    for (UILabel *label in labels) {
        NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))];
        if (!cols[key]) { cols[key] = [NSMutableArray array]; }
        [cols[key] addObject:label];
    }
    
    if (cols.allKeys.count != 4) return @"";
    
    NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) {
        return [@([o1 floatValue]) compare:@([o2 floatValue])];
    }];
    
    NSMutableArray *c1 = cols[keys[0]], *c2 = cols[keys[1]], *c3 = cols[keys[2]], *c4 = cols[keys[3]];
    [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    [c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
    
    NSString *k1_shang = ((UILabel*)c4[0]).text, *k1_jiang = ((UILabel*)c4[1]).text, *k1_xia = ((UILabel*)c4[2]).text;
    NSString *k2_shang = ((UILabel*)c3[0]).text, *k2_jiang = ((UILabel*)c3[1]).text, *k2_xia = ((UILabel*)c3[2]).text;
    NSString *k3_shang = ((UILabel*)c2[0]).text, *k3_jiang = ((UILabel*)c2[1]).text, *k3_xia = ((UILabel*)c2[2]).text;
    NSString *k4_shang = ((UILabel*)c1[0]).text, *k4_jiang = ((UILabel*)c1[1]).text, *k4_xia = ((UILabel*)c1[2]).text;

    return [NSString stringWithFormat:@"- 第一课(日干): %@ 上 %@，%@乘%@\n- 第二课(日上): %@ 上 %@，%@乘%@\n- 第三课(支辰): %@ 上 %@，%@乘%@\n- 第四课(辰上): %@ 上 %@，%@乘%@",
        SafeString(k1_xia), SafeString(k1_shang), SafeString(k1_shang), SafeString(k1_jiang),
        SafeString(k2_xia), SafeString(k2_shang), SafeString(k2_shang), SafeString(k2_jiang),
        SafeString(k3_xia), SafeString(k3_shang), SafeString(k3_shang), SafeString(k3_jiang),
        SafeString(k4_xia), SafeString(k4_shang), SafeString(k4_shang), SafeString(k4_jiang)
    ];
}

%new
- (NSString *)_echo_extractSanChuanInfo {
    Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if (!sanChuanViewClass) return @"";

    NSMutableArray *scViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews);
    [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) {
        return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
    }];

    NSArray *titles = @[@"初传", @"中传", @"末传"];
    NSMutableArray *lines = [NSMutableArray array];
    for (NSUInteger i = 0; i < scViews.count; i++) {
        UIView *v = scViews[i];
        NSMutableArray *labels = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], v, labels);
        [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
            return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)];
        }];

        if (labels.count >= 3) {
            NSString *lq = [[(UILabel*)labels.firstObject text] stringByReplacingOccurrencesOfString:@"->" withString:@""];
            NSString *tj = [(UILabel*)labels.lastObject text];
            NSString *dz = [(UILabel*)[labels objectAtIndex:labels.count - 2] text];
            
            NSMutableArray *ssParts = [NSMutableArray array];
            if (labels.count > 3) {
                for (UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count - 3)]) {
                    if (l.text.length > 0) [ssParts addObject:l.text];
                }
            }
            NSString *ss = [ssParts componentsJoinedByString:@", "];
            NSString *title = (i < titles.count) ? titles[i] : [NSString stringWithFormat:@"%lu传", (unsigned long)i+1];

            [lines addObject:[NSString stringWithFormat:@"- %@: %@ (%@, %@) [状态: %@]", title, SafeString(dz), SafeString(lq), SafeString(tj), ss.length > 0 ? ss : @"无"]];
        }
    }
    return [lines componentsJoinedByString:@"\n"];
}

%new
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion {
    LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 行年参数");
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
        g_isExtractingNianming = NO;
        if (completion) { completion(@""); }
        return;
    }
  
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
  
    if (allUnitCells.count == 0) {
        LogMessage(EchoLogTypeWarning, @"[行年] 行年单元数量为0，跳过分析。");
        g_isExtractingNianming = NO;
        if (completion) { completion(@""); }
        return;
    }
  
    LogMessage(EchoLogTypeInfo, @"[行年] 发现 %lu 个参数，开始构建任务队列...", (unsigned long)allUnitCells.count);
    NSMutableArray *workQueue = [NSMutableArray array];
    for (NSUInteger i = 0; i < allUnitCells.count; i++) {
        UICollectionViewCell *cell = allUnitCells[i];
        [workQueue addObject:@{@"type": @"年命摘要", @"cell": cell, @"index": @(i)}];
        [workQueue addObject:@{@"type": @"格局方法", @"cell": cell, @"index": @(i)}];
    }
  
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = [^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            LogMessage(EchoLogTypeTask, @"[行年] 所有参数分析完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            NSUInteger personCount = allUnitCells.count;
            for (NSUInteger i = 0; i < personCount; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[摘要未获取]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[格局未获取]";
                
                [resultStr appendFormat:@"- 参数 %lu\n  摘要: %@\n  格局: %@", (unsigned long)i+1, zhaiYao, geJu];
                
                if (i < personCount - 1) { [resultStr appendString:@"\n\n"]; }
            }
            g_isExtractingNianming = NO;
            g_currentItemToExtract = nil;
            if (completion) { completion([resultStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
            processQueue = nil;
            return;
        }
        NSDictionary *item = workQueue.firstObject; [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"];
        UICollectionViewCell *cell = item[@"cell"];
        NSInteger index = [item[@"index"] integerValue];
        LogMessage(EchoLogTypeInfo, @"[行年] 正在处理参数 %ld 的 [%@]", (long)index + 1, type);
        g_currentItemToExtract = type;
        id delegate = targetCV.delegate;
        NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    } copy];
    processQueue();
}

// MARK: - Helper Methods & Data Formatters
%new
- (id)GetIvarValueSafely:(id)object ivarNameSuffix:(NSString *)ivarNameSuffix { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { value = object_getIvar(object, ivar); break; } } } free(ivars); return value; }
%new
- (NSString *)GetStringFromLayer:(id)layer { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
%new
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView { Class cellClass = NSClassFromString(@"六壬大占.格局單元"); if (!cellClass) return @""; NSMutableArray *cells = [NSMutableArray array]; FindSubviewsOfClassRecursive(cellClass, contentView, cells); [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }]; NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array]; for (UIView *cell in cells) { NSMutableArray *labelsInCell = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell); if (labelsInCell.count > 0) { UILabel *titleLabel = labelsInCell[0]; NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; NSMutableString *contentString = [NSMutableString string]; if (labelsInCell.count > 1) { for (NSUInteger i = 1; i < labelsInCell.count; i++) { [contentString appendString:((UILabel *)labelsInCell[i]).text]; } } NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "]; NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content]; if (![formattedPairs containsObject:pair]) { [formattedPairs addObject:pair]; } } } return [formattedPairs componentsJoinedByString:@" | "]; }
%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator { Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { LogMessage(EchoLogError, @"[错误] 类名 '%@' 未找到。", className); return @""; } NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews); if (targetViews.count == 0) return @""; UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView); [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } } return [textParts componentsJoinedByString:separator]; }
%new
- (NSString *)extractTianDiPanInfo_V18 { @try { Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类"; UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow"; NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例"; UIView *plateView = plateViews.firstObject; id diGongDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"地宮宮名列"], tianShenDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天神宮名列"], tianJiangDict = [self GetIvarValueSafely:plateView ivarNameSuffix:@"天將宮名列"]; if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典"; NSArray *diGongLayers=[diGongDict allValues], *tianShenLayers=[tianShenDict allValues], *tianJiangLayers=[tianJiangDict allValues]; if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配"; NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil]; void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (id layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = [layer presentationLayer] ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; CGFloat dx = pos.x - center.x; CGFloat dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": [self GetStringFromLayer:layer], @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } }; processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang"); NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary]; for (NSDictionary *info in allLayerInfos) { BOOL foundGroup = NO; for (NSNumber *angleKey in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angleKey floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angleKey] addObject:info]; foundGroup=YES; break; } } if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];} } NSMutableArray *palaceData = [NSMutableArray array]; for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count < 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; NSString *diPan=@"?", *tianPan=@"?", *tianJiang=@"?"; for(NSDictionary* li in group){ if([li[@"type"] isEqualToString:@"diPan"]) diPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianPan"]) tianPan=li[@"text"]; else if([li[@"type"] isEqualToString:@"tianJiang"]) tianJiang=li[@"text"]; } [palaceData addObject:@{ @"diPan": diPan, @"tianPan": tianPan, @"tianJiang": tianJiang }]; } if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整"; NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"]; [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }]; NSMutableString *result = [NSMutableString string]; for (NSDictionary *entry in palaceData) { [result appendFormat:@"- %@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; } return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; } }
%end

// =========================================================================
// 4. S1 提取函数定义
// =========================================================================
static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie) { if (!rootView) return @"[错误: 根视图为空]"; NSMutableString *finalResult = [NSMutableString string]; NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], rootView, stackViews); if (stackViews.count > 0) { UIStackView *mainStackView = stackViews.firstObject; NSMutableArray *blocks = [NSMutableArray array]; NSMutableDictionary *currentBlock = nil; for (UIView *subview in mainStackView.arrangedSubviews) { if (![subview isKindOfClass:[UILabel class]]) continue; UILabel *label = (UILabel *)subview; NSString *text = label.text; if (!text || text.length == 0) continue; BOOL isTitle = (label.font.fontDescriptor.symbolicTraits & UIFontDescriptorTraitBold) != 0; if (isTitle) { if (currentBlock) [blocks addObject:currentBlock]; currentBlock = [NSMutableDictionary dictionaryWithDictionary:@{@"title": text, @"content": [NSMutableString string]}]; } else { if (currentBlock) { NSMutableString *content = currentBlock[@"content"]; if (content.length > 0) [content appendString:@"\n"]; [content appendString:text]; } } } if (currentBlock) [blocks addObject:currentBlock]; for (NSDictionary *block in blocks) { NSString *title = block[@"title"]; NSString *content = [block[@"content"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; if (content.length > 0) { [finalResult appendFormat:@"%@\n%@\n\n", title, content]; } else { [finalResult appendFormat:@"%@\n\n", title]; } } } if (includeXiangJie) { Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView"); if (tableViewClass) { NSMutableArray *tableViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(tableViewClass, rootView, tableViews); if (tableViews.count > 0) { NSMutableArray *xiangJieLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], tableViews.firstObject, xiangJieLabels); if (xiangJieLabels.count > 0) { [finalResult appendString:@"// 详解内容\n\n"]; for (NSUInteger i = 0; i < xiangJieLabels.count; i += 2) { UILabel *titleLabel = xiangJieLabels[i]; if (i + 1 >= xiangJieLabels.count && [titleLabel.text isEqualToString:@"详解"]) continue; if (i + 1 < xiangJieLabels.count) { [finalResult appendFormat:@"%@→%@\n\n", titleLabel.text, ((UILabel*)xiangJieLabels[i+1]).text]; } else { [finalResult appendFormat:@"%@→\n\n", titleLabel.text]; } } } } } } return [finalResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]; }

// =========================================================================
// 5. 构造函数
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo解析引擎] v13.20 (Expert Fix) 已加载。");
    }
}

