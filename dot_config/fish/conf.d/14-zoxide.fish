# zoxide：智能目录跳转
# zoxide: smart directory jumper
#
# fish 4.x 把内置函数（含 cd.fish）内嵌进二进制，/usr/share/fish/functions/ 目录不存在。
# zoxide init fish 会尝试从 $__fish_data_dir/functions/cd.fish 复制 cd 函数来定义
# __zoxide_cd_internal，在 fish 4.x 下该文件缺失导致 __zoxide_cd_internal 未定义，
# 触发 "Unknown command: __zoxide_cd_internal"。
# 修复：预定义一个 builtin cd 版本的回退函数，zoxide init 检测到已存在即跳过文件读取。
#
# fish 4.x embeds built-in functions (incl. cd.fish) in the binary; the
# /usr/share/fish/functions/ directory does not exist. zoxide init fish tries to
# source $__fish_data_dir/functions/cd.fish to define __zoxide_cd_internal, which
# fails on fish 4.x → "Unknown command: __zoxide_cd_internal".
# Fix: pre-define a fallback based on `builtin cd`; zoxide init skips the file read.
if not functions -q __zoxide_cd_internal
	function __zoxide_cd_internal --description 'Fallback cd for zoxide (fish 4.x)'
		builtin cd $argv
	end
end

zoxide init fish | source
