# Git Configuration Setup Script

自动配置 Git 设置的 Python 脚本 / Python script for automatic Git configuration setup

## 功能 / Features

- 🔧 从 `dot_gitconfig` 文件读取用户名和邮箱 / Read username and email from `dot_gitconfig` file
- 🌍 自动应用为全局 Git 配置 / Automatically apply as global Git configuration  
- 💻 根据操作系统自动设置 `core.autocrlf` / Automatically set `core.autocrlf` based on OS
  - Windows: `true`
  - Unix/Linux/macOS: `input`
- 🌐 双语输出支持 / Bilingual output support (Chinese/English)

## 使用方法 / Usage

### 基本使用 / Basic Usage

```bash
# 运行配置脚本 / Run the configuration script
python setup_git_config.py

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
- ✅ 存在 `dot_gitconfig` 文件在 dotfiles 根目录 / `dot_gitconfig` file exists in dotfiles root

## 配置说明 / Configuration Details

脚本会读取 `../../dot_gitconfig` 文件中的以下配置：
The script reads the following configuration from `../../dot_gitconfig`:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

然后自动设置以下全局 Git 配置：
Then automatically sets the following global Git configurations:

- `user.name`
- `user.email`
- `core.autocrlf` (基于操作系统 / based on OS)

## 错误处理 / Error Handling

脚本包含完善的错误处理：
The script includes comprehensive error handling:

- ❌ Git 未安装检测 / Git not installed detection
- ❌ 配置文件缺失检测 / Missing configuration file detection
- ❌ 用户信息缺失检测 / Missing user information detection
- ❌ Git 命令执行失败处理 / Git command execution failure handling

## 示例输出 / Example Output

```text
开始 Git 配置设置... / Starting Git configuration setup...
检测到操作系统: Windows，将设置 core.autocrlf = true / Detected OS: Windows, will set core.autocrlf = true
设置 user.name = Cyanix-0721 / Set user.name = Cyanix-0721
设置 user.email = 34270450+Cyanix-0721@users.noreply.github.com / Set user.email = 34270450+Cyanix-0721@users.noreply.github.com
设置 core.autocrlf = true / Set core.autocrlf = true
Git 配置设置完成！ / Git configuration setup completed successfully!

当前 Git 配置: / Current Git configuration:
  user.name = Cyanix-0721
  user.email = 34270450+Cyanix-0721@users.noreply.github.com
  core.autocrlf = true
```
