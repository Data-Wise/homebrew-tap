# typed: false
# frozen_string_literal: true

# Connect Claude.ai to local MCP servers via SSE
class McpBridge < Formula
  desc "Connect Claude.ai to local MCP servers via SSE"
  homepage "https://data-wise.github.io/mcp-bridge/"
  url "https://github.com/Data-Wise/mcp-bridge/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "b1e0b46e58e0a8714bc7893498231bfe1e5e0dde670f7bb55d3d998aa0ff939e"
  license "MIT"
  head "https://github.com/Data-Wise/mcp-bridge.git", branch: "dev"

  depends_on "node"

  def install
    # Install the server package to libexec
    cd "packages/server" do
      # Copy server files to libexec
      libexec.install Dir["*"]

      # Install node_modules in libexec
      cd libexec do
        system "npm", "install", *std_npm_args(prefix: false)
      end

      # Create bin wrapper for mcp-bridge CLI
      (bin/"mcp-bridge").write <<~EOS
        #!/bin/bash
        exec "#{libexec}/mcp-bridge" "$@"
      EOS

      # Create bin wrapper for server
      (bin/"mcp-bridge-server").write <<~EOS
        #!/bin/bash
        exec node "#{libexec}/server.js" "$@"
      EOS
    end

    # Make bin scripts executable
    chmod 0755, bin/"mcp-bridge"
    chmod 0755, bin/"mcp-bridge-server"
  end

  service do
    run [opt_bin/"mcp-bridge-server"]
    keep_alive true
    working_dir var/"mcp-bridge"
    log_path var/"log/mcp-bridge/server.log"
    error_log_path var/"log/mcp-bridge/server.err.log"
    environment_variables PATH: std_service_path_env
  end

  def post_install
    # Create config directory and default config
    config_dir = etc/"mcp-bridge"
    config_dir.mkpath

    unless (config_dir/"config.json").exist?
      (config_dir/"config.json").write <<~EOS
        {
          "servers": []
        }
      EOS
    end

    # Create log directory
    (var/"log/mcp-bridge").mkpath
    (var/"mcp-bridge").mkpath
  end

  def caveats
    <<~EOS
      MCP Bridge has been installed!

      Configuration file: #{etc}/mcp-bridge/config.json

      To start the bridge as a background service:
        brew services start mcp-bridge

      To check the status:
        brew services info mcp-bridge
        mcp-bridge status

      To view logs:
        tail -f #{var}/log/mcp-bridge/server.log

      The Chrome extension must be installed separately.
      See: https://data-wise.github.io/mcp-bridge/
    EOS
  end

  test do
    # Test that the server starts and responds
    _port = free_port
    pid = fork do
      exec bin/"mcp-bridge-server"
    end

    sleep 2

    begin
      output = shell_output("curl -s http://localhost:3000/health")
      assert_match "sessions", output
    ensure
      Process.kill("TERM", pid)
      Process.wait(pid)
    end
  end
end
