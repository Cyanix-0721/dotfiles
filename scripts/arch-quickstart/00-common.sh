#!/bin/bash

# Arch 公共函数：加载跨平台公共库（scripts/lib/quickstart-common.sh）。
# 日志、确认、包清单等通用函数均由公共库提供，本文件仅作薄壳。

_QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/quickstart-common.sh
. "$_QS_DIR/../lib/quickstart-common.sh"
