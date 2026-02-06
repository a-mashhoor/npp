#!/usr/bin/env zsh


#
# Simple zsh script to reduce the amount of time the pentester should spend
# to create related directory and files for each new project!
#
#
# Author: Arshia Mashhoor
# Version: 1.1.0
# creation data: 2025 aug 15
# Last Update: 2026 feb 06
#
#
# in the next version I will add support for openGPG encryption + decryption
# Also Option to determine the number of report directories to create
# Also the abalitiy to backup an existing project
# the ability to move all of existing directories and files of old project to new project and
#
# adding a number of new report directories (to expand) --> done
#
# Adding a way to set the number of created apex domains or giving a list of scope
# detect the apex domains based on the scope list and each corealed subdomains --> done
#



setopt extendedglob
set -euo pipefail


function main(){
    parse_args "$@"

    if [[ $update_mode -eq 1 ]]; then
        update_existing_project
        exit 0
    fi

    colorful "Current directory is: $(printf '%q\n' "${PWD##*/}")\n" G >&1
    colorful "New project directory name is: ${pname}\n" G >&1
    [[ -n $abs_path ]] && colorful "Specified path: $abs_path\n" G >&1

    local fpath=$(build_path $pname $abs_path)
    [[ ! -n $fpath ]] &&
        colorful "err: Something went wrong when creating path\nprinting help\n\n" R >&2 && usage && exit 1

    colorful "Final Path where the project will be stored is: ${fpath}\n" C >&1
    creation $fpath
    exit 0
}



# Domain processing functions
function trim_string() {
    local str="$1"
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    echo "$str"
}


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


function create_scope_directories() {
    local project_path="$1"
    local -A apex_map

    # Parse the scope_results into local associative array
    for key value in "${(@)scope_results}"; do
        apex_map[$key]="$value"
    done

    if [[ ${#apex_map[@]} -eq 0 ]]; then
        colorful "No valid domains found in scope. Creating sample structure.\n" Y >&1
        # Create sample apex domains
        $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/apex-domain-{A..C}.tld/subdomains/sub-{1..3}.apex.tld/{tech_stack,URLs/{waybackURLs,gathered_urls}}
        return
    fi

    colorful "Creating directory structure for scope...\n" G >&1

    for apex_domain subdomains in "${(@kv)apex_map}"; do
        # Clean apex domain for directory name (replace dots with dashes for safety)
        local apex_dir="${apex_domain//./-}"

        colorful "  Creating apex domain: $apex_domain\n" C >&1

        # Create main apex domain directory
        $mkdir -m 700 -p "$project_path/gathered_info/apex_domains/$apex_dir"

        # Create a file with the original apex domain name
        echo "$apex_domain" > "$project_path/gathered_info/apex_domains/$apex_dir/apex_domain.txt"

        # Process subdomains
        local -a sub_array=(${=subdomains})
        for sub in "${sub_array[@]}"; do
            local sub_dir=""
            local is_wildcard=0

            if [[ "$sub" == *\** ]]; then
                is_wildcard=1
                # Remove wildcard prefix for directory name
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

            # Create subdomain directory structure
            $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/"$apex_dir"/subdomains/"$sub_dir"/{tech_stack,URLs/{waybackURLs,gathered_urls}}

            # Create info files
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


function add_scope_to_existing() {
    local project_path="$1"

    if [[ ${#scope_inputs[@]} -eq 0 ]]; then
        colorful "No scope provided to add.\n" Y >&1
        return
    fi

    colorful "Adding new scope to existing project...\n" G >&1

    # Process the new scope inputs
    process_scope "${scope_inputs[@]}"

    # Parse scope_results into associative array
    local -A new_apex_map
    for key value in "${(@)scope_results}"; do
        new_apex_map[$key]="$value"
    done

    if [[ ${#new_apex_map[@]} -eq 0 ]]; then
        colorful "No valid domains to add.\n" Y >&1
        return
    fi

    # Check existing apex domains
    if [[ -d "$project_path/gathered_info/apex_domains" ]]; then
        local -a existing_apex_dirs=("$project_path/gathered_info/apex_domains"/*(N))
        local -A existing_apex_map

        for apex_dir in "${existing_apex_dirs[@]}"; do
            if [[ -f "$apex_dir/apex_domain.txt" ]]; then
                local apex_name=$(<"$apex_dir/apex_domain.txt")
                existing_apex_map[$apex_name]="$apex_dir"
            fi
        done

        # Process each new apex domain
        for apex_domain subdomains in "${(@kv)new_apex_map}"; do
            if [[ -n "${existing_apex_map[$apex_domain]}" ]]; then
                colorful "  Adding to existing apex domain: $apex_domain\n" C >&1
                local apex_dir="${existing_apex_map[$apex_domain]}"
                apex_dir="${apex_dir##*/}"  # Get just the directory name
            else
                colorful "  Creating new apex domain: $apex_domain\n" G >&1
                local apex_dir="${apex_domain//./-}"
                $mkdir -m 700 -p "$project_path/gathered_info/apex_domains/$apex_dir"
                echo "$apex_domain" > "$project_path/gathered_info/apex_domains/$apex_dir/apex_domain.txt"
            fi

            # Process subdomains for this apex
            local -a sub_array=(${=subdomains})
            for sub in "${sub_array[@]}"; do
                local sub_dir=""
                local is_wildcard=0

                if [[ "$sub" == *\** ]]; then
                    is_wildcard=1
                    sub="${sub#\*.}"
                    sub_dir="${sub//./-}"
                elif [[ "$sub" == "@" ]]; then
                    sub_dir="apex-domain"
                else
                    sub_dir="${sub//./-}"
                fi

                # Check if subdomain already exists
                if [[ -d "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir" ]]; then
                    colorful "    Subdomain already exists: $sub_dir\n" Y >&1
                    continue
                fi

                # Create subdomain directory
                $mkdir -m 700 -p "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/{tech_stack,URLs/{waybackURLs,gathered_urls}}"

                # Create info files
                if [[ $is_wildcard -eq 1 ]]; then
                    echo "*.${sub}" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
                    echo "wildcard" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/wildcard.txt"
                    colorful "    Added wildcard subdomain: *.$sub\n" Y >&1
                elif [[ "$sub" == "@" ]]; then
                    echo "$apex_domain" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
                    echo "apex" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/apex.txt"
                    colorful "    Added apex domain directory\n" C >&1
                else
                    echo "${sub}.${apex_domain}" > "$project_path/gathered_info/apex_domains/$apex_dir/subdomains/$sub_dir/subdomain.txt"
                    colorful "    Added subdomain: $sub\n" G >&1
                fi
            done
        done
    else
        colorful "No existing apex_domains directory found. Creating new structure.\n" Y >&1
        create_scope_directories "$project_path"
    fi

    colorful "Scope addition complete.\n" G >&1
}



function creation(){
    p=$1
    mkdir=$(which mkdir)
    touch=$(which touch)
    tree=$(which tree)
    mkdir="${${mkdir## #}%% #}"
    touch="${${touch## #}%% #}"
    tree="${${tree## #}%% #}"

    [[ -f $p ]] && colorful "err: a file with the same name: '$pname' already exists in the current/target dir\n" R >&2 && exit 1
    [[ -d $p ]] && colorful "err: directory with the same name: '$pname' already exists in the target dir\n" R >&2 && exit 1

    $mkdir -m 700 "$p"
    $mkdir -m 700 -p "$p"/{burp_project,target_data,reports,my_evaluation,gathered_info,"$pname"_obsidian_valut,tmp_exploits/{custom_src,payloads,bin,files2u}}
    $mkdir -m 700 -p "$p"/evidences/{0-vuln_evidences,2-payment_evidences,1-functionalP_evidences}
    $mkdir -m 700 -p "$p"/gathered_info/access_levels/{admins/{full_admin,other_admin_levels},users/{unauth,authed}}
    $mkdir -m 700 -p "$p"/gathered_info/{crawlers_results/katana_r,dns_results,fuzzing_results/{ffuf_r,ferox_r}}

    # Handle apex domains based on scope or create sample
    if [[ ${#scope_inputs[@]} -gt 0 ]]; then
        process_scope "${scope_inputs[@]}"
        create_scope_directories "$p"
    else
        $mkdir -m 700 -p "$p"/gathered_info/apex_domains/apex-domain-{A..C}.tld/subdomains/sub-{1..3}.apex.tld/{tech_stack,URLs/{waybackURLs,gathered_urls}}
    fi

    $mkdir -m 700 -p "$p"/gathered_info/{network/{scan_r},custom_wordlists}
    $mkdir -m 700 -p "$p"/reports/{templates,all_reports/No.{01.."$report_count"}/{evidences/{txt,image,video,payloads,exploits,test_files/files2u},edited_media,examples,encrypted,old_versions}}
    $mkdir -m 700 "$p"/"$pname"_obsidian_valut/"$pname"

    $touch "$p"/gathered_info/network/{ASNs,CIDRs,CDN,whois,hosts_on_ASN}
    $touch "$p"/target_data/{users,general_description}.txt
    $touch "$p"/"$pname"_obsidian_valut/"$pname"/{users,general_description,observations,tmp}.md

    {
        print -n -- "Report author:\nPenTester:\nCVSS_vector:\n"
        print -n -- "CVSS_score:\nOWASP_Rating_Vector:\nOWASP_Rating_score:\n"
    } > "$p"/reports/all_reports/No.{01.."$report_count"}/author.txt

    if [[ $tr -eq 0 ]]; then
        colorful "Project directory is created with below tree structure:\n\n" G >&1
        if [[ -n $tree ]];then
            $tree --noreport "$p" -L 2
        else
            colorful "note: 'tree' is not installed; skipping tree output.\n" Y >&1
            command find "$p" -maxdepth 2 -print 2>/dev/null || true
        fi
    else
        colorful "Project directory is created!\n" G >&1
    fi
}


function update_existing_project() {
    local project_path

    # Determine project path
    if [[ -n $existing_project_path ]]; then
        # User provided a path
        if [[ -d "$existing_project_path" ]]; then
            project_path="${existing_project_path:A}"
        else
            colorful "err: The provided project directory does not exist: $existing_project_path\n" R >&2
            exit 1
        fi
    elif [[ -d "./$existing_project_name" ]]; then
        # Try current directory with provided name
        project_path="${PWD:A}/$existing_project_name"
    elif [[ -d "$existing_project_name" ]]; then
        # Try as absolute/relative path
        project_path="${existing_project_name:A}"
    else
        colorful "err: Could not find project directory. Please provide full path with -up or -dn\n" R >&2
        exit 1
    fi

    # Verify this is a project directory (has the expected structure)
    if [[ ! -d "$project_path/reports/all_reports" ]]; then
        colorful "err: Directory doesn't appear to be a valid project (missing reports/all_reports/)\n" R >&2
        exit 1
    fi

    colorful "Updating existing project at: $project_path\n" G >&1

    # Initialize mkdir command for use in functions
    mkdir=$(which mkdir)
    mkdir="${${mkdir## #}%% #}"

    # Handle scope addition if requested
    if [[ $add_scope -eq 1 ]]; then
        add_scope_to_existing "$project_path"
    fi

    # Handle report addition if requested
    if [[ $add_reports -gt 0 ]]; then
        # Find the highest existing report number
        local existing_reports=("$project_path/reports/all_reports"/No.*(N))
        local last_report_num=0

        if [[ ${#existing_reports[@]} -gt 0 ]]; then
            # Extract the number from the last report directory
            local last_report="${existing_reports[-1]}"
            [[ "$last_report" =~ No\.([0-9]+) ]] && last_report_num="${match[1]#0}"
            # Remove leading zeros by converting to decimal
            last_report_num=$((10#$last_report_num))
        fi

        colorful "Found $last_report_num existing report directories\n" G >&1

        local start_num=$((last_report_num + 1))
        local end_num=$((last_report_num + add_reports))

        colorful "Adding $add_reports new report directories (No.$start_num to No.$end_num)\n" G >&1

        # Create new report directories
        for ((i = start_num; i <= end_num; i++)); do
            local formatted_num=$(printf "%02d" $i)
            $mkdir -m 700 -p "$project_path/reports/all_reports/No.$formatted_num"/{evidences/{txt,image,video,payloads,exploits,test_files/files2u},edited_media,examples,encrypted,old_versions}

            {
                print -n -- "Report author:\nPenTester:\nCVSS_vector:\n"
                print -n -- "CVSS_score:\nOWASP_Rating_Vector:\nOWASP_Rating_score:\n"
            } > "$project_path/reports/all_reports/No.$formatted_num/author.txt"

            colorful "Created report directory No.$formatted_num\n" G >&1
        done

        colorful "Successfully added $add_reports new report directories\n" G >&1
    else
        colorful "No new reports to add (use -ar/--add-reports to specify number)\n" Y >&1
    fi
}

function build_path() {
    local name=${1:-""}
    local apath=${2:-""}
    local path

    if [[ "$name" =~ "/" ]]; then
        colorful "err: Project name contains '/' which is problematic\n\n" R >&2
        return 1
    fi

    if [[ -n $apath ]]; then
        if [[ ! -d "$apath" ]]; then
            colorful "err: The provided path does not exist or is not a directory\n\n" R >&2
            return 1
        fi

        # Use zsh's :A modifier to get absolute path
        apath="${apath:A}"

        path="${apath}/${name}"
        echo "$path"
        return 0
    else
        local current_dir="${PWD:A}"
        path="${current_dir}/${name}"
        echo "$path"
        return 0
    fi
}

function usage(){
    local script_name=${funcfiletrace[1]%:*}
    script_name=${${script_name:t}:r}
    echo
    colorful "simple zsh script to create and manage project needed dirs and files at the start\n" C >&1
    colorful "nnp stands for new pentest project\n" C >&1
    colorful "Author: Arshia Mashhoor\n\n" B >&1
    colorful "Usage:\n" R >&1
    colorful "  Create new project:\n" W >&1
    colorful "    $script_name -n PROJECT_NAME [-p ABSOLUTE_PATH] [-rc REPORT_COUNT] [-s SCOPE_FILE_OR_LIST] [-t]\n\n" W >&1
    colorful "  Update existing project:\n" W >&1
    colorful "    $script_name -up PROJECT_PATH [-ar ADD_REPORTS] [-as]\n" W >&1
    colorful "    $script_name -dn PROJECT_NAME [-ar ADD_REPORTS] [-as]\n\n" W >&1

    colorful "Options:\n" W >&1
    colorful "  -h, --help                         print to stdout this help message\n" W >&1
    colorful "  -n, --name      PROJECT_NAME       takes a name for your new project\n" W >&1
    colorful "  -p, --path      SELECTED_PATH      takes an absolute path for project's parent dir\n" W >&1
    colorful "  -rc, --report-count REPORT_COUNT   number of report directories to create (default: 20)\n" W >&1
    colorful "  -s, --scope     SCOPE_INPUT        domains/URLs to process (file with @ prefix or list)\n" W >&1
    colorful "  -t, --tree                         prints the final tree structure of created dirs\n" W >&1
    colorful "  -up, --update-project PROJECT_PATH update an existing project at given path\n" W >&1
    colorful "  -dn, --directory-name PROJECT_NAME update an existing project by name in current dir\n" W >&1
    colorful "  -ar, --add-reports ADD_REPORTS     number of additional report directories to add\n" W >&1
    colorful "  -as, --add-scope                   add new domains to existing project scope\n\n" W >&1

    colorful "Scope Input:\n" Y >&1
    colorful "  -s can take:\n" Y >&1
    colorful "    - A list of domains/URLs: -s 'example.com' '*.test.com' 'https://api.example.com'\n" Y >&1
    colorful "    - A file with @ prefix: -s @scope.txt (one domain/URL per line)\n" Y >&1
    colorful "    - Read from stdin with @-: -s @- (pipe input)\n\n" Y >&1

    colorful "Examples:\n" Y >&1
    colorful "  Create new project with scope from file:\n" Y >&1
    colorful "    $script_name -n myproject -s @scope.txt -rc 30\n\n" Y >&1
    colorful "  Create new project with inline scope:\n" Y >&1
    colorful "    $script_name -n myproject -s 'example.com' '*.test.example.com' 'https://api.example.com'\n\n" Y >&1
    colorful "  Update existing project, add 10 more reports and new scope:\n" Y >&1
    colorful "    $script_name -up /path/to/project -ar 10 -as -s 'new.example.com' '*.api.example.com'\n\n" Y >&1
    colorful "  Update existing project by name, add scope from file:\n" Y >&1
    colorful "    $script_name -dn myproject -as -s @new_scope.txt\n\n" Y >&1
}






function parse_args(){
    zmodload zsh/zutil

    [[ ${#@} -eq 0 ]] && { usage; exit 1 }

    local -A opts
    typeset -g n=() p=() t=0 rc=() up=() dn=() ar=() s=() as=0

    # Parse all possible options
    zparseopts -D -F -A opts -- \
        n:=n -name:=n \
        p:=p -path:=p \
        t=t -tree=t \
        rc:=rc -report-count:=rc \
        s:=s -scope:=s \
        up:=up -update-project:=up \
        dn:=dn -directory-name:=dn \
        ar:=ar -add-reports:=ar \
        as=as -add-scope=as \
        h=help -help=help  || { usage; exit 1 }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage
        exit 0
    fi

    local mode_count=0
    [[ ${#n} -gt 0 ]] && mode_count=$((mode_count + 1))
    [[ ${#up} -gt 0 ]] && mode_count=$((mode_count + 1))
    [[ ${#dn} -gt 0 ]] && mode_count=$((mode_count + 1))

    if [[ $mode_count -eq 0 ]]; then
        colorful "err: You must specify either -n (new project) or -up/-dn (update project)\n" R >&2
        usage
        exit 1
    elif [[ $mode_count -gt 1 ]]; then
        colorful "err: Cannot specify multiple modes (-n, -up, -dn) at the same time\n" R >&2
        usage
        exit 1
    fi

    # Set update mode flag
    typeset -g update_mode=0
    if [[ ${#up} -gt 0 ]] || [[ ${#dn} -gt 0 ]]; then
        update_mode=1
    fi

    # Handle scope inputs
    typeset -g scope_inputs=()
    if [[ ${#s} -gt 0 ]]; then
        local scope_arg="${s[-1]}"

        if [[ "$scope_arg" == @- ]]; then
            # Read from stdin
            while IFS= read -r line || [[ -n "$line" ]]; do
                line=$(trim_string "$line")
                [[ -n "$line" ]] && scope_inputs+=("$line")
            done
        elif [[ "$scope_arg" == @* ]]; then
            # Read from file
            local scope_file="${scope_arg#@}"
            if [[ ! -f "$scope_file" ]]; then
                colorful "err: Scope file not found: $scope_file\n" R >&2
                exit 1
            fi
            while IFS= read -r line || [[ -n "$line" ]]; do
                line=$(trim_string "$line")
                [[ -n "$line" ]] && scope_inputs+=("$line")
            done < "$scope_file"
        else
            # Direct scope arguments
            scope_inputs=("${(@)s}")
        fi
    fi

    if [[ $update_mode -eq 1 ]]; then
        typeset -g existing_project_path=""
        typeset -g existing_project_name=""

        if [[ ${#up} -gt 0 ]]; then
            existing_project_path="${up[-1]}"
        fi
        if [[ ${#dn} -gt 0 ]]; then
            existing_project_name="${dn[-1]}"
        fi

        typeset -g add_reports=0
        if [[ ${#ar} -gt 0 ]]; then
            if [[ ${ar[-1]} =~ ^[0-9]+$ ]]; then
                add_reports=${ar[-1]}
            else
                colorful "err: -ar/--add-reports must be a positive integer\n" R >&2
                exit 1
            fi
        fi

        # Set add_scope flag - FIX: check if as is set (not empty string)
        typeset -g add_scope=0
        if [[ -n "${opts[-as]:-${opts[--add-scope]}}" ]]; then
            add_scope=1
            # If adding scope but no scope provided, show error
            if [[ ${#scope_inputs[@]} -eq 0 ]]; then
                colorful "err: -as/--add-scope requires scope input with -s\n" R >&2
                usage
                exit 1
            fi
        fi

        typeset -g tr=1
        if (( ${+opts[-t]} )) || (( ${+opts[--tree]} )); then
            tr=0
        fi

        # We need either -up or -dn
        if [[ -z "$existing_project_path" ]] && [[ -z "$existing_project_name" ]]; then
            colorful "err: Update mode requires either -up or -dn option\n" R >&2
            usage
            exit 1
        fi
    else
        typeset -g tr=1
        if (( ${+opts[-t]} )) || (( ${+opts[--tree]} )); then
            tr=0
        fi

        typeset -g pname=""
        if [[ ${#n} -gt 0 ]]; then
            pname="${n[-1]}"
        fi

        if [[ -z "$pname" ]]; then
            colorful "Project name is required!" R >&2
            vared -p "enter project name: " -c pname
            [[ -z $pname ]] && colorful "err: no project name provided exiting\nprinting help\n\n" R >&2 && usage && exit 3
        fi

        if [[ "$pname" == */* ]]; then
            colorful "err: project name must not contain '/'\n" R >&2
            exit 2
        fi

        typeset -g report_count=20
        if [[ ${#rc} -gt 0 ]]; then
            if [[ ${rc[-1]} =~ ^[0-9]+$ ]] && [[ ${rc[-1]} -gt 0 ]]; then
                report_count=${rc[-1]}
            else
                colorful "err: -rc/--report-count must be a positive integer\n" R >&2
                exit 1
            fi
        fi

        typeset -g abs_path
        if [[ ${#p} -gt 0 ]]; then
            abs_path="${p[-1]}"
            if [[ "$abs_path" != /* ]]; then
                colorful "err: The provided path must be absolute (start with '/')\n\n" R >&2
                usage
                exit 1
            fi
            if [[ ! -d "$abs_path" ]]; then
                colorful "err: The provided absolute path does not exist\n\n" R >&2 && usage && exit 1
            fi
        fi
    fi
}

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

function colorful(){
    t=$1 # text
    c=$2 # color
    print -nP "${colors[$c]}${t}${colors[reset]}"
}

main "${@}"
