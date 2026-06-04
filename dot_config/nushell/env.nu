# env.nu
# Environment variables for Nushell
# See https://www.nushell.sh/book/configuration.html

# Add your environment variables here
# Example:
# $env.EDITOR = "nvim"
# $env.LANG = "en_US.UTF-8"

# 动态配置代理（如果可用）
def setup_proxy [] {
  let proxy_addr = "127.0.0.1"
  let proxy_port = 7897
  let proxy_url = $"http://($proxy_addr):($proxy_port)"
  
  # 检查操作系统
  let os = (sys).host.os_version
  
  if $os == "windows" {
    # Windows: 使用 PowerShell 测试连接
    try {
      let result = (
        powershell -NoProfile -Command $"
          (Test-NetConnection -ComputerName ($proxy_addr) -Port ($proxy_port) -WarningAction SilentlyContinue).TcpTestSucceeded
        " 2>/dev/null | str trim
      )
      if $result == "True" {
        $env.http_proxy = $proxy_url
        $env.https_proxy = $proxy_url
      }
    } catch {
      # 代理检查失败，保持直连
    }
  } else {
    # Linux/macOS: 使用 nc 或 timeout
    try {
      if (which nc | is-not-empty) {
        let _ = (nc -z $proxy_addr $proxy_port 2>/dev/null)
        if $env.LAST_EXIT_CODE == 0 {
          $env.http_proxy = $proxy_url
          $env.https_proxy = $proxy_url
        }
      } else if (which timeout | is-not-empty) {
        let _ = (timeout 1 bash -c $"echo >/dev/tcp/($proxy_addr)/($proxy_port)" 2>/dev/null)
        if $env.LAST_EXIT_CODE == 0 {
          $env.http_proxy = $proxy_url
          $env.https_proxy = $proxy_url
        }
      }
    } catch {
      # 代理检查失败，保持直连
    }
  }
}

setup_proxy
