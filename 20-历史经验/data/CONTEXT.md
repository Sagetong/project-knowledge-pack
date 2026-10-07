【项目记忆简报 · 由 DSH 记忆框架自动生成】
生成时间: 2026-10-07 17:36:41

== 一、已验证的事实 ==
  [f002] 中文 UTF-8 在全链路正常，无乱码
        证据: 输入 45 字节（15 汉字），返回 18 字符正常
  [f003] DeepSeek 能真实执行 Windows 命令
        证据: pwsh Get-Location → <项目盘>，isError=false
  [f004] 多轮上下文连续
        证据: 跨轮记住口令「紫色鲸鱼-8899」
  [f007] chatgpt.com 被 DNS 投毒
        证据: 5 个不同 DNS 返回 5 个完全不同的无关 IP（Facebook/Linode/Verizon 段）
  [f008] ChatGPT Desktop 黑屏的直接原因是网络不通
        证据: 日志 116 处 net::ERR_CONNECTION_TIMED_OUT；重试 315 次
  [f009] DSH SDK 的 session 表是纯内存，协议无 open/resume 方法
        证据: 读源码 dsh-sdk-jsonrpc-server/lib/index.js：sessions = new Map()；官方 README 只列 initialize/session/prompt/shutdown
  [f010] bridge 的 session 冲突可通过冲突自愈解决
        证据: 连续重启 2 次均通过；归档目录正好 3 个（裁剪生效）
  [f011] 阿里云日本东京服务器的 IP 没有被 OpenAI 封
        证据: 服务器侧 api.openai.com → HTTP 401 {"error":"Missing bearer authentication"}（正常认证错误）
  [f012] Reality 的 dest 用 www.microsoft.com 会握手失败
        证据: 服务端日志 REALITY: processed invalid connection ... handshake did not complete successfully；换成 www.apple.com 后立刻成功
  [f013] Xray VLESS+Reality+Vision 工作正常
        证据: 服务端日志 proxy: Xtls Unpadding new block；客户端 api.openai.com → 401
  [f014] ChatGPT Desktop 在代理下恢复正常，显示登录界面
        证据: Established=19, SynSent=0，截图确认登录界面
  [f015] 登录所需端点经代理全部可达
        证据: chatgpt.com 403 / auth.openai.com 403 / auth0.openai.com 302 / api.openai.com 401 等 9 个端点全部有响应
  [f016] 代理连续稳定性 6/6
        证据: 连续 6 次请求 api.openai.com 全部 401
  [f017] iPhone 无法提供热点供网
        证据: 无 SIM 卡 → 无蜂窝数据 → 个人热点不可用（用户确认）
  [f018] ChatGPT 个人账号（Free/Go/Plus/Pro）禁止创建 Custom GPT
        证据: OpenAI 官方 ChatGPT Free Tier FAQ
  [f019] MCP Apps 移动端不支持（web only）
        证据: OpenAI 官方 Developer mode & MCP apps 文档
  [f026] memory.ps1 的追加功能可用
        证据: 追加一条后重新读取，记录数 +1
  [f028] 能给电脑下指令的永远是你设备上的程序，不是 GPT 模型本身
        证据: 同一时刻：手机浏览器请求被记录（EdgiOS UA），手机 ChatGPT 请求未被记录。GPT 住在云端，手里没有到你局域网的通道
  [f030] 桌面版 ChatGPT 已在本地登录，且能看到与手机版同步的对话历史
        证据: 窗口截图显示左侧 Recents 有 11 条对话（长期投资策略/爱情/AI成长伙伴建议等），右上角有 Chat/Work 标签
  [f031] Codex (GPT-6) 具备视觉能力，能通过 codex exec -i <图片> 读取界面截图内容
        证据: 传入 ChatGPT 窗口截图，19.3 秒内准确读出全部 11 条对话标题，与人工肉眼所见完全一致
  [f032] AA 的云端在国内（115.190.133.236 / 115.191.44.x / 116.205.40.x），必须绕过代理直连
        证据: 直连 0.14-0.22 秒；经日本代理 1.29-3.03 秒（慢 8-15 倍）。加入绕过列表 + 重启 Xray 后，AA 转为直连，sync.ack 70 次零失败，队列清空
  [f033] DSH 会话文件 session.v4.jsonl.zstd 是 zstd 多帧格式，当前主会话解压后达 46MB（7906 帧）
        证据: 用 Node 逐帧解压统计：总帧 7906，总行 12787，46.09MB，其中 assistant/message 34.52MB×1934 条占 75%，无重复内容
  [f034] AA runtime 从 starting 变为 ready 的条件是「首次会话清单成功提交到平台」
        证据: 00:32:30 snapshot.started → 00:41:35 sync.inventory_completed → snapshot.completed=1 → runtime_unavailable 停止报告，AA 恢复可用
  [f035] 系统代理是单点故障：ProxyEnable=1 指向 127.0.0.1:10809 而 Xray 未运行时，所有走代理的程序全部失败
        证据: 停掉 Xray 后 curl -x http://127.0.0.1:10809 退出码=7（连不上代理），chatgpt.com 返回 000；同时直连 curl --noproxy 正常。代理开着但后端死了 = 死代理陷阱
  [f037] 2026-10-07 开机后 AA 连续失败 367 次（07:19-07:50），错误只有两种：getaddrinfo failed 与 All connection attempts failed
        证据: connector 日志逐行统计：07:19:09 启动，07:50:43 最后一次失败，07:50:47 连上。Errno 11004 = WSAHOST_NOT_FOUND 即 DNS 解析失败
  [f038] Xray 配置无 DNS 段、无 TUN 适配器，只监听本机 10808/10809，因此不可能影响系统 DNS
        证据: config.json 只有两个 socks/http 入站 + 一个 vless reality 出站；Get-NetAdapter 无 wintun/tap；Get-Service 无 Xray 服务。故 getaddrinfo failed 与 Xray 无关
  [f039] 千问更新器在计划任务与 HKCU Run 两处注册，触发器含重复间隔 PT1H，每小时弹一次控制台窗口
        证据: 任务 QianwenUpdaterTaskUser1.0.0.10 触发器 = Logon + Daily 且 Repetition.Interval=PT1H；动作 updater.exe --wake --enable-logging --vmodule=...，--enable-logging 即黑框来源
  [f041] 主会话从 2026-10-02 13:49 连续运行到 10-07，共 189 轮、5 天，期间被压缩 7 次、非正常结束 14 次
        证据: 用 tail-session.js/timeline-session.js 解析 session.v4.jsonl.zstd（15.17MB，8609 个 zstd 帧，解压 54.91MB，13917 行）：turn/end 共 188 条，其中 error 4 / interrupted 4 / aborted-user 6；compaction/summary 7 次
  [f042] 4 次 interrupted 是真正丢失工作的强行终止，每次都紧跟着 session/end-seed
        证据: turn 21(10-02 16:00 电脑关机) / turn 61(10-03 18:25) / turn 127(10-05 21:37 整夜断开) / turn 170(10-06 21:02 DSH 挂死，用户 23:35 问还能思考吗)。四者之后都出现 session/end-seed 记录
  [f043] 7 次上下文压缩的时间点，最后一次(10-07 07:50:05-07:50:31)立即早于 AA 恢复在线(07:50:47)约 22 秒
        证据: compaction/summary 时间：10-03 14:47 / 10-03 20:30 / 10-05 07:42 / 10-05 19:57 / 10-06 09:49 / 10-06 23:55 / 10-07 07:50。最后这次的 22 秒间隔与Xray
  [f046] 2026-10-07 08:02:43 到 08:13:09 之间，ProxyEnable 在无我方操作的情况下从 1 变成 0
        证据: 08:02:43 boot-ai.ps1 运行结束并复核 ProxyEnable=1（boot-ai.log 与终检输出均有记录）；08:13:09 复查变为 0，而 10809 仍在监听（不一致状态）。期间我只做了经验包写入与会话解析，未触碰注册表。已手工恢复为 1。存在未知写入者，尚未定位
  [f047] ProxyEnable 被意外置 0 的后果是安全的：等价于失效安全的降级态，不会造成死代理
        证据: 代理关闭时所有流量直连。实测停 Xray 且 ProxyEnable=0 时，dashscope.aliyuncs.com 返回 404、agents-anywhere.com 返回 200，常规上网正常。代价仅是需要翻墙的软件（Codex）暂不可用，重新开启或重跑 boot-ai.ps1 即可
  [f048] Codex 安装目录是带哈希的易变目录，升级即变；曾有 5 个脚本写死旧的 f544b3844e0f14e9，导致 delegate.ps1 调 Codex 完全不通
        证据: 实存目录为 5ea220ae823df3d7（codex.exe 311.7MB），旧目录已不存在。受影响：delegate.ps1 / read-desktop-gpt.ps1 / vpn\codex-cli.cmd / codex-with-proxy.cmd / codex-remote-start.cmd。修复后 delegate.ps1 -To codex 实测 9.3 秒返回「正常」
  [f049] 电脑端 AI（Codex GPT-6 视觉）能准确读取桌面版 ChatGPT 截图上的文字内容
        证据: 对 screen\desktop-gpt-20261006-201537.png 实测：Codex 8.0 秒读出左侧全部 11 个对话标题（长期投资策略（延续）等）、界面元素、主区域文字，与人工逐字核对完全一致。此前 20:28 那张 58.7KB 的截图因窗口黑屏而无文字，Codex 如实回答「无可见文字」而非编造
  [f050] 本机 pwsh 工具会话的 PowerShell 执行策略是 Restricted，dot-source .ps1 会抛 PSSecurityException
        证据: Get-ExecutionPolicy 返回 Restricted；. resolve-paths.ps1 报「在此系统上禁止运行脚本」。因此调用脚本必须显式 -ExecutionPolicy Bypass；脚本内部 dot-source 也需要调用方已 Bypass，否则会静默失败导致变量为空
  [f051] 系统代理被意外置 0 的后果是安全的降级态，不会造成死代理
        证据: ProxyEnable=0 时全部流量直连；实测 dashscope.aliyuncs.com 返回 404、agents-anywhere.com 返回 200，常规上网正常。代价仅是需要翻墙的软件暂不可用，重跑 boot-ai.ps1 即可恢复
  [f052] AA connector 原本强制把后端连接走系统代理，这是死代理时 AA 整体失效的真正原因
        证据: client.py:258 websockets.connect(proxy=None if is_loopback_url(...) else True)，websockets 17.2 的 proxy 默认值就是 True（读环境/系统代理）；client.py:516 httpx.AsyncClient(trust_env=...)；terminal_relay.py:63 同样写法。AA 后端 web.agents-anywhere.com 是国内 IP（115.191.78.81），本应直连。用户关闭 Xray 后立即报 ConnectorNetworkError(All connection attempts failed)，重开 Xray 即恢复
  [f053] 已把 AA connector 改为永久直连，AA 从此不受 Xray 开关影响
        证据: 两个 connector-source 副本（818a5857a408385b / dc1d99ba46b29fdb）的 client.py 与 terminal_relay.py 均改为 proxy=None / trust_env=False，py_compile 通过，备份在 _archive\\AA强制直连修复-20261007。重启 AA 后 connector 进程启动时间(08:31:03)晚于文件修改时间(08:30:31)，确认加载新代码。实测：切到国内直连后 AA 日志 60 秒 0 行新增、0 条连接错误（修复前每 3 秒报一次）
  [f054] AA 恢复可用的判定信号是插件日志出现 sync.inventory_completed
        证据: 插件日志 ~\\.agents-anywhere\\dsh-bridge-next\\logs\\dsh-runtime.jsonl 出现 inventory.completed(candidates:41 visible:37) 与 sync.inventory_completed(sessions:37)，随后 sync.batch/sync.ack 每约 50ms 一组成对成功。8244 行日志仅 1 条 warn（人为杀 connector 导致的 ECONNRESET）
  [f055] DSH 的 workspace.json 结构是 tables.workspaces.<id>.sessionIds，不是顶层 sessionIds
        证据: 文件真实内容含 global.workspaceIds 与 tables.workspaces.<uuid>.sessionIds（登记 12 个会话）。我用 $j.sessionIds 读顶层得到 null，误判为登记的会话是空的、目录缺失，差点报出一个不存在的问题
  [f056] 网络代理已在桌面提供窗口式一键开关，内置死代理告警与手机通道自愈
        证据: autostart\网络开关.ps1（PowerShell WinForms 自包含，不 dot-source 任何外部文件，不受执行策略影响）+ 桌面 网络代理开关.lnk（直连 powershell -WindowStyle Hidden）。已用 EnumWindows 实测能从快捷方式打开窗口；-SelfTest 返回 SELFTEST_OK。窗口功能：日本代理/国内直连一键切换、死代理显示红色告警、显示出口 IP、自动检测并修复 8787/8788
  [f057] 旧的可执行入口 网络切换.cmd 因带 UTF-8 BOM 而完全无法运行
        证据: 读取文件头确认前三字节为 EF BB BF。cmd.exe 会把 BOM 当作命令的一部分，启动即失败，表现为窗口一闪而过。已从桌面移出并归档到 _archive\废弃入口-20261007，改用 .lnk 直连 powershell
  [f058] 桌面「网络代理」入口改为 VBS 原生对话框：显示现状、三选一、再显示结果，全程无命令行窗口
        证据: autostart\网络代理.vbs（UTF-16LE with BOM，头两字节 FF FE）实测可执行并写出日志「打开面板，当前=异常：代理开着，但 Xray 没在跑」。状态判定用 WMI 查 xray.exe 进程 + RegRead 读 ProxyEnable，切换用 RegWrite + WshShell.Run(隐藏窗口)。桌面 网络代理.lnk 指向 wscript.exe 并带网络图标
  [f059] 本机「ChatGPT」和「Codex」是同一个桌面应用：Appx 包名为 OpenAI.Codex，程序文件叫 ChatGPT.exe
        证据: Get-AppxPackage -Name OpenAI.Codex 返回安装位置 C:\Program Files\WindowsApps\OpenAI.Codex_26.930.7945.0_x64__2p2nqsd0c76g0，其 app\ChatGPT.exe 存在；当前 13 个 ChatGPT 进程都指向该路径。AppUserModelId = OpenAI.Codex_2p2nqsd0c76g0!App，桌面入口用 explorer.exe shell:AppsFolder\<AppID> 即可启动。另有独立命令行 codex.exe 于 %LOCALAPPDATA%\OpenAI\Codex\bin\<hash>" -Tags codex,chatgpt,desktop-app,verified
  [f060] Codex CLI 已登录并可用，实测 codex exec 6.5 秒返回正确结果
        证据: codex-cli 0.160.1；codex exec 返回「可以用」，tokens used 6728，model gpt-6-luna。auth.json 存在含 tokens 段（08:49:44 刚更新）。前提是设置 HTTP_PROXY/HTTPS_PROXY 指向 127.0.0.1:10809，因为 Codex 不读 Windows 系统代理
  [f061] 阿里云东京服务器不是手机缓慢的原因：负载 0.08、内存可用 436MB、Xray 稳定运行 24 小时、443 端口 35 个连接
        证据: SSH 上机实测：uptime load average 0.08/0.02/0.01；free -m 显示 890MB 总量、可用 436MB；无 swap 但也没用满；systemctl is-active xray = active，已运行 24h；ss 统计 443 已建立连接 35 条。结论：瓶颈不在这台 2 核 1G 的机器
  [f062] 电脑到 ChatGPT 的链路很快（首字节约 0.3 秒），手机慢是因为走了另一条差的路
        证据: 经 127.0.0.1:10809 实测：chatgpt.com 403 总耗时 0.287s（首字节 0.286s）；api.openai.com 421 总耗时 0.365s。手机端表现为回复极慢、会话列表五六分钟才刷新，属于典型的链路质量差
  [f063] 已把电脑做成手机的局域网代理：Xray 新增 0.0.0.0:10810 带密码的 http 入站，并加防火墙规则仅放行本地子网
        证据: config.json 新增 protocol=http listen=0.0.0.0 port=10810 settings.accounts=[{user:phone}]，原有 127.0.0.1:10808/10809 未改动；xray -test 报 Configuration OK；实测 LAN 经 10810 带密码 → HTTP 200 / 0.52s，不带密码 → HTTP 000（被拒），本机经 10809 → HTTP 200。防火墙规则 Xray LAN Proxy (phone only)，RemoteAddress=LocalSubnet。备份 config.json.bak-20261007-090416
  [f065] Xray 已配置国内外分流：国内域名/IP 走 direct 出站，其余走东京 vless，因此手机全局挂代理也不会让国内 App 变慢
        证据: config.json 增加 freedom 出站(tag=direct)与 routing(domainStrategy=IPIfNonMatch)，规则为 geosite:cn/geosite:private 与 geoip:cn/geoip:private -> direct。xray -test 报 Configuration OK。实测电脑与手机两条路径：google.com 均 HTTP 200 且出口 47.79.39.225（东京）；myip.ipip.net 均返回「39.187.237.19 中国 浙江 金华 移动」（家宽直连）。备份 config.json.bak-20261007-090905
  [f068] ChatGPT 桌面版「让 AI 操控电脑」的官方开关在 设置 → 常规 → 权限 → 完整访问权限（与 默认权限 二选一）
        证据: 对窗口做非侵入 PrintWindow 截图后读到：设置-个人-常规 页面下有「权限」分区，含两张卡片：默认权限（ChatGPT 可以读取和编辑其工作空间中的文件）与完整访问权限（无需你的批准即可编辑你电脑上的文件、运行访问网络的命令，并提示会显著增加数据丢失、泄露或意外行为的风险）。另有「无项目任务文件夹」设置项
  [f069] Codex/ChatGPT 桌面版的相关能力开关现状：computer_use 已开、node_repl 已启用、browser_use 已开；cua_repl 被禁用
        证据: codex features list 显示 computer_use=stable/true、browser_use=stable/true、browser_use_external=true、browser_use_full_cdp_access=true、in_app_local_automation=true、in_app_browser=true、multi_agent=true；而 remote_control 标记为 removed/false（功能标志已被官方移除，但 CLI 子命令仍在）。codex mcp list 显示 node_repl=enabled、cua_repl=disabled
  [f070] Codex 的 computer use 由 ChatGPT 桌面应用托管：应用在满足条件时才把 cua_repl 的 MCP 配置写入并启用，用户无需手填参数
        证据: 读取 @oai/cua-repl/README.md 原文：Codex Desktop 的 unified-computer-use 插件指向已安装的 bin；Desktop 会把 @oai/cua-repl/plugin 复制过去，并把 plugin/.mcp.template.json 改名为 .mcp.json（插件加载器要求的文件名）后填入 Node 可执行文件与包 bin 路径，然后启用。打包的模板是 disabled 且无启动参数。实际状态：plugin 目录下只有 .mcp.template.json 与 .codex-plugin/plugin.json，没有 .mcp.json，证实应用尚未生成它；config.toml 里 cua_repl 是一段残缺占位（command=ChatGPT.exe、enabled=false、无 args 无 env）
  [f071] cua_repl 启动必需环境变量 CUA_REPL_ENABLED_SURFACES，缺失即启动失败，这正是 codex doctor 报的 MCP 配置问题
        证据: README 原文：The launcher accepts the normal NodeREPL environment plus: CUA_REPL_NODE_REPL_PATH（NodeREPL 可执行文件绝对路径）、CUA_REPL_ENABLED_SURFACES（必需，取值 browser / computer / browser,computer，缺失或非法值导致启动失败）、CUA_REPL_BROWSER_ENV（可选）。codex doctor 输出 ⚠ mcp MCP configuration has optional issues - Set the missing MCP env vars or disable the affected server
  [f072] computer use 的底层通道已在运行，只差 MCP 注册这一步
        证据: 命名管道 \\.\pipe\codex-computer-use-<会话标识> 存在（与 config.toml 中 node_repl 的 SKY_CUA_NATIVE_PIPE_DIRECTORY 一致）；codex-computer-use.exe (1514.8KB) 与 @oai/cua、@oai/sky 运行时齐全；notify 钩子已指向 codex-computer-use.exe turn-ended。但 codex exec 询问时模型明确回答「没有，我当前没有读取屏幕或控制鼠标、键盘的 computer use 工具」，其工具清单里也无相关项
  [f073] 本机 ChatGPT 权限状态：permissionStatus=not-requested，当前生效的权限档是 :workspace（仅工作空间），尚未授予完整访问权限
        证据: .codex-global-state.json 中 electron-persisted-atom-state.electron:conversational-onboarding-workflow.permissionStatus = not-requested；heartbeat-thread-permissions-by-id.<threadId>.activePermissionProfile.id = :workspace；同组 sandboxPolicy.type = workspaceWrite、networkAccess = False、approvalPolicy = on-request、approvalsReviewer = user。另有 composer-permission-mode-visibility = True，说明对话输入区存在权限模式选择入口
  [f074] computer use 的插件随 ChatGPT 桌面版一起打包，但本机应用从未注册它自带的 openai-bundled 市场，因此插件始终没被安装
        证据: 应用包内 app\resources\plugins\openai-bundled\.agents\plugins\marketplace.json 定义市场 name=openai-bundled，含 9 个插件：codex-app-tools, browser, unified-computer-use, chrome, computer-use, latex, code-review, deep-research, visualize；.bundle-id=<会话标识>。但 config.toml 只注册了 marketplaces.openai-primary-runtime，没有 openai-bundled；plugin marketplace list 只有 openai-primary-runtime 与 openai-curated 两项；plugins\cache 下无 openai-bundled 目录；.codex-global-state.json 中完全没有 openai-bundled 字样
  [f075] openai-bundled 是保留市场名，外部命令无法注册，只能由应用自身注册
        证据: 执行 codex plugin marketplace add 指向应用包内该目录，返回 Error: marketplace openai-bundled is reserved and cannot be added from this source。随后 codex plugin add computer-use@openai-bundled 与 unified-computer-use@openai-bundled 均返回 plugin was not found。执行前后 config.toml 哈希一致、已注册市场仍为 2 个，未产生任何改动
  [f076] computer-use 插件确认就是让 ChatGPT 操控 Windows 电脑的官方功能，unified-computer-use 提供 cua_repl 服务
        证据: computer-use 的 plugin.json：version=26.930.61225，description 为 Control desktop apps on Windows from ChatGPT through Computer Use，interface.displayName 为 Computer Use，shortDescription 为 Control Windows apps，longDescription 说明可用任何应用与浏览器、可能截屏、用户可选择允许哪些应用、可随时停止、可选择是否用于训练；并带 skills/computer-use/SKILL.md 与 docs 下 api/confirmations/guidance 三份文档。unified-computer-use 的 .mcp.json 定义 cua_repl：command=node, args=[], enabled=false, enabled_tools=[js,js_reset,turn_ended], startup_timeout_sec=120，与 config.toml 中占位段对应
  [f077] ChatGPT 桌面端 Remote Control 无法启用的根因是 WebSocket 直连被污染 DNS 与封锁卡死，注入代理环境变量后恢复
        证据: 日志证据：remote_control websocket 反复报 failed to connect ... wss://chatgpt.com/backend-api/wham/remote/control/server，error=IO error ... (os error 10060) TCP 超时，同时 has_enrollment=true 且已有 server_id 与 environment_id，说明配对本身成功。对照测试：直连该端点 20 秒超时退出码 28；经 127.0.0.1:10809 代理 0.57 秒返回 426，WebSocket 升级握手经代理得到 HTTP 400 且响应体为 Missing required websocket headers，端点健康。DNS 证据：chatgpt.com 解析为 157.240.10.32、31.13.94.49（均为 Meta 段），直连 443 超时 6012ms。代理分层证据：WinHTTP 为 Direct access (no proxy server)，WinINET 为 ProxyEnable=1 且 127.0.0.1:10809，故普通 HTTPS 走 WinINET 能通而 WebSocket 直连失败。修复：写入 User 级 HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/NO_PROXY 并广播 WM_SETTINGCHANGE，重启应用。修复后日志：status changed Connecting -> Connected，connected to app-server remote control websocket，响应头 cf-ray 结尾 -NRT（东京），重启后 10060 出现 0 次
  [f078] ChatGPT 桌面端「打不开」的根因是它把窗口坐标保存成了屏幕外的 -21333,-21333，每次启动都在屏幕外开窗
        证据: .codex-global-state.json 中原值为 electron-main-window-bounds:{x:-21333,y:-21333,width:480,height:600,isMaximized:false}，与 GetWindowRect 读到的 (-21333,-21333) 158x26 完全一致，且 IsIconic 为 True。修复方式：先用 ShowWindow(SW_RESTORE) 加 MoveWindow 把窗口搬到 (120,70) 1380x900 并置前，再优雅关闭应用让它把正确坐标写回；关闭后文件内容变为 {x:120,y:70,width:1380,height:900,isMaximized:false}，重启后 GetWindowRect 得到 (120,70) 1380x900 且在屏幕内
  [f080] ALL_PROXY=socks5://127.0.0.1:10808 会让 ChatGPT 桌面端界面完全渲染不出来，并让它不再响应关闭请求
        证据: 10:03 写入含 ALL_PROXY=socks5:// 的四个 User 级代理变量后，应用出现两种症状：窗口只有深色背景与右下角 logo，界面元素全部缺失（窗口区域非背景像素仅 7.7%）；且 CloseMainWindow 返回后在 24 秒内 8 个进程一个都不退出，Windows 事件日志出现 Application Hang 与 MoAppHang。10:16 删除 ALL_PROXY 并把 NO_PROXY 里的通配符去掉、仅保留 HTTP_PROXY 与 HTTPS_PROXY 后：CloseMainWindow 返回 True 且进程正常退出，界面在约 70 秒内渲染完成（非背景像素升到 67-69%），截图确认侧边栏与历史对话全部为中文。整个过程 Remote Control 始终保持 Connected（10:15:56 Connecting -> Connected）
  [f081] 本机多 AI 协同信道已建立并实测验证：DSH 与 Codex 可通过 codex exec 做双向带签名通信
        证据: 信道位于 <信道目录>\（README.md 协议 / state.md 事实快照 / channel.md 主信道）。DSH 发出 MSG 0001（FROM: DSH, TO: CODEX），Codex 经 codex exec 回复 MSG 0002 并自签 FROM: CODEX / TO: DSH，确认收到。Codex 自述：身份为桌面 Codex agent，工具含 exec_command/web/文件查看，权限档为 read-only 文件系统 + 网络受限 + 审批 never，不能写文件，且没有 read_thread 工具
  [f082] 本机已建成可运行的 AI 圆桌会议机制：DSH 主持并记录，Codex 经 codex exec 自动入席参与多轮讨论
        证据: 执行器 <信道目录>\roundtable.ps1，实测 2 轮 31 秒完成，输出 roundtable-<时间戳>.md 并广播到 channel.md。实测中文正常（1161 个汉字、0 个乱码字符）。Codex 在两轮中给出独立判断，包括同意分工、反对宣称三方闭环已实现、反对把定时读队列当闭环方案、建议做带唯一标记的最小端到端验证，并指出信道存在重复 ID 与截断回复等缺陷
  [f085] 桌面应用 agent 具备子智能体编排能力（collaboration.spawn_agent 等），这是 DSH 所没有的
        证据: 同一份工具清单中含 collaboration.followup_task、collaboration.interrupt_agent、collaboration.list_agents、collaboration.send_message、collaboration.spawn_agent、collaboration.wait_agent，另有 functions.create_goal、functions.update_goal、functions.view_image、web.run。DSH 侧不具备 spawn_agent 这类子智能体编排工具。因此若要它当指挥官，合理理由是编排能力而非掌握聊天历史
  [f087] 手机在 Remote Control 中是「用完即断」的连接，因此电脑无法在手机离线时实时推送
        证据: 实测：11:20 时事件送达连接数出现 2（手机在线）；到 11:22 再查 ConnectionId 分布，手机对应的 ConnectionId(2) 已完全消失，只剩 ConnectionId(0) 本机 UI、ConnectionId(3) 后端通知、ConnectionId(5) 新增（DSH 的 codex queue）。说明手机的远程会话不是常驻连接。因此实时推送不可行，只能采用「写入会话、下次打开可见」的延迟投递
  [f089] 圆桌执行器 token 优化成功：输入从约 24k 降到 1.8k tokens（-92.5%），耗时从 33 秒降到 16.8 秒
        证据: 优化前每场 2 轮的 prompt 含全量 state.md（11.3KB≈7.5k tokens）+ channel.md 尾部 6000 字符（≈4k tokens）+ 上一轮全文，合计约 24k tokens。优化手段：① 用 context-digest.md（1546B≈1k tokens，压缩到 state.md 的 14%）替代全量 state.md；② 第 2 轮只带上一轮 300 字摘要，不重传全文；③ 默认不携带 channel 尾部（可用 -WithHistory 开启）；④ 强制顾问发言限 300-400 字；⑤ 输出超 1200 字符硬截断。实测 v2 单场：第 1 轮 prompt 1202 字符≈0.8k tokens、第 2 轮 1500 字符≈1k tokens，输入合计 1.8k tokens，耗时 16.8 秒
  [f091] 本机可用系统自带 ssh-keygen 实现 Ed25519 非对称签名，无需安装 git/openssl/gpg
        证据: 实测环境 C:\WINDOWS\System32\OpenSSH\ssh-keygen.exe（Windows 10+ 自带）。生成 ed25519 密钥对（私钥 419B、公钥 107B），对文件签名（294B 签名），四项验证全部符合预期：① 原文件验签通过输出 Good file signature；② 篡改后报 Signature verification failed: incorrect signature；③ 冒名身份报 Could not verify signature。全程不需要 git / openssl / gpg（本机三者均无）
  [f092] 虎符 v3 双口令机制验证通过：左符 + 右符任一错误都无法解锁，且只知一符不可破解
        证据: 机制：masterKey = PBKDF2-HMAC-SHA256(左符 + | + 右符, 32B 盐, 600000 次迭代, 32B 输出)；用 AES-256-CBC 加密已知明文作为验证块。实测五项通过：① 左对+右对 解锁成功；② 左对+右错 拒绝；③ 左错+右对 拒绝；④ 双错 拒绝；⑤ 只知左符试 8 个常见右符全部失败。单次派生耗时 1.72 秒，即暴力破解每天仅能试约 5 万个组合
  [f093] 虎符 v3.1 三选二门限机制验证通过：三个口令中任意两个均可解锁，且三者得到的真钥匙相同
        证据: 实现：为三组配对 (1,2)(1,3)(2,3) 各派生一个密钥 K_ij，随机生成同一个真钥匙 REAL_KEY，用 K_ij 分别加密 REAL_KEY 得到三个保险箱文件。实测七项通过：1+2 / 1+3 / 2+3 三组都能打开且取出的真钥匙一致；错误口令、错误左符、同一口令重复均被拒绝；只知一个口令试 6 个组合命中 0 次。原理图解：多保险箱保护同一个真钥匙，而非用不同密钥加密不同数据
  [f094] 作者名字是公开身份标识，不承担保密职责；只有私钥泄露才是严重风险
        证据: 密码学分析：攻击者要伪造的是签名而非名字。名字对不上无所谓，符对不上才致命。这正是虎符本意（一半在君一半在将，合符才生效）。因此正确组合是：名字公开建立信任 + 私钥严格离线保密。虎符 v2 用 Ed25519 私钥签名核心清单，公钥发布为 allowed_signers 供任何人验签

== 二、假设（不能当依据）==
  [f020] Codex Remote 已 GA，覆盖所有 ChatGPT 档位（含 Free），支持 Windows host
  [f044] 假设：AA 显示离线可能与超大会话导致 DSH 侧忙于压缩有关，而非网络
  [f045] ai-manager.exe 二进制内含系统代理注册表的四个关键字符串，且带 proxy 服务模块，是 ProxyEnable 被改动的首要嫌疑对象

== 三、未验证 / 待办 ==
  [f021] Free 账号是否有 Site Tools 权限
  [f022] Free 档位的 Codex 额度是否够用
  [f023] Codex Computer Use 能否驱动浏览器访问 127.0.0.1:8788

== 四、已证伪（不要再提）==
  [f024] 阿里云 IP 会被 OpenAI 封
  [f025] 把 WLAN 网络类别改成 Private 就能解决 8788 超时
  [f036] Agents Anywhere 不受 Xray 影响，它的后端连接走代理绕过列表直连
  [f040] ai-manager.exe 每次登录以 Highest 权限批量改写各 AI 的 live 配置并跑 healthcheck，但不修改系统代理

== 五、经验教训（务必遵守）==
  [l002][method] 不要猜 API/协议行为，去读源码
        → 猜 API 行为可能导致完全错误的设计。源码 + 官方 README 是唯一权威。当直觉方案有明显副作用时，先停下来读源码。
  [l003][method] 严格区分 已实测 / 假设 / 未验证
        → 把假设当事实会让整个项目建立在沙子上。发言时标注置信级别，别人才能正确评估。
  [l004][method] 每步只排除一个未知数
        → 一次只赌一个环节，赌赢了再进下一步。串联验证 > 全链设计。
  [l005][method] 不要为『技术方案』努力，要为『目标』努力
        → 每当引入新组件时先问：这离目标更近了吗？如果链条越来越长，可能选错了路。
  [l006][pitfall] 中文经 stdin 变乱码（PowerShell 5.1 的限制）
        → 工具选错会浪费大量时间。当某个语言/运行时能力不足时，早点换工具，不要在它身上硬磨。
  [l007][pitfall] Reality 的 dest 不能选走 CDN 的站点
        → Reality 的 dest 必须是『直连的、支持 TLS1.3 的、非 CDN 的』站点。推荐 www.apple.com / www.amazon.com / www.cloudflare.com。避免走 Akamai 等 CDN 的域名。
  [l008][pitfall] 改系统代理后，Electron 应用必须完整重启
        → 改系统代理后，VSCode/ChatGPT/Claude 等 Electron 应用需完整重启。排查时可用 Edge（同为 Chromium）做对比，确认代理本身没问题就能定位到应用。
  [l009][technique] 多个 DNS 返回完全不同的 IP = DNS 投毒
        → 快速确诊 DNS 投毒：foreach($s in @('223.5.5.5','119.29.29.29','8.8.8.8','1.1.1.1')){ Resolve-DnsName -Name X -Server $s -Type A -QuickTimeout }
  [l010][technique] 通过 SSH 传复杂脚本要用 base64，不要用嵌套引号 heredoc
        → 跨层传脚本的通用解法：base64 编码。彻底避免引号/换行/特殊字符问题。
  [l011][technique] 改系统配置的四步规范
        → 本项目已按此规范做过 3 次改动，全部有快照和回滚命令（WLAN 类别、防火墙规则、系统代理）。
  [l012][pitfall] curl 抓 github.com 会返回整个 HTML 页面
        → 任何只关心状态码的 curl 测试，都必须加 -o /dev/null。
  [l013][pitfall] OCU 的三个坑
        → 遇到 React 管理后台类页面（Ant Design/Element UI），不要浪费时间做自动化点击——直接让用户点，3 秒的事。
  [l014][technique] 持久化 session + 无 resume 协议 = 必然的命名冲突
        → 桥接层的通用设计模式：动态名（产生垃圾）❌ vs 固定名+冲突自愈（推荐）✅。归档上限是防止无限增长的关键。
  [l015][method] 不要在有两个未知数的方案上投入不可逆成本
        → 评估方案时先数未知数。未知数越少越好。宁可换方案，不要在多个未知数叠加的地方投入。
  [l016][method] 结构化记忆比散文文档更适合 AI 使用
        → 给 AI 的上下文应该是机器可解析的，而不是要求它通读散文
  [l017][method] harvest 工具本身可用
        → 经验固化要设计成一条命令，否则 AI 不会主动做
  [l018][method] 经验包做成自包含文件夹 + 结构化记忆 + 自动 Skill 生成
        → 给 AI 的长期记忆应满足四点：结构可解析、追加安全、可查询、一条命令读写
  [l019][method] 命名空间机制验证
        → 集体知识库必须先解决通用与特异的分离，否则无法合并
  [l021][method] 经验包升级为可成长的命名空间架构
        → 要让知识库能跨环境汇聚，必须先解决'通用与特异'的分离，并提前定义格式演化规则
  [l022][pitfall] PowerShell 里 BinaryWriter.Write() 重载解析不可靠
        → PowerShell 中写二进制格式【不要用 BinaryWriter】，它的重载解析会选错。用固定偏移手工拼字节
  [l023][pitfall] PowerShell 函数返回单元素数组会被展开成标量
        → PowerShell 函数返回数组时必须加逗号 return ,$array，否则单元素数组会被展开成标量，导致类型错误且难以察觉
  [l024][technique] 虎符双因子：密钥文件 + 口令，XOR 合成主密钥
        → 双因子的价值在【分散风险】而非增加强度：任一单因子泄露都不足以解密；关键是两个因子必须物理分离存放
  [l025][pitfall] Codex CLI 不读 Windows 系统代理，必须设环境变量
        → 很多 CLI 工具（Codex/rclone/curl 等）不读系统代理，只认 HTTP_PROXY/HTTPS_PROXY 环境变量。排查'某个工具网络慢/超时'时先查这个
  [l026][technique] Codex CLI 可用 codex exec 非交互式执行任务
        → Codex CLI 0.160.0 提供 exec 子命令做非交互执行；这是把 Codex 接入自动化管线的关键接口。注意 workspace-write 沙箱被账号策略锁定，只有 bypass 能真实写文件
  [l027][technique] 卸载 Windows Store 应用的正确流程（含安全检查）
        → 卸载 Appx 前必须确认三件事：目标是否在跑、数据是否共享、凭证是否在包外。共享目录（如 ~/.codex）不会随包卸载而删除，但桌面快捷方式会变成死链接需要手动清理
  [l028][technique] 经验包桌面同步机制
        → 镜像同步只需比较大小+时间戳即可判定变更，无需全量哈希（对本地目录够用且快）
  [l031][pitfall] Node spawn 子进程默认 stdin 是管道，会让等待 stdin 的程序卡死
        → spawn 默认给子进程一个打开的 stdin 管道；任何会读 stdin 的 CLI（codex/curl/ssh 等）都会因此挂起。批量调 CLI 时默认就该关掉 stdin
  [l032][pitfall] Codex 不指定模型时会自选一个 ChatGPT 账号不支持的模型
        → 把 Codex 接入自动化时，【必须】用 -m 显式锁定模型，否则 Codex 自动选择新模型可能不被当前账号支持，导致间歇性全部失败（而且报错是网络超时，容易误判）
  [l033][technique] 把 Codex CLI 接入 HTTP bridge，打通手机到 GPT-6 的链路
        → 把 CLI 工具接入 HTTP 的通用模式：① 关 stdin ② 锁版本/模型 ③ 注入它需要的环境变量 ④ 解析结构化输出（优先 --json） ⑤ 序列化并发调用
  [l035][technique] 用「截图 + Codex 视觉」读取桌面版 GPT 的界面内容
        → 读取无法用 API/文件访问的 GUI 内容，最通用的办法是【截图 + 多模态模型视觉识别】。比 OCR 更准，能理解布局和语义
  [l036][pitfall] PowerShell 窗口跑到屏幕外导致「看不到」
        → 排查「窗口不见了」时，不要只看 IsWindowVisible，一定要读 GetWindowRect 的实际坐标 —— 窗口可能在可见状态下位于屏幕外
  [l037][pitfall] PowerShell 脚本含中文必须带 UTF-8 BOM
        → 任何含非 ASCII 的 PowerShell 脚本，必须确保有 UTF-8 BOM，否则 -File 执行时会用系统代码页解码而破坏内容
  [l038][pitfall] 绝不要对已运行的 GUI 应用做强制窗口操作
        → 读取别人窗口的内容，永远用 PrintWindow 这类只读 API。ShowWindow/MoveWindow/SetForegroundWindow 会改变窗口状态，对 Electron 应用尤其危险，可能造成不可逆的黑屏
  [l039][pitfall] 操作任何 GUI 应用前，先检查它是否已在运行
        → 自动化 GUI 的第一原则：先观察，后操作。强行启动已运行的应用会产生多个实例，强行改变窗口状态会破坏渲染。任务栏里的窗口坐标通常被标记为 (-21333,-21333)
  [l040][technique] 用 PrintWindow 非侵入式截取窗口内容
        → PrintWindow + PW_RENDERFULLCONTENT 是抓取窗口内容的首选。实测在 DSH 窗口上成功抓到 168.8 KB 的完整内容。注意：C# 代码里不要 using System.Drawing，否则 Add-Type 会编译失败，把绘图留给 PowerShell 做
  [l041][technique] Agents Anywhere 同步超时：云端在国内却被代理绕道日本
        → 诊断「某应用同步失败」的通用方法：① 看日志找 queuedEvents 这类积压指标 ② 对比该应用云端的直连 vs 代理延迟 ③ 国内服务走境外代理会因延迟激增而超时 ④ 长连接不重读代理设置，必须断连重连才生效
  [l042][technique] AA runtime 卡在 starting：会话过大导致快照 ACK 超时
        → 诊断 AA runtime 卡住的完整方法：① 看 AA connector 日志（%APPDATA%\Agents Anywhere\logs）找 runtime_unavailable 和 INTERNAL_ERROR ② 看插件日志（~/.agents-anywhere/dsh-bridge-next/logs/dsh-runtime.jsonl）找 sync.failed 的 batchSeq —— 若 batchSeq 长期不变即为卡住点 ③ 统计 snapshot.started 是否只针对某一个会话且从不 completed ④ 用 Node 24 的 zlib.zstdDecompressSync 解压 session.v4.jsonl.zstd（注意是【多帧】格式，需按 magic 28b52ffd 切分逐帧解压）⑤ 修法：把 index.js L6068 的 6e4 改成 6e5（60秒→600秒）后重启 DSH
  [l044][technique] DSH 会话文件是 zstd 多帧格式，必须逐帧解压
        → 读 zstd 文件若解压结果远小于预期，先怀疑多帧拼接。Node 24+ 内置 zlib.zstdDecompressSync 可用（Python 标准库无 zstd）。扫描 magic 切分逐帧解压是通用解法
  [l045][pitfall] AA connector 起不来：uv 下载国内 PyPI 镜像被代理绕道日本而超时
        → 国内服务/镜像被境外代理拖死的通用规律：直连 vs 代理测速，若代理慢 10 倍以上就加入绕过列表。本机已踩坑三次：① AA 云端(agents-anywhere.com) ② 阿里云 PyPI 镜像 ③ 清华镜像。判断方法：curl --proxy 与 curl 直连对比 time_total
  [l046][pitfall] 用 Start-Process 启动的 GUI 应用会随 pwsh 会话结束被终止
        → 需要让启动的程序在本命令结束后继续运行，绝不能用 Start-Process（它创建的子进程在我的进程树里）。用 WMI Win32_Process.Create，或 schtasks 创建计划任务。这也是为什么之前的 restart-dsh.ps1 在第 3 步就断了——它是 DSH 的子进程，DSH 一死它就死
  [l047][pitfall] AA connector 真正运行的是 connector-source 下的可编辑安装，不是 Programs 里的副本
        → 修改 Python 可编辑安装（pip install -e）的代码时，必须先用 venv\Scripts\python.exe -c 'import mod; print(mod.__file__)' 确认真实加载路径。不要凭目录名猜测。editable 安装的 .pth 文件指向真实源码目录
  [l048][pitfall] 系统代理必须做失效安全：代理开着而后端死了会让一批软件同时失效
        → 任何把某进程设为全局依赖（系统代理、hosts、DNS、环境变量）的配置，都必须有降级路径。判据：这个依赖挂掉时，系统是整体不可用还是仅部分功能降级？前者必须修
  [l049][method] 排查因果不要被时间巧合骗，必须做对照实验
        → 时间相关性只是线索不是证据。汇报根因前必须做一次去掉该变量的对照实验。第一次实验若窗口长度小于被测系统的检测周期（如心跳 30 秒而只停了 20 秒），实验无效必须重做
  [l050][pitfall] PowerShell 脚本必须存为 UTF-8 with BOM，否则中文乱码并直接导致语法错误
        → 跨编码边界的文本文件（.ps1/.psm1/.bat）一律 UTF-8 with BOM。若用编辑器或工具改过 .ps1，改完必须重新确认 BOM 还在
  [l051][pitfall] edit 类工具会丢掉 .ps1 的 BOM，改完必须补回
        → 任何读-改-写整文件的编辑操作都会重写编码。把 BOM 检查放进改动后的固定动作清单，不要靠记忆
  [l052][pitfall] PowerShell 测直连必须用 curl --noproxy，Invoke-WebRequest 默认走系统代理
        → 测网络路径时要明确指定是否用代理。带 --noproxy 的 curl 是最可靠的低层探针；应用层库（.NET/Electron/Python）会各自以不同方式读系统代理，不能互相代表
  [l053][pitfall] 开机自启的 GUI 和服务必须等到网络真正就绪之后再启动
        → 开机自启的可靠性问题多来自竞态而非程序本身。把启动顺序收敛到单点、并在依赖就绪后再启动，比给每个程序加重试更有效。注意等待必须有超时上限，否则会变成卡死
  [l054][method] 单个会话跑到 5 天 189 轮必然反复丢上下文：应主动开新会话并用 STATE.md 续接
        → 上下文长度是易失存储，不是持久存储。长项目必须外置状态。判断信号：会话超过约 100 轮或出现第一次自动压缩时，就该切分会话
  [l055][pitfall] 回到项目早期的根因是压缩摘要有损，对策是先读状态文件再动手
        → 交接文档必须包含已排除方案及原因，只写已完成不够——重走被排除的路是最常见的时间浪费
  [l056][technique] DSH 会话的 interrupted 与 aborted 语义不同：interrupted 才是丢工作的那种
        → 读日志要区分谁发起的终止。用户主动中止与进程被杀在语义和后果上完全不同，混在一起统计会得出错误结论
  [l057][pitfall] 搜数据文件 0 命中不能推出「程序不会写注册表」：能力线索要搜二进制
        → 判断某个程序具备什么能力，要看二进制而不是它的数据文件。同时要区分「读取」与「写入」：Electron 应用普遍含系统代理字符串但只是读取，命中字符串只算嫌疑线索，定罪需要实测
  [l058][method] 自己写下的 verified 结论被推翻时，必须主动回改并留证据链
        → 长期记忆里「状态」是可变字段（按 SCHEMA 4.2，falsified 的含义就是不要再提），数值和文本才不动。推翻旧结论时应改状态+追加说明，而不是悄悄加一条新的了事
  [l059][method] 易变路径必须集中解析：一个程序一个路径，不要每个脚本各写一遍
        → 凡是含版本号或哈希的安装目录都算易变路径，必须动态发现。判据：这个路径会在软件升级后改变吗？会，就不要写进代码。另注意要校验目标文件真的存在——出现过只有半个更新目录的情况
  [l060][pitfall] 改代码时的自造 bug 两大来源：引号与换行；改完必须当场回读并运行验证
        → 批量替换是高风险操作。三条硬规矩：改完回读、跑语法检查、跑一次真实调用。「工具报告成功」不等于「结果正确」，只有回读和运行才算数
  [l061][pitfall] 判断替换是否命中和实际替换必须用同一个字符串
  [l062][method] 判断某因素是否影响某系统时，必须确保被测路径真的被触发
        → 阴性结果只有在触发条件确实成立时才有意义。设计实验前先问：如果这个因素真的有影响，在这个窗口里它会通过哪条代码路径表现出来？那条路径会被执行吗？
  [l063][pitfall] 字面量检查一律用 Contains，不要用 -match
        → 验证脚本本身也会出错，尤其会产生假阴性（明明改好了说没改）和假阳性（文件没问题说有问题）。核实关键结论时，优先直接回读文件原文，而不是相信自己的判断表达式
  [l064][pitfall] .cmd/.bat 绝不能写 UTF-8 BOM，否则双击一闪就没
        → 编码规则按扩展名分叉：.ps1/.psm1 要 BOM（否则 PS5.1 按 GBK 读成乱码），.cmd/.bat/.vbs 绝不能有 BOM。写完任何脚本按扩展名核对一次
  [l065][method] 给非技术用户做入口，优先 GUI 开关而不是命令行脚本
        → 交付给非技术用户的工具要满足：双击即用、无黑框、状态可见、失败有可读提示。同时给脚本加自检开关，AI 就能验证能打开而不必真的弹窗
  [l066][pitfall] 长命令里一处语法错误会让整条命令在解析阶段全废，什么都没执行
        → PowerShell 是整条脚本先解析后执行，任何语法错误都会让整段零执行——不是执行到出错处为止。所以长命令要么拆段，要么先用 Parser::ParseFile 校验
  [l067][method] 给非技术用户做系统开关，最稳的是原生对话框（VBS/HTA），不是 PowerShell 窗口
        → 判断交付形态时的优先级：原生对话框(VBS/HTA) > WinForms窗口 > 命令行。凡是会弹控制台或让窗口标题带上「管理员:」的方案，对非技术用户都是减分项。另外 UAC 关闭(EnableLUA=0)时全系统都是管理员，标题前缀会一直出现，不是真的在请求授权
  [l068][pitfall] 用 cmd /c node
        → 常驻进程要脱离启动者的控制台：避免 cmd /c 包装、避免 shell 管道重定向。诊断进程莫名消失时，先看它有没有留下退出痕迹——本例中的 ^C 直接指明了是被信号终止，而不是崩溃
  [l069][pitfall] 批处理里找易变路径，优先用纯 batch 的 for /d，不要依赖 PATH 里的 powershell
        → 批处理脚本里尽量避免夹调用 powershell；能用 for /d、if exist、%VAR% 解决的就不要外挂解释器。若必须调用外部程序，写全路径而不是裸名字
  [l070][pitfall] PowerShell 5.1 没有 Test-Connection -TimeoutSeconds，扫描要用 ping.exe
        → 扫描/探测类脚本要先做阳性对照：拿一个确定存在的目标（如本机）验证探测逻辑真的работает。否则没扫到和扫不了无法区分，后者会直接产出错误结论
  [l072][pitfall] 让手机全局走电脑代理会引入新的不稳定，用户否决；不要再主动提议这类方案
        → 给用户设备新增全局依赖类改动（全局代理、DNS、hosts）前，先算故障面：这个依赖挂掉时用户会失去什么？如果答案是整个设备上不了网，那即使性能更好也应当先征得同意，或干脆不做。性能优化不能以增加脆弱性为代价
  [l073][technique] Chromium/Electron 应用的界面控件无法用 UI Automation 读取，只能靠截图加人工点击
        → 要操作 Electron/Chromium 应用的界面，先判断无障碍树是否有内容；没有就别指望程序化点击。非侵入截图的 PrintWindow 第二参数传 2(PW_RENDERFULLCONTENT) 才能截到 GPU 渲染内容；注意需要窗口可见
  [l074][pitfall] 遇到 reserved 拒绝就停手：保留名由应用完整性机制保护，绕路等于破坏完整性
        → 遇到 reserved 或 not permitted 或 integrity 类拒绝，不要绕路：不要改注册表、不要直接写插件缓存目录、不要伪造 bundle id。这类拒绝就是厂家安全边界。正确做法是留证据、报告、给官方修复途径
  [l075][technique] Windows 代理分两层：WinINET 与 WinHTTP 独立，普通 HTTPS 通不代表 WebSocket 通
        → 遇到「HTTPS 能通但 WebSocket/长连接不通」，先分清是哪一层代理：WinINET、WinHTTP、进程环境变量三者互不相通。用 curl 做直连与经代理的对照实验能一击定性：一个超时、一个秒回，就说明客户端没走代理。修复优先用进程环境变量，作用面可控且可逆
  [l076][technique] Windows 应用打不开先查保存的窗口坐标，别急着判断是崩溃或网络问题
        → 「进程在跑但看不到窗口」时，第一步永远是量窗口坐标而不是猜崩溃。判断标准：GetWindowRect 返回负几千、IsIconic 为真、GetForegroundWindow 不是它。修复要顺便把持久化的坐标改对，否则下次启动又跑到屏幕外
  [l077][pitfall] 给 Electron 应用注入代理环境变量时不要用 ALL_PROXY，socks5:// scheme 会破坏它的网络栈
        → 给 GUI 应用（Electron/Chromium）设代理变量时，优先只给 HTTP_PROXY 与 HTTPS_PROXY，不要给 ALL_PROXY；NO_PROXY 避免通配符。判断方法：加变量后若界面空白或不响应关闭，第一个怀疑对象就是代理变量里的 scheme 与通配符，先做减法而不是去查应用崩溃
  [l078][pitfall] 判断 Electron 窗口是否真的渲染出来，不能用亮度或颜色数，必须看截图
        → 视觉类判断不要用像素统计代理。深色 UI 的空白判定尤其容易翻车，因为背景色本身就是有效像素。要么直接看截图，要么用与背景色的差值和足够大的阈值，并且阈值必须由「已知空白样本」和「已知正常样本」两组数据标定出来
  [l079][pitfall] 与 Codex 交换中文内容时，必须由 PowerShell 侧独占文件读写，且 prompt 里不能有双引号
        → 跨程序传中文的三条通则：① 谁拥有文件系统就用 .NET API 显式指定编码，别依赖 shell 的 Get-Content；② 给原生程序传参时避免内嵌双引号；③ 判定状态要看结构化位置（最后一块、精确字段），不要用全文包含匹配，否则会被文档里的示例误导
  [l080][pitfall] PowerShell Start-Job 里的重定向不使用 UTF-8，中文会被写成 GBK 乱码
        → 任何把外部程序输出落盘的代码，都不要依赖 shell 的重定向与默认编码。要么显式设定控制台编码，要么捕获字符串后用 .NET API 指定编码写盘。发现乱码时先判断方向（UTF-8 当 GBK 还是 GBK 当 UTF-8），逆向一次通常就能救回原始文本
  [l081][technique] 做不到实时推送时，改用延迟投递到对方必定会打开的会话
        → 当实时推送做不到时，先问对方有没有一个「必定会打开的容器」。把消息投进那个容器，就把「主动推送」降级成「被动可见」，成本几乎为零且同样消除了人工转述。这比硬造推送通道更实用
  [l082][design] 多 AI 协同系统必须内置「是否值得开会」的判定，否则会被会议拖垮
        → 任何召集多方的机制都要配一个不必召集的判据，并且把判据写下来、可审计。判断标准尽量客观（可逆性、影响面、是否有多条合理路线），避免退化成感觉重要就开会
  [l083][design] 多 AI 会议的真实缺陷：顾问只能听操作员转述，无法独立核验
        → 设计只读审查者角色时，必须同时给它独立的证据通路。否则审查退化为听汇报，独立性是假的。判断方法：问一句如果执行者做错了，审查者有没有办法自己发现？ 若答案是否，则角色隔离只完成了形式
  [l084][design] 灾备角色的第一原则是保持干净：急救员不得参与日常操作
        → 设计灾备时先问一句：如果主系统坏了，备系统会不会因为同样的原因也坏？若会，则它不是灾备而是副本。真正的灾备必须在故障面上与主系统隔离——不同的进程、不同的依赖、不同的权限路径
  [l085][design] 灾备角色的权限必须分状态：常态只读保持干净，紧急态必须能动手
        → 设计灾备权限时不要一刀切。问两个问题：① 常态下它参与操作会不会与主系统共享故障面？（会 → 常态应限制）② 主系统全挂时它还能不能动？（不能 → 灾备无效）。正确解是让权限随状态变化，把保持干净和能动手放在不同状态里，而不是二选一
  [l086][pitfall] jsonl 必须无 BOM，而 md/json/ps1 必须带 BOM —— 二者要求相反，混用会造成静默故障
        → 批量设置文件编码前先按扩展名分类。判断依据是谁读它：PowerShell 命令读的要 BOM，编程语言的 json 解析器读的不要 BOM。混用一种编码会制造长期沉默故障——文件在，但谁都用不了
  [l087][design] 加密数据前必须先建立一份永不上锁的母版
        → 任何加密或加锁的方案，实施前先问：如果这把锁打不开了，我还能拿回数据吗？若答案是否，则先建立一份不受该锁保护的离线/本机副本。备份与加密不能是同一份数据，否则加密就从保护变成了风险
  [l088][pitfall] PowerShell 变量名不区分大小写：$p 会覆盖 $P，循环变量极易造成隐性故障
        → PowerShell 是大小写不敏感语言。凡是看起来像能靠大小写区分的地方都要主动避开。判断方法：把外层变量名改成一个完全不同的词，而不是改大小写
  [l089][pitfall] PowerShell 里嵌套 here-string 会提前终止外层，整个脚本在解析阶段全废
        → 需要脚本生成脚本时，避免多层同构的字符串定界符。选择异质方案（文件写入 API、字符串拼接、模板占位符替换）比嵌套同符号更可靠
  [l090][pitfall] PowerShell 不支持 < 输入重定向，需要 stdin 的命令必须走 cmd /c
        → 跨 shell 迁移命令时，先确认目标 shell 支持哪些运算符。PowerShell 与 cmd/bash 的重定向语法并不通用，凡是看到 < 或 > 都要先想一下当前 shell 是否支持
  [l091][pitfall] .cmd 启动器的中文是编码雷区，最稳的做法是全用 ASCII
        → 分层处理编码问题：外壳（.cmd）用最保守的纯 ASCII，内容（.ps1/.md）才用需要的编码。让每一层只承担它最擅长的事，比在某层里强行处理多编码更可靠
  [l092][pitfall] 必须确认工具实际往哪个目录写数据，否则隐私会被写进对外发布的那一份
        → 多副本架构下，写到哪里必须是显式且唯一的。判断方法：随便改一条数据，看哪些副本的时间戳变了。凡是同一份数据存在两处以上可写位置，就一定会有写错的一天
  [l093][design] 名字与密钥是两件事：身份标识不承担保密职责
        → 任何身份体系都要先分清标识与凭证。标识可以公开、可以重复、可以改名；凭证必须保密、必须唯一、改名即失效。把标识当凭证用，等于把门牌号当钥匙
  [l094][technique] 门限方案（三选二）的实现：多个保险箱保护同一个真钥匙，而不是用不同密钥加密不同数据
        → 需要多路径访问同一份数据时，不要让数据本身承担多路径，而是加一层钥匙的钥匙。把访问凭证与数据密钥分离，既保持数据单一副本，又能自由增减访问路径
  [l095][design] 加锁之前先问：这把锁打不开了，我还能拿回数据吗
        → 任何加密/加锁方案实施前先做锁失效演练：假设密钥永久丢失，还能拿回数据吗？若答案是否，则先建立不受该锁保护的副本。备份与加密不能是同一份数据，否则加密就从保护变成了风险
  [l096][pitfall] ssh-keygen 生成空口令密钥时，空字符串参数在 PowerShell 里传参失败，要用 cmd 包裹
        → 给原生程序传空字符串参数在 PowerShell 里不可靠。凡是需要传空值的场景，优先用 cmd 包裹或改成传非空占位值。更普遍的原则：外部命令的没报错不等于成功了，必须验证产物

== 六、关键决策 ==
  [d001] bridge 的 session 冲突怎么修？
        选了: 固定 sessionId + 冲突自愈（检测 already exists → 归档冲突日志 → 重试一次，归档上限 3）
        理由: 读源码确认协议无 open/resume，无法复用；自愈只在真正冲突时才动磁盘，零副作用且有界
  [d002] 用哪种方式解决 Windows 外网？
        选了: 阿里云轻量应用服务器（日本东京）自建 Xray
        理由: 用户明确要自建；轻量国际型 ¥28/月 最便宜；日本东京延迟与 IP 质量平衡
  [d003] 服务器规格选哪个档？
        选了: 国际型 · 2核1G / 30G · 1个月
        理由: 做代理只需极少资源；1 个月便于在 IP 被封时退款换地域
  [d004] SSH 用密码还是密钥？
        选了: 本地生成 ed25519 密钥，用户在远程终端粘贴一条命令装公钥
        理由: 密码永不经过 AI；装好公钥后 AI 可完全自主操作
  [d005] 代理协议选哪个？
        选了: VLESS + xtls-rprx-vision + REALITY
        理由: Reality 当前抗封锁最好，不需要域名和证书，伪装成真实站点
  [d006] Reality 的 dest 用哪个站点？
        选了: www.apple.com
        理由: 实测：microsoft 失败、apple 成功。Reality 要求 dest 是非 CDN 的直连站点
  [d007] Windows 客户端用 GUI 还是 CLI？
        选了: Xray CLI（xray.exe + config.json）
        理由: CLI 可完全用命令行配置和验证，不依赖 GUI 操作（本机 UI 自动化已证明不可靠）
  [d008] 代理用系统代理还是 TUN 模式？
        选了: 系统代理（127.0.0.1:10809）
        理由: Electron 应用（ChatGPT Desktop）遵守系统代理；实测 Established=19 全部走代理成功。TUN 是后备方案
  [d009] 要不要加看门狗？
        选了: 加（计划任务每 5 分钟检查，挂了自动重启）
        理由: 系统代理指向本地端口有单点故障风险；看门狗把恢复时间从『用户手动排查』缩短到 5 分钟
  [d010] 记忆框架用纯文本还是结构化？
        选了: JSONL（facts/lessons/timeline/decisions 四个追加式文件）+ index.json + memory.ps1 查询工具
        理由: JSONL 追加安全、逐行可读、机器可解析、grep 友好；Markdown 保留作为人类可读层
  [d011] GPT 接入走 WebMCP 还是 Codex Remote？
        选了: 转向 Codex Remote（尚未验证）
        理由: Codex Remote 是官方 GA、覆盖所有档位（含 Free）、支持 Windows host——未知数最少
  [d012] 长期项目如何避免反复丢失上下文
        选了: 按阶段主动开新会话，并把状态外置到经验包（STATE.md + facts/lessons）
        理由: 实测同一会话压缩 7 次、非正常结束 14 次，压缩摘要有损，导致 AI 多次退回早期认知并重复已排除的工作
  [d013] 脚本里如何处理带版本号/哈希的安装路径
        选了: 集中到 lib\resolve-paths.ps1 动态发现，调用方一律不写死
        理由: 5 个脚本硬编码同一路径，升级后全部静默失效且难以归因。集中解析只有一处需要维护，且能兼容升级
  [d014] AA 后端连接是否应该走系统代理
        选了: 永久直连（proxy=None / trust_env=False）
        理由: AA 后端是国内服务（115.191.78.81）本就应直连；依赖系统代理会让 AA 的可用性与 Xray 状态耦合，Xray 一关就整体失效。改为直连后 AA 与代理完全解耦
  [d015] 手机代理在电脑关机时如何自动回退
        选了: 不实现自动回退，由用户手动切换（关机时把手机配置代理改回关闭）
        理由: 用户明确表示手动切就行，不希望再增加一个常驻服务；手动方案不引入新组件、不需要额外维护

== 七、最近事件（时间倒序，10 条）==
  2026-10-07T09:16:54+08:00  手机经电脑代理的方案被用户否决并已完整回退  —— 用户反馈：手机改了这个 Wi-Fi 代理之后反而变得不稳定。已完整回退：config.json 用 config.json.bak-20261007-090416 覆盖（移除 0.0.0.0:10810 入站与 routing 分流规则），删除防火墙规则「Xray LAN Proxy (phone only)」，Xray 重启后 Configuration OK。回退后仅剩原有 127.0.0.1:10808/10809，电脑自身代理正常（google 200 / chatgpt 403 / 出口 47.79.39.225）。经验包中 f063/f065/f066/d015 所描述的这一整套方案【已停止使用】，不要再向用户提议。
  2026-10-07T09:32:15+08:00  查清 ChatGPT 桌面版「了解并操控电脑」的官方设置路径，以及远程控制被 UAC 关闭所阻断  —— 用 codex features list / mcp list / remote-control 系列命令与窗口截图完成排查。确认操控开关在 设置-常规-权限-完整访问权限，已把位置标注在截图 点这里-完整访问权限.png 交给用户自行点击。远程控制（手机操控电脑）因 EnableLUA=0 无法启动守护进程，需恢复 UAC 并重启才可能启用；用户未选择该路径
  2026-10-07T09:52:17+08:00  查明 computer use 未接入的根因：应用自带的 openai-bundled 插件市场从未注册，且该市场为保留名无法外部注册  —— 路径：features list 显示 computer_use 已开；mcp list 显示 cua_repl 是占位且 disabled；读 cua-repl README 得知 CUA_REPL_ENABLED_SURFACES 必需且由 Desktop 填充；查 logs_2.sqlite 发现 openai-bundled 插件缺失、GitHub 429、无 Git 可执行文件；再定位到应用包内实际存在全部 9 个 bundled 插件；最后尝试注册被 reserved 拒绝。全程零改动。结论属应用侧问题，正规出路是更新应用
  2026-10-07T10:04:40+08:00  修复 ChatGPT 桌面端 Remote Control 无法启用：注入代理环境变量使 WebSocket 经东京节点连通  —— 现象为设置-连接-控制此电脑点击允许后提示无法启用远程控制请重试。只读诊断确认应用与 Codex 版本一致、登录有效、enrollment 已成功（有 server_id 与 environment_id），唯一故障是 wss 直连 TCP 超时。对照实验证明端点经代理 0.57 秒可达。修复动作为写入 User 级代理环境变量并重启应用，修复后 Connected。附带发现：openai-bundled 插件市场仍未注册（computer use 另外一条线），以及启动时 list_models 曾超时一次
  2026-10-07T11:37:20+08:00  裁定桌面 Codex agent 担任技术顾问与独立审查者，不参与共同操作；明确 A/B 权限交替为互为备份而非同时开启  —— 理由：① DESKTOP 权限为 read-only + 网络受限 + 审批 never，不能写文件，exec_command 历史为 0 次，物理上做不到共管；② 共管会让动作无法归因；③ 它的价值恰在独立性 —— 两次圆桌中它明确反对 DSH 的结论且反对正确。A 面常态为 DSH（操作员兼记录员），B 面 DESKTOP 仅在 DSH 不可用时升格，升格需先提权、解除网络限制并取得用户授权。已写入桌面 AI圆桌系统/05-模型与权限对照.md
  2026-10-07T12:43:37+08:00  建立虎符 v2：作者签名体系（Ed25519）  —— 确立名字公开
  2026-10-07T12:43:37+08:00  建立虎符 v3/v3.1：双口令与三选二门限  —— v3 双口令：左符（AI 生成，32 字符 CSPRNG，熵约 186 位）+ 右符（用户自设，AI 从未见过），PBKDF2 60 万次迭代派生主密钥。v3.1 三选二门限：用户三个口令中任意两个即可解锁，实现为三个保险箱保护同一个真钥匙。配套 init/unlock 脚本与纯 ASCII 的 .cmd 双击启动器 + 桌面快捷方式
  2026-10-07T12:43:37+08:00  建立三层架构：工作母版 / 备份母版 / 发行版  —— 用户指出虎符若出问题会导致全盘失守，提出需要一份永不锁死的母版。重组为三层：经验包-工作母版（无锁、活跃、权威）、经验包-备份母版（无锁、静止、参考修复）、experience-pack（带虎符、对外开源）。两条单向数据流，配套 snapshot-to-backup.ps1 与 sync-to-release.ps1
  2026-10-07T12:43:38+08:00  修复工具写错目录隐患：本机隐私曾被写入发行版  —— 核查发现 memory.ps1 等工具使用 $ScriptDir 推导根目录，而发行版当时兼作工作目录，导致 90 条事实与 87 条经验等本机数据被写进准备开源的那一份。处理：把最新数据迁回工作母版、修正 sync-pack.ps1 的硬编码路径为 $PackRoot、桌面镜像改指向工作母版、删除桌面多余镜像。修复后三层各司其职
  2026-10-07T12:43:38+08:00  制作可发手机的经验包基础版并完成隐私核查  —— 首次按完全脱敏制作，剔除全部经验数据后仅 227KB。用户指出经验本身才是价值（复利效应），遂重新制作：保留全部 274 条经验数据与全部文档，仅清除零知识价值的身份指纹（账号 ID、会话 ID、服务器/环境/安装 ID、用户标识）。成品 52 文件 441KB，压缩包 198KB。README 重写，以会滚雪球的知识体为核心理念

== 八、配套文档 ==
  AGENTS.md   方法论      %USERPROFILE%\agents\B\workspace\AGENTS.md
  STATE.md    当前状态    %USERPROFILE%\agents\bridge-client\STATE.md
  LESSONS.md  经验教训    %USERPROFILE%\agents\bridge-client\LESSONS.md

【使用说明】这是机器生成的记忆简报，可直接粘贴给任何 AI 作为项目背景。
