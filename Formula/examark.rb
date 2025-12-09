class Examark < Formula
  desc "Create exams from Markdown and export to Canvas QTI format"
  homepage "https://data-wise.github.io/examark/"
  url "https://registry.npmjs.org/examark/-/examark-0.6.5.tgz"
  sha256 "1453b778dc48342609f0a9eec02693b3ccd7e3e4ee0c63e9433dd0ca19381a99"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "0.6.5", shell_output("#{bin}/examark --version")
  end
end
