# PortPeek

> macOS 菜单栏里的本机端口查看与进程管理工具。

PortPeek 帮你快速回答三个问题：

- 当前有哪些 TCP / UDP 端口正在监听？
- 哪个进程占用了它们？
- 这是哪个应用、项目或开发服务？

它常驻菜单栏，打开即可查看当前用户可管理的监听端口，不需要切换到终端执行命令。

## 亮点

- **清晰的进程分组**：按 PID 组织端口，单端口进程也有独立分组。
- **快速定位**：支持按端口号、进程名、地址、协议和 PID 搜索。
- **完整上下文**：展开后查看命令行、可执行文件路径、工作目录、启动时间和父进程。
- **开发者友好**：识别常见的 Vite、Next.js、Docker、Postgres、Redis 等工具和服务。
- **风险提示**：标记绑定到所有网卡的端口，提示其可能对外暴露。
- **安全操作**：只处理当前用户拥有的进程；普通结束和 SIGKILL 分级放置，并对强制结束再次确认。

## 界面信息

每个端口 item 会展示：

| 信息 | 用途 |
| --- | --- |
| 端口与协议 | 识别 TCP / UDP 服务 |
| IPv4 / IPv6 | 了解 socket 的网络类型 |
| 绑定地址 | 判断仅本机可用或可能对外开放 |
| PID 与应用名 | 定位实际占用进程 |
| 工具徽标 | 快速识别常见开发框架或服务 |

点击 item 可展开更多详情；右键菜单提供复制地址、打开项目目录和结束当前用户进程等操作。

## 获取信息的方式

PortPeek 使用 macOS 自带工具读取本机监听状态：

1. 通过 `lsof` 获取 TCP / UDP 端口和进程关联。
2. 在必要时使用 `netstat` 作为回退来源。
3. 通过 `ps` 补充用户、父 PID、启动时间和完整命令行。
4. 通过 PID 级 `lsof` 补充可执行文件路径和工作目录。
5. 可选读取 Docker 端口映射，用于展示容器项目名。
6. 过滤 root、系统级、其他用户和无效 PID 的记录，只展示当前用户可管理的端口。

扫描在后台执行，主线程只负责更新界面。默认每 5 秒刷新一次，也支持手动刷新。

## 安全边界

- 不提供 root、系统级或其他用户进程。
- 不请求管理员权限，也不会绕过 macOS 安全机制。
- 普通结束使用 `SIGTERM`。
- `SIGKILL` 仅位于右键菜单的二级“结束进程”菜单，并在执行前明确提示风险。
- 结束进程后只触发一次刷新，后续状态由自动刷新更新。
- 应用关闭后不会在后台持续运行或上传端口数据。

## 构建

要求：

- macOS
- Xcode
- SwiftUI

在仓库根目录执行：

```sh
xcodebuild \
  -project PortPeek.xcodeproj \
  -scheme PortPeek \
  -sdk macosx \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

PortPeek 使用菜单栏应用模式运行，不会在 Dock 中显示普通应用窗口。

## 自动发布

项目使用 GitHub Actions 和 Release Please 自动管理版本与发布：

```text
提交 feat / fix
      ↓
Release Please 创建 Release PR
      ↓
合并 Release PR
      ↓
自动更新 VERSION 与 CHANGELOG
      ↓
创建版本 tag 和 GitHub Release
      ↓
构建 Universal PortPeek.app 并上传 ZIP / SHA-256
```

版本号遵循 Conventional Commits：`fix:` 发布 patch，`feat:` 发布 minor，带有 `BREAKING CHANGE` 或 `!` 的提交发布 major。

当前发布产物为未签名 ZIP，适合内部测试和早期分发。正式公开分发前，需要在 GitHub Secrets 中配置 Apple Developer ID 签名与公证凭据。

## 项目结构

```text
PortPeek/
├── PortPeek.xcodeproj/           # Xcode 工程配置
├── PortPeek/                     # 应用源码
│   ├── PortPeekApp.swift         # 菜单栏 App 入口
│   ├── ContentView.swift        # 主界面、筛选与分组
│   ├── PortRow.swift            # 端口 item、详情与操作菜单
│   ├── PortMonitor.swift        # 刷新、扫描、解析与进程操作
│   ├── PortModels.swift         # ListeningPort 数据模型与派生信息
│   ├── Assets.xcassets/         # 图标与颜色资源
│   └── LIST_DATA_FLOW.md        # 列表信息获取流程图
├── HOMEBREW.md                  # Homebrew 分发说明
└── README.md                    # 项目介绍
```

> Xcode 工程、target、源码目录和构建产物均已统一为 `PortPeek`；Bundle ID 也已同步更新。

## 文档

- [列表信息获取流程图](PortPeek/LIST_DATA_FLOW.md)
- [Homebrew 分发说明](HOMEBREW.md)

## 项目状态

PortPeek 当前专注于本机 TCP / UDP 监听端口。容器名称映射、协议识别和服务识别会持续完善；项目识别依赖进程命令行和工作目录是否可读取。

## Repository

[github.com/OSpoon/PortPeek](https://github.com/OSpoon/PortPeek)
