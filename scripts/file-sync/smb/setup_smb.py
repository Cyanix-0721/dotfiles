"""
Simple Windows SMB share setup helper.
Run with administrator privileges.
用途：简化在 Windows 上创建/移除专用 SMB 帐号与共享。
Use this tool to create or remove a dedicated SMB account and its shares on Windows.
"""

from __future__ import annotations

import argparse
import ctypes
import os
import platform
import subprocess
import sys
from pathlib import Path

# 将上一级目录加入 sys.path 以便导入共享配置
# Add parent directory to sys.path for shared configuration import
SCRIPT_DIR = Path(__file__).resolve().parent
# Prevent creation of __pycache__ when importing shared config
sys.dont_write_bytecode = True
sys.path.insert(0, str(SCRIPT_DIR.parent))

from config import DEFAULT_ACCOUNT  # type: ignore  # noqa: E402

# ---------------------------------------------------------------------------
# Customisation (edit as needed)
# ---------------------------------------------------------------------------
# SMB authentication / SMB 认证信息（默认取自共享配置，可根据需要覆盖）
SMB_USER = DEFAULT_ACCOUNT.username
SMB_PASSWORD = DEFAULT_ACCOUNT.password

# Default access level / 默认访问权限（read=只读，change=读写）
DEFAULT_PERMISSION = "read"  # read or change

# Shares to publish / 需要发布的共享列表
SHARES = [
    {
        "path": r"D:\UserData\Videos",
        "name": "Videos",
        "description": "Video Library / 视频库",
    },
    {
        "path": r"D:\UserData\Pictures\Comics",
        "name": "Comics",
        "description": "Comic Library / 漫画库",
    },
]


VALID_PERMISSIONS = {"read": "READ", "change": "CHANGE"}


def ensure_windows() -> None:
    """Ensure script runs on Windows / 确认脚本运行在 Windows 系统"""
    if platform.system() != "Windows":
        print("[ERROR] Windows is required for this script.")
        sys.exit(1)


def require_admin() -> None:
    """Require elevation / 检查是否以管理员权限运行"""
    try:
        is_admin = ctypes.windll.shell32.IsUserAnAdmin()
    except Exception:
        is_admin = False
    if not is_admin:
        print("[ERROR] Run this script from an elevated PowerShell or CMD window.")
        sys.exit(1)


def run_command(
    command: str, check: bool = False, quiet: bool = False
) -> subprocess.CompletedProcess[str]:
    """Execute a shell command / 执行外部命令"""
    result = subprocess.run(command, shell=True, capture_output=True, text=True)
    if result.returncode != 0 and not quiet:
        print(f"[WARN] Command failed: {command}")
        if result.stdout.strip():
            print(result.stdout.strip())
        if result.stderr.strip():
            print(result.stderr.strip())
        if check:
            sys.exit(result.returncode)
    elif result.returncode != 0 and check:
        sys.exit(result.returncode)
    return result


def user_exists(username: str) -> bool:
    """Check whether user exists / 检查用户是否存在"""
    result = run_command(f"net user {username}", quiet=True)
    return result.returncode == 0


def hide_user(username: str) -> None:
    """Hide account from sign-in UI / 将账户从登录界面隐藏"""
    reg_path = "HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\SpecialAccounts\\UserList"
    run_command(f'reg add "{reg_path}" /v {username} /t REG_DWORD /d 0 /f')


def create_user(username: str, password: str) -> None:
    """Create or update SMB-only account / 创建或更新 SMB 专用账户"""
    if user_exists(username):
        print(f"[INFO] User {username} exists. Updating password.")
        run_command(f"net user {username} {password}", check=True)
    else:
        print(f"[INFO] Creating user {username}.")
        run_command(f"net user {username} {password} /add /y", check=True)
    run_command(f"net user {username} /active:yes")
    run_command(f"net user {username} /passwordchg:no")
    run_command(f'net localgroup "Users" {username} /add', quiet=True)
    run_command(f'net localgroup "Administrators" {username} /delete', quiet=True)
    hide_user(username)


def delete_user(username: str) -> None:
    """Remove SMB account if present / 若存在则删除 SMB 账户"""
    if not user_exists(username):
        print(f"[INFO] User {username} not present. Nothing to remove.")
        return
    print(f"[INFO] Deleting user {username}.")
    run_command(f"net user {username} /delete", check=True)


def share_exists(name: str) -> bool:
    """Check share presence / 检查共享是否存在"""
    result = run_command(f"net share {name}", quiet=True)
    return result.returncode == 0


def delete_share(name: str) -> None:
    """Remove an existing share / 删除已有共享"""
    if share_exists(name):
        print(f"[INFO] Removing share {name}.")
        run_command(f"net share {name} /delete /y", check=True)


def create_share(name: str, path: str, permission: str, description: str) -> None:
    """Create SMB share with requested permission / 创建指定权限的 SMB 共享"""
    os.makedirs(path, exist_ok=True)
    delete_share(name)
    perm_flag = VALID_PERMISSIONS[permission]
    desc_part = f' /remark:"{description}"' if description else ""
    command = f'net share {name}="{path}" /GRANT:{SMB_USER},{perm_flag} /CACHE:None{desc_part}'
    run_command(command, check=True)


def enable_firewall_rules() -> None:
    """Enable firewall group for SMB / 启用 SMB 所需的防火墙规则"""
    result = run_command(
        'netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes',
        quiet=True,
    )
    if result.returncode != 0:
        fallback = run_command(
            'netsh advfirewall firewall set rule group="文件和打印机共享" new enable=Yes',
            quiet=True,
        )
        if fallback.returncode != 0:
            print("[WARN] Could not enable the SMB firewall group automatically.")


def ensure_server_service() -> None:
    """Start/enable LanmanServer service / 确保 LanmanServer 服务已启用"""
    run_command("sc config lanmanserver start= auto")
    run_command("sc start lanmanserver", quiet=True)


def install(permission: str) -> None:
    """Install workflow / 安装流程：创建账户并发布共享"""
    permission = permission.lower()
    if permission not in VALID_PERMISSIONS:
        print(f"[ERROR] Unsupported permission level: {permission}")
        sys.exit(1)
    print("[STEP] Ensuring local SMB user is configured.")
    create_user(SMB_USER, SMB_PASSWORD)

    print("[STEP] Creating SMB shares.")
    for share in SHARES:
        create_share(
            name=share["name"],
            path=share["path"],
            permission=permission,
            description=share.get("description", ""),
        )

    print("[STEP] Enabling firewall group for SMB.")
    enable_firewall_rules()
    ensure_server_service()

    print("[DONE] SMB shares are ready:")
    computer = os.environ.get("COMPUTERNAME", "localhost")
    for share in SHARES:
        print(f"  \\{computer}\\{share['name']} -> {share['path']}")
    print(f"  User: {SMB_USER}")
    print(f"  Password: {SMB_PASSWORD}")
    print(f"  Permission: {permission}")


def uninstall() -> None:
    """Uninstall workflow / 卸载流程：移除共享与账户"""
    print("[STEP] Removing SMB shares.")
    for share in SHARES:
        delete_share(share["name"])

    print("[STEP] Removing SMB user.")
    delete_user(SMB_USER)
    print("[DONE] Cleanup finished.")


def parse_args() -> argparse.Namespace:
    """Parse CLI arguments / 解析命令行参数"""
    parser = argparse.ArgumentParser(
        description="Manage SMB shares for a dedicated account."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    install_parser = subparsers.add_parser(
        "install", help="Set up the SMB account and shares."
    )
    install_parser.add_argument(
        "--permission",
        choices=sorted(VALID_PERMISSIONS.keys()),
        default=DEFAULT_PERMISSION,
        help="Access level for the SMB account (read=read only, change=read/write).",
    )
    install_parser.add_argument(
        "--rw",
        action="store_true",
        help="Shortcut for --permission change.",
    )

    subparsers.add_parser("uninstall", help="Remove the SMB shares and account.")

    return parser.parse_args()


def prompt_permission() -> str:
    """Prompt user for permission level / 交互式选择访问权限"""
    print("请选择访问权限：")
    print("  1) read  - 只读（默认）")
    print("  2) change - 读写")
    choice = input("请输入编号（默认为 1）: ").strip()
    if choice == "2":
        return "change"
    return DEFAULT_PERMISSION


def interactive_flow() -> None:
    """Interactive menu / 交互式菜单入口"""
    while True:
        print("请选择操作：")
        print("  1) 安装（创建账户与共享）")
        print("  2) 卸载（移除账户与共享）")
        print("  3) 退出")
        choice = input("请输入编号: ").strip()
        if choice == "1":
            permission = prompt_permission()
            install(permission)
            break
        if choice == "2":
            uninstall()
            break
        if choice == "3":
            print("已退出。")
            break
        print("输入无效，请重新选择。\n")


def main() -> None:
    ensure_windows()
    require_admin()
    if len(sys.argv) == 1:
        interactive_flow()
        return

    args = parse_args()

    if args.command == "install":
        permission = "change" if getattr(args, "rw", False) else args.permission
        install(permission)
    elif args.command == "uninstall":
        uninstall()


if __name__ == "__main__":
    main()
