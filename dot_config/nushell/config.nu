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

# zoxide
zoxide init nushell | save -f ~/.zoxide.nu
source ~/.zoxide.nu

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

# vfox initialization
eval (vfox activate nushell | str trim)

# proxy
let clash_port = 7897

$env.HTTP_PROXY = $"http://127.0.0.1:($clash_port)"
$env.HTTPS_PROXY = $"http://127.0.0.1:($clash_port)"
$env.ALL_PROXY = $"http://127.0.0.1:($clash_port)"
