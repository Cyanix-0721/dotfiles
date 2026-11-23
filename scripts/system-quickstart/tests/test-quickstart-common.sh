#!/usr/bin/env bash
# Bash 公共库测试：加载守卫 / DRY_RUN / AUTO_YES / confirm_install / read_choice / read_pkg_list / qs_run_cmd / failures / err
# 运行: bash scripts/system-quickstart/tests/test-quickstart-common.sh
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="$dir/../lib/quickstart-common.sh"
# shellcheck source=../lib/quickstart-common.sh
. "$LIB"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
tmp="$tmp_dir/pkg.list"

passed=0
fail() {
	echo "FAIL: $*" >&2
	exit 1
}
pass() {
	passed=$((passed + 1))
}

# =============================================================================
# 1) P0-1: 加载守卫（同进程幂等 + 子进程必须重新加载）
# =============================================================================

# 同进程重复 source 不应清空已有状态（QS_FAILURES）
(
	add_failure "guard-preserve"
	# shellcheck source=../lib/quickstart-common.sh
	. "$LIB"
	[ "$(get_failure_count)" = "1" ] || fail "同进程重复 source 意外重置了 QS_FAILURES"
)
pass

# 不应 export COMMON_LOADED
if [ -n "${COMMON_LOADED:-}" ]; then
	fail "不应再设置 COMMON_LOADED"
fi
pass

# 父进程已加载公共库，子进程重新 source 必须成功定义 header 等函数
child_out="$(bash -euo pipefail -c '. "$1"; header "child-ok"; printf "count=%s\n" "$(get_failure_count)"' _ "$LIB")"
[[ "$child_out" == *"==> child-ok"* ]] || fail "子进程未成功加载 header: [$child_out]"
[[ "$child_out" == *"count=0"* ]] || fail "子进程未成功初始化 QS_FAILURES: [$child_out]"
pass

# =============================================================================
# 2) P0-2: DRY_RUN 归一化与导出
# =============================================================================

dry_out="$(env -u DRY_RUN QUICKSTART_DRY_RUN=1 bash -euo pipefail -c '
	. "$1"
	printf "self=%s\n" "$DRY_RUN"
	bash -c "printf \"child=%s\n\" \"\${DRY_RUN:-unset}\""
' _ "$LIB")"
[[ "$dry_out" == *"self=1"* ]] || fail "QUICKSTART_DRY_RUN=1 未归一化为 DRY_RUN=1: [$dry_out]"
[[ "$dry_out" == *"child=1"* ]] || fail "DRY_RUN=1 未 export 给子进程: [$dry_out]"
pass

default_dry="$(env -u DRY_RUN -u QUICKSTART_DRY_RUN bash -euo pipefail -c '. "$1"; printf "%s" "$DRY_RUN"' _ "$LIB")"
[ "$default_dry" = "0" ] || fail "默认 DRY_RUN 应为 0，得到: [$default_dry]"
pass

# =============================================================================
# 3) P1-8: read_pkg_list 全部边界与真实清单
# =============================================================================

# 3.1 去注释、去首尾空白、去重、保持首次出现顺序
printf 'bat\n# comment\n\nfish\nbat\n  zoxide  # inline comment\n' >"$tmp"
out="$(read_pkg_list "$tmp")"
expected=$'bat\nfish\nzoxide'
[ "$out" = "$expected" ] || fail "去重/顺序错误，得到: [$out]"
pass

# 3.2 空文件 → 退出 0 且 stdout 为空（不输出空行）
: >"$tmp"
out="$(read_pkg_list "$tmp")"
[ -z "$out" ] || fail "空文件应返回空输出，得到: [$out]"
byte_count="$(read_pkg_list "$tmp" | wc -c | tr -d '[:space:]')"
[ "$byte_count" = "0" ] || fail "空文件不应输出换行符，字节数: [$byte_count]"
pass

# 3.3 仅含注释与空白的文件 → 退出 0 且 stdout 为 0 字节
printf '# only comment\n   \n\t# another\r\n' >"$tmp"
byte_count="$(read_pkg_list "$tmp" | wc -c | tr -d '[:space:]')"
[ "$byte_count" = "0" ] || fail "纯注释文件不应输出任何字节，字节数: [$byte_count]"
pass

# 3.4 CRLF 行尾与末尾无换行
printf 'bat\r\n  fish  # note\r\nzoxide\r' >"$tmp"
out="$(read_pkg_list "$tmp")"
expected=$'bat\nfish\nzoxide'
[ "$out" = "$expected" ] || fail "CRLF 解析失败，得到: [$out]"
pass

# 3.5 含内部空格的行必须被拒绝（不能把 "foo bar" 拼成 "foobar"）
printf 'foo bar\n' >"$tmp"
if read_pkg_list "$tmp" >/dev/null 2>&1; then
	fail '含内部空格的包名未被拒绝'
fi
pass

# 3.6 非法字符 / 前导 '-' 必须被拒绝，且错误输出到 stderr
for bad_pkg in 'bad!name' '-leading-dash' 'pkg;rm' 'pkg$(id)' 'UPPER'; do
	printf '%s\n' "$bad_pkg" >"$tmp"
	bad_stdout=""
	if bad_stdout="$(read_pkg_list "$tmp" 2>/dev/null)"; then
		fail "非法包名未被拒绝: $bad_pkg"
	fi
	[ -z "$bad_stdout" ] || fail "非法包名不应向 stdout 输出: [$bad_stdout]"
done
pass

# 3.7 Arch 兼容字符（_ 与 @）应被接受
printf 'python_foo\n@scope\nlib32-foo_bar\nly@tty2\n7zip\ng++\npkg.name\n' >"$tmp"
out="$(read_pkg_list "$tmp")"
expected=$'python_foo\n@scope\nlib32-foo_bar\nly@tty2\n7zip\ng++\npkg.name'
[ "$out" = "$expected" ] || fail "Arch 字符 _/@ 校验失败，得到: [$out]"
pass

# 3.8 文件不存在、空路径、目录路径均应安全返回非 0（不触发 set -u 崩溃）
if read_pkg_list "$tmp_dir/does-not-exist" >/dev/null 2>&1; then
	fail '不存在的文件未被拒绝'
fi
if read_pkg_list "" >/dev/null 2>&1; then
	fail '空路径未被拒绝'
fi
if read_pkg_list "$tmp_dir" >/dev/null 2>&1; then
	fail '目录路径未被拒绝'
fi
pass

# 3.9 解析真实清单 scripts/system-quickstart/wsl/manifests/apt-packages.list
real_manifest="$dir/../wsl/manifests/apt-packages.list"
real_out="$(read_pkg_list "$real_manifest")"
[ -n "$real_out" ] || fail "真实清单解析结果为空: $real_manifest"
grep -qx 'git' <<<"$real_out" || fail "真实清单缺少预期包 git"
grep -qx 'fish' <<<"$real_out" || fail "真实清单缺少预期包 fish"
pass

# =============================================================================
# 4) confirm_install：AUTO_YES 语义 + 交互式 Y/N + EOF 安全
# =============================================================================

# AUTO_YES=1：仅自动确认 default_yes=1，跳过 default_yes=0
AUTO_YES=1 confirm_install 1 "推荐项" || fail "AUTO_YES=1 时 default_yes=1 应返回 0"
if AUTO_YES=1 confirm_install 0 "危险/可选项"; then
	fail "AUTO_YES=1 时 default_yes=0 应返回 1"
fi
pass

# AUTO_YES=0 交互式（default_yes=1）
AUTO_YES=0 confirm_install 1 "p" <<<"" || fail "default_yes=1 空回车应返回 0"
AUTO_YES=0 confirm_install 1 "p" <<<"y" || fail "default_yes=1 输入 y 应返回 0"
AUTO_YES=0 confirm_install 1 "p" <<<"YES" || fail "default_yes=1 输入 YES 应返回 0"
if AUTO_YES=0 confirm_install 1 "p" <<<"n"; then fail "default_yes=1 输入 n 应返回 1"; fi
if AUTO_YES=0 confirm_install 1 "p" <<<"no"; then fail "default_yes=1 输入 no 应返回 1"; fi
if AUTO_YES=0 confirm_install 1 "p" <<<"maybe"; then fail "default_yes=1 非法输入应返回 1"; fi
if AUTO_YES=0 confirm_install 1 "p" </dev/null; then fail "default_yes=1 EOF 应安全返回 1"; fi
pass

# AUTO_YES=0 交互式（default_yes=0）
if AUTO_YES=0 confirm_install 0 "p" <<<""; then fail "default_yes=0 空回车应返回 1"; fi
AUTO_YES=0 confirm_install 0 "p" <<<"y" || fail "default_yes=0 输入 y 应返回 0"
AUTO_YES=0 confirm_install 0 "p" <<<"yes" || fail "default_yes=0 输入 yes 应返回 0"
if AUTO_YES=0 confirm_install 0 "p" <<<"no"; then fail "default_yes=0 输入 no 应返回 1"; fi
if AUTO_YES=0 confirm_install 0 "p" </dev/null; then fail "default_yes=0 EOF 应安全返回 1"; fi
pass

# 无末尾换行输入
printf 'y' | AUTO_YES=0 confirm_install 0 "p" || fail "无末尾换行输入 y 应返回 0"
if printf 'n' | AUTO_YES=0 confirm_install 1 "p"; then fail "无末尾换行输入 n 应返回 1"; fi
pass

# =============================================================================
# 5) read_choice：AUTO_YES + 交互式 + EOF 回退默认值
# =============================================================================

rc_auto="$(AUTO_YES=1 read_choice "1" "prompt: " <<<"99")"
[ "$rc_auto" = "1" ] || fail "AUTO_YES=1 时 read_choice 应直接返回默认值 1，得到: [$rc_auto]"
pass

rc_val="$(AUTO_YES=0 read_choice "1" "prompt: " <<<"3")"
[ "$rc_val" = "3" ] || fail "read_choice 应返回输入值 3，得到: [$rc_val]"

rc_no_nl="$(printf '2' | AUTO_YES=0 read_choice "1" "prompt: ")"
[ "$rc_no_nl" = "2" ] || fail "read_choice 无换行输入应返回 2，得到: [$rc_no_nl]"

rc_empty="$(AUTO_YES=0 read_choice "tty2" "prompt: " <<<"")"
[ "$rc_empty" = "tty2" ] || fail "read_choice 空输入应回退 tty2，得到: [$rc_empty]"

rc_eof="$(AUTO_YES=0 read_choice "4" "prompt: " </dev/null)"
[ "$rc_eof" = "4" ] || fail "read_choice EOF 应回退默认值 4，得到: [$rc_eof]"
pass

# =============================================================================
# 6) init_auto_yes：环境变量兼容 + Y/n 默认 + EOF + 不盲目 export
# =============================================================================

init_res="$(env -u AUTO_YES QUICKSTART_AUTO_YES=1 bash -euo pipefail -c '
	. "$1"
	init_auto_yes >/dev/null
	printf "%s" "$AUTO_YES"
' _ "$LIB")"
[ "$init_res" = "1" ] || fail "init_auto_yes 未识别 QUICKSTART_AUTO_YES=1: [$init_res]"

init_enter="$(env -u AUTO_YES -u QUICKSTART_AUTO_YES bash -euo pipefail -c '
	. "$1"
	init_auto_yes <<<"$(printf "")" >/dev/null
	child_val="$(bash -c "printf \"%s\" \"\${AUTO_YES:-unset}\"")"
	printf "self=%s,child=%s" "$AUTO_YES" "$child_val"
' _ "$LIB")"
[ "$init_enter" = "self=1,child=unset" ] || fail "init_auto_yes 回车应启用且不盲目 export，得到: [$init_enter]"

init_no="$(env -u AUTO_YES -u QUICKSTART_AUTO_YES bash -euo pipefail -c '
	. "$1"
	init_auto_yes <<<"no" >/dev/null
	printf "%s" "$AUTO_YES"
' _ "$LIB")"
[ "$init_no" = "0" ] || fail "init_auto_yes 输入 no 应设 AUTO_YES=0，得到: [$init_no]"

init_eof="$(env -u AUTO_YES -u QUICKSTART_AUTO_YES bash -euo pipefail -c '
	. "$1"
	init_auto_yes </dev/null >/dev/null
	printf "%s" "$AUTO_YES"
' _ "$LIB")"
[ "$init_eof" = "0" ] || fail "init_auto_yes EOF 应安全设 AUTO_YES=0，得到: [$init_eof]"
pass

# =============================================================================
# 7) qs_run_cmd：dry-run 引用格式 / live 执行 / 0 参数安全
# =============================================================================

marker="$tmp_dir/marker"
dry_cmd_out="$(DRY_RUN=1 qs_run_cmd touch "$marker" "hello world")"
[ ! -e "$marker" ] || fail "DRY_RUN=1 不应实际执行命令"
[[ "$dry_cmd_out" == *"[dry-run]"* ]] || fail "DRY_RUN=1 应输出 [dry-run] 前缀: [$dry_cmd_out]"
[[ "$dry_cmd_out" == *'hello\ world'* ]] || fail "DRY_RUN=1 应保留参数转义格式: [$dry_cmd_out]"
pass

DRY_RUN=0 qs_run_cmd touch "$marker"
[ -f "$marker" ] || fail "DRY_RUN=0 应实际执行命令"
if DRY_RUN=0 qs_run_cmd false; then
	fail "DRY_RUN=0 应透传命令非 0 退出码"
fi
pass

zero_err="$(qs_run_cmd 2>&1)"
[[ "$zero_err" == *"qs_run_cmd"* ]] || fail "qs_run_cmd 无参数应输出警告: [$zero_err]"
pass

# =============================================================================
# 8) P1-7: add_failure / get_failure_count / write_failure_summary
# =============================================================================

(
	[ "$(get_failure_count)" = "0" ] || fail "初始失败数应为 0"
	write_failure_summary >/dev/null || fail "无失败项时 write_failure_summary 应返回 0"

	add_failure ""
	add_failure "   "
	[ "$(get_failure_count)" = "0" ] || fail "空消息不应计入失败列表"

	add_failure "pkg-a failed"
	add_failure "pkg-b failed"
	add_failure "pkg-a failed"
	[ "$(get_failure_count)" = "2" ] || fail "重复失败项应去重，期望 2 得到 $(get_failure_count)"

	summary_out=""
	if summary_out="$(write_failure_summary)"; then
		fail "存在失败项时 write_failure_summary 应返回非 0"
	fi
	[[ "$summary_out" == *"pkg-a failed"* ]] || fail "失败汇总缺少 pkg-a failed"
	[[ "$summary_out" == *"pkg-b failed"* ]] || fail "失败汇总缺少 pkg-b failed"
)
pass

# =============================================================================
# 9) P2: err() 输出到 stderr 而非 stdout
# =============================================================================

err_stdout="$(err "boom" 2>/dev/null)"
[ -z "$err_stdout" ] || fail "err() 不应输出到 stdout: [$err_stdout]"
err_stderr="$(err "boom" 2>&1 >/dev/null)"
[[ "$err_stderr" == *"boom"* ]] || fail "err() 应输出到 stderr: [$err_stderr]"
pass

echo "bash tests OK ($passed groups passed)"
