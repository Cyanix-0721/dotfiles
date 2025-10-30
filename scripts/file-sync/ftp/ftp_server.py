"""Interactive cross-platform FTP server / 交互式跨平台 FTP 服务器。

This script provides a lightweight, temporary FTP server using pyftpdlib.
本脚本使用 pyftpdlib 提供轻量级临时 FTP 服务器。

Features / 功能:
- Interactive directory selection / 交互式目录选择
- Pure Python implementation (no system user required) / 纯 Python 实现（无需系统用户）
- Configurable passive port range / 可配置被动模式端口范围
- Cross-platform (Windows/Linux/macOS) / 跨平台支持（Windows/Linux/macOS）
- No admin/root privileges required / 无需管理员权限

Dependencies / 依赖:
    pip install pyftpdlib
"""

from __future__ import annotations

import signal
import sys
from pathlib import Path
from typing import Tuple

try:
    from pyftpdlib.authorizers import DummyAuthorizer
    from pyftpdlib.handlers import FTPHandler
    from pyftpdlib.servers import FTPServer
except ImportError as exc:
    print("[ERROR] pyftpdlib is required. Install it with 'pip install pyftpdlib'.")
    raise SystemExit(1) from exc

# Allow importing the shared configuration.
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from config import DEFAULT_ACCOUNT  # type: ignore  # noqa: E402

DEFAULT_PORT = 2121
DEFAULT_PASSIVE_RANGE = (60000, 60100)

# Preset roots for quick selection
PRESET_ROOTS = {
    "1": ("User Home", lambda: Path.home()),
    "2": ("Custom Path", None),
}


def _interactive_select_directory() -> Path:
    """Interactive directory selection / 交互式选择目录。"""
    print("\n" + "=" * 60)
    print("Select FTP Root Directory / 选择 FTP 根目录")
    print("=" * 60)

    for key, (name, resolver) in PRESET_ROOTS.items():
        if resolver:
            path = resolver()
            default_marker = " (default)" if key == "1" else ""
            print(f"{key}. {name}{default_marker}: {path}")
        else:
            print(f"{key}. {name}")

    while True:
        choice = input("\nEnter your choice (1/2): ").strip()

        # Default to option 1 (User Home) if empty input
        if choice == "":
            choice = "1"

        if choice in PRESET_ROOTS:
            name, resolver = PRESET_ROOTS[choice]
            if resolver:
                path = resolver()
                print(f"Selected: {path}")
                return path
            else:
                # Custom path
                while True:
                    custom = input("Enter custom path / 输入自定义路径: ").strip()
                    if custom:
                        path = Path(custom).expanduser().resolve()
                        confirm = input(f"Confirm path: {path} (y/n)? ").strip().lower()
                        if confirm == "y":
                            return path
        else:
            print("[ERROR] Invalid choice. Please enter 1 or 2.")


def _interactive_get_address() -> Tuple[str, int]:
    """Interactive get bind address and port / 交互式获取绑定地址和端口。"""
    print("\n" + "=" * 60)
    print("Server Network Configuration / 服务器网络配置")
    print("=" * 60)

    default_host = "0.0.0.0"
    host_input = input(f"Bind address (default: {default_host}) / 绑定地址: ").strip()
    host = host_input if host_input else default_host

    default_port = DEFAULT_PORT
    while True:
        port_input = input(f"Port (default: {default_port}) / 端口: ").strip()
        if not port_input:
            port = default_port
            break
        try:
            port = int(port_input)
            if 1 <= port <= 65535:
                break
            print("[ERROR] Port must be between 1 and 65535.")
        except ValueError:
            print("[ERROR] Invalid port number.")

    return host, port


def _interactive_passive_ports() -> Tuple[int, int]:
    """Interactive passive port range selection / 交互式选择被动模式端口范围。"""
    print("\n" + "=" * 60)
    print("FTP Passive Port Range / FTP 被动模式端口范围")
    print("=" * 60)
    default_start, default_end = DEFAULT_PASSIVE_RANGE
    print(f"Default range / 默认范围: {default_start}-{default_end}")
    print("Press Enter to accept defaults / 直接回车使用默认值")

    while True:
        start_input = input("Passive range start / 起始端口: ").strip()
        end_input = input("Passive range end / 结束端口: ").strip()

        if not start_input and not end_input:
            return default_start, default_end

        try:
            start = int(start_input) if start_input else default_start
            end = int(end_input) if end_input else default_end
        except ValueError:
            print("[ERROR] Invalid port number. Please enter integers.")
            continue

        if not (1 <= start <= 65535 and 1 <= end <= 65535):
            print("[ERROR] Ports must be between 1 and 65535.")
            continue

        if start > end:
            print("[ERROR] Start port must be less than or equal to end port.")
            continue

        return start, end


def _ensure_password(password: str) -> None:
    """Ensure a password is available for FTP login."""
    if password == "":
        print("\n[ERROR] FTP requires a password-based login.")
        print("[ERROR] Please configure FILESYNC_PASSWORD or update config.py.")
        sys.exit(1)


def _create_authorizer(username: str, password: str, home: Path) -> DummyAuthorizer:
    """Create an in-memory authorizer with a single user."""
    authorizer = DummyAuthorizer()
    perms = "elradfmwMT"  # Full permissions for read/write and directory ops
    authorizer.add_user(username, password, str(home), perm=perms)
    return authorizer


def _run_server(
    root: Path,
    host: str,
    port: int,
    passive_start: int,
    passive_end: int,
    username: str,
    password: str,
) -> None:
    """Start FTP server with application-level authentication."""
    root.mkdir(parents=True, exist_ok=True)

    authorizer = _create_authorizer(username, password, root)
    handler_cls = FTPHandler
    handler_cls.authorizer = authorizer
    handler_cls.passive_ports = range(passive_start, passive_end + 1)  # type: ignore[assignment]
    handler_cls.banner = "Temporary FTP service ready."  # Simple status banner

    address = (host, port)
    server = FTPServer(address, handler_cls)

    print("\n" + "=" * 60)
    print("FTP Server Started / FTP 服务器已启动")
    print("=" * 60)
    print(f"  Address / 地址: {host}:{port}")
    print(f"  Root Directory / 根目录: {root}")
    print(f"  Username / 用户名: {username}")
    print(f"  Password / 密码: {'*' * len(password)}")
    print(f"  Passive Ports / 被动端口: {passive_start}-{passive_end}")
    print("  Mode / 模式: FTP")
    print("\nPress Ctrl+C to stop the server / 按 Ctrl+C 停止服务器")
    print("=" * 60)

    # Use polling loop for better Ctrl+C handling on Windows
    running = True

    def signal_handler(sig: int, frame: object) -> None:
        nonlocal running
        running = False
        print("\n[INFO] Shutting down server... / 正在关闭服务器...")

    signal.signal(signal.SIGINT, signal_handler)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, signal_handler)

    try:
        while running:
            # Serve with timeout to allow checking running flag
            server.serve_forever(timeout=1, blocking=False)
    except Exception as e:
        print(f"\n[ERROR] Server error: {e}")
    finally:
        print("[INFO] Closing all connections... / 正在关闭所有连接...")
        server.close_all()
        print("[INFO] Server stopped / 服务器已停止")


def main() -> None:
    """Main entry point / 主入口。"""
    print("=" * 60)
    print("Interactive FTP Server / 交互式 FTP 服务器")
    print("=" * 60)

    username = DEFAULT_ACCOUNT.username
    password = DEFAULT_ACCOUNT.password

    print("\nAuthentication Configuration / 认证配置")
    print(f"  Username / 用户名: {username}")
    if password:
        print("  Password / 密码: Configured / 已配置")
    else:
        print("  Password / 密码: Not configured / 未配置")

    _ensure_password(password)

    root = _interactive_select_directory()
    host, port = _interactive_get_address()
    passive_start, passive_end = _interactive_passive_ports()

    _run_server(
        root=root,
        host=host,
        port=port,
        passive_start=passive_start,
        passive_end=passive_end,
        username=username,
        password=password,
    )


if __name__ == "__main__":
    main()
