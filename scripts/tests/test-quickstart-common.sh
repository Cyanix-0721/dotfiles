#!/usr/bin/env bash
# Bash 公共库测试：read_pkg_list 的去注释/去空白/去重/非法校验
# 运行: bash scripts/tests/test-quickstart-common.sh
set -euo pipefail

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/quickstart-common.sh
. "$dir/../lib/quickstart-common.sh"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

fail() {
	echo "FAIL: $*" >&2
	exit 1
}

# 1) 去注释、去空白、去重、保持顺序
printf 'bat\n# comment\n\nfish\nbat\n  zoxide  \n' >"$tmp"
out="$(read_pkg_list "$tmp")"
expected=$'bat\nfish\nzoxide'
[ "$out" = "$expected" ] || fail "去重/顺序错误，得到: [$out]"

# 2) 非法包名应返回非 0
printf 'bad!name\n' >"$tmp"
if read_pkg_list "$tmp" >/dev/null 2>&1; then
	fail '非法包名未被拒绝'
fi

# 3) 文件不存在应返回非 0
if read_pkg_list "$tmp/does-not-exist" >/dev/null 2>&1; then
	fail '不存在的文件未被拒绝'
fi

echo 'bash tests OK'
