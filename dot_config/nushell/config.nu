# config.nu
#
# Nushell configuration
# See https://www.nushell.sh/book/configuration.html

# Hide startup banner
$env.config.show_banner = false

# env
source-env ($nu.env-path)

# starship
mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")

# zoxide (only if installed)
if (which zoxide | is-not-empty) {
    zoxide init nushell | save -f ~/.zoxide.nu
    source ~/.zoxide.nu
}

# yazi
def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
}

# vfox configuration
const vfox_script = ($nu.default-config-dir | path join "vfox.nu")
source $vfox_script

# Fix deprecated `get -i` → `get -o` in auto-generated vfox.nu (deprecated since 0.106)
try { open $vfox_script | str replace 'get -i hooks.pre_prompt' 'get -o hooks.pre_prompt' | save -f $vfox_script }
