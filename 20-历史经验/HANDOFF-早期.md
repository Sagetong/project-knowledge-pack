# HANDOFF — 手机 GPT ↔ 电脑 AI 通信项目

> 用途：给任何接手的 AI（或人）一份「现在到底是什么情况」的事实台账。
> 最后更新：2026-10-05 18:35（本地时间）

---

## 一、根本目标

消除「人类充当 AI 与 AI 之间传话筒」。

```
手机端 GPT → 自动发送任务 → 电脑端 AI 执行 → 自动返回结果
```

**验收标准**：`copy = 0` · `paste = 0` · `人工转发 = 0`

**注意**：用户在手机上打字下命令，不算"传话"（那是提目标）。
被禁止的是：把 A 的回复复制/改写后喂给 B。

---

## 二、当前架构（已实机跑通）

```
手机浏览器（192.168.x.x）
    ↓  HTTP POST /task  {"task":"..."}
mobile-client  :8788        （Node.js，0 依赖，页面 + 反向代理）
    ↓  HTTP POST /task
bridge         :8787        （Node.js，0 依赖，127.0.0.1 only）
    ↓  stdio JSON-RPC（换行分隔）
dsh-sdk-app                 （官方 SDK profile，常驻进程）
    ↓
DeepSeek（deepseek-official / deepseek-flash）+ 22 个电脑工具
    ↓  session.event 通知流
返回 → 手机页面显示
```

**三个进程**：
| 组件 | 位置 | 文件 |
|---|---|---|
| mobile-client | `0.0.0.0:8788` | `%USERPROFILE%\agents\bridge-client\mobile-client-test\server.js` |
| bridge | `127.0.0.1:8787` | `%USERPROFILE%\agents\bridge-client\http-bridge-test\bridge.js` |
| dsh-sdk-app | 子进程 | `%USERPROFILE%\.dsh\profiles\sdk\` |

---

## 三、已实测验证的能力

| 能力 | 状态 | 证据 |
|---|---|---|
| `dsh sdk` 独立实例可启动 | ✅ | 官方内建模板 `dsh-app-boot` L533：`sdk: { bundles: [dsh-base, dsh-sdk-app] }` |
| SDK `initialize` / `session/prompt` / `shutdown` | ✅ | `serverInfo.name = "deepseek-harness-sdk-runtime"` |
| DeepSeek 真实调用 | ✅ | 返回含 reasoning 的真实回复 |
| computer tool 执行 | ✅ | `pwsh Get-Location` → `<项目盘>`，`isError:false` |
| 多轮上下文 | ✅ | 跨 4 轮记住口令「紫色鲸鱼-7788」 |
| bridge `POST /task` | ✅ | `{"ok":true,"result":"..."}` |
| 手机真实入站 | ✅ | **4 次实测全通**，含中文 |
| 中文 UTF-8 全链路 | ✅ | 输入 45 字节（15 中文字），返回 18 字符，无乱码 |

**四次手机实机测试记录：**
| # | 时间 | 发送内容 | 耗时 | 结果 |
|---|---|---|---|---|
| 1 | 18:29 | `PHONE_OK` | 1197 ms | ✅ |
| 2 | 18:31 | `PHONE_OK` | 989 ms | ✅ |
| 3 | 18:32 | `FINAL_OK` | 847 ms | ✅ |
| 4 | 18:33 | `你好，请确认你已经收到这条消息` | 775 ms | ✅ 中文正常 |

---

## 四、本次遇到的问题与解决过程（重要经验）

### 问题 1：手机访问 `192.168.x.x:8788` 一直 `ERR_CONNECTION_TIMED_OUT`

**排查顺序（前两步都是错的，第三步才对）：**

| 步骤 | 假设 | 做法 | 结果 |
|---|---|---|---|
| ① | 防火墙的 `node.exe` Inbound Block（Public）在拦 | 把 WLAN 网络类别 `Public → Private`，使该规则不适用 | ❌ **仍然超时**（推理错误） |
| ② | 是不是不同网段 / AP 隔离 / VPN | ping 手机、查路由表、查 VPN 进程 | ✅ 全部排除：手机 1ms 可达、路由正确、无 VPN |
| ③ | **不再推理，抓证据** | **启用 Windows 防火墙丢包日志** | 🎯 **一击命中** |

**决定性证据：**
```
2026-10-05 18:26:10  DROP TCP  192.168.x.x → 192.168.x.x  57124 → 8788  RECEIVE  7680
...（共 26 条，18:26:10 ~ 18:27:47，正是用户测试的时刻）
```
- `DROP` → 确认是 Windows 防火墙丢的
- 源 IP `192.168.x.x` → **手机真实 IP 是 .8**（此前误以为是 .5）
- `RECEIVE` + 目标端口 8788 + pid 7680 → **包已到达电脑，网络层完全正常**

**最终修复：新增一条精确的入站放行规则**
```powershell
New-NetFirewallRule -DisplayName 'mobile-client-test 8788 (LAN only)' `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8788 `
  -RemoteAddress 192.168.x.x/24 -Profile Any
```
**规则生效瞬间：**
```
18:29:34  ALLOW TCP  192.168.x.x → 192.168.x.x:8788   ← 手机立刻连上了
```

### 问题 2：那条 `node.exe` Block 规则是哪来的？

```
规则名：TCP Query User{A7533F35-...}C:\...\node.exe
Profile：Public     Group：(空)     PolicyStore：Local
```
**这是 Windows 弹出「安全警报」被点「取消」时留下的遗留规则** —— 不是本项目创建的，一直躺在系统里。

### 问题 3：PowerShell 驱动 DSH 时中文乱码

**现象**：Python 版 `tempfile` 报错、PowerShell `StandardInputEncoding` 属性在 .NET Framework 上不存在 → 中文变成 `��ֻ�ش�`。
**解决**：**改用 Node.js 直接 `spawn`**，`stdout.setEncoding('utf8')` + `stdin.write(str,'utf8')` 精确控制编码。**已实测 45 字节中文完整往返。**

### 经验教训（值得记住）

1. **不要靠推理定位网络/防火墙问题，要靠日志** —— 第一步的推理是错的，白白多花两轮测试。
2. **`ERR_CONNECTION_TIMED_OUT` = 包被静默丢弃**（防火墙 Block 的动作就是静默丢弃），不是"端口没开"。
3. **Windows 防火墙规则优先级：显式 Block > Allow > 默认策略**，且**按 profile 过滤**。
4. **排查链路要先分层**：L2（ARP/同网段）→ L3（ping/路由）→ L4（端口/防火墙）→ 应用层。

---

## 五、当前系统改动清单（全部可回滚）

| 改动 | 回滚命令 |
|---|---|
| WLAN 网络类别 `Public → Private` | `Set-NetConnectionProfile -InterfaceAlias 'WLAN' -NetworkCategory Public` |
| 新增防火墙规则 | `Remove-NetFirewallRule -DisplayName 'mobile-client-test 8788 (LAN only)'` |
| 启用防火墙日志 | `netsh advfirewall set allprofiles logging droppedconnections disable` |

**未改动**：`bridge.js` · desktop DSH · Agents Anywhere · `ask-deepseek.ps1` · 任何已有防火墙规则 · 防火墙开关 · 热点

---

## 六、已确认的产品边界（决定了下一步方向）

| 事实 | 来源 |
|---|---|
| **ChatGPT 个人账号（Free/Go/Plus/Pro）全部禁止创建 Custom GPT** | [ChatGPT Free Tier FAQ](https://help.openai.com/en/articles/9275245-chatgpt-free-tier-faq) |
| **MCP Apps 移动端不支持（"web only"）** | [OpenAI Developer mode & MCP apps](https://help.openai.com/en/articles/12584461-developer-mode-and-mcp-apps-in-chatgpt-beta) |
| 完整 MCP 需 Business/Enterprise/Edu | 同上 |

**⇒ ChatGPT 手机端无法主动调用外部 API。这是产品边界，不是配置问题。**

**⇒ 因此当前路线是「自建轻量前端」——用已有的 `DEEPSEEK_API_KEY`，而不是 ChatGPT。**

---

## 七、下一步待决

| 选项 | 说明 |
|---|---|
| **A. 保持现状** | 手机浏览器已可当"电脑 AI 遥控器" |
| **B. 接入 GPT** | 需要换一个「能调用外部 API 的前端载体」（ChatGPT 个人账号不行） |
| **C. 清理** | 回滚所有改动，停三个进程 |

**关键技术债（已知但未处理）**：
- 移动端页面无认证（仅靠局域网可达性隔离）
- bridge 与 mobile-client 都是单会话串行
- 无异常/超时重试策略

---

## 八、文件位置索引

```
%USERPROFILE%\agents\bridge-client\
   ├─ http-bridge-test\bridge.js              ← 核心 bridge（已验收，勿改）
   ├─ http-bridge-test\bridge.log
   ├─ mobile-client-test\server.js            ← 手机页面 + 反向代理
   ├─ mobile-client-test\server.log
   ├─ ask-deepseek.ps1                        ← 早期 PowerShell 版（保留）
   ├─ firewall-state-20261005-101648.txt      ← 网络类别改动前快照
   ├─ fwfix-20261005-182902.txt               ← 防火墙规则改动前快照
   ├─ fwlog-before.txt                        ← 日志设置改动前快照
   └─ HANDOFF.md                              ← 本文件

%USERPROFILE%\.dsh\profiles\sdk\     ← SDK profile（官方模板自动创建）
```
