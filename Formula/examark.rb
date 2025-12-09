class Examark < Formula
  desc "Create exams from Markdown and export to Canvas QTI format"
  homepage "https://data-wise.github.io/examark/"
  url "https://registry.npmjs.org/examark/-/examark-0.6.0.tgz"
  sha256 "07582e3f317cb409c4a4fbedf5b7fac7c6d86f68c976018e0f1c4168ad49e57b"
  license "MIT"

  depends_on "node"

  def install
    system "npm", "install", *Language::Node.std_npm_install_args(libexec)
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    assert_match "0.6.0", shell_output("#{bin}/examark --version")
  end
end
