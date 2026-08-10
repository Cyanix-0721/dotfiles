#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "Pillow",
# ]
# ///
"""
批量将图片文件夹打包为 CBZ 漫画脚本

功能：
1. 灵活判断目录结构，自动推导 title / series / writer
2. 为每个包含图片的文件夹生成 ComicInfo.xml 并打包为 CBZ
3. CBZ 内图片固定按名称升序（自然排序）重命名为 001.jpg、002.jpg ...（与 ComicInfo.xml 页码一致）
4. 可选删除已打包的源文件夹

目录结构判断（灵活，无需固定层级）：
- 根目录内嵌一层文件夹（每个子文件夹是一本漫画）
    title = series = 文件夹名
- 根目录内嵌两层（外层为系列层，内层为单卷漫画层）
    title = 内层文件夹名（本卷标题），series = 外层文件夹名（[] 后部分，系列名）
- 根目录本身就是漫画文件夹（图片直接在其中，例如"在 series 文件夹"或"在单个漫画文件夹"）
    title = series = 根目录名

名称解析规则：
- 文件夹名如 "[作者] 标题 系列"：[] 内为 writer，其后为 title
- 内层（系列）文件夹名也可能带 [] 前缀，例如 "[作者] 系列名 1"（系列第 1 卷），
  解析 series 时忽略该 [] 前缀；writer 一律取外层文件夹的 []
- 标题/系列后可能带全角（）或半角 () 括号，内含"原作"信息（如 "标题（原作：X）"），
  ComicInfo.xml 中忽略括号内容

CBZ 输出位置（默认）：
- 两层结构（漫画在 series 内）：CBZ 放在 series 文件夹内（与漫画文件夹同级），不嵌套子文件夹
- 单层结构（单个漫画直接含图）：CBZ 放在漫画文件夹内部，不向上移动
- 可用 -o/--out 指定统一输出目录

示例——四种运行场景的输出结构：
  root（漫画库）
  ├── [作者甲] 系列A/              ← 场景1: series 文件夹
  │   ├── [作者甲] 系列A 1/        ← comic 文件夹（含图片）
  │   ├── [作者甲] 系列A 2/        ← comic 文件夹（含图片）
  │   └── ← cbz 生成在这里（系列A 1.cbz、系列A 2.cbz），不嵌套
  └── [作者乙] 单行本/              ← 场景2: 单个漫画（含图片）
      └── ← cbz 生成在这里
  （在 series 文件夹内运行脚本=场景3，在单个漫画文件夹内运行=场景4）

联动（与 batch_rename_images.py 配合）：
1. 先用 batch_rename_images.py 批量重命名图片（保证排序与命名一致）
2. 再运行本脚本将每个文件夹打包为 CBZ
    例如：python batch_pack_cbz.py "D:\\漫画库"
    或在目标文件夹内直接运行：python batch_pack_cbz.py

使用方法：
python batch_pack_cbz.py [根目录] [选项]
- 不传根目录时询问执行位置：默认（脚本所在目录）/ 手动输入 / 弹出窗口选择

复制到目标目录运行（依赖自动自举）：
- 脚本头部含 PEP 723 依赖声明，用 uv 直接运行即可自动安装 Pillow 并执行：
    uv run batch_pack_cbz.py
- 若用系统 python 直接运行，需先安装 Pillow（见下方依赖说明）

命令行选项：
  root                根目录（缺省询问：默认脚本目录 / 手动输入 / 弹窗选择）
  -o, --out 目录      指定 CBZ 统一输出目录（缺省：两层结构放 series 内 / 单层放漫画文件夹内）
  --lang {skip,ja,zh,interactive}
                      LanguageISO：skip 不生成 / ja 全部日语 / zh 全部中文 /
                      interactive 逐文件夹交互选择（缺省交互式询问）
  --volume {skip,auto,input}
                      Volume 模式：skip 不生成 / auto 自动检测（同系列存在
                      更高卷号时，无卷号的漫画自动推断为第 1 卷）/
                      input 逐文件夹输入（缺省交互式询问）
  -d, --delete        打包成功后自动删除源文件夹（不询问）
  -k, --keep          打包后保留源文件夹（不询问，默认行为）
  -y, --yes           跳过所有确认（打包确认、覆盖确认）
  --dry-run           仅预览计划内容，不实际创建 CBZ

交互式流程：
- 开头询问执行位置（root）：1 默认脚本所在目录（回车）/ 2 手动输入 / 3 弹出窗口选择
- 开头询问 LanguageISO 模式：跳过（默认）/ 逐文件夹选择 ja 或 zh
- 开头询问 Volume 模式：跳过（默认）/ 自动检测 / 逐文件夹手动输入
  （auto 模式：同系列有更高卷号时，无卷号的漫画自动推断为第 1 卷）
- 开头询问删除模式：保留（默认）/ 打包后自动删除源文件夹
- 以上各项均可通过命令行选项直接指定（root / --lang / --volume / -d / -k）

依赖：
- Pillow（读取图片宽高）
- 复制脚本到任意目录后，推荐用 uv 直接运行（自动创建临时环境并安装 Pillow，不污染目标目录）：
    uv run batch_pack_cbz.py
- 或在仓库脚本环境安装依赖：
    uv pip install --python scripts/.venv/Scripts/python.exe -r scripts/requirements.txt
"""

from __future__ import annotations

import argparse
import contextlib
import os
import platform
import re
import shutil
import zipfile
from pathlib import Path
from xml.sax.saxutils import escape

try:
    from PIL import Image
except ImportError:  # pragma: no cover - 便于给出友好提示
    Image = None

# 支持的图片格式（与 batch_rename_images.py 保持一致）
IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".bmp",
    ".webp",
    ".tiff",
    ".tif",
    ".ico",
    ".svg",
    ".heic",
    ".heif",
    ".avif",
}


def natural_key(text: str):
    """自然排序键：将 'a2b10' 排序为 ['a', 2, 'b', 10]（数字按数值比较）"""
    return [int(part) if part.isdigit() else part.lower() for part in re.split(r"(\d+)", text)]


# 全角/半角括号（内容为"原作"，ComicInfo.xml 中忽略）
_PAREN_RE = re.compile(r"[（(][^（）()]*[）)]")

# 卷号检测：末尾的纯数字、#1、Vol.1、vol 1 等（可选空格）
_VOLUME_RE = re.compile(r"\s*(?:#\s*|[Vv][Oo][Ll]\.?\s*)?(\d+)\s*$")

# 内嵌卷号检测：数字紧跟波浪线（如 "系列A3〜副标题" 中的 3），保留在标题中
_EMBEDDED_VOLUME_RE = re.compile(r"(\d+)[〜~]")


def strip_original_work(name: str) -> str:
    """
    去除名称中的括号内容（原作信息，目前无用）并规整空白

    例：
    "作品A（原作：X）"            -> "作品A"
    "作品A (原作X)"               -> "作品A"
    "作品A（原作：X） 1"          -> "作品A 1"
    """
    name = _PAREN_RE.sub("", name)
    return re.sub(r"\s+", " ", name).strip()


def detect_volume(name: str) -> tuple[str, int | None]:
    """
    检测卷号，返回 (处理后的名称, 卷号)

    两种模式：
    1. 末尾卷号（移除并返回）："作品A 1"、"作品A #1"、"作品A Vol.1"
    2. 内嵌卷号（保留名称，仅提取数值）："作品A3〜副标题" 中的 3

    例：
    "作品A 1"                     -> ("作品A", 1)
    "作品A #1"                    -> ("作品A", 1)
    "作品A Vol.1"                 -> ("作品A", 1)
    "作品A vol 1"                 -> ("作品A", 1)
    "作品A3〜副标题…"             -> ("作品A3〜副标题…", 3)  # 内嵌，保留
    "作品A 3〜副标题…"            -> ("作品A 3〜副标题…", 3)  # 内嵌，保留
    "系列B3〜風紀委員長…"          -> ("系列B3〜風紀委員長…", 3)  # 内嵌，保留
    "无卷号标题"                   -> ("无卷号标题", None)
    """
    # 1) 末尾纯卷号：移除
    m = _VOLUME_RE.search(name)
    if m:
        volume = int(m.group(1))
        clean = name[: m.start()].strip()
        return clean, volume
    # 2) 内嵌卷号：仅提取数值，不修改名称
    m2 = _EMBEDDED_VOLUME_RE.search(name)
    if m2:
        return name, int(m2.group(1))
    return name, None


def infer_volumes(metas: list[dict]) -> dict[Path, int | None]:
    """
    推断每个漫画文件夹的卷号（含"无卷号推断为第 1 卷"的规则）

    规则：
    1. 显式卷号：从标题检测（末尾 " 1"、"#1"、"Vol.1" 或内嵌 "3〜"），检测到则使用
    2. 推断卷号：同一系列（series_key）下存在大于 1 的显式卷号，
       且"无显式卷号"的漫画恰好只有 1 本时，将该本推断为第 1 卷
       （例：系列同时有 屈服2、屈服3 时，"屈服" 推断为 Vol.1）
    3. 其余情况无卷号（None，不生成 <Volume>）

    metas: derive_metadata 结果，须含 "folder"、"title"、"series_key"

    Returns:
        {folder: 卷号或 None}
    """
    explicit = {m["folder"]: detect_volume(m["title"])[1] for m in metas}
    groups: dict[str, list[Path]] = {}
    for m in metas:
        groups.setdefault(m["series_key"], []).append(m["folder"])

    result: dict[Path, int | None] = {}
    for m in metas:
        folder = m["folder"]
        vol = explicit[folder]
        if vol is None:
            siblings = groups[m["series_key"]]
            no_vol = [p for p in siblings if explicit[p] is None]
            has_vol = [explicit[p] for p in siblings if explicit[p] is not None]
            if len(no_vol) == 1 and has_vol and max(has_vol) > 1:
                vol = 1
        result[folder] = vol
    return result


def get_image_files(folder: Path) -> list[Path]:
    """获取文件夹中直接包含的图片文件（未排序）"""
    return [f for f in folder.iterdir() if f.is_file() and f.suffix.lower() in IMAGE_EXTENSIONS]


def find_comic_folders(root: Path) -> list[tuple[Path, int]]:
    """
    递归查找所有"直接包含图片"的文件夹

    Returns:
        [(文件夹路径, 相对根目录的深度)]，深度 0 表示根目录本身
    """
    comics: list[tuple[Path, int]] = []

    if get_image_files(root):
        comics.append((root, 0))

    for dirpath, _dirnames, _filenames in os.walk(root):
        folder = Path(dirpath)
        if folder == root:
            continue
        if get_image_files(folder):
            depth = len(folder.relative_to(root).parts)
            comics.append((folder, depth))

    comics.sort(key=lambda item: str(item[0]))
    return comics


def parse_name(name: str) -> tuple[str, str]:
    """
    从文件夹名解析 (writer, clean_name)

    - 开头的 [writer] 提取为 writer
    - 标题/系列中的括号（）/( ) 内容（原作）被忽略

    例："[作者A] 作品A 副标题（原作：X）"
        -> ("作者A", "作品A 副标题")
    无 [] 时返回 ("", 清理后的名称)
    """
    name = name.strip()
    writer = ""
    if name.startswith("[") and "]" in name:
        end = name.find("]")
        writer = name[1:end].strip()
        name = name[end + 1 :].strip()
    return writer, strip_original_work(name)


def derive_metadata(folder: Path, root: Path, depth: int) -> dict[str, str]:
    """
    根据文件夹层级推导 title / series / writer / cbz 名称

    规则：
    - depth <= 1：title = series = 文件夹名（[] 后部分），writer 来自 []
    - depth >= 2：外层（父文件夹）= Series（系列名）+ writer，内层（当前文件夹）= Title（本卷标题）
    - 内层文件夹名也可能带 [] 前缀（单个漫画 title），与括号内容一并忽略
    - cbz 名称始终使用原始文件夹名
    """
    if depth <= 1:
        writer, title = parse_name(folder.name)
        series = title
    else:
        outer = folder.parent
        writer, series = parse_name(outer.name)  # 外层 → Series（系列名）
        # 内层名称同样去除 [] 前缀与括号内容（writer 仍取外层）
        _, title = parse_name(folder.name)  # 内层 → Title（本卷标题）

    return {
        "writer": writer,
        "title": title,
        "series": series,
        "cbz_name": folder.name,
    }


def read_image_size(path: Path) -> tuple[int | None, int | None]:
    """读取图片宽高（失败时返回 (None, None)）"""
    if Image is None:
        return None, None
    try:
        with Image.open(path) as im:
            return im.width, im.height
    except Exception:
        return None, None


def build_comic_info_xml(
    title: str,
    series: str,
    writer: str,
    image_infos: list[tuple[int, int | None, int | None]],
    volume: int | None = None,
    language_iso: str | None = None,
) -> str:
    """
    生成 ComicInfo.xml 内容

    image_infos: [(ImageSize字节数, ImageWidth, ImageHeight), ...]，顺序即页码顺序
    volume: 卷号（可选，None 时不生成 <Volume>）
    language_iso: 语言代码如 "ja"/"zh"（可选，None 时不生成 <LanguageISO>）
    """
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<ComicInfo xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xmlns:xsd="http://www.w3.org/2001/XMLSchema">',
        f"    <Title>{escape(title)}</Title>",
        f"    <Series>{escape(series)}</Series>",
    ]
    if volume is not None:
        lines.append(f"    <Volume>{volume}</Volume>")
    if writer:
        lines.append(f"    <Writer>{escape(writer)}</Writer>")
    if language_iso:
        lines.append(f"    <LanguageISO>{escape(language_iso)}</LanguageISO>")
    lines.append(f"    <PageCount>{len(image_infos)}</PageCount>")
    lines.append("    <Pages>")
    for index, (size, width, height) in enumerate(image_infos):
        attrs = f' Image="{index}" Type="Story" ImageSize="{size}"'
        if width is not None:
            attrs += f' ImageWidth="{width}"'
        if height is not None:
            attrs += f' ImageHeight="{height}"'
        lines.append(f"        <Page{attrs}/>")
    lines.append("    </Pages>")
    lines.append("</ComicInfo>")
    return "\n".join(lines)


def create_cbz(images: list[Path], cbz_path: Path, xml_content: str) -> None:
    """将图片打包为 CBZ（ZIP_STORED 无压缩，漫画阅读器兼容性最佳）"""
    digits = max(3, len(str(len(images))))
    with zipfile.ZipFile(str(cbz_path), "w", zipfile.ZIP_STORED) as zf:
        zf.writestr("ComicInfo.xml", xml_content)
        for i, img in enumerate(images):
            arcname = f"{str(i + 1).zfill(digits)}{img.suffix.lower()}"
            zf.write(str(img), arcname)


def ask_folder_dialog(initial_dir: Path) -> Path | None:
    """
    弹出系统文件夹选择窗口，返回所选目录

    - 基于 tkinter（Python 标准库，跨平台），Windows 下为原生文件夹对话框
    - 无 tkinter / 无图形环境 / 用户取消时返回 None
    """
    try:
        import tkinter as tk
        from tkinter import filedialog
    except ImportError:
        print("[提示] 当前环境未安装 tkinter，无法弹出选择窗口，请改用手动输入。")
        return None
    root = None
    try:
        root = tk.Tk()
        root.withdraw()
        with contextlib.suppress(Exception):
            root.attributes("-topmost", True)  # 窗口置顶，避免被遮挡
        result = filedialog.askdirectory(initialdir=str(initial_dir), title="选择要打包的根目录")
    except Exception as e:
        print(f"[提示] 打开选择窗口失败（{e}），请改用手动输入。")
        return None
    finally:
        if root is not None:
            with contextlib.suppress(Exception):
                root.destroy()
    return Path(result) if result else None


def wait_for_exit():
    """等待用户按回车退出，兼容交互终端（Ctrl+C）和非交互终端（EOF）"""
    try:
        input("\n按回车键退出...")
    except (EOFError, KeyboardInterrupt):
        print()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="批量将图片文件夹打包为 CBZ 漫画（自动生成 ComicInfo.xml）",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "示例：\n"
            '  python batch_pack_cbz.py "D:\\漫画库"\n'
            "  python batch_pack_cbz.py  # 询问执行位置（默认脚本目录 / 手动输入 / 弹窗选择）\n"
            "  python batch_pack_cbz.py . --out D:\\cbz --dry-run\n"
        ),
    )
    parser.add_argument(
        "root", nargs="?", default=None, help="根目录（缺省交互式输入，默认脚本所在目录）"
    )
    parser.add_argument(
        "-o",
        "--out",
        default=None,
        help="CBZ 输出目录（缺省：两层结构放 series 内 / 单层放漫画文件夹内）",
    )
    parser.add_argument(
        "--lang",
        choices=["skip", "ja", "zh", "interactive"],
        default=None,
        help=(
            "LanguageISO：skip 不生成 / ja 全部日语 / zh 全部中文 / "
            "interactive 逐文件夹交互选择（缺省交互式询问）"
        ),
    )
    parser.add_argument(
        "--volume",
        choices=["skip", "auto", "input"],
        default=None,
        help=(
            "Volume 模式：skip 不生成 / auto 自动检测（同系列有更高卷号时"
            "无卷号漫画推断为第 1 卷）/ input 逐文件夹输入（缺省交互式询问）"
        ),
    )
    parser.add_argument(
        "-d", "--delete", action="store_true", help="打包成功后自动删除源文件夹（不询问）"
    )
    parser.add_argument(
        "-k", "--keep", action="store_true", help="打包后保留源文件夹（不询问，默认行为）"
    )
    parser.add_argument("-y", "--yes", action="store_true", help="跳过所有确认")
    parser.add_argument("--dry-run", action="store_true", help="仅预览，不实际打包")
    args = parser.parse_args()

    # 检测依赖
    if Image is None:
        print("[错误] 未找到 Pillow，无法读取图片宽高。请先安装依赖：")
        print(
            "  uv pip install --python scripts/.venv/Scripts/python.exe -r scripts/requirements.txt"
        )
        wait_for_exit()
        return

    print("=" * 60)
    print("批量 CBZ 打包工具")
    print(f"运行环境: {platform.system()}")
    print("=" * 60)
    print()

    # 根目录：优先命令行参数；否则交互式询问（默认 / 手动输入 / 弹窗选择）
    if args.root:
        root_dir = Path(args.root).resolve()
    else:
        default_dir = Path(__file__).resolve().parent
        print("执行位置（要打包的根目录 / root directory）：")
        print(f"  1. 使用默认（脚本所在目录）: {default_dir}")
        print("  2. 手动输入路径")
        print("  3. 弹出窗口选择文件夹")
        choice = input("请选择 (1-3，直接回车默认 1): ").strip()
        if choice == "2":
            entered = input("  请输入路径: ").strip()
            root_dir = Path(entered).resolve() if entered else default_dir
        elif choice == "3":
            selected = ask_folder_dialog(default_dir)
            root_dir = selected.resolve() if selected else default_dir
        else:
            root_dir = default_dir
    if not root_dir.is_dir():
        print(f"[错误] 目录不存在 / Directory not found: {root_dir}")
        wait_for_exit()
        return

    out_dir = Path(args.out).resolve() if args.out else None
    print(f"根目录: {root_dir}")
    if out_dir:
        print(f"输出目录: {out_dir}")
    print()

    # ---- LanguageISO 模式（--lang 直接指定，否则交互式询问） ----
    language_iso_mode = "skip"
    lang_fixed: str | None = None
    if args.lang == "ja":
        language_iso_mode = "fixed"
        lang_fixed = "ja"
        print("LanguageISO: 固定 ja")
    elif args.lang == "zh":
        language_iso_mode = "fixed"
        lang_fixed = "zh"
        print("LanguageISO: 固定 zh")
    elif args.lang == "interactive":
        language_iso_mode = "interactive"
        print("LanguageISO: 逐文件夹交互式选择")
    elif args.lang == "skip":
        print("LanguageISO: （不生成）")
    else:
        print("LanguageISO 选项（ComicInfo.xml 中的语言标签）：")
        print("  1. 跳过（默认，不生成 <LanguageISO> 标签）")
        print("  2. 交互式选择 — 逐文件夹选择 ja 或 zh")
        lang_choice = input("请选择 (1-2，直接回车默认跳过): ").strip()
        if lang_choice == "2":
            language_iso_mode = "interactive"
            print("LanguageISO: 逐文件夹交互式选择")
        else:
            print("LanguageISO: （不生成）")
    print()

    # ---- Volume 模式（--volume 直接指定，否则交互式询问） ----
    if args.volume:
        volume_mode = args.volume
    else:
        print("Volume（卷号）选项：")
        print("  1. 跳过（默认，不生成 <Volume> 标签）")
        print("  2. 自动检测 — 从标题/系列名末尾自动提取数字卷号；同系列存在")
        print("     更高卷号时，无卷号的漫画自动推断为第 1 卷")
        print("  3. 交互式输入 — 逐文件夹手动输入卷号")
        vol_choice = input("请选择 (1-3，直接回车默认跳过): ").strip()
        volume_mode = {"1": "skip", "2": "auto", "3": "input"}.get(vol_choice, "skip")
    volume_labels = {"skip": "跳过（不生成）", "auto": "自动检测", "input": "交互式输入"}
    print(f"Volume 模式: {volume_labels[volume_mode]}")
    print()

    # ---- 删除模式（-d/-k 直接指定，否则交互式询问） ----
    if args.delete:
        delete_mode = "delete"
        print("删除模式: 打包后自动删除源文件夹")
    elif args.keep:
        delete_mode = "keep"
        print("删除模式: 保留源文件夹")
    else:
        print("删除源文件夹选项：")
        print("  1. 保留（默认，不删除）")
        print("  2. 自动删除 — 打包成功后删除源文件夹")
        del_choice = input("请选择 (1-2，直接回车默认保留): ").strip()
        delete_mode = "delete" if del_choice == "2" else "keep"
        print(f"删除模式: {'自动删除' if delete_mode == 'delete' else '保留源文件夹'}")
    print()

    # 扫描包含图片的文件夹
    print("正在扫描图片文件夹...")
    comics = find_comic_folders(root_dir)

    if not comics:
        print("未找到包含图片的文件夹！")
        wait_for_exit()
        return

    total_images = sum(len(get_image_files(folder)) for folder, _ in comics)
    print(f"\n找到 {len(comics)} 个包含图片的文件夹，共 {total_images} 张图片：")
    if language_iso_mode != "skip":
        if language_iso_mode == "fixed":
            print(f"LanguageISO: 固定 {lang_fixed}")
        else:
            print("LanguageISO: 逐文件夹交互式选择")
    if volume_mode != "skip":
        print(f"Volume 模式: {volume_labels[volume_mode]}")
    if delete_mode == "delete":
        print("删除模式: 打包后自动删除源文件夹")

    # 收集元数据 + 推断卷号
    # auto 模式：同系列存在更高卷号时，无显式卷号的漫画自动推断为第 1 卷
    metas: list[dict] = []
    for folder, depth in comics:
        meta = derive_metadata(folder, root_dir, depth)
        meta["folder"] = folder
        meta["depth"] = depth
        # series 分组键：两层结构用外层系列文件夹路径，单层结构每本自成一组
        meta["series_key"] = str(folder.parent) if depth >= 2 else str(folder)
        metas.append(meta)
    volume_map: dict[Path, int | None] = infer_volumes(metas) if volume_mode == "auto" else {}

    print("-" * 70)
    for meta in metas:
        folder = meta["folder"]
        depth = meta["depth"]
        rel = folder.relative_to(root_dir)
        display = str(rel) if str(rel) != "." else f"<根目录: {root_dir.name}>"
        n = len(get_image_files(folder))

        # Volume 预览（与打包逻辑一致：始终检测 title）
        volume_str = ""
        if volume_mode == "auto":
            vol = volume_map[folder]
            if vol is not None:
                # 无显式卷号但被推断为第 1 卷时标注"推断"
                explicit_vol = detect_volume(meta["title"])[1]
                volume_str = f"  Vol.{vol}（推断）" if explicit_vol is None else f"  Vol.{vol}"
        elif volume_mode == "input":  # 交互式
            volume_str = "  Vol.?"

        print(f"  [{depth}层] {display}")
        print(
            f"          {n} 张图片 | title='{meta['title']}' series='{meta['series']}'"
            f" writer='{meta['writer']}'{volume_str} -> {meta['cbz_name']}.cbz"
        )
    print("-" * 70)
    print()

    # 预览（dry-run）或确认
    if args.dry_run:
        print("[预览模式] 以上为计划打包的内容，未实际创建 CBZ。")
        wait_for_exit()
        return

    if not args.yes:
        confirm = input("确认执行打包操作？(y/n): ").strip().lower()
        if confirm != "y":
            print("操作已取消。")
            wait_for_exit()
            return

    # 逐文件夹打包
    success_folders: list[Path] = []
    fail_folders: list[Path] = []
    success_cbzs = 0

    print("\n开始打包...")
    for folder, depth in comics:
        try:
            meta = derive_metadata(folder, root_dir, depth)

            # ---- Volume 处理 ----
            volume: int | None = None
            # 始终检测 title（两层时 title 来自内层漫画名）
            volume_target = meta["title"]
            if volume_mode == "auto":  # 自动检测
                clean, vol = detect_volume(volume_target)
                if vol is not None:
                    volume = vol
                    meta["title"] = clean
                    if depth <= 1:
                        meta["series"] = clean  # 一层时 title == series
                elif volume_map.get(folder) == 1:  # 推断为第 1 卷（标题无卷号，无需修改）
                    volume = 1
            elif volume_mode == "input":  # 交互式输入
                prompt = f"  [{meta['cbz_name']}] 请输入卷号（直接回车跳过）: "
                vol_input = input(prompt).strip()
                if vol_input.isdigit():
                    volume = int(vol_input)

            # ---- LanguageISO 逐文件夹处理 ----
            lang_iso: str | None = None
            if language_iso_mode == "fixed":
                lang_iso = lang_fixed
            elif language_iso_mode == "interactive":
                print(f"  [{meta['cbz_name']}] LanguageISO:")
                print("    1. 跳过   2. ja   3. zh")
                li = input("    请选择 (1-3，直接回车默认跳过): ").strip()
                if li == "2":
                    lang_iso = "ja"
                elif li == "3":
                    lang_iso = "zh"

            # 排序图片：固定按名称升序（自然排序），命名已由重命名脚本保证顺序
            images = get_image_files(folder)
            images.sort(key=lambda f: natural_key(f.name))

            # 读取图片元数据（大小 + 宽高）
            image_infos: list[tuple[int, int | None, int | None]] = []
            for img in images:
                size = img.stat().st_size
                width, height = read_image_size(img)
                image_infos.append((size, width, height))

            xml_content = build_comic_info_xml(
                meta["title"],
                meta["series"],
                meta["writer"],
                image_infos,
                volume=volume,
                language_iso=lang_iso,
            )

            # 决定 CBZ 输出位置：
            # - 两层结构（漫画在 series 内）：放 series 文件夹内，与漫画文件夹同级，不嵌套
            # - 单层结构（单个漫画直接含图）：放漫画文件夹内部，避免上移到根目录
            if out_dir:
                cbz_dir = out_dir
            elif depth >= 2:
                cbz_dir = folder.parent
            else:
                cbz_dir = folder
            cbz_path = cbz_dir / f"{meta['cbz_name']}.cbz"

            # 文件名冲突处理
            if cbz_path.exists() and not args.yes:
                overwrite = input(f"  {cbz_path.name} 已存在，覆盖？(y/n): ").strip().lower()
                if overwrite != "y":
                    print(f"  ⚠ 跳过: {cbz_path.name}")
                    fail_folders.append(folder)
                    continue

            cbz_dir.mkdir(parents=True, exist_ok=True)
            create_cbz(images, cbz_path, xml_content)
            print(f"  ✓ {cbz_path}")
            success_folders.append(folder)
            success_cbzs += 1

        except Exception as e:
            print(f"  ✗ 打包 {folder} 时出错: {e}")
            fail_folders.append(folder)

    print()
    print(f"成功打包: {success_cbzs} 个 CBZ")
    if fail_folders:
        print(f"失败: {len(fail_folders)} 个")

    # 删除策略：根据开头选择的删除模式执行
    delete_folders = delete_mode == "delete"

    deleted = 0
    if delete_folders and success_folders:
        print("\n删除源文件夹...")
        # 先删深层，再删浅层，避免父目录残留导致误删
        for folder in sorted(success_folders, key=lambda p: len(p.parts), reverse=True):
            try:
                if folder.exists() and folder.is_dir():
                    # 检查是否还有非图片文件，提前提示
                    others = [
                        f
                        for f in folder.iterdir()
                        if f.is_file() and f.suffix.lower() not in IMAGE_EXTENSIONS
                    ]
                    if others:
                        print(f"  ⚠ {folder.name} 含 {len(others)} 个非图片文件，将一并删除")
                    shutil.rmtree(folder)
                    print(f"  已删除: {folder}")
                    deleted += 1
            except Exception as e:
                print(f"  ✗ 删除 {folder} 时出错: {e}")
        print(f"已删除 {deleted} 个源文件夹")

    print("\n" + "=" * 60)
    print("处理完成！")
    print("=" * 60)
    wait_for_exit()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n操作已被用户中断。")
        wait_for_exit()
    except Exception as e:
        print(f"\n发生错误: {e}")
        wait_for_exit()
