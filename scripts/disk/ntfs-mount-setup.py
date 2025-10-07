#!/usr/bin/env python3

import os
import sys
import subprocess
import shutil
from datetime import datetime
import re

# 默认配置
DEFAULT_DEVICE = "/dev/nvme0n1p4"
DEFAULT_MOUNT_POINT = "/mnt/DDDD"
FSTAB_FILE = "/etc/fstab"

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    PURPLE = '\033[0;35m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

def print_color(text, color):
    print(f"{color}{text}{Colors.NC}")

def print_info(text):
    print_color(f"[INFO] {text}", Colors.BLUE)

def print_warn(text):
    print_color(f"[WARN] {text}", Colors.YELLOW)

def print_error(text):
    print_color(f"[ERROR] {text}", Colors.RED)

def print_success(text):
    print_color(f"[SUCCESS] {text}", Colors.GREEN)

def run_command(cmd, check=True, capture_output=True):
    """运行命令并返回结果"""
    try:
        result = subprocess.run(
            cmd, 
            shell=True, 
            check=check, 
            capture_output=capture_output,
            text=True
        )
        return result
    except subprocess.CalledProcessError as e:
        if check:
            print_error(f"命令执行失败: {cmd}")
            print_error(f"错误信息: {e.stderr}")
            return None
        return e

def check_root():
    """检查root权限"""
    if os.geteuid() != 0:
        print_error("此脚本需要root权限，请使用sudo运行")
        sys.exit(1)

def choose_device():
    """选择设备"""
    print_info("当前存储设备:")
    result = run_command("lsblk -f -o NAME,FSTYPE,SIZE,MOUNTPOINT,LABEL")
    if result:
        print(result.stdout)
    
    device = input(f"\n输入设备路径 (默认: {DEFAULT_DEVICE}): ").strip()
    if not device:
        device = DEFAULT_DEVICE
    
    # 验证设备是否存在
    if not os.path.exists(device):
        print_error(f"设备 {device} 不存在")
        sys.exit(1)
    
    return device

def choose_mount_point():
    """选择挂载点"""
    print_info("/mnt 目录下的现有文件夹:")
    if os.path.exists("/mnt"):
        result = run_command("ls -la /mnt", check=False)
        if result and result.returncode == 0:
            print(result.stdout)
    
    mount_point = input(f"\n输入挂载点路径 (默认: {DEFAULT_MOUNT_POINT}): ").strip()
    if not mount_point:
        mount_point = DEFAULT_MOUNT_POINT
    
    return mount_point

def create_mount_point(mount_point):
    """创建挂载点"""
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

def get_user_ids():
    """获取用户ID和组ID"""
    try:
        # 尝试获取登录用户
        desktop_user = os.getlogin()
    except:
        # 回退到环境变量
        desktop_user = os.environ.get('SUDO_USER') or os.environ.get('USER')
    
    if not desktop_user:
        # 最后回退到当前用户
        desktop_user = os.environ.get('USER')
    
    try:
        uid = os.getuid() if desktop_user is None else int(run_command(f"id -u {desktop_user}", capture_output=True).stdout.strip())
        gid = os.getgid() if desktop_user is None else int(run_command(f"id -g {desktop_user}", capture_output=True).stdout.strip())
    except:
        uid = os.getuid()
        gid = os.getgid()
        desktop_user = "current user"
    
    print_info(f"使用用户: {desktop_user} (UID: {uid}, GID: {gid})")
    return uid, gid, desktop_user

def check_ntfs3_support():
    """检测NTFS3支持"""
    print_info("检测NTFS3驱动支持…")
    
    # 检查内核版本
    result = run_command("uname -r", capture_output=True)
    if not result:
        return False
    
    kernel_version = result.stdout.strip()
    match = re.match(r'(\d+)\.(\d+)', kernel_version)
    
    if match:
        major = int(match.group(1))
        minor = int(match.group(2))
        
        if major > 5 or (major == 5 and minor >= 15):
            # 检查内核模块
            modprobe_result = run_command("modprobe -n ntfs3", check=False)
            if modprobe_result.returncode == 0:
                lsmod_result = run_command("lsmod | grep ntfs3", check=False)
                if lsmod_result.returncode == 0 or run_command("modprobe ntfs3", check=False).returncode == 0:
                    print_success(f"系统支持NTFS3驱动 (内核 {kernel_version})")
                    return True
    
    print_warn("系统不支持NTFS3驱动，将使用ntfs-3g")
    return False

def test_mount(device, mount_point, fs_type, options):
    """测试挂载"""
    print_info(f"测试使用 {fs_type} 挂载…")
    
    # 确保挂载点存在
    os.makedirs(mount_point, exist_ok=True)
    
    result = run_command(f"mount -t {fs_type} -o {options} {device} {mount_point}", check=False)
    
    if result.returncode == 0:
        # 检查是否可写（如果不是只读选项）
        if "ro" not in options:
            test_file = os.path.join(mount_point, ".mount_test")
            try:
                with open(test_file, 'w') as f:
                    f.write("test")
                os.remove(test_file)
                print_success("读写权限测试成功")
                mount_readonly = False
            except:
                print_warn("分区以只读方式挂载，可能需要在Windows中禁用快速启动")
                mount_readonly = True
        else:
            mount_readonly = True
        
        # 卸载测试挂载
        run_command(f"umount {mount_point}", check=False)
        return True, mount_readonly
    else:
        return False, False

def get_user_choices(ntfs3_supported):
    """获取用户选择"""
    print_info("NTFS自动挂载配置")
    print()
    
    # 文件系统类型选择
    if ntfs3_supported:
        fs_choice = input("选择文件系统类型 [1]ntfs3 (推荐) [2]ntfs-3g (默认:1): ").strip()
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

def generate_mount_options(noauto_option, ro_option, uid, gid, fs_type):
    """生成挂载选项"""
    base_options = f"{noauto_option}{ro_option}nofail,uid={uid},gid={gid},umask=022"
    
    if fs_type == "ntfs3":
        # NTFS3特定选项
        base_options = f"{base_options},iocharset=utf8,prealloc"
    else:
        # NTFS-3G特定选项
        base_options = f"{base_options},windows_names"
    
    # 移除末尾的逗号（如果有）
    return base_options.rstrip(',')

def backup_fstab():
    """备份fstab文件"""
    backup_file = f"{FSTAB_FILE}.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    print_info(f"备份 {FSTAB_FILE} 到 {backup_file}")
    shutil.copy2(FSTAB_FILE, backup_file)
    print_success("备份完成")
    return backup_file

def add_to_fstab(device, mount_point, fs_type, mount_options):
    """添加挂载配置到fstab"""
    fstab_entry = f"{device} {mount_point} {fs_type} {mount_options} 0 0"
    
    print_info("添加fstab条目:")
    print(f"  {fstab_entry}")
    
    # 读取现有fstab内容
    with open(FSTAB_FILE, 'r') as f:
        lines = f.readlines()
    
    # 移除已存在的相同设备或挂载点条目
    new_lines = []
    for line in lines:
        line_stripped = line.strip()
        # 跳过空行和注释
        if not line_stripped or line_stripped.startswith('#'):
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
    with open(FSTAB_FILE, 'w') as f:
        f.writelines(new_lines)
    
    print_success("fstab更新完成")

def test_configuration(mount_point, noauto_option, ro_option):
    """测试配置"""
    print_info("测试挂载配置…")
    
    if not noauto_option:
        # 测试自动挂载
        result = run_command("mount -a", check=False)
        if result.returncode == 0:
            print_success("自动挂载测试成功")
            
            # 检查实际挂载状态
            result = run_command(f"mount | grep {mount_point}", check=False)
            if result.returncode == 0:
                print_info("挂载详情:")
                print(result.stdout)
                
                # 测试文件操作（如果不是只读）
                if not ro_option:
                    test_file = os.path.join(mount_point, ".config_test")
                    try:
                        with open(test_file, 'w') as f:
                            f.write("test")
                        os.remove(test_file)
                        print_success("读写权限测试成功")
                    except Exception as e:
                        print_warn(f"无法写入文件: {e}")
                
                # 卸载测试挂载
                run_command(f"umount {mount_point}", check=False)
        else:
            print_error("自动挂载测试失败")
            print_warn("请检查/etc/fstab配置")
    else:
        # 测试手动挂载
        result = run_command(f"mount {mount_point}", check=False)
        if result.returncode == 0:
            print_success("手动挂载测试成功")
            result = run_command(f"mount | grep {mount_point}", check=False)
            if result.returncode == 0:
                print(result.stdout)
            run_command(f"umount {mount_point}", check=False)
        else:
            print_error("手动挂载测试失败")

def show_usage(device, mount_point, noauto_option, ro_option):
    """显示使用说明"""
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

def main():
    """主函数"""
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
    mount_success, mount_readonly = test_mount(device, mount_point, fs_type, mount_options)
    
    if not mount_success:
        print_error("挂载测试失败")
        
        # 如果NTFS3失败，尝试回退到ntfs-3g
        if fs_type == "ntfs3":
            print_warn("NTFS3挂载失败，尝试使用ntfs-3g")
            fs_type = "ntfs-3g"
            mount_options = generate_mount_options(noauto_option, ro_option, uid, gid, fs_type)
            mount_success, mount_readonly = test_mount(device, mount_point, fs_type, mount_options)
            
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
