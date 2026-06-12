# typed: false
# frozen_string_literal: true

# Obsidian CLI Ops formula for the data-wise/tap Homebrew tap.
#
# Approach A (v3.2.1): core Python deps are installed into an ISOLATED venv at
# libexec/venv via pinned `resource` blocks — never into ambient python@3.12.
# This fixes the v3.2.0 clean-install crash (ModuleNotFoundError: 'rich') and
# survives system-python upgrades. Regenerate resources with:
#   brew update-python-resources Formula/obsidian-cli-ops.rb
class ObsidianCliOps < Formula
  include Language::Python::Virtualenv

  desc "CLI tool for Obsidian vault management with AI-powered graph analysis"
  homepage "https://data-wise.github.io/obsidian-cli-ops/"
  url "https://github.com/Data-Wise/obsidian-cli-ops/archive/refs/tags/v3.2.2.tar.gz"
  sha256 "b4ddb572efbd49e720bb6d6f9bf080e49b4c4b1eaf1089b5ef6ebe07365184d6"
  license "MIT"
  head "https://github.com/Data-Wise/obsidian-cli-ops.git", branch: "main"

  depends_on "python@3.12"
  depends_on "zsh"
  depends_on "jq" => :optional

  # CORE deps pinned to requirements.lock, with real PyPI sdist URLs + sha256.
  #
  # RELEASE TODO: the transitive deps (markdown-it-py, mdurl, pygments, certifi,
  # idna, urllib3, charset-normalizer, ...) are NOT yet listed. A virtualenv
  # install needs the FULL tree, so before opening the PR run, from the tapped
  # clone after v3.2.1 is tagged:
  #   brew update-python-resources data-wise/tap/obsidian-cli-ops
  # then reconcile the 6 core versions below back to requirements.lock if pip
  # resolved anything newer.
  resource "python-frontmatter" do
    url "https://files.pythonhosted.org/packages/96/de/910fa208120314a12f9a88ea63e03707261692af782c99283f1a2c8a5e6f/python-frontmatter-1.1.0.tar.gz"
    sha256 "7118d2bd56af9149625745c58c9b51fb67e8d1294a0c76796dafdc72c36e5f6d"
  end

  resource "PyYAML" do
    url "https://files.pythonhosted.org/packages/05/8e/961c0007c59b8dd7729d542c61a4d537767a59645b82a0b521206e1e25c2/pyyaml-6.0.3.tar.gz"
    sha256 "d76623373421df22fb4cf8817020cbb7ef15c725b9d5e45f17e189bfc384190f"
  end

  resource "networkx" do
    url "https://files.pythonhosted.org/packages/6a/51/63fe664f3908c97be9d2e4f1158eb633317598cfa6e1fc14af5383f17512/networkx-3.6.1.tar.gz"
    sha256 "26b7c357accc0c8cde558ad486283728b65b6a95d85ee1cd66bafab4c8168509"
  end

  resource "rich" do
    url "https://files.pythonhosted.org/packages/fb/d2/8920e102050a0de7bfabeb4c4614a49248cf8d5d7a8d01885fbb24dc767a/rich-14.2.0.tar.gz"
    sha256 "73ff50c7c0c1c77c8243079283f4edb376f0f6442433aecb8ce7e6d0b92d1fe4"
  end

  resource "requests" do
    url "https://files.pythonhosted.org/packages/c9/74/b3ff8e6c8446842c3f5c837e9c3dfcfe2018ea6ecef224c710c85ef728f4/requests-2.32.5.tar.gz"
    sha256 "dbba0bac56e100853db0ea71b82b4dfd5fe2bf6d3754a8893c3af500cec7d7cf"
  end

  resource "click" do
    url "https://files.pythonhosted.org/packages/3d/fa/656b739db8587d7b5dfa22e22ed02566950fbfbcdc20311993483657a5c0/click-8.3.1.tar.gz"
    sha256 "12ff4785d337a1bb490bb7e9c2b1ee5da3112e94a8622f26a6c77f5d2fc6842a"
  end

  resource "certifi" do
    url "https://files.pythonhosted.org/packages/f3/ce/ee2ecad540810a79593028e88299baeae54d346cc7a0d94b6199988b89b1/certifi-2026.5.20.tar.gz"
    sha256 "69dea482ab64caa7b9f6aba1c6bf48bb6a5448d1c0f1b17ab42ad8c763a5344d"
  end
  resource "charset-normalizer" do
    url "https://files.pythonhosted.org/packages/e7/a1/67fe25fac3c7642725500a3f6cfe5821ad557c3abb11c9d20d12c7008d3e/charset_normalizer-3.4.7.tar.gz"
    sha256 "ae89db9e5f98a11a4bf50407d4363e7b09b31e55bc117b4f7d80aab97ba009e5"
  end
  resource "idna" do
    url "https://files.pythonhosted.org/packages/cd/63/9496c57188a2ee585e0f1db071d75089a11e98aa86eb99d9d7618fc1edce/idna-3.18.tar.gz"
    sha256 "ffb385a7e039654cef1ab9ef32c6fafe283c0c0467bba1d9029738ce4a14a848"
  end
  resource "markdown-it-py" do
    url "https://files.pythonhosted.org/packages/06/ff/7841249c247aa650a76b9ee4bbaeae59370dc8bfd2f6c01f3630c35eb134/markdown_it_py-4.2.0.tar.gz"
    sha256 "04a21681d6fbb623de53f6f364d352309d4094dd4194040a10fd51833e418d49"
  end
  resource "mdurl" do
    url "https://files.pythonhosted.org/packages/d6/54/cfe61301667036ec958cb99bd3efefba235e65cdeb9c84d24a8293ba1d90/mdurl-0.1.2.tar.gz"
    sha256 "bb413d29f5eea38f31dd4754dd7377d4465116fb207585f97bf925588687c1ba"
  end
  resource "pygments" do
    url "https://files.pythonhosted.org/packages/c3/b2/bc9c9196916376152d655522fdcebac55e66de6603a76a02bca1b6414f6c/pygments-2.20.0.tar.gz"
    sha256 "6757cd03768053ff99f3039c1a36d6c0aa0b263438fcab17520b30a303a82b5f"
  end
  resource "urllib3" do
    url "https://files.pythonhosted.org/packages/53/0c/06f8b233b8fd13b9e5ee11424ef85419ba0d8ba0b3138bf360be2ff56953/urllib3-2.7.0.tar.gz"
    sha256 "231e0ec3b63ceb14667c67be60f2f2c40a518cb38b03af60abc813da26505f4c"
  end

  def install
    bin.mkpath

    # Build the isolated venv and install ONLY the pinned deps (resources above).
    venv = virtualenv_create(libexec/"venv", "python3.12")
    venv.pip_install resources

    # Bundle the backend, schema, and zsh wrapper.
    (libexec/"src").install "src/python"
    libexec.install "schema"
    (libexec/"src").install "src/obs.zsh"

    # Launcher → isolated venv interpreter (matches obs.zsh resolution tier 1).
    (bin/"obs").write <<~EOS
      #!/bin/zsh
      # Obsidian CLI Ops launcher (Homebrew-installed)
      export OBS_PYTHON="#{libexec}/venv/bin/python"
      source "#{libexec}/src/obs.zsh"
      obs "$@"
    EOS
    (bin/"obs").chmod 0755

    # Essential docs
    prefix.install "README.md"
    prefix.install "LICENSE" if (buildpath/"LICENSE").exist?

    # Man page. Shipped from releases that include man/man1/obs.1 (added
    # 2026-06); absent from v3.2.1, so guard on existence to stay install-safe
    # on older tarballs and on --HEAD before the page is merged. Homebrew links
    # it onto MANPATH automatically, so `man obs` works after install.
    man1.install "man/man1/obs.1" if (buildpath/"man/man1/obs.1").exist?
  end

  def post_install
    # Initialize the database using the isolated interpreter (deps guaranteed).
    system libexec/"venv/bin/python", "#{libexec}/src/python/obs_cli.py", "db", "init"
  end

  def caveats
    <<~EOS
      Obsidian CLI Ops v#{version} installed!

      Quick start:
        obs                    # List your vaults
        obs discover <path>    # Find Obsidian vaults
        obs stats <vault>      # Show vault statistics
        obs analyze <vault>    # Analyze knowledge graph
        obs health <vault>     # Vault health dashboard

      AI features (optional):
        obs ai setup           # Interactive AI setup wizard
        obs ai status          # Check provider status

      Dependencies are isolated in an internal venv — no manual pip needed.

      Documentation: https://data-wise.github.io/obsidian-cli-ops/
    EOS
  end

  test do
    # Core files present.
    assert_path_exists bin/"obs"
    assert_path_exists libexec/"src/obs.zsh"
    assert_path_exists libexec/"src/python/obs_cli.py"
    assert_path_exists libexec/"schema/vault_db.sql"

    # Isolated venv has the deps (the v3.2.0 regression guard).
    system libexec/"venv/bin/python", "-c",
           "import frontmatter, yaml, networkx, rich, requests, click"

    # Version output through the real launcher.
    assert_match version.to_s, shell_output("#{bin}/obs version 2>&1")
  end
end
