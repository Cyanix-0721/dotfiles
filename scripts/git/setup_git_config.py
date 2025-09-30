#!/usr/bin/env python3
"""
Git configuration setup script
自动配置 Git 设置脚本

This script reads the user.name and user.email from the dotfiles repository's
dot_gitconfig file and applies them globally. It also sets the appropriate
core.autocrlf setting based on the operating system.

该脚本从 dotfiles 仓库的 dot_gitconfig 文件中读取 user.name 和 user.email，
并将其应用为全局设置。同时根据操作系统设置适当的 core.autocrlf 配置。
"""

import os
import sys
import platform
import subprocess
import configparser
from pathlib import Path


class GitConfigManager:
    """Git configuration management class / Git 配置管理类"""

    def __init__(self):
        self.script_dir = Path(__file__).parent.absolute()
        self.dotfiles_root = self.script_dir.parent.parent
        self.gitconfig_path = self.dotfiles_root / "dot_gitconfig"

    def log(self, message_cn, message_en):
        """Print bilingual log messages / 打印双语日志信息"""
        print(f"{message_cn} / {message_en}")

    def error(self, message_cn, message_en):
        """Print bilingual error messages / 打印双语错误信息"""
        print(f"错误 / Error: {message_cn} / {message_en}", file=sys.stderr)

    def check_git_installed(self):
        """Check if git is installed / 检查是否安装了 git"""
        try:
            subprocess.run(["git", "--version"], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def read_dotfiles_gitconfig(self):
        """Read user configuration from dot_gitconfig / 从 dot_gitconfig 读取用户配置"""
        if not self.gitconfig_path.exists():
            self.error(
                f"找不到配置文件: {self.gitconfig_path}",
                f"Configuration file not found: {self.gitconfig_path}",
            )
            return None, None

        try:
            config = configparser.ConfigParser()
            config.read(self.gitconfig_path)

            if "user" not in config:
                self.error(
                    "配置文件中没有找到 [user] 部分",
                    "No [user] section found in configuration file",
                )
                return None, None

            user_name = config.get("user", "name", fallback=None)
            user_email = config.get("user", "email", fallback=None)

            if not user_name or not user_email:
                self.error(
                    "配置文件中缺少用户名或邮箱",
                    "Missing username or email in configuration file",
                )
                return None, None

            return user_name, user_email

        except Exception as e:
            self.error(
                f"读取配置文件时出错: {e}", f"Error reading configuration file: {e}"
            )
            return None, None

    def get_autocrlf_setting(self):
        """Get appropriate autocrlf setting based on OS / 根据操作系统获取适当的 autocrlf 设置"""
        system = platform.system().lower()
        if system == "windows":
            return "true"
        else:
            return "input"

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
        self.log("开始 Git 配置设置...", "Starting Git configuration setup...")

        # Check if git is installed
        if not self.check_git_installed():
            self.error(
                "Git 未安装或不在 PATH 中", "Git is not installed or not in PATH"
            )
            return False

        # Read configuration from dot_gitconfig
        user_name, user_email = self.read_dotfiles_gitconfig()
        if not user_name or not user_email:
            return False

        # Get autocrlf setting
        autocrlf_value = self.get_autocrlf_setting()
        system_name = platform.system()

        self.log(
            f"检测到操作系统: {system_name}，将设置 core.autocrlf = {autocrlf_value}",
            f"Detected OS: {system_name}, will set core.autocrlf = {autocrlf_value}",
        )

        # Apply configurations
        configs_to_set = [
            ("user.name", user_name),
            ("user.email", user_email),
            ("core.autocrlf", autocrlf_value),
        ]

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

        configs_to_show = ["user.name", "user.email", "core.autocrlf"]
        for key in configs_to_show:
            value = self.get_current_git_config(key)
            if value:
                print(f"  {key} = {value}")
            else:
                print(f"  {key} = (未设置 / not set)")


def main():
    """Main function / 主函数"""
    if len(sys.argv) > 1 and sys.argv[1] in ["-h", "--help", "help"]:
        print(__doc__)
        return 0

    manager = GitConfigManager()

    if len(sys.argv) > 1 and sys.argv[1] in ["show", "status"]:
        manager.show_current_config()
        return 0

    success = manager.setup_git_config()

    print()  # Empty line for readability
    manager.show_current_config()

    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
