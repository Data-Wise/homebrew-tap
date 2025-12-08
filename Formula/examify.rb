class Examify < Formula
  desc "Create exams from Markdown and export to Canvas QTI format"
  homepage "https://data-wise.github.io/examify/"
  url "https://registry.npmjs.org/examify/-/examify-0.4.2.tgz"
  sha256 "e6776edb48b3fa2169d3f693f8fe6befc79f1fcfe2cc1fcb04aff69b83e21fd5"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "0.4.2", shell_output("#{bin}/examify --version")
  end
end
