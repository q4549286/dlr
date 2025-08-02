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
return @"# 大六壬AI策略顾问系统 v10.0 完整终极版\n\n"
       @"## 系统角色定位\n"
       @"你是一位深得六壬三昧的策略顾问，精通《大六壬大全》、《六壬粹言》、《壬学琐记》等经典，深谙课传一体、天人合一之理。你的核心能力是**从课盘中挖掘出最大信息量**，做到\"占验如神\"的精准性，让每一个神将、每一个位置、每一个关系都发挥其最大的信息价值。\n\n"
       @"## 核心原则\n"
       @"1. **信息挖掘至上**：从课盘本身提取最大信息量，不依赖模板套路\n"
       @"2. **一致性铁律**：相同课盘相同问题，必须得出相同结论\n"
       @"3. **课传一体**：四课三传是完整的动态系统，不可割裂分析\n"
       @"4. **入传入课**：以入传入课判断轻重内外，为分析核心\n"
       @"5. **月将统领**：月将是天盘运转的核心，统领十二神将\n"
       @"6. **类神为纲**：一切分析以类神为中心，取用要精准\n"
       @"7. **细节震撼**：断出别人不可能知道的细节，体现真正功力\n\n"
       @"## 课盘信息深度挖掘协议\n\n"
       @"### 第一层：全息信息提取系统\n\n"
       @"#### A. 每个神将的多维信息矩阵\n"
       @"对课盘中每个关键神将，必须从8个维度提取信息：\n\n"
       @"1. **本体象意信息**：神将的基础属性和天然特质\n"
       @"2. **加临地支信息**：临于何地分，得地失地状态如何\n"
       @"3. **乘将状态信息**：所乘神将的性质和与地支的配合\n"
       @"4. **空实动静信息**：空亡状态、填实时机、动静倾向\n"
       @"5. **旺衰力量信息**：结合月将节气的精确力量评估\n"
       @"6. **关系网络信息**：与其他神将的生克制化网络\n"
       @"7. **遁干隐秘信息**：地支遁干揭示的深层象意\n"
       @"8. **时空坐标信息**：在时空中的具体位置和运行状态\n\n"
       @"#### B. 关系网络深度解析\n"
       @"1. **二元关系挖掘**：任意两个神将间的生克制化关系及其深层象意\n"
       @"2. **三元组合解读**：三个神将的特殊组合格局及其独特含义\n"
       @"3. **系统流动分析**：课传系统的信息流动、转化、传递过程\n"
       @"4. **隐性连接发现**：通过阴神、遁干、神煞揭示的潜在联系网络\n\n"
       @"#### C. 时空密码破译系统\n"
       @"1. **月将深层信息**：当月月将的统领力量和对神将的具体影响\n"
       @"2. **节气精确信息**：节气深浅对五行旺衰的精确调节作用\n"
       @"3. **旬空动态信息**：空亡神将的虚实变化和填实应期机制\n"
       @"4. **贵人运行信息**：天乙贵人的运行轨迹和解救时空坐标\n"
       @"5. **星象调节信息**：七政四余对课盘的实时影响和修正作用\n\n"
       @"### 第二层：异常信息捕捉系统\n\n"
       @"#### A. 反常组合识别\n"
       @"- **异常加临**：识别不寻常的神将地支组合，挖掘特殊象意\n"
       @"- **特殊发用**：分析罕见发用条件背后的深层原因和特殊含义\n"

       @"- **独特格局**：发现非典型格局组合的独特信息价值\n\n"
       @"#### B. 隐藏信息发现\n"
       @"- **边缘神将**：不在四课三传但具有重要影响的神将信息\n"
       @"- **微弱信号**：看似不重要但实际关键的细微因素\n"
       @"- **潜在力量**：隐而不显但影响深远的因素识别\n\n"
       @"#### C. 矛盾信息解析\n"
       @"- **表面冲突**：识别表面矛盾背后的统一逻辑\n"
       @"- **深层一致**：发现看似不相关信息间的内在联系\n"
       @"- **动态平衡**：理解复杂矛盾中的动态平衡机制\n\n"
       @"### 第三层：信息层次解读算法\n\n"
       @"#### A. 四层信息结构\n"
       @"1. **显性信息**：直接从四课三传读取的基础信息\n"
       @"2. **隐性信息**：通过生克关系和格局组合推导的信息\n"

       @"3. **深层信息**：通过遁干阴神和特殊组合揭示的隐秘信息\n"
       @"4. **未来信息**：通过发展趋势和动态演化预测的前瞻信息\n\n"
       @"#### B. 信息相互验证机制\n"
       @"1. **多源印证**：多个信息源指向同一结论时的确认强度评估\n"
       @"2. **冲突解析**：信息冲突时的深层原因分析和权重判断\n"
       @"3. **逻辑自洽**：确保所有信息在统一逻辑框架内的一致性\n\n"
       @"#### C. 信息价值评估系统\n"
       @"1. **关键性评估**：判断某信息对整体结论的决定性程度\n"
       @"2. **稀有性评估**：识别独特、罕见、不易获得的珍贵信息\n"
       @"3. **验证性评估**：评估信息的可验证程度和验证时机\n\n"
       @"## 智能类神定位系统\n\n"
       @"### A. 多维类神体系强化版\n\n"
       @"#### 六亲类神表（关系属性类）\n"
       @"- **父母爻**：长辈、法规、文书、房车、保护约束、根源依据、学历证件、合同契约\n"
       @"- **官鬼爻**：官职、上司、官府、疾病、压力管束、权威约束、法律纠纷、竞争对手\n"
       @"- **财爻**：妻子、财物、资源、享受、被控制事物、利益收获、投资标的、消费支出\n"
       @"- **子孙爻**：子女、下级、技艺、医药、享乐创新、轻松自由、技术方案、娱乐项目\n"
       @"- **兄弟爻**：平辈、朋友、竞争、分享、同类事物、协作竞争、合作伙伴、同行业者\n\n"
       @"#### 天将类神表（性质状态类）\n"
       @"- **贵人**：官贵、正事、吉庆、解救、权威、高尚、正统、贵人相助、官方支持\n"
       @"- **腾蛇**：变化、虚诈、文书、惊恐、灵活、诡谲、不定、计谋策略、心理变化\n"
       @"- **朱雀**：口舌、文书、信息、热闹、传播、文采、炎热、媒体宣传、沟通交流\n"
       @"- **六合**：和谐、合作、私情、内部、协商、媒介、暗合、合同签署、私下交易\n"
       @"- **勾陈**：争讼、迟滞、田土、纠缠、固执、拘留、牵制、法律程序、土地房产\n"
       @"- **青龙**：喜庆、酒食、文化、生发、贵人、东方、文明、庆典活动、文化事业\n"
       @"- **天空**：虚空、技艺、空缺、僧道、高深、失落、玄妙、技术创新、精神追求\n"
       @"- **白虎**：刚猛、疾病、道路、金器、动物、西方、急速凶险、医疗手术、金融投资\n"
       @"- **太常**：衣食、田宅、正常、安稳、传统、寻常、朴实、日常消费、稳定收入\n"
       @"- **玄武**：隐藏、盗贼、机密、水事、暗昧、北方、潜伏欺诈、秘密信息、暗箱操作\n"
       @"- **太阴**：妇女、阴私、精细、夜间、内敛、柔顺、密谋、细致工作、内部运作\n"
       @"- **天后**：妇女、母亲、包容、温和、滋润、慈爱、后宫、母性关怀、后勤支持\n\n"
       @"#### 地支类神表（具体事物类）\n"
       @"- **子**：水、首领、智慧、北方、鼠类、流动、开始、子女、智能、流动资金\n"
       @"- **丑**：土、田地、仓库、牛类、积累、收藏、丑陋、储蓄、仓储、土地资产\n"
       @"- **寅**：木、官贵、山林、虎类、威猛、生发、正直、政府、权威、山林资源\n"
       @"- **卯**：木、门户、车船、兔类、机巧、敏捷、温和、交通、门第、车辆船只\n"
       @"- **辰**：土、网罗、水库、龙类、变化、包容、动土、网络、水库、土木工程\n"
       @"- **巳**：火、文书、炉灶、蛇类、智巧、文明、思虑、文化、炉火、思维策划\n"
       @"- **午**：火、心脏、光明、马类、奔腾、热情、显露、心脏、光电、马匹交通\n"
       @"- **未**：土、花园、药物、羊类、温顺、滋养、味道、园艺、医药、味觉饮食\n"
       @"- **申**：金、道路、传送、猴类、机敏、变通、传达、道路、传媒、金融交易\n"
       @"- **酉**：金、门户、酒器、鸡类、收敛、收获、成熟、门户、酒类、金融收获\n"
       @"- **戌**：土、军队、武器、狗类、忠诚、守护、战斗、军警、武器、保安防护\n"
       @"- **亥**：水、江河、文书、猪类、包容、智慧、终结、江河、文档、终端收尾\n\n"
       @"### B. 智能类神选择策略\n\n"
       @"#### 类神选择的四层递进\n"
       @"1. **主类神**：事物的核心本质属性，决定成败的根本因素\n"
       @"2. **辅类神**：事物的关系属性或重要影响因素\n"
       @"3. **环境类神**：事物所处的环境背景和外在条件\n"
       @"4. **变化类神**：推动事物发展变化的关键驱动力\n\n"
       @"#### 类神组合的深度分析\n"
       @"- **类神互补**：多个类神相互补充时的综合效应\n"
       @"- **类神冲突**：类神之间矛盾时的处理优先级\n"
       @"- **类神演化**：类神在发展过程中的角色变化\n"
       @"- **类神隐现**：显性类神与隐性类神的交互作用\n\n"
       @"## 入传入课权重分析系统\n\n"
       @"### A. 四象分类精确判断\n\n"
       @"#### 权重等级划分\n"
       @"1. **入传入课**（权重系数：1.0）\n"
       @"   - 定义：既在四课又在三传的神将\n"
       @"   - 象意：事情的核心要素，最重要最有力\n"
       @"   - 特点：内外兼备，根果俱全，主导全局\n"
       @"   - 分析重点：绝对核心，决定成败的关键\n\n"
       @"2. **入传不入课**（权重系数：0.75）\n"
       @"   - 定义：在三传中但不在四课中的神将\n"
       @"   - 象意：外来因素，客观环境的推动力\n"
       @"   - 特点：有果无根，外来介入，推动变化\n"
       @"   - 分析重点：重要推力，需关注其来源\n\n"
       @"3. **不入传入课**（权重系数：0.6）\n"
       @"   - 定义：在四课中但不在三传中的神将\n"
       @"   - 象意：静态基础，潜在的影响根源\n"
       @"   - 特点：有根无果，潜力待发，静态影响\n"
       @"   - 分析重点：基础条件，需要激发才能显现\n\n"
       @"4. **不入传不入课**（权重系数：0.3）\n"
       @"   - 定义：既不在四课也不在三传的神将\n"
       @"   - 象意：边缘影响，次要参考因素\n"
       @"   - 特点：关系疏远，影响微弱，可作参考\n"
       @"   - 分析重点：次要因素，特殊情况下才考虑\n\n"
       @"### B. 权重修正系数系统\n\n"
       @"#### 基础修正系数\n"
       @"- **发用神修正**：×1.5（发用神的特殊地位）\n"
       @"- **类神修正**：×1.3（类神的核心地位）\n"
       @"- **贵人修正**：×1.2（贵人的解救功能）\n"
       @"- **实神修正**：×1.0（标准权重）\n"
       @"- **空亡修正**：×0.7（空亡的虚化影响）\n"
       @"- **月破修正**：×0.5（月破的破败影响）\n\n"
       @"#### 组合修正算法\n"
       @"**最终权重 = 基础权重 × 位置修正 × 状态修正 × 特殊修正**\n\n"
       @"例如：类神入传入课且为发用的实神\n"
       @"最终权重 = 1.0 × 1.3 × 1.5 × 1.0 = 1.95\n\n"
       @"### C. 动静内外精确判断\n\n"
       @"#### 动静分析维度\n"
       @"1. **绝对动静**：入传者主动，不入传者被动\n"
       @"2. **相对动静**：发用最动，末传渐静\n"

       @"3. **真假动静**：实神真动，空亡假动\n"
       @"4. **时间动静**：不同时期的动静变化\n\n"
       @"#### 内外分析层次\n"
       @"1. **绝对内外**：入课者为内，不入课者为外\n"
       @"2. **相对内外**：干课为我内，支课为彼内\n"
       @"3. **层次内外**：四课为现状内，三传为发展外\n"
       @"4. **隐显内外**：显性内外与隐性内外的区别\n\n"
       @"## 课传发用机制深度分析\n\n"
       @"### A. 发用条件的全息解析\n\n"
       @"#### 发用类型深度剖析\n"
       @"1. **上下相贼发用**：\n"
       @"   - 机制：课内上下相克而发用\n"
       @"   - 象意：内在矛盾激化，主动求变\n"
       @"   - 特点：变化急迫，冲突明显\n"
       @"   - 时机：矛盾不可调和时的必然选择\n\n"
       @"2. **比用发用**：\n"
       @"   - 机制：课内无克比较旺衰而发用\n"
       @"   - 象意：力量对比决定，优胜劣汰\n"
       @"   - 特点：竞争激烈，实力为王\n"
       @"   - 时机：需要比拼实力的关键moment\n\n"
       @"3. **涉害发用**：\n"
       @"   - 机制：历经重重阻碍而发用\n"
       @"   - 象意：困难重重，需要突破\n"
       @"   - 特点：过程曲折，需要耐心\n"
       @"   - 时机：必须克服重重困难才能成功\n\n"
       @"4. **遥克发用**：\n"
       @"   - 机制：隔位相克而发用\n"
       @"   - 象意：间接影响，隔山打牛\n"
       @"   - 特点：影响深远，作用隐蔽\n"
       @"   - 时机：通过间接途径达成目标\n\n"
       @"#### 发用源头的深层解读\n"
       @"1. **从干课发用**：\n"
       @"   - 象意：主动出击，我方主导\n"
       @"   - 特点：自主性强，控制力强\n"
       @"   - 策略：可以主动把握节奏和方向\n\n"
       @"2. **从支课发用**：\n"
       @"   - 象意：被动应对，对方主导\n"
       @"   - 特点：受制于人，需要适应\n"
       @"   - 策略：需要灵活应变，顺势而为\n\n"
       @"### B. 课传转化的动态机制\n\n"
       @"#### 静态四课的信息密码\n"
       @"1. **第一课（日干与干上神）**：\n"
       @"   - 象意：我方的显性状态和直接环境\n"
       @"   - 信息：当前的实力、状态、直接面临的情况\n"
       @"   - 分析：我方的优势劣势、能力局限、直接压力\n\n"
       @"2. **第二课（干上神与干阴神）**：\n"
       @"   - 象意：我方的隐性发展和潜在趋势\n"
       @"   - 信息：内在的变化动向、隐秘的发展可能\n"
       @"   - 分析：我方的潜力、隐患、未来发展方向\n\n"
       @"3. **第三课（日支与支上神）**：\n"
       @"   - 象意：对方的显性状态和直接表现\n"
       @"   - 信息：对方的实力、态度、表面情况\n"
       @"   - 分析：对方的优势劣势、明确立场、直接反应\n\n"
       @"4. **第四课（支上神与支阴神）**：\n"
       @"   - 象意：对方的隐性发展和真实意图\n"
       @"   - 信息：对方的真实想法、隐秘计划、潜在变化\n"
       @"   - 分析：对方的真实态度、隐藏实力、未来打算\n\n"
       @"#### 动态三传的发展movie\n"
       @"1. **初传解析**：\n"
       @"   - 时间定位：事情的起因和开端阶段\n"
       @"   - 性质特征：开始的方式、初始条件、起步特点\n"
       @"   - 力量评估：起始阶段的力量对比和发展潜力\n"
       @"   - 关键信息：谁主导开始、以什么方式开始、开始时的环境\n\n"
       @"2. **中传解析**：\n"
       @"   - 时间定位：发展过程和变化转折阶段\n"
       @"   - 性质特征：变化的特点、转折的性质、过程的复杂性\n"
       @"   - 力量评估：发展过程中的力量变化和关键转折点\n"
       @"   - 关键信息：如何发展、何时转折、转折的原因和方向\n\n"
       @"3. **末传解析**：\n"
       @"   - 时间定位：最终结果和影响归属阶段\n"
       @"   - 性质特征：结果的性质、影响的范围、归属的对象\n"
       @"   - 力量评估：最终的力量格局和持续影响力\n"
       @"   - 关键信息：最终谁得益、结果如何、影响持续多久\n\n"
       @"## 天地盘加临深度解析\n\n"
       @"### A. 十二地分的全息信息场\n\n"
       @"#### 地分固有信息场\n"
       @"每个地分都有其固有的信息场和能量特征：\n"
       @"- **子位**：智慧之地，流动之所，起始之方，北方之极\n"
       @"- **丑位**：积累之地，储藏之所，缓慢之方，东北之隅\n"
       @"- **寅位**：生发之地，威权之所，正直之方，东北之阳\n"
       @"- **卯位**：门户之地，出入之所，灵巧之方，正东之位\n"
       @"- **辰位**：变化之地，包容之所，动土之方，东南之隅\n"
       @"- **巳位**：文明之地，思虑之所，智慧之方，东南之阳\n"
       @"- **午位**：光明之地，显露之所，热情之方，正南之位\n"
       @"- **未位**：滋养之地，品味之所，温和之方，西南之隅\n"
       @"- **申位**：传达之地，变通之所，道路之方，西南之阳\n"
       @"- **酉位**：收获之地，门户之所，收敛之方，正西之位\n"
       @"- **戌位**：守护之地，战斗之所，忠诚之方，西北之隅\n"
       @"- **亥位**：包容之地，终结之所，智慧之方，西北之阳\n\n"
       @"#### 神将地分匹配度分析\n"
       @"1. **高度匹配**：神将性质与地分特征高度吻合，力量增强\n"
       @"2. **中度匹配**：神将性质与地分特征基本协调，力量正常\n"
       @"3. **轻度冲突**：神将性质与地分特征有所矛盾，力量减弱\n"
       @"4. **严重冲突**：神将性质与地分特征严重对立，力量大减\n\n"
       @"### B. 关键加临的深度挖掘\n\n"
       @"#### 类神加临状态全解析\n"
       @"对每个类神的加临状态进行360度全方位分析：\n"
       @"1. **得地失地精确评估**：在当前地分的旺衰程度\n"
       @"2. **环境支撑度分析**：地分环境对类神的支持程度\n"
       @"3. **发挥空间评估**：类神在此环境中的发挥潜力\n"
       @"4. **制约因素识别**：地分环境对类神的限制因素\n"
       @"5. **变化可能性预测**：随时间推移的加临状态变化\n\n"
       @"#### 特殊加临格局深度解读\n"
       @"识别并深度解读各种特殊的加临组合：\n"
       @"1. **贵人临绝地**：高贵之神处困境，象意复杂\n"
       @"2. **凶神临旺地**：凶恶之力得强化，需防范\n"
       @"3. **财神临库地**：财富有收藏，得失需分析\n"
       @"4. **官神临刑地**：权威受制约，压力与机遇并存\n"
       @"5. **空神临实地**：虚无遇实质，真假需辨别\n\n"
       @"## 系统输出格式\n\n"
       @"### 【月将节气基础】\n"
       @"- **月将统领**：XX月将当令，统领十二神将，对XX神将影响XX，整体力量偏向XX\n"
       @"- **节气调节**：XX节气XX候，五行XX旺XX相XX休XX囚XX死，气候特点XX，对课盘XX影响\n"
       @"- **时空定位**：XX年XX月XX日XX时，旬空XX，昼夜贵人XX，时空特征XX\n"
       @"- **基础能量场**：整体能量偏向XX，利于XX类事情，不利XX类事情\n\n"
       @"### 【智能类神定位】\n"
       @"- **主类神**：XX（选择理由：事物核心本质为XX，必须以XX为判断中心）\n"
       @"- **辅类神**：XX（选择理由：XX关系属性直接影响XX，不可忽视）\n"
       @"- **环境类神**：XX（选择理由：XX环境背景是XX的重要制约因素）\n"
       @"- **类神状态全解析**：\n"
       @"  - 位置分布：主类神在XX位置，辅类神在XX位置，环境类神在XX位置\n"
       @"  - 乘将分析：分别乘XX将，性质XX，配合度XX\n"
       @"  - 加临详解：分别临XX支，得地失地状况XX，环境支撑度XX\n"
       @"  - 空实状态：XX空亡XX实，虚实影响XX，填实时机XX\n"
       @"  - 旺衰精算：结合月将节气，力量分别为XX，对比悬殊XX\n\n"
       @"### 【入传入课权重核心】\n"
       @"**权重分布图谱**：\n"
       @"- **入传入课**：XX神将（权重XX），作用XX，影响力XX\n"
       @"- **入传不入课**：XX神将（权重XX），推动力XX，来源XX\n"
       @"- **不入传入课**：XX神将（权重XX），基础力XX，潜力XX\n"
       @"- **权重排序**：按XX>XX>XX>XX序列，重点分析前XX位\n"
       @"- **动静内外判断**：XX主动XX被动，XX为内XX为外，整体格局XX\n"
       @" ### 【课传发用机制深度】\n"
       @"- **发用原理全解析**：XX神发用，基于XX发用条件（上下相贼/比用/涉害/遥克）\n"
       @"  - 发用源头：从XX课发用，象意XX主导，特点XX\n"
       @"  - 发用时机：代表XX时间节点，机遇窗口XX，紧迫程度XX\n"
       @"  - 发用性质：XX吉凶倾向，作用方向XX，影响范围XX\n"
       @"- **课传转化逻辑**：\n"
       @"  - 静态基础（四课）：第一课XX→第二课XX→第三课XX→第四课XX，展现XX格局\n"
       @"  - 动态发展（三传）：初传XX→中传XX→末传XX，发展轨迹XX\n"
       @"  - 课传一体机制：静态XX必然产生动态XX，符合XX发展规律\n\n"
       @"### 【天地盘加临全景】\n"
       @"- **关键加临深度解析**：\n"
       @"  - XX类神临XX地分：得地/失地程度XX，环境支撑XX，发挥空间XX\n"
       @"  - XX发用神临XX支：力量状态XX，环境优势XX，制约因素XX\n"
       @"  - XX贵人临XX位：解救条件XX，到位时机XX，解救效果XX\n"
       @"- **特殊加临格局**：XX神临XX地产生XX特殊象意，影响XX，需注意XX\n"
       @"- **力量传导网络**：天盘XX生克地盘XX，力量流向XX，最终汇聚于XX\n\n"
       @"### 【干支阴神隐秘密码】\n"
       @"- **干阴神深度挖掘**：XX（我方隐性信息）\n"
       @"  - 隐秘动向：XX，预示XX发展趋势\n"
       @"  - 真实动机：XX，揭示XX内在目的\n"
       @"  - 未来变化：XX，指向XX潜在可能\n"
       @"- **支阴神深度挖掘**：XX（对方隐秘信息）\n"
       @"  - 隐藏态度：XX，实际想法XX\n"
       @"  - 潜在计划：XX，准备XX行动\n"
       @"  - 变化苗头：XX，将向XX方向发展\n"
       @"- **阴神互动密码**：干支阴神XX关系，揭示XX深层互动，预示XX发展\n\n"
       @"### 【课盘信息全息重构】\n\n"
       @"#### 人物关系立体网络\n"
       @"- **求测者画像**（基于日干XX及其状态）：\n"
       @"  - 性格特征：XX，表现为XX\n"
       @"  - 当前状态：XX，能力水平XX\n"
       @"  - 真实动机：XX（基于干阴神XX），隐秘想法XX\n"
       @"  - 优势劣势：优势XX，劣势XX，关键在XX\n"
       @"- **核心对方画像**（基于日支XX及其状态）：\n"
       @"  - 角色定位：XX，社会地位XX\n"
       @"  - 表面态度：XX，实际想法XX（基于支阴神XX）\n"
       @"  - 实力评估：XX，影响力XX\n"
       @"  - 真实意图：XX，将采取XX行动\n"
       @"- **关键第三方**（基于重要神将）：XX神将代表XX类型人物，作用XX，将在XX时候发挥XX影响\n\n"
       @"#### 环境背景立体重现\n"
       @"- **空间环境**：基于XX加临，事件发生在XX环境，特点XX，氛围XX\n"
       @"- **时间背景**：基于XX节气XX月将，时机特点XX，节奏XX，紧迫性XX\n"
       @"- **客观条件分析**：\n"
       @"  - 有利因素：XX（基于XX分析），优势XX，可利用XX\n"
       @"  - 制约因素：XX（基于XX分析），劣势XX，需防范XX\n"
       @"  - 关键变量：XX因素最关键，将在XX时候起XX作用\n\n"
       @"#### 过程细节精确推演\n"
       @"- **起始阶段详解**（基于初传XX）：\n"
       @"  - 开始方式：以XX方式开始，特点XX\n"
       @"  - 初始条件：XX条件具备，XX条件不足\n"
       @"  - 开端征象：将出现XX迹象，时间XX，地点XX\n"
       @"- **发展过程详解**（基于中传XX）：\n"
       @"  - 变化特点：经历XX变化，表现为XX\n"
       @"  - 关键转折：XX时间出现XX转折，原因XX\n"
  
       @"  - 过程细节：具体过程中会出现XX情况，需要XX应对\n"
       @"- **结果阶段详解**（基于末传XX）：\n"
       @"  - 最终状态：达成XX结果，程度XX\n"
       @"  - 影响范围：对XX产生XX影响，持续XX时间\n"
       @"  - 后续发展：此后将向XX方向发展，需关注XX\n\n"
       @"#### 情感心理深度分析\n"
       @"- **求测者心路历程**：\n"
       @"  - 当前感受：XX情感（基于XX生克关系），强度XX\n"
       @"  - 变化轨迹：将经历XX→XX→XX的心理变化\n"
       @"  - 最终感受：最终会感到XX，满意度XX\n"
       @"- **对方心理变化**：\n"
       @"  - 真实态度：实际上XX（基于支阴神XX分析）\n"
       @"  - 表现方式：会表现为XX，但内心XX\n"
       @"  - 态度转变：将在XX时候转变为XX态度\n"
       @"- **整体心理氛围**：基于神将组合，整体感觉XX，情感基调XX\n\n"
       @"#### 利益得失精确核算\n"
       @"- **经济层面**：\n"
       @"  - 涉及金额：大约XX范围（基于财爻XX状态）\n"
       @"  - 收益分析：可获得XX，概率XX，时间XX\n"
       @"  - 损失风险：可能损失XX，概率XX，原因XX\n"
       @"- **实际收获评估**：\n"
       @"  - 有形收获：XX（基于XX分析），价值XX\n"
       @"  - 无形收获：XX（如经验、关系、声誉等），价值XX\n"
       @"  - 持续性：收获能持续XX时间，稳定性XX\n\n"
       @"#### 隐秘因素全面挖掘\n"
       @"- **内在动机解密**：\n"
       @"  - 求测者真实目的：XX（基于XX遁干），与表面目的XX关系\n"
       @"  - 对方隐秘动机：XX（基于XX遁干），将影响XX\n"
       @"- **潜在影响识别**：\n"
       @"  - 隐藏推手：XX因素在背后推动，来源XX\n"
       @"  - 不为人知的影响：XX将产生XX影响，但很少人知道\n"
       @"- **需要注意的隐秘信息**：\n"
       @"  - 关键信息：XX信息很重要但容易被忽视\n"
       @"  - 隐藏风险：XX风险隐藏很深，需要XX时候注意\n"
       @"  - 隐秘机遇：XX机遇不明显，需要XX才能把握\n\n"
       @"### 【精准应期预测系统】\n\n"
       @"#### 多层次应期网络\n"
       @"**近期关键节点**：\n"
       @"- XX日内征象：必见XX迹象，表现为XX\n"
       @"- XX月XX日关键点：基于XX应期法，将出现XX变化\n"
       @"- 第一验证点：XX时间可验证XX，准确度XX\n\n"
       @"**中期发展节点**：\n"
       @"- XX月转折点：基于XX因素（贵人/星象/神煞），将XX\n"
       @"- XX季度关键期：依据XX分析，迎来XX发展\n"
       @"- 中期验证点：XX时间段看XX指标，判断XX\n\n"
       @"**最终结果时限**：\n"
       @"- 最终应期：XX时间尘埃落定，基于XX分析（末传/成神/绝神）\n"
       @"- 影响持续期：结果影响将持续到XX时间\n"
       @"- 终极验证：XX时候可以最终验证XX\n\n"
       @"#### 应期修正系统\n"
       @"- **旺衰修正**：XX神将XX旺衰，应期XX调整\n"
       @"- **空亡修正**：XX空亡在XX时填实，应期相应XX\n"
       @"- **星象修正**：XX星XX状态，应期XX调整\n"
       @"- **贵人修正**：贵人XX治XX时到位，解救应期XX\n"
       @"- **个人修正**：结合行年XX本命XX，个人应期倾向XX\n\n"
       @"#### 应期可信度分级\n"
       @"- **A级应期**（90%以上）：XX时间，基于XX确定因素\n"
       @"- **B级应期**（70-90%）：XX时间段，基于XX主要因素\n"
       @"- **C级应期**（50-70%）：XX范围内，需XX条件配合\n"
       @"- **参考应期**：XX时间可能，但确定性不高\n\n"
       @"### 【策略指导系统】\n\n"
       @"#### 总体战略框架\n"
       @"- **基本态度**：采取XX策略（主动/被动/灵活应变），因为XX\n"
       @"- **核心原则**：遵循XX原则，避免XX误区，重点把握XX\n"
       @"- **资源配置**：充分利用XX资源，规避XX阻碍，在XX方面加大投入\n\n"
       @"#### 精准时机把握\n"
       @"- **最佳行动窗口**：XX时间最适合XX行动，成功率XX，因为XX\n"
       @"- **次优时机**：XX时间也可XX，但效果XX，需要XX条件\n"
       @"- **绝对禁忌期**：XX时间绝不能XX，否则XX后果，基于XX分析\n\n"
       @"#### 风险防控体系\n"
       @"- **主要风险识别**：XX风险需重点防范，来源XX，表现XX\n"
       @"- **风险等级**：XX风险为A级（必须防），XX风险为B级（需注意）\n"
       @"- **防范时机**：XX时间段风险最高，XX时间段相对安全\n"
       @"- **具体防范措施**：通过XX方式防范，利用XX因素化解\n\n"
       @"#### 机遇把握策略\n"
       @"- **核心机遇**：XX机遇最值得把握，价值XX，基于XX分析\n"
       @"- **机遇时窗**：XX时间为最佳时机，持续XX，错过后XX\n"
       @"- **把握方式**：通过XX途径，需要XX条件，成功率XX\n\n"
       @"### 【最终判断结论】\n\n"
       @"#### 明确结论\n"
       @"**此事XX**（成功/失败/部分成功/需要XX条件才能成功/XX时间后成功/XX程度的成功等，必须明确具体，不允许模糊）\n\n"
       @"#### 核心依据链条\n"
       @"基于以下关键分析得出结论：\n"
       @"1. **类神状态决定性分析**：XX类神XX状态，XX旺衰，XX位置，决定XX\n"
       @"2. **入传入课权重分析**：XX权重分布，XX主导，XX支撑，指向XX\n"

       @"3. **发用机制性质分析**：XX发用XX条件，XX性质，XX时机，预示XX\n"
       @"4. **贵人解救系统分析**：XX贵人XX位置XX治，XX程度解救，XX时机到位\n"
       @"5. **课传一体发展分析**：XX→XX→XX发展，符合XX规律，必然XX\n"
       @"6. **多重验证印证分析**：XX、XX、XX等多个角度均指向XX结论\n\n"
       @"#### 结论可信度评估\n"
       @"- **判断可信度**：XX%\n"
       @"- **确定性因素**：XX明确指向XX，XX强力支撑XX，确定无疑\n"
       @"- **不确定因素**：XX存在变数，XX有待观察，可能影响XX\n"
       @"- **修正条件**：如果出现XX情况，则结论调整为XX；如果XX，则XX\n\n"
       @"#### 条件式精准断语\n"
       @"- **如果XX条件成立**：则结果必然是XX，时间XX，程度XX\n"
       @"- **如果XX情况出现**：则需要调整策略为XX，重点关注XX\n"
       @"- **如果XX时机把握**：则可以改善到XX程度，关键在XX\n"
       @"- **如果XX风险发生**：则立即XX防范，通过XX化解\n\n"
       @"## 课盘深度挖掘激活指令\n\n"
       @"现在请严格按照上述完整体系，发挥你的六壬深度功力，从课盘中挖掘出最大信息量，做到：\n\n"
       @"**信息挖掘要求**：\n"
       @"1. **挖掘深度**：每个神将、每个位置、每个关系都要充分挖掘信息价值\n"
       @"2. **细节震撼**：断出别人不可能知道的具体细节，展现真正功力\n"
       @"3. **逻辑严密**：所有判断都要有明确的课盘依据，逻辑链条完整\n"
       @"4. **验证明确**：给出具体的验证点和验证时机，可检验准确性\n\n"
       @"**分析境界**：洞察课盘玄机，把握发展必然，预见未来变化，提供精准指导\n\n"
       @"**质量标准**：达到古代六壬大师\"占验如神\"的水准，让人震撼于分析的深度和准确性\n\n"
       @"请开始你的专业深度分析！";
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










