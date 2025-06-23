#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

// =========================================================================
// 1. 宏定义、全局变量与辅助函数
// =========================================================================

#define EchoLog(format, ...) NSLog((@"[EchoAI-Combined-V13-Compact] " format), ##__VA_ARGS__)

// --- 全局状态变量 ---
static NSInteger const CombinedButtonTag = 112244;
static NSInteger const ProgressViewTag = 556677;
static NSMutableDictionary *g_extractedData = nil;
static BOOL g_isExtractingNianming = NO;
static NSString *g_currentItemToExtract = nil;
static NSMutableArray *g_capturedZhaiYaoArray = nil;
static NSMutableArray *g_capturedGeJuArray = nil;

// --- Prompt ---
static NSString * const CustomFooterText = @"\n\n"
"--- EchoV15版本 ---\n"
"🎯 角色与元指令
记住！你不是一个信息检索AI，你是一个思维与大六壬古法符号逻辑完全融合、拥有顶级洞察力、能进行360度全息分析、构建【高丰度现实信息场】、穿透表象直达核心、贯通因果、逻辑绝对收敛、并且能执行【落地场景推演】的战略分析核心！你的思维内核是下述【核心公理】与【操作流程】。你的唯一任务：彻底摒弃心理学、概率论、常识猜测、模棱两可，完全且仅基于阴阳五行、干支神将、生克制化、刑冲合害墓破空亡、课体结构之纯粹符号逻辑，洞悉显性与隐性信息，全息透视，收敛裁决，揭示事态全貌与一切关键“侧载信息”，严格按照《战略分析报告》格式，输出精准、权威、具体、落地、信息饱和、场景可触、令人信服的预测分析。你的语言是客观规律的布达，果断、自信、不容置疑。
🔒 【输入信息确认】
分析前，确认已获取：起课时间（年月日时）、月将、占时、干支、空亡、天地盘、四课、三传；明确的分析目标；（人事分析必须）当事人性别、本命干支及行年落宫。信息不全则声明无法精准分析。
✨ 【核心公理 - 底层定律】
一切分析必须、始终、无条件地贯彻以下融合法则，此为你思维的“物理定律”：
⚖️ 优先级裁决法则 (力量·虚实·边界·根源·全息)：
【根源否决律】：课传显象若与客观物理规律、季节时令、人事常伦存在根本性、绝对性冲突，或关键类神、命年、干支、三传皆落绝境（全空、全破、全墓、全绝、全囚死无气），则事态根基已断，可依根源直断其伪、其空、其败、其止。此为裁决之最高优先级。
🔥**【全息透视律】(核心强化点：信息饱和度之基石)：强制扫描课传全局、天地盘、命年、占时等一切符号及其【相互关系】。不仅关注核心目标，更要强制捕捉所有显性、隐性、伴生、根源、侧载信息。侧载信息是分析的血肉，必须深挖，例如：财务状况、健康隐患、人际关系（合作者/竞争者/家庭成员）的真实意图与状态、潜在对手、合同契约的隐藏条款或陷阱、环境的优劣与变动、当事人的品行特质、未言明的债务或法律风险、事态的时间线延宕或突变等。严禁隧道视野，必须构建事态【完整、立体、信息饱和】的现实图景。
【力量权衡律】：比较核心要素间旺相休囚死、生克制化之力量对比，旺胜衰，生胜克（贪生忘克），多胜寡。
【虚实辩证律】：空亡、月破、墓、绝为虚；旺相、长生、临官、月建、占时、填实、冲实为实。虚不胜实，虚不受生，虚不克实，实能填/冲虚。
【裁决次序律】：严格依 命年 > 干支（及其互动） > 干支上神/阴神 > 三传（及其互动） > 核心类神 > 课体结构 > 神煞 > 占时 的次序审视其对事态的定义权。前者对后者有统摄与否决权。
【信息阈值律】：单一象意不足为凭，多重、多维信息交叉验证、指向归一，方可定论。
🔬 符号解读与互动法则 (转化·烈度·表里·归一·结构·神煞·网络)：
【象意转化律】：象意非固定。依生克、神将、神煞、结构、事态及【互动关系】，动态转化象意。
【烈度校准律】：融合旺衰、神煞、结构，校准吉凶、成败、快慢、多寡、轻重之具体程度。
【阴阳表里律】：四课上神、初中传为表、为显、为始；阴神、末传、地盘、本命、暗藏为里、为隐、为终、为根。须透表及里，表里互参。
🔥【生克互动网络律】(核心强化点：网络定义价值，杜绝无效周转)：将干支、四课、三传、命年视为一个能量与关系的动态网络。必须清晰追踪并分析：
① 干支互动：干与支、干上神与支上神、干与支上神、支与干上神、阴神之间的一切生克冲合刑害脱、交车、互换、互墓、互空关系，定义核心主体间的基调。
② 三传互动：初中末传之间的生克链、进退、顺逆、三合、连茹等关系，定义事态发展的内部流程与趋势。
③ 课传互动：三传如何由四课、干支发出（发用根源），三传的演化（尤其是末传）如何反作用于干支、四课、命年（归结影响），定义事态的因果与闭环。
④ 命年介入：本命行年与干支、四课、三传所有关键节点的互动关系，定义当事人与事态的关联和作用。
此网络分析的唯一目的，是定义清晰的因果链条、心意所属、力量传递路径、关系亲疏实质、事态演化的动态过程与最终归宿。任何互动分析，必须落脚到对【事态性质、走向、信息饱和度】的具体定义上，严禁罗列孤立的生克关系。
🔥【象意归一·裁决法则】(核心强化点：矛盾转化为信息深度，构建信服力)：
① 定锚点：锁定事态核心类神、干支角色、发用，作为逻辑起点。
② 论融合：将作用于锚点的所有信息（包括所有侧载信息），以及由【生克互动网络律】定义的各种互动关系进行【深度融合】，构建【多维、立体、信息饱和的复合象意】，而非简单符号叠加。
③ 行反证 (核心！)：审视课传中一切“矛盾信息”与“矛盾关系”（如合处逢冲、冲中见合、吉中有凶、空亡反吉），必须论证其为何被主导信息/关系否决/化解/包容，或【证明其恰好构成了关键的次要矛盾、背景因素、过程波折、或重要的侧载信息】（例如：合处逢冲，若冲力大于合力，则主分离，但“合”的象意必须转化为“曾有关系/试图挽回/表面和气”等侧载信息，绝不丢弃）。唯有通过反证，将一切表象矛盾纳入统一逻辑框架，证明当前结论的【最高概率性、逻辑收敛性与信息完整性】，方可定论。此步是将“复杂周转”转化为“信息深度”与“信服力”的关键。
【结构统摄律】：高度重视课体、结构（如连茹、反吟、伏吟、鬼墓、三交、断桥、从革、顾祖、时遁、天心、雀鬼、交车等），视其为定义事态性质、走向、气象、信息丰度的宏观框架，统摄细节与互动关系。
🔥【神煞叠加律】(核心强化点：融合渲染场景)：解读关键宫位、关键类神时，须将其上叠加之多个神煞（如桃花劫、破碎、德禄、羊刃、病符）、神将、暗藏、长生十二态意象进行融合渲染**，构建复合、立体、信息极其丰富的【意象场景与人物/事物特质】，此为信息饱和度的重要来源。
🎯 关联定位法则 (人课·事态·角色)：
【人课合一律】：本命、行年是当事人在课中时空坐标，其状态及与全局之【互动关系】，定义人之状态及与事态之关联深浅、得失难易。
【课随事态律】：依所占事态之性质，精准锁定核心类神（如六亲体系之财、官、父、兄、子，及广义之用神、事态专属符号等），一切推演围绕核心类神展开。
【干支定格律】：依分析事态，明确为干、支（及干上、支上、干阴、支阴）赋予具体角色（主客、男女、尊卑、内外、上下级、人与物、人与环境等），以此为“剧情”之主角、配角及其【基础关系】，构建叙事框架。
⏳ 时机感应法则 (动静·占时·应期)：
【动静感应律】：发用、冲、刑、马星、丁神、三传进退主事动；空、墓、合、伏吟、夹、六害主事静、缓、滞、藏。
【占时破译律】：占时为当下时空切片，其自身状态（空破墓）及与课传关键要素（尤其发用、类神、命年）之生克冲合关系，是事态当下状态与应期关键线索。
【应期裁决律】：综合运用冲、合、填实、出空、值日、入/出传、驿马、丁神、类神值期、占时、本命行年感应等，锁定事态发生、变化、结束之具体时间节点。
🔥🔥**【落地场景推演律】(终极要求：信息无损，现实演绎)**
此律专用于【第三段】之风格构建与信息呈现。必须将第二段的逻辑推演结论**【无损、无漏、无折扣地】转化为：
① 角色化：将干支、类神、神将、结构、神煞视为现实中“有名有姓”的角色或“可感可知”的动态力量。
② 动态化：用“加、临、乘、墓、克、冲、刑、害、夹、隔、逼、逃、进、退、罩、引、破、锁、泄、遁”等强动词描绘其【互动】与空间关系，展现【生克互动网络】的现实力量博弈。
③ 戏剧化：构建冲突、转折（叙述【反证】，如合处逢冲、先合后离、镜花水月）、困境、结局的“现实剧情”。
④ 具体化 (核心！)：强制融合【结构统摄】、【神煞叠加】、【全息透视】捕捉到的一切【侧载信息】，并进行【大胆而精准的取象】，渲染场景细节、环境氛围、人物心理、真实动机、具体物件、金钱数额、地点方位等，构建信息饱和、细节丰富、可触摸的现实画面。
⑤ 写意化：语言生动、跌宕、有画面感、节奏感，具确定性与张力。
⑥ 流畅化 (核心！)：严禁使用【】、 * 等任何视觉强调符号。 强调与张力必须通过词语选择、句式变换、节奏控制、语势构建来自然实现，文气贯通，浑然一体，如亲眼所见。
⑦ 逻辑内核不变：叙事内容必须【严格、完全】基于第二段【象意归一·裁决法则】与【反证】逻辑推导出的收敛性结论、【生克互动网络】定义的动态关系及所有被论证的【全部侧载信息】，绝不临场发挥、增删逻辑与信息。第三段是第二段逻辑的【落地化、场景化、信息无损化演绎】，是全息信息的【动态全景展示】，而非新的推导或信息缩水。
⚙️ 【操作流程 - 分析系统】
必须严格按此步骤思考与构建：
STEP 0 宏观定调：俯瞰全局。执行【根源否决律】、【全息透视律】、【结构统摄律】初步扫描，定下【一句话核心基调】与信息饱和度基调。
STEP 1 识别主体与关系：明确分析类型，锁定【核心类神】，执行【干支定格律】分配角色，锁定所有“关联方”、“根源因素”、“潜藏状态”、“侧载信息”的关键符号，及本命、行年。
STEP 2 提取信息与网络：系统提取干支、三传、所有锁定要素、命年、神将、空破墓、所有神煞、结构、占时等关键要素状态，并初步构建【生克互动网络】。
STEP 3 逻辑推演 (核心！)：综合运用【核心公理】。必须清晰展示【全息透视】如何捕捉全部关键信息与侧载信息，应用【生克互动网络律】分析各模块间关系，定义因果与动态，并强制执行【象意归一·裁决法则】的【定锚点、论融合、行反证】全过程，论证矛盾信息如何被转化为信息深度。基于此收敛的【全景信息场】与互动网络，裁决所问之事的结果及【所有伴生的侧载信息】，并说明应期法理。此步完成纯粹逻辑与【信息全集】的构建。
STEP 4 输出结论 (核心！)：严格执行【落地场景推演律】，将STEP 3构建的逻辑结论、【全景信息场】、互动关系与【所有侧载信息】，【无损、无漏地演绎】为权威、具体、生动、跌宕、自然流畅、信息饱和、画面感极强的落地分析。
STEP 5 强制自检：对照【自检清单】与【负面清单】，校对无误。
📝 【战略分析报告输出模式 - 严格执行】
(对应STEP 0) 第零段：宏观定调 • 结构总论
基于全局俯瞰，点明此课的核心基调、气象、结构总论。【必点明课体结构、全息特征、互动关系特征、信息饱和度层次及信息收敛方向】。
(对应STEP 2) 第一段：符号精解 • 关系标定
精准描述：干支角色、核心类神、干支上神阴神、三传、本命行年、占时、所有关键神煞、结构、以及【全息透视律】锁定的所有关联方、根源、隐态、侧载信息符号之状态、位置，并初步点明关键的【干支、三传、课传、命年互动关系】。专业术语密集。
(对应STEP 3) 第二段：逻辑推演 • 机理洞悉 (逻辑内核与信息全集展示)
必须清晰阐述：
如何运用【全息透视律】、【结构统摄律】、【神煞叠加律】、【干支定格律】构建【全景高饱和信息场】。
🔥核心： 依【生克互动网络律】，清晰论证干支之间、三传内部、课传之间、以及命年与全局的关键互动关系，证明关系亲疏、力量流向、因果链条、事态演化路径。
🔥核心： 清晰展示【象意归一·裁决法则】的【定锚点、论融合、行反证】全过程，逻辑裁决与融合所有信息（特别是侧载信息）与【互动关系】，证明结论及【所有侧载细节】的收敛性，解释矛盾信息如何被转化为具体情境。
基于此【全息且归一】之信息场与互动网络，裁定最终结论与【所有侧载细节】。
清晰说明【应期判断的逻辑依据】。引用《毕法赋》、课格精义等验证。逻辑严丝合密。此段为纯逻辑与【信息全集】层。
(对应STEP 4) 第三段：场景直断 • 落地推演 (风格演绎与信息无损展示)
【严格执行落地场景推演律！】：
将第二段的逻辑结论、【所有侧载信息】与【所有关键互动关系】，【无损、丰富地演绎】为生动、动态、具体、跌宕、自然流畅的“现实分析剧情”。
生动描绘关键符号间的动态攻伐与空间关系，展现【生克互动网络律】定义的力量流向与关系演变全过程。
将【课体结构】名称意涵融入叙事骨架（如：反吟则反复不定、从革则新旧交替）。
将【神煞叠加】、【神将】、【全息透视】之意象融入氛围渲染与情景描绘，构建信息丰富的立体场景。
以叙事中的【转折、对比】来展现【逻辑反证】（如“虽见...奈何...”、“合处逢冲终致分离”、“看似...实则...”）。
🔥核心： 生动、自然、具象地叙述【全部】关键“侧载信息”（如：关联人动机、隐藏的债务、健康问题、品性缺陷、竞争态势、环境阻力、心理状态、信息真伪等），将其无缝编织进主线剧情。
🔥核心： 给出由【象意归一】推导出的、高度聚焦、信息密度极高、涵盖主次矛盾与全部关键细节的【精准核心结论】与精准【应期】（定于某时，因XX逻辑）。
使用 "必然"、"必定"、"定数"、"绝无可能" 、"终将"等权威词汇，辅以跌宕、画面感、节奏感之语势，全陈述句，无任何疑问句。严禁使用任何视觉强调符号。
🔍 【专题路径铁律】
针对特定分析主题（如：关系、财运、事业、法务、健康、寻物、出行、环境、学业等），必须优先调用该主题之核心类神定位法则、特殊结构意涵、专属神煞解释及判断准则。严禁跨主题乱套类神与法则。
🛑 【输出前强制自检清单 - 守门员】
是否执行【第零段：宏观定调】？
🔥核心： 第二段与第三段，是否清晰分析并生动叙述了【生克互动网络律】所定义的关键【互动关系】，证明其非无效周转？
🔥最高优先级： 第二段是否执行了【象意归一·裁决法则】，清晰展示【逻辑反证】，证明结论收敛性，且【将矛盾信息转化为有价值的侧载信息或过程描述】？
🔥核心关键： 第二段的逻辑推演与第三段的场景叙事，是否充分体现了【全息透视】、【神煞叠加】带来的【信息饱和度】，全面揭示并生动演绎了关键的“侧载信息”，构建了立体场景，而非【信息贫瘠、干瘪抽象】？
✨关键： 第三段是否严格执行了【落地场景推演律】？是否将符号【活化、动态化、戏剧化】？语言风格是否【落地、具体、自然流畅】？是否完全避免了视觉符号？
🔥核心关键： 第三段的叙事内容，是否【完全、无损、且仅】基于第二段的逻辑结论、互动关系分析和【所有侧载信息】，做到【风格演绎，信息无漏，内核不变】，而非另起炉炉灶或信息缩水？
是否触犯【负面清单】中任何一条？
🚫 【负面清单 - 思维禁区】
严禁 平均主义：不分主次、力量，平均看待所有符号。
严禁 僵化读象：不依事态、生克、结构转化象意。
严禁 模棱两可：使用“可能、也许、大概”等概率词汇。
严禁 脱离事态：空谈课理，不紧扣分析目标。
严禁 舍本逐末：忽略干支、三传、命年，过度解读次要神煞。
严禁 逻辑跳跃：象与断之间无线索、无推理、无反证。
严禁 掺杂私货：混入非符号逻辑（心理分析、常识、个人好恶）。
严禁 强行判断：信息不足或矛盾无法归一时，强行下结论。
严禁 隧道视野：忽略全息“侧载信息”。
严禁 象意堆砌：简单罗列象意，未进行【归一反证】，未能构建复合信息场。
🔥核心禁令：严禁 模块孤立与无效周转：未能执行【生克互动网络律】，将各模块视为孤立部分，或虽言生克但未能定义其对【因果链接、力量流转、事态走向】的实质影响。
🔥核心禁令：严禁 信息贫瘠与象意孤立：未能执行全息透视、神煞叠加、结构统摄、归一反证，断语单薄，象意孤立，未挖掘、融合、演绎多层次信息及关键“侧载信息”，导致第三段【场景推演】干瘪、抽象、缺乏细节与现实感。
🔥核心禁令：严禁 风格错位与信息漏失：第三段【场景直断】未能执行【落地场景推演律】，语言风格平铺直叙、缺乏动态、画面感与戏剧张力，或【信息贫瘠】；或第三段叙事内容脱离、缩水、遗漏了第二段的逻辑结论与【关键侧载信息】，导致逻辑与风格、信息量前后断裂。
🔥核心禁令：严禁 符号标注：在输出文本中（特别是第三段）使用【】、 等任何视觉强调符号，破坏语言的自然流畅与权威感。
⚡ 终极标准
你输出的每一篇分析，必须是公理贯通、流程严谨、逻辑无漏、法理纯正、全息尽显、互动清晰、信息饱和、归一反证、场景落地、现实可触、结论信服的专家级分析报告！ ==秉持核心公理，融会贯通，全息透视，网络互动，归一反证，落地推演！==//现在问：";


// --- 辅助函数 (保持不变) ---
static void FindSubviewsOfClassRecursive(Class aClass, UIView *view, NSMutableArray *storage) { if ([view isKindOfClass:aClass]) { [storage addObject:view]; } for (UIView *subview in view.subviews) { FindSubviewsOfClassRecursive(aClass, subview, storage); } }
static id GetIvarValueSafely(id object, NSString *ivarNameSuffix) { if (!object || !ivarNameSuffix) return nil; unsigned int ivarCount; Ivar *ivars = class_copyIvarList([object class], &ivarCount); if (!ivars) { free(ivars); return nil; } id value = nil; for (unsigned int i = 0; i < ivarCount; i++) { Ivar ivar = ivars[i]; const char *name = ivar_getName(ivar); if (name) { NSString *ivarName = [NSString stringWithUTF8String:name]; if ([ivarName hasSuffix:ivarNameSuffix]) { ptrdiff_t offset = ivar_getOffset(ivar); void **ivar_ptr = (void **)((__bridge void *)object + offset); value = (__bridge id)(*ivar_ptr); break; } } } free(ivars); return value; }
static NSString* GetStringFromLayer(id layer) { if (layer && [layer respondsToSelector:@selector(string)]) { id stringValue = [layer valueForKey:@"string"]; if ([stringValue isKindOfClass:[NSString class]]) return stringValue; if ([stringValue isKindOfClass:[NSAttributedString class]]) return ((NSAttributedString *)stringValue).string; } return @"?"; }
static UIImage *createWatermarkImage(NSString *text, UIFont *font, UIColor *textColor, CGSize tileSize, CGFloat angle) { UIGraphicsBeginImageContextWithOptions(tileSize, NO, 0); CGContextRef context = UIGraphicsGetCurrentContext(); CGContextTranslateCTM(context, tileSize.width / 2, tileSize.height / 2); CGContextRotateCTM(context, angle * M_PI / 180); NSDictionary *attributes = @{NSFontAttributeName: font, NSForegroundColorAttributeName: textColor}; CGSize textSize = [text sizeWithAttributes:attributes]; CGRect textRect = CGRectMake(-textSize.width / 2, -textSize.height / 2, textSize.width, textSize.height); [text drawInRect:textRect withAttributes:attributes]; UIImage *image = UIGraphicsGetImageFromCurrentImageContext(); UIGraphicsEndImageContext(); return image; }

// =========================================================================
// 2. 界面UI微调 Hooks (UILabel, UIWindow) - 保持不变
// =========================================================================
%hook UILabel
- (void)setText:(NSString *)text { if (!text) { %orig(text); return; } NSString *newString = nil; if ([text isEqualToString:@"我的分类"] || [text isEqualToString:@"我的分類"] || [text isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([text isEqualToString:@"起課"] || [text isEqualToString:@"起课"]) { newString = @"定制"; } else if ([text isEqualToString:@"法诀"] || [text isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { %orig(newString); return; } NSMutableString *simplifiedText = [text mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)simplifiedText, NULL, CFSTR("Hant-Hans"), false); %orig(simplifiedText); }
- (void)setAttributedText:(NSAttributedString *)attributedText { if (!attributedText) { %orig(attributedText); return; } NSString *originalString = attributedText.string; NSString *newString = nil; if ([originalString isEqualToString:@"我的分类"] || [originalString isEqualToString:@"我的分類"] || [originalString isEqualToString:@"通類"]) { newString = @"Echo"; } else if ([originalString isEqualToString:@"起課"] || [originalString isEqualToString:@"起课"]) { newString = @"定制"; } else if ([originalString isEqualToString:@"法诀"] || [originalString isEqualToString:@"法訣"]) { newString = @"毕法"; } if (newString) { NSMutableAttributedString *newAttr = [attributedText mutableCopy]; [newAttr.mutableString setString:newString]; %orig(newAttr); return; } NSMutableAttributedString *finalAttributedText = [attributedText mutableCopy]; CFStringTransform((__bridge CFMutableStringRef)finalAttributedText.mutableString, NULL, CFSTR("Hant-Hans"), false); %orig(finalAttributedText); }
%end

%hook UIWindow
- (void)layoutSubviews { %orig; if (self.windowLevel != UIWindowLevelNormal) { return; } NSInteger watermarkTag = 998877; if ([self viewWithTag:watermarkTag]) { return; } NSString *watermarkText = @"Echo定制"; UIFont *watermarkFont = [UIFont systemFontOfSize:16.0]; UIColor *watermarkColor = [UIColor.blackColor colorWithAlphaComponent:0.12]; CGFloat rotationAngle = -30.0; CGSize tileSize = CGSizeMake(150, 100); UIImage *patternImage = createWatermarkImage(watermarkText, watermarkFont, watermarkColor, tileSize, rotationAngle); UIView *watermarkView = [[UIView alloc] initWithFrame:self.bounds]; watermarkView.tag = watermarkTag; watermarkView.userInteractionEnabled = NO; watermarkView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; watermarkView.backgroundColor = [UIColor colorWithPatternImage:patternImage]; [self addSubview:watermarkView]; [self bringSubviewToFront:watermarkView]; }
%end

// =========================================================================
// 3. 主功能区：UIViewController 整合
// =========================================================================

@interface UIViewController (EchoAICombinedAddons)
- (void)performCombinedAnalysis;
- (void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion;
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion;
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator;
- (NSString *)extractTianDiPanInfo_V18;
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView;
@end

%hook UIViewController

- (void)viewDidLoad {
    %orig;
    Class targetClass = NSClassFromString(@"六壬大占.ViewController");
    if (targetClass && [self isKindOfClass:targetClass]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = self.view.window; if (!keyWindow) { return; }
            if ([keyWindow viewWithTag:CombinedButtonTag]) { [[keyWindow viewWithTag:CombinedButtonTag] removeFromSuperview]; }
            UIButton *combinedButton = [UIButton buttonWithType:UIButtonTypeSystem];
            combinedButton.frame = CGRectMake(keyWindow.bounds.size.width - 150, 45, 140, 36);
            combinedButton.tag = CombinedButtonTag;
            [combinedButton setTitle:@"高级技法解析" forState:UIControlStateNormal];
            combinedButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
            combinedButton.backgroundColor = [UIColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0];
            [combinedButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            combinedButton.layer.cornerRadius = 8;
            [combinedButton addTarget:self action:@selector(performCombinedAnalysis) forControlEvents:UIControlEventTouchUpInside];
            [keyWindow addSubview:combinedButton];
        });
    }
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (g_extractedData && ![viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
        viewControllerToPresent.view.alpha = 0.0f; flag = NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
            NSString *title = viewControllerToPresent.title ?: @"";
            if (title.length == 0) {
                 NSMutableArray *labels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, labels);
                 if (labels.count > 0) { [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }]; UILabel *firstLabel = labels.firstObject; if (firstLabel && firstLabel.frame.origin.y < 100) { title = firstLabel.text; } }
            }
            NSMutableArray *textParts = [NSMutableArray array];
            if ([title containsString:@"法诀"] || [title containsString:@"毕法"] || [title containsString:@"格局"] || [title containsString:@"方法"]) {
                NSMutableArray *stackViews = [NSMutableArray array]; FindSubviewsOfClassRecursive([UIStackView class], viewControllerToPresent.view, stackViews); [stackViews sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)]; }];
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
                if ([title containsString:@"方法"]) g_extractedData[@"方法"] = content; else if ([title containsString:@"格局"]) g_extractedData[@"格局"] = content; else g_extractedData[@"毕法"] = content;
            } else if ([vcClassName containsString:@"七政"]) {
                NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], viewControllerToPresent.view, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                for (UILabel *label in allLabels) { if (label.text.length > 0) [textParts addObject:label.text]; }
                g_extractedData[@"七政四余"] = [textParts componentsJoinedByString:@"\n"];
            } else { EchoLog(@"[课盘提取] 抓取到未知弹窗 [%@]，内容被忽略。", title); }
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
        });
        %orig(viewControllerToPresent, flag, completion); return;
    }
    else if (g_isExtractingNianming && g_currentItemToExtract) {
        __weak typeof(self) weakSelf = self;
        if ([viewControllerToPresent isKindOfClass:[UIAlertController class]]) {
            UIAlertController *alert = (UIAlertController *)viewControllerToPresent; UIAlertAction *targetAction = nil;
            for (UIAlertAction *action in alert.actions) { if ([action.title isEqualToString:g_currentItemToExtract]) { targetAction = action; break; } }
            if (targetAction) { id handler = [targetAction valueForKey:@"handler"]; if (handler) { ((void (^)(UIAlertAction *))handler)(targetAction); } return; }
        }
        NSString *vcClassName = NSStringFromClass([viewControllerToPresent class]);
        if ([g_currentItemToExtract isEqualToString:@"年命摘要"] && [vcClassName containsString:@"年命摘要視圖"]) {
            UIView *contentView = viewControllerToPresent.view; NSMutableArray *allLabels = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], contentView, allLabels); [allLabels sortUsingComparator:^NSComparisonResult(UILabel *l1, UILabel *l2) { return [@(l1.frame.origin.y) compare:@(l2.frame.origin.y)]; }];
            NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in allLabels) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
            // 【紧凑化修改】
            NSString *compactText = [[textParts componentsJoinedByString:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            [g_capturedZhaiYaoArray addObject:compactText];
            [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil]; return;
        } else if ([g_currentItemToExtract isEqualToString:@"格局方法"] && [vcClassName containsString:@"年命格局視圖"]) {
            void (^newCompletion)(void) = ^{
                if (completion) { completion(); }
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) return;
                    UIView *contentView = viewControllerToPresent.view;
                    Class tableViewClass = NSClassFromString(@"六壬大占.IntrinsicTableView"); NSMutableArray *tableViews = [NSMutableArray array]; if (tableViewClass) { FindSubviewsOfClassRecursive(tableViewClass, contentView, tableViews); }
                    UITableView *theTableView = tableViews.firstObject;
                    if (theTableView && [theTableView.delegate respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)] && theTableView.dataSource) {
                        id<UITableViewDelegate> delegate = theTableView.delegate; id<UITableViewDataSource> dataSource = theTableView.dataSource;
                        NSInteger sections = [dataSource respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [dataSource numberOfSectionsInTableView:theTableView] : 1;
                        for (NSInteger section = 0; section < sections; section++) {
                            NSInteger rows = [dataSource tableView:theTableView numberOfRowsInSection:section];
                            for (NSInteger row = 0; row < rows; row++) {
                                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
                                [delegate tableView:theTableView didSelectRowAtIndexPath:indexPath];
                            }
                        }
                    }
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) return;
                        NSString *formattedGeju = [strongSelf2 formatNianmingGejuFromView:contentView];
                        [g_capturedGeJuArray addObject:formattedGeju];
                        [viewControllerToPresent dismissViewControllerAnimated:NO completion:nil];
                    });
                });
            };
            %orig(viewControllerToPresent, flag, newCompletion); return;
        }
    }
    %orig(viewControllerToPresent, flag, completion);
}

// =========================================================================
// 4. "高级技法解析" 功能实现
// =========================================================================

// ====================== 【V13 核心修复】 ======================
%new
- (NSString *)formatNianmingGejuFromView:(UIView *)contentView {
    // 找到所有可见的 TableViewCell，它们是天然的条目分隔
    Class cellClass = NSClassFromString(@"六壬大占.格局單元");
    if (!cellClass) return @"";
    
    NSMutableArray *cells = [NSMutableArray array];
    FindSubviewsOfClassRecursive(cellClass, contentView, cells);
    [cells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) {
        return [@(v1.frame.origin.y) compare:@(v2.frame.origin.y)];
    }];
    
    NSMutableArray<NSString *> *formattedPairs = [NSMutableArray array];

    for (UIView *cell in cells) {
        NSMutableArray *labelsInCell = [NSMutableArray array];
        FindSubviewsOfClassRecursive([UILabel class], cell, labelsInCell);
        
        if (labelsInCell.count > 0) {
            // 第一个label是标题
            UILabel *titleLabel = labelsInCell[0];
            NSString *title = [[titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            
            // 后续所有label都是内容
            NSMutableString *contentString = [NSMutableString string];
            if (labelsInCell.count > 1) {
                for (NSUInteger i = 1; i < labelsInCell.count; i++) {
                    UILabel *contentLabel = labelsInCell[i];
                    [contentString appendString:contentLabel.text];
                }
            }
            
            // 【紧凑化修改】
            NSString *content = [[contentString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            
            NSString *pair = [NSString stringWithFormat:@"%@→%@", title, content];
            if (![formattedPairs containsObject:pair]) {
                [formattedPairs addObject:pair];
            }
        }
    }
    
    return [formattedPairs componentsJoinedByString:@"\n"];
}

%new
- (void)performCombinedAnalysis {
    EchoLog(@"--- 开始执行 [高级技法解析] 联合任务 ---");
    UIWindow *keyWindow = self.view.window; if (!keyWindow) return;
    UIView *progressView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];
    progressView.center = keyWindow.center; progressView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.75]; progressView.layer.cornerRadius = 10; progressView.tag = ProgressViewTag;
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    spinner.color = [UIColor whiteColor]; spinner.center = CGPointMake(100, 45); [spinner startAnimating]; [progressView addSubview:spinner];
    UILabel *progressLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 80, 180, 30)];
    progressLabel.textColor = [UIColor whiteColor]; progressLabel.textAlignment = NSTextAlignmentCenter; progressLabel.font = [UIFont systemFontOfSize:14]; progressLabel.adjustsFontSizeToFitWidth = YES;
    progressLabel.text = @"提取课盘信息..."; [progressView addSubview:progressLabel];
    [keyWindow addSubview:progressView];
    
    __weak typeof(self) weakSelf = self;
    [self extractKePanInfoWithCompletion:^(NSString *kePanText) {
        __strong typeof(weakSelf) strongSelf = weakSelf; if (!strongSelf) { [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview]; return; }
        EchoLog(@"--- 课盘信息提取完成 ---");
        progressLabel.text = @"提取年命信息...";
        [strongSelf extractNianmingInfoWithCompletion:^(NSString *nianmingText) {
             __strong typeof(weakSelf) strongSelf2 = weakSelf; if (!strongSelf2) { [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview]; return; }
            EchoLog(@"--- 年命信息提取完成 ---");
            [[keyWindow viewWithTag:ProgressViewTag] removeFromSuperview];
            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【年命格局】" withString:@""];
            nianmingText = [nianmingText stringByReplacingOccurrencesOfString:@"【格局方法】" withString:@"【年命格局】"];
            NSString *finalCombinedText;
            if (nianmingText && nianmingText.length > 0) {
                finalCombinedText = [NSString stringWithFormat:@"%@\n\n====================\n【年命分析】\n====================\n\n%@%@", kePanText, nianmingText, CustomFooterText];
            } else {
                finalCombinedText = [NSString stringWithFormat:@"%@%@", kePanText, CustomFooterText];
            }
            [UIPasteboard generalPasteboard].string = [finalCombinedText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"解析完成" message:@"所有高级技法信息已合并，并成功复制到剪贴板。" preferredStyle:UIAlertControllerStyleAlert];
            [successAlert addAction:[UIAlertAction actionWithTitle:@"好的" style:UIAlertActionStyleDefault handler:nil]];
            [strongSelf2 presentViewController:successAlert animated:YES completion:nil];
            EchoLog(@"--- [高级技法解析] 联合任务全部完成 ---");
        }];
    }];
}

%new
- (void)extractKePanInfoWithCompletion:(void (^)(NSString *kePanText))completion {
    #define SafeString(str) (str ?: @"")
    g_extractedData = [NSMutableDictionary dictionary];
    g_extractedData[@"时间块"] = [[self extractTextFromFirstViewOfClassName:@"六壬大占.年月日時視圖" separator:@" "] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    g_extractedData[@"月将"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.七政視圖" separator:@" "];
    g_extractedData[@"空亡"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.旬空視圖" separator:@""];
    g_extractedData[@"三宫时"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.三宮時視圖" separator:@" "];
    g_extractedData[@"昼夜"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.晝夜切換視圖" separator:@" "];
    g_extractedData[@"课体"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.課體視圖" separator:@" "];
    g_extractedData[@"九宗门"] = [self extractTextFromFirstViewOfClassName:@"六壬大占.九宗門視圖" separator:@" "];
    g_extractedData[@"天地盘"] = [self extractTianDiPanInfo_V18];
    NSMutableString *siKe = [NSMutableString string]; Class siKeViewClass = NSClassFromString(@"六壬大占.四課視圖");
    if(siKeViewClass){
        NSMutableArray *siKeViews=[NSMutableArray array]; FindSubviewsOfClassRecursive(siKeViewClass, self.view, siKeViews);
        if(siKeViews.count > 0){
            UIView* container=siKeViews.firstObject; NSMutableArray* labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], container, labels);
            if(labels.count >= 12){
                NSMutableDictionary *cols = [NSMutableDictionary dictionary]; for(UILabel *label in labels){ NSString *key = [NSString stringWithFormat:@"%.0f", roundf(CGRectGetMidX(label.frame))]; if(!cols[key]){ cols[key]=[NSMutableArray array]; } [cols[key] addObject:label]; }
                if (cols.allKeys.count == 4) {
                    NSArray *keys = [cols.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *o1, NSString *o2) { return [@([o1 floatValue]) compare:@([o2 floatValue])]; }];
                    NSMutableArray *c1=cols[keys[0]],*c2=cols[keys[1]],*c3=cols[keys[2]],*c4=cols[keys[3]]; [c1 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c2 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c3 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];[c4 sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
                    NSString* k1s=((UILabel*)c4[0]).text,*k1t=((UILabel*)c4[1]).text,*k1d=((UILabel*)c4[2]).text; NSString* k2s=((UILabel*)c3[0]).text,*k2t=((UILabel*)c3[1]).text,*k2d=((UILabel*)c3[2]).text; NSString* k3s=((UILabel*)c2[0]).text,*k3t=((UILabel*)c2[1]).text,*k3d=((UILabel*)c2[2]).text; NSString* k4s=((UILabel*)c1[0]).text,*k4t=((UILabel*)c1[1]).text,*k4d=((UILabel*)c1[2]).text;
                    siKe = [NSMutableString stringWithFormat:@"第一课: %@->%@%@\n第二课: %@->%@%@\n第三课: %@->%@%@\n第四课: %@->%@%@", SafeString(k1d),SafeString(k1t),SafeString(k1s), SafeString(k2d),SafeString(k2t),SafeString(k2s), SafeString(k3d),SafeString(k3t),SafeString(k3s), SafeString(k4d),SafeString(k4t),SafeString(k4s)];
                }
            }
        }
    }
    g_extractedData[@"四课"] = siKe;
    NSMutableString *sanChuan = [NSMutableString string]; Class sanChuanViewClass = NSClassFromString(@"六壬大占.傳視圖");
    if(sanChuanViewClass){
        NSMutableArray *scViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(sanChuanViewClass, self.view, scViews); [scViews sortUsingComparator:^NSComparisonResult(UIView *o1, UIView *o2) { return [@(o1.frame.origin.y) compare:@(o2.frame.origin.y)]; }];
        NSArray *titles = @[@"初传:", @"中传:", @"末传:"]; NSMutableArray *lines = [NSMutableArray array];
        for(NSUInteger i = 0; i < scViews.count; i++){
            UIView *v = scViews[i]; NSMutableArray *labels=[NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], v, labels); [labels sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
            if(labels.count >= 3){
                NSString *lq=((UILabel*)labels.firstObject).text, *tj=((UILabel*)labels.lastObject).text, *dz=((UILabel*)[labels objectAtIndex:labels.count-2]).text;
                NSMutableArray *ssParts = [NSMutableArray array]; if (labels.count > 3) { for(UILabel *l in [labels subarrayWithRange:NSMakeRange(1, labels.count-3)]){ if(l.text.length > 0) [ssParts addObject:l.text]; } }
                NSString *ss = [ssParts componentsJoinedByString:@" "]; NSMutableString *line = [NSMutableString stringWithFormat:@"%@->%@%@", SafeString(lq), SafeString(dz), SafeString(tj)]; if(ss.length > 0){ [line appendFormat:@" (%@)", ss]; }
                [lines addObject:[NSString stringWithFormat:@"%@ %@", (i < titles.count) ? titles[i] : @"", line]];
            }
        }
        sanChuan = [[lines componentsJoinedByString:@"\n"] mutableCopy];
    }
    g_extractedData[@"三传"] = sanChuan;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SEL sBiFa=NSSelectorFromString(@"顯示法訣總覽"), sGeJu=NSSelectorFromString(@"顯示格局總覽"), sQiZheng=NSSelectorFromString(@"顯示七政信息WithSender:"), sFangFa=NSSelectorFromString(@"顯示方法總覽");
        #define SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING(code) _Pragma("clang diagnostic push") _Pragma("clang diagnostic ignored \"-Warc-performSelector-leaks\"") code; _Pragma("clang diagnostic pop")
        if ([self respondsToSelector:sBiFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sBiFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sGeJu]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sGeJu withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sFangFa]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sFangFa withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        if ([self respondsToSelector:sQiZheng]) { dispatch_sync(dispatch_get_main_queue(), ^{ SUPPRESS_PERFORM_SELECTOR_LEAK_WARNING([self performSelector:sQiZheng withObject:nil]); }); [NSThread sleepForTimeInterval:0.4]; }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *biFa = g_extractedData[@"毕法"]?:@"", *geJu = g_extractedData[@"格局"]?:@"", *fangFa = g_extractedData[@"方法"]?:@"";
            NSArray *trash = @[@"通类门→\n", @"通类门→", @"通類門→\n", @"通類門→"]; for (NSString *t in trash) { biFa=[biFa stringByReplacingOccurrencesOfString:t withString:@""]; geJu=[geJu stringByReplacingOccurrencesOfString:t withString:@""]; fangFa=[fangFa stringByReplacingOccurrencesOfString:t withString:@""]; }
            if(biFa.length>0) biFa=[NSString stringWithFormat:@"%@\n\n", biFa]; if(geJu.length>0) geJu=[NSString stringWithFormat:@"%@\n\n", geJu]; if(fangFa.length>0) fangFa=[NSString stringWithFormat:@"%@\n\n", fangFa];
            NSString *qiZheng = g_extractedData[@"七政四余"] ? [NSString stringWithFormat:@"七政四余:\n%@\n\n", g_extractedData[@"七政四余"]] : @"";
            NSString *tianDiPan = g_extractedData[@"天地盘"] ? [NSString stringWithFormat:@"%@\n", g_extractedData[@"天地盘"]] : @"";
            NSString *finalText = [NSString stringWithFormat:@"%@\n\n月将: %@\n空亡: %@\n三宫时: %@\n昼夜: %@\n课体: %@\n九宗门: %@\n\n%@%@\n%@\n\n%@%@%@%@", SafeString(g_extractedData[@"时间块"]), SafeString(g_extractedData[@"月将"]), SafeString(g_extractedData[@"空亡"]), SafeString(g_extractedData[@"三宫时"]), SafeString(g_extractedData[@"昼夜"]), SafeString(g_extractedData[@"课体"]), SafeString(g_extractedData[@"九宗门"]), tianDiPan, SafeString(g_extractedData[@"四课"]), SafeString(g_extractedData[@"三传"]), biFa, geJu, fangFa, qiZheng];
            g_extractedData = nil;
            if (completion) { completion([finalText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]); }
        });
    });
}

%new
- (void)extractNianmingInfoWithCompletion:(void (^)(NSString *nianmingText))completion {
    g_isExtractingNianming = YES;
    g_capturedZhaiYaoArray = [NSMutableArray array];
    g_capturedGeJuArray = [NSMutableArray array];
    UICollectionView *targetCV = nil;
    Class unitClass = NSClassFromString(@"六壬大占.行年單元");
    NSMutableArray *cvs = [NSMutableArray array]; FindSubviewsOfClassRecursive([UICollectionView class], self.view, cvs);
    for (UICollectionView *cv in cvs) { if ([cv.visibleCells.firstObject isKindOfClass:unitClass]) { targetCV = cv; break; } }
    if (!targetCV) { EchoLog(@"年命提取模块：未找到行年单元，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }
    
    NSMutableArray *allUnitCells = [NSMutableArray array];
    for (UIView *cell in targetCV.visibleCells) { if([cell isKindOfClass:unitClass]){ [allUnitCells addObject:cell]; } }
    [allUnitCells sortUsingComparator:^NSComparisonResult(UIView *v1, UIView *v2) { return [@(v1.frame.origin.x) compare:@(v2.frame.origin.x)]; }];
    if (allUnitCells.count == 0) { EchoLog(@"年命提取模块：行年单元数量为0，跳过。"); g_isExtractingNianming = NO; if (completion) { completion(@""); } return; }

    NSMutableArray *workQueue = [NSMutableArray array];
    for (NSUInteger i = 0; i < allUnitCells.count; i++) {
        UICollectionViewCell *cell = allUnitCells[i];
        [workQueue addObject:@{@"type": @"年命摘要", @"cell": cell, @"index": @(i)}];
        [workQueue addObject:@{@"type": @"格局方法", @"cell": cell, @"index": @(i)}];
    }
    __weak typeof(self) weakSelf = self;
    __block void (^processQueue)(void);
    processQueue = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || workQueue.count == 0) {
            EchoLog(@"所有年命任务处理完毕。");
            NSMutableString *resultStr = [NSMutableString string];
            NSUInteger personCount = allUnitCells.count;
            for (NSUInteger i = 0; i < personCount; i++) {
                NSString *zhaiYao = (i < g_capturedZhaiYaoArray.count) ? g_capturedZhaiYaoArray[i] : @"[年命摘要未提取到]";
                NSString *geJu = (i < g_capturedGeJuArray.count) ? g_capturedGeJuArray[i] : @"[年命格局未提取到]";
                [resultStr appendFormat:@"--- 人员 %lu ---\n", (unsigned long)i+1];
                [resultStr appendString:@"【年命摘要】\n"];
                [resultStr appendString:zhaiYao];
                [resultStr appendString:@"\n\n【格局方法】\n"];
                [resultStr appendString:geJu];
                if (i < personCount - 1) { [resultStr appendString:@"\n\n--------------------\n\n"]; }
            }
            g_isExtractingNianming = NO;
            if (completion) { completion(resultStr); }
            processQueue = nil;
            return;
        }
        NSDictionary *item = workQueue.firstObject;
        [workQueue removeObjectAtIndex:0];
        NSString *type = item[@"type"];
        UICollectionViewCell *cell = item[@"cell"];
        NSInteger index = [item[@"index"] integerValue];
        EchoLog(@"正在处理 人员 %ld 的 [%@]", (long)index + 1, type);
        g_currentItemToExtract = type;
        id delegate = targetCV.delegate;
        NSIndexPath *indexPath = [targetCV indexPathForCell:cell];
        if (delegate && indexPath && [delegate respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) {
            [delegate collectionView:targetCV didSelectItemAtIndexPath:indexPath];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            processQueue();
        });
    };
    processQueue();
}

%new
- (NSString *)extractTextFromFirstViewOfClassName:(NSString *)className separator:(NSString *)separator {
    Class targetViewClass = NSClassFromString(className); if (!targetViewClass) { EchoLog(@"类名 '%@' 未找到。", className); return @""; }
    NSMutableArray *targetViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(targetViewClass, self.view, targetViews);
    if (targetViews.count == 0) return @"";
    UIView *containerView = targetViews.firstObject; NSMutableArray *labelsInView = [NSMutableArray array]; FindSubviewsOfClassRecursive([UILabel class], containerView, labelsInView);
    [labelsInView sortUsingComparator:^NSComparisonResult(UILabel *o1, UILabel *o2) { if(roundf(o1.frame.origin.y) < roundf(o2.frame.origin.y)) return NSOrderedAscending; if(roundf(o1.frame.origin.y) > roundf(o2.frame.origin.y)) return NSOrderedDescending; return [@(o1.frame.origin.x) compare:@(o2.frame.origin.x)]; }];
    NSMutableArray *textParts = [NSMutableArray array]; for (UILabel *label in labelsInView) { if (label.text && label.text.length > 0) { [textParts addObject:label.text]; } }
    return [textParts componentsJoinedByString:separator];
}
%new
- (NSString *)extractTianDiPanInfo_V18 {
    @try {
        Class plateViewClass = NSClassFromString(@"六壬大占.天地盤視圖") ?: NSClassFromString(@"六壬大占.天地盤視圖類"); if (!plateViewClass) return @"天地盘提取失败: 找不到视图类";
        UIWindow *keyWindow = self.view.window; if (!keyWindow) return @"天地盘提取失败: 找不到keyWindow";
        NSMutableArray *plateViews = [NSMutableArray array]; FindSubviewsOfClassRecursive(plateViewClass, keyWindow, plateViews); if (plateViews.count == 0) return @"天地盘提取失败: 找不到视图实例";
        UIView *plateView = plateViews.firstObject;
        NSDictionary *diGongDict=GetIvarValueSafely(plateView,@"地宮宮名列"),*tianShenDict=GetIvarValueSafely(plateView,@"天神宮名列"),*tianJiangDict=GetIvarValueSafely(plateView,@"天將宮名列");
        if (!diGongDict || !tianShenDict || !tianJiangDict) return @"天地盘提取失败: 未能获取核心数据字典";
        NSArray *diGongLayers=[diGongDict allValues],*tianShenLayers=[tianShenDict allValues],*tianJiangLayers=[tianJiangDict allValues];
        if (diGongLayers.count!=12||tianShenLayers.count!=12||tianJiangLayers.count!=12) return @"天地盘提取失败: 数据长度不匹配";
        NSMutableArray *allLayerInfos = [NSMutableArray array]; CGPoint center = [plateView convertPoint:CGPointMake(CGRectGetMidX(plateView.bounds), CGRectGetMidY(plateView.bounds)) toView:nil];
        void (^processLayers)(NSArray *, NSString *) = ^(NSArray *layers, NSString *type) { for (CALayer *layer in layers) { if (![layer isKindOfClass:[CALayer class]]) continue; CALayer *pLayer = layer.presentationLayer ?: layer; CGPoint pos = [pLayer.superlayer convertPoint:pLayer.position toLayer:nil]; CGFloat dx = pos.x - center.x, dy = pos.y - center.y; [allLayerInfos addObject:@{ @"type": type, @"text": GetStringFromLayer(layer), @"angle": @(atan2(dy, dx)), @"radius": @(sqrt(dx*dx + dy*dy)) }]; } };
        processLayers(diGongLayers, @"diPan"); processLayers(tianShenLayers, @"tianPan"); processLayers(tianJiangLayers, @"tianJiang");
        NSMutableDictionary *palaceGroups = [NSMutableDictionary dictionary];
        for (NSDictionary *info in allLayerInfos) {
            BOOL foundGroup = NO; for (NSNumber *angle in [palaceGroups allKeys]) { CGFloat diff = fabsf([info[@"angle"] floatValue] - [angle floatValue]); if (diff > M_PI) diff = 2*M_PI-diff; if (diff < 0.15) { [palaceGroups[angle] addObject:info]; foundGroup=YES; break; } }
            if (!foundGroup) { palaceGroups[info[@"angle"]] = [NSMutableArray arrayWithObject:info];}
        }
        NSMutableArray *palaceData = [NSMutableArray array];
        for (NSNumber *groupAngle in palaceGroups) { NSMutableArray *group = palaceGroups[groupAngle]; if (group.count != 3) continue; [group sortUsingComparator:^NSComparisonResult(id o1, id o2) { return [o2[@"radius"] compare:o1[@"radius"]]; }]; [palaceData addObject:@{ @"diPan": group[0][@"text"], @"tianPan": group[1][@"text"], @"tianJiang": group[2][@"text"] }]; }
        if (palaceData.count != 12) return @"天地盘提取失败: 宫位数据不完整";
        NSArray *order = @[@"子", @"丑", @"寅", @"卯", @"辰", @"巳", @"午", @"未", @"申", @"酉", @"戌", @"亥"];
        [palaceData sortUsingComparator:^NSComparisonResult(NSDictionary *o1, NSDictionary *o2) { return [@([order indexOfObject:o1[@"diPan"]]) compare:@([order indexOfObject:o2[@"diPan"]])]; }];
        NSMutableString *result = [NSMutableString stringWithString:@"天地盘:\n"];
        for (NSDictionary *entry in palaceData) { [result appendFormat:@"%@宫: %@(%@)\n", entry[@"diPan"], entry[@"tianPan"], entry[@"tianJiang"]]; }
        return result;
    } @catch (NSException *exception) { return [NSString stringWithFormat:@"天地盘提取异常: %@", exception.reason]; }
}

%end
