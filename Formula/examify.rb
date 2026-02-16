# typed: false
# frozen_string_literal: true

# Examify formula for the data-wise/tap Homebrew tap.
class Examify < Formula
  desc "DEPRECATED: Use examark instead - Create exams from Markdown"
  homepage "https://data-wise.github.io/examark/"
  url "https://registry.npmjs.org/examify/-/examify-0.5.0.tgz"
  sha256 "e6776edb48b3fa2169d3f693f8fe6befc79f1fcfe2cc1fcb04aff69b83e21fd5"
  license "MIT"

  deprecate! date: "2025-12-09", because: "renamed to examark"

  depends_on "node"

  def install
    opoo "examify has been renamed to examark. Please run: brew install data-wise/tap/examark"
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/examify --version")
  end
end
