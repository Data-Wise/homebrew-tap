# typed: false
# frozen_string_literal: true

# Examark formula for the data-wise/tap Homebrew tap.
class Examark < Formula
  desc "Create exams from Markdown and export to Canvas QTI format"
  homepage "https://data-wise.github.io/examark/"
  url "https://registry.npmjs.org/examark/-/examark-0.6.6.tgz"
  sha256 "3eef8418a16db3e41dab3cdebf6f6b92d21d30eafa6727063bc21c05241181c1"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "0.6.6", shell_output("#{bin}/examark --version")
  end
end
