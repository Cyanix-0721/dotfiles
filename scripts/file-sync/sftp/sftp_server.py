"""Interactive cross-platform SFTP server / 交互式跨平台 SFTP 服务器。

This script provides a lightweight, temporary SFTP server using asyncssh.
本脚本提供基于 asyncssh 的轻量级临时 SFTP 服务器。

Features / 功能:
- Interactive directory selection / 交互式目录选择
- Pure Python implementation (no system user required) / 纯 Python 实现（无需系统用户）
- Password and public key authentication / 密码和公钥认证
- Cross-platform (Windows/Linux/macOS) / 跨平台支持（Windows/Linux/macOS）
- No admin/root privileges required / 无需管理员权限

Dependencies / 依赖:
    pip install asyncssh

Authentication / 认证:
- Password auth: Validates against config.py credentials / 密码认证：验证 config.py 中的凭据
- Public key auth: Validates against configured public key file / 公钥认证：验证配置的公钥文件
- Both methods work at application level (no system user needed) / 两种方式都在应用层验证（无需系统用户）
"""

from __future__ import annotations

import asyncio
import os
import signal
import stat
import sys
from pathlib import Path
from typing import Optional

try:
    import asyncssh
except ImportError as exc:
    print("[ERROR] asyncssh is required. Install it with 'pip install asyncssh'.")
    raise SystemExit(1) from exc

# Allow importing the shared configuration.
SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR.parent))

from config import DEFAULT_ACCOUNT  # type: ignore  # noqa: E402

DEFAULT_PORT = 8022
DEFAULT_HOST_KEY_PATH = SCRIPT_DIR / "host_ed25519"

# Preset roots for quick selection
PRESET_ROOTS = {
    "1": ("User Home", lambda: Path.home()),
    "2": ("Custom Path", None),
}


class SimpleSSHServer(asyncssh.SSHServer):
    """Minimal SSH server with application-level authentication.

    This server does NOT rely on system users. Authentication is handled
    purely at the application level by asyncssh.

    应用层认证的最小 SSH 服务器。
    本服务器不依赖系统用户，认证完全由 asyncssh 在应用层处理。
    """

    def __init__(
        self,
        allowed_username: str,
        allowed_password: str,
        allowed_keys: list[asyncssh.SSHKey],
    ) -> None:
        self._allowed_username = allowed_username
        self._allowed_password = allowed_password
        self._allowed_keys = allowed_keys

    def connection_made(self, conn: asyncssh.SSHServerConnection) -> None:
        self._conn = conn

    def begin_auth(self, username: str) -> bool:
        """Check if username is allowed to attempt authentication.

        This only validates the username format, actual password/key
        validation happens in the authenticator callbacks.

        仅验证用户名格式，实际的密码/密钥验证在认证回调中进行。
        """
        return username == self._allowed_username

    def password_auth_supported(self) -> bool:
        """Return whether password authentication is supported.

        返回是否支持密码认证。
        """
        return self._allowed_password != ""

    def validate_password(self, username: str, password: str) -> bool:
        """Validate password at application level.

        This function is called by asyncssh when a client attempts password auth.
        It simply compares the provided password with the one from config.py.
        NO system user validation involved!

        应用层密码验证。
        当客户端尝试密码认证时，asyncssh 调用此函数。
        它只是将提供的密码与 config.py 中的密码进行比较。
        不涉及系统用户验证！
        """
        if username != self._allowed_username:
            return False
        return password == self._allowed_password and password != ""

    def public_key_auth_supported(self) -> bool:
        """Return whether public key authentication is supported.

        返回是否支持公钥认证。
        """
        return len(self._allowed_keys) > 0

    def validate_public_key(self, username: str, key: asyncssh.SSHKey) -> bool:
        """Validate public key at application level.

        This function is called by asyncssh when a client attempts public key auth.
        It checks if the client's key matches any key in our allowed list.
        NO ~/.ssh/authorized_keys or system user involved!

        应用层公钥验证。
        当客户端尝试公钥认证时，asyncssh 调用此函数。
        它检查客户端的密钥是否在我们的允许列表中。
        不涉及 ~/.ssh/authorized_keys 或系统用户！
        """
        if username != self._allowed_username:
            return False
        return any(key == allowed for allowed in self._allowed_keys)


def _set_secure_permissions(path: Path) -> None:
    """Set secure permissions for private key file (cross-platform).

    设置私钥文件的安全权限（跨平台）。

    - Linux/macOS: Set to 0o600 (owner read/write only)
    - Windows: Set read-only for current user
    """
    try:
        if sys.platform == "win32":
            # Windows: Use icacls or just set read-only attribute
            # os.chmod on Windows has limited functionality
            os.chmod(path, stat.S_IREAD | stat.S_IWRITE)
        else:
            # Linux/macOS: Standard Unix permissions
            os.chmod(path, 0o600)
    except Exception as e:
        # Don't fail if we can't set permissions
        print(f"[WARN] Could not set secure permissions: {e}")


def _ensure_host_key(path: Path) -> tuple[asyncssh.SSHKey | str, bool]:
    """Ensure host key exists with user choice / 确保主机密钥存在（用户选择）。

    Returns:
        tuple: (key_or_path, is_temporary)
            - If persistent: (str path, False)
            - If temporary: (SSHKey object, True)
    """
    path = path.expanduser().resolve()
    path.parent.mkdir(parents=True, exist_ok=True)

    if path.exists():
        print(f"\n[INFO] Found existing host key / 发现已有主机密钥: {path}")

        # Try to load the private key (may require passphrase)
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                # First try without passphrase
                if attempt == 1:
                    try:
                        key = asyncssh.read_private_key(str(path))
                        # Successfully loaded without passphrase
                        fingerprint = key.convert_to_public().get_fingerprint()
                        print(f"[INFO] Fingerprint / 指纹: {fingerprint}")
                        return str(path), False
                    except asyncssh.KeyEncryptionError:
                        # Key is encrypted, need passphrase
                        print(
                            "[INFO] This key is protected by a passphrase / 此密钥受密码短语保护"
                        )

                # Ask for passphrase
                import getpass

                passphrase = getpass.getpass(
                    f"Enter passphrase for {path.name} (attempt {attempt}/{max_attempts}) / "
                    f"输入 {path.name} 的密码短语 (第 {attempt}/{max_attempts} 次): "
                )

                # Try to load with passphrase
                key = asyncssh.read_private_key(str(path), passphrase=passphrase)
                fingerprint = key.convert_to_public().get_fingerprint()
                print("[SUCCESS] Key loaded successfully / 密钥加载成功")
                print(f"[INFO] Fingerprint / 指纹: {fingerprint}")
                return str(path), False

            except asyncssh.KeyEncryptionError:
                if attempt < max_attempts:
                    print("[ERROR] Incorrect passphrase / 密码短语错误")
                else:
                    print(
                        f"[ERROR] Failed to load key after {max_attempts} attempts / {max_attempts} 次尝试后加载密钥失败"
                    )
                    print(
                        "[ERROR] Please check your passphrase or use a different key / 请检查密码短语或使用其他密钥"
                    )
                    sys.exit(1)
            except Exception as e:
                print(f"[ERROR] Failed to load key: {e} / 加载密钥失败: {e}")
                sys.exit(1)

        return str(path), False

    # No existing key - ask user
    print(f"\n[INFO] No host key found / 未找到主机密钥: {path}")
    print("[INFO] SSH/SFTP server requires a host key for:")
    print("       - Establishing encrypted connections / 建立加密连接")
    print("       - Server identity verification / 服务器身份验证")
    print("\n[INFO] You can choose / 您可以选择：")
    print("       1. Temporary key (memory only, default) / 临时密钥（仅内存，默认）")
    print("          Benefit / 优点: No files created / 不创建文件")
    print("          Note / 注意: New fingerprint each time / 每次指纹不同")
    print("       2. Persistent key (saved to disk) / 持久化密钥（保存到磁盘）")
    print(f"          Location / 位置: {path}")
    print("          Benefit / 优点: Same fingerprint on restart / 重启后指纹不变")

    while True:
        choice = input("\nChoose key type (1/2): ").strip()

        if choice in ["1", ""]:  # Temporary (default)
            print(
                "[INFO] Generating temporary ED25519 host key (memory only) / 正在生成临时 ED25519 主机密钥（仅内存）..."
            )
            key = asyncssh.generate_private_key("ssh-ed25519")
            fingerprint = key.convert_to_public().get_fingerprint()

            print("[SUCCESS] Temporary host key generated / 临时主机密钥已生成")
            print(f"[INFO] Fingerprint / 指纹: {fingerprint}")
            print(
                "[WARN] This key will be discarded when server stops / 服务器停止后此密钥将被丢弃"
            )
            print("[WARN] Clients will see a different fingerprint on next run.")
            print("[警告] 下次运行客户端会看到不同的指纹。")

            return key, True

        elif choice == "2":  # Persistent
            # Ask if user wants passphrase protection
            use_passphrase = (
                input(
                    "\nProtect key with passphrase? (y/n (default)) / 用密码短语保护密钥？(y/n (默认)): "
                )
                .strip()
                .lower()
            )

            passphrase = None
            if use_passphrase == "y":
                import getpass

                while True:
                    passphrase = getpass.getpass("Enter passphrase / 输入密码短语: ")
                    if not passphrase:
                        print(
                            "[WARN] Empty passphrase, key will not be encrypted / 密码短语为空，密钥将不加密"
                        )
                        passphrase = None
                        break

                    passphrase_confirm = getpass.getpass(
                        "Confirm passphrase / 确认密码短语: "
                    )
                    if passphrase == passphrase_confirm:
                        print("[INFO] Passphrase set / 密码短语已设置")
                        break
                    else:
                        print(
                            "[ERROR] Passphrases do not match, please try again / 密码短语不匹配，请重试"
                        )

            print(
                "[INFO] Generating persistent ED25519 host key / 正在生成持久化 ED25519 主机密钥..."
            )
            key = asyncssh.generate_private_key("ssh-ed25519")

            # Export with or without passphrase
            if passphrase:
                private_key_data = key.export_private_key(passphrase=passphrase)
                print("[INFO] Key encrypted with passphrase / 密钥已用密码短语加密")
            else:
                private_key_data = key.export_private_key()

            path.write_bytes(private_key_data)
            _set_secure_permissions(path)

            pub_path = path.with_suffix(path.suffix + ".pub")
            pub_path.write_bytes(key.export_public_key())

            fingerprint = key.convert_to_public().get_fingerprint()
            print(f"[SUCCESS] Persistent host key saved / 持久化主机密钥已保存: {path}")
            print(f"[INFO] Fingerprint / 指纹: {fingerprint}")
            print(
                "[INFO] This key will be automatically detected and reused on next run"
            )
            print("[INFO] 下次运行时会自动检测并复用此密钥（除非删除文件）")
            print(
                "[INFO] To regenerate, delete the file first / 如需重新生成，请先删除该文件"
            )
            print("[INFO] Clients will see this fingerprint on first connection.")
            print("[INFO] 客户端首次连接时会看到此指纹。")

            return str(path), False

        else:
            print(
                "[ERROR] Invalid choice. Please enter '1' or '2' / 无效选择，请输入 '1' 或 '2'。"
            )


def _load_public_keys(public_key_path: Path | None) -> list[asyncssh.SSHKey]:
    """Load authorized public keys for authentication.

    These keys are used for application-level public key authentication,
    completely independent of system's ~/.ssh/authorized_keys.

    加载用于认证的公钥。
    这些密钥用于应用层公钥认证，完全独立于系统的 ~/.ssh/authorized_keys。
    """
    if not public_key_path:
        return []
    expanded = public_key_path.expanduser().resolve()
    if not expanded.exists():
        print(f"[WARN] Public key file not found: {expanded}")
        return []
    try:
        key = asyncssh.read_public_key(str(expanded))
    except (OSError, asyncssh.Error) as exc:
        print(f"[WARN] Failed to load public key {expanded}: {exc}")
        return []
    return [key]


def _interactive_select_directory() -> Path:
    """Interactive directory selection / 交互式选择目录。"""
    print("\n" + "=" * 60)
    print("Select SFTP Root Directory / 选择 SFTP 根目录")
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


def _interactive_get_address() -> tuple[str, int]:
    """Interactive get bind address and port / 交互式获取绑定地址和端口。"""
    print("\n" + "=" * 60)
    print("Server Network Configuration / 服务器网络配置")
    print("=" * 60)

    # Get bind address
    default_host = "0.0.0.0"
    host_input = input(f"Bind address (default: {default_host}) / 绑定地址: ").strip()
    host = host_input if host_input else default_host

    # Get port
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
            else:
                print("[ERROR] Port must be between 1 and 65535.")
        except ValueError:
            print("[ERROR] Invalid port number.")

    return host, port


async def _run_server(
    root: Path,
    host: str,
    port: int,
    username: str,
    password: str,
    public_key_path: Optional[Path],
) -> None:
    """Start SFTP server with application-level authentication.

    Authentication flow:
    1. Client connects and provides username
    2. Server checks if username matches (begin_auth in SimpleSSHServer)
    3. Client attempts authentication:
       - Password: password_authenticator validates the password string
       - Public key: public_key_authenticator validates the key against allowed keys
    4. If authenticated, client gets SFTP access to the chroot directory

    All authentication happens in Python code - NO system user account needed!

    启动带应用层认证的 SFTP 服务器。

    认证流程：
    1. 客户端连接并提供用户名
    2. 服务器检查用户名是否匹配（SimpleSSHServer 的 begin_auth）
    3. 客户端尝试认证：
       - 密码：password_authenticator 验证密码字符串
       - 公钥：public_key_authenticator 验证密钥是否在允许列表中
    4. 认证成功后，客户端获得对 chroot 目录的 SFTP 访问权限

    所有认证都在 Python 代码中完成 - 不需要系统用户账户！
    """
    root.mkdir(parents=True, exist_ok=True)

    host_key_data, is_temporary = _ensure_host_key(DEFAULT_HOST_KEY_PATH)

    allowed_keys = _load_public_keys(public_key_path)
    allow_password = password != ""

    if not allow_password and not allowed_keys:
        raise SystemExit("[ERROR] No authentication method is configured.")

    server_kwargs = {
        "server_factory": lambda: SimpleSSHServer(username, password, allowed_keys),
        "host": host,
        "port": port,
        "server_host_keys": [host_key_data],  # Can be SSHKey object or str path
        "sftp_factory": lambda _conn: asyncssh.SFTPServer(
            _conn, chroot=str(root).encode()
        ),
    }

    server = await asyncssh.create_server(**server_kwargs)

    print("\n" + "=" * 60)
    print("SFTP Server Started / SFTP 服务器已启动")
    print("=" * 60)
    print(f"  Address / 地址: {host}:{port}")
    print(f"  Root Directory / 根目录: {root}")
    print(f"  Username / 用户名: {username}")
    if allow_password:
        print(f"  Password / 密码: {'*' * len(password)}")
        print("  Auth Method / 认证方式: Password (application-level) / 密码（应用层）")
    if allowed_keys:
        print(f"  Authorized Keys / 授权密钥: {len(allowed_keys)} key(s)")
        print(
            "  Auth Method / 认证方式: Public key (application-level) / 公钥（应用层）"
        )

    # Display host key information
    if is_temporary:
        print("  Host Key / 主机密钥: Temporary (memory only) / 临时（仅内存）")
        # host_key_data is SSHKey object for temporary keys
        if isinstance(host_key_data, asyncssh.SSHKey):
            fingerprint = host_key_data.convert_to_public().get_fingerprint()
            print(f"  Host Key Fingerprint / 主机密钥指纹: {fingerprint}")
    else:
        # host_key_data is str path for persistent keys
        print(f"  Host Key / 主机密钥: {host_key_data}")
        if isinstance(host_key_data, str):
            try:
                pub_key_path = Path(host_key_data).with_suffix(
                    Path(host_key_data).suffix + ".pub"
                )
                if pub_key_path.exists():
                    pub_key = asyncssh.read_public_key(str(pub_key_path))
                    fingerprint = pub_key.get_fingerprint()
                    print(f"  Host Key Fingerprint / 主机密钥指纹: {fingerprint}")
            except Exception:
                pass

    print("\nPress Ctrl+C to stop the server / 按 Ctrl+C 停止服务器")
    print("=" * 60)

    # Setup signal handling for graceful shutdown
    loop = asyncio.get_event_loop()
    shutdown_event = asyncio.Event()

    def signal_handler(sig: int = 0, frame: object = None) -> None:
        print("\n[INFO] Shutting down server... / 正在关闭服务器...")
        shutdown_event.set()

    # Register signal handlers
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, signal_handler)
        except NotImplementedError:
            # Windows doesn't support add_signal_handler, use signal.signal instead
            signal.signal(sig, signal_handler)

    try:
        await shutdown_event.wait()
    except Exception as e:
        print(f"\n[ERROR] Server error: {e}")
    finally:
        print("[INFO] Closing all connections... / 正在关闭所有连接...")
        server.close()
        await server.wait_closed()
        print("[INFO] Server stopped / 服务器已停止")


def main() -> None:
    """Main entry point / 主入口。"""
    print("=" * 60)
    print("Interactive SFTP Server / 交互式 SFTP 服务器")
    print("=" * 60)

    # Get configuration from config.py
    username = DEFAULT_ACCOUNT.username
    password = DEFAULT_ACCOUNT.password
    public_key_path = DEFAULT_ACCOUNT.ssh_public_key

    print("\nAuthentication Configuration / 认证配置")
    print(f"  Username / 用户名: {username}")

    # Validate authentication methods
    has_password = password != ""
    has_pubkey = public_key_path is not None and public_key_path.exists()

    if has_password:
        print("  Password / 密码: Configured / 已配置")
    else:
        print("  Password / 密码: Not configured / 未配置")

    if has_pubkey:
        print(f"  Public Key / 公钥: {public_key_path}")
    else:
        print("  Public Key / 公钥: Not configured / 未配置")

    if not has_password and not has_pubkey:
        print("\n[ERROR] No authentication method available.")
        print("[ERROR] Please configure password or public key in config.py")
        sys.exit(1)

    print("\n[INFO] Using application-level authentication (no system user needed)")
    print("[INFO] 使用应用层认证（无需系统用户）")

    # Interactive configuration
    root = _interactive_select_directory()
    host, port = _interactive_get_address()

    # Start server
    try:
        asyncio.run(_run_server(root, host, port, username, password, public_key_path))
    except KeyboardInterrupt:
        # Additional fallback for KeyboardInterrupt
        pass


if __name__ == "__main__":
    main()
