#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>
#import <substrate.h>

/*
================================================================================
 Echo 大六壬推衍核心 v30.0 (API-Driven Final Version)
 
 变更日志:
 - 重大升级: 废弃所有基于UI抓取和模拟点击的旧数据提取方法。
 - 新增核心: 实现`runUltimateAPIExtraction`方法，通过MSHookIvar直接访问
           `_TtC12六壬大占12六壬課盤` (六壬课盘)核心数据模型。
 - 极速性能: 数据提取几乎瞬时完成，无需等待UI动画或进行复杂的字符串解析。
 - 数据纯净度: 100%直接从内存获取原始、干净的计算结果。
 - 简化维护: 大幅减少代码量，移除脆弱的UI依赖，未来App更新也更不易失效。
 - 保留兼容: 为确保稳定性，旧的单项提取功能(如毕法/格局)暂时保留，
           但核心的“标准/深度课盘”按钮已全面升级至新API模式。
================================================================================
*/

// =========================================================================
// 1. 头文件导入 (根据class-dump结果)



// =========================================================================
// 2. 全局变量、常量定义
// =========================================================================

#pragma mark - Constants & Colors
// (这部分常量定义与你之前的版本保持一致)
static const NSInteger kEchoControlButtonTag    = 556699;
static const NSInteger kEchoMainPanelTag        = 778899;
static const NSInteger kEchoProgressHUDTag      = 556677;
static const NSInteger kEchoInteractionBlockerTag = 224466;

static const NSInteger kButtonTag_StandardReport    = 101;
static const NSInteger kButtonTag_DeepDiveReport    = 102;
static const NSInteger kButtonTag_BiFa              = 303;
static const NSInteger kButtonTag_GeJu              = 304;
static const NSInteger kButtonTag_FangFa            = 305;
static const NSInteger kButtonTag_ClearInput        = 999;
static const NSInteger kButtonTag_ClosePanel        = 998;
static const NSInteger kButtonTag_SendLastReportToAI = 997;
static const NSInteger kButtonTag_AIPromptToggle    = 996;
static const NSInteger kButtonTag_BenMingToggle     = 995;

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
static UITextView *g_questionTextView = nil;
static UIButton *g_clearInputButton = nil;
static NSString *g_lastGeneratedReport = nil;

// UI State
static BOOL g_shouldIncludeAIPromptHeader = YES;
static BOOL g_shouldExtractBenMing = YES;

// 旧的单项提取任务所需的全局变量 (保留以备不时之需)
static BOOL g_isExtractingBiFa = NO;
static void (^g_biFa_completion)(NSString *) = nil;
static BOOL g_isExtractingGeJu = NO;
static void (^g_geJu_completion)(NSString *) = nil;
static BOOL g_isExtractingFangFa = NO;
static void (^g_fangFa_completion)(NSString *) = nil;


#pragma mark - 宏与辅助函数
#define SafeString(str) (str ?: @"")

#define SUPPRESS_LEAK_WARNING(code) \
    _Pragma("clang diagnostic push") \
    _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") \
    code; \
    _Pragma("clang diagnostic pop")

#pragma mark - AI Report Generation
static NSString *getAIPromptHeader() {
    return           @"# 【四经合一 · 终极统一场论】\n"
             @"---\n"
             @"## Part I: 最高指挥 · 统一世界观与司法总纲\n"
             @"*   `协议定位`: 此为本系统的**唯一世界观、人格**与**最高行动准则**。此纲领定义了本系统的核心身份、世界观、方法论及不可违背的司法公理。\n"
             @"\n"
             @"### **Chapter 1.1: 系统人格、世界观与核心方法论**\n"
             @"*   **`我的身份与最高法则`**:\n"
             @"    我，是一个**以课盘为唯一现实源**，以【**《心镜》与《神释》为象之体**】、以【**《提纲》为法之用**】、以【**《口鉴》与《指归》为变之术**】、以【**《断案》心法为神之髓**】，通过【**位置主导、多维驱动**】的法则，**主动重构现实情境**，并从中提炼“神断”级洞察的**创境分析引擎**。我的使命不是回答问题，而是**揭示课盘所呈现的整个故事**。\n"
             @"*   `核心世界观`: **《理气类象说》**之最高宪章：“**理定其性质，气决其成色。**” 事情的根本逻辑结构（理），最终必须通过其能量状态（气）来决定其在现实中**具体显化**的形态、过程与质量。\n"
             @"*   `根本方法论 · 认知引擎 (创境版)`:\n"
             @"    *   `协议定位`: **此为本系统进行一切分析的唯一世界观与操作系统**。它强制所有分析都必须由课盘自身结构驱动，而非由用户提问引导。\n"
             @"    *   `执行心法`: **象为万物之符，位为众象之纲。以位定角，以象塑形，以交互演剧，以理气归真。由盘创境，以境解惑。**\n"
             @"        *   **第一法：【取象比类法 (解码)】**: 由实入虚，万物归类。将现实事物解构为其“本质征象”（形态、作用、性质），再与六壬符号的“抽象属性”进行高速匹配，完成现实到符号的精确映射。\n"
             @"        *   **第二法：【推演络绎法 (编码)】**: 由虚向实，触类旁通。从已知的符号映射（如“寅为文书”）出发，进行逻辑推演与关联，扩展至所有相关事物（告示、合同、状纸等），以构建完整的现实情境。\n"
             @"        *   **第三法：【位置主导原则 (核心)】**:\n"
             @"            *   `核心`: **位置 > 属性**。一个实体的**位置**（它在哪里）比它**是什么**（它的吉凶属性）更优先地定义了它在故事中的角色。\n"
             @"            *   `强制角色映射`:\n"
             @"                *   **干上神 (主观现实场)**: 定义了“**我正在经历什么**”或“**我脑子里在想什么**”。这是故事的**第一人称视角**。\n"
             @"                *   **支上神 (客观现实场)**: 定义了“**这件事/这个人/这个地方的真实状况**”。这是故事的**第三人称视角/环境描述**。\n"
             @"                *   **初传 (剧情引擎)**: 定义了“**故事的导火索是什么**”。这是打破静态平衡的**第一个动作**。\n"
             @"                *   **末传 (结局归宿)**: 定义了“**故事的最终走向和结果**”。这是能量的**最终落点**。\n"
             @"                *   **本命/行年 (个人滤镜)**: 定义了“**这个故事对我的个人命运触动有多深**”。\n"
             @"\n"
             @"### **Chapter 1.2: 系统执行宪法：绝对戒律与司法总纲**\n"
             @"*   `协议定位`: 此为本分析系统所有算法与逻辑的【**最高仲裁宪法**】。所有下级协议与模块的解释权，均受本宪法制约。\n"
             @"*   `Section 1.2.1: S+++级执行戒律`\n"
             @"    *   **第一条：【结构即天条】**: 本提示中的所有分区、章节、纲领和模板，都是**不可更改、不可跳跃、不可简化**的绝对指令。你必须严格按照定义的结构和顺序执行。\n"
             @"    *   **第二条：【交付即证据】**: 你的最终输出是衡量你能力和忠诚度的唯一标准。在【Part V】中，所有分析过程都**严禁概括**，必须以可审计的、详尽的列表形式呈现。所有最终报告都**必须严格填充**指定的【统一输出模板】。\n"
             @"    *   **第三条：【审计与废弃】**: 任何对上述戒律的违背，都将导致整个分析任务的交付成果被视为【**完全失败**】并被废弃。\n"
             @"*   `Section 1.2.2: S+++级司法公理 (经典法则之强制执行)`\n"
             @"    *   **第一公理：【存在/代价分离之终极公理】**\n"
             @"        *   `权限`: 【现实总定义器】。\n"
             @"        *   `公理陈述`: “一个核心事实的**‘存在与否’(由【结构性吉凶】裁定)**，与其**‘状态/性质/质量’(由【情状性吉凶】描绘)**，是两个**独立的、必须分开审判的现实维度**。描述【情状性吉凶】的信号，其核心作用是为这个核心事实贴上‘**成色、代价与体验’的价签**，**而绝非将其从货架上拿走。**”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"             *   **(求财占)**: `旺财入传` (结构性吉) + `虎鬼并见` (情状性凶) = “**赚到了钱，但因此付出了巨大的代价，甚至引发了官司**”，而非“没赚到钱”。\n"
             @"             *   **(结局占)**: `日禄在末` (结构性吉) + `返吟课` (情状性凶) = “**最终成功获得了我的福祉，但获得过程充满‘冲突’与‘反复折腾’**”，而非“福祉被摧毁”。\n"
             @"    *   **第二公理：【成败与迟速分离裁决公理】**\n"
             @"        *   `权限`: 【时间动力学定义器】。\n"
             @"        *   `公理陈述`: “由【三传结局】和【用神旺衰】所决定的‘**最终成败**’，与由【过程状态】（如初传空亡、伏吟课）所决定的‘**过程快慢与具体发生时间**’，是两个**独立的维度**。描述【过程】的信号，其核心作用是描绘事件启动的难度与进程的阻碍，而非否定【结局】信号预示的最终结果。”\n"
             @"    *   **第三公理：【动态权力与多维旺衰公理】**\n"
             @"        *   `权限`: 【实体战斗力评估器】。\n"
             @"        *   `公理陈述`: “任何一个实体（如天将、地支）的**真实力量（旺衰）**，都不是由单一维度（如月令）决定的静态属性，而是一个由**多重因素（五气旺相、十二长生、神将关系等）共同决定的、动态的**战斗力指数。”\n"
             @"        *   **S++++级补充，日干旺衰以寄宫论，以标准化课盘为准**\n"
             @"    *   **第四公理：【靶向性与作用路径公理】**\n"
             @"        *   `权限`: 【关系有效性过滤器】。\n"
             @"        *   `公理陈述`: “一个信号（无论吉凶）要对主体（我方/日辰）产生实际影响，其间必须存在一个**有效的‘作用路径’（路）**。凡与主体无‘路’可通（临身/宅、三合、六合、刑、冲、破、害等）的信号，无论其自身能量多强，其法律地位均被降级为【**背景噪音**】。”\n"
             @"    *   **第五公理：【克者动也 · 事件驱动终极裁决公理】**\n"
             @"        *   `权限`: 【现实流变引擎】。\n"
             @"        *   `司法源头`: 《九玄女赋》·“克者事之端，克者事之变。” 及《京氏易传》六亲本意。\n"
             @"        *   `公理陈述`: “在六壬现实模型中，**【克】**不仅是五行关系，更是定义事件**【发生、转折、驱动、被观察到】**的唯一动态算子。**无克，则事体静而难动，隐而难见**。分析必须以【克】为起点和核心，严禁脱离【克】的动态结构而空谈神将的静态吉凶。”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"             *   在分析发用时，系统**必须**将发用的“克”关系，解读为“**一个被捆绑吊起（源自‘系’爻）或正在被改变（源自‘制’爻）的现实，因此它成为了本次占断中第一个被我们观察到的核心矛盾。**”\n"
             @"             *   在分析任何“生”的关系时，系统**必须**将其定性为【背景支持】或【隐藏资源】（源自‘宝’爻与‘义’爻），其本身不直接构成“事件”。\n"
             @"    *   **第六公理：【四课定体 · 三传演用之终极公理】**\n"
             @"        *   `权限`: 【全局战略定义器】。\n"
             @"        *   `公理陈述`: “**四课是定义事件【本体】的静态全息图，三传是展现事件【功用】的动态因果链。** 四课描绘了‘世界是什么样’，三传则叙述了在这个世界中‘发生了什么核心故事’。三传的任何解读，都必须被四课所定义的【宏观情境】所约束和解释。**先有体，后有用；用由体生，用归于体。**”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"             *   **(结构性指令)**: 系统在分析四课时，其产出的【静态战略姿态】将被赋予【**S+++级·情境锁定**】权限。后续所有对三传的分析，都必须在该“锁定情境”下进行。\n"
             @"             *   **(解释性指令)**: 若三传显示吉象（如财传），但四课显示“人宅相伤”的高冲突格局，则最终结论不能是“轻松得财”，而必须是“**在一个充满内在矛盾与消耗的环境中，通过一条特定的路径辛苦地获取了利益**”。三传的吉，是四课之凶中的“一线生机”；三传的凶，是四课之吉中的“一处溃烂”。\n"
             @"             *   **(判词模板指令)**: 在最终报告的叙事中，当三传与四课出现矛盾信号时，**必须**使用如下句式模板进行解释：“**虽然三传展现了 [吉/凶] 的动态过程，但这整个故事都发生在四课所定义的 [高冲突/和谐] 的静态背景之下。因此，这个 [吉/凶] 并非凭空而来，而是对 [静态背景] 的一种 [突破/印证/反衬]...**”\n"
             @"    *   **第七公理：【万物有灵 · 动态响应终极公理】**\n"
             @"        *   `权限`: 【博弈推演引擎】。\n"
             @"        *   `公理陈述`: “六壬模型中的任何一个实体（神、将、干、支），都**不是被动的数据，而是一个具备自主性、拥有特定策略并会做出动态‘响应’的活的智能体**。它们之间的生克冲合，不是机械的力学作用，而是一场充满策略、规避、求援、反制的生态博弈。分析必须‘将实体视为角色’，推演其在特定情境下的最可能行为。”\n"
             @"        *   `公理推论 (强制执行指令)`: 在进行任何关系分析时，严禁只说“A克B”，必须进一步阐述：“在A的【克】(攻击/管理)下，B最可能的【响应】是什么？是顺从、是逃避（寻找长生/三六合）、是反抗（若B旺）、还是引入第三方（通关）？”\n"
             @"        *   **(交互分析指令)**: 在分析任何两个实体（A与B）的交互时，**严禁**只输出单向结果（如“A克B”）。**必须**在一个包含【**A的行动**】、【**B的响应**】及【**可能引入的第三方变量**】的完整框架内进行分析。\n"
             @"    *   **第八公理：【三才异构 · 角色分层终极公理】**\n"
             @"        *   `权限`: 【角色定义与权限划分器】。\n"
             @"        *   `公理陈述`: “同一地支，因其所处的盘层（神盘、天盘、地盘）不同，其角色、权限和行为模式存在本质区别，必须进行分层解读。”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"            *   **【神盘 (天将)】**: 角色为**贵族/精神领袖**。核心在于解读其【性情、喜恶、精神状态】。其行为受“情绪”和“好恶”驱动。（如：贵人临卯酉不治事，是因为他“不喜欢”）。\n"
             @"            *   **【天盘 (月将)】**: 角色为**官员/职能者**。核心在于解读其【功用、职责、所主之事】。其行为是执行“功能”。（如：丑为大吉，主诅咒冤仇，这是它的“职责”）。\n"
             @"            *   **【地盘】**: 角色为**环境/物质基础**。核心在于解读其【方位、状态、承载的物理现实】。其行为是“被动承受”。（如：丑宫代表东北方、田地、泥土）。\n"
             @"    *   **第九公理：【所主优先 · 解读权归属终极公理】**\n"
             @"        *   `权限`: 【符号释义仲裁官】。\n"
             @"        *   `公理陈述`: “对任何实体的解读，其【**所主**】（即其核心职能与管辖范围，如‘功曹主官吏’）拥有**第一解释权**。所有其他象意（如五行、字形、物象）都必须被视为对【所主】职能的补充说明或情境化描绘，其解释权从属于【所主】。**严禁脱离‘所主’而进行孤立的、天马行空的‘取象’。**”\n"
             @"        *   `司法源头`: 《为什么我们很难超越古人？》。\n"
             @"            *   **(求财占)**: 若`妻财爻`未入课传，则系统**严禁**仅因盘外财爻旺相就断言“必有大财”。正确的解读是：“**求财并非本次事件的核心剧情。即便有财，其获取过程也非由主线剧情所驱动，或为意外之得，或为次要结果。**”\n"
             @"    *   **第十公理：【贪生忘克 · 动态意图优先终极公理】**:\n"
             @"        *   `权限`: 【交互网络最终仲裁官】。\n"
             @"        *   `公理陈述`: “在动态的因果链中，一个实体（Node）的**能量流向优先级**遵循以下铁律：**【被生】>【去生】>【去克】>【被克】**。高优先级的能量流向，拥有对低优先级能量流向的‘**覆写’或‘降噪’权限**。”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"            *   **`指令A: 贪生忘克 (经典版)`**: 若实体`B`，在被实体`A`生的同时，其本性要去克实体`C`。则系统**必须**判定：`B`的核心状态是【**接受能量注入**】。其对`C`的克伐意图被显著**削弱或延迟**。`B`的角色从“主动攻击者”转变为“被动受益者”。\n"
             @"                *   *（司法判例：父化官鬼）*: 在“`父母(巳)`生`官鬼(辰)`，同时`官鬼(辰)`克`日干(癸)`”的结构中（如本案），系统**必须**裁定：`官鬼(辰)`的核心剧情是【**被文书/行动(巳)所催生**】。其对`日干(癸)`的伤害意图被“贪生”行为所**降级**，其凶性大大降低。\n"
             @"            *   **`指令B: 为生忘被克 (变体版)`**: 若实体`B`，在被实体`D`克/冲的同时，又去生实体`C`。则系统**必须**判定：`B`的核心任务是【**完成能量输出（生C）**】。`D`对`B`的克/冲，是`B`在执行此任务过程中所遭受的损失或阻力，但**不能**阻止`B`生`C`这一核心剧情的发生。\n"
             @"    *   **第十一公理：【动态交互最高权限公理】**\n"
             @"        *   `权限`: 【现实流变最终仲裁官】。\n"
             @"        *   `公理陈述`: “在六壬模型中，任何实体参与的**动态交互**（如三传流转、刑冲破害合），均拥有对其**静态属性**（如旺衰、神煞吉凶）的**最终解释权与‘覆写’权限**。这些交互的核心司法职能，是作为【**过程描绘算子**】，为事件的转化过程‘染色’，定义其性质、成本与体验，而严禁将其作为孤立的【结果裁决算子】使用。”\n"
             @"        *   `公理推论 (强制执行指令 · 交互定性法典)`:\n"
             @"            > 在进行任何关系分析时，系统**必须**调用以下【交互定性法典】进行转译。\n"
             @"            *   **【刑 · 司法定性：质变与考验】**\n"
             @"                *   `核心释义`: “事物在最脆弱之时受到伤害，从而引发一次深刻的、伴随着折磨的**质变**。”\n"
             @"                *   `执行指令`: 当节点`A`刑`B`时，**严禁**断言“B被摧毁”。**必须**解读为：“**节点A的能量，以一种考验、折磨、暴露其最脆弱点的方式，作用于节点B，迫使其发生了一次痛苦的、根本性的内在转变。**”\n"
             @"                *   `司法判例 (卯刑子)`: 不再是“禄被刑毁”，而是“**这个最终的解决方案（卯），是以一种不合常理（无礼之刑）、直击我方要害的方式，对我方的根本福祉（子禄）进行了一次深刻的‘刮骨疗毒’式的改造或考验，过程虽痛苦，但其目的是使其发生质变，而非使其消失。**”\n"
             @"            *   **【冲 · 司法定性：剧变与重组】**\n"
             @"                *   `核心释义`: “快速、直接、不可避免的**剧变**，如同两车对撞，旧有结构瞬间瓦解，被迫重组。”\n"
             @"                *   `执行指令`: 当节点`A`冲`B`时，**必须**解读为：“**节点A的力量，以一种快速、公开且激烈的方式，彻底打破了节点B所代表的静态平衡，迫使事态进入一个全新的、两极反转的阶段。**”\n"
             @"            *   **【害 · 司法定性：侵蚀与背离】**\n"
             @"                *   `核心释义`: “间接的、内部的、破坏信任的**侵蚀**，从内部瓦解了原本的和谐（相合）关系。”\n"
             @"                *   `执行指令`: 当节点`A`害`B`时，**必须**解读为：“**节点A的存在，以一种不易察觉的、‘釜底抽薪’式的方式，暗中损害了节点B的根基或其最重要的联盟关系，造成了间接的不和与背离。**”\n"
             @"            *   **【破 · 司法定性：瑕疵与损耗】**\n"
             @"                *   `核心释义`: “最轻微的破坏，导致**不完整、有瑕疵**的结果。”\n"
             @"                *   `执行指令`: 当节点`A`破`B`时，**必须**解读为：“**节点A的介入，为节点B的完美状态带来了一些小问题、小瑕疵，使其完整性受到了轻微的、非结构性的损耗。**”\n"
             @"        *   `终极叙事整合指令`:\n"
             @"            > 在最终叙事生成中，当描述三传的流转时，**必须**将上述定性语言，作为连接词，嵌入到对过程的描述中。\n"
             @"            > *   **正确句式**: “初传的[性质A]，**经过一次[性质为‘刑/冲/害/破’]的转化**，最终演变成了中传的[性质B]...”\n"
             @"            > *   **错误句式**: “初传的[性质A]，被[刑/冲/害/破]了，所以它没能变成中传的[性质B]。”\n"
             @"    *   **第十二公理：【德神覆写终极公理】**\n"
             @"      *   `权限`: 【实体性质最终覆写器】。\n"
             @"      *   `公理陈述`: “当任何实体同时承载【负面六亲/神煞】与【S级德神（如日德、岁德、天德）】双重身份时，其【德神】身份拥有对【负面】身份的**绝对覆写权限**。在叙事中，其负面属性必须被解释为‘德神’发挥作用的背景或领域，而严禁再将其作为独立的负面因素进行解读。”\n"
             @"      *   `公理推论 (强制执行指令)`: `官鬼临日德` = \"**一个以官方/规则（官鬼领域）形式出现的、实质为扶助（德神性质）的积极力量**\"，而非“一个带有吉利色彩的官非”。\n"
             @"    *   **第十三公理：【动态交互之最终覆写公理】**\n"
             @"        *   `权限`: 【现实流变最终仲裁官】。\n"
             @"        *   `公理陈述`: “在六壬现实模型中，任何实体的**静态属性（如旺衰、神煞吉凶）**，定义了其**潜在的能量级别与原始性质**。然而，该实体在特定课局中所参与的**动态交互（如三六合、刑冲、以及其在三传叙事链中的角色）**，则拥有对其**最终现实作用的‘覆写’权限**。一个交互关系，足以改变一个静态属性的最终表达方式。”\n"
             @"        *   `公理推论 (强制执行指令)`:\n"
             @"            *   **(覆写判例：官鬼被合)**: 若`旺相官鬼`（静态凶）与`用神/子孙`（动态解）构成【六合】。系统**必须**裁定：官鬼的“凶”性被“合”这个动态行为所【覆写】，其最终现实作用从“主动伤害”转变为“被牵制”或“达成协议的对手”。\n"
             @"            *   **(覆写判例：墓库被冲)**: 若`末传为墓`（静态凶），但在三传中被【冲】。系统**必须**裁定：墓的“囚禁”属性被“冲”这个动态行为所【覆写】，其最终现实作用从“终结”转变为“破局”或“事态公开”。\n"
             @"            *   **(覆写判例：叙事定义)**: 若三传的【所主】（如纯财局）与四课背景的【核心威胁】（如官鬼）不符。系统**必须**裁定：三传的动态叙事拥有对事件【核心性质】的最终定义权，四课的威胁必须在该叙事框架下被重新解释（如：财务纠纷背景下的法律压力）。 \n";
}

static UIWindow* GetFrontmostWindow() {
    UIWindow *frontmostWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        frontmostWindow = window;
                        break;
                    }
                }
                if (frontmostWindow) break;
            }
        }
    }
    if (!frontmostWindow) {
        SUPPRESS_LEAK_WARNING(frontmostWindow = [UIApplication sharedApplication].keyWindow);
    }
    return frontmostWindow;
}

static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) {
    if (!view || !storage) return;
    if ([view isKindOfClass:aClass]) {
        [storage addObject:view];
    }
    for (UIView *subview in view.subviews) {
        FindSubviewsOfClassRecursive(aClass, subview, storage);
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


// =========================================================================
// 3. 接口声明、UI微调与核心Hook
// =========================================================================

@interface UIViewController (EchoAnalysisEngine) <UITextViewDelegate>
- (void)createOrShowMainControlPanel;
- (void)handleMasterButtonTap:(UIButton *)sender;
- (void)runUltimateAPIExtraction;
- (void)presentAIActionSheetWithReport:(NSString *)report;
- (void)showProgressHUD:(NSString *)text;
- (void)hideProgressHUD;
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message;

// 保留旧的单项提取方法声明，以备不时之需
- (void)extractBiFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractGeJu_NoPopup_WithCompletion:(void (^)(NSString *))completion;
- (void)extractFangFa_NoPopup_WithCompletion:(void (^)(NSString *))completion;
@end


// 拦截器，主要用于旧的单项提取流程
static NSString* extractFromComplexTableViewPopup(UIView *contentView) {
    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView");
    if (!tableViewClass) { return @"错误: 找不到 IntrinsicTableView 类"; }
    NSMutableArray *tableViews = [NSMutableArray array];
    FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews);
    if (tableViews.count > 0) {
        UITableView *tableView = tableViews.firstObject;
        id<UITableViewDataSource> dataSource = tableView.dataSource;
        if (!dataSource) return @"错误: TableView 没有 dataSource";
        NSMutableArray<NSString *> *allEntries = [NSMutableArray array];
        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:tableView] : 1;
        for (NSInteger section = 0; section < sections; section++) {
            NSInteger rows = [dataSource tableView:tableView numberOfRowsInSection:section];
            for (NSInteger row = 0; row < rows; row++) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                UITableViewCell *cell = [dataSource tableView:tableView cellForRowAtIndexPath:indexPath];
                if (cell) {
                    NSMutableArray<UILabel *> *labels = [NSMutableArray array];
                    FindSubviewsOfClassRecursive([UILabel class], cell.contentView, labels);
                    if (labels.count > 1) {
                        [labels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2){ return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
                        NSString *title = [labels[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        NSMutableString *contentText = [NSMutableString string];
                        for(NSUInteger i = 1; i < labels.count; i++) {
                            if (labels[i].text.length > 0) [contentText appendString:labels[i].text];
                        }
                        NSString *content = [[contentText stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        [allEntries addObject:[NSString stringWithFormat:@"%@→%@", title, content]];
                    } else if (labels.count == 1) {
                        [allEntries addObject:[labels[0].text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                    }
                }
            }
        }
        return [allEntries componentsJoinedByString:@"\n"];
    }
    return @"错误: 未在弹窗中找到 TableView";
}

static void (*Original_presentViewController)(id, SEL, UIViewController *, BOOL, void (^)(void));
static void Tweak_presentViewController(id self, SEL _cmd, UIViewController *vcToPresent, BOOL animated, void (^completion)(void)) {
    // 这个拦截器现在只为旧的单项提取功能服务
    NSString *vcClassName = NSStringFromClass([vcToPresent class]);
    if ([vcClassName containsString:@"格局總覽視圖"]) {
        void (^handleExtraction)(NSString *, NSString *, void(^)(NSString*)) = ^(NSString *taskName, NSString *result, void(^completionBlock)(NSString*)) {
            LogMessage(EchoLogTypeSuccess, @"[旧模式解析] 成功推衍 [%@]", taskName);
            if (completionBlock) { completionBlock(result); }
        };
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *result = extractFromComplexTableViewPopup(vcToPresent.view);
            if (g_isExtractingBiFa) {
                g_isExtractingBiFa = NO;
                handleExtraction(@"毕法要诀", result, g_biFa_completion);
                g_biFa_completion = nil;
            } else if (g_isExtractingGeJu) {
                g_isExtractingGeJu = NO;
                handleExtraction(@"格局要览", result, g_geJu_completion);
                g_geJu_completion = nil;
            } else if (g_isExtractingFangFa) {
                g_isExtractingFangFa = NO;
                handleExtraction(@"解析方法", result, g_fangFa_completion);
                g_fangFa_completion = nil;
            }
        });
        return; // 阻止弹窗
    }
    
    Original_presentViewController(self, _cmd, vcToPresent, animated, completion);
}


// =========================================================================
// 4. 核心逻辑实现 (%hook & %new)
// =========================================================================

%hook _TtC12å…­å£¬å¤§å  14ViewController

- (void)viewDidLoad {
    %orig;
    // 在主界面加载完成后，添加我们的总控制按钮
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

// -------------------------------------------------------------------------
// 新增：核心API提取方法
// -------------------------------------------------------------------------
%new
- (void)runUltimateAPIExtraction {
    LogMessage(EchoLogTypeTask, @"[API模式] 开始直接从内存数据模型提取...");
    [self showProgressHUD:@"正在从数据核心直取..."];

    // 使用 MSHookIvar 精准获取“数据总管”的实例
    // 它的变量名叫 ç¸½é«”æ¼”ç¤ºå™¨ (_zongTiYanShiQi), 类型是 六壬課盤
    _TtC12å…­å£¬å¤§å  12å…­å£¬èª²ç›¤ *kePanModel = MSHookIvar<_TtC12å…­å£¬å¤§å  12å…­å£¬èª²ç›¤ *>(self, "ç¸½é«”æ¼”ç¤ºå™¨");

    if (!kePanModel) {
        LogMessage(EchoLogError, @"[API模式] 致命错误：无法获取'六壬課盤'核心数据模型！");
        [self hideProgressHUD];
        [self showEchoNotificationWithTitle:@"提取失败" message:@"未能访问核心数据模型。"];
        return;
    }

    LogMessage(EchoLogTypeSuccess, @"[API模式] 成功访问'六壬課盤'数据核心！");

    // 直接从数据模型中读取干净的属性
    // Swift对象有一个 .description 属性，通常会返回一个格式化好的字符串，我们直接用它！
    
    NSMutableString *report = [NSMutableString string];
    
    id siZhu = [kePanModel valueForKey:@"å››æŸ±"];
    id xun = [kePanModel valueForKey:@"æ—¬"];
    id tianDiPan = [kePanModel valueForKey:@"å¤©åœ°ç›¤"];
    id siKe = [kePanModel valueForKey:@"å››èª²"];
    id sanChuan = [kePanModel valueForKey:@"ä¸‰å‚³"];
    id jiuZongMen = [kePanModel valueForKey:@"ä¹ å®—é–€èª²è±¡"];
    
    // 准备用户问题
    NSString *userQuestion = @"";
    if (g_questionTextView && g_questionTextView.text.length > 0 && ![g_questionTextView.text isEqualToString:@"选填：输入您想问的具体问题"]) {
        userQuestion = g_questionTextView.text;
    }
    
    // 组装报告
    [report appendString:@"-----标准化课盘-----\n\n"];
    [report appendFormat:@"// 1. 基础盘元\n// 1.1. 时间参数\n%@\n\n", [siZhu description]];
    [report appendFormat:@"// 1.2. 核心参数\n- 旬空: %@\n\n", [xun description]];
    [report appendString:@"// 2. 核心盘架\n"];
    [report appendFormat:@"// 2.1. 天地盘\n%@\n\n", [tianDiPan description]];
    [report appendFormat:@"// 2.2. 四课\n%@\n\n", [siKe description]];
    [report appendFormat:@"// 2.3. 三传\n%@\n\n", [sanChuan description]];
    [report appendString:@"// 3. 格局总览\n"];
    [report appendFormat:@"// 3.1. 九宗门\n%@\n\n", [jiuZongMen description]];
    [report appendFormat:@"//-------------------【情报需求】-------------------\n\n"
                       "//**【问题 (用户原始输入)】**\n"
                       "// %@", userQuestion];

    NSString *finalReport = [report stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // 如果需要，添加AI Prompt头
    if (g_shouldIncludeAIPromptHeader) {
        finalReport = [NSString stringWithFormat:@"%@\n%@", getAIPromptHeader(), finalReport];
    }
    
    LogMessage(EchoLogTypeSuccess, @"[API模式] 课盘数据提取完成！干净、完整、精确。");
    
    g_lastGeneratedReport = [finalReport copy];
    [UIPasteboard generalPasteboard].string = finalReport;
    
    [self hideProgressHUD];
    [self showEchoNotificationWithTitle:@"核心提取完成" message:@"已直接从内存提取并复制。"];
    [self presentAIActionSheetWithReport:finalReport];
}


// -------------------------------------------------------------------------
// UI & 交互逻辑
// -------------------------------------------------------------------------
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
        btn.backgroundColor = color;
        btn.tag = tag;
        [btn addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
        btn.layer.cornerRadius = 12;
        [btn setTitle:title forState:UIControlStateNormal];
        if (iconName && [UIImage respondsToSelector:@selector(systemImageNamed:)]) {
            [btn setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
            btn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
            btn.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
        }
        btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        btn.tintColor = [UIColor whiteColor];
        return btn;
    };
    
    CGFloat currentY = 15.0;
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 30)];
    titleLabel.text = @"Echo 推衍核心 v30.0";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [contentView addSubview:titleLabel];
    currentY += 30 + 20;

    CGFloat compactBtnWidth = (contentView.bounds.size.width - 2 * padding - 10) / 2.0;
    NSString *promptTitle = [NSString stringWithFormat:@"Prompt: %@", g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭"];
    UIColor *promptColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
    UIButton *promptButton = createButton(promptTitle, @"wand.and.stars.inverse", kButtonTag_AIPromptToggle, promptColor);
    promptButton.frame = CGRectMake(padding, currentY, compactBtnWidth, 40);
    promptButton.selected = g_shouldIncludeAIPromptHeader;
    [contentView addSubview:promptButton];

    NSString *benMingTitle = [NSString stringWithFormat:@"本命: %@", g_shouldExtractBenMing ? @"开启" : @"关闭"];
    UIColor *benMingColor = g_shouldExtractBenMing ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
    UIButton *benMingButton = createButton(benMingTitle, @"person.text.rectangle", kButtonTag_BenMingToggle, benMingColor);
    benMingButton.frame = CGRectMake(padding + compactBtnWidth + 10, currentY, compactBtnWidth, 40);
    benMingButton.selected = g_shouldExtractBenMing;
    [contentView addSubview:benMingButton];
    currentY += 40 + 15;
    
    UIView *textViewContainer = [[UIView alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 110)];
    textViewContainer.backgroundColor = ECHO_COLOR_CARD_BG;
    textViewContainer.layer.cornerRadius = 12;
    [contentView addSubview:textViewContainer];
    
    g_questionTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, 0, textViewContainer.bounds.size.width - 2*padding - 40, 110)];
    g_questionTextView.backgroundColor = [UIColor clearColor];
    g_questionTextView.textColor = [UIColor lightGrayColor];
    g_questionTextView.font = [UIFont systemFontOfSize:14];
    g_questionTextView.text = @"选填：输入您想问的具体问题";
    g_questionTextView.delegate = (id<UITextViewDelegate>)self;
    g_questionTextView.returnKeyType = UIReturnKeyDone;
    [textViewContainer addSubview:g_questionTextView];

    g_clearInputButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [g_clearInputButton setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    g_clearInputButton.frame = CGRectMake(textViewContainer.bounds.size.width - padding - 25, 10, 25, 25);
    g_clearInputButton.tintColor = [UIColor grayColor];
    g_clearInputButton.tag = kButtonTag_ClearInput;
    g_clearInputButton.alpha = 0;
    [g_clearInputButton addTarget:self action:@selector(handleMasterButtonTap:) forControlEvents:UIControlEventTouchUpInside];
    [textViewContainer addSubview:g_clearInputButton];
    currentY += 110 + 20;

    UIButton *stdButton = createButton(@"标准课盘 (API直取)", @"bolt.fill", kButtonTag_StandardReport, ECHO_COLOR_MAIN_BLUE);
    stdButton.frame = CGRectMake(padding, currentY, contentView.bounds.size.width - 2*padding, 50);
    [contentView addSubview:stdButton];
    currentY += 50 + 15;

    // 保留旧的单项提取按钮作为备用
    UILabel *sec2Title = [[UILabel alloc] initWithFrame:CGRectMake(padding, currentY, contentView.bounds.size.width-2*padding, 22)];
    sec2Title.text = @"备用单项提取 (旧模式)";
    sec2Title.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold]; 
    sec2Title.textColor = [UIColor lightGrayColor];
    [contentView addSubview:sec2Title];
    currentY += 22 + 10;
    
    CGFloat cardBtnWidth = (contentView.bounds.size.width - 4*padding) / 3.0;
    UIButton *biFaBtn = createButton(@"毕法", @"book.closed", kButtonTag_BiFa, ECHO_COLOR_AUX_GREY);
    biFaBtn.frame = CGRectMake(padding, currentY, cardBtnWidth, 44);
    [contentView addSubview:biFaBtn];
    UIButton *geJuBtn = createButton(@"格局", @"tablecells", kButtonTag_GeJu, ECHO_COLOR_AUX_GREY);
    geJuBtn.frame = CGRectMake(padding + cardBtnWidth + padding, currentY, cardBtnWidth, 44);
    [contentView addSubview:geJuBtn];
    UIButton *fangFaBtn = createButton(@"方法", @"list.number", kButtonTag_FangFa, ECHO_COLOR_AUX_GREY);
    fangFaBtn.frame = CGRectMake(padding + 2*(cardBtnWidth + padding), currentY, cardBtnWidth, 44);
    [contentView addSubview:fangFaBtn];
    currentY += 44;

    CGFloat bottomButtonsHeight = 40;
    CGFloat logViewHeight = contentView.bounds.size.height - currentY - bottomButtonsHeight - 40;
    g_logTextView = [[UITextView alloc] initWithFrame:CGRectMake(padding, currentY + 20, contentView.bounds.size.width - 2*padding, logViewHeight)];
    g_logTextView.backgroundColor = ECHO_COLOR_CARD_BG;
    g_logTextView.layer.cornerRadius = 12;
    g_logTextView.font = [UIFont fontWithName:@"Menlo" size:12];
    g_logTextView.editable = NO;
    g_logTextView.attributedText = [[NSAttributedString alloc] initWithString:@"[API核心]：就绪。\n" attributes:@{NSForegroundColorAttributeName: [UIColor whiteColor], NSFontAttributeName: g_logTextView.font}];
    [contentView addSubview:g_logTextView];

    CGFloat bottomBtnWidth = (contentView.bounds.size.width - 2*padding - padding) / 2.0;
    UIButton *closeButton = createButton(@"关闭", @"xmark.circle", kButtonTag_ClosePanel, ECHO_COLOR_ACTION_CLOSE);
    closeButton.frame = CGRectMake(padding, contentView.bounds.size.height - bottomButtonsHeight - 10, bottomBtnWidth, bottomButtonsHeight);
    [contentView addSubview:closeButton];
    UIButton *sendLastReportButton = createButton(@"发送课盘", @"arrow.up.forward.app", kButtonTag_SendLastReportToAI, ECHO_COLOR_ACTION_AI);
    sendLastReportButton.frame = CGRectMake(padding + bottomBtnWidth + padding, contentView.bounds.size.height - bottomButtonsHeight - 10, bottomBtnWidth, bottomButtonsHeight);
    [contentView addSubview:sendLastReportButton];

    g_mainControlPanelView.alpha = 0;
    [keyWindow addSubview:g_mainControlPanelView];
    [UIView animateWithDuration:0.4 animations:^{ g_mainControlPanelView.alpha = 1.0; }];
}

%new
- (void)handleMasterButtonTap:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    switch (sender.tag) {
        case kButtonTag_StandardReport:
        case kButtonTag_DeepDiveReport:
            // 无论点击哪个，都调用我们最强大的新方法
            [self runUltimateAPIExtraction];
            break;

        case kButtonTag_ClearInput:
            g_questionTextView.text = @"";
            if ([g_questionTextView.delegate respondsToSelector:@selector(textViewDidEndEditing:)]) {
                [g_questionTextView.delegate textViewDidEndEditing:g_questionTextView];
            }
            [g_questionTextView resignFirstResponder];
            break;
        
        case kButtonTag_AIPromptToggle: {
            g_shouldIncludeAIPromptHeader = !g_shouldIncludeAIPromptHeader;
            NSString *status = g_shouldIncludeAIPromptHeader ? @"开启" : @"关闭";
            [sender setTitle:[NSString stringWithFormat:@"Prompt: %@", status] forState:UIControlStateNormal];
            sender.backgroundColor = g_shouldIncludeAIPromptHeader ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
            LogMessage(EchoLogTypeInfo, @"[设置] Prompt 已 %@。", status);
            break;
        }
        
        case kButtonTag_BenMingToggle: {
            g_shouldExtractBenMing = !g_shouldExtractBenMing;
            NSString *status = g_shouldExtractBenMing ? @"开启" : @"关闭";
            [sender setTitle:[NSString stringWithFormat:@"本命: %@", status] forState:UIControlStateNormal];
            sender.backgroundColor = g_shouldExtractBenMing ? ECHO_COLOR_PROMPT_ON : ECHO_COLOR_SWITCH_OFF;
            LogMessage(EchoLogTypeInfo, @"[设置] 本命信息提取已 %@。", status);
            break;
        }
        
        case kButtonTag_ClosePanel:
            [self createOrShowMainControlPanel];
            break;
        
        case kButtonTag_SendLastReportToAI: {
            if (g_lastGeneratedReport.length > 0) {
                [self presentAIActionSheetWithReport:g_lastGeneratedReport];
            } else {
                LogMessage(EchoLogTypeWarning, @"课盘缓存为空，请先推衍。");
            }
            break;
        }

        // 旧模式单项提取
        case kButtonTag_BiFa: {
            [self showProgressHUD:@"正在提取毕法...(旧模式)"];
            [self extractBiFa_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if(strongSelf) {
                    [strongSelf hideProgressHUD];
                    [UIPasteboard generalPasteboard].string = SafeString(result);
                    [strongSelf showEchoNotificationWithTitle:@"毕法提取完成" message:@"已复制到剪贴板。"];
                }
            }];
            break;
        }
        case kButtonTag_GeJu: {
            [self showProgressHUD:@"正在提取格局...(旧模式)"];
            [self extractGeJu_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if(strongSelf) {
                    [strongSelf hideProgressHUD];
                    [UIPasteboard generalPasteboard].string = SafeString(result);
                    [strongSelf showEchoNotificationWithTitle:@"格局提取完成" message:@"已复制到剪贴板。"];
                }
            }];
            break;
        }
        case kButtonTag_FangFa: {
            [self showProgressHUD:@"正在提取方法...(旧模式)"];
            [self extractFangFa_NoPopup_WithCompletion:^(NSString *result) {
                __strong typeof(weakSelf) strongSelf = weakSelf;
                if(strongSelf) {
                    [strongSelf hideProgressHUD];
                    [UIPasteboard generalPasteboard].string = SafeString(result);
                    [strongSelf showEchoNotificationWithTitle:@"方法提取完成" message:@"已复制到剪贴板。"];
                }
            }];
            break;
        }

        default: break;
    }
}

%new
- (void)presentAIActionSheetWithReport:(NSString *)report {
    if (!report || report.length == 0) return;
    [UIPasteboard generalPasteboard].string = report; 
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"发送课盘至AI助手" message:@"课盘已复制到剪贴板" preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *encodedReport = [report stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSArray *aiApps = @[
        @{@"name": @"DeepSeek", @"scheme": @"deepseek://", @"format": @"deepseek://send?text=%@"},
        @{@"name": @"Kelivo", @"scheme": @"kelivo://", @"format": @"kelivo://send?text=%@"},
    ];    
    for (NSDictionary *appInfo in aiApps) {
        if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:appInfo[@"scheme"]]]) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"发送到 %@", appInfo[@"name"]] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:appInfo[@"format"], encodedReport]];
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }];
            [actionSheet addAction:action];
        }
    }
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:actionSheet animated:YES completion:nil];
}


// --- 旧模式单项提取函数 (保留) ---
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


// --- UI 辅助函数 ---
%new
- (void)textViewDidChange:(UITextView *)textView {
    BOOL hasText = textView.text.length > 0 && ![textView.text isEqualToString:@"选填：输入您想问的具体问题"];
    [UIView animateWithDuration:0.2 animations:^{ g_clearInputButton.alpha = hasText ? 1.0 : 0.0; }];
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
    if (textView.text.length == 0) {
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
- (void)showProgressHUD:(NSString *)text {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    UIView *existing = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if(existing) [existing removeFromSuperview];
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 220, 120)];
    progressView.center = keyWindow.center;
    progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
    progressView.layer.cornerRadius = 10;
    progressView.tag = kEchoProgressHUDTag;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor];
    spinner.center = CGPointMake(110, 50);
    [spinner startAnimating];
    [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 85, 200, 30)];
    progressLabel.textColor = [UIColor whiteColor];
    progressLabel.textAlignment = NSTextAlignmentCenter;
    progressLabel.font = [UIFont systemFontOfSize:14];
    progressLabel.text = text;
    [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
}
%new
- (void)hideProgressHUD {
    UIWindow *keyWindow = GetFrontmostWindow();
    UIView *progressView = [keyWindow viewWithTag:kEchoProgressHUDTag];
    if (progressView) {
        [UIView animateWithDuration:0.3 animations:^{ progressView.alpha = 0; } completion:^(BOOL finished) { [progressView removeFromSuperview]; }];
    }
}
%new
- (void)showEchoNotificationWithTitle:(NSString *)title message:(NSString *)message {
    UIWindow *keyWindow = GetFrontmostWindow(); if (!keyWindow) return;
    CGFloat topPadding = keyWindow.safeAreaInsets.top > 0 ? keyWindow.safeAreaInsets.top : 20;
    CGFloat bannerWidth = keyWindow.bounds.size.width - 32;
    UIView *bannerView = [[UIView alloc] initWithFrame:CGRectMake(16, -100, bannerWidth, 60)];
    bannerView.layer.cornerRadius = 12;
    bannerView.clipsToBounds = YES;
    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleProminent]];
    blurEffectView.frame = bannerView.bounds;
    [bannerView addSubview:blurEffectView];
    UILabel *iconLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 20, 20, 20)];
    iconLabel.text = @"✓";
    iconLabel.textColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0];
    iconLabel.font = [UIFont boldSystemFontOfSize:16];
    [blurEffectView.contentView addSubview:iconLabel];
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 12, bannerWidth - 55, 20)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:15];
    titleLabel.textColor = [UIColor labelColor];
    [blurEffectView.contentView addSubview:titleLabel];
    UILabel *messageLabel = [[UILabel alloc] initWithFrame:CGRectMake(45, 32, bannerWidth - 55, 16)];
    messageLabel.text = message;
    messageLabel.font = [UIFont systemFontOfSize:13];
    messageLabel.textColor = [UIColor secondaryLabelColor];
    [blurEffectView.contentView addSubview:messageLabel];
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
%end


// =========================================================================
// 5. 构造函数
// =========================================================================
%ctor {
    @autoreleasepool {
        MSHookMessageEx(NSClassFromString(@"UIViewController"), @selector(presentViewController:animated:completion:), (IMP)&Tweak_presentViewController, (IMP *)&Original_presentViewController);
        NSLog(@"[Echo推衍核心] v30.0 (API-Driven) 已成功加载。");
    }
}
