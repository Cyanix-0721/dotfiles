"""Shared configuration for file synchronization scripts.
提供给传输脚本使用的共用默认账户配置。
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Optional
import os


@dataclass(frozen=True)
class DefaultAccount:
    """默认账户信息 / Default account information."""

    username: str
    password: str
    ssh_private_key: Optional[Path] = None
    ssh_public_key: Optional[Path] = None


def resolve_key_path(key_path: Optional[str]) -> Optional[Path]:
    """将字符串路径转换为绝对 Path（若提供）。/ Resolve key path to absolute Path if supplied."""
    if not key_path:
        return None
    path = Path(key_path).expanduser()
    return path.resolve()


# Build DEFAULT_ACCOUNT from environment variables when available, otherwise
# fall back to the literal defaults (username=0d00, password=0721, keys None).
DEFAULT_ACCOUNT = DefaultAccount(
    username=os.environ.get("FILESYNC_USERNAME", "0d00"),
    password=os.environ.get("FILESYNC_PASSWORD", "0721"),
    ssh_private_key=resolve_key_path(os.environ.get("FILESYNC_SSH_PRIVATE_KEY")),
    ssh_public_key=resolve_key_path(os.environ.get("FILESYNC_SSH_PUBLIC_KEY")),
)
