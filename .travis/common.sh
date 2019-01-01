# vim: set ts=4:

readonly ALPINE_ROOT='/mnt/alpine'
readonly CLONE_DIR="${CLONE_DIR:-$(pwd)}"
readonly MIRROR_URI='http://dl-cdn.alpinelinux.org/alpine/edge'

# provide an approximation of declare for busybox /bin/sh
command -v declare >/dev/null 2>&1 || declare() {
	local _evars=$(env | cut -d = -f 1 | tr '\n' ' ')
	local var; for var
	do
		local _found=false

		case " $_evars " in
			(*" $var "*) _found=true ;;
		esac

		"$_found" || continue
		local _value
		eval _value="\$$var"
		_value="${_value//\'/\'\\\'\'}"
		printf -- 'declare -x '"$var"'=\x27%s\x27\n' "$_value"
	done
}

declare_to_export() {
	awk '"declare" == $1 && "-x" == $2 {$2="export"; $1=""; print; next;} "declare" != $1 {print;}'
}

# Runs commands inside the Alpine chroot.
alpine_run() {
	local user="${1:-root}"
	local cmd="${2:-sh}"

	local _sudo=
	[ "$(id -u)" -eq 0 ] || _sudo='sudo'

	$_sudo install -c -o "$(id -un)" -m 0644 /dev/null "${ALPINE_ROOT}/.alpine_run_env"

	declare -p ALPINE_ROOT CLONE_DIR MIRROR_URI TRAVIS \
		| declare_to_export > "${ALPINE_ROOT}/.alpine_run_env"
	env | grep ^TRAVIS_ | cut -d = -f 1 | while IFS= read -r VAR; do
		[ -n "$VAR" ] || continue
		declare -p "$VAR" | declare_to_export
	done >> "${ALPINE_ROOT}/.alpine_run_env"

	cat -vn "${ALPINE_ROOT}/.alpine_run_env"

	$_sudo chroot "$ALPINE_ROOT" /usr/bin/env -i su -l $user \
		sh -c "set -x; . /.alpine_run_env; set +x; cd $CLONE_DIR; $cmd"
}

die() {
	print -s1 -c1 "$@\n" 1>&2
	exit 1
}

# Marks start of named folding section for Travis and prints title.
fold_start() {
	local name="$1"
	local title="$2"

	printf "\ntravis_fold:start:$name "
	print -s1 -c6 "> $title\n"
}

# Marks end of the named folding section.
fold_end() {
	local name="$1"

	printf "travis_fold:end:$name\n"
}

# Prints formatted and colored text.
print() {
	local style=0
	local fcolor=9

	local opt; while getopts 's:c:' opt; do
		case "$opt" in
			s) style="$OPTARG";;
			c) fcolor="$OPTARG";;
		esac
	done

	shift $(( OPTIND - 1 ))
	local text="$@"

	printf "\033[${style};3${fcolor}m$text\033[0m"
}

title() {
	printf '\n'
	print -s1 -c6 "==> $@\n"
}
