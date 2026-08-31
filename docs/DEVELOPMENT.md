# PortPeek 开发指南

这份文档面向开发、构建和维护 PortPeek 的贡献者。产品介绍和用户使用信息请先阅读根目录的 [README](../README.md)。

## 本地构建

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

## 代码结构

```text
PortPeek/
├── PortPeek.xcodeproj/       # Xcode 工程配置
├── PortPeek/                 # 应用源码
│   ├── PortPeekApp.swift     # 菜单栏 App 入口
│   ├── ContentView.swift     # 主界面、搜索与分组
│   ├── PortRow.swift         # 端口条目、详情与操作菜单
│   ├── PortMonitor.swift     # 扫描、刷新、解析与进程操作
│   ├── PortModels.swift      # ListeningPort 数据模型
│   └── Assets.xcassets/      # 图标与颜色资源
├── docs/                     # 开发、数据流与分发文档
└── README.md                 # 产品介绍
```

## 数据与权限边界

PortPeek 使用 macOS 自带工具读取端口和进程信息，默认每 5 秒刷新一次；完整的数据流见[列表数据流](LIST_DATA_FLOW.md)。

- 使用 `lsof` 获取 TCP / UDP 监听端口
- 必要时使用 `netstat` 补充缺失记录
- 使用 `ps` 和 PID 级 `lsof` 获取进程详情
- 可选读取 Docker 端口映射，用于识别容器项目名
- 仅保留当前用户拥有、且 PID 有效的可管理记录
- 不请求 root 权限，不上传本机数据

## 发布

项目使用 GitHub Actions 和 Release Please 管理版本与发布。提交信息遵循 Conventional Commits：

- `fix:` 触发 patch 版本
- `feat:` 触发 minor 版本
- `BREAKING CHANGE` 或 `!` 触发 major 版本

Homebrew Cask 相关流程见[分发说明](HOMEBREW.md)。
