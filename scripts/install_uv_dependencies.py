"""Install Python dependencies via uv / 使用 uv 安装 Python 依赖。

This helper reads the shared requirements file under ``scripts/`` and invokes the
``uv`` CLI to install all listed packages. It ensures the project Python version
declared in ``.python-version`` is available as a uv-managed interpreter and
creates a dedicated uv virtual environment (``.venv``) before installing.
"""

from __future__ import annotations

import platform
import subprocess
import sys
from pathlib import Path

VERSION_FILE_NAME = ".python-version"

BASE_DIR = Path(__file__).resolve().parent
REQUIREMENT_FILES = [BASE_DIR / "requirements.txt"]
PLATFORM_FILES = {
    "Windows": BASE_DIR / "requirements-windows.txt",
    "Linux": BASE_DIR / "requirements-linux.txt",
}
VENV_DIR = BASE_DIR / ".venv"


def resolve_python_spec() -> str:
    """Resolve desired Python spec / 解析目标 Python 规格。"""
    candidate = BASE_DIR / VERSION_FILE_NAME
    if not candidate.exists():
        print(f"[ERROR] Version file not found / 未找到版本文件: {candidate}")
        sys.exit(1)

    spec = candidate.read_text(encoding="utf-8").strip()
    if not spec:
        print(f"[ERROR] Version file is empty / 版本文件为空: {candidate}")
        sys.exit(1)
    return spec


def ensure_uv_python(spec: str) -> Path:
    """Install and locate uv-managed Python / 安装并定位 uv 管理的 Python。"""
    print(
        f"[INFO] Ensuring uv Python {spec} is installed / 确保安装 uv Python {spec}。"
    )
    try:
        subprocess.run(["uv", "python", "install", spec], check=True)
    except FileNotFoundError:
        print(
            "[ERROR] 'uv' executable not found. Please install uv and ensure it is in PATH."
        )
        print("[错误] 未找到 'uv' 可执行文件。请安装 uv 并确保其在 PATH 中。")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(
            f"[ERROR] Failed to install uv python {spec} (exit code {exc.returncode})."
        )
        print(f"[错误] 安装 uv python {spec} 失败（退出码 {exc.returncode}）。")
        sys.exit(exc.returncode)

    try:
        result = subprocess.run(
            ["uv", "python", "find", spec],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        print(
            "[ERROR] 'uv' executable not found. Please install uv and ensure it is in PATH."
        )
        print("[错误] 未找到 'uv' 可执行文件。请安装 uv 并确保其在 PATH 中。")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(
            f"[ERROR] Unable to locate uv python {spec} (exit code {exc.returncode})."
        )
        print(f"[错误] 无法定位 uv python {spec}（退出码 {exc.returncode}）。")
        sys.exit(exc.returncode)

    path = Path(result.stdout.strip())
    if not path.exists():
        print(
            f"[ERROR] Located uv python path does not exist / uv python 路径不存在: {path}"
        )
        sys.exit(1)
    return path


def venv_python_path() -> Path:
    """Return interpreter path inside the uv-managed virtual env / 返回虚拟环境内的解释器路径。"""
    if platform.system() == "Windows":
        return VENV_DIR / "Scripts" / "python.exe"
    return VENV_DIR / "bin" / "python"


def ensure_uv_venv(spec: str) -> None:
    """Ensure the uv virtual environment exists / 确保 uv 虚拟环境已创建。"""
    interpreter = venv_python_path()
    if interpreter.exists():
        return

    print(
        f"[INFO] Creating uv virtual environment at / 正在创建 uv 虚拟环境: {VENV_DIR}。"
    )
    try:
        subprocess.run(
            ["uv", "venv", "--python", spec],
            check=True,
            cwd=BASE_DIR,
        )
    except FileNotFoundError:
        print(
            "[ERROR] 'uv' executable not found. Please install uv and ensure it is in PATH."
        )
        print("[错误] 未找到 'uv' 可执行文件。请安装 uv 并确保其在 PATH 中。")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(f"[ERROR] Failed to create uv venv (exit code {exc.returncode}).")
        print(f"[错误] 创建 uv 虚拟环境失败（退出码 {exc.returncode}）。")
        sys.exit(exc.returncode)

    if not interpreter.exists():
        print(
            f"[ERROR] Virtual environment interpreter missing / 虚拟环境解释器缺失: {interpreter}"
        )
        sys.exit(1)


def existing_requirement_files() -> list[Path]:
    """Collect requirement files that exist on disk / 收集当前存在的依赖文件。"""
    files: list[Path] = []
    for req_file in REQUIREMENT_FILES:
        if req_file.exists():
            files.append(req_file)
        else:
            print(f"[WARN] Requirements file not found / 未找到依赖文件: {req_file}")

    platform_file = PLATFORM_FILES.get(platform.system())
    if platform_file and platform_file.exists():
        files.append(platform_file)
    elif platform_file:
        print(
            f"[INFO] Platform-specific requirements file missing / 未找到平台特定依赖文件: {platform_file}"
        )

    return files


def main() -> None:
    """Run ``uv pip install`` for the shared and platform-specific requirements / 调用 ``uv pip install`` 安装通用与平台特定依赖。"""
    python_spec = resolve_python_spec()
    ensure_uv_python(python_spec)
    ensure_uv_venv(python_spec)

    files = existing_requirement_files()
    if not files:
        print("[ERROR] No requirement files found / 未找到依赖文件。")
        sys.exit(1)

    command = [
        "uv",
        "pip",
        "install",
        "--python",
        str(venv_python_path()),
    ]
    for file in files:
        command.extend(["--requirement", str(file)])

    print(f"[INFO] Executing / 执行中: {' '.join(command)}")

    try:
        subprocess.run(command, check=True)
    except FileNotFoundError:
        print(
            "[ERROR] 'uv' executable not found. Please install uv and ensure it is in PATH."
        )
        print("[错误] 未找到 'uv' 可执行文件。请安装 uv 并确保其在 PATH 中。")
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        print(f"[ERROR] uv reported failure (exit code {exc.returncode}).")
        print(f"[错误] uv 报告失败（退出码 {exc.returncode}）。")
        sys.exit(exc.returncode)

    # Print activation instructions
    print("\n" + "=" * 70)
    print("[SUCCESS] Dependencies installed successfully! / 依赖安装成功！")
    print("=" * 70)
    print("\nTo use the virtual environment, choose one of the following methods:")
    print("使用虚拟环境，请选择以下方式之一：")
    print(
        "\n1. Activate the virtual environment (traditional way) / 激活虚拟环境（传统方式）:"
    )
    if platform.system() == "Windows":
        print(f"   {VENV_DIR}\\Scripts\\Activate.ps1")
    else:
        print(f"   source {VENV_DIR}/bin/activate")
    print(
        "\n2. Run scripts directly with virtual environment Python / 直接使用虚拟环境的 Python:"
    )
    print(f"   {venv_python_path()} <your_script.py>")
    print("\n3. Use uv run (modern way) / 使用 uv run（现代方式）:")
    print(f"   uv run --python {VENV_DIR} <your_script.py>")
    print("=" * 70)


if __name__ == "__main__":
    main()
