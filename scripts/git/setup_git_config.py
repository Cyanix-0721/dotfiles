#!/usr/bin/env python3
"""
Git configuration setup script
自动配置 Git 设置脚本

This script sets the appropriate core.autocrlf based on the operating system.
该脚本仅根据操作系统设置合适的 core.autocrlf。
"""

import sys
import os
import argparse
import platform
import subprocess
import logging
from typing import Optional


class GitConfigManager:
    """Git configuration management class / Git 配置管理类"""

    def __init__(self, dry_run: bool = False, logger: Optional[logging.Logger] = None):
        self.dry_run = dry_run
        # Use provided logger or create module-level logger
        self.logger = logger or logging.getLogger("setup_git_config")

    def log(self, message_cn, message_en):
        """Log bilingual messages at INFO level / 以 INFO 级别记录双语信息"""
        self.logger.info(f"{message_cn} / {message_en}")

    def error(self, message_cn, message_en):
        """Log bilingual error messages at ERROR level / 以 ERROR 级别记录双语错误信息"""
        self.logger.error(f"错误 / Error: {message_cn} / {message_en}")

    def check_git_installed(self):
        """Check if git is installed / 检查是否安装了 git"""
        try:
            subprocess.run(["git", "--version"], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def get_autocrlf_setting(self):
        """Get appropriate autocrlf setting based on OS / 根据操作系统获取适当的 autocrlf 设置"""
        # Treat WSL as Linux (i.e. use 'input').
        if self.is_wsl():
            return "input"

        system = platform.system().lower()
        if system == "windows":
            return "true"
        else:
            return "input"

    def is_wsl(self):
        """Detect whether running under WSL. Returns True for WSL1/WSL2."""
        # Common reliable checks: presence of WSL_DISTRO_NAME env var or
        # /proc/version containing 'microsoft' (case-insensitive).
        try:
            if "WSL_DISTRO_NAME" in os.environ:
                return True
        except Exception:
            # os may not be available in some restricted environments; fallthrough
            pass

        if platform.system().lower() == "linux":
            try:
                with open("/proc/version", "r", encoding="utf-8", errors="ignore") as f:
                    contents = f.read().lower()
                    return "microsoft" in contents
            except Exception:
                return False
        return False

    def run_git_command(self, args):
        """Run git command safely / 安全地运行 git 命令"""
        try:
            result = subprocess.run(
                ["git"] + args, capture_output=True, text=True, check=True
            )
            return True, result.stdout.strip()
        except subprocess.CalledProcessError as e:
            return False, e.stderr.strip()

    def set_git_config(self, key, value):
        """Set a git configuration value / 设置 git 配置值"""
        if self.dry_run:
            # In dry-run mode, do not execute commands; just print what would run.
            self.log(
                f"[DRY RUN] 将运行: git config --global {key} {value}",
                f"[DRY RUN] would run: git config --global {key} {value}",
            )
            return True

        success, output = self.run_git_command(["config", "--global", key, value])
        if success:
            self.log(f"设置 {key} = {value}", f"Set {key} = {value}")
        else:
            self.error(f"设置 {key} 失败: {output}", f"Failed to set {key}: {output}")
        return success

    def get_current_git_config(self, key):
        """Get current git configuration value / 获取当前 git 配置值"""
        success, output = self.run_git_command(["config", "--global", "--get", key])
        return output if success else None

    def setup_git_config(self):
        """Main setup function / 主要设置函数"""
        self.log("开始 Git 配置设置（仅 core.autocrlf）...", "Starting Git configuration setup (core.autocrlf only)...")

        # Check if git is installed
        if not self.check_git_installed():
            self.error(
                "Git 未安装或不在 PATH 中", "Git is not installed or not in PATH"
            )
            return False

        # Get autocrlf setting
        autocrlf_value = self.get_autocrlf_setting()
        system_name = platform.system()

        self.log(
            f"检测到操作系统: {system_name}，将设置 core.autocrlf = {autocrlf_value}",
            f"Detected OS: {system_name}, will set core.autocrlf = {autocrlf_value}",
        )

        # Apply configurations
        configs_to_set = [("core.autocrlf", autocrlf_value)]

        success_count = 0
        for key, value in configs_to_set:
            current_value = self.get_current_git_config(key)
            if current_value == value:
                self.log(
                    f"{key} 已经设置为正确的值: {value}",
                    f"{key} is already set to correct value: {value}",
                )
                success_count += 1
            else:
                if current_value:
                    self.log(
                        f"当前 {key} = {current_value}，将更新为 {value}",
                        f"Current {key} = {current_value}, updating to {value}",
                    )

                if self.set_git_config(key, value):
                    success_count += 1

        if success_count == len(configs_to_set):
            self.log(
                "Git 配置设置完成！", "Git configuration setup completed successfully!"
            )
            return True
        else:
            self.error(
                f"部分配置设置失败 ({success_count}/{len(configs_to_set)} 成功)",
                f"Some configurations failed ({success_count}/{len(configs_to_set)} successful)",
            )
            return False

    def show_current_config(self):
        """Show current git configuration / 显示当前 git 配置"""
        self.log("当前 Git 配置:", "Current Git configuration:")

        # Only display core.autocrlf since this script only manages it.
        configs_to_show = ["core.autocrlf"]
        for key in configs_to_show:
            value = self.get_current_git_config(key)
            if value:
                self.logger.info(f"  {key} = {value}")
            else:
                self.logger.info(f"  {key} = (未设置 / not set)")


def main():
    """Main function / 主函数"""
    parser = argparse.ArgumentParser(
        description="Configure global Git core.autocrlf based on the operating system."
    )
    parser.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show actions without applying them",
    )
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="Enable verbose (DEBUG) logging",
    )
    parser.add_argument(
        "command",
        nargs="?",
        choices=["show", "status", "help"],
        help="Optional command: 'show' or 'status' to display current config, 'help' to show the docstring",
    )

    args = parser.parse_args()

    if args.command == "help":
        print(__doc__)
        return 0

    # Configure logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    logger = logging.getLogger("setup_git_config")

    manager = GitConfigManager(dry_run=args.dry_run, logger=logger)

    if args.command in ("show", "status"):
        manager.show_current_config()
        return 0

    success = manager.setup_git_config()

    print()  # Empty line for readability
    manager.show_current_config()

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
