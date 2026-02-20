# Config file handling
#
# Validate a config file (syntax and known keys)
function validate_config() {
    local config_file="$1"
    if [[ ! -f "$config_file" ]]; then
        colorful "Config file not found: $config_file\n" R >&2
        return 1
    fi

    local -A valid_keys=(
        name 1
        path 1
        type 1
        bounty-program 1
        client 1
        pentest-info 1
        description 1
        roe 1
        git-email 1
        git-user 1
        note 1
        trilium-server 1
        trilium-api-key 1
        trilium-parent 1
    )

    local line_num=0
    local ok=0
    while IFS= read -r line; do
        ((line_num++))
        line=$(trim_string "$line")
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" != *=* ]]; then
            colorful "Line $line_num: Missing '=': $line\n" R >&2
            ok=1
            continue
        fi
        local key="${line%%=*}"
        local value="${line#*=}"
        key=$(trim_string "$key")
        value=$(trim_string "$value")
        if [[ -z "$key" ]]; then
            colorful "Line $line_num: Empty key\n" R >&2
            ok=1
            continue
        fi
        if [[ -z "$value" ]]; then
            colorful "Line $line_num: Empty value for key '$key'\n" R >&2
            ok=1
            continue
        fi
        if [[ -z "${valid_keys[$key]}" ]]; then
            colorful "Line $line_num: Unknown key '$key'\n" R >&2
            ok=1
        fi
    done < "$config_file"
    return $ok
}

# Read config file and set init variables if they are still empty
function read_config() {
    local config_file="$1"
    [[ -f "$config_file" ]] || { colorful "Config file not found: $config_file\n" R >&2; return 1; }

    # Map config keys to global variable names
    local -A key_to_var=(
        name init_name
        path init_path
        type init_type
        bounty-program init_bounty_platforms
        client init_client
        pentest-info init_pentest_info
        description init_description
        roe init_roe
        git-email init_git_email
        git-user init_git_user
        note init_note_system
        trilium-server init_trilium_server
        trilium-api-key init_trilium_api_key
        trilium-parent init_trilium_parent
    )

    # Temporary storage for config values (multiple lines allowed for bounty-program)
    typeset -A config_vals
    while IFS= read -r line; do
        line=$(trim_string "$line")
        [[ -z "$line" || "$line" == \#* ]] && continue
        if [[ "$line" != *=* ]]; then
            colorful "Invalid config line (no =): $line\n" R >&2
            return 1
        fi
        local key="${line%%=*}"
        local value="${line#*=}"
        key=$(trim_string "$key")
        value=$(trim_string "$value")
        if [[ -z "$key" ]]; then
            colorful "Empty key in config line: $line\n" R >&2
            return 1
        fi
        if [[ -z "${key_to_var[$key]}" ]]; then
            colorful "Unknown config key: $key\n" R >&2
            return 1
        fi
        # Store multiple values separated by a delimiter (ASCII unit separator)
        if [[ -n "${config_vals[$key]}" ]]; then
            config_vals[$key]+=$'\x1F'"$value"
        else
            config_vals[$key]="$value"
        fi
    done < "$config_file"

    # Apply to globals only if they are still empty (i.e., not set by command line)
    local key varname
    for key varname in "${(@kv)key_to_var}"; do
        if [[ -n "${config_vals[$key]}" ]]; then
            local -a values=("${(@ps:\x1F:)config_vals[$key]}")
            if [[ "$varname" == "init_bounty_platforms" ]]; then
                # Array variable
                if [[ ${#init_bounty_platforms[@]} -eq 0 ]]; then
                    init_bounty_platforms=("${values[@]}")
                fi
            else
                # Scalar variable: take first value
                if [[ -z "$(eval echo \$$varname)" ]]; then
                    eval "$varname='${values[1]}'"
                fi
            fi
        fi
    done
}

