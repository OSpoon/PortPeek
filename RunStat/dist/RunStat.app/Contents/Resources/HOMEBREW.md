# Homebrew 分发

## 发布流程

1. 合并代码到 `main`。
2. 创建并推送版本标签，例如：

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. `Release macOS app` 会自动构建 Universal macOS App，生成 ZIP、SHA-256 和 GitHub Release。

每次 Release 会在构件中生成已经填好版本号和 SHA-256 的 `Casks/runstat.rb`。将它复制到 Homebrew 的 `Casks/` 目录后提交官方 Cask PR。

Homebrew Cask 模板位于 `packaging/homebrew/Casks/runstat.rb`。正式 Cask 应把 `version` 和 `sha256` 更新为 Release 产物的实际值：

```ruby
cask "runstat" do
  version "1.0.0"
  sha256 "<dist/RunStat-1.0.0.sha256 的内容>"

  url "https://github.com/OSpoon/RunStat/releases/download/v#{version}/RunStat-#{version}.zip"
  name "RunStat"
  desc "Lightweight macOS menu bar monitor for listening TCP and UDP ports"
  homepage "https://github.com/OSpoon/RunStat"

  app "RunStat.app"
end
```

在官方 Cask PR 合并后，用户可以直接安装：

```sh
brew install --cask runstat
```

## 签名状态

当前阶段暂不配置 Apple Developer 签名和公证。Release 产物是未签名 ZIP，适合内部测试和早期分发；后续接入 Developer ID 后，再将签名、公证加入 Release gate。

## Homebrew 官方仓库

官方发布需要向 `Homebrew/homebrew-cask` 提交 Cask PR。Homebrew 要求使用开发者公开发布的下载地址、版本化 URL 和 SHA-256，并通过 `brew audit --new --cask` / `brew lgtm --online` 等检查。参考[官方添加软件流程](https://docs.brew.sh/Adding-Software-to-Homebrew)和[官方 PR 流程](https://docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request)。
