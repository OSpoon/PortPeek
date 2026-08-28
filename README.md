# RunStat

RunStat 是一个常驻 macOS 菜单栏的轻量端口监视器，用来快速查看本机正在监听的 TCP / UDP 端口，并安全处理占用进程。

## 功能

- TCP / UDP 切换，并显示当前协议的监听数量
- 每 5 秒自动刷新，也支持手动刷新；结束进程后会立即刷新
- 显示监听端口、协议、IPv4 / IPv6、绑定地址和 PID
- 合并同一进程、协议和端口的 IPv4 / IPv6 监听，并标记双栈
- 识别 GUI App 图标、命令行进程、系统进程和 launchd 托管进程
- 展开详情查看完整命令行、可执行文件路径、工作目录、启动时间、用户和父进程
- 识别常见开发工具和服务，例如 Vite、Next.js、Webpack、Django、FastAPI、Postgres、Redis、Docker 等
- 橙色天线图标提示端口绑定到所有网卡、可能对外暴露
- 点击行展开 / 折叠；支持悬停状态和右键菜单
- 复制 `localhost:端口`、端口号、PID 和项目路径
- 在 Finder、Terminal 或编辑器中打开相关路径
- 结束进程带确认；右键“结束进程”二级菜单中提供 SIGKILL，并再次确认
- 不提供 root、系统级和其他用户进程；仅显示当前用户可管理的监听端口

## 端口扫描

RunStat 使用两条系统命令获取监听信息：

1. `lsof`：获取进程、用户、协议、地址和端口等详细信息。
2. `netstat`：补充 macOS 新版本中 `lsof` 无法读取的 root-owned socket，例如 `cupsd:631`。

`netstat` 回退链路会兼容 `tcp4`、`tcp6`、`tcp46`、`udp4` 和 `udp6`，并从 `ps` 和 `lsof` 补充进程命令行、路径、工作目录、启动时间和用户信息。

macOS 可能限制普通应用读取其他用户或系统进程的 socket。RunStat 不会绕过系统安全机制，也不会向用户提供 root、系统级或其他用户进程；如果当前用户端口无法读取，会在界面中显示扫描错误，而不是将结果误显示为空列表。

## 开发构建

要求：

- macOS
- Xcode
- SwiftUI

在仓库根目录执行：

```sh
xcodebuild \
  -project RunStat.xcodeproj \
  -scheme RunStat \
  -sdk macosx \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

RunStat 是菜单栏应用，应用窗口使用 accessory application policy，不会在 Dock 中显示普通应用窗口。

## GitHub Actions 发布

Pull Request 和 `main` 分支推送会触发构建检查。

推送版本标签即可发布：

```sh
git tag v1.0.0
git push origin v1.0.0
```

Release workflow 会自动：

- 构建 arm64 + x86_64 Universal App
- 生成 `RunStat-<version>.zip`
- 生成 SHA-256 校验文件
- 创建 GitHub Release 并生成 Release Notes
- 生成可提交到 Homebrew 官方 Cask 的 `Casks/runstat.rb`

详细配置见 [HOMEBREW.md](HOMEBREW.md)。

## Homebrew 安装

RunStat 通过 Homebrew Cask 分发。自有 tap 配置完成后：

```sh
brew tap <组织>/homebrew-tap
brew install --cask runstat
```

Cask 模板位于 [`packaging/homebrew/Casks/runstat.rb`](packaging/homebrew/Casks/runstat.rb)。当前版本暂不签名和公证，正式公开分发前需要补充 Developer ID 签名与 Apple 公证。

## 权限与安全

- 仅允许结束当前用户拥有的进程。
- root、系统进程和其他用户进程不会进入列表，也不会提供结束权限。
- 当前用户的 launchd 托管进程结束后可能自动重启，界面会提前提示。
- SIGKILL 仅通过右键“结束进程”二级菜单提供，并在执行前明确提示不可恢复风险。
- 应用关闭后不会在后台持续运行或上传端口数据。

## 项目状态

RunStat 当前专注于本机 TCP / UDP 监听端口。容器名称映射、协议探测和更完整的服务识别会持续完善；项目识别依赖进程命令行和工作目录是否可读取。
