#!/usr/bin/env python3
"""
通用文件同步工具 - 支持Linux/Linux、Linux/Windows、Windows/Linux
Universal File Sync Tool - Supports Linux↔Linux, Linux↔Windows, Windows↔Linux

在Linux端执行，支持各种文件系统，可选排除空文件夹
Executes on Linux, supports various filesystems, optional empty directory exclusion
"""

import argparse
import json
import logging
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass
class FileSystemInfo:
    """文件系统信息 / Filesystem information"""

    fs_type: str
    mount_point: str
    device: str


@dataclass
class SyncScenario:
    """同步场景信息 / Sync scenario information"""

    source_fs: str
    dest_fs: str
    scenario_type: str
    recommendations: list[str]
    warnings: list[str]


class FileSystemAnalyzer:
    """文件系统分析器 / Filesystem analyzer"""

    WINDOWS_FS_TYPES = ["ntfs", "ntfs3", "fuseblk", "vfat", "exfat", "msdos"]

    def __init__(self, logger: logging.Logger):
        self.logger = logger

    def detect_filesystem_type(self, path: str) -> FileSystemInfo:
        """检测路径的文件系统类型 / Detect filesystem type of path"""
        try:
            result = subprocess.run(
                ["df", "--output=source,target,fstype", path],
                capture_output=True,
                text=True,
                check=True,
                timeout=5,
            )

            lines = result.stdout.strip().split("\n")
            if len(lines) > 1:
                parts = lines[1].split()
                if len(parts) >= 3:
                    return FileSystemInfo(fs_type=parts[2], mount_point=parts[1], device=parts[0])
        except subprocess.TimeoutExpired:
            self.logger.error(f"检测文件系统超时: {path}")
        except subprocess.CalledProcessError as e:
            self.logger.error(f"检测文件系统失败: {e}")
        except Exception as e:
            self.logger.warning(f"检测文件系统时发生异常: {e}")

        return FileSystemInfo("unknown", path, "unknown")

    def analyze_sync_scenario(self, source: str, destination: str) -> SyncScenario:
        """分析同步场景并返回优化建议 / Analyze sync scenario and return recommendations"""
        source_info = self.detect_filesystem_type(source)
        dest_info = self.detect_filesystem_type(destination)

        self.logger.info("同步场景分析 / Sync scenario analysis:")
        self.logger.info(f"  源 / Source: {source}")
        self.logger.info(
            "    文件系统 / Filesystem: "
            f"{source_info.fs_type}, 挂载点 / Mount: {source_info.mount_point}"
        )
        self.logger.info(f"  目标 / Destination: {destination}")
        self.logger.info(
            "    文件系统 / Filesystem: "
            f"{dest_info.fs_type}, 挂载点 / Mount: {dest_info.mount_point}"
        )

        source_is_windows = source_info.fs_type.lower() in self.WINDOWS_FS_TYPES
        dest_is_windows = dest_info.fs_type.lower() in self.WINDOWS_FS_TYPES

        recommendations = []
        warnings = []

        # 确定场景类型 / Determine scenario type
        if source_is_windows and not dest_is_windows:
            scenario_type = "Windows to Linux"
            recommendations.extend(
                [
                    "--modify-window=2 (扩大时间戳窗口 / Expand timestamp window)",
                    "--no-perms (忽略Windows权限 / Ignore Windows permissions)",
                    "--no-owner --no-group (忽略所有者和组 / Ignore owner and group)",
                ]
            )
            warnings.extend(
                [
                    "时间戳精度差异: Windows(100ns) vs Linux(1s) / Timestamp precision difference",
                    "权限系统不兼容 / Permission system incompatible",
                    "符号链接处理可能不同 / Symlink handling may differ",
                ]
            )
        elif not source_is_windows and dest_is_windows:
            scenario_type = "Linux to Windows"
            recommendations.extend(
                [
                    "--modify-window=2 (扩大时间戳窗口 / Expand timestamp window)",
                    "--no-perms (忽略Linux权限 / Ignore Linux permissions)",
                    "--no-owner --no-group (忽略所有者和组 / Ignore owner and group)",
                ]
            )
            warnings.extend(
                [
                    "时间戳精度差异 / Timestamp precision difference",
                    "权限信息会丢失 / Permission information will be lost",
                    "符号链接可能无法创建 / Symlinks may not be created",
                ]
            )
        elif not source_is_windows and not dest_is_windows:
            scenario_type = "Linux to Linux"
            recommendations.extend(
                [
                    "-a (归档模式，保留所有属性 / Archive mode, preserve all attributes)",
                    "--modify-window=1 (标准时间戳窗口 / Standard timestamp window)",
                ]
            )
        elif source_is_windows and dest_is_windows:
            scenario_type = "Windows to Windows"
            recommendations.extend(
                [
                    "--modify-window=2 (扩大时间戳窗口 / Expand timestamp window)",
                    "-rlt (递归、链接、时间 / Recursive, links, time)",
                ]
            )
        else:
            scenario_type = "Unknown scenario"
            recommendations.extend(
                [
                    "--modify-window=2 (保守时间戳窗口 / Conservative timestamp window)",
                    "-rlt (基本文件属性 / Basic file attributes)",
                ]
            )

        return SyncScenario(
            source_fs=source_info.fs_type,
            dest_fs=dest_info.fs_type,
            scenario_type=scenario_type,
            recommendations=recommendations,
            warnings=warnings,
        )

    def analyze_empty_directories(self, source_path: str, max_display: int = 10) -> list[str]:
        """分析源目录中的空文件夹 / Analyze empty directories in source"""
        if not Path(source_path).exists():
            return []

        self.logger.info(f"空文件夹分析 / Empty directory analysis: {source_path}")

        empty_dirs = []
        try:
            for root, dirs, files in os.walk(source_path):
                # 检查当前目录是否为空 / Check if current directory is empty
                if not files and not dirs:
                    rel_path = Path(root).relative_to(source_path)
                    if str(rel_path) != ".":
                        empty_dirs.append(str(rel_path))

                if len(empty_dirs) >= 100:  # 限制收集数量 / Limit collection
                    break
        except Exception as e:
            self.logger.error(f"分析空文件夹时出错 / Error analyzing empty directories: {e}")
            return []

        if empty_dirs:
            self.logger.info(
                f"  发现 {len(empty_dirs)} 个空文件夹 / Found {len(empty_dirs)} empty directories"
            )
            for empty_dir in empty_dirs[:max_display]:
                self.logger.debug(f"    📁 {empty_dir}")
            if len(empty_dirs) > max_display:
                self.logger.debug(
                    f"    ... 还有 {len(empty_dirs) - max_display} 个 / "
                    f"{len(empty_dirs) - max_display} more"
                )
        else:
            self.logger.info("  未发现空文件夹 / No empty directories found")

        return empty_dirs


class RsyncCommandBuilder:
    """Rsync 命令构建器 / Rsync command builder"""

    def __init__(self, logger: logging.Logger):
        self.logger = logger

    def build_command(
        self,
        source: str,
        destination: str,
        scenario: SyncScenario,
        sync_mode: str = "mirror",
        dry_run: bool = False,
        exclude_empty_dirs: bool = True,
        folder_white_list: list[str] | None = None,
        folder_black_list: list[str] | None = None,
        extension_white_list: list[str] | None = None,
        extension_black_list: list[str] | None = None,
    ) -> list[str]:
        """构建rsync命令 / Build rsync command"""

        # 基础参数 / Base arguments
        cmd = ["rsync", "-vh", "--progress"]

        # 根据场景选择参数 / Select parameters based on scenario
        if scenario.scenario_type == "Linux to Linux":
            cmd.extend(["-a", "--modify-window=1"])
        else:
            cmd.extend(["-rlt", "--modify-window=2", "--no-perms", "--no-owner", "--no-group"])

            # 对于Windows目标，使用大小比较 / For Windows destination, use size comparison
            if scenario.dest_fs.lower() in FileSystemAnalyzer.WINDOWS_FS_TYPES:
                cmd.append("--size-only")

        # 同步模式 / Sync mode
        if sync_mode == "mirror":
            cmd.append("--delete")
        elif sync_mode == "safe":
            cmd.append("--ignore-existing")
        # update 模式不需要额外参数 / update mode needs no extra parameters

        # 空文件夹排除 / Empty directory exclusion
        if exclude_empty_dirs:
            cmd.append("--prune-empty-dirs")

        # Dry run
        if dry_run:
            cmd.append("--dry-run")

        # 构建过滤器 / Build filters
        filter_args = self._build_filters(
            folder_white_list or [],
            folder_black_list or [],
            extension_white_list or [],
            extension_black_list or [],
        )

        # 确保路径以斜杠结尾 / Ensure paths end with slash
        if not source.endswith("/"):
            source += "/"
        if not destination.endswith("/"):
            destination += "/"

        return cmd + filter_args + [source, destination]

    def _build_filters(
        self,
        folder_white_list: list[str],
        folder_black_list: list[str],
        extension_white_list: list[str],
        extension_black_list: list[str],
    ) -> list[str]:
        """构建过滤器参数 / Build filter arguments"""
        filters = []

        # 首先包含所有目录 / Include all directories first
        filters.extend(["--include", "*/"])

        # 文件夹白名单 / Folder whitelist
        for folder in folder_white_list:
            filters.extend(["--include", f"{folder}/", "--include", f"{folder}/**"])

        # 文件扩展名白名单 / Extension whitelist
        for ext in extension_white_list:
            filters.extend(["--include", f"*.{ext}"])
            if ext != ext.upper():
                filters.extend(["--include", f"*.{ext.upper()}"])

        # 文件夹黑名单 / Folder blacklist
        for folder in folder_black_list:
            filters.extend(["--exclude", f"{folder}/"])

        # 文件扩展名黑名单 / Extension blacklist
        for ext in extension_black_list:
            filters.extend(["--exclude", f"*.{ext}"])
            if ext != ext.upper():
                filters.extend(["--exclude", f"*.{ext.upper()}"])

        # 如果指定了白名单，排除其他所有文件 / If whitelist specified, exclude all other files
        if extension_white_list or folder_white_list:
            filters.extend(["--exclude", "*"])

        return filters


class SyncManager:
    """同步管理器 / Sync manager"""

    SYNC_MODE_DESCRIPTIONS = {
        "mirror": "镜像同步 (删除目标中多余文件) / Mirror sync (delete extra files)",
        "update": "增量更新 (只添加/更新，不删除) / Incremental update (add/update only)",
        "safe": "安全同步 (不覆盖现有文件) / Safe sync (don't overwrite existing)",
    }

    def __init__(self, logger: logging.Logger):
        self.logger = logger
        self.fs_analyzer = FileSystemAnalyzer(logger)
        self.cmd_builder = RsyncCommandBuilder(logger)

    @staticmethod
    def check_rsync_available() -> bool:
        """检查rsync是否可用 / Check if rsync is available"""
        return shutil.which("rsync") is not None

    def validate_paths(self, source: str, destination: str, auto_create: bool = False) -> bool:
        """验证源路径和目标路径 / Validate source and destination paths"""
        source_path = Path(source)
        dest_path = Path(destination)

        if not source_path.exists():
            self.logger.error(f"源路径不存在 / Source path does not exist: {source}")
            return False

        if not dest_path.exists():
            if auto_create:
                try:
                    dest_path.mkdir(parents=True, exist_ok=True)
                    self.logger.info(
                        f"已创建目标目录 / Created destination directory: {destination}"
                    )
                except Exception as e:
                    self.logger.error(f"创建目标目录失败 / Failed to create destination: {e}")
                    return False
            else:
                self.logger.error(
                    f"目标路径不存在 / Destination path does not exist: {destination}"
                )
                return False

        return True

    def run_sync(
        self,
        config: dict,
        sync_mode: str = "mirror",
        dry_run: bool = False,
        exclude_empty_dirs: bool = True,
        auto_create_dest: bool = False,
    ) -> bool:
        """执行同步操作 / Execute sync operation"""
        source = config["source"]
        destination = config["destination"]

        # 验证路径 / Validate paths
        if not self.validate_paths(source, destination, auto_create_dest):
            return False

        # 分析场景 / Analyze scenario
        scenario = self.fs_analyzer.analyze_sync_scenario(source, destination)

        self.logger.info(f"同步类型 / Sync type: {scenario.scenario_type}")

        if scenario.recommendations:
            self.logger.info("推荐参数 / Recommended parameters:")
            for rec in scenario.recommendations:
                self.logger.info(f"  ✅ {rec}")

        if scenario.warnings:
            self.logger.warning("注意事项 / Warnings:")
            for warning in scenario.warnings:
                self.logger.warning(f"  ⚠️  {warning}")

        # 分析空文件夹 / Analyze empty directories
        empty_dirs = self.fs_analyzer.analyze_empty_directories(source)

        # 显示空文件夹设置 / Display empty directory settings
        if exclude_empty_dirs:
            self.logger.info("空文件夹排除: 已启用 / Empty dir exclusion: Enabled")
            if empty_dirs:
                self.logger.info(
                    f"  {len(empty_dirs)} 个空文件夹将不会被同步 / empty dirs will not be synced"
                )
        else:
            self.logger.info("空文件夹排除: 已禁用 / Empty dir exclusion: Disabled")
            if empty_dirs:
                self.logger.warning(
                    f"  {len(empty_dirs)} 个空文件夹将会被同步 / empty dirs will be synced"
                )

        # 构建命令 / Build command
        command = self.cmd_builder.build_command(
            source=source,
            destination=destination,
            scenario=scenario,
            sync_mode=sync_mode,
            dry_run=dry_run,
            exclude_empty_dirs=exclude_empty_dirs,
            folder_white_list=config.get("folder_white_list"),
            folder_black_list=config.get("folder_black_list"),
            extension_white_list=config.get("extension_white_list"),
            extension_black_list=config.get("extension_black_list"),
        )

        # 显示同步信息 / Display sync information
        self.logger.info("=" * 60)
        self.logger.info("通用文件同步 / Universal File Sync")
        self.logger.info(f"源 / Source: {source}")
        self.logger.info(f"目标 / Destination: {destination}")
        self.logger.info(f"预设 / Preset: {config.get('name', 'Unknown')}")
        self.logger.info(
            f"同步模式 / Sync mode: {self.SYNC_MODE_DESCRIPTIONS.get(sync_mode, sync_mode)}"
        )
        self.logger.info(f"场景 / Scenario: {scenario.scenario_type}")
        self.logger.info(
            f"空文件夹排除 / Empty dir exclusion: "
            f"{'启用' if exclude_empty_dirs else '禁用'} / "
            f"{'Enabled' if exclude_empty_dirs else 'Disabled'}"
        )

        if dry_run:
            self.logger.warning("模式: 模拟运行 / Mode: DRY RUN")

        self.logger.info("=" * 60)
        self.logger.debug(f"完整命令 / Full command: {' '.join(command)}")
        self.logger.info("=" * 60)

        # 执行命令 / Execute command
        try:
            result = subprocess.run(command, check=False)

            if result.returncode == 0:
                self.logger.info("同步操作完成 / Sync operation completed!")
                if dry_run:
                    self.logger.info("这是模拟运行，要实际执行请去掉--dry-run / This was a dry run")
                else:
                    self._show_post_sync_advice(scenario, exclude_empty_dirs)
                return True
            else:
                self.logger.error(
                    f"同步操作失败，返回码 / Sync failed, return code: {result.returncode}"
                )
                return False
        except KeyboardInterrupt:
            self.logger.warning("操作被用户中断 / Operation interrupted by user")
            return False
        except Exception as e:
            self.logger.error(f"执行过程中发生错误 / Error during execution: {e}")
            return False

    def _show_post_sync_advice(self, scenario: SyncScenario, exclude_empty_dirs: bool):
        """显示同步后建议 / Show post-sync advice"""
        self.logger.info("同步后建议 / Post-sync advice:")

        if scenario.scenario_type in ["Windows to Linux", "Linux to Windows"]:
            self.logger.info("  1. 验证文件完整性 / Verify file integrity")
            self.logger.info("  2. 检查时间戳 / Check timestamps")
            if exclude_empty_dirs:
                self.logger.info("  3. 空文件夹检查 / Empty directory check")
            self.logger.info("  4. 验证文件数量 / Verify file count")
        else:
            self.logger.info("  1. 快速验证 / Quick verification")
            if not exclude_empty_dirs:
                self.logger.info("  2. 空文件夹结构 / Empty directory structure")
            self.logger.info("  3. 权限检查 / Permission check (Linux to Linux only)")


class PresetManager:
    """预设管理器 / Preset manager"""

    def __init__(self, preset_dir: Path, logger: logging.Logger):
        self.preset_dir = preset_dir
        self.logger = logger
        self.presets: dict[str, dict] = {}

    def load_presets(self) -> dict[str, dict]:
        """加载所有预设文件 / Load all preset files"""
        preset_files = sorted(self.preset_dir.glob("preset_*.json"))

        for i, preset_file in enumerate(preset_files, 1):
            try:
                with open(preset_file, encoding="utf-8") as f:
                    preset_data = json.load(f)

                preset_name = preset_file.stem.replace("preset_", "")
                self.presets[str(i)] = {
                    "name": preset_data.get("name", preset_name),
                    "file": str(preset_file),
                    "data": preset_data,
                }
                self.logger.info(
                    f"加载预设 / Loaded preset: {preset_data.get('name', preset_name)}"
                )
            except json.JSONDecodeError as e:
                self.logger.error(f"JSON解析失败 / JSON parse error {preset_file}: {e}")
            except Exception as e:
                self.logger.error(f"加载预设文件失败 / Failed to load preset {preset_file}: {e}")

        return self.presets

    def get_preset(self, preset: str) -> dict | None:
        """
        获取指定预设 / Get preset by id, name or file path
        - 数字字符串: 作为编号
        - 名称: 精确匹配 data.name（区分大小写）
        - 文件路径: 若存在 .json 文件则直接加载
        """
        # by numeric id
        if preset in self.presets:
            return self.presets[preset]

        # by name
        for item in self.presets.values():
            if item["data"].get("name") == preset:
                return item

        # by file path
        p = Path(preset)
        if p.exists() and p.is_file():
            try:
                with open(p, encoding="utf-8") as f:
                    data = json.load(f)
                return {
                    "name": data.get("name", p.stem),
                    "file": str(p),
                    "data": data,
                }
            except Exception as e:
                self.logger.error(f"加载预设文件失败 / Failed to load preset file {p}: {e}")
                return None

        return None

    @staticmethod
    def normalize_and_validate_config(raw: dict) -> dict | None:
        """
        规范化并校验配置字段，确保类型正确，必填项存在。
        必填: source, destination
        可选数组: folder_white_list, folder_black_list, extension_white_list, extension_black_list
        返回规范化后的 dict；若校验失败返回 None
        """
        required = ["source", "destination"]
        for k in required:
            if k not in raw or not isinstance(raw[k], str) or not raw[k].strip():
                return None

        def to_list(v: list[str] | str | None) -> list[str]:
            if v is None:
                return []
            if isinstance(v, list):
                return [str(x) for x in v]
            if isinstance(v, str):
                return [v] if v.strip() else []
            return []

        return {
            "name": raw.get("name", "Unnamed preset"),
            "description": raw.get("description", ""),
            "source": raw["source"],
            "destination": raw["destination"],
            "folder_white_list": to_list(raw.get("folder_white_list")),
            "folder_black_list": to_list(raw.get("folder_black_list")),
            "extension_white_list": to_list(raw.get("extension_white_list")),
            "extension_black_list": to_list(raw.get("extension_black_list")),
        }

    def list_presets(self) -> list[tuple[str, str, str, str, str]]:
        """列出所有预设 / List all presets"""
        result: list[tuple[str, str, str, str, str]] = []
        for key, preset in self.presets.items():
            data = preset["data"]
            result.append(
                (
                    key,
                    data.get("name", "Unknown"),
                    data.get("source", ""),
                    data.get("destination", ""),
                    data.get("description", ""),
                )
            )
        return result


def setup_logging(verbose: bool = False, quiet: bool = False) -> logging.Logger:
    """设置日志系统 / Setup logging system"""
    logger = logging.getLogger("file_sync")
    logger.handlers.clear()

    if quiet:
        level = logging.ERROR
    elif verbose:
        level = logging.DEBUG
    else:
        level = logging.INFO

    logger.setLevel(level)

    # 控制台处理器 / Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)

    # 格式化器 / Formatter
    if verbose:
        formatter = logging.Formatter(
            "%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S"
        )
    else:
        formatter = logging.Formatter("%(message)s")

    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)

    return logger


def interactive_mode(
    sync_manager: SyncManager, preset_manager: PresetManager, logger: logging.Logger
):
    """交互式模式 / Interactive mode"""
    logger.info("=" * 60)
    logger.info("🔄 通用文件同步工具 / Universal File Sync Tool")
    logger.info("支持 / Supports: Linux↔Linux, Linux↔Windows, Windows↔Linux")
    logger.info("特性 / Features: 可选排除空文件夹 / Optional empty directory exclusion")
    logger.info("=" * 60)

    presets = preset_manager.list_presets()

    if not presets:
        logger.error("未找到任何预设文件 / No preset files found")
        logger.info("请在同目录下创建 preset_*.json 文件 / Please create preset_*.json files")
        logger.info("可参考 template.json / Refer to template.json")
        return

    # 显示预设列表 / Display preset list
    for preset_id, name, source, dest, desc in presets:
        logger.info(f"{preset_id}. {name}")
        logger.info(f"   源 / Source: {source}")
        logger.info(f"   目标 / Destination: {dest}")
        if desc:
            logger.info(f"   描述 / Description: {desc}")
        logger.info("")

    logger.info("0. 退出 / Exit")
    logger.info("=" * 60)

    try:
        choice = input(f"请选择预设 / Select preset (0-{len(presets)}): ").strip()

        if choice == "0":
            logger.info("再见! / Goodbye! 👋")
            return

        preset = preset_manager.get_preset(choice)
        if not preset:
            logger.error("无效选择 / Invalid choice")
            return

        raw_config = preset["data"]
        config = PresetManager.normalize_and_validate_config(raw_config)  # type: ignore
        if not config:
            logger.error(
                "配置缺失或字段类型错误：至少需要 source 与 destination（字符串）/ "
                "Invalid config: requires string fields 'source' and 'destination'"
            )
            return
        logger.info(f"\n选择的预设 / Selected preset: {config.get('name')}")

        # 同步模式选择 / Sync mode selection
        logger.info("\n同步模式 / Sync mode:")
        logger.info("1. 镜像同步 / Mirror sync (recommended)")
        logger.info("2. 增量更新 / Incremental update")
        logger.info("3. 安全同步 / Safe sync")

        mode_choice = input("请选择 / Select (1-3): ").strip()
        sync_modes = {"1": "mirror", "2": "update", "3": "safe"}
        sync_mode = sync_modes.get(mode_choice, "mirror")

        # 执行方式选择 / Execution mode selection
        logger.info("\n执行方式 / Execution mode:")
        logger.info("1. 模拟运行 / Dry run")
        logger.info("2. 实际执行 / Actual execution")

        exec_choice = input("请选择 / Select (1-2): ").strip()
        dry_run = exec_choice == "1"

        # 空文件夹排除选择 / Empty directory exclusion selection
        logger.info("\n空文件夹排除 / Empty directory exclusion:")
        logger.info("1. 启用 (推荐) / Enable (recommended)")
        logger.info("2. 禁用 / Disable")

        exclude_choice = input("请选择 / Select (1-2): ").strip()
        exclude_empty_dirs = exclude_choice != "2"

        # 执行同步 / Execute sync
        if not dry_run:
            confirm = input("\n确认执行同步操作? / Confirm sync operation? (y/n): ").strip().lower()
            if confirm != "y":
                logger.info("操作已取消 / Operation cancelled")
                return

        sync_manager.run_sync(config, sync_mode, dry_run, exclude_empty_dirs, auto_create_dest=True)

    except KeyboardInterrupt:
        logger.warning("\n操作被用户中断 / Operation interrupted by user")
    except Exception as e:
        logger.error(f"发生错误 / Error occurred: {e}")


def main():
    """主函数 / Main function"""
    parser = argparse.ArgumentParser(
        description="通用文件同步工具 / Universal File Sync Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "-p",
        "--preset",
        type=str,
        help="预设ID/名称或文件路径(.json) / Preset ID, name or file path (.json)",
    )
    parser.add_argument(
        "-m",
        "--mode",
        type=str,
        choices=["mirror", "update", "safe"],
        default="mirror",
        help="同步模式 / Sync mode (default: mirror)",
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="模拟运行，不实际执行 / Dry run, do not execute",
    )
    parser.add_argument(
        "--no-exclude-empty",
        action="store_true",
        help="不排除空文件夹 / Do not exclude empty directories",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="详细输出 / Verbose output")
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="静默模式，只显示错误 / Quiet mode, show errors only",
    )
    parser.add_argument(
        "--auto-create-dest",
        action="store_true",
        help="自动创建目标目录 / Auto-create destination directory",
    )

    args = parser.parse_args()

    # 设置日志 / Setup logging
    logger = setup_logging(verbose=args.verbose, quiet=args.quiet)

    # 检查rsync / Check rsync
    if not SyncManager.check_rsync_available():
        logger.error("错误: 未找到rsync命令 / Error: rsync command not found")
        logger.info("Ubuntu/Debian: sudo apt install rsync")
        logger.info("Arch/Manjaro: sudo pacman -S rsync")
        sys.exit(1)

    # 初始化管理器 / Initialize managers
    script_dir = Path(__file__).parent
    preset_manager = PresetManager(script_dir, logger)
    preset_manager.load_presets()

    sync_manager = SyncManager(logger)

    # CLI 模式或交互模式 / CLI mode or interactive mode
    if args.preset:
        # CLI 模式 / CLI mode
        preset = preset_manager.get_preset(args.preset)
        if not preset:
            logger.error(f"未找到预设 / Preset not found: {args.preset}")
            sys.exit(1)

        # 规范化配置 / Normalize & validate config
        config = PresetManager.normalize_and_validate_config(preset["data"])  # type: ignore
        if not config:
            logger.error(
                "配置缺失或字段类型错误：至少需要 source 与 destination（字符串）/ "
                "Invalid config: requires string fields 'source' and 'destination'"
            )
            sys.exit(1)
        exclude_empty_dirs = not args.no_exclude_empty

        success = sync_manager.run_sync(
            config, args.mode, args.dry_run, exclude_empty_dirs, args.auto_create_dest
        )

        sys.exit(0 if success else 1)
    else:
        # 交互模式 / Interactive mode
        interactive_mode(sync_manager, preset_manager, logger)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n程序被用户中断 / Program interrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"程序运行出错 / Program error: {e}")
        sys.exit(1)
