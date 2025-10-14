#!/usr/bin/env python3
"""
NTFS 自动挂载配置脚本

该脚本用于配置 NTFS 分区的自动挂载，支持 NTFS3 和 NTFS-3G 驱动。
支持自定义挂载选项、权限配置和 fstab 自动更新。

注意: 此脚本仅支持 Linux 系统
"""

import os  # type: ignore
import sys
import subprocess
import shutil
from datetime import datetime
import re

# 默认配置
DEFAULT_DEVICE = "/dev/nvme0n1p4"
DEFAULT_MOUNT_POINT = "/mnt/DDDD"
FSTAB_FILE = "/etc/fstab"

# NTFS3 最低内核要求
MIN_KERNEL_MAJOR = 5
MIN_KERNEL_MINOR = 15


class Colors:
    RED = "\033[0;31m"
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    BLUE = "\033[0;34m"
    PURPLE = "\033[0;35m"
    CYAN = "\033[0;36m"
    NC = "\033[0m"  # No Color


def print_color(text: str, color: str) -> None:
    """打印带颜色的文本"""
    print(f"{color}{text}{Colors.NC}")


def print_info(text: str) -> None:
    """打印信息消息"""
    print_color(f"[INFO] {text}", Colors.BLUE)


def print_warn(text: str) -> None:
    """打印警告消息"""
    print_color(f"[WARN] {text}", Colors.YELLOW)


def print_error(text: str) -> None:
    """打印错误消息"""
    print_color(f"[ERROR] {text}", Colors.RED)


def print_success(text: str) -> None:
    """打印成功消息"""
    print_color(f"[SUCCESS] {text}", Colors.GREEN)


def run_command(
    cmd: str, check: bool = True, capture_output: bool = True
) -> subprocess.CompletedProcess | None:
    """
    运行 shell 命令并返回结果

    Args:
        cmd: 要执行的命令
        check: 是否检查返回码并抛出异常
        capture_output: 是否捕获输出

    Returns:
        命令执行结果或 None（如果失败且 check=True）
    """
    try:
        result = subprocess.run(
            cmd, shell=True, check=check, capture_output=capture_output, text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"命令执行失败: {cmd}")
            if e.stderr:
                print_error(f"错误信息: {e.stderr}")
        return None


def check_root() -> None:
    """检查是否具有 root 权限"""
    if sys.platform != "win32":
        if os.geteuid() != 0:
            print_error("此脚本需要 root 权限")
            sys.exit(1)
    else:
        print_error("此脚本仅支持 Linux 系统")
        sys.exit(1)


def choose_device() -> str:
    """
    选择要挂载的设备

    Returns:
        设备路径
    """
    print_info("当前存储设备:")
    result = run_command("lsblk -f -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL")
    if result and result.stdout:
        print(result.stdout)

    device = input(f"\n输入设备路径 (默认: {DEFAULT_DEVICE}): ").strip()
    if not device:
        device = DEFAULT_DEVICE

    # 验证设备是否存在
    if not os.path.exists(device):
        print_error(f"设备 {device} 不存在")
        sys.exit(1)

    return device


def choose_mount_point() -> str:
    """
    选择挂载点路径

    Returns:
        挂载点路径
    """
    print_info("/mnt 目录下的现有文件夹:")
    if os.path.exists("/mnt"):
        result = run_command("ls -la /mnt", check=False)
        if result and result.returncode == 0 and result.stdout:
            print(result.stdout)

    mount_point = input(f"\n输入挂载点路径 (默认: {DEFAULT_MOUNT_POINT}): ").strip()
    if not mount_point:
        mount_point = DEFAULT_MOUNT_POINT

    return mount_point


def create_mount_point(mount_point: str) -> None:
    """
    创建挂载点目录，如果已挂载则先卸载

    Args:
        mount_point: 挂载点路径
    """
    if not os.path.exists(mount_point):
        print_info(f"创建挂载点: {mount_point}")
        os.makedirs(mount_point, exist_ok=True)
        print_success("挂载点创建成功")
    else:
        print_info(f"挂载点 {mount_point} 已存在")

        # 检查是否已挂载
        result = run_command(f"mountpoint -q {mount_point}", check=False)
        if result.returncode == 0:
            print_warn("挂载点已被使用，正在卸载…")
            run_command(f"umount {mount_point}", check=False)
            print_success("卸载完成")


def get_user_ids() -> tuple[int, int, str]:
    """
    获取用户 ID 和组 ID

    Returns:
        (UID, GID, 用户名) 元组
    """
    try:
        # 尝试获取登录用户
        desktop_user = os.getlogin()
    except (OSError, AttributeError):
        # 回退到环境变量
        desktop_user = os.environ.get("SUDO_USER") or os.environ.get("USER")

    if not desktop_user:
        # 最后回退到当前用户
        desktop_user = os.environ.get("USER", "current user")

    try:
        if desktop_user and desktop_user != "current user":
            result_uid = run_command(f"id -u {desktop_user}", capture_output=True)
            result_gid = run_command(f"id -g {desktop_user}", capture_output=True)
            uid = int(result_uid.stdout.strip()) if result_uid else os.getuid()
            gid = int(result_gid.stdout.strip()) if result_gid else os.getgid()
        else:
            uid = os.getuid()
            gid = os.getgid()
    except (ValueError, AttributeError):
        uid = os.getuid()
        gid = os.getgid()
        desktop_user = "current user"

    print_info(f"使用用户: {desktop_user} (UID: {uid}, GID: {gid})")
    return uid, gid, desktop_user


def check_ntfs3_support() -> bool:
    """
    检测系统是否支持 NTFS3 驱动

    Returns:
        True 如果支持 NTFS3，否则返回 False
    """
    print_info("检测 NTFS3 驱动支持…")

    # 检查内核版本
    result = run_command("uname -r", capture_output=True)
    if not result or not result.stdout:
        return False

    kernel_version = result.stdout.strip()
    match = re.match(r"(\d+)\.(\d+)", kernel_version)

    if match:
        major = int(match.group(1))
        minor = int(match.group(2))

        # NTFS3 需要内核 5.15 或更高版本
        if major > MIN_KERNEL_MAJOR or (
            major == MIN_KERNEL_MAJOR and minor >= MIN_KERNEL_MINOR
        ):
            # 检查内核模块
            modprobe_result = run_command("modprobe -n ntfs3", check=False)
            if modprobe_result and modprobe_result.returncode == 0:
                lsmod_result = run_command("lsmod | grep ntfs3", check=False)
                load_result = run_command("modprobe ntfs3", check=False)
                if (lsmod_result and lsmod_result.returncode == 0) or (
                    load_result and load_result.returncode == 0
                ):
                    print_success(f"系统支持 NTFS3 驱动 (内核 {kernel_version})")
                    return True

    print_warn(
        f"系统不支持 NTFS3 驱动 (需要内核 >={MIN_KERNEL_MAJOR}.{MIN_KERNEL_MINOR})，将使用 ntfs-3g"
    )
    return False


def test_mount(
    device: str, mount_point: str, fs_type: str, options: str
) -> tuple[bool, bool]:
    """
    测试挂载配置是否有效

    Args:
        device: 设备路径
        mount_point: 挂载点路径
        fs_type: 文件系统类型
        options: 挂载选项

    Returns:
        (挂载是否成功, 是否为只读) 元组
    """
    print_info(f"测试使用 {fs_type} 挂载…")

    # 确保挂载点存在
    os.makedirs(mount_point, exist_ok=True)

    result = run_command(
        f"mount -t {fs_type} -o {options} {device} {mount_point}", check=False
    )

    if result and result.returncode == 0:
        # 检查是否可写（如果不是只读选项）
        mount_readonly = False
        if "ro" not in options:
            test_file = os.path.join(mount_point, ".mount_test")
            try:
                with open(test_file, "w", encoding="utf-8") as f:
                    f.write("test")
                os.remove(test_file)
                print_success("读写权限测试成功")
            except (OSError, PermissionError) as e:
                print_warn(f"分区以只读方式挂载: {e}")
                print_warn("可能需要在 Windows 中禁用快速启动")
                mount_readonly = True
        else:
            mount_readonly = True

        # 卸载测试挂载
        run_command(f"umount {mount_point}", check=False)
        return True, mount_readonly

    return False, False


def get_user_choices(ntfs3_supported: bool) -> tuple[str, str, str]:
    """
    获取用户的配置选择

    Args:
        ntfs3_supported: 系统是否支持 NTFS3

    Returns:
        (文件系统类型, noauto选项, 只读选项) 元组
    """
    print_info("NTFS自动挂载配置")
    print()

    # 文件系统类型选择
    if ntfs3_supported:
        fs_choice = input(
            "选择文件系统类型 [1]ntfs3 (推荐) [2]ntfs-3g (默认:1): "
        ).strip()
        fs_type = "ntfs-3g" if fs_choice == "2" else "ntfs3"
    else:
        fs_type = "ntfs-3g"
        print_info(f"自动选择文件系统类型: {fs_type}")

    # 自动挂载选择
    auto_choice = input("是否开机自动挂载? [Y/n] (默认:Y): ").strip().upper()
    noauto_option = "noauto," if auto_choice == "N" else ""

    # 读写权限选择
    ro_choice = input("挂载为只读? [y/N] (默认:N): ").strip().upper()
    ro_option = "ro," if ro_choice == "Y" else ""

    return fs_type, noauto_option, ro_option


def generate_mount_options(
    noauto_option: str, ro_option: str, uid: int, gid: int, fs_type: str
) -> str:
    """
    生成 fstab 挂载选项字符串

    Args:
        noauto_option: noauto 选项字符串
        ro_option: 只读选项字符串
        uid: 用户 ID
        gid: 组 ID
        fs_type: 文件系统类型

    Returns:
        完整的挂载选项字符串
    """
    base_options = f"{noauto_option}{ro_option}nofail,uid={uid},gid={gid},umask=022"

    if fs_type == "ntfs3":
        # NTFS3 特定选项
        base_options = f"{base_options},iocharset=utf8,prealloc"
    else:
        # NTFS-3G 特定选项
        base_options = f"{base_options},windows_names"

    # 移除末尾的逗号（如果有）
    return base_options.rstrip(",")


def backup_fstab() -> str:
    """
    备份 fstab 文件

    Returns:
        备份文件的路径
    """
    backup_file = f"{FSTAB_FILE}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    print_info(f"备份 {FSTAB_FILE} 到 {backup_file}")
    shutil.copy2(FSTAB_FILE, backup_file)
    print_success("备份完成")
    return backup_file


def add_to_fstab(
    device: str, mount_point: str, fs_type: str, mount_options: str
) -> None:
    """
    添加挂载配置到 fstab 文件

    Args:
        device: 设备路径
        mount_point: 挂载点路径
        fs_type: 文件系统类型
        mount_options: 挂载选项
    """
    fstab_entry = f"{device} {mount_point} {fs_type} {mount_options} 0 0"

    print_info("添加fstab条目:")
    print(f"  {fstab_entry}")

    # 读取现有fstab内容
    with open(FSTAB_FILE, "r") as f:
        lines = f.readlines()

    # 移除已存在的相同设备或挂载点条目
    new_lines = []
    for line in lines:
        line_stripped = line.strip()
        # 跳过空行和注释
        if not line_stripped or line_stripped.startswith("#"):
            new_lines.append(line)
            continue

        parts = line_stripped.split()
        if len(parts) >= 2:
            # 检查设备或挂载点是否匹配
            if parts[0] == device or parts[1] == mount_point:
                continue  # 跳过匹配的行

        new_lines.append(line)

    # 添加新条目
    new_lines.append(f"{fstab_entry}\n")

    # 写回fstab
    with open(FSTAB_FILE, "w") as f:
        f.writelines(new_lines)

    print_success("fstab更新完成")


def test_configuration(mount_point: str, noauto_option: str, ro_option: str) -> None:
    """
    测试挂载配置

    Args:
        mount_point: 挂载点路径
        noauto_option: noauto 选项字符串
        ro_option: 只读选项字符串
    """
    print_info("测试挂载配置…")

    if not noauto_option:
        # 测试自动挂载
        result = run_command("mount -a", check=False)
        if result and result.returncode == 0:
            print_success("自动挂载测试成功")

            # 检查实际挂载状态
            result = run_command(f"mount | grep {mount_point}", check=False)
            if result and result.returncode == 0:
                print_info("挂载详情:")
                if result.stdout:
                    print(result.stdout)

                # 测试文件操作（如果不是只读）
                if not ro_option:
                    test_file = os.path.join(mount_point, ".config_test")
                    try:
                        with open(test_file, "w", encoding="utf-8") as f:
                            f.write("test")
                        os.remove(test_file)
                        print_success("读写权限测试成功")
                    except (OSError, PermissionError) as e:
                        print_warn(f"无法写入文件: {e}")

                # 卸载测试挂载
                run_command(f"umount {mount_point}", check=False)
        else:
            print_error("自动挂载测试失败")
            print_warn("请检查 /etc/fstab 配置")
    else:
        # 测试手动挂载
        result = run_command(f"mount {mount_point}", check=False)
        if result and result.returncode == 0:
            print_success("手动挂载测试成功")
            result = run_command(f"mount | grep {mount_point}", check=False)
            if result and result.returncode == 0 and result.stdout:
                print(result.stdout)
            run_command(f"umount {mount_point}", check=False)
        else:
            print_error("手动挂载测试失败")


def show_usage(
    device: str, mount_point: str, noauto_option: str, ro_option: str
) -> None:
    """
    显示使用说明

    Args:
        device: 设备路径
        mount_point: 挂载点路径
        noauto_option: noauto 选项字符串
        ro_option: 只读选项字符串
    """
    print()
    print_info("使用说明:")
    print(f"  手动挂载: sudo mount {mount_point}")
    print(f"  手动卸载: sudo umount {mount_point}")
    print(f"  查看挂载: mount | grep {mount_point}")
    print(f"  查看磁盘空间: df -h | grep {mount_point}")

    if noauto_option:
        print()
        print_warn("注意: 分区不会在启动时自动挂载")
        print(f"  需要时手动运行: sudo mount {mount_point}")

    if ro_option:
        print()
        print_warn("注意: 分区以只读方式挂载")


def main() -> None:
    """主函数 - 执行 NTFS 挂载配置流程"""
    print("=" * 50)
    print("    NTFS 自动挂载配置脚本")
    print("=" * 50)
    print()

    # 检查root权限
    check_root()

    # 选择设备和挂载点
    device = choose_device()
    mount_point = choose_mount_point()

    # 创建挂载点
    create_mount_point(mount_point)

    # 获取用户ID
    uid, gid, username = get_user_ids()

    # 检查NTFS3支持
    ntfs3_supported = check_ntfs3_support()

    # 获取用户选择
    fs_type, noauto_option, ro_option = get_user_choices(ntfs3_supported)

    # 生成挂载选项
    mount_options = generate_mount_options(noauto_option, ro_option, uid, gid, fs_type)

    # 测试选择的配置
    mount_success, mount_readonly = test_mount(
        device, mount_point, fs_type, mount_options
    )

    if not mount_success:
        print_error("挂载测试失败")

        # 如果NTFS3失败，尝试回退到ntfs-3g
        if fs_type == "ntfs3":
            print_warn("NTFS3挂载失败，尝试使用ntfs-3g")
            fs_type = "ntfs-3g"
            mount_options = generate_mount_options(
                noauto_option, ro_option, uid, gid, fs_type
            )
            mount_success, mount_readonly = test_mount(
                device, mount_point, fs_type, mount_options
            )

            if mount_success:
                print_success("ntfs-3g挂载测试成功，将使用ntfs-3g")
            else:
                print_error("ntfs-3g挂载也失败，请检查设备状态")
                sys.exit(1)
        else:
            sys.exit(1)

    # 备份并更新fstab
    backup_fstab()
    add_to_fstab(device, mount_point, fs_type, mount_options)

    # 测试配置
    test_configuration(mount_point, noauto_option, ro_option)

    # 显示使用说明
    show_usage(device, mount_point, noauto_option, ro_option)

    print()
    print_success("NTFS挂载配置完成!")


if __name__ == "__main__":
    main()
