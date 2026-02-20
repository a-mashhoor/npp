function create_scope_directories() {
    local project_path="$1"
    local -A apex_map

    local mkdir=$(command -v mkdir 2>/dev/null || echo "")
    mkdir="${${mkdir## #}%% #}"

    local touch=$(command -v touch 2>/dev/null || echo "")
    touch="${${touch## #}%% #}"


    if [[ -z "$mkdir" ]]; then
        colorful "err: mkdir command not found. This is required.\n" R >&2
        exit 1
    fi

    for key value in "${(@)scope_results}"; do
        apex_map[$key]="$value"
    done

    if [[ ${#apex_map[@]} -eq 0 ]]; then
        colorful "No valid domains found in scope. Creating sample structure.\n" Y >&1
        $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/apex-domain-{A..C}.tld/subdomains/sub-{1..3}.apex.tld/{tech_stack,URLs/{waybackURLs,gathered_urls}}
        return
    fi

    colorful "Creating directory structure for scope...\n" G >&1

    for apex_domain subdomains in "${(@kv)apex_map}"; do
        local apex_dir="${apex_domain//./-}"

        colorful "  Creating apex domain: $apex_domain\n" C >&1

        $mkdir -m 700 -p "$project_path/gathered_info/apex_domains/$apex_dir"
        echo "$apex_domain" > "$project_path/gathered_info/apex_domains/$apex_dir/apex_domain.txt"

        local -a sub_array=(${=subdomains})
        for sub in "${sub_array[@]}"; do
            local sub_dir=""
            local is_wildcard=0

            if [[ "$sub" == *\** ]]; then
                is_wildcard=1
                sub="${sub#\*.}"
                sub_dir="${sub//./-}"
                colorful "    Creating wildcard subdomain: *.$sub\n" Y >&1
            elif [[ "$sub" == "@" ]]; then
                sub_dir="apex-domain"
                colorful "    Creating apex domain directory\n" C >&1
            else
                sub_dir="${sub//./-}"
                colorful "    Creating subdomain: $sub\n" G >&1
            fi

            $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/"$apex_dir"/subdomains/"$sub_dir"/{tech_stack,URLs/{waybackURLs,gathered_urls}}
            $touch "$project_path"/gathered_info/apex_domains/"$apex_dir"/subdomains/"$sub_dir"/tech_stack/technologies.json

            if [[ $is_wildcard -eq 1 ]]; then
                echo "*.${sub}" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
                echo "wildcard" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/wildcard.txt"
            elif [[ "$sub" == "@" ]]; then
                echo "$apex_domain" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
                echo "apex" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/apex.txt"
            else
                echo "${sub}.${apex_domain}" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
            fi
        done
    done
}



function process_scope() {
    local -a inputs=("${(@)@}")  # All arguments as array
    local -A apex_to_subdomains  # Associative array: apex -> array of subdomains

    colorful "Processing scope/domains...\n" C >&1

    for input in "${inputs[@]}"; do
        # Trim whitespace from the input
        input=$(trim_string "$input")

        # Skip empty lines after trimming
        if [[ -z "$input" ]]; then
            continue
        fi

        local original_input="$input"
        local is_wildcard=0
        local fqdn=""

        colorful "  Processing: $original_input\n" C >&1

        # Check if it's a wildcard
        if [[ "$input" == \*.* ]]; then
            is_wildcard=1
            # Remove the wildcard prefix
            input="${input#\*.}"
            colorful "    Detected as wildcard, using: $input\n" Y >&1
        fi

        # Extract FQDN from URL if it's a URL
        if [[ "$input" == http://* ]] || [[ "$input" == https://* ]] || \
           [[ "$input" == ftp://* ]] || [[ "$input" == *://* ]]; then
            fqdn=$(extract_fqdn_from_url "$input")
            # Trim the extracted FQDN too
            fqdn=$(trim_string "$fqdn")
            colorful "    Extracted FQDN from URL: $fqdn\n" B >&1
        else
            fqdn="$input"
        fi

        # Validate the FQDN
        if ! validate_domain "$fqdn"; then
            colorful "    Skipping invalid domain: $fqdn\n" R >&1
            continue
        fi

        # Get the apex domain
        local apex_domain=$(get_apex_domain "$fqdn")

        # Get the subdomain part (everything before the apex domain)
        local subdomain_part=""
        if [[ "$fqdn" == "$apex_domain" ]]; then
            subdomain_part="@"
        else
            # Remove the apex domain from the end of the FQDN
            subdomain_part="${fqdn%.$apex_domain}"
        fi

        # If it was a wildcard input, mark it as such
        if [[ $is_wildcard -eq 1 ]]; then
            if [[ "$subdomain_part" == "@" ]]; then
                subdomain_part="*"
            else
                subdomain_part="*.${subdomain_part}"
            fi
        fi

        # Add to our associative array
        if (( ! ${+apex_to_subdomains[$apex_domain]} )); then
            apex_to_subdomains[$apex_domain]="$subdomain_part"
        else
            # Check if this subdomain already exists for this apex
            local existing_subs="${apex_to_subdomains[$apex_domain]}"
            if [[ ! " ${existing_subs} " =~ " ${subdomain_part} " ]]; then
                apex_to_subdomains[$apex_domain]="${existing_subs} ${subdomain_part}"
            fi
        fi

        colorful "    ✓ Apex: $apex_domain, Subdomain: $subdomain_part\n" G >&1
    done

    # Return the associative array via a global variable
    typeset -g scope_results
    scope_results=("${(@kv)apex_to_subdomains}")
}


