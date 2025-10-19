# Git Configuration Setup Script

自动配置 Git 设置的 Python 脚本 / Python script for automatic Git configuration setup

## 功能 / Features

- 💻 根据操作系统自动设置 `core.autocrlf` / Automatically set `core.autocrlf` based on OS
  - Windows: `true`
  - Unix/Linux/macOS/WSL: `input`
- 🌐 双语输出支持 / Bilingual output support (Chinese/English)
- 🧪 支持 dry-run（预览变更）和 verbose（调试）模式 / Supports dry-run and verbose modes

## 使用方法 / Usage

### 基本使用 / Basic Usage

```bash
# 运行配置脚本 / Run the configuration script (will apply changes)
python setup_git_config.py

# 仅预览将要执行的操作（dry-run，不会修改配置）
python setup_git_config.py --dry-run
python setup_git_config.py -n

# 开启调试输出（verbose）以获取更多日志
python setup_git_config.py --verbose
python setup_git_config.py -v

# 查看当前配置 / Show current configuration
python setup_git_config.py show

# 显示帮助信息 / Show help information
python setup_git_config.py --help
```

### 从任何位置运行 / Run from anywhere

```bash
# 使用绝对路径 / Using absolute path
python /path/to/dotfiles/scripts/git/setup_git_config.py

# 或者先切换到脚本目录 / Or change to script directory first
cd /path/to/dotfiles/scripts/git
python setup_git_config.py
```

## 前提条件 / Prerequisites

- ✅ Python 3.6+ 已安装 / Python 3.6+ installed
- ✅ Git 已安装并在 PATH 中 / Git installed and in PATH

## 配置说明 / Configuration Details

脚本会根据当前系统自动设置以下全局 Git 配置：
The script automatically sets the following global Git configuration based on OS:

- `core.autocrlf`
  - Windows: `true`
  - Unix/Linux/macOS/WSL: `input`

## 错误处理 / Error Handling

脚本包含完善的错误处理：
The script includes comprehensive error handling:

- ❌ Git 未安装检测 / Git not installed detection
- ❌ 配置文件缺失检测 / Missing configuration file detection
- ❌ 用户信息缺失检测 / Missing user information detection
- ❌ Git 命令执行失败处理 / Git command execution failure handling

## 平台兼容性 / Platform compatibility

- Windows: 使用 Git for Windows 或在 PATH 中可用的 git，脚本会将 core.autocrlf 设置为 `true`。
- Linux/macOS/WSL: 脚本将 core.autocrlf 设置为 `input`（WSL 通过 `WSL_DISTRO_NAME` 或 `/proc/version` 中包含 `microsoft` 自动检测）。

注意：确保在 Windows 上安装 Git 并添加到 PATH；在受限环境下（公司策略）写入全局配置可能失败。

## 示例输出 / Example Output

```text
开始 Git 配置设置（仅 core.autocrlf）... / Starting Git configuration setup (core.autocrlf only)...
检测到操作系统: Windows，将设置 core.autocrlf = true / Detected OS: Windows, will set core.autocrlf = true
设置 core.autocrlf = true / Set core.autocrlf = true
Git 配置设置完成！ / Git configuration setup completed successfully!

当前 Git 配置: / Current Git configuration:
  core.autocrlf = true
```
