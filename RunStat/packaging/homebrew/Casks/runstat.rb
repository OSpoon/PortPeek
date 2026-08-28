cask "runstat" do
  version "0.0.0"
  sha256 :no_check

  url "https://github.com/OSpoon/RunStat/releases/download/v#{version}/RunStat-#{version}.zip"
  name "RunStat"
  desc "Lightweight macOS menu bar monitor for listening TCP and UDP ports"
  homepage "https://github.com/OSpoon/RunStat"

  app "RunStat.app"
end

