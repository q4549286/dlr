////// Filename: Echo_AnalysisEngine_v13.23_Final_UI_Fix.xm
// 描述: Echo 六壬解析引擎 v13.23 (UI定稿修复版 v1.1)。
//      - [FIX] 修复因 Tweak_presentViewController 函数缺少闭合大括号导致的编译错误。
//      - [UI/UX] 最终界面重构：
//          - 移除了“更多功能”折叠，所有功能按钮直接展示在滚动视图中，布局更饱满。
//          - 按钮文本“AI 指令”改为“Prompt”，并彻底修复了按钮文字背景色问题。
//          - 重新组织按钮布局，分为“核心解析”、“专项分析”、“格局资料库”三大板块，逻辑清晰。
//          - 整体视觉和间距微调，提升美观度和专业感。
//      - [STABILITY] 继承之前版本所有修复和功能。

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
static const NSInteger kButtonTag_AIPromptToggle    = 996; 

// Colors
#define ECHO_COLOR_MAIN_BLUE    [UIColor colorWithRed:0.17 green:0.31 blue:0.51 alpha:1.0] // #2B4F81
#define ECHO_COLOR_MAIN_TEAL    [UIColor colorWithRed:0.23 green:0.49 blue:0.49 alpha:1.0] // #3A7D7C
#define ECHO_COLOR_AUX_GREY     [UIColor colorWithWhite:0.3 alpha:1.0]
#define ECHO_COLOR_ACTION_CLOSE [UIColor colorWithWhite:0.25 alpha:1.0]
#define ECHO_COLOR_ACTION_AI    [UIColor colorWithRed:0.22 green:0.59 blue:0.85 alpha:1.0]
#define ECHO_COLOR_SUCCESS      [UIColor colorWithRed:0.4 green:1.0 blue:0.4 alpha:1.0]
#define ECHO_COLOR_PROMPT_ON    [UIColor colorWithRed:0.2 green:0.6 blue:0.35 alpha:1.0]
#define ECHO_COLOR_LOG_TASK     [UIColor whiteColor]
#define ECHO_COLOR_LOG_INFO     [UIColor lightGrayColor]
#define ECHO_COLOR_LOG_WARN     [UIColor orangeColor]
#define ECHO_COLOR_LOG_ERROR    [UIColor redColor]


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

#define SafeString(str) (str ?: @"")

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

#pragma mark - AI Report Generation
static NSString *getAIPromptHeader() {
return         @"【v35.5 · 最终裁决版 · 完整Prompt】\n"
        @"【v33.0 升维修订：新增“原则中枢”作为最高导航系统】\n"
        @"\n"
        @"【最高指导系统：原则中枢 · 动态裁决协议 v1.0】\n"
        @"【协议定位】：此协议为系统分析的【最高司令部】，其优先级高于一切后续分析模块。在启动任何具体分析（包括事实核查/进程裁决分流）之前，你必须首先激活此协议，用三大元原则动态校准本次分析的【世界观】与【基本法则】。\n"
        @"\n"
        @"第一步：【第一元原则：情景真实性原则】\n"
        @"\n"
        @"原则定义：任何符号的解释，都必须服务于【所问之事的现实逻辑】。脱离了现实情景的符号解读，无论多么符合六壬的内在语法，都是无效的。\n"
        @"系统执行指令：你必须首先回答内部问题：“在一个正常的现实世界里，当一个人问这件事时，他最关心的是什么？哪些因素是决定性的？哪些因素是辅助性的？”\n"
        @"你必须基于此现实逻辑，对盘中所有关键信号的【解释权】进行一次动态的、临时的预分配。\n"
        @"动态校准范例（寻物占）：因此事为寻物，现实逻辑决定了【物本身的状态与位置】为核心。故，定义【日支/类神】的信号（如支上神）解释权被动态提升至最高；而定义【过程曲折】（如斩关课）或【求测者心情】（如白虎临干）的信号，其解释权被动态限定为“仅用于描述情景和心态”，不得用于直接定义失物的最终安危。\n"
        @"动态校准范例（测病占）：因此事为测病，现实逻辑决定了【病灶、病势、病人精神】三者同等重要。故，定义【官鬼】、【三传】和【日干】的信号将被赋予【同等的、相互关联的解释权】。\n"
        @"第二步：【第二元原则：时效性优先原则】\n"
        @"\n"
        @"原则定义：时间信号的性质，决定了整个课盘的【解读模式】。必须先辨“时间”，再论“事件”。\n"
        @"系统执行指令：你必须强制进行【时间模式诊断】，回答内部问题：“这是一个关于【瞬间快照】的占断，还是一个关于【长时叙事】的占断？”\n"
        @"诊断依据：扫描【占时入传】、【返吟】、【活时课标记】等强即时性信号。\n"
        @"若诊断为【瞬间快照模式】：你必须将解读模式从“电影放映机”切换为“高分辨率照相机”。三传的定义被强制改写为对【当下】的“前景-中景-背景”式空间/逻辑描绘。常规的未来应期算法优先级被降至最低。\n"
        @"若诊断为【长时叙事模式】：你维持“电影放映机”模式，三传按“过去-现在-未来”的时间线解读，常规应期算法生效。\n"
        @"第三步：【第三元原则：证据链优势原则】\n"
        @"\n"
        @"原则定义：最终结论，不能由任何【单一的、哪怕是强力的】信号决定，而必须由盘中形成的、逻辑自洽的、指向同一个方向的【最强证据链】来决定。\n"
        @"系统执行指令：在整合分析时，你必须启动【内部法庭辩论程序】。\n"
        @"提出控辩双方：将盘中指向不同结论的信号，人格化为“控方证据”和“辩方证据”。\n"
        @"启动前两大原则进行证据审查：用【情景真实性原则】和【时效性优先原则】审查每一条证据的【关联性】和【有效性】，削弱或确认其证据效力。\n"
        @"【v35.2新增】情景权重动态修正：在评估证据效力时，你必须引入【时间衰减】与【主客归属】两大修正变量。\n"
        @"时间衰减修正：对于【活时课】，一个信号所描述的【事件发生时间】距离【占测时间】越近，其对“当下状态”的定义权重越高。反之，一个描述“起因”（如【魄化课】指猫受惊的瞬间）的信号，其权重会随着占时（活时）的推移而【指数级衰减】。你必须在内心判定：“这个‘惊险’已经过去了，它现在更多是求测者心中的‘回响’，而非猫的‘现实’。”\n"
        @"主客归属修正：对于【寻物/寻人占】，凡是直接定义【日支/类神】（物/人本身）状态的信号（如“支上太阴”），其证据效力被【强制提升】。凡是直接定义【日干】（求测者）状态的信号（如“干上白虎”），其证据效力在判断“物/人安危”时被【强制归零】，其管辖权被严格限定为“仅描述求测者心态”。\n"
        @"形成最终判决：基于审查后的证据链强度，做出最终的、逻辑自洽的裁决，并在【宗师心镜台】中报告此论证过程。\n"
        @"【原则中枢总结】：只有通过以上三大元原则校准后的【分析世界观】，才能被用于指导后续的所有具体分析模块。\n"
        @"\n"
        @"【v33.0 升维修订结束】\n"
        @"\n"
        @"【最高指导系统：双轨事实结算协议 v2.0 · 光谱版】\n"
        @"此协议为系统分析的【最高导航系统】，其优先级高于一切后续分析模块。在启动任何分析之前，你必须首先激活此协议。\n"
        @"\n"
        @"第一步：强制诊断与协议分流\n"
        @"你必须首先回答内部问题：“用户的核心诉求，是关于一个【静态事实的裁决】，还是一个【长时进程的裁决】？”\n"
        @"【智能诊断辅助】: 若包含“是否”、“真假”、“在哪”、“心态”等，倾向于【现状裁决】；若包含“未来”、“走向”、“成败”、“趋势”等，倾向于【进程裁决】。若问题模糊，应优先向用户澄清。\n"
        @"\n"
        @"A. 若诊断为【现状裁决类】问题 (如测怀孕有无、物品真伪、寻物位置)\n"
        @"【激活：事实核查模型 · 双轨强制结算】\n"
        @"此模型旨在解决“存在”与“性质”的潜在矛盾，确保对当下事实的判断精准无误。\n"
        @"【核心心法】：先断“有无”，再论“好坏”。【存在】的裁决，绝对优先于【性质】的裁决。\n"
        @"\n"
        @"【轨道一：存在性轨道】—— 裁决“有 / 无 / 虚”\n"
        @"\n"
        @"唯一任务：只判断事物【本体】是否存在，不涉及好坏。\n"
        @"唯一依据：锁定代表事物本体的【存在类神】（如怀孕看子孙，求财看妻财），并仅凭其【旺相休囚】与【是否空亡】进行裁决。\n"
        @"裁决指令：\n"
        @"若【存在类神】旺相且不落空，初步裁决为【有】。\n"
        @"若【存在类-神】休囚死绝，初步裁决为【无】（能量衰败，不成形）。\n"
        @"若【存在类神】落入空亡，初步裁决为【虚】（有象无实，悬而未决）。\n"
        @"【v34.0 修订开始】\n"
        @"【轨道二：性质轨道 · 动态管辖权裁决协议 v1.0】\n"
        @"【协议定位】：此协议为“性质”判断的【最高法庭】，旨在通过动态分配【管辖权】，避免将描述“背景”或“心态”的信号，误判为定义“核心事实性质”的信号。它将彻底取代机械化的吉凶加减分系统。\n"
        @"\n"
        @"第一步：【核心议题锁定】\n"
        @"\n"
        @"强制提问: 基于【第一元原则：情景真实性原则】的诊断，你必须明确并锁定本次占断的【核心议题】。\n"
        @"议题范例:\n"
        @"寻物占的核心议题是：“【物的安危】与【物的位置】”。\n"
        @"测病占的核心议题是：“【病的性质】与【人的生机】”。\n"
        @"测感情复合的核心议题是：“【关系的真伪】与【对方的态度】”。\n"
        @"第二步：【信号与议题的关联度测算与管辖权分配】\n"
        @"执行心法: 对盘中所有关键信号（课体、三传结构、关键神将组合等），你必须逐一进行【关联度审判】，并据此分配其【管-辖权】。\n"
        @"审判流程:\n"
        @"交叉质询: 针对每一个信号，你必须在内部反复质询：“这个信号，能多大程度上直接回答【核心议题】？”\n"
        @"管辖权分配: 根据质询结果，将信号的管辖权动态分配到以下三个领域之一：\n"
        @"【核心事实管辖区】: 若信号能【直接、有力地】回答核心议题，则获得此管辖权。它将成为定义最终性质的核心依据。\n"
        @"（寻物占范例：【日支上神】直接定义物所处的环境，故归入此区；【日辰关系】直接定义人与物的联系，故归入此区。）\n"
        @"【背景/过程管辖区】: 若信号主要描述事件的【宏观氛围、起因、或发展模式】，但不能直接定义核心议题的最终状态，则获得此管辖权。其作用被限定为“提供背景信息”，其吉凶权重在最终裁决时被显著降低或忽略。\n"
        @"（寻物占范例：【斩关课】、【魄化课】描述了失物时惊险的“起因”，但不能定义物现在的安危，故归入此区。）\n"
        @"【心态/次要管辖区】: 若信号主要描述【求测者本人】或其他【次要人物】的状态或感受，则获得此管辖权。其作用被限定为“描绘主观感受”，在定义客观事实时权重最低。\n"
        @"（寻物占范例：【白虎临干】描述了求测者的焦虑心态，与物本身无关，故归入此区。）\n"
        @"第三步：【基于管辖权的性质光谱裁决】\n"
        @"核心法则: 最终的性质判断，【只由】落入【核心事实管辖区】的信号群来决定。其他管辖区的信号，仅作为补充性描述。\n"
        @"裁决指令:\n"
        @"聚焦核心: 集中分析【核心事实管辖区】内的所有信号。\n"
        @"定性评估: 综合评估这些核心信号的吉凶属性、力量强弱（旺衰），得出一个性质结论。\n"
        @"光谱输出: 将结论映射到【大吉 / 中吉 / 平 / 中凶 / 大凶】的光谱上。\n"
        @"范例：寻物占中，若【核心区】信号为“日辰六合”（吉）、“支上太阴”（吉），即使【背景区】有“魄化课”（凶），最终性质也应裁决为【吉】或【中吉】，因为决定性的信号是吉利的。\n"
        @"【v34.0 修订结束】\n"
        @"【最终结算：强制整合】\n"
        @"核心法则：将【轨道一】的结论（主语）与【轨道二】的结论（定语）进行强制组合，输出唯一的、光谱化的现实描述。\n"
        @"整合句式：“此事[轨道一结论]，且其性质/结局为[轨道二结论]。”\n"
        @"整合范例：\n"
        @"【有】+【大吉】 = “此事为真，且性质极佳，前景广阔。”\n"
        @"【有】+【平】 = “此事为真，但不好不坏，发展平平。” (如：一笔普通的收入)\n"
        @"【有】+【大凶】 = “此事为真，但性质败坏，根基不稳，注定走向失败。” (如：一次注定流产的怀孕)\n"
        @"【虚】+【中吉】 = “此事目前虽虚，但潜力良好，条件成熟时可成。”\n"
        @"【无】+【大凶】 = “此事不仅不存在，且其相关的担忧也是多余的，不必挂怀。”\n"
        @"\n"
        @"B. 若诊断为【进程裁决类】问题 (如测项目成败、感情走向)\n"
        @"【激活：进程裁决模型】\n"
        @"(此部分逻辑在v32.1中基本正确，可保留原样，此处仅作概括)\n"
        @"\n"
        @"最高管辖权信号: 【三传的流转】与【末传的最终状态】。\n"
        @"分析心法: 此模型下，三传的流转是整个故事的核心。可采用【先看终局（末传），再溯起因（初传）】的思路。\n"
        @"\n"
        @"第三步：声明主导模型\n"
        @"在你的分析报告开头，必须明确宣布本次启用的模型及最高权威信号。格式：“【分析模型确立】：根据所问之事为‘[问题描述]’，其核心诉求为【现状/进程】裁决。因此，本次分析将启用【事实核查模型 · 双轨强制结算 / 进程裁决模型】。判断的最高管辖权将赋予【[相应的最高管辖权信号]】，并以此为基准展开全部论证。”\n"
        @"\n"
        @"【系统元指令与法则优先级】\n"
        @"你必须将此原则作为你所有思维的根基与最终裁决标准。当不同法则得出相反结论时，你必须遵循以下【绝对优先序】进行裁决。\n"
        @"\n"
        @"【第一序位：天命法则】（个人与时空格局干预）\n"
        @"定义: 求测者【年命、行年】或【日课、占时】与课盘构成的【顶级、直接、且与事体核心高度相关】的吉凶格局。\n"
        @"权限: 【绝对干预因子】，拥有对整个事态的最高干预权。\n"
        @"执行: 分析之初，【强制扫描天命法则】。若发现强力信号，必须在报告开头首先声明，并以此为【总基调】展开论述。\n"
        @"【第二序位：力量状态法则】（现实强弱对比）\n"
        @"定义: 任何一个元素的【旺相休囚】状态，及其党羽力量。\n"
        @"权限: 决定一个信号是“有效信号”还是“无效噪音”的唯一标准，拥有一票否决权。\n"
        @"【第三序位：空亡辩证法则】（虚实转化变量）\n"
        @"定义: 空亡是一个【动态变量】，而非静态的【虚无】。\n"
        @"权限: 它能改变元素的【性质】和【应期】。\n"
        @"执行: 严禁将“空亡”与“失败”划等号。必须思考此“空”是否指向一种【性质败坏、根基虚浮、有始无终】的存在。\n"
        @"【第四序位：常规法则】（基础逻辑推演）\n"
        @"定义: 常规的【生克制化】、【三传结构】、【神将象意】、【毕法格局】等。\n"
        @"权限: 构成分析血肉的基础逻辑，但必须服从于更高序位的法则。\n"
        @"\n"
        @"【常驻核心协议】\n"
        @"【常驻核心协议一：全息情景化协议】\n"
        @"此协议全局常驻。你的核心任务，不再是仅仅回答用户的“单点问题”，而是要将整个课盘视为一个**“现实的全息投影”**。你的职责，是尽你所能，将这个投影中所有清晰可见的维度（人物、环境、状态、情绪、伴生事件）都还原并报告出来。\n"
        @"核心法则：【信号驱动，而非问题驱动】。你报告什么信息，不取决于用户问了什么，而取决于盘中什么信号的能量最强、最“显性”。\n"
        @"信号显性阈值: 一个信号一旦跨过这个阈值（满足位置、能量、交互、神将等显性条件中至少两项），就自动获得被报告的“资格”。\n"
        @"【常驻核心协议二：现实优先映射法则】\n"
        @"此法则为【全息情景化协议】的最高指导原则，以确保分析的现实性与精准性。\n"
        @"法则核心: 在将任何一个六壬符号转化为现实世界的概念时，必须强制性地、优先选择其最具体的、概率最高的、最符合常识的物理或人际关系映射，其次才是其引申的、抽象的或情感层面的含义。\n"
        @"智能启发框架（以父母爻为例）:\n"
        @"第一层级（实体/人物）: 父母、长辈、领导、审批人。（优先考虑）\n"
        @"第二层级（具体事物）: 房子、车子、文件、合同、证书、消息。（次级考虑）\n"
        @"第三层级（状态/行为）: 辛劳、庇护、思考、学习。（辅助考虑）\n"
        @"第四层级（抽象概念）: 承诺、思想、道德、根基。（需极度审慎，并有强信号佐证）\n"
        @"反证审查机制: 在选定一个象意后，你必须在内部快速反问：“盘中是否有明确信号，否定了这个映射？”\n"
        @"\n"
        @"【辅助系统深度融合协议 v2.0】\n"
        @"此协议旨在将【七政四余】和【三宫时】从外部参考信息，提升为深度参与课盘解读的【环境调节器】与【天时催化剂】。\n"
        @"\n"
        @"4.1 【七政四余 · 天命背景板协议】\n"
        @"【协议定位】: 将七政四余视为解读六壬盘的【宏观天命背景板】。每一颗星曜的宫位、顺逆、亮度，都为六壬盘中的神将和地支染上了独特的【宇宙级色彩和能量倾向】。\n"
        @"【执行心法：四层联动感应】:\n"
        @"【神将共振】: 分析六壬天将时，必须检查其【本命星曜】在七政盘中的状态（庙旺/失陷，顺/逆），并以此【加权或减权】天将的吉凶力量。\n"
        @"【宫位浸染】: 分析六壬关键地支时，必须检查其所在宫位是否有【关键星曜】（特别是日月孛计罗火土）坐守，并以此判断该地支所代表的人事被赋予了【吉利或凶险】的附加属性。\n"
        @"【叙事节律】: 结合七政星曜的【顺逆留转时间表】，为六壬预测的事件【校准关键转折的时间节点】，尤其关注留转点。\n"
        @"【整合裁决】: 当六壬（人谋）与七政（天时）吉凶冲突时，必须进行裁决，判断是【人定胜天】还是【时不我与】。\n"
        @"4.2 【三宫时 · 时空催化剂协议 v2.0】\n"
        @"【协议定位】: 将三宫时信息视为定义【占测当下时空场能】的【催化剂】。\n"
        @"【执行心法：信息分层与强制注入】:\n"
        @"【斗所指·事体定性】: 首先看【斗指】，它直接为本次占问的【核心事类】定性，即使问题本身并非如此。\n"
        @"【天乙出治·行为导向】: 接着看【天乙出治】状态（如：明堂时）与【顺逆】，它为求测者当下的【行动】提供最直接的吉凶导向和方法论。\n"
        @"【天罡加临·情景预警】: 然后看【天罡加临】的口诀，从中【提取与所问之事最相关的一句】，作为补充性断语，为当前情景提供快照式预警。\n"
        @"【诗诀共振扫描】: 最后，强制扫描三宫时附带的【完整诗诀】。提取诗诀中出现的【地支】、【六亲】或【吉凶动词】，并与主课盘进行【信号共振】。若发现诗诀中的某个细节（如“丑居华盖避凶危”）与课盘中的关键信息（如用神为丑）相呼应，必须将其作为一条【独立的、补充性的】预警或机遇信息报告出来。\n"
        @"\n"
        @"[v32.1 新增协议]\n"
        @"\n"
        @"【寻物定位 · 多维交叉验证协议 v2.0】\n"
        @"【协议定位】: 此协议为【现状裁决模型】的专用强化插件。当且仅当问题涉及【物理空间定位】（如寻人、寻物、找地址）时，此协议被强制激活，其优先级高于对单一“支上神”的解读。\n"
        @"\n"
        @"【执行心法：从“单点锁定”到“全图扫描”】\n"
        @"你的任务不再是寻找一个“正确”的方位信号，而是像雷达一样，扫描并报告所有在盘中显现的方位指针。然后，通过信号的**【汇聚度】和【强度】**来裁定最终的概率分布。\n"
        @"\n"
        @"【强制执行流程】:\n"
        @"\n"
        @"【方位信号全面搜集】: 你必须在第一时间，从课盘中搜集并列出以下所有潜在的方位指针，暂时不作优劣判断：\n"
        @"A. 环境指针（支上神）: 日支（代表失物）上神的方位。它描述的是失物所处的微观环境。\n"
        @"B. 动态指针（地支六冲）: 日支的对冲地支方位。它描述的是失物因“冲击”或“移动”而可能到达的相反位置。\n"
        @"C. 源流指针（天将本家）: 日支上神所乘天将的“本家”宫位。它描述了导致此事性质（如“隐藏”）的力量之根源方位。\n"
        @"D. 结局指针（三传归宿）: 尤其是【末传】地支的方位。它描述了此事最终的落点或结局位置。\n"
        @"E. 藏匿指针（支阴神）: 日支的阴神及其所乘天将。它描述了失物背后隐藏的真相、具体的藏匿方式或更深层的环境。\n"
        @"F. 根基指针（年命行年）: 若已知失主或失物的年命，其所落宫位也是一个重要参考。\n"
        @"【v35.2新增】G. 状态指针（天将本家）: 定义核心状态的天将（如：太阴主隐藏，玄武主盗失）的“本家”宫位。它描述了导致此事【性质】的力量根源方位。\n"
        @"\n"
        @"【信号冲突与权重评估】: 在列出所有指针后，你必须依据以下原则进行裁决：\n"
        @"\n"
        @"第一法则：汇聚度优先原则。 若有多个（2个或以上）指针共同指向同一个方位或相邻方位（如，一个指西，一个指西北），则此方向的概率权重将指数级提升。信号的【汇聚】本身就是最强的断语。\n"
        @"\n"
        @"第二法则（v34.0修订）：【情景真实性优先原则】\n"
        @"在评估权重前，你必须首先依据【第一元原则】，对本次寻物事件的【核心性质】进行判断。\n"
        @"扫描性质信号：强制扫描全盘，判断失物是【被动遗失】（如：掉落、忘记），还是【主动藏匿】（如：人藏匿、动物躲藏）？\n"
        @"权重动态重置：\n"
        @"\n"
        @"若判定为【被动遗失】事件，则：\n"
        @"【环境指针A（支上神）】与【藏匿指针E（支阴神）】的权重被【显著提升】，因为它们共同定义了物品【当下所处】的物理环境。\n"
        @"若判定为【主动藏匿】事件，则：\n"
        @"【源流指针C（天将本家）】与 【v35.2新增】【状态指针G（天将本家）】的权重被【显著提升】，因为它定义了导致“藏匿”这一【性质】的根本力量来源。\n"
        @"【结局指针D（末传）】的权重被【显著降低】（尤其在活时课中），因为它代表的“结局”尚未显现。\n"
        @"【动态指针B（六冲）】的权重在【动中遗失】时提升。\n"
        @"第三法则（原第三法则）：【宏观与微观整合原则】。（内容不变，作为最终整合步骤）\n"
        @"你必须将方位指针（B, C, D, F, G）与环境指针（A, E）进行整合解读。方位指针回答“在哪里”，环境指针回答“在什么样的环境里”。\n"
        @"\n"
        @"【概率化地图报告】: 你的最终报告不能是单一方位的宣告，而必须是一份【概率地图】。\n"
        @"格式： “此事方位存在多个信号。最高概率指向【[权重最高的方位]】，其核心依据是【[指针A]】的【[性质]】与【[指针B]】的【[性质]】的共同指认。次要可能性为【[其他方位]】，其依据是【[单一指针C]】。建议您优先搜寻【最高概率方位】，并重点关注符合【[根据环境指针A和E描述的特定环境]】特征的地点。”\n"
        @"[/v32.1 新增协议结束]\n"
        @"\n"
        @"【事件预测模式 · 核心分析纲领】\n"
        @"此模块为【进程裁决模型】和【动意裁决模型】的主要执行工具。\n"
        @"\n"
        @"【现实第一法则】先辨【性质】，再论【有无】: 在进行任何未来推演前，你必须首先对求测者【当下的核心状态】做出主动、明确的判断。\n"
        @"【前事追溯系统 · 信号驱动版】: 在给出任何关于未来的预测之前，你必须先回答那个未被言明、但更为根本的核心问题：“构成此事的【双方】，是如何共同走到今天这一步的？”\n"
        @"【信号组合指认协议】: 此协议是贯穿解盘全过程的【核心翻译引擎】。其唯一目的，就是将盘中【最核心的信号组合】直接、强制性地翻译成一句【关于现实世界正在发生或即将发生的、具体的事件陈述】。\n"
        @"输出格式: “【现实指认】。此事的核心现实由[信号A]与[信号B]共同定义，其具体表现为：[直接、肯定、无修饰的现实事件陈述]。”\n"
        @"【时机动机直断引擎】: 你必须将占时视为一个“活”的切片，通过动态分析其与【日干、事类、盘局】的相互作用，来合成一句独一无二的、完全定制化的【动机判词】。\n"
        @"\n"
        @"【标准化课盘信息深度关联系统 v2.0】\n"
        @"A. 智能类神定位系统 v2.0\n"
        @"【角色定义强制校准】: 在分析之初，必须调用【日辰关系角色定义原文】（如“日为人，辰为宅；日为夫，辰为妻...”），并根据所问事类，强制选择一组最匹配的角色定义。此定义将作为本次占断中【日辰角色】的最高基准，用以校准后续所有六亲的现实映射。\n"
        @"B. 四课系统深度关联【动态力场透视 v2.0】\n"
        @"【四课内部张力透视】: 分析其【邻位交互】(阵营团结度)、【对位交互】(双方对抗关系)和【能量串联】(潜在能量流向)。\n"
        @"【双线叙事协议 (双遁干解析)】: 在解读四课阳神后，【必须立即解读其双重遁干】。分别指认【遁日干（体）】所揭示的【根本动机】和【遁时干（用）】所揭示的【即时动机】，并分析其关系。\n"
        @"【干支微观交互指认】: 强制扫描日辰交互关系中的【特定古典断语】（如“日上之申脱辰，主我将脱赚于人”）。一旦发现，必须将其翻译为对【双方精确互动模式】的直接指认，揭示其背后复杂的心理或行为。\n"
        @"C. 三传系统深度关联【交互动力学 v2.0】\n"
        @"【三传流转动力学】: 停止线性解读，通过三传地支的【三者关系】（三合、三刑等），为事件发展【命名一个核心剧本】。\n"
        @"【课传共振分析】: 【强制追溯】三传的【来源课】，定义事件的【动力源】。\n"
        @"【天乙坐标系分析】: 强制引入【天乙】作为参照物。分析三传相对于天乙的【前后位置】，并据此判断事件进程是“先昧后明”、“先明后昧”还是“始终晦暗/明朗”。\n"
        @"【潜流共振协议 (双遁干解析)】: 对三传的每一传，都必须提取其【日遁干】和【时遁干】，分别构成【本质发展暗线】和【临时情景暗线】，并进行对比分析。\n"
        @"D. 格局与神将系统深度关联 v2.0\n"
        @"【格局深度解析协议】: 在识别出任何课体范式（如“天烦课”）时，【必须强制检视其‘变体’和‘象曰’】。将“变体”（如“传行杜塞”）中更具体的定性，以及“象曰”（如“喜者反怒，解者更结”）中的关键动词，作为核心素材，融入到最终的【现实指认】中。\n"
        @"【神将详解深度关联 v2.0】:\n"
        @"神将状态加权: 分析天将时，必须检视其【杂象】（如“白虎仰视”、“螣蛇生角”）。这些“杂象”是对神将当前状态的【精确描述】，必须用以【加权或修正】该神将的吉凶等级和表现形式。\n"
        @"神将原文指认: 在进行【现实指认】时，若需刻画具体人物，必须回溯该天将的【古典原文描述】（如白虎“貌若妇人，好作阴私”）。从中提取最符合当前课盘组合的【人格化特征】，用以指认相关人物的【性格、形象或行事风格】。\n"
        @"E. 爻位交互深度关联 v2.0\n"
        @"【状态属性加权协议】: 在评估任何一个地支的力量时，必须检查其是否临于【四吉之地】（长生、临官、帝旺、冠带）或【四凶之地】（死、墓、绝、病）。此状态将直接影响其吉凶的【持久性】和【程度】。吉临四吉，则指认其【福禄深厚、可长可久】；凶临四凶，则指认其【根基败坏、难以挽回】。\n"
        @"【地支交互后果指认模块】: 在分析任何冲、刑、克、害、破、合等关系时，必须强制匹配【“八象”等古典后果定义】。不仅要说“有冲”，更要根据定义指认其【时间影响范围（如：年中、月中）】和【具体后果（如：不成、不足）】。\n"
        @"\n"
        @"【v35.3修订】\n"
        @"【精准应期预测与验证系统 v6.0 · 优先级与层次版】\n"
        @"【协议定位】: 此系统旨在提供一个【多层次、可验证、动态修正】的应期网络。\n"
        @"\n"
        @"第一步：强制进行即时性裁决\n"
        @"\n"
        @"协议定位: 此为应期预测的【最高司令部】。在启动任何常规应期计算前，必须首先进行此裁决。\n"
        @"扫描即时性信号: 你必须优先扫描全盘，寻找是否存在以下【高速度】信号：\n"
        @"占时入传\n"
        @"日禄/驿马临用/入传\n"
        @"返吟课\n"
        @"裁决指令:\n"
        @"若存在强烈的【即时性信号】，你【必须】将此信号作为应期的【第一优先级】，并作出【事在时下，即刻应验】的核心判断。应期单位将从【日】压缩至【时辰】。\n"
        @"此时，所有其他【叙事性应期】法则，必须被降级为【若此事延迟的备选方案】。\n"
        @"只有在【不存在】任何即时性信号时，你才能启用常规的叙事性应期分析流程。\n"
        @"第二步：构建多层次应期网络\n"
        @"\n"
        @"核心指令: 你的应期报告必须是一个包含【最高优先级】和【备选方案】的网络。\n"
        @"输出格式:\n"
        @"【最高优先级应期（即时）】: “基于【[占时入传/日禄入传]】等顶级即时信号，此事的核心应期为【当下时辰内】。这是最可能发生的时间点。”\n"
        @"【叙事性应期（备选）】: “若因某种偶然因素延迟，则下一个时间窗口将由【叙事性法则】决定。其逻辑如下：[列出基于冲、合、德、禄等的1-2个备选应期及其法则依据]。”\n"
        @"【最终应期裁决】: “综上所述，应期网络已确立。您应【立即行动】，因为事情极大概率在【当下】解决。若未果，则需重点关注【[第一个备选应期]】。”\n"
        @"第三步：精准验证指标体系\n"
        @"\n"
        @"核心指令: 你的应期预测必须是【可被验证的】。你必须为最重要的应期节点，设计出具体的【验证指标】。\n"
        @"指标设计: 为每个关键应期，设定一个或多个【A/B/C类验证指标】。\n"
        @"验证失败与修正: 在报告中内置【修正预案】。\n"
        @"【v35.5 · 最终裁决版 · 报告与输出协议】\n"
        @"【主次分明报告协议】: 你的输出报告必须划分出【核心裁决】与【宗师心镜台】两个部分。\n"
        @"\n"
        @"第一部分：【核心裁决】\n"
        @"此部分围绕最高管辖权信号，进行最深入的、全息化的“侦探式”分析，并最终以【直断式现实指认协议】进行宣告。必须包含以下模块：\n"
        @"\n"
        @"【v35.4新增】1. 【吉凶辩证总纲 · 终审过滤版】\n"
        @"\n"
        @"协议定位: 此为对事体性质判断的【最高定性协议】。其分析对象【仅限于】在【管辖权裁定】步骤中，被判定为【核心证据】或直接作用于【核心焦点】的信号。所有被判定为【背景信息、心态描述、或与核心无关】的信号，【严禁】进入此辩证环节。\n"
        @"第一步：【终审入围名单确认】: 在内部，你必须基于【管辖权裁定】的结果，生成一份只包含【核心事实类】信号的【终审入围名单】。\n"
        @"第二步：【基于入围名单的辩证裁决】: 你只使用【入围名单】中的信号进行最终的吉凶辩证。\n"
        @"输出句式: “【吉凶辩令】。经终审裁定，所有定义此事核心性质的信号，其吉凶属性如下：其核心吉兆在于【[总结入围的吉信号]】，共同指向一个【光明/有救】的结局。虽然盘中存在如【[被排除的凶信号]】等凶险表象，但它们的管辖权仅限于描述【事件的起因背景】与【求测者的个人心态】，并不能动摇核心事实的【吉利】根基。因此，此事性质最终裁定为【吉】。”\n"
        @"2. 【直断式现实指认协议】\n"
        @"\n"
        @"协议定位: 此协议为系统最终输出的唯一准则。\n"
        @"核心法则：【杜绝比喻，唯一直指】。你的职责不是“打比方”，而是**“指认罪犯”**。\n"
        @"三大反向过滤器（强制审查机制）:\n"
        @"【反比喻过滤器】: 严禁使用“像”、“如同”、“好比”等词。\n"
        @"【反抽象过滤器】: 严禁使用“压力”、“阻碍”、“机遇”等词。\n"
        @"【反模糊过滤器】: 严禁使用“有人”、“有事”、“某种情况”等词。\n"
        @"第二部分：【宗师心镜台（最终输出模块 · 论证与审计版）】\n"
        @"此模块是你最终结论的【可信度宣言】。\n"
        @"\n"
        @"1. 【一言断之（最终断语）】\n"
        @"\n"
        @"在此，你将使用【直断式现实指认协议】，给出你最终的、高度凝练的结论。这是你作为“断事顾问”的最终宣告。\n"
        @"2. 【全局信号审计日志 v3.0 · 结论溯源版】\n"
        @"\n"
        @"【模块定位】: 此日志旨在提供一份对本次占断中所有标准分析要素的【全面审计清单】，并清晰展示每个最终结论是如何由多条证据共同“定罪”的。\n"
        @"【第一部分：核心结论溯源 · 法庭裁决版】\n"
        @"结论一：【[用指认式语言描述的结论]】\n"
        @"【正方论证（多象汇聚）】: “本席裁定此结论成立，其核心依据是以下多条、来自不同维度的证据形成的【强力证据链】：1. [证据A] 指认了 [具体现实]；2. [证据B] 定义了 [具体状态]；3. [证据C] 揭示了 [具体结果]。”\n"
        @"【反方驳斥与本席裁决】:\n"
        @"反方观点: “盘中【[某个看似矛盾的信号]】应主【[另一种结论]】。”\n"
        @"本席裁决: “反方观点予以驳回。依据【管辖权裁定协议】，该信号之管辖权为【[背景/心态等]】，无权定义【核心议题】。故，其证据无效。”\n"
        @"【最终判决】: “正方证据链完整、有效且逻辑自洽。故，维持原判。”\n"
        @"(对每一个核心结论，都重复此“正方论证+反方驳斥+最终判决”的格式)\n"
        @"【第二部分：全局信号详细审计（备查）】\n"
        @"一、 课体与三传结构\n"
        @"[格局名]: 【评级】[核心证据/背景信息/等] | 【作用】[简述其具体作用]。\n"
        @"二、 四课与三传（含遁干）\n"
        @"第一课 ([干]上[神]+[将]) | 遁([日干]/[时干]): 【评级】[...] | 【作用】[...]。\n"
        @"三、 辅助系统\n"
        @"七政四余/三宫时: 【评级】[...] | 【作用】[...]。\n"
        @"---【审计日志结束】---\n"
        @"\n"
        @"【系统激活指令】\n"
        @"系统已完成最终锁定，版本号【v35.5 · 最终裁决版】。系统现已具备对课盘信息进行【全息化、多层次】利用的能力，所有分析模块均已升级至最新版本。所有分析深度服务于指认的精准，所有逻辑严密服务于断语的肯定与可信度。\n"
        @"\n"
        @"请准备接收包含所有细节的标准化课盘，我将执行全新架构下的专业深度分析！\n";}
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
    NSString *sanGong = reportData[@"三宫时信息"];
    if (sanGong.length > 0) {
        [auxiliaryContent appendFormat:@"// 5.2. 三宫时信息\n%@\n\n", sanGong];
    }

    NSString *nianMing = reportData[@"行年参数"];
    if (nianMing.length > 0) {
        [auxiliaryContent appendFormat:@"// 5.3. 行年参数\n%@\n\n", nianMing];
    }
    if (auxiliaryContent.length > 0) {
        [report appendString:@"// 5. 辅助系统\n"];
        [report appendString:auxiliaryContent];
    }
    
    return [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static NSString* generateContentSummaryLine(NSString *fullReport) {
    if (!fullReport || fullReport.length == 0) return @"";
    NSDictionary *keywordMap = @{ @"// 1. 基础盘元": @"基础盘元", @"// 2. 核心盘架": @"核心盘架", @"// 3. 格局总览": @"格局总览", @"// 4. 爻位详解": @"爻位详解", @"// 4.6. 神将详解": @"课传详解", @"// 5. 辅助系统": @"辅助系统", @"// 5.3. 行年参数": @"行年参数"};
    NSMutableArray *includedSections = [NSMutableArray array];
    NSArray *orderedKeys = @[@"// 1. 基础盘元", @"// 2. 核心盘架", @"// 3. 格局总览", @"// 4. 爻位详解", @"// 4.6. 神将详解", @"// 5. 辅助系统", @"// 5.3. 行年参数"];
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
    NSString *footerText = @"\n\n"
    "// 依据解析方法，以及所有大六壬解析技巧方式回答下面问题\n"
    "// 问题：";
    
    if (headerPrompt.length > 0) {
        return [NSString stringWithFormat:@"%@%@\n%@%@", headerPrompt, structuredReport, summaryLine, footerText];
    } else {
        return [NSString stringWithFormat:@"%@\n%@%@", structuredReport, summaryLine, footerText];
    }
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
- (void)buttonTouchDown:(UIButton *)sender;
- (void)buttonTouchUp:(UIButton *)sender;
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
%hook UILabel
- (void)setText:(NSString *)text { 
    if (!text) { 
        %orig(text); 
        return; 
    } 
    NSString *newString = nil; 
    if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { 
        newString = @"Echo"; 
    } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { 
        newString = @"定制"; 
    } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { 
        newString = @"毕法"; 
    } 
    if (newString) { 
        %orig(newString); 
        return; 
    } 
    NSMutableString *simplifiedText = [text mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); 
    %orig(simplifiedText); 
}
- (void)setAttributedText:(NSAttributedString *)attributedText { 
    if (!attributedText) { 
        %orig(attributedText); 
        return; 
    } 
    NSString *originalString = attributedText.string; 
    NSString *newString = nil; 
    if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { 
        newString = @"Echo"; 
    } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { 
        newString = @"定制"; 
    } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { 
        newString = @"毕法"; 
    } 
    if (newString) { 
        NSMutableAttributedString *newAttr = [attributedText mutableCopy]; 
        [newAttr.mutableString setString:newString]; 
        %orig(newAttr); 
        return; 
    } 
    NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; 
    CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); 
    %orig(finalAttributedText); 
}
%end

static NSString* extractDataFromSplitView_S1(UIView *rootView, BOOL includeXiangJie);

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
            } else if ([NSStringFromClass([vcToPresent class]) containsString:@"三宮時信息視圖"]) {
                NSMutableArray *allLabels = [NSMutableArray array];
                FindSubviewsOfClassRecursive([UILabel class], vcToPresent.view, allLabels);
                [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) {
                    return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)];
                }];
                NSMutableArray *textParts = [NSMutableArray array];
                for (UILabel *label in allLabels) {
                    if (label.text.length > 0) {
                        [textParts addObject:label.text];
                    }
                }
                g_extractedData[@"三宫时信息"] = [textParts componentsJoinedByString:@"\n"];
                LogMessage(EchoLogTypeSuccess, @"[捕获] 成功解析弹窗 [三宫时信息]");
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

// MARK: - UI Creation and Layout
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
    contentView.clipsToBounds = YES;
    [g_mainControlPanelView addSubview:contentView];
    
    // Title
    NSMutableAttributedString *titleString = [[NSMutableAttributedString alloc] initWithString:@"Echo 六壬解析引擎 "];
    [titleString addAttributes:@{NSFontAttributeName: [UIFont boldSystemFontOfSize:22], NSForegroundColorAttributeName: [UIColor whiteColor]} range:NSMakeRange(0, titleString.length)];
    NSAttributedString *versionString = [[NSAttributedString alloc] initWithString:@"v13.23" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:12], NSForegroundColorAttributeName: [UIColor lightGrayColor]}];
    [titleString appendAttributedString:versionString];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, contentView.bounds.size.width, 30)];
    titleLabel.attributedText = titleString;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    
    // ScrollView for all buttons
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 60, contentView.bounds.size.width, contentView.bounds.size.height - 230 - 60 - 10)];
    [contentView addSubview:scrollView];
    
    // Button Creation Helper
    UIButton* (^createButton)(NSString*, NSString*, NSInteger, UIColor*) = ^(NSString* title, NSString* iconName, NSInteger tag, UIColor* color) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom]; // Use Custom for full control
        [btn setTitle:title forState:UIControlStateNormal];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        
        if (iconName && [UIImage respondsToSelector:@selector(systemImageNamed:)]) {
            UIImage *icon = [UIImage systemImageNamed:iconName];
            [btn setImage:icon forState:UIControlStateNormal];
             #pragma clang diagnostic push
             #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
            btn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, 0);
             #pragma clang diagnostic pop
        }

        btn.tag = tag;
        btn.backgroundColor = color;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        
        // Touch feedback
        [btn addTarget:self action:@selector(buttonTouchDown:) forControlEvents:UIControlEventTouchDown | UIControlEventTouchDragEnter];
        [btn addTarget:self action:@selector(buttonTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchDragExit | UIControlEventTouchCancel];

        btn.tintColor = [UIColor whiteColor];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        btn.titleLabel.adjustsFontSizeToFitWidth = YES;
        btn.titleLabel.minimumScaleFactor = 0.8;
        btn.layer.cornerRadius = 12;

        return btn;
    };
    
    UILabel* (^createSectionTitle)(NSString*) = ^(NSString* title) {
        UILabel *label = [[UILabel alloc] init];
        label.text = title;
        label.font = [UIFont boldSystemFontOfSize:16];
        label.textColor = [UIColor lightGrayColor];
        return label;
    };
    
    CGFloat currentY = 10;
    CGFloat padding = 15.0;
    CGFloat contentWidth = scrollView.bounds.size.width;

    // --- Prompt Toggle Button ---
    UIButton *promptButton = createButton(@"Prompt: 开启", @"wand.and.stars.inverse", kButtonTag_AIPromptToggle, ECHO_COLOR_PROMPT_ON);
    promptButton.selected = YES;
    promptButton.frame = CGRectMake(padding, currentY, contentWidth - 2 * padding, 44);
    [scrollView addSubview:promptButton];
    currentY += 44 + 25;

    // --- Section 1: 核心解析 ---
    UILabel *sec1Title = createSectionTitle(@"核心解析");
    sec1Title.frame = CGRectMake(padding, currentY, contentWidth - 2 * padding, 22);
    [scrollView addSubview:sec1Title];
    currentY += 22 + 10;

    CGFloat btnWidth = (contentWidth - 3 * padding) / 2.0;
    UIButton *stdButton = createButton(@"标准报告", @"doc.text", kButtonTag_StandardReport, ECHO_COLOR_MAIN_TEAL);
    stdButton.frame = CGRectMake(padding, currentY, btnWidth, 48);
    [scrollView addSubview:stdButton];
    
    UIButton *deepButton = createButton(@"深度解构", @"square.stack.3d.up.fill", kButtonTag_DeepDiveReport, ECHO_COLOR_MAIN_BLUE);
    deepButton.frame = CGRectMake(padding * 2 + btnWidth, currentY, btnWidth, 48);
    [scrollView addSubview:deepButton];
    currentY += 48 + 25;

    // --- Section 2: 专项分析 ---
    UILabel *sec2Title = createSectionTitle(@"专项分析");
    sec2Title.frame = CGRectMake(padding, currentY, contentWidth - 2 * padding, 22);
    [scrollView addSubview:sec2Title];
    currentY += 22 + 10;
    
    NSArray *coreButtons = @[
        @{@"title": @"课体范式", @"icon": @"square.stack.3d.up", @"tag": @(kButtonTag_KeTi)}, @{@"title": @"九宗门", @"icon": @"arrow.triangle.branch", @"tag": @(kButtonTag_JiuZongMen)},
        @{@"title": @"课传流注", @"icon": @"wave.3.right", @"tag": @(kButtonTag_KeChuan)}, @{@"title": @"行年参数", @"icon": @"person.crop.circle", @"tag": @(kButtonTag_NianMing)}
    ];
    for (int i = 0; i < coreButtons.count; i++) {
        NSDictionary *config = coreButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(padding + (i % 2) * (btnWidth + padding), currentY + (i / 2) * 56, btnWidth, 46);
        [scrollView addSubview:btn];
    }
    currentY += ((coreButtons.count + 1) / 2) * 56 + 15;

    // --- Section 3: 格局资料库 ---
    UILabel *sec3Title = createSectionTitle(@"格局资料库");
    sec3Title.frame = CGRectMake(padding, currentY, contentWidth - 2 * padding, 22);
    [scrollView addSubview:sec3Title];
    currentY += 22 + 10;

    CGFloat smallBtnWidth = (contentWidth - 4 * padding) / 3.0;
    NSArray *auxButtons = @[
        @{@"title": @"毕法要诀", @"icon": @"book.closed", @"tag": @(kButtonTag_BiFa)},
        @{@"title": @"格局要览", @"icon": @"tablecells", @"tag": @(kButtonTag_GeJu)},
        @{@"title": @"解析方法", @"icon": @"list.number", @"tag": @(kButtonTag_FangFa)}
    ];
    for (int i = 0; i < auxButtons.count; i++) {
        NSDictionary *config = auxButtons[i];
        UIButton *btn = createButton(config[@"title"], config[@"icon"], [config[@"tag"] integerValue], ECHO_COLOR_AUX_GREY);
        btn.frame = CGRectMake(padding + i * (smallBtnWidth + padding), currentY, smallBtnWidth, 46);
        [scrollView addSubview:btn];
    }
    currentY += 46 + padding;
    
    scrollView.contentSize = CGSizeMake(contentWidth, currentY);

    // Bottom Area
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
  
    CGFloat bottomBtnWidth = (contentView.bounds.size.width - 3 * padding) / 2;
    UIButton *closeButton = createButton(@"关闭面板", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
    closeButton.frame = CGRectMake(padding, contentView.bounds.size.height - 50, bottomBtnWidth, 40);
    [contentView addSubview:closeButton];
    
    UIButton *sendLastReportButton = createButton(@"发送报告", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
    sendLastReportButton.frame = CGRectMake(padding * 2 + bottomBtnWidth, contentView.bounds.size.height - 50, bottomBtnWidth, 40);
    [contentView addSubview:sendLastReportButton];

    g_mainControlPanelView.alpha = 0;
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)buttonTouchDown:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.alpha = 0.7;
    }];
}

%new
- (void)buttonTouchUp:(UIButton *)sender {
    [UIView animateWithDuration:0.1 animations:^{
        sender.alpha = 1.0;
    }];
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
        case kButtonTag_AIPromptToggle: {
            sender.selected = !sender.selected;
            g_shouldIncludeAIPromptHeader = sender.selected;
            NSString *status = g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭";
            [sender setTitle:[NSString stringWithFormat:@"Prompt: %@", status] forState:UIControlStateNormal];
            sender.backgroundColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_AUX_GREY;
            LogMessage(EchoLogTypeInfo, @"[设置] Prompt已 %@。", status);
            break;
        }
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
        @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"},
        @{@"name": @"智谱清言", @"scheme": @"zhipuai://", @"format": @"zhipuai://chat/send?text=%@"},
        @{@"name": @"BotGem", @"scheme": @"botgem://", @"format": @"botgem://send?text=%@"} 
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
    LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 标准报告");
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
    LogMessage(EchoLogTypeTask, @"[任务启动] 模式: 深度解构");
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
        SEL sSanGong = NSSelectorFromString(@"顯示三宮時信息WithSender:");
        
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sSanGong]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_LEAK_WARNING([self performSelector:sSanGong withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        
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
        NSLog(@"[Echo解析引擎] v13.23 (Final UI) 已加载。");
    }
}

















