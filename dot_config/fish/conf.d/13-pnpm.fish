# pnpm fish 补全：内容即官方 `pnpm completion fish` 的输出，内联在此以免另外维护
# ~/.config/fish/completions/pnpm.fish 文件；候选由 `pnpm completion-server` 在补全时动态生成
# 需要更新时重新执行（实际位置为 ~/.config/fish/conf.d/13-pnpm.fish；该文件由 chezmoi 管理，
# 改动需回写源仓库 dot_config/fish/conf.d/13-pnpm.fish，否则下次 apply 会覆盖）：
#   pnpm completion fish > ~/.config/fish/conf.d/13-pnpm.fish
# pnpm fish completions: this is the output of the official `pnpm completion fish`, inlined so
# that no separate ~/.config/fish/completions/pnpm.fish is needed; candidates are produced on
# demand by `pnpm completion-server`
# To regenerate (actual location ~/.config/fish/conf.d/13-pnpm.fish; chezmoi-managed, so write
# the change back to the source dot_config/fish/conf.d/13-pnpm.fish or apply will overwrite it):
#   pnpm completion fish > ~/.config/fish/conf.d/13-pnpm.fish
if command -q pnpm
	function __pnpm_completion
		set -lx SHELL fish
		set -lx COMP_LINE (commandline -cp)
		set -lx COMP_POINT (string length -- $COMP_LINE)
		set -l tokens (commandline -opc)
		set -l current (commandline -ct)
		if test (count $tokens) -eq 0
			set -a tokens "$current"
		else if test "$tokens[-1]" != "$current"
			set -a tokens "$current"
		end
		pnpm completion-server -- $tokens
	end
	complete -c pnpm -f -a "(__pnpm_completion)"
	complete -c pn -f -a "(__pnpm_completion)"
end
