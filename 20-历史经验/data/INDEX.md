# 经验包索引（自动生成 —— 请勿手工编辑）

> 由 `30-工具\build-index.ps1` 生成于 2026-10-08 13:10:19，命名空间 `universal`。
>
> **用法**：这是导航，不是正文。下面每条只有一个标题/摘要 + id。
> 想读全文，用 ``memory.ps1 search <关键词>``（它会打印命中原行），
> 或直接在对应 ``.jsonl`` 里按 id 搜。

## 一、已验证事实 / 假设（facts）

| id | 状态 | 时间 | 摘要 |
|---|---|---|---|
| f002 | verified | 2026-10-05 | 中文 UTF-8 在全链路正常，无乱码 |
| f003 | verified | 2026-10-05 | DeepSeek 能真实执行 Windows 命令 |
| f004 | verified | 2026-10-05 | 多轮上下文连续 |
| f007 | verified | 2026-10-05 | chatgpt.com 被 DNS 投毒 |
| f008 | verified | 2026-10-05 | ChatGPT Desktop 黑屏的直接原因是网络不通 |
| f009 | verified | 2026-10-06 | DSH SDK 的 session 表是纯内存，协议无 open/resume 方法 |
| f010 | verified | 2026-10-06 | bridge 的 session 冲突可通过冲突自愈解决 |
| f011 | verified | 2026-10-06 | 阿里云日本东京服务器的 IP 没有被 OpenAI 封 |
| f012 | verified | 2026-10-06 | Reality 的 dest 用 www.microsoft.com 会握手失败 |
| f013 | verified | 2026-10-06 | Xray VLESS+Reality+Vision 工作正常 |
| f014 | verified | 2026-10-06 | ChatGPT Desktop 在代理下恢复正常，显示登录界面 |
| f015 | verified | 2026-10-06 | 登录所需端点经代理全部可达 |
| f016 | verified | 2026-10-06 | 代理连续稳定性 6/6 |
| f017 | verified | 2026-10-06 | iPhone 无法提供热点供网 |
| f018 | verified | 2026-10-06 | ChatGPT 个人账号（Free/Go/Plus/Pro）禁止创建 Custom GPT |
| f019 | verified | 2026-10-06 | MCP Apps 移动端不支持（web only） |
| f020 | hypothesis | 2026-10-06 | Codex Remote 已 GA，覆盖所有 ChatGPT 档位（含 Free），支持 Windows host |
| f021 | unverified | 2026-10-06 | Free 账号是否有 Site Tools 权限 |
| f022 | unverified | 2026-10-06 | Free 档位的 Codex 额度是否够用 |
| f023 | unverified | 2026-10-06 | Codex Computer Use 能否驱动浏览器访问 127.0.0.1:8788 |
| f024 | falsified | 2026-10-05 | 阿里云 IP 会被 OpenAI 封 |
| f025 | falsified | 2026-10-05 | 把 WLAN 网络类别改成 Private 就能解决 8788 超时 |
| f026 | verified | 2026-10-06 | memory.ps1 的追加功能可用 |
| f028 | verified | 2026-10-06 | 能给电脑下指令的永远是你设备上的程序，不是 GPT 模型本身 |
| f030 | verified | 2026-10-06 | 桌面版 ChatGPT 已在本地登录，且能看到与手机版同步的对话历史 |
| f031 | verified | 2026-10-06 | Codex (GPT-6) 具备视觉能力，能通过 codex exec -i <图片> 读取界面截图内容 |
| f032 | verified | 2026-10-06 | AA 的云端在国内（115.190.133.236 / 115.191.44.x / 116.205.40.x），必须绕过代理直连 |
| f033 | verified | 2026-10-07 | DSH 会话文件 session.v4.jsonl.zstd 是 zstd 多帧格式，当前主会话解压后达 46MB（7906 帧） |
| f034 | verified | 2026-10-07 | AA runtime 从 starting 变为 ready 的条件是「首次会话清单成功提交到平台」 |
| f035 | verified | 2026-10-07 | 系统代理是单点故障：ProxyEnable=1 指向 127.0.0.1:10809 而 Xray 未运行时，所有走代理的程序全部失败 |
| f036 | falsified | 2026-10-07 | Agents Anywhere 不受 Xray 影响，它的后端连接走代理绕过列表直连 |
| f037 | verified | 2026-10-07 | 2026-10-07 开机后 AA 连续失败 367 次（07:19-07:50），错误只有两种：getaddrinfo failed 与 All connection att… |
| f038 | verified | 2026-10-07 | Xray 配置无 DNS 段、无 TUN 适配器，只监听本机 10808/10809，因此不可能影响系统 DNS |
| f039 | verified | 2026-10-07 | 千问更新器在计划任务与 HKCU Run 两处注册，触发器含重复间隔 PT1H，每小时弹一次控制台窗口 |
| f040 | falsified | 2026-10-07 | ai-manager.exe 每次登录以 Highest 权限批量改写各 AI 的 live 配置并跑 healthcheck，但不修改系统代理 |
| f041 | verified | 2026-10-07 | 主会话从 2026-10-02 13:49 连续运行到 10-07，共 189 轮、5 天，期间被压缩 7 次、非正常结束 14 次 |
| f042 | verified | 2026-10-07 | 4 次 interrupted 是真正丢失工作的强行终止，每次都紧跟着 session/end-seed |
| f043 | verified | 2026-10-07 | 7 次上下文压缩的时间点，最后一次(10-07 07:50:05-07:50:31)立即早于 AA 恢复在线(07:50:47)约 22 秒 |
| f044 | hypothesis | 2026-10-07 | 假设：AA 显示离线可能与超大会话导致 DSH 侧忙于压缩有关，而非网络 |
| f045 | hypothesis | 2026-10-07 | ai-manager.exe 二进制内含系统代理注册表的四个关键字符串，且带 proxy 服务模块，是 ProxyEnable 被改动的首要嫌疑对象 |
| f046 | verified | 2026-10-07 | 2026-10-07 08:02:43 到 08:13:09 之间，ProxyEnable 在无我方操作的情况下从 1 变成 0 |
| f047 | verified | 2026-10-07 | ProxyEnable 被意外置 0 的后果是安全的：等价于失效安全的降级态，不会造成死代理 |
| f048 | verified | 2026-10-07 | Codex 安装目录是带哈希的易变目录，升级即变；曾有 5 个脚本写死旧的 f544b3844e0f14e9，导致 delegate.ps1 调 Codex 完全不通 |
| f049 | verified | 2026-10-07 | 电脑端 AI（Codex GPT-6 视觉）能准确读取桌面版 ChatGPT 截图上的文字内容 |
| f050 | verified | 2026-10-07 | 本机 pwsh 工具会话的 PowerShell 执行策略是 Restricted，dot-source .ps1 会抛 PSSecurityException |
| f051 | verified | 2026-10-07 | 系统代理被意外置 0 的后果是安全的降级态，不会造成死代理 |
| f052 | verified | 2026-10-07 | AA connector 原本强制把后端连接走系统代理，这是死代理时 AA 整体失效的真正原因 |
| f053 | verified | 2026-10-07 | 已把 AA connector 改为永久直连，AA 从此不受 Xray 开关影响 |
| f054 | verified | 2026-10-07 | AA 恢复可用的判定信号是插件日志出现 sync.inventory_completed |
| f055 | verified | 2026-10-07 | DSH 的 workspace.json 结构是 tables.workspaces.<id>.sessionIds，不是顶层 sessionIds |
| f056 | verified | 2026-10-07 | 网络代理已在桌面提供窗口式一键开关，内置死代理告警与手机通道自愈 |
| f057 | verified | 2026-10-07 | 旧的可执行入口 网络切换.cmd 因带 UTF-8 BOM 而完全无法运行 |
| f058 | verified | 2026-10-07 | 桌面「网络代理」入口改为 VBS 原生对话框：显示现状、三选一、再显示结果，全程无命令行窗口 |
| f059 | verified | 2026-10-07 | 本机「ChatGPT」和「Codex」是同一个桌面应用：Appx 包名为 OpenAI.Codex，程序文件叫 ChatGPT.exe |
| f060 | verified | 2026-10-07 | Codex CLI 已登录并可用，实测 codex exec 6.5 秒返回正确结果 |
| f061 | verified | 2026-10-07 | 阿里云东京服务器不是手机缓慢的原因：负载 0.08、内存可用 436MB、Xray 稳定运行 24 小时、443 端口 35 个连接 |
| f062 | verified | 2026-10-07 | 电脑到 ChatGPT 的链路很快（首字节约 0.3 秒），手机慢是因为走了另一条差的路 |
| f063 | verified | 2026-10-07 | 已把电脑做成手机的局域网代理：Xray 新增 0.0.0.0:10810 带密码的 http 入站，并加防火墙规则仅放行本地子网 |
| f065 | verified | 2026-10-07 | Xray 已配置国内外分流：国内域名/IP 走 direct 出站，其余走东京 vless，因此手机全局挂代理也不会让国内 App 变慢 |
| f068 | verified | 2026-10-07 | ChatGPT 桌面版「让 AI 操控电脑」的官方开关在 设置 → 常规 → 权限 → 完整访问权限（与 默认权限 二选一） |
| f069 | verified | 2026-10-07 | Codex/ChatGPT 桌面版的相关能力开关现状：computer_use 已开、node_repl 已启用、browser_use 已开；cua_repl 被禁用 |
| f070 | verified | 2026-10-07 | Codex 的 computer use 由 ChatGPT 桌面应用托管：应用在满足条件时才把 cua_repl 的 MCP 配置写入并启用，用户无需手填参数 |
| f071 | verified | 2026-10-07 | cua_repl 启动必需环境变量 CUA_REPL_ENABLED_SURFACES，缺失即启动失败，这正是 codex doctor 报的 MCP 配置问题 |
| f072 | verified | 2026-10-07 | computer use 的底层通道已在运行，只差 MCP 注册这一步 |
| f073 | verified | 2026-10-07 | 本机 ChatGPT 权限状态：permissionStatus=not-requested，当前生效的权限档是 :workspace（仅工作空间），尚未授予完整访问权限 |
| f074 | verified | 2026-10-07 | computer use 的插件随 ChatGPT 桌面版一起打包，但本机应用从未注册它自带的 openai-bundled 市场，因此插件始终没被安装 |
| f075 | verified | 2026-10-07 | openai-bundled 是保留市场名，外部命令无法注册，只能由应用自身注册 |
| f076 | verified | 2026-10-07 | computer-use 插件确认就是让 ChatGPT 操控 Windows 电脑的官方功能，unified-computer-use 提供 cua_repl 服务 |
| f077 | verified | 2026-10-07 | ChatGPT 桌面端 Remote Control 无法启用的根因是 WebSocket 直连被污染 DNS 与封锁卡死，注入代理环境变量后恢复 |
| f078 | verified | 2026-10-07 | ChatGPT 桌面端「打不开」的根因是它把窗口坐标保存成了屏幕外的 -21333,-21333，每次启动都在屏幕外开窗 |
| f080 | verified | 2026-10-07 | ALL_PROXY=socks5://127.0.0.1:10808 会让 ChatGPT 桌面端界面完全渲染不出来，并让它不再响应关闭请求 |
| f081 | verified | 2026-10-07 | 本机多 AI 协同信道已建立并实测验证：DSH 与 Codex 可通过 codex exec 做双向带签名通信 |
| f082 | verified | 2026-10-07 | 本机已建成可运行的 AI 圆桌会议机制：DSH 主持并记录，Codex 经 codex exec 自动入席参与多轮讨论 |
| f085 | verified | 2026-10-07 | 桌面应用 agent 具备子智能体编排能力（collaboration.spawn_agent 等），这是 DSH 所没有的 |
| f087 | verified | 2026-10-07 | 手机在 Remote Control 中是「用完即断」的连接，因此电脑无法在手机离线时实时推送 |
| f089 | verified | 2026-10-07 | 圆桌执行器 token 优化成功：输入从约 24k 降到 1.8k tokens（-92.5%），耗时从 33 秒降到 16.8 秒 |
| f091 | verified | 2026-10-07 | 本机可用系统自带 ssh-keygen 实现 Ed25519 非对称签名，无需安装 git/openssl/gpg |
| f092 | verified | 2026-10-07 | 虎符 v3 双口令机制验证通过：左符 + 右符任一错误都无法解锁，且只知一符不可破解 |
| f093 | verified | 2026-10-07 | 虎符 v3.1 三选二门限机制验证通过：三个口令中任意两个均可解锁，且三者得到的真钥匙相同 |
| f094 | verified | 2026-10-07 | 作者名字是公开身份标识，不承担保密职责；只有私钥泄露才是严重风险 |

## 二、经验教训（lessons）

| id | 类型 | 时间 | 标题 |
|---|---|---|---|
| l002 | method | 2026-10-06 | 不要猜 API/协议行为，去读源码 |
| l003 | method | 2026-10-06 | 严格区分 已实测 / 假设 / 未验证 |
| l004 | method | 2026-10-06 | 每步只排除一个未知数 |
| l005 | method | 2026-10-06 | 不要为『技术方案』努力，要为『目标』努力 |
| l006 | pitfall | 2026-10-05 | 中文经 stdin 变乱码（PowerShell 5.1 的限制） |
| l007 | pitfall | 2026-10-06 | Reality 的 dest 不能选走 CDN 的站点 |
| l008 | pitfall | 2026-10-06 | 改系统代理后，Electron 应用必须完整重启 |
| l009 | technique | 2026-10-06 | 多个 DNS 返回完全不同的 IP = DNS 投毒 |
| l010 | technique | 2026-10-06 | 通过 SSH 传复杂脚本要用 base64，不要用嵌套引号 heredoc |
| l011 | technique | 2026-10-06 | 改系统配置的四步规范 |
| l012 | pitfall | 2026-10-06 | curl 抓 github.com 会返回整个 HTML 页面 |
| l013 | pitfall | 2026-10-06 | OCU 的三个坑 |
| l014 | technique | 2026-10-06 | 持久化 session + 无 resume 协议 = 必然的命名冲突 |
| l015 | method | 2026-10-06 | 不要在有两个未知数的方案上投入不可逆成本 |
| l016 | method | 2026-10-06 | 结构化记忆比散文文档更适合 AI 使用 |
| l017 | method | 2026-10-06 | harvest 工具本身可用 |
| l018 | method | 2026-10-06 | 经验包做成自包含文件夹 + 结构化记忆 + 自动 Skill 生成 |
| l019 | method | 2026-10-06 | 命名空间机制验证 |
| l021 | method | 2026-10-06 | 经验包升级为可成长的命名空间架构 |
| l022 | pitfall | 2026-10-06 | PowerShell 里 BinaryWriter.Write() 重载解析不可靠 |
| l023 | pitfall | 2026-10-06 | PowerShell 函数返回单元素数组会被展开成标量 |
| l024 | technique | 2026-10-06 | 虎符双因子：密钥文件 + 口令，XOR 合成主密钥 |
| l025 | pitfall | 2026-10-06 | Codex CLI 不读 Windows 系统代理，必须设环境变量 |
| l026 | technique | 2026-10-06 | Codex CLI 可用 codex exec 非交互式执行任务 |
| l027 | technique | 2026-10-06 | 卸载 Windows Store 应用的正确流程（含安全检查） |
| l028 | technique | 2026-10-06 | 经验包桌面同步机制 |
| l031 | pitfall | 2026-10-06 | Node spawn 子进程默认 stdin 是管道，会让等待 stdin 的程序卡死 |
| l032 | pitfall | 2026-10-06 | Codex 不指定模型时会自选一个 ChatGPT 账号不支持的模型 |
| l033 | technique | 2026-10-06 | 把 Codex CLI 接入 HTTP bridge，打通手机到 GPT-6 的链路 |
| l035 | technique | 2026-10-06 | 用「截图 + Codex 视觉」读取桌面版 GPT 的界面内容 |
| l036 | pitfall | 2026-10-06 | PowerShell 窗口跑到屏幕外导致「看不到」 |
| l037 | pitfall | 2026-10-06 | PowerShell 脚本含中文必须带 UTF-8 BOM |
| l038 | pitfall | 2026-10-06 | 绝不要对已运行的 GUI 应用做强制窗口操作 |
| l039 | pitfall | 2026-10-06 | 操作任何 GUI 应用前，先检查它是否已在运行 |
| l040 | technique | 2026-10-06 | 用 PrintWindow 非侵入式截取窗口内容 |
| l041 | technique | 2026-10-06 | Agents Anywhere 同步超时：云端在国内却被代理绕道日本 |
| l042 | technique | 2026-10-07 | AA runtime 卡在 starting：会话过大导致快照 ACK 超时 |
| l044 | technique | 2026-10-07 | DSH 会话文件是 zstd 多帧格式，必须逐帧解压 |
| l045 | pitfall | 2026-10-07 | AA connector 起不来：uv 下载国内 PyPI 镜像被代理绕道日本而超时 |
| l046 | pitfall | 2026-10-07 | 用 Start-Process 启动的 GUI 应用会随 pwsh 会话结束被终止 |
| l047 | pitfall | 2026-10-07 | AA connector 真正运行的是 connector-source 下的可编辑安装，不是 Programs 里的副本 |
| l048 | pitfall | 2026-10-07 | 系统代理必须做失效安全：代理开着而后端死了会让一批软件同时失效 |
| l049 | method | 2026-10-07 | 排查因果不要被时间巧合骗，必须做对照实验 |
| l050 | pitfall | 2026-10-07 | PowerShell 脚本必须存为 UTF-8 with BOM，否则中文乱码并直接导致语法错误 |
| l051 | pitfall | 2026-10-07 | edit 类工具会丢掉 .ps1 的 BOM，改完必须补回 |
| l052 | pitfall | 2026-10-07 | PowerShell 测直连必须用 curl --noproxy，Invoke-WebRequest 默认走系统代理 |
| l053 | pitfall | 2026-10-07 | 开机自启的 GUI 和服务必须等到网络真正就绪之后再启动 |
| l054 | method | 2026-10-07 | 单个会话跑到 5 天 189 轮必然反复丢上下文：应主动开新会话并用 STATE.md 续接 |
| l055 | pitfall | 2026-10-07 | 回到项目早期的根因是压缩摘要有损，对策是先读状态文件再动手 |
| l056 | technique | 2026-10-07 | DSH 会话的 interrupted 与 aborted 语义不同：interrupted 才是丢工作的那种 |
| l057 | pitfall | 2026-10-07 | 搜数据文件 0 命中不能推出「程序不会写注册表」：能力线索要搜二进制 |
| l058 | method | 2026-10-07 | 自己写下的 verified 结论被推翻时，必须主动回改并留证据链 |
| l059 | method | 2026-10-07 | 易变路径必须集中解析：一个程序一个路径，不要每个脚本各写一遍 |
| l060 | pitfall | 2026-10-07 | 改代码时的自造 bug 两大来源：引号与换行；改完必须当场回读并运行验证 |
| l061 | pitfall | 2026-10-07 | 判断替换是否命中和实际替换必须用同一个字符串 |
| l062 | method | 2026-10-07 | 判断某因素是否影响某系统时，必须确保被测路径真的被触发 |
| l063 | pitfall | 2026-10-07 | 字面量检查一律用 Contains，不要用 -match |
| l064 | pitfall | 2026-10-07 | .cmd/.bat 绝不能写 UTF-8 BOM，否则双击一闪就没 |
| l065 | method | 2026-10-07 | 给非技术用户做入口，优先 GUI 开关而不是命令行脚本 |
| l066 | pitfall | 2026-10-07 | 长命令里一处语法错误会让整条命令在解析阶段全废，什么都没执行 |
| l067 | method | 2026-10-07 | 给非技术用户做系统开关，最稳的是原生对话框（VBS/HTA），不是 PowerShell 窗口 |
| l068 | pitfall | 2026-10-07 | 用 cmd /c node |
| l069 | pitfall | 2026-10-07 | 批处理里找易变路径，优先用纯 batch 的 for /d，不要依赖 PATH 里的 powershell |
| l070 | pitfall | 2026-10-07 | PowerShell 5.1 没有 Test-Connection -TimeoutSeconds，扫描要用 ping.exe |
| l072 | pitfall | 2026-10-07 | 让手机全局走电脑代理会引入新的不稳定，用户否决；不要再主动提议这类方案 |
| l073 | technique | 2026-10-07 | Chromium/Electron 应用的界面控件无法用 UI Automation 读取，只能靠截图加人工点击 |
| l074 | pitfall | 2026-10-07 | 遇到 reserved 拒绝就停手：保留名由应用完整性机制保护，绕路等于破坏完整性 |
| l075 | technique | 2026-10-07 | Windows 代理分两层：WinINET 与 WinHTTP 独立，普通 HTTPS 通不代表 WebSocket 通 |
| l076 | technique | 2026-10-07 | Windows 应用打不开先查保存的窗口坐标，别急着判断是崩溃或网络问题 |
| l077 | pitfall | 2026-10-07 | 给 Electron 应用注入代理环境变量时不要用 ALL_PROXY，socks5:// scheme 会破坏它的网络栈 |
| l078 | pitfall | 2026-10-07 | 判断 Electron 窗口是否真的渲染出来，不能用亮度或颜色数，必须看截图 |
| l079 | pitfall | 2026-10-07 | 与 Codex 交换中文内容时，必须由 PowerShell 侧独占文件读写，且 prompt 里不能有双引号 |
| l080 | pitfall | 2026-10-07 | PowerShell Start-Job 里的重定向不使用 UTF-8，中文会被写成 GBK 乱码 |
| l081 | technique | 2026-10-07 | 做不到实时推送时，改用延迟投递到对方必定会打开的会话 |
| l082 | design | 2026-10-07 | 多 AI 协同系统必须内置「是否值得开会」的判定，否则会被会议拖垮 |
| l083 | design | 2026-10-07 | 多 AI 会议的真实缺陷：顾问只能听操作员转述，无法独立核验 |
| l084 | design | 2026-10-07 | 灾备角色的第一原则是保持干净：急救员不得参与日常操作 |
| l085 | design | 2026-10-07 | 灾备角色的权限必须分状态：常态只读保持干净，紧急态必须能动手 |
| l086 | pitfall | 2026-10-07 | jsonl 必须无 BOM，而 md/json/ps1 必须带 BOM —— 二者要求相反，混用会造成静默故障 |
| l087 | design | 2026-10-07 | 加密数据前必须先建立一份永不上锁的母版 |
| l088 | pitfall | 2026-10-07 | PowerShell 变量名不区分大小写：$p 会覆盖 $P，循环变量极易造成隐性故障 |
| l089 | pitfall | 2026-10-07 | PowerShell 里嵌套 here-string 会提前终止外层，整个脚本在解析阶段全废 |
| l090 | pitfall | 2026-10-07 | PowerShell 不支持 < 输入重定向，需要 stdin 的命令必须走 cmd /c |
| l091 | pitfall | 2026-10-07 | .cmd 启动器的中文是编码雷区，最稳的做法是全用 ASCII |
| l092 | pitfall | 2026-10-07 | 必须确认工具实际往哪个目录写数据，否则隐私会被写进对外发布的那一份 |
| l093 | design | 2026-10-07 | 名字与密钥是两件事：身份标识不承担保密职责 |
| l094 | technique | 2026-10-07 | 门限方案（三选二）的实现：多个保险箱保护同一个真钥匙，而不是用不同密钥加密不同数据 |
| l095 | design | 2026-10-07 | 加锁之前先问：这把锁打不开了，我还能拿回数据吗 |
| l096 | pitfall | 2026-10-07 | ssh-keygen 生成空口令密钥时，空字符串参数在 PowerShell 里传参失败，要用 cmd 包裹 |

## 三、决策（decisions）

| id | 时间 | 问题 | 选定 |
|---|---|---|---|
| d001 | 2026-10-06 | bridge 的 session 冲突怎么修？ | 固定 sessionId + 冲突自愈（检测 already exists → 归档冲突日志 → 重试一次，归档上限 3） |
| d002 | 2026-10-06 | 用哪种方式解决 Windows 外网？ | 阿里云轻量应用服务器（日本东京）自建 Xray |
| d003 | 2026-10-06 | 服务器规格选哪个档？ | 国际型 · 2核1G / 30G · 1个月 |
| d004 | 2026-10-06 | SSH 用密码还是密钥？ | 本地生成 ed25519 密钥，用户在远程终端粘贴一条命令装公钥 |
| d005 | 2026-10-06 | 代理协议选哪个？ | VLESS + xtls-rprx-vision + REALITY |
| d006 | 2026-10-06 | Reality 的 dest 用哪个站点？ | www.apple.com |
| d007 | 2026-10-06 | Windows 客户端用 GUI 还是 CLI？ | Xray CLI（xray.exe + config.json） |
| d008 | 2026-10-06 | 代理用系统代理还是 TUN 模式？ | 系统代理（127.0.0.1:10809） |
| d009 | 2026-10-06 | 要不要加看门狗？ | 加（计划任务每 5 分钟检查，挂了自动重启） |
| d010 | 2026-10-06 | 记忆框架用纯文本还是结构化？ | JSONL（facts/lessons/timeline/decisions 四个追加式文件）+ index.json + memory… |
| d011 | 2026-10-06 | GPT 接入走 WebMCP 还是 Codex Remote？ | 转向 Codex Remote（尚未验证） |
| d012 | 2026-10-07 | 长期项目如何避免反复丢失上下文 | 按阶段主动开新会话，并把状态外置到经验包（STATE.md + facts/lessons） |
| d013 | 2026-10-07 | 脚本里如何处理带版本号/哈希的安装路径 | 集中到 lib\resolve-paths.ps1 动态发现，调用方一律不写死 |
| d014 | 2026-10-07 | AA 后端连接是否应该走系统代理 | 永久直连（proxy=None / trust_env=False） |
| d015 | 2026-10-07 | 手机代理在电脑关机时如何自动回退 | 不实现自动回退，由用户手动切换（关机时把手机配置代理改回关闭） |

## 四、事件（timeline，倒序）

| id | 时间 | 事件 |
|---|---|---|
| t086 | 2026-10-07T12:43 | 修复工具写错目录隐患：本机隐私曾被写入发行版 |
| t087 | 2026-10-07T12:43 | 制作可发手机的经验包基础版并完成隐私核查 |
| t083 | 2026-10-07T12:43 | 建立虎符 v2：作者签名体系（Ed25519） |
| t084 | 2026-10-07T12:43 | 建立虎符 v3/v3.1：双口令与三选二门限 |
| t085 | 2026-10-07T12:43 | 建立三层架构：工作母版 / 备份母版 / 发行版 |
| t082 | 2026-10-07T11:37 | 裁定桌面 Codex agent 担任技术顾问与独立审查者，不参与共同操作；明确 A/B 权限交替为互为备份而非同时开启 |
| t080 | 2026-10-07T10:04 | 修复 ChatGPT 桌面端 Remote Control 无法启用：注入代理环境变量使 WebSocket 经东京节点连通 |
| t079 | 2026-10-07T09:52 | 查明 computer use 未接入的根因：应用自带的 openai-bundled 插件市场从未注册，且该市场为保留名无法外部注册 |
| t078 | 2026-10-07T09:32 | 查清 ChatGPT 桌面版「了解并操控电脑」的官方设置路径，以及远程控制被 UAC 关闭所阻断 |
| t077 | 2026-10-07T09:16 | 手机经电脑代理的方案被用户否决并已完整回退 |
| t075 | 2026-10-07T08:52 | 为 Codex 建立两个桌面入口（应用 + 命令行），并确认 Codex 已登录可用 |
| t074 | 2026-10-07T08:43 | 把网络切换重做为窗口式开关；查明旧 .cmd 点不开的原因（UTF-8 BOM） |
| t073 | 2026-10-07T08:35 | 定位并根治 AA 反复失效：connector 强制走系统代理；同时建立一键网络切换 |
| t072 | 2026-10-07T08:22 | 病根审计收尾：清除最后两处易变路径硬编码，确认全机零病根 |
| t071 | 2026-10-07T08:22 | 修复易变路径病根：建立统一解析器，修好 5 个失效脚本，并验证电脑端 AI 读桌面版 GPT 的通道 |
| t070 | 2026-10-07T08:13 | 自我纠错：推翻 f040（ai-manager 不改系统代理），并记录 ProxyEnable 被未知方置 0 的异常 |
| t069 | 2026-10-07T08:12 | 回溯完成：还原了主会话 5 天 189 轮的完整中断史，定位真正被强行终止的点 |
| t068 | 2026-10-07T08:08 | 禁用千问更新器（每小时弹控制台窗口的真凶） |
| t066 | 2026-10-07T08:08 | 开机事故定位：AA 与千问失效，排除 Xray 误因，确认真凶为开机时序竞态 + 死代理陷阱 |
| t067 | 2026-10-07T08:08 | 实施失效安全开机自检 boot-ai.ps1 并注册到启动文件夹 |
| t065 | 2026-10-07T00:44 | 固化经验: AA connector 真正运行的是 connector-source 下的可编辑安装，不是 Programs 里的副本 |
| t063 | 2026-10-07T00:44 | 固化经验: AA connector 起不来：uv 下载国内 PyPI 镜像被代理绕道日本而超时 |
| t064 | 2026-10-07T00:44 | 固化经验: 用 Start-Process 启动的 GUI 应用会随 pwsh 会话结束被终止 |
| t061 | 2026-10-07T00:03 | 固化经验: 不要直接编辑 DSH 运行时持有的状态文件 |
| t062 | 2026-10-07T00:03 | 固化经验: DSH 会话文件是 zstd 多帧格式，必须逐帧解压 |
| t060 | 2026-10-07T00:03 | 固化经验: AA runtime 卡在 starting：会话过大导致快照 ACK 超时 |
| t059 | 2026-10-06T23:53 | 固化经验: Agents Anywhere 同步超时：云端在国内却被代理绕道日本 |
| t058 | 2026-10-06T20:48 | 固化经验: 用 PrintWindow 非侵入式截取窗口内容 |
| t057 | 2026-10-06T20:48 | 固化经验: 操作任何 GUI 应用前，先检查它是否已在运行 |
| t056 | 2026-10-06T20:48 | 固化经验: 绝不要对已运行的 GUI 应用做强制窗口操作 |
| t054 | 2026-10-06T20:14 | 固化经验: PowerShell 窗口跑到屏幕外导致「看不到」 |
| t055 | 2026-10-06T20:14 | 固化经验: PowerShell 脚本含中文必须带 UTF-8 BOM |
| t053 | 2026-10-06T20:14 | 固化经验: 用「截图 + Codex 视觉」读取桌面版 GPT 的界面内容 |
| t052 | 2026-10-06T19:59 | 固化经验: 手机 ChatGPT 无法访问电脑局域网地址（探针实验证实） |
| t050 | 2026-10-06T19:23 | 固化经验: Codex 不指定模型时会自选一个 ChatGPT 账号不支持的模型 |
| t051 | 2026-10-06T19:23 | 固化经验: 把 Codex CLI 接入 HTTP bridge，打通手机到 GPT-6 的链路 |
| t049 | 2026-10-06T19:23 | 固化经验: Node spawn 子进程默认 stdin 是管道，会让等待 stdin 的程序卡死 |
| t048 | 2026-10-06T19:23 | 固化经验: 在 JS 字符串里写 Windows 路径会被转义序列吃掉 |
| t046 | 2026-10-06T18:55 | 固化经验: 经验包桌面同步机制 |
| t045 | 2026-10-06T18:47 | 固化经验: 卸载 Windows Store 应用的正确流程（含安全检查） |
| t043 | 2026-10-06T18:30 | 固化经验: Codex CLI 不读 Windows 系统代理，必须设环境变量 |
| t044 | 2026-10-06T18:30 | 固化经验: Codex CLI 可用 codex exec 非交互式执行任务 |
| t041 | 2026-10-06T09:59 | 固化经验: PowerShell 函数返回单元素数组会被展开成标量 |
| t042 | 2026-10-06T09:59 | 固化经验: 虎符双因子：密钥文件 + 口令，XOR 合成主密钥 |
| t040 | 2026-10-06T09:58 | 固化经验: PowerShell 里 BinaryWriter.Write() 重载解析不可靠 |
| t032 | 2026-10-06T09:55 | 当前状态：等待用户登录 ChatGPT Desktop |
| t039 | 2026-10-06T09:51 | 固化经验: 经验包升级为可成长的命名空间架构 |
| t037 | 2026-10-06T09:50 | 固化经验: 命名空间机制验证 |
| t031 | 2026-10-06T09:50 | ★ 建立长期记忆框架 |
| t036 | 2026-10-06T09:45 | 固化经验: 经验包做成自包含文件夹 + 结构化记忆 + 自动 Skill 生成 |
| t035 | 2026-10-06T09:43 | 生成 Skill: harvest-experience |
| t034 | 2026-10-06T09:43 | 固化经验: harvest 工具本身可用 |
| t033 | 2026-10-06T09:39 | 测试追加机制 |
| t029 | 2026-10-06T09:35 | 配置看门狗计划任务 |
| t030 | 2026-10-06T09:33 | 建立经验包三件套 |
| t028 | 2026-10-06T09:30 | 自启脚本可靠性测试通过 |
| t026 | 2026-10-06T09:29 | 登录端点预验证全通 |
| t027 | 2026-10-06T09:29 | 配置备份 |
| t025 | 2026-10-06T08:52 | 配置开机自启计划任务 |
| t024 | 2026-10-06T08:50 | ★ ChatGPT Desktop 恢复正常 |
| t023 | 2026-10-06T08:49 | Edge 验证代理成功 |
| t022 | 2026-10-06T08:48 | 配置 Windows 系统代理 |
| t021 | 2026-10-06T08:47 | ★ 换成 www.apple.com 后成功 |
| t020 | 2026-10-06T08:45 | ★ Reality 握手失败（第一次） |
| t019 | 2026-10-06T08:44 | Windows 客户端下载并配置 |
| t018 | 2026-10-06T08:43 | 服务端 VLESS+Reality 配置完成 |
| t017 | 2026-10-06T08:42 | 服务器安装 Xray 26.3.27 |
| t016 | 2026-10-06T08:41 | SSH 密钥安装成功 |
| t015 | 2026-10-06T08:40 | ★ 用户购买阿里云服务器 |
| t014 | 2026-10-06T07:39 | bridge.js 加入冲突自愈（1 处改动） |
| t013 | 2026-10-06T07:32 | 零改动恢复 8787/8788 |
| t012 | 2026-10-06T07:31 | 定位 bridge session 冲突根因 |
| t011 | 2026-10-06T07:30 | 发现 8787/8788/59339 全部停止 |
| t010 | 2026-10-05T19:26 | ChatGPT Desktop 装好但黑屏 |
| t009 | 2026-10-05T19:20 | 诊断出 chatgpt.com DNS 投毒 |
| t008 | 2026-10-05T18:29 | 手机端 4 次端到端实测全通 |
| t004 | 2026-10-05T09:59 | mobile-client 建成 |
| t003 | 2026-10-05T09:40 | bridge.js 建成 |

---

*本文件是导航索引。正文在 `facts.jsonl` / `lessons.jsonl` / `decisions.jsonl` / `timeline.jsonl`。*
