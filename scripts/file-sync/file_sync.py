#!/usr/bin/env python3
"""
通用文件同步工具 - 支持Linux/Linux、Linux/Windows、Windows/Linux
在Linux端执行，支持各种文件系统，可选排除空文件夹
"""

import os
import sys
import json
import subprocess
import shutil
from pathlib import Path
import glob
import datetime

class UniversalFileSyncTool:
    def __init__(self):
        self.script_dir = Path(__file__).parent
        self.presets = self.load_presets()
        
    def load_presets(self):
        """加载所有预设文件"""
        presets = {}
        
        # 查找所有预设文件 (preset_*.json)
        preset_files = glob.glob(str(self.script_dir / "preset_*.json"))
        
        for i, preset_file in enumerate(sorted(preset_files), 1):
            try:
                with open(preset_file, 'r', encoding='utf-8') as f:
                    preset_data = json.load(f)
                
                preset_name = Path(preset_file).stem.replace("preset_", "")
                presets[str(i)] = {
                    "name": preset_data.get("name", preset_name),
                    "file": preset_file,
                    "data": preset_data
                }
                print(f"✅ 加载预设: {preset_data.get('name', preset_name)}")
                
            except Exception as e:
                print(f"❌ 加载预设文件失败 {preset_file}: {e}")
        
        return presets

    def check_rsync_available(self):
        """检查rsync是否可用"""
        if not shutil.which('rsync'):
            print("错误: 未找到rsync命令，请先安装rsync")
            print("Ubuntu/Debian: sudo apt install rsync")
            print("Arch/Manjaro: sudo pacman -S rsync")
            return False
        return True

    def detect_filesystem_type(self, path):
        """检测路径的文件系统类型"""
        try:
            # 获取路径的挂载点
            result = subprocess.run(
                ['df', '--output=source,target,fstype', path],
                capture_output=True, 
                text=True, 
                check=True
            )
            
            lines = result.stdout.strip().split('\n')
            if len(lines) > 1:
                # 第二行是目标路径的信息
                parts = lines[1].split()
                if len(parts) >= 3:
                    device, mount_point, fstype = parts[0], parts[1], parts[2]
                    return fstype, mount_point, device
                    
        except Exception as e:
            print(f"⚠️  检测文件系统失败 {path}: {e}")
            
        return "unknown", path, "unknown"

    def analyze_sync_scenario(self, source, destination):
        """分析同步场景并返回优化建议"""
        source_fs, source_mount, source_device = self.detect_filesystem_type(source)
        dest_fs, dest_mount, dest_device = self.detect_filesystem_type(destination)
        
        print(f"\n🔍 同步场景分析:")
        print(f"   源: {source}")
        print(f"     文件系统: {source_fs}, 挂载点: {source_mount}")
        print(f"   目标: {destination}")
        print(f"     文件系统: {dest_fs}, 挂载点: {dest_mount}")
        
        scenario = {
            "source_fs": source_fs,
            "dest_fs": dest_fs,
            "recommendations": [],
            "warnings": []
        }
        
        # Windows文件系统检测
        windows_fs = ["ntfs", "ntfs3", "fuseblk", "vfat", "exfat", "msdos"]
        
        # 场景1: Windows to Linux
        if source_fs.lower() in windows_fs and dest_fs.lower() not in windows_fs:
            scenario["type"] = "Windows to Linux"
            scenario["recommendations"].extend([
                "--modify-window=2 (扩大时间戳窗口)",
                "--no-perms (忽略Windows权限)",
                "--no-owner --no-group (忽略所有者和组)"
            ])
            scenario["warnings"].extend([
                "时间戳精度差异: Windows(100ns) vs Linux(1s)",
                "权限系统不兼容",
                "符号链接处理可能不同"
            ])
            
        # 场景2: Linux to Windows  
        elif source_fs.lower() not in windows_fs and dest_fs.lower() in windows_fs:
            scenario["type"] = "Linux to Windows"
            scenario["recommendations"].extend([
                "--modify-window=2 (扩大时间戳窗口)",
                "--no-perms (忽略Linux权限)",
                "--no-owner --no-group (忽略所有者和组)"
            ])
            scenario["warnings"].extend([
                "时间戳精度差异",
                "权限信息会丢失",
                "符号链接可能无法创建"
            ])
            
        # 场景3: Linux to Linux
        elif source_fs.lower() not in windows_fs and dest_fs.lower() not in windows_fs:
            scenario["type"] = "Linux to Linux"
            scenario["recommendations"].extend([
                "-a (归档模式，保留所有属性)",
                "--modify-window=1 (标准时间戳窗口)"
            ])
            
        # 场景4: Windows to Windows
        elif source_fs.lower() in windows_fs and dest_fs.lower() in windows_fs:
            scenario["type"] = "Windows to Windows"
            scenario["recommendations"].extend([
                "--modify-window=2 (扩大时间戳窗口)",
                "-rlt (递归、链接、时间)"
            ])
            
        else:
            scenario["type"] = "未知场景"
            scenario["recommendations"].extend([
                "--modify-window=2 (保守时间戳窗口)",
                "-rlt (基本文件属性)"
            ])
            
        return scenario

    def build_rsync_command_universal(self, config, sync_mode="mirror", dry_run=False, scenario=None, exclude_empty_dirs=True):
        """构建通用rsync命令"""
        source = config["source"]
        destination = config["destination"]
        
        # 基础参数
        base_args = ['rsync', '-vh', '--progress']
        
        # 根据场景选择参数
        if scenario["type"] in ["Linux to Linux"]:
            # Linux to Linux: 使用完整归档模式
            base_args.extend(['-a'])  # 归档模式
            base_args.extend(['--modify-window=1'])
        else:
            # 跨平台同步: 使用保守参数
            base_args.extend(['-rlt'])  # 递归、保留链接和时间戳
            base_args.extend(['--modify-window=2'])  # 扩大时间窗口
            base_args.extend(['--no-perms', '--no-owner', '--no-group'])  # 忽略权限
            
            # 对于Windows目标，添加额外参数
            windows_fs = ["ntfs", "ntfs3", "fuseblk", "vfat", "exfat", "msdos"]
            if scenario["dest_fs"].lower() in windows_fs:
                base_args.extend(['--size-only'])  # 对于Windows目标，使用大小比较

        # 同步模式参数
        if sync_mode == "mirror":
            base_args.append('--delete')
        elif sync_mode == "update":
            # 只更新，不删除
            pass
        elif sync_mode == "safe":
            base_args.append('--ignore-existing')

        # 可选排除空文件夹 - 根据参数决定
        if exclude_empty_dirs:
            base_args.append('--prune-empty-dirs')

        if dry_run:
            base_args.append('--dry-run')

        # 处理文件夹黑白名单
        folder_white_list = config.get("folder_white_list", [])
        folder_black_list = config.get("folder_black_list", [])
        
        # 处理文件扩展名黑白名单
        extension_white_list = config.get("extension_white_list", [])
        extension_black_list = config.get("extension_black_list", [])

        # 构建包含/排除参数
        filter_args = []
        
        # 首先包含所有目录（以便递归）
        filter_args.extend(['--include', '*/'])
        
        # 文件夹白名单处理
        for folder in folder_white_list:
            filter_args.extend(['--include', f'{folder}/'])
            filter_args.extend(['--include', f'{folder}/**'])
        
        # 文件扩展名白名单处理
        for ext in extension_white_list:
            filter_args.extend(['--include', f'*.{ext}'])
            if ext != ext.upper():  # 避免重复添加
                filter_args.extend(['--include', f'*.{ext.upper()}'])
        
        # 文件夹黑名单处理
        for folder in folder_black_list:
            filter_args.extend(['--exclude', f'{folder}/'])
        
        # 文件扩展名黑名单处理
        for ext in extension_black_list:
            filter_args.extend(['--exclude', f'*.{ext}'])
            if ext != ext.upper():  # 避免重复添加
                filter_args.extend(['--exclude', f'*.{ext.upper()}'])
        
        # 如果指定了白名单，需要排除其他所有文件
        if extension_white_list or folder_white_list:
            filter_args.extend(['--exclude', '*'])

        return base_args + filter_args + [source, destination]

    def validate_paths(self, source, destination):
        """验证源路径和目标路径"""
        if not os.path.exists(source):
            print(f"错误: 源路径不存在: {source}")
            return False
        
        if not os.path.exists(destination):
            create = input(f"目标路径不存在: {destination}\n是否创建? (y/n): ").strip().lower()
            if create == 'y':
                os.makedirs(destination, exist_ok=True)
                print(f"已创建目标目录: {destination}")
            else:
                return False
        
        return True

    def analyze_empty_directories(self, config):
        """分析源目录中的空文件夹"""
        source = config["source"]
        
        if not os.path.exists(source):
            return
        
        print(f"\n📁 空文件夹分析: {source}")
        
        empty_dirs = []
        total_dirs = 0
        
        try:
            for root, dirs, files in os.walk(source):
                total_dirs += 1
                
                # 检查当前目录是否为空
                if not dirs and not files:
                    rel_path = os.path.relpath(root, source)
                    if rel_path != '.':  # 跳过根目录
                        empty_dirs.append(rel_path)
                        
                # 限制输出数量，避免过多信息
                if len(empty_dirs) >= 10:
                    break
                    
        except Exception as e:
            print(f"❌ 分析空文件夹时出错: {e}")
            return
        
        if empty_dirs:
            print(f"   🔍 发现 {len(empty_dirs)} 个空文件夹 (显示前10个):")
            for empty_dir in empty_dirs[:10]:
                print(f"      📁 {empty_dir}")
            if len(empty_dirs) > 10:
                print(f"      ... 还有 {len(empty_dirs) - 10} 个空文件夹")
        else:
            print(f"   ✅ 未发现空文件夹")

        return empty_dirs

    def run_universal_sync(self, config, sync_mode="mirror", dry_run=False, exclude_empty_dirs=True):
        """执行通用同步操作"""
        source = config["source"]
        destination = config["destination"]
        
        if not self.validate_paths(source, destination):
            return False

        # 分析同步场景
        scenario = self.analyze_sync_scenario(source, destination)
        
        print(f"\n🎯 同步类型: {scenario['type']}")
        
        if scenario["recommendations"]:
            print("💡 推荐参数:")
            for rec in scenario["recommendations"]:
                print(f"   ✅ {rec}")
                
        if scenario["warnings"]:
            print("⚠️  注意事项:")
            for warning in scenario["warnings"]:
                print(f"   ⚠️  {warning}")

        # 分析空文件夹
        empty_dirs = self.analyze_empty_directories(config)
        
        # 显示空文件夹排除设置
        if exclude_empty_dirs:
            print(f"\n✅ 空文件夹排除: 已启用")
            if empty_dirs:
                print(f"   以上 {len(empty_dirs)} 个空文件夹将不会被同步")
            else:
                print(f"   未发现空文件夹，此设置不会影响同步")
        else:
            print(f"\n❌ 空文件夹排除: 已禁用")
            if empty_dirs:
                print(f"   注意: {len(empty_dirs)} 个空文件夹将会被同步到目标目录")

        # 确保路径以斜杠结尾
        if not source.endswith('/'):
            source += '/'
        if not destination.endswith('/'):
            destination += '/'

        command = self.build_rsync_command_universal(config, sync_mode, dry_run, scenario, exclude_empty_dirs)
        
        print("\n" + "="*60)
        print(f"🔄 通用文件同步")
        print(f"📁 源: {source}")
        print(f"📁 目标: {destination}")
        print(f"📝 预设: {config.get('name', '未知')}")
        print(f"🔧 同步模式: {self.get_sync_mode_description(sync_mode)}")
        print(f"💻 场景: {scenario['type']}")
        print(f"🗑️  空文件夹排除: {'启用' if exclude_empty_dirs else '禁用'}")
        
        # 显示使用的参数
        print(f"\n⚙️  使用参数:")
        param_desc = {
            '-a': '归档模式 (保留所有属性)',
            '-rlt': '递归+链接+时间戳 (基础属性)',
            '--modify-window=1': '标准时间戳窗口',
            '--modify-window=2': '扩大时间戳窗口',
            '--no-perms': '忽略权限',
            '--no-owner': '忽略所有者',
            '--no-group': '忽略组',
            '--size-only': '仅比较文件大小',
            '--prune-empty-dirs': '排除空文件夹'
        }
        
        for arg in command:
            if arg in param_desc:
                print(f"   {arg}: {param_desc[arg]}")
            
        if dry_run:
            print("\n⚠️  模式: 模拟运行")
        print("="*60)
        print(f"🔧 完整命令:\n{' '.join(command)}")
        print("="*60)

        try:
            # 执行rsync命令
            result = subprocess.run(command, check=False)
            if result.returncode == 0:
                print("\n✅ 同步操作完成!")
                if dry_run:
                    print("💡 这是模拟运行，要实际执行请去掉--dry-run选项")
                
                # 显示同步后建议
                if not dry_run:
                    self.show_post_sync_advice(scenario, exclude_empty_dirs)
                return True
            else:
                print(f"\n❌ 同步操作失败，返回码: {result.returncode}")
                return False
                
        except KeyboardInterrupt:
            print("\n\n⚠️  操作被用户中断")
            return False
        except Exception as e:
            print(f"\n❌ 执行过程中发生错误: {e}")
            return False

    def show_post_sync_advice(self, scenario, exclude_empty_dirs):
        """显示同步后建议"""
        print(f"\n💡 同步后建议:")
        
        if scenario["type"] in ["Windows to Linux", "Linux to Windows"]:
            print(f"   1. 验证文件完整性: 随机抽查文件是否能正常访问")
            print(f"   2. 检查时间戳: 确认重要文件的时间戳正确")
            if exclude_empty_dirs:
                print(f"   3. 空文件夹检查: 确认空文件夹已正确排除")
            print(f"   4. 验证文件数量: 确认目标目录文件数量符合预期")
        else:
            print(f"   1. 快速验证: 确认主要文件已同步")
            if not exclude_empty_dirs:
                print(f"   2. 空文件夹: 确认需要的空文件夹结构已保留")
            print(f"   3. 权限检查: 确认文件权限正确 (仅Linux to Linux)")

    def get_sync_mode_description(self, sync_mode):
        """获取同步模式的描述"""
        descriptions = {
            "mirror": "镜像同步 (删除目标中多余文件)",
            "update": "增量更新 (只添加/更新，不删除)",
            "safe": "安全同步 (不覆盖现有文件)"
        }
        return descriptions.get(sync_mode, "标准同步")

    def show_presets_menu(self):
        """显示预设菜单"""
        print("\n" + "="*60)
        print("🔄 通用文件同步工具")
        print("支持: Linux↔Linux, Linux↔Windows, Windows↔Linux")
        print("特性: 可选排除空文件夹 (默认启用)")
        print("="*60)
        
        if not self.presets:
            print("❌ 未找到任何预设文件")
            print("请在同目录下创建 preset_*.json 文件")
            print("可参考 template.json 创建模板")
            print("="*60)
            return False
            
        for key, preset in self.presets.items():
            data = preset["data"]
            print(f"{key}. {data['name']}")
            print(f"   源: {data['source']}")
            print(f"   目标: {data['destination']}")
            print(f"   描述: {data.get('description', '无描述')}")
            
            # 显示过滤配置摘要
            filters = []
            if data.get("folder_white_list"):
                filters.append(f"📂白({len(data['folder_white_list'])})")
            if data.get("folder_black_list"):
                filters.append(f"📂黑({len(data['folder_black_list'])})")
            if data.get("extension_white_list"):
                filters.append(f"📄白({len(data['extension_white_list'])})")
            if data.get("extension_black_list"):
                filters.append(f"📄黑({len(data['extension_black_list'])})")
                
            if filters:
                print(f"   过滤: {' '.join(filters)}")
            print()
        
        print("0. 退出")
        print("="*60)
        return True

    def show_sync_options(self, preset_name, config):
        """显示同步选项菜单"""
        print(f"\n🎯 预设: {preset_name}")
        print(f"📁 源目录: {config['source']}")
        print(f"📁 目标目录: {config['destination']}")
        
        # 显示详细配置
        print("\n⚙️  过滤配置:")
        if config.get("folder_white_list"):
            print(f"📂 文件夹白名单: {', '.join(config['folder_white_list'])}")
        if config.get("folder_black_list"):
            print(f"📂 文件夹黑名单: {', '.join(config['folder_black_list'])}")
        if config.get("extension_white_list"):
            print(f"📄 文件白名单: {', '.join(config['extension_white_list'])}")
        if config.get("extension_black_list"):
            print(f"📄 文件黑名单: {', '.join(config['extension_black_list'])}")
        
        print("\n🔄 同步模式:")
        print("1. 镜像同步 (推荐 - 删除目标中多余文件)")
        print("2. 增量更新 (只添加/更新，不删除)")
        print("3. 安全同步 (不覆盖现有文件)")
        
        print("\n📋 执行选项:")
        print("4. 智能模拟运行 (排除空文件夹)")
        print("5. 智能实际执行 (排除空文件夹)")
        print("6. 自定义空文件夹设置")
        print("7. 返回上级菜单")
        
        choice = input("请选择 (1-7): ").strip()
        return choice

    def main(self):
        """主菜单"""
        if not self.check_rsync_available():
            sys.exit(1)

        while True:
            if not self.show_presets_menu():
                input("\n按Enter键退出...")
                break
                
            choice = input("请选择预设 (0-{}): ".format(len(self.presets))).strip()

            if choice == "0":
                print("再见! 👋")
                break
            elif choice in self.presets:
                # 选择的预设
                preset = self.presets[choice]
                self.handle_sync_operation(preset)
            else:
                print("无效选择，请重新输入")

    def handle_sync_operation(self, preset):
        """处理同步操作"""
        preset_name = preset["data"]["name"]
        config = preset["data"]
        
        while True:
            sync_choice = self.show_sync_options(preset_name, config)
            
            sync_modes = {
                "1": "mirror",
                "2": "update", 
                "3": "safe"
            }
            
            if sync_choice in ["1", "2", "3"]:
                # 选择同步模式后，选择执行方式
                sync_mode = sync_modes[sync_choice]
                print(f"\n🔄 同步模式: {self.get_sync_mode_description(sync_mode)}")
                print("🗑️  空文件夹排除选项:")
                print("1. 启用空文件夹排除 (推荐)")
                print("2. 禁用空文件夹排除")
                exclude_choice = input("请选择 (1-2): ").strip()
                
                exclude_empty_dirs = (exclude_choice == "1")
                
                exec_choice = input("选择执行方式:\n1. 模拟运行\n2. 实际执行\n3. 返回\n请选择 (1-3): ").strip()
                
                if exec_choice == "1":
                    self.run_universal_sync(config, sync_mode, dry_run=True, exclude_empty_dirs=exclude_empty_dirs)
                    input("\n按Enter键继续...")
                elif exec_choice == "2":
                    confirm = input("确认执行同步操作? (y/n): ").strip().lower()
                    if confirm == 'y':
                        self.run_universal_sync(config, sync_mode, dry_run=False, exclude_empty_dirs=exclude_empty_dirs)
                        input("\n按Enter键继续...")
                    else:
                        print("操作已取消")
                elif exec_choice == "3":
                    continue
                else:
                    print("无效选择")
                    
            elif sync_choice == "4":
                # 智能模拟运行 (默认排除空文件夹)
                self.run_universal_sync(config, "mirror", dry_run=True, exclude_empty_dirs=True)
                input("\n按Enter键继续...")
            elif sync_choice == "5":
                # 智能实际执行 (默认排除空文件夹)
                confirm = input("确认执行智能同步操作? (y/n): ").strip().lower()
                if confirm == 'y':
                    self.run_universal_sync(config, "mirror", dry_run=False, exclude_empty_dirs=True)
                    input("\n按Enter键继续...")
                else:
                    print("操作已取消")
            elif sync_choice == "6":
                # 自定义空文件夹设置
                self.custom_empty_dir_setting(config)
            elif sync_choice == "7":
                # 返回上级
                break
            else:
                print("无效选择")

    def custom_empty_dir_setting(self, config):
        """自定义空文件夹设置"""
        print(f"\n⚙️  自定义空文件夹设置")
        print("当前预设:", config['name'])
        
        while True:
            print("\n空文件夹排除选项:")
            print("1. 启用空文件夹排除 (不同步空文件夹)")
            print("2. 禁用空文件夹排除 (同步所有空文件夹)")
            print("3. 返回上级菜单")
            
            choice = input("请选择 (1-3): ").strip()
            
            if choice == "1":
                sync_mode = input("选择同步模式:\n1. 镜像同步\n2. 增量更新\n3. 安全同步\n请选择 (1-3): ").strip()
                sync_modes = {"1": "mirror", "2": "update", "3": "safe"}
                actual_mode = sync_modes.get(sync_mode, "mirror")
                
                exec_choice = input("选择执行方式:\n1. 模拟运行\n2. 实际执行\n请选择 (1-2): ").strip()
                
                if exec_choice == "1":
                    self.run_universal_sync(config, actual_mode, dry_run=True, exclude_empty_dirs=True)
                elif exec_choice == "2":
                    confirm = input("确认执行同步操作? (y/n): ").strip().lower()
                    if confirm == 'y':
                        self.run_universal_sync(config, actual_mode, dry_run=False, exclude_empty_dirs=True)
                else:
                    print("无效选择")
                input("\n按Enter键继续...")
                
            elif choice == "2":
                sync_mode = input("选择同步模式:\n1. 镜像同步\n2. 增量更新\n3. 安全同步\n请选择 (1-3): ").strip()
                sync_modes = {"1": "mirror", "2": "update", "3": "safe"}
                actual_mode = sync_modes.get(sync_mode, "mirror")
                
                # 警告用户
                print("⚠️  警告: 禁用空文件夹排除将同步所有空文件夹")
                print("   这可能导致目标目录中出现大量空文件夹结构")
                confirm = input("确定要禁用空文件夹排除吗? (y/n): ").strip().lower()
                
                if confirm == 'y':
                    exec_choice = input("选择执行方式:\n1. 模拟运行\n2. 实际执行\n请选择 (1-2): ").strip()
                    
                    if exec_choice == "1":
                        self.run_universal_sync(config, actual_mode, dry_run=True, exclude_empty_dirs=False)
                    elif exec_choice == "2":
                        final_confirm = input("确认执行同步操作? (y/n): ").strip().lower()
                        if final_confirm == 'y':
                            self.run_universal_sync(config, actual_mode, dry_run=False, exclude_empty_dirs=False)
                    else:
                        print("无效选择")
                input("\n按Enter键继续...")
                
            elif choice == "3":
                break
            else:
                print("无效选择")


def main():
    """主函数"""
    try:
        tool = UniversalFileSyncTool()
        tool.main()
    except KeyboardInterrupt:
        print("\n\n程序被用户中断")
    except Exception as e:
        print(f"程序运行出错: {e}")


if __name__ == "__main__":
    main()
