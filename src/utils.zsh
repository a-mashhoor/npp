typeset -Ag colors=(
	[W]='%F{white}'
	[R]='%F{red}'
	[G]='%F{green}'
	[Y]='%F{yellow}'
	[B]='%F{blue}'
	[M]='%F{magneta}'
	[C]='%F{cyan}'
	[reset]='%f'
)

function colorful() {
	t=$1 # text
	c=$2 # color
	print -nP "${colors[$c]}${t}${colors[reset]}"
}

# dep check functions
function dep_check() {

	if ! command -v jq >/dev/null 2>&1; then
		colorful "Err: 'jq' is required but not installed.\n" R >&2
		return 1
	fi

	if ! command -v uuidgen >/dev/null 2>&1; then
		colorful "Err: 'uuidgen' is required but not installed.\n" R >&2
		return 1
	fi
	if ! command -v git >/dev/null 2>&1; then
		colorful "Err: 'git' is required but not installed\n" R >&2
		return 1
	fi
	if ! command -v dig >/dev/null 2>&1; then
		colorful "Err: 'dig' is required but not installed\n" R >&2
		return 1
	fi

}

# this will be called only if the user asks for an advanced lookup
function dnsr_check() {
	if ! command -v dnsr >/dev/null 2>&1; then
		colorful "Err: 'dnsr' is required for advanced dns resovling \n" R >&2
		colorful "hint: https://github.com/a-mashhoor/dnsr"
		return 1
	fi
}

function archive_deps_check() {
    local format="$1"
    local cmds=()
    case "$format" in
        zip)       cmds=(zip) ;;
        tar)       cmds=(tar) ;;
        tar.gz|tgz) cmds=(tar) ;;
        tar.bz2|tbz2) cmds=(tar bzip2) ;;
        7z)        cmds=(7z) ;;
        rar)       cmds=(rar) ;;
        *)
            colorful "archive format not supported\n" R >&2
            exit 1
            ;;
    esac
    local cmd
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            colorful "Err: $cmd is required but not installed.\n" R >&2
            return 1
        fi
    done
}

function trim_string() {
	local str="$1"
	str="${str#"${str%%[![:space:]]*}"}"
	str="${str%"${str##*[![:space:]]}"}"
	echo "$str"
}

function generate_uuid() {
	uuidgen | tr '[:upper:]' '[:lower:]'
}


# Perform DNS A record lookup for a list of domains, with retries
# Arguments:
#   $1: space‑separated list of domains
#   $2: optional resolver IP
# Populates global associative array dns_results (domain -> space‑separated IPs)
function dns_resolve_domains() {
    local -a domains=("${(@)=1}")
    local resolver="$2"
    local max_retries=5
    typeset -gA dns_results=()   # clear previous results

    for domain in "${domains[@]}"; do
        # Skip wildcard domains
        if [[ "$domain" == *\** ]]; then
            dns_results[$domain]=""
            continue
        fi

        local ips=""
        local attempt=1
        while [[ $attempt -le $max_retries ]]; do
            if [[ -n "$resolver" ]]; then
                ips=$(dig +short A @"$resolver" "$domain" 2>/dev/null | { grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true; } | paste -sd ' ')
            else
                ips=$(dig +short A "$domain" 2>/dev/null | { grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true; } | paste -sd ' ')
            fi
            if [[ -n "$ips" ]]; then
                break
            fi
            ((attempt++))
            sleep 1
        done
        dns_results[$domain]="$ips"
    done
}
