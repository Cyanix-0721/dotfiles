# smb

该目录包含用于在 Windows 上设置 SMB 共享的脚本。

主要脚本

- `setup_smb.py`
  - 用途：创建/更新一个本地用户（用于 SMB 共享），并发布仓库中预定义的目录为 SMB 共享；也支持卸载（删除共享与用户）。
  - 要求：必须在 Windows 系统上运行，并以管理员权限（elevated）打开 PowerShell 或 CMD。
  - 使用示例：
    - 交互式运行（在管理员 PowerShell 中直接运行，会出现菜单）：
      python .\setup_smb.py

    - 以命令行方式安装共享（设置为只读，默认）：
      python .\setup_smb.py install

    - 以命令行方式安装共享并授予读写权限：
      python .\setup_smb.py install --permission change
      或者使用快捷参数：
      python .\setup_smb.py install --rw

    - 卸载（删除共享与用户）：
      python .\setup_smb.py uninstall

  - 配置来源：
    - 脚本会从上级目录的 `config.py` 导入 `DEFAULT_ACCOUNT`，因此你可以通过设置环境变量来改变默认的 SMB 用户名/密码（详见上层 `README.md`）。

注意事项与安全

- 脚本会尝试创建指定路径（`SHARES` 中配置的目录），请确保路径正确且你愿意在这些位置创建目录。
- 脚本使用明文密码创建本地用户；如果你对安全有更高要求，建议先在 `config.py` 中改为读取更安全的凭据来源，或在运行前将环境变量注入会话中。
- 请确认防火墙和网络策略允许 SMB（脚本会尝试启用“文件和打印机共享”相关防火墙规则）。

自定义

`setup_smb.py` 顶部有一些可编辑的常量：

- `SMB_USER` / `SMB_PASSWORD`：可直接覆盖默认导入值。
- `DEFAULT_PERMISSION`：默认权限（`read` 或 `change`）。
- `SHARES`：一个列表，定义要发布的共享（包含 `path`, `name`, `description`）。

如果你想添加/删除共享或更改路径，直接编辑 `SHARES` 列表并再次运行安装流程。

故障排查

- 如果脚本提示需要管理员权限，请用“以管理员身份运行”的 PowerShell/CMD 重新启动。
- 如果某个 `net` 命令失败，尝试在管理员命令行中单独运行该命令查看更详细的错误输出。
- 如果防火墙组无法启用，脚本会尝试使用中文规则名作为回退，但在某些本地化 Windows 版本上仍可能失败，这时需手动检查防火墙设置。
