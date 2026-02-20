function validate_domain() {
    local domain=$1
    local max_length=255

    domain=$(trim_string "$domain")

    if [[ -z "$domain" ]]; then
        colorful "err: Empty domain string\n" R >&2
        return 1
    fi

    if [[ ${#domain} -gt $max_length ]]; then
        colorful "err: Domain exceeds maximum length of $max_length characters\n" R >&2
        return 1
    fi

    if ! [[ "$domain" =~ '^([a-zA-Z0-9]+(-[a-zA-Z0-9]+)*\.)+[a-zA-Z]{2,}$' ]]; then
        colorful "err: '$domain' doesn't appear to be a valid domain\n" R >&2
        return 1
    fi

    local IFS="."
    local labels=(${=domain})
    for label in "${labels[@]}"; do
        if [[ ${#label} -lt 1 || ${#label} -gt 63 ]]; then
            colorful "err: Domain part '$label' has invalid length (must be 1-63 characters)\n" R >&2
            return 1
        fi

        if ! [[ "$label" =~ '^[a-zA-Z0-9]' ]] || ! [[ "$label" =~ '[a-zA-Z0-9]$' ]]; then
            colorful "err: Domain part '$label' must start and end with a letter or digit\n" R >&2
            return 1
        fi

        if ! [[ "$label" =~ '^[a-zA-Z0-9-]+$' ]]; then
            colorful "err: Domain part '$label' contains invalid characters\n" R >&2
            return 1
        fi
    done

    return 0
}


function extract_fqdn_from_url() {
    local url="$1"
    local fqdn=""

    url="${url#*://}"
    url="${url%%:*}"
    url="${url%%/*}"
    url="${url#*@}"

    echo "$url"
}


function get_apex_domain() {
    local domain="$1"
    local domain_lower="${domain:l}"  # Convert to lowercase

    # Known public suffixes list (common TLDs and public suffixes)
    local -a public_suffixes=(
        "com" "org" "net" "edu" "gov" "mil"
        "co.uk" "ac.uk" "gov.uk" "org.uk" "me.uk" "ltd.uk" "plc.uk" "net.uk"
        "com.au" "net.au" "org.au" "edu.au" "gov.au"
        "ca" "de" "fr" "it" "es" "nl" "se" "no" "dk" "fi"
        "com.br" "org.br" "net.br" "gov.br"
        "co.jp" "ne.jp" "or.jp" "go.jp" "ac.jp" "ed.jp"
        "co.za" "org.za" "net.za" "web.za" "gov.za"
        "co.nz" "org.nz" "net.nz" "maori.nz" "iwi.nz" "govt.nz"
        "com.sg" "org.sg" "net.sg" "edu.sg" "gov.sg"
        "com.hk" "org.hk" "net.hk" "edu.hk" "gov.hk"
        "com.cn" "org.cn" "net.cn" "edu.cn" "gov.cn"
        "com.tw" "org.tw" "net.tw" "edu.tw" "gov.tw"
        "com.mx" "org.mx" "net.mx" "edu.mx" "gob.mx"
        "com.ar" "org.ar" "net.ar" "edu.ar" "gov.ar"
        "co.in" "org.in" "net.in" "edu.in" "gov.in" "res.in" "ac.in"
        "co.il" "org.il" "net.il" "ac.il" "gov.il" "muni.il"
        "co.kr" "or.kr" "ne.kr" "re.kr" "pe.kr" "go.kr" "ac.kr" "hs.kr"
        "com.my" "org.my" "net.my" "edu.my" "gov.my"
        "com.ph" "org.ph" "net.ph" "edu.ph" "gov.ph"
    )

    # Sort suffixes by length (longest first) to match most specific first
    local -a sorted_suffixes=(${(Oa)public_suffixes})

    # Try to find a matching public suffix
    for suffix in "${sorted_suffixes[@]}"; do
        if [[ "$domain_lower" == *".$suffix" ]]; then
            # Remove the matched suffix and get the part before it
            local without_suffix="${domain_lower%.$suffix}"
            # Get the last label before the suffix
            local apex_part="${without_suffix##*.}"
            echo "${apex_part}.${suffix}"
            return 0
        fi
    done

    # If no public suffix found, use a simple heuristic: last two parts
    local -a parts=(${(s:.:)domain_lower})
    if [[ ${#parts[@]} -ge 2 ]]; then
        echo "${parts[-2]}.${parts[-1]}"
    else
        echo "$domain"
    fi
}

