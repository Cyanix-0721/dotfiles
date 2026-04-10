# 通用文件同步工具 / Universal File Sync Tool

自动化文件同步工具，支持 Linux/Windows 跨平台同步，基于 rsync 实现。

Automated file synchronization tool supporting Linux/Windows cross-platform sync, based on rsync.

## 功能特性 / Features

- 🔄 支持多种同步场景 / Multiple sync scenarios supported
  - Linux ↔ Linux
  - Linux ↔ Windows  
  - Windows ↔ Linux
- 🎯 智能文件系统检测 / Intelligent filesystem detection
  - 自动识别 NTFS、ext4、FAT32 等文件系统
  - 根据文件系统自动调整 rsync 参数
- 📁 灵活的过滤规则 / Flexible filtering rules
  - 文件夹白名单/黑名单
  - 文件扩展名白名单/黑名单
- 🗑️ 可选空文件夹排除 / Optional empty directory exclusion
- 💻 支持 CLI 和交互模式 / CLI and interactive mode support
- 📝 详细的日志输出 / Detailed logging output
- 🌐 双语支持 / Bilingual support (Chinese/English)

## 前提条件 / Prerequisites

- ✅ Python 3.7+ 已安装 / Python 3.7+ installed
- ✅ rsync 已安装 / rsync installed

  ```bash
  # Ubuntu/Debian
  sudo apt install rsync
  
  # Arch/Manjaro
  sudo pacman -S rsync
  
  # Fedora/RHEL
  sudo dnf install rsync
  ```

- ✅ 在 Linux 端执行 / Execute on Linux side

## 安装 / Installation

无需安装，直接运行脚本即可。

No installation required, run the script directly.

```bash
cd scripts/rsync
python rsync.py
```

## 配置文件 / Configuration

### 创建预设 / Create Preset

提示 / Note:

- 仅支持 JSON 预设文件（preset_*.json）。Only JSON presets are supported.

复制 `template.json` 并重命名为 `preset_<name>.json`：

Copy `template.json` and rename to `preset_<name>.json`:

```bash
cp template.json preset_mybackup.json
```

### 配置示例 / Configuration Example

```json
{
    "name": "音乐库同步",
    "description": "从NTFS只读分区同步音乐文件到本地音乐库",
    "source": "/mnt/DDDD/UserData/Music/Music/My collection/",
    "destination": "/home/user/Music/",
    
    "folder_white_list": [],
    "folder_black_list": ["temp", "cache"],
    
    "extension_white_list": [
        "flac", "wav", "mp3", "m4a", "aac", "ogg"
    ],
    "extension_black_list": []
}
```

### 配置字段说明 / Configuration Fields

| 字段 / Field           | 说明 / Description                                      |
| ---------------------- | ------------------------------------------------------- |
| `name`                 | 预设名称 / Preset name                                  |
| `description`          | 描述信息 / Description                                  |
| `source`               | 源目录路径 / Source directory path                      |
| `destination`          | 目标目录路径 / Destination directory path               |
| `folder_white_list`    | 文件夹白名单（只同步这些文件夹）/ Folder whitelist      |
| `folder_black_list`    | 文件夹黑名单（排除这些文件夹）/ Folder blacklist        |
| `extension_white_list` | 文件扩展名白名单（只同步这些类型）/ Extension whitelist |
| `extension_black_list` | 文件扩展名黑名单（排除这些类型）/ Extension blacklist   |

### 路径末尾斜杠说明 / Trailing Slash Behavior

⚠️ **重要**: rsync 对路径末尾斜杠的处理方式不同，请注意区分 / **Important**: rsync treats trailing slashes differently

**源目录斜杠 / Source Directory Slash:**

- **有斜杠** `/path/source/`：同步源目录**内的内容**到目标目录
  - 例如: `/mnt/Music/` → 将 Music 文件夹内的文件同步到目标
  - With slash: syncs **contents** of source directory to destination
  
- **无斜杠** `/path/source`：在目标目录**创建源目录的子文件夹**
  - 例如: `/mnt/Music` → 在目标目录创建 Music 子文件夹
  - Without slash: creates source directory **as a subdirectory** in destination

**目标目录斜杠 / Destination Directory Slash:**

- **建议始终以斜杠结尾** `/path/destination/`
  - 确保行为一致性，避免意外结果
  - Recommended to always end with slash for consistent behavior

**示例对比 / Example Comparison:**

```bash
# 有斜杠: /home/user/Music/ 会包含 song1.mp3, song2.mp3 等
# With slash: /home/user/Music/ will contain song1.mp3, song2.mp3, etc.
source: "/mnt/source/"
destination: "/home/user/Music/"

# 无斜杠: /home/user/Music/ 会包含 source/song1.mp3, source/song2.mp3 等
# Without slash: /home/user/Music/ will contain source/song1.mp3, source/song2.mp3, etc.
source: "/mnt/source"
destination: "/home/user/Music/"
```

## 使用方法 / Usage

### 交互模式 / Interactive Mode

直接运行脚本进入交互式菜单：

Run script directly to enter interactive menu:

```bash
python rsync.py
```

### 命令行模式 / CLI Mode

使用命令行参数直接执行同步：

Execute sync directly with command-line arguments:

```bash
# 基本用法：使用预设1，镜像同步
# Basic usage: Use preset 1, mirror sync
python rsync.py -p 1

# 模拟运行（不实际执行）
# Dry run (do not execute)
python rsync.py -p 1 --dry-run

# 详细输出
# Verbose output
python rsync.py -p 1 --verbose

# 增量更新模式（不删除目标中的文件）
# Update mode (do not delete files in destination)
python rsync.py -p 1 --mode update

# 不排除空文件夹
# Do not exclude empty directories
python rsync.py -p 1 --no-exclude-empty

# 自动创建目标目录
# Auto-create destination directory
python rsync.py -p 1 --auto-create-dest

# 组合使用
# Combined usage
python rsync.py -p 1 --mode mirror --dry-run --verbose
```

### 命令行参数 / CLI Arguments

| 参数 / Argument      | 说明 / Description                                                      |
| -------------------- | ----------------------------------------------------------------------- |
| `-p, --preset`       | 预设ID/名称或文件路径(.json) / Preset ID, name or file path (.json)     |
| `-m, --mode`         | 同步模式: `mirror`（镜像）, `update`（增量）, `safe`（安全）/ Sync mode |
| `-n, --dry-run`      | 模拟运行，不实际执行 / Dry run, do not execute                          |
| `--no-exclude-empty` | 不排除空文件夹 / Do not exclude empty directories                       |
| `-v, --verbose`      | 详细输出（调试模式）/ Verbose output (debug mode)                       |
| `-q, --quiet`        | 静默模式，只显示错误 / Quiet mode, errors only                          |
| `--auto-create-dest` | 自动创建目标目录 / Auto-create destination directory                    |

## 同步模式说明 / Sync Mode Description

### 镜像同步 / Mirror Sync (`mirror`)

- 使目标成为源的精确副本 / Make destination an exact copy of source
- **会删除**目标中多余的文件 / **Will delete** extra files in destination
- 推荐用于备份场景 / Recommended for backup scenarios

### 增量更新 / Update Mode (`update`)

- 只添加和更新文件 / Only add and update files
- **不会删除**目标中的文件 / **Will not delete** files in destination
- 适合持续累积的场景 / Suitable for continuous accumulation

### 安全同步 / Safe Sync (`safe`)

- 不覆盖目标中已存在的文件 / Do not overwrite existing files
- 只添加新文件 / Only add new files
- 最保守的模式 / Most conservative mode

## 文件系统兼容性 / Filesystem Compatibility

### Linux to Linux

- ✅ 完全兼容 / Fully compatible
- ✅ 保留所有文件属性 / Preserve all file attributes
- ✅ 保留权限和所有者信息 / Preserve permissions and ownership

### Linux ↔ Windows

- ⚠️ 时间戳精度差异 / Timestamp precision difference
- ⚠️ 权限信息会丢失 / Permission information will be lost
- ⚠️ 符号链接可能无法正常处理 / Symlinks may not work properly
- ✅ 自动调整参数以兼容 / Auto-adjust parameters for compatibility

## 常见问题 / FAQ

### Q: 为什么要在 Linux 端执行？

A: rsync 在 Linux 上性能最佳，且更好地处理各种文件系统。Windows 端可通过 WSL 或挂载的方式访问。

### Q: Why execute on Linux side?

A: rsync performs best on Linux and handles various filesystems better. Windows side can be accessed via WSL or mounts.

### Q: 空文件夹排除是什么意思？

A: 启用后，只同步包含文件的目录，避免创建大量空目录结构。推荐启用以保持目标目录整洁。

### Q: What does empty directory exclusion mean?

A: When enabled, only syncs directories containing files, avoiding creation of numerous empty directory structures. Recommended for keeping destination clean.

### Q: 如何查看将要同步的内容？

A: 使用 `--dry-run` 参数进行模拟运行，查看将要执行的操作但不实际修改文件。

### Q: How to preview what will be synced?

A: Use `--dry-run` parameter for simulation, see what will be done without actually modifying files.

### Q: 白名单和黑名单可以同时使用吗？

A: 可以。白名单优先级更高。如果同时指定，会先应用白名单，然后在白名单范围内应用黑名单。

### Q: Can whitelist and blacklist be used together?

A: Yes. Whitelist has higher priority. If both specified, whitelist is applied first, then blacklist within whitelist scope.

## 示例场景 / Example Scenarios

### 场景1: 备份音乐库 / Scenario 1: Music Library Backup

```json
{
    "name": "音乐库同步",
    "source": "/mnt/windows/Music/",
    "destination": "/home/user/Music/",
    "extension_white_list": ["flac", "mp3", "m4a", "wav"],
    "folder_black_list": ["temp", ".cache"]
}
```

```bash
python rsync.py -p 1 --mode mirror --dry-run
```

### 场景2: 安全的增量备份 / Scenario 2: Safe Incremental Backup

```bash
# 只添加新文件，不覆盖已存在的文件
# Only add new files, don't overwrite existing
python rsync.py -p 1 --mode safe
```

### 场景3: 同步特定文件夹 / Scenario 3: Sync Specific Folders

```json
{
    "name": "项目文件同步",
    "source": "/mnt/data/Projects/",
    "destination": "/home/user/Projects/",
    "folder_white_list": ["project-a", "project-b"],
    "extension_black_list": ["tmp", "log", "cache"]
}
```

## 注意事项 / Notes

1. ⚠️ 镜像模式会删除目标中多余的文件，请谨慎使用
   Mirror mode will delete extra files in destination, use with caution

2. 💡 建议先使用 `--dry-run` 模拟运行检查结果
   Recommend using `--dry-run` to preview results first

3. 📝 Windows 文件系统的时间戳精度较低，可能会导致文件被重新同步
   Windows filesystem has lower timestamp precision, may cause files to be re-synced

4. 🔒 跨平台同步时，权限信息会丢失，这是正常现象
   Permission information is lost in cross-platform sync, this is normal

5. 🗑️ 默认启用空文件夹排除，如需保留目录结构请使用 `--no-exclude-empty`
   Empty directory exclusion is enabled by default, use `--no-exclude-empty` to keep structure

## 故障排查 / Troubleshooting

### rsync 命令未找到 / rsync Command Not Found

```bash
# 安装 rsync
sudo apt install rsync  # Ubuntu/Debian
sudo pacman -S rsync    # Arch
```

### 权限被拒绝 / Permission Denied

确保对源目录有读权限，对目标目录有写权限。

Ensure read permission on source and write permission on destination.

### 目标目录不存在 / Destination Directory Not Exists

使用 `--auto-create-dest` 参数自动创建目标目录。

Use `--auto-create-dest` parameter to auto-create destination directory.
