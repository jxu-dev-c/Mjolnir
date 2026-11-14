#!/usr/bin/env bash
# Print the Homebrew cask for a release; CI writes it to jxu-dev-c/homebrew-tap as Casks/mjolnir.rb.
#
#   scripts/render-cask.sh VERSION SHA256
set -euo pipefail

VERSION="${1:?usage: render-cask.sh VERSION SHA256}"
SHA256="${2:?usage: render-cask.sh VERSION SHA256}"

cat <<CASK
cask "mjolnir" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/jxu-dev-c/Mjolnir/releases/download/v#{version}/Mjolnir-#{version}.zip"
  name "Mjolnir"
  desc "Desktop app for herdr-core agent terminals"
  homepage "https://github.com/jxu-dev-c/Mjolnir"

  depends_on arch: :arm64
  depends_on :macos

  app "Mjolnir.app"
  binary "#{appdir}/Mjolnir.app/Contents/MacOS/Mjolnir", target: "herdr-app"

  # signed with a self-signed identity, not notarized
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Mjolnir.app"],
                          writable_paths: ["Mjolnir.app"], writable_base: :appdir
  end

  uninstall quit: "com.jasonxu.mjolnir"

  # ~/.config/herdr-app is left alone: upstream Herdr may share it.
  zap trash: "~/Library/Preferences/com.jasonxu.mjolnir.plist"
end
CASK
