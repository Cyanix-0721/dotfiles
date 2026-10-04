@echo off
rem ============================================================================
rem  git shim - required so that betterleaks can scan git history on Windows.
rem
rem  betterleaks injects config-isolation variables into git:
rem      GIT_CONFIG_GLOBAL=NUL   GIT_CONFIG_SYSTEM=NUL   GIT_CONFIG_NOSYSTEM=1
rem  Since Git for Windows 2.56.0 (UCRT switch) the all-uppercase device name
rem  NUL is rejected:
rem      fatal: unable to access 'NUL': Invalid argument   (git exit 128)
rem  betterleaks then scans 0 bytes but still prints
rem      WRN no leaks found in incomplete scan
rem  which is a false green. Upstream fix PR #6450 is merged, not yet released.
rem  See: betterleaks issue #352, git-for-windows issue #6449 / PR #6450
rem
rem  This shim does exactly one thing: rewrite a value that is exactly NUL to
rem  lowercase nul, which 2.56.0 does accept. Every other value is passed
rem  through untouched, so normal git config reads are unaffected.
rem  Older git (2.53 - 2.55) accepts nul as well (verified).
rem
rem  Put on PATH by the mise global [env] _.path entry; no manual PATH edits.
rem ============================================================================
rem  KEEP THIS FILE PURE ASCII. cmd.exe parses .cmd in the OEM codepage
rem  (CP936 on this machine), so UTF-8 comments make DBCS lead/trail bytes
rem  pair across line breaks and the "comment" text gets RUN AS COMMANDS.
rem  Cost of ignoring this: a stray '...' is not recognized as an internal
rem  or external command, plus a ~240s hang when invoked from a batch file.
rem  Also: batch callers must use `call git ...`; without `call` control
rem  transfers into this shim and never returns to the caller.
rem ============================================================================
setlocal
if /i "%GIT_CONFIG_GLOBAL%"=="NUL" set "GIT_CONFIG_GLOBAL=nul"
if /i "%GIT_CONFIG_SYSTEM%"=="NUL" set "GIT_CONFIG_SYSTEM=nul"
rem call git.exe directly, not git, to avoid re-entering this shim
git.exe %*
