#!/usr/bin/env python3
# /// script
# requires-python = ">=3.14.0"
# dependencies = []
# ///
"""openwith -- inspect and clean the Windows "Open with" list.

Targets CPython 3.14 (declared in the PEP 723 block above so `uv run`
selects a 3.14 interpreter from somewhere else, e.g. chezmoi-managed
machines).  No third-party dependencies: everything is stdlib, so the
script also runs under a plain `python openwith.py`.  `rich` is used for
prettier tables when it happens to be importable, and is not required.

Why this exists
---------------
Windows builds the "Open with" menu from several registry layers and
de-duplicates only by ProgID / executable path -- never by display name.
Two consequences that bite people:

* A program that was uninstalled or upgraded can leave a ProgID behind.
  The entry stays in the menu with a blank icon and launches nothing.
* Any key under ``HKCR\\Applications`` that has a ``shell\\<verb>\\command``
  is offered for **every** file extension, whether or not it declares
  ``SupportedTypes``.  ``SupportedTypes`` does *not* gate the menu (zen.exe
  claims 30 types, none of them ``.md``, and still appears for ``.md``);
  only a ``NoOpenWith`` value removes an entry.  That is how an ordinary
  data file (``aria2.conf``) ends up being listed as an application that
  can "open" your ``.md`` files -- the answer to "why is a config file an
  Open-with entry?".
* Office registers ``shell\\edit\\command`` without any ``shell\\open``,
  so a scanner that only reads ``open`` misses Word entirely.

This tool asks the shell itself (``SHAssocEnumHandlers``) what the dialog
would actually show, then traces every entry back to the registry keys
that put it there.  Enumeration and auditing are read-only.  Mutations are
dry-run unless ``--apply`` is passed, and ``--apply`` exports ``.reg``
backups of every key it is about to touch.

The tool never writes ``...\\FileExts\\<ext>\\UserChoice``: editing that key
by hand invalidates its ``Hash`` value and Windows silently resets the
user's default program.  ``Hash`` is read-only here, always.

Usage::

    uv run scripts/openwith/openwith.py list .md
    uv run scripts/openwith/openwith.py audit .md
    uv run scripts/openwith/openwith.py polluters
    uv run scripts/openwith/openwith.py prune .md --apply
    uv run scripts/openwith/openwith.py hide zen.exe --apply
    uv run scripts/openwith/openwith.py list .md --json

``scripts/`` is listed in ``.chezmoiignore``, so this file stays in the
chezmoi source tree and is never deployed into ``$HOME``.
"""

from __future__ import annotations

import argparse
import ctypes
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys
from ctypes import wintypes
from dataclasses import dataclass
from pathlib import Path

if sys.platform != "win32":
    sys.exit("openwith: Windows only")

if sys.version_info < (3, 14):
    print(
        f"openwith: CPython 3.14+ expected, got {sys.version.split()[0]}. "
        "Run it with `uv run openwith.py ...` to pick up the declared interpreter.",
        file=sys.stderr,
    )

import contextlib
import winreg  # noqa: E402

__version__ = "1.0.0"


def _force_utf8_streams() -> None:
    """Localised app names must survive a GBK console.

    Python 3.14 still derives stdio encoding from the console code page, so a
    name like "Windows 照片查看器" turns into mojibake the moment the output is
    captured or redirected.  Force UTF-8 on the streams we write to.
    """
    for stream in (sys.stdout, sys.stderr):
        with contextlib.suppress(AttributeError, ValueError, OSError):
            stream.reconfigure(encoding="utf-8", errors="replace")
    os.environ.setdefault("PYTHONIOENCODING", "utf-8")


_force_utf8_streams()

# --------------------------------------------------------------------------
# pretty output (rich when importable, plain text otherwise)
# --------------------------------------------------------------------------

try:
    from rich import box as _box
    from rich.console import Console as _Console
    from rich.table import Table as _Table

    _console = _Console()
    _RICH = True
except Exception:  # pragma: no cover - optional dependency
    _console = None
    _RICH = False

_MARKUP = re.compile(r"\[/?[a-zA-Z0-9_ #=]+\]")


def _strip(s: str) -> str:
    return _MARKUP.sub("", s)


def say(msg: str = "") -> None:
    if _RICH:
        _console.print(msg)
    else:
        print(_strip(msg))


def ok(msg: str) -> None:
    say(f"[green]OK[/green]  {msg}" if _RICH else f"OK    {msg}")


def warn(msg: str) -> None:
    say(f"[yellow]!![/yellow]  {msg}" if _RICH else f"!!    {msg}")


def err(msg: str) -> None:
    say(f"[red]XX[/red]  {msg}" if _RICH else f"ERROR {msg}")


def info(msg: str) -> None:
    say(f"[cyan]--[/cyan]  {msg}" if _RICH else f"--    {msg}")


def head(msg: str) -> None:
    say(f"\n[bold]{msg}[/bold]" if _RICH else f"\n{msg}")


def d(msg: str) -> str:
    return f"[dim]{msg}[/dim]" if _RICH else msg


def g(msg: str) -> str:
    return f"[green]{msg}[/green]" if _RICH else msg


def b(msg: str) -> str:
    return f"[red]{msg}[/red]" if _RICH else msg


def c(msg: str) -> str:
    return f"[cyan]{msg}[/cyan]" if _RICH else msg


def table(cols: list[str], rows: list[list[str]], title: str | None = None) -> None:
    rows = [[str(x) for x in r] for r in rows]
    if _RICH:
        t = _Table(title=title, box=_box.SIMPLE_HEAD, header_style="bold", pad_edge=False)
        for col in cols:
            t.add_column(col, overflow="fold")
        for r in rows:
            t.add_row(*r)
        _console.print(t)
        return
    if title:
        print(f"\n{title}")
    rows = [[_strip(x) for x in r] for r in rows]
    widths = [len(x) for x in cols]
    for r in rows:
        for i, x in enumerate(r[: len(cols)]):
            widths[i] = max(widths[i], len(x))
    print("  ".join(x.ljust(widths[i]) for i, x in enumerate(cols)))
    print("  ".join("-" * widths[i] for i in range(len(cols))))
    for r in rows:
        cells = list(r) + [""] * (len(cols) - len(r))
        print("  ".join(cells[i].ljust(widths[i]) for i in range(len(cols))))


# --------------------------------------------------------------------------
# registry helpers
# --------------------------------------------------------------------------

HIVENUM = {
    "HKCU": winreg.HKEY_CURRENT_USER,
    "HKLM": winreg.HKEY_LOCAL_MACHINE,
}
VIEWKEY = {"64": winreg.KEY_WOW64_64KEY, "32": winreg.KEY_WOW64_32KEY}
VIEWS = ("64", "32")

APPS = r"SOFTWARE\Classes\Applications"
FILEEXTS = r"SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FileExts"


def _open(hive: str, path: str, view: str, access: int = winreg.KEY_READ):
    try:
        return winreg.OpenKey(HIVENUM[hive], path, 0, access | VIEWKEY[view])
    except OSError:
        return None


def reg_exists(hive: str, path: str, view: str = "64") -> bool:
    k = _open(hive, path, view)
    if k is None:
        return False
    winreg.CloseKey(k)
    return True


def reg_values(hive: str, path: str, view: str = "64") -> dict[str, object]:
    """All values of a key, or {} when the key does not exist."""
    k = _open(hive, path, view)
    if k is None:
        return {}
    out: dict[str, object] = {}
    try:
        for i in range(winreg.QueryInfoKey(k)[1]):
            name, data, _kind = winreg.EnumValue(k, i)
            out[name] = data
    except OSError:
        pass
    finally:
        winreg.CloseKey(k)
    return out


def reg_default(hive: str, path: str, view: str = "64") -> str:
    v = reg_values(hive, path, view).get("")
    return v if isinstance(v, str) else ""


def reg_subkeys(hive: str, path: str, view: str = "64") -> list[str]:
    k = _open(hive, path, view)
    if k is None:
        return []
    out: list[str] = []
    try:
        for i in range(winreg.QueryInfoKey(k)[0]):
            out.append(winreg.EnumKey(k, i))
    except OSError:
        pass
    finally:
        winreg.CloseKey(k)
    return out


def reg_set(hive: str, path: str, view: str, name: str, data: str) -> None:
    with winreg.CreateKeyEx(HIVENUM[hive], path, 0, winreg.KEY_SET_VALUE | VIEWKEY[view]) as k:
        winreg.SetValueEx(k, name, 0, winreg.REG_SZ, data)


def reg_del_value(hive: str, path: str, view: str, name: str) -> None:
    with winreg.OpenKey(HIVENUM[hive], path, 0, winreg.KEY_SET_VALUE | VIEWKEY[view]) as k:
        winreg.DeleteValue(k, name)


def reg_del_tree(hive: str, path: str, view: str = "64") -> None:
    for child in reg_subkeys(hive, path, view):
        reg_del_tree(hive, path + "\\" + child, view)
    winreg.DeleteKeyEx(HIVENUM[hive], path, VIEWKEY[view], 0)


# --------------------------------------------------------------------------
# small utilities
# --------------------------------------------------------------------------


def parse_exe(command: str) -> str:
    """Best-effort extraction of the program a shell command actually runs.

    Two shapes need care:

    * ``"C:\\path\\app.exe" "%1"``      -> the quoted head is the program.
    * ``%SystemRoot%\\System32\\rundll32.exe "C:\\...\\PhotoViewer.dll", ImageView_Fullscreen %1``
      -> the *interesting* identity is the DLL, not ``rundll32.exe``: that is
      what the shell reports in the Open-with list, and the DLL genuinely
      exists.  Returning the raw tail here made the entry look dead.
    """
    cmd = os.path.expandvars((command or "").strip())
    if not cmd:
        return ""
    # rundll32 is tested on the *first whitespace token* only: the general
    # head-splitter deliberately absorbs unquoted tokens that contain spaces
    # (``C:\Program Files\app.exe``), which for a rundll32 line would swallow
    # the whole command and hide the host DLL.
    first = cmd.split()[0]
    if os.path.basename(first).lower() in ("rundll32.exe", "rundll32"):
        tail = cmd[len(first) :]
        m = re.search(r'"([^"]+\.(?:dll|cpl))"', tail, re.IGNORECASE)
        if m:
            return m.group(1)
        m = re.search(r"(\S+\.(?:dll|cpl))", tail, re.IGNORECASE)
        if m:
            return m.group(1).rstrip(",")
    head, _sep, _tail = _split_head(cmd)
    return head


def _split_head(cmd: str) -> tuple[str, str, str]:
    """Split a command line into (program token, separator, rest).

    Quoted heads end at the closing quote.  Unquoted heads may still contain
    spaces (``C:\\Program Files\\app.exe``), so keep absorbing tokens until one
    looks like a switch (``-``/``/``) or a placeholder argument.
    """
    if cmd[0] == '"':
        end = cmd.find('"', 1)
        if end > 0:
            return cmd[1:end], cmd[end + 1 : end + 2], cmd[end + 1 :]
        return cmd[1:], "", ""
    toks = cmd.split()
    if not toks:
        return "", "", ""
    keep = [toks[0]]
    for t in toks[1:]:
        if t[:1] in "-/%" or t[:2] in ("%1", "%L"):
            break
        keep.append(t)
    head = " ".join(keep)
    return head, " ", cmd[len(head) :]


def which(name: str) -> str:
    """Resolve an executable name or path; '' when nothing exists."""
    if not name:
        return ""
    if "\\" in name or "/" in name:
        return name if Path(name).exists() else ""
    return shutil.which(name) or ""


def file_ok(path: str) -> bool:
    return bool(path) and Path(path).exists()


def same_exe(a: str, b: str) -> bool:
    """Do two handler identities refer to the same program?"""
    if not a or not b:
        return False
    na, nb = os.path.normcase(a.strip()), os.path.normcase(b.strip())
    if na == nb:
        return True
    ba, bb = os.path.basename(na), os.path.basename(nb)
    if not ba or ba != bb:
        return False
    # Same basename: accept only when one side is not a resolvable file,
    # so two real installs of the same program stay distinct.
    return not file_ok(a) or not file_ok(b)


def norm_ext(target: str) -> tuple[str, str]:
    """Return (value passed to the shell, normalised extension)."""
    t = (target or "").strip()
    if not t:
        raise SystemExit("openwith: empty extension/target")
    p = Path(t)
    if p.exists() and p.is_file():
        return str(p), p.suffix.lower()
    if "\\" in t or "/" in t:
        return t, p.suffix.lower()
    ext = t if t.startswith(".") else "." + t
    return ext, ext.lower()


# --------------------------------------------------------------------------
# shell enumeration: what the dialog actually shows
# --------------------------------------------------------------------------

_ole32 = ctypes.WinDLL("ole32")
_shell32 = ctypes.WinDLL("shell32")

_ole32.CoInitializeEx.argtypes = [ctypes.c_void_p, wintypes.DWORD]
_ole32.CoInitializeEx.restype = ctypes.c_long
_ole32.CoTaskMemFree.argtypes = [ctypes.c_void_p]

_shell32.SHAssocEnumHandlers.argtypes = [
    wintypes.LPCWSTR,
    ctypes.c_int,
    ctypes.POINTER(ctypes.c_void_p),
]
_shell32.SHAssocEnumHandlers.restype = ctypes.c_long
_shell32.SHChangeNotify.argtypes = [
    ctypes.c_long,
    ctypes.c_uint,
    ctypes.c_void_p,
    ctypes.c_void_p,
]

ASSOC_FILTER_NONE = 0  # "More options"
ASSOC_FILTER_RECOMMENDED = 1  # "Recommended apps"

SHCNE_ASSOCCHANGED = 0x08000000
SHCNF_IDLIST = 0x0000

_COM_READY = False


def com_init() -> None:
    global _COM_READY
    if _COM_READY:
        return
    _ole32.CoInitializeEx(None, 0x2)  # COINIT_APARTMENTTHREADED
    _COM_READY = True


def _vfn(iface: int, slot: int, restype, *argtypes):
    """Fetch vtable slot `slot` of a raw COM interface pointer."""
    vt = ctypes.cast(iface, ctypes.POINTER(ctypes.POINTER(ctypes.c_void_p))).contents
    return ctypes.WINFUNCTYPE(restype, ctypes.c_void_p, *argtypes)(vt[slot])


def _release(iface) -> None:
    if not iface:
        return
    with contextlib.suppress(Exception):
        _vfn(iface, 2, ctypes.c_long)(iface)


def _take_str(ptr: int) -> str:
    if not ptr:
        return ""
    try:
        return ctypes.wstring_at(ptr)
    finally:
        _ole32.CoTaskMemFree(ctypes.c_void_p(ptr))


# IAssocHandler {F04061AC-1659-4A3F-A954-775AA57FC083}
#   slots: 3 GetName, 4 GetUIName, 5 GetIconLocation, 6 IsRecommended,
#          7 MakeDefault, 8 Invoke
# IEnumAssocHandlers {973810AE-9599-4B88-9E4D-6EE98C9552DA}
#   slots: 3 Next, 4 Skip, 5 Reset, 6 Clone


def _handler_name(iface) -> str:
    buf = ctypes.c_void_p()
    hr = _vfn(iface, 3, ctypes.c_long, ctypes.POINTER(ctypes.c_void_p))(iface, ctypes.byref(buf))
    return _take_str(buf.value) if hr == 0 else ""


def _handler_uiname(iface) -> str:
    buf = ctypes.c_void_p()
    hr = _vfn(iface, 4, ctypes.c_long, ctypes.POINTER(ctypes.c_void_p))(iface, ctypes.byref(buf))
    return _take_str(buf.value) if hr == 0 else ""


def _handler_icon(iface) -> str:
    # GetIconLocation(LPWSTR *ppszPath, int *pIndex) -- two out params.
    buf = ctypes.c_void_p()
    idx = ctypes.c_int(0)
    hr = _vfn(
        iface,
        5,
        ctypes.c_long,
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.POINTER(ctypes.c_int),
    )(iface, ctypes.byref(buf), ctypes.byref(idx))
    return _take_str(buf.value) if hr == 0 else ""


def _handler_recommended(iface) -> bool:
    return _vfn(iface, 6, ctypes.c_long)(iface) == 0


def _enum_next(enum_iface):
    out = ctypes.c_void_p()
    fetched = ctypes.c_ulong(0)
    hr = _vfn(
        enum_iface,
        3,
        ctypes.c_long,
        ctypes.c_ulong,
        ctypes.POINTER(ctypes.c_void_p),
        ctypes.POINTER(ctypes.c_ulong),
    )(enum_iface, 1, ctypes.byref(out), ctypes.byref(fetched))
    if hr != 0 or fetched.value == 0 or not out.value:
        return None
    return out


@dataclass
class Handler:
    index: int
    recommended: bool
    name: str
    ui_name: str
    icon: str

    @property
    def exists(self) -> bool:
        return file_ok(self.name)

    @property
    def is_appx(self) -> bool:
        return "\\windowsapps\\" in self.name.lower()

    @property
    def status(self) -> str:
        if self.exists:
            return "AppX" if self.is_appx else "ok"
        return "DEAD"


def enum_handlers(extra: str, recommended: bool) -> list[Handler]:
    """Ask the shell what the Open-with dialog would list."""
    com_init()
    penum = ctypes.c_void_p()
    filt = ASSOC_FILTER_RECOMMENDED if recommended else ASSOC_FILTER_NONE
    hr = _shell32.SHAssocEnumHandlers(extra, filt, ctypes.byref(penum))
    if hr != 0 or not penum.value:
        raise RuntimeError(
            f"SHAssocEnumHandlers({extra!r}, filter={filt}) failed: 0x{hr & 0xFFFFFFFF:08X}"
        )
    out: list[Handler] = []
    n = 0
    try:
        while True:
            h = _enum_next(penum)
            if h is None:
                break
            n += 1
            name = _handler_name(h)
            out.append(
                Handler(
                    index=n,
                    recommended=_handler_recommended(h),
                    name=name,
                    ui_name=_handler_uiname(h) or os.path.basename(name),
                    icon=_handler_icon(h),
                )
            )
            _release(h)
    finally:
        _release(penum)
    return out


def list_handlers(extra: str) -> tuple[list[Handler], list[Handler]]:
    return enum_handlers(extra, True), enum_handlers(extra, False)


# --------------------------------------------------------------------------
# registry model
# --------------------------------------------------------------------------


@dataclass
class AppEntry:
    """One ``HKCR\\Applications\\<key>`` registration."""

    hive: str
    view: str
    key: str
    verb: str
    command: str
    exe: str
    supported: list[str]
    no_open_with: bool

    @property
    def reg_path(self) -> str:
        return f"{APPS}\\{self.key}"

    @property
    def exists(self) -> bool:
        return file_ok(self.exe)

    @property
    def wildcard(self) -> bool:
        """Offered for *every* extension.

        ``SupportedTypes`` does NOT gate membership: zen.exe declares 30 types
        (none of them ``.md``) and wmplayer.exe declares 58 (none ``.md``), yet
        both appear for ``.md``.  Measured gate is a single value: only
        ``NoOpenWith`` removes an entry.  A registration lacking both a
        command and ``NoOpenWith`` is invisible for a different reason.
        """
        return not self.no_open_with

    def declares(self, ext: str) -> bool:
        """Does this app name *ext* in SupportedTypes?  Affects ranking only."""
        return ext.lower() in self.supported

    @property
    def scope(self) -> str:
        if self.no_open_with:
            return "hidden"
        return "declared" if self.supported else "undeclared"

    @property
    def tag(self) -> str:
        return f"{self.hive}/{self.view}"


# Verbs that can put an application into the Open-with menu, best first.
# Office ships ``shell\\edit`` with no ``shell\\open`` at all.
PREFERRED_VERBS = ("open", "edit", "play", "print", "printto", "runas")


def verb_command(hive: str, reg_path: str, view: str) -> tuple[str, str]:
    """Return (verb, command) for the first usable shell verb of an app key."""
    shell = reg_path + r"\shell"
    verbs = reg_subkeys(hive, shell, view)
    if not verbs:
        return "", ""
    ordered = [v for v in PREFERRED_VERBS if v in verbs]
    ordered += sorted(v for v in verbs if v.lower() not in PREFERRED_VERBS)
    for verb in ordered:
        cmd = reg_default(hive, f"{shell}\\{verb}\\command", view)
        if cmd:
            return verb, cmd
    return "", ""


def scan_applications() -> list[AppEntry]:
    """Enumerate HKCR\\Applications registrations.

    Both registry views are read so that a 32-bit-only registration is never
    missed, but the result is deduplicated on *content* rather than on view.
    Measured on this machine the two views return identical data for
    ``SOFTWARE\\Classes`` (HKCU n64=n32=4, HKLM n64=n32=78 key names, same
    values), so keying the dedup on the view reported every application twice
    and made ``hide`` emit the same write twice.
    """
    out: list[AppEntry] = []
    seen: set[tuple] = set()
    for hive in ("HKCU", "HKLM"):
        for view in VIEWS:
            if not reg_exists(hive, APPS, view):
                continue
            for key in reg_subkeys(hive, APPS, view):
                rp = f"{APPS}\\{key}"
                verb, cmd = verb_command(hive, rp, view)
                if not cmd:
                    continue  # no command -> cannot appear in Open-with
                sup = sorted(s.lower() for s in reg_values(hive, rp + r"\SupportedTypes", view))
                now = "NoOpenWith" in reg_values(hive, rp, view)
                exe = parse_exe(cmd)
                sig = (hive, key.lower(), tuple(sup), now, exe.lower())
                if sig in seen:
                    continue
                seen.add(sig)
                out.append(
                    AppEntry(
                        hive=hive,
                        view=view,
                        key=key,
                        verb=verb,
                        command=cmd,
                        exe=exe,
                        supported=sup,
                        no_open_with=now,
                    )
                )
    return out


def resolve_progid(progid: str) -> tuple[str, str]:
    """ProgID -> (hive it resolves in, open command)."""
    if not progid:
        return "", ""
    for hive in ("HKCU", "HKLM"):
        for view in VIEWS:
            cmd = reg_default(hive, rf"SOFTWARE\Classes\{progid}\shell\open\command", view)
            if cmd:
                return hive, cmd
    return "", ""


@dataclass
class SourceRef:
    """A registry location that can contribute an entry to the menu."""

    label: str
    kind: str
    exe: str = ""
    dead: bool = False
    hive: str = ""
    view: str = "64"
    path: str = ""
    name: str = ""
    progid: str = ""
    removable: bool = False
    # For ``kind == "applications"``: the key to remove when the registration is
    # dead.  ``path`` may point at a *subkey* (``...\SupportedTypes``), so whole
    # key deletion must not reuse it.
    app_path: str = ""


def collect_sources(ext: str) -> list[SourceRef]:
    refs: list[SourceRef] = []

    # 1. Applications -- every registration with a shell verb is offered for
    #    *every* extension; SupportedTypes only ranks it as "recommended".
    for a in scan_applications():
        declared = a.declares(ext)
        if declared:
            label = f"Applications[{a.tag}].SupportedTypes :: {a.key}"
            path = a.reg_path + r"\SupportedTypes"
            name = ext
        elif a.no_open_with:
            label = (
                f"Applications[{a.tag}] :: {a.key}"
                r"  (NoOpenWith set => hidden from Open-with)"
            )
            path = a.reg_path
            name = "NoOpenWith"
        else:
            label = f"Applications[{a.tag}] :: {a.key}  (shell\\{a.verb} => ALL extensions)"
            path = a.reg_path
            name = ""
        refs.append(
            SourceRef(
                label=label,
                kind="applications",
                exe=a.exe,
                dead=not a.exists,
                hive=a.hive,
                view=a.view,
                path=path,
                name=name,
                removable=True,
                app_path=a.reg_path,
            )
        )

    # 2. OpenWithProgids.  Both views are read but the same ProgID in the same
    #    hive is reported once: ``SOFTWARE\Classes`` is shared between views,
    #    so listing both would double every row.
    seen_progid: set[tuple[str, str, str]] = set()
    for hive, view, base, tag in (
        ("HKLM", "64", rf"SOFTWARE\Classes\{ext}", "Classes"),
        ("HKCU", "64", rf"SOFTWARE\Classes\{ext}", "Classes"),
        ("HKLM", "32", rf"SOFTWARE\Classes\{ext}", "Classes"),
        ("HKCU", "32", rf"SOFTWARE\Classes\{ext}", "Classes"),
        ("HKCU", "64", rf"{FILEEXTS}\{ext}", "FileExts"),
    ):
        p = base + r"\OpenWithProgids"
        for progid in reg_values(hive, p, view):
            sig = (hive, tag, str(progid).lower())
            if sig in seen_progid:
                continue
            seen_progid.add(sig)
            _ph, cmd = resolve_progid(str(progid))
            exe = parse_exe(cmd)
            refs.append(
                SourceRef(
                    label=f"OpenWithProgids[{hive}/{tag}] :: {progid}",
                    kind="progid",
                    exe=exe,
                    dead=not cmd or not file_ok(exe),
                    hive=hive,
                    view=view,
                    path=p,
                    name=str(progid),
                    progid=str(progid),
                    removable=True,
                )
            )

    # 3. OpenWithList (MRU history).  Windows stores a bare executable name here
    #    ("Code.exe"), which is NOT resolvable via PATH, so look the name up
    #    against the Applications registry before calling it dead.
    p = rf"{FILEEXTS}\{ext}\OpenWithList"
    vals = reg_values("HKCU", p, "64")
    mru = str(vals.get("MRUList", ""))
    known = {os.path.basename(a.exe).lower(): a.exe for a in scan_applications() if a.exe}
    for name, data in vals.items():
        if name == "MRUList":
            continue
        exe = which(str(data)) or known.get(os.path.basename(str(data)).lower(), "")
        refs.append(
            SourceRef(
                label=f"OpenWithList[HKCU/FileExts][{name}] = {data}  (MRUList={mru})",
                kind="mru",
                exe=exe or str(data),
                dead=not exe,
                hive="HKCU",
                view="64",
                path=p,
                name=name,
                progid=str(data),
                removable=True,
            )
        )

    # 4. UserChoice -- the actual default program.  READ ONLY, always.
    p = rf"{FILEEXTS}\{ext}\UserChoice"
    uc = reg_values("HKCU", p, "64")
    if uc.get("ProgId"):
        progid = str(uc["ProgId"])
        _ph, cmd = resolve_progid(progid)
        exe = parse_exe(cmd)
        refs.append(
            SourceRef(
                label=f"UserChoice[HKCU/FileExts] :: {progid}   [DEFAULT PROGRAM - read only]",
                kind="userchoice",
                exe=exe,
                dead=not cmd or not file_ok(exe),
                hive="HKCU",
                view="64",
                path=p,
                name="ProgId",
                progid=progid,
                removable=False,
            )
        )

    # 5. Class default (both views, one row per distinct default)
    seen_default: set[tuple[str, str]] = set()
    for hive in ("HKLM", "HKCU"):
        for view in VIEWS:
            p = rf"SOFTWARE\Classes\{ext}"
            default = reg_default(hive, p, view)
            if not default:
                continue
            sig = (hive, default.lower())
            if sig in seen_default:
                continue
            seen_default.add(sig)
            _ph, cmd = resolve_progid(default)
            exe = parse_exe(cmd)
            refs.append(
                SourceRef(
                    label=f"ClassDefault[{hive}] :: {default}",
                    kind="classdefault",
                    exe=exe,
                    dead=not cmd or not file_ok(exe),
                    hive=hive,
                    view=view,
                    path=p,
                    name="",
                    progid=default,
                    removable=False,
                )
            )
    return refs


def sources_for(handler: Handler, refs: list[SourceRef]) -> list[SourceRef]:
    return [r for r in refs if same_exe(r.exe, handler.name)]


# --------------------------------------------------------------------------
# write operations
# --------------------------------------------------------------------------

GUARDED = "userchoice"


@dataclass
class Op:
    kind: str  # set_value | del_value | del_key
    hive: str
    view: str
    path: str
    name: str = ""
    data: str = ""
    why: str = ""

    @property
    def label(self) -> str:
        if self.kind == "set_value":
            return f"SET    {self.hive}\\{self.path}  [{self.name}] = {self.data!r}"
        if self.kind == "del_value":
            return f"DELETE {self.hive}\\{self.path}  value [{self.name}]"
        return f"DELETE {self.hive}\\{self.path}  (entire key)"


def op_set(hive: str, view: str, path: str, name: str, data: str, why: str = "") -> Op:
    return Op("set_value", hive, view, path, name, data, why)


def op_delvalue(hive: str, view: str, path: str, name: str, why: str = "") -> Op:
    return Op("del_value", hive, view, path, name, "", why)


def op_delkey(hive: str, view: str, path: str, why: str = "") -> Op:
    return Op("del_key", hive, view, path, "", "", why)


def guard(op: Op) -> str | None:
    """Refuse anything that would touch UserChoice."""
    if GUARDED in op.path.lower():
        return (
            "refusing to write UserChoice: its Hash would be invalidated "
            "and Windows would reset the default program"
        )
    return None


def unique_ops(ops: list[Op]) -> list[Op]:
    out: list[Op] = []
    seen: set[tuple] = set()
    for o in ops:
        sig = (o.kind, o.hive, o.view, o.path.lower(), o.name.lower())
        if sig in seen:
            continue
        seen.add(sig)
        out.append(o)
    return out


def _slug(text: str) -> str:
    s = "".join(ch if (ch.isalnum() or ch in "-_.") else "-" for ch in text)
    while "--" in s:
        s = s.replace("--", "-")
    return s.strip("-")[:150] or "key"


def do_backup(ops: list[Op], outdir: Path) -> Path | None:
    """`reg export` every key the operation set can touch."""
    keys: set[tuple[str, str]] = set()
    for o in ops:
        p = o.path
        if o.kind == "del_key" and "\\" in p:
            p = p.rsplit("\\", 1)[0]
        keys.add((o.hive, p))
    if not keys:
        return None
    outdir.mkdir(parents=True, exist_ok=True)
    for hive, path in sorted(keys):
        if not reg_exists(hive, path, "64") and not reg_exists(hive, path, "32"):
            continue
        dest = outdir / f"{_slug(hive + '-' + path)}.reg"
        r = subprocess.run(
            ["reg", "export", f"{hive}\\{path}", str(dest), "/y"],
            capture_output=True,
            text=True,
        )
        if r.returncode == 0 and dest.exists():
            info(f"backup  {dest.name}  ({dest.stat().st_size} B)")
        else:
            warn(f"backup FAILED for {hive}\\{path}: {(r.stderr or r.stdout).strip()}")
    return outdir


def apply_ops(ops: list[Op], apply: bool, backup: bool, backup_dir: Path | None) -> dict:
    ops = unique_ops(ops)
    result: dict = {"operations": [o.__dict__ for o in ops], "applied": 0, "blocked": []}
    if not ops:
        if not _RICH:
            pass
        ok("nothing to do")
        return result

    head(f"{'APPLY' if apply else 'DRY RUN'} - {len(ops)} operation(s)")
    for o in ops:
        reason = guard(o)
        if reason:
            err(f"{o.label}  ->  {reason}")
            result["blocked"].append(o.__dict__)
            continue
        say(f"  {o.label}" + (f"\n       {d('why: ' + o.why)}" if o.why else ""))

    if not apply:
        info("dry run: nothing was written. add --apply to commit.")
        return result

    if backup:
        do_backup(ops, backup_dir or default_backup_dir())

    done = 0
    for o in ops:
        if guard(o):
            continue
        try:
            if o.kind == "set_value":
                reg_set(o.hive, o.path, o.view, o.name, o.data)
            elif o.kind == "del_value":
                reg_del_value(o.hive, o.path, o.view, o.name)
            elif o.kind == "del_key" and reg_exists(o.hive, o.path, o.view):
                reg_del_tree(o.hive, o.path, o.view)
            done += 1
        except OSError as e:
            err(f"failed: {o.label} -> {e}")
    shell_refresh()
    result["applied"] = done
    ok(f"applied {done}/{len(ops)} operation(s)")
    return result


def default_backup_dir() -> Path:
    ts = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    return Path.home() / "Desktop" / f"OpenWithBackup-{ts}"


def shell_refresh() -> None:
    with contextlib.suppress(Exception):
        _shell32.SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, None, None)
    exe = shutil.which("ie4uinit.exe") or r"C:\Windows\System32\ie4uinit.exe"
    if Path(exe).exists():
        subprocess.run([exe, "-show"], capture_output=True)


# --------------------------------------------------------------------------
# commands
# --------------------------------------------------------------------------


def payload(handlers: list[Handler]) -> list[dict]:
    return [
        {
            "index": h.index,
            "recommended": h.recommended,
            "ui_name": h.ui_name,
            "exe": h.name,
            "status": h.status,
            "icon": h.icon,
        }
        for h in handlers
    ]


def cmd_list(args) -> dict:
    extra, ext = norm_ext(args.target)
    rec, more = list_handlers(extra)
    result = {
        "target": extra,
        "extension": ext,
        "recommended": payload(rec),
        "more_options": payload(more),
    }
    if args.json:
        return result
    head(f"Open-with list for {extra}")
    say(
        f"\n[bold]Recommended apps[/bold]  ({len(rec)})"
        if _RICH
        else f"\nRecommended apps  ({len(rec)})"
    )
    table(
        ["#", "App", "Executable", "State"],
        [[h.index, h.ui_name, h.name, g(h.status) if h.exists else b(h.status)] for h in rec],
    )
    say(
        f"\n[bold]More options[/bold]  ({len(more)})" if _RICH else f"\nMore options  ({len(more)})"
    )
    table(
        ["#", "App", "Executable", "State"],
        [[h.index, h.ui_name, h.name, g(h.status) if h.exists else b(h.status)] for h in more],
    )
    dead = [h for h in rec + more if not h.exists]
    if dead:
        warn(f"{len(dead)} entr(ies) point at a missing file -> prune {ext}")
    return result


def cmd_layers(args) -> dict:
    _extra, ext = norm_ext(args.target)
    layers = (
        (f"HKLM\\Classes\\{ext}", "HKLM", rf"SOFTWARE\Classes\{ext}", "64"),
        (f"HKCU\\Classes\\{ext}", "HKCU", rf"SOFTWARE\Classes\{ext}", "64"),
        (f"HKLM\\Classes\\{ext} (32-bit view)", "HKLM", rf"SOFTWARE\Classes\{ext}", "32"),
        (f"HKCU\\Classes\\{ext} (32-bit view)", "HKCU", rf"SOFTWARE\Classes\{ext}", "32"),
        (
            f"HKCU\\FileExts\\{ext}\\OpenWithProgids",
            "HKCU",
            rf"{FILEEXTS}\{ext}\OpenWithProgids",
            "64",
        ),
        (f"HKCU\\FileExts\\{ext}\\OpenWithList", "HKCU", rf"{FILEEXTS}\{ext}\OpenWithList", "64"),
        (f"HKCU\\FileExts\\{ext}\\UserChoice", "HKCU", rf"{FILEEXTS}\{ext}\UserChoice", "64"),
    )
    out: dict = {"extension": ext, "layers": {}}
    apps = scan_applications()
    for label, hive, path, view in layers:
        vals = {str(k): v for k, v in reg_values(hive, path, view).items()}
        out["layers"][label] = vals
        if args.json:
            continue
        head(label)
        if not vals:
            say(d("  (absent)"))
            continue
        for k, v in vals.items():
            kk = "(default)" if k == "" else k
            mark = d("   [read only]") if "userchoice" in path.lower() else ""
            say(f"  {kk} = {v}{mark}")
    if args.json:
        return out
    head("HKCR\\Applications registrations")
    table(
        ["Hive", "Application key", "Verb", "Scope", "SupportedTypes", "Exe", "State"],
        [
            [
                a.tag,
                a.key,
                a.verb or "-",
                d("hidden") if a.no_open_with else ("declared" if a.supported else "undeclared"),
                ", ".join(a.supported) if a.supported else "-",
                a.exe or "-",
                g("ok") if a.exists else b("DEAD"),
            ]
            for a in apps
        ],
    )
    return out


def cmd_audit(args) -> dict:
    extra, ext = norm_ext(args.target)
    rec, more = list_handlers(extra)
    refs = collect_sources(ext)
    used: set[int] = set()
    result: dict = {"target": extra, "extension": ext, "entries": [], "orphan_sources": []}

    if not args.json:
        head(f"Where each entry of {extra} comes from")

    for group, handlers in (("recommended", rec), ("more_options", more)):
        if not args.json:
            title = "Recommended apps" if group == "recommended" else "More options"
            say(f"\n== {title} ==")
        for h in handlers:
            src = sources_for(h, refs)
            for i, r in enumerate(refs):
                if any(r is s for s in src):
                    used.add(i)
            result["entries"].append(
                {
                    "index": h.index,
                    "list": group,
                    "ui_name": h.ui_name,
                    "exe": h.name,
                    "status": h.status,
                    "sources": [{"label": r.label, "kind": r.kind, "dead": r.dead} for r in src],
                }
            )
            if args.json:
                continue
            badge = g("REC ") if h.recommended else c("MORE")
            state = g(h.status) if h.exists else b(h.status)
            say(
                f"\n{badge} {h.index:>2}. {h.ui_name}   {state}"
                if _RICH
                else f"\n{h.index:>2}. {h.ui_name}   {h.status}"
            )
            say(f"        exe   {h.name}")
            if not src:
                say("        from  " + d("(no known registry layer - AppX handler or shell cache)"))
            for r in src:
                say(f"        from  {r.label}" + (b("   <- dead") if r.dead else ""))

    orphans = [r for i, r in enumerate(refs) if i not in used]
    result["orphan_sources"] = [{"label": r.label, "kind": r.kind, "dead": r.dead} for r in orphans]
    if orphans and not args.json:
        head("Registry entries that contributed nothing to the list")
        table(
            ["Layer", "Source", "Resolves to", "State"],
            [[r.kind, r.label, r.exe or "-", b("DEAD") if r.dead else g("ok")] for r in orphans],
        )
    return result


def cmd_apps(args) -> dict:
    apps = scan_applications()
    if args.dead_only:
        apps = [a for a in apps if not a.exists]
    result = {
        "applications": [
            {
                "hive": a.hive,
                "view": a.view,
                "key": a.key,
                "verb": a.verb,
                "exe": a.exe,
                "exists": a.exists,
                "scope": a.scope,
                "supported_types": a.supported,
                "command": a.command,
                "reg_path": a.reg_path,
            }
            for a in apps
        ]
    }
    if args.json:
        return result
    head(f"HKCR\\Applications registrations  ({len(apps)})")
    table(
        ["Hive", "Application key", "Verb", "Scope", "SupportedTypes", "Exe", "State"],
        [
            [
                a.tag,
                a.key,
                a.verb or "-",
                d("hidden") if a.no_open_with else ("declared" if a.supported else "undeclared"),
                ", ".join(a.supported) if a.supported else "-",
                a.exe or "-",
                g("ok") if a.exists else b("DEAD"),
            ]
            for a in apps
        ],
    )
    say("")
    info("undeclared = no SupportedTypes, yet Windows still offers it for EVERY extension")
    info("hidden     = NoOpenWith value present, so it is absent from Open-with")
    return result


def cmd_polluters(args) -> dict:
    bogus = ".openwithprobe7f3a"
    _rec, more = list_handlers(bogus)
    apps = scan_applications()
    rows: list[list[str]] = []
    entries: list[dict] = []
    for h in more:
        match = next((a for a in apps if same_exe(a.exe, h.name)), None)
        if match is not None:
            kind = "Applications"
            if match.no_open_with:
                scope = "already hidden"
                fix = "-"
            else:
                scope = f"shell\\{match.verb or '?'} => every extension"
                if match.supported:
                    scope += f" (declares {len(match.supported)} types)"
                fix = f"hide {match.key}"
        elif h.is_appx:
            kind, scope, fix = "AppX", "AppX package handler", "(not removable here)"
        else:
            kind, scope, fix = "?", "unknown source", "-"
        entries.append(
            {
                "index": h.index,
                "ui_name": h.ui_name,
                "exe": h.name,
                "status": h.status,
                "kind": kind,
                "scope": scope,
                "suggested_fix": fix,
            }
        )
        rows.append([str(h.index), h.ui_name, h.name, kind, scope, fix])
    result = {"probe_extension": bogus, "count": len(more), "entries": entries}
    if args.json:
        return result
    head(f"Offered for EVERY extension  (probed with {bogus})")
    table(["#", "App", "Executable", "Kind", "Why it shows up", "Suggested fix"], rows)
    say("")
    info("These are the irrelevant entries that appear in every Open-with dialog.")
    info("Any Applications row is removable with:  hide <key> --apply")
    return result


def resolve_app_key(spec: str, apps: list[AppEntry]) -> list[AppEntry]:
    """Accept an Applications key name, an exe basename, or an exe path."""
    s = (spec or "").strip()
    if not s:
        return []
    base = os.path.basename(s)
    hits = [a for a in apps if a.key.lower() in (s.lower(), base.lower())]
    if not hits:
        hits = [a for a in apps if same_exe(a.exe, s)]
    if not hits:
        hits = [a for a in apps if os.path.basename(a.exe).lower() == base.lower()]
    return hits


def cmd_hide(args) -> dict:
    apps = scan_applications()
    ops: list[Op] = []
    for spec in args.app:
        hits = resolve_app_key(spec, apps)
        if not hits:
            warn(f"no Applications registration matches {spec!r}")
            continue
        for a in hits:
            if a.no_open_with:
                info(f"{a.key} is already hidden")
                continue
            hive = a.hive if args.hive == "auto" else args.hive
            ops.append(
                op_set(
                    hive,
                    a.view,
                    a.reg_path,
                    "NoOpenWith",
                    "",
                    why=(
                        f"hides {a.key} from every Open-with dialog; "
                        f"reversible with `unhide {a.key}`"
                    ),
                )
            )
    res = apply_ops(ops, args.apply, not args.no_backup, args.backup_dir)
    if args.json:
        return res
    return res


def cmd_unhide(args) -> dict:
    apps = scan_applications()
    ops: list[Op] = []
    for spec in args.app:
        hits = resolve_app_key(spec, apps)
        if not hits:
            warn(f"no Applications registration matches {spec!r}")
            continue
        for a in hits:
            for hive in ("HKCU", "HKLM"):
                if "NoOpenWith" in reg_values(hive, a.reg_path, a.view):
                    ops.append(
                        op_delvalue(
                            hive,
                            a.view,
                            a.reg_path,
                            "NoOpenWith",
                            why=f"makes {a.key} visible in Open-with again",
                        )
                    )
    if not ops:
        ok("no NoOpenWith values found for the given app(s)")
    res = apply_ops(ops, args.apply, not args.no_backup, args.backup_dir)
    if args.json:
        return res
    return res


def cmd_prune(args) -> dict:
    _extra, ext = norm_ext(args.target)
    refs = collect_sources(ext)
    ops: list[Op] = []
    for r in refs:
        if not r.dead or not r.removable:
            continue
        if r.kind == "progid":
            ops.append(
                op_delvalue(
                    r.hive,
                    r.view,
                    r.path,
                    r.name,
                    why=f"ProgID {r.progid!r} resolves to nothing or to a missing file",
                )
            )
        elif r.kind == "mru" and args.mru:
            ops.append(
                op_delvalue(
                    r.hive,
                    r.view,
                    r.path,
                    r.name,
                    why=f"OpenWithList entry {r.progid!r} no longer exists",
                )
            )
        elif r.kind == "applications" and args.dead_apps:
            if r.path == r.app_path:
                # The registration itself is the polluter (it is offered for
                # every extension), so the whole key can go.
                ops.append(
                    op_delkey(
                        r.hive,
                        r.view,
                        r.app_path,
                        why="Applications registration points at a missing executable",
                    )
                )
            else:
                # Only this extension is declared; delete just its entry so the
                # app keeps working for the other extensions it supports.
                ops.append(
                    op_delvalue(
                        r.hive,
                        r.view,
                        r.app_path + r"\SupportedTypes",
                        r.name,
                        why=(
                            f"SupportedTypes entry for {ext} points at a missing "
                            f"executable ({r.exe or '?'})"
                        ),
                    )
                )

    # keep MRUList consistent with the letters that survive
    mru_path = rf"{FILEEXTS}\{ext}\OpenWithList"
    mru_vals = reg_values("HKCU", mru_path, "64")
    removed = {o.name for o in ops if o.kind == "del_value" and o.path == mru_path}
    cur_mru = str(mru_vals.get("MRUList", ""))
    if removed and cur_mru:
        keep = "".join(ch for ch in cur_mru if ch not in removed)
        if keep != cur_mru:
            ops.append(
                op_set(
                    "HKCU",
                    "64",
                    mru_path,
                    "MRUList",
                    keep,
                    why="repair the MRU order after deleting stale entries",
                )
            )

    if not ops:
        ok(f"nothing dead found for {ext}")
    res = apply_ops(ops, args.apply, not args.no_backup, args.backup_dir)
    res["extension"] = ext
    if args.json:
        return res
    return res


def cmd_backup(args) -> dict:
    out = args.backup_dir or default_backup_dir()
    keys = [
        ("HKCU", APPS),
        ("HKLM", APPS),
        ("HKCU", rf"SOFTWARE\Classes\{args.ext}"),
        ("HKLM", rf"SOFTWARE\Classes\{args.ext}"),
        ("HKCU", rf"{FILEEXTS}\{args.ext}"),
    ]
    ops = [op_set(h, "64", p, "_", "") for h, p in keys]
    do_backup(ops, out)
    ok(f"backup written to {out}")
    return {"backup_dir": str(out)}


# --------------------------------------------------------------------------
# CLI
# --------------------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--json", action="store_true", help="machine-readable output")
    common.add_argument(
        "--apply", action="store_true", help="commit changes (default is a dry run)"
    )
    common.add_argument("--no-backup", action="store_true", help="skip the automatic .reg export")
    common.add_argument(
        "--backup-dir", type=Path, default=None, help="where to write the .reg backup"
    )

    p = argparse.ArgumentParser(
        prog="openwith",
        description="Inspect and clean the Windows 'Open with' list.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "read-only commands : list, layers, audit, apps, polluters\n"
            "writing commands   : hide, unhide, prune  (dry run unless --apply)\n"
            "\n"
            "UserChoice (the default program and its Hash) is never modified.\n"
            "Typical run:  uv run scripts/openwith/openwith.py audit .md\n"
        ),
    )
    p.add_argument("--version", action="version", version=f"openwith {__version__}")
    sub = p.add_subparsers(dest="cmd", required=True)

    sp = sub.add_parser(
        "list", parents=[common], help="what the Open-with dialog shows (via the shell API)"
    )
    sp.add_argument("target", help="extension (md) or a file path")
    sp.set_defaults(func=cmd_list)

    sp = sub.add_parser(
        "layers", parents=[common], help="dump the raw registry layers for an extension"
    )
    sp.add_argument("target")
    sp.set_defaults(func=cmd_layers)

    sp = sub.add_parser(
        "audit", parents=[common], help="list entries plus the registry keys each one comes from"
    )
    sp.add_argument("target")
    sp.set_defaults(func=cmd_audit)

    sp = sub.add_parser(
        "apps", parents=[common], help="all HKCR\\Applications registrations and their scope"
    )
    sp.add_argument(
        "--dead-only", action="store_true", help="show only entries whose exe is missing"
    )
    sp.set_defaults(func=cmd_apps)

    sp = sub.add_parser(
        "polluters", parents=[common], help="programs offered for EVERY extension (bogus-ext probe)"
    )
    sp.set_defaults(func=cmd_polluters)

    sp = sub.add_parser(
        "hide", parents=[common], help="add NoOpenWith so an app stops appearing everywhere"
    )
    sp.add_argument("app", nargs="+", help="Applications key (zen.exe), a basename, or an exe path")
    sp.add_argument(
        "--hive",
        default="auto",
        choices=["auto", "HKCU", "HKLM"],
        help="auto = write into the hive where the app is registered",
    )
    sp.set_defaults(func=cmd_hide)

    sp = sub.add_parser("unhide", parents=[common], help="remove NoOpenWith")
    sp.add_argument("app", nargs="+")
    sp.set_defaults(func=cmd_unhide)

    sp = sub.add_parser(
        "prune", parents=[common], help="delete dead ProgIDs / stale MRU entries for an extension"
    )
    sp.add_argument("target")
    sp.add_argument(
        "--no-mru", dest="mru", action="store_false", default=True, help="leave OpenWithList alone"
    )
    sp.add_argument(
        "--dead-apps", action="store_true", help="also delete Applications keys whose exe is gone"
    )
    sp.set_defaults(func=cmd_prune)

    sp = sub.add_parser(
        "backup", parents=[common], help="export the registry keys this tool can touch"
    )
    sp.add_argument("ext", nargs="?", default=".md")
    sp.set_defaults(func=cmd_backup)

    return p


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        result = args.func(args)
    except RuntimeError as e:
        err(str(e))
        return 2
    if args.json and result is not None:
        print(json.dumps(result, ensure_ascii=False, indent=2, default=str))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
