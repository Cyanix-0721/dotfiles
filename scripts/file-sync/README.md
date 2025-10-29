# file-sync

此目录包含用于在不同方式下同步或发布文件的脚本集合。

目录结构概览：

- `rsync/` - Linux rsync 的同步脚本，用于单向文件同步。
- `sftp/` - 跨平台 SFTP 轻量服务器脚本（依赖 `asyncssh`，可使用 `uv` 安装）。
- `smb/` - Windows SMB 相关的助手脚本，用于创建 SMB 账户与共享。
- `config.py` - 共享配置（默认账号信息），供子脚本导入。有关需要设置的环境变量和示例，请参见下文。

## 依赖管理

脚本所需的 Python 依赖记录在 `scripts/requirements*.txt` 文件中，可通过 `uv` 安装：

```sh
cd scripts
python install_uv_dependencies.py
```

安装脚本会根据当前系统自动附加 `requirements-windows.txt` 或 `requirements-linux.txt`。

### 使用虚拟环境

安装依赖后，脚本会创建虚拟环境 `scripts/.venv`。运行脚本时需要使用虚拟环境：

#### 方式 1: 激活虚拟环境（适合运行多个命令）

**Windows (PowerShell):**

```powershell
cd scripts
.\.venv\Scripts\Activate.ps1
python file-sync\sftp\sftp_server.py
deactivate  # 用完后退出
```

**Linux/macOS:**

```bash
cd scripts
source .venv/bin/activate
python file-sync/sftp/sftp_server.py
deactivate  # 用完后退出
```

#### 方式 2: 直接使用虚拟环境的 Python（推荐）

**Windows:**

```powershell
scripts\.venv\Scripts\python.exe file-sync\sftp\sftp_server.py
```

**Linux/macOS:**

```bash
scripts/.venv/bin/python file-sync/sftp/sftp_server.py
```

#### 方式 3: 使用 uv run（最简单）

```sh
cd scripts
uv run --python .venv file-sync/sftp/sftp_server.py
```

## 配置（`config.py`）

`config.py` 会从环境变量读取默认账户信息：

- `FILESYNC_USERNAME`：默认用户名（若未设置，脚本默认 `0d00`）。
- `FILESYNC_PASSWORD`：默认密码（若未设置，脚本默认 `0721`）。
- `FILESYNC_SSH_PUBLIC_KEY`：可选，SSH 公钥路径（字符串，支持 `~` 展开）。用于 SFTP 服务器的公钥认证。

这些环境变量可用于覆盖 `config.py` 中的默认值，从而使脚本在不同机器/用户下更方便地配置。

### 在常见 shell 中设置环境变量

注意：以下示例分别展示了如何在当前会话中设置环境变量（一次性）以及如何在用户级别持久化这些变量。持久化方式因系统和 shell 不同，请根据自己的需要选择。

#### PowerShell（当前会话）

```powershell
$env:FILESYNC_USERNAME = "myuser"
$env:FILESYNC_PASSWORD = "mypassword"
$env:FILESYNC_SSH_PUBLIC_KEY = "$env:USERPROFILE\.ssh\id_rsa.pub"
```

#### PowerShell（持久化到用户环境变量，Windows）

```powershell
setx FILESYNC_USERNAME "myuser"
setx FILESYNC_PASSWORD "mypassword"
setx FILESYNC_SSH_PUBLIC_KEY "%USERPROFILE%\.ssh\id_rsa.pub"
```

注意：`setx` 设置的是持久变量，但不会影响当前会话。需要打开新终端或手动将变量导入当前会话。

#### Bash / Zsh（当前会话）

```bash
export FILESYNC_USERNAME="myuser"
export FILESYNC_PASSWORD="mypassword"
export FILESYNC_SSH_PUBLIC_KEY="~/.ssh/id_rsa.pub"
```

#### Bash / Zsh（持久化，将上述加入 `~/.bashrc` 或 `~/.zshrc`）

#### Fish（当前会话）

```fish
set -x FILESYNC_USERNAME "myuser"
set -x FILESYNC_PASSWORD "mypassword"
set -x FILESYNC_SSH_PUBLIC_KEY "~/.ssh/id_rsa.pub"
```

#### Fish（持久化为全局变量）

```fish
set -Ux FILESYNC_USERNAME "myuser"
set -Ux FILESYNC_PASSWORD "mypassword"
set -Ux FILESYNC_SSH_PUBLIC_KEY "~/.ssh/id_rsa.pub"
```

## 安全注意事项

- 避免在公共仓库或共享配置文件中硬编码敏感信息（如密码）。优先使用系统级的秘密管理器或 OS 提供的凭据存储。
- 对于生产或长期使用场景，建议只在会话中设置密码并从安全存储读取，而不是写入 shell 启动文件。
