class McpBridge < Formula
  desc "MCP Bridge - Connect Claude.ai to local MCP servers via SSE"
  homepage "https://data-wise.github.io/mcp-bridge/"
  head "https://github.com/Data-Wise/mcp-bridge.git", branch: "dev"
  license "MIT"

  depends_on "node"

  def install
    # Install server dependencies
    cd "packages/server" do
      system "npm", "install", *Language::Node.std_npm_install_args(libexec)
      bin.install_symlink Dir["#{libexec}/bin/*"]
    end
  end

  service do
    run [opt_bin/"node", libexec/"lib/node_modules/@mcp-bridge/server/server.js"]
    keep_alive true
    working_dir var/"log/mcp-bridge"
    log_path var/"log/mcp-bridge/server.log"
    error_log_path var/"log/mcp-bridge/server.err.log"
    environment_variables PATH: std_service_path_env
  end

  def caveats
    <<~EOS
      The MCP Bridge server is installed.
      
      To start the bridge as a background service:
        brew services start mcp-bridge
      
      To check the status:
        mcp-bridge status
        
      The Chrome extension must be installed separately from the source code
      or loaded manually in your browser.
    EOS
  end

  test do
    assert_match "MCP Bridge Server", shell_output("#{bin}/mcp-bridge --help", 1)
  end
end
