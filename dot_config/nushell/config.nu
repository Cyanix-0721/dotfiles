# config.nu
#
# Nushell configuration
# See https://www.nushell.sh/book/configuration.html

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

# vfox configuration
vfox activate nushell $nu.default-config-dir | save --append $nu.config-path

# proxy
let clash_port = 7897
let-env HTTP_PROXY = $"http://127.0.0.1:($clash_port)"
let-env HTTPS_PROXY = $"http://127.0.0.1:($clash_port)"
