cask "portpeek" do
  version "0.0.0"
  sha256 :no_check

  url "https://github.com/OSpoon/PortPeek/releases/download/v#{version}/PortPeek-#{version}.zip"
  name "PortPeek"
  desc "Lightweight macOS menu bar monitor for listening TCP and UDP ports"
  homepage "https://github.com/OSpoon/PortPeek"

  app "PortPeek.app"
end
