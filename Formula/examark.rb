# typed: false
# frozen_string_literal: true

# Examark formula for the data-wise/tap Homebrew tap.
class Examark < Formula
  desc "Create exams from Markdown and export to Canvas QTI format"
  homepage "https://data-wise.github.io/examark/"
  url "https://registry.npmjs.org/examark/-/examark-0.7.0.tgz"
  sha256 "efd2677e6fa4c234c5f59b5b6303d30ad2eda6475d86e41893fb7999d493080d"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "0.7.0", shell_output("#{bin}/examark --version")
  end
end
