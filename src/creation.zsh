
function creation() {
    local project_path="$1"
    local project_name="$2"
    local project_id="$3"
    local report_count="$4"
    shift 4
    local -a scope_inputs=("$@")

    local mkdir=$(which mkdir)
    local touch=$(which touch)
    local tree=$(which tree)
    mkdir="${${mkdir## #}%% #}"
    touch="${${touch## #}%% #}"
    tree="${${tree## #}%% #}"

    # Safety checks
    if [[ -f "$project_path" ]]; then
        colorful "err: A file with the name '$project_name' already exists at the target location.\n" R >&2
        exit 1
    fi
    if [[ -d "$project_path" ]]; then
        colorful "err: A directory named '$project_name' already exists at the target location.\n" R >&2
        exit 1
    fi

    # Create main project directory and subdirectories
    $mkdir -m 700 "$project_path"
    $mkdir -m 700 -p "$project_path/project_data"
    $mkdir -m 700 -p "$project_path"/{burp_project,target_data,reports,my_evaluation,gathered_info,tmp_exploits/{custom_src,payloads,bin,files2u}}
    $mkdir -m 700 -p "$project_path"/target_data/{scope,credentials,api_documents,general_data}
    $mkdir -m 700 -p "$project_path"/evidences/{0-vuln_evidences,2-payment_evidences,1-functionalP_evidences}
    $mkdir -m 700 -p "$project_path"/gathered_info/RBAC/{admins/{full_admin,other_admin_levels},users/{unauth,authed}}
    $mkdir -m 700 -p "$project_path"/gathered_info/{screen_shots,crawlers_results/katana_r,dns_results,fuzzing_results/{ffuf_r,ferox_r}}

    # Handle apex domains based on scope or create sample structure
    if [[ ${#scope_inputs[@]} -gt 0 ]]; then
        process_scope "${scope_inputs[@]}"
        create_scope_directories "$project_path"
    else
        $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/apex-domain-{A..C}.tld/subdomains/sub-{1..3}.apex.tld/{tech_stack,URLs/{waybackURLs,gathered_urls}}
    fi

    $mkdir -m 700 -p "$project_path"/gathered_info/{network/{scan_r},custom_wordlists}
    $mkdir -m 700 -p "$project_path"/reports/{templates,all_reports/No.{01..$report_count}/{evidences/{txt,image,video,payloads,exploits,test_files/files2u},edited_media,examples,encrypted,old_versions}}

    # Create placeholder files
    $touch "$project_path"/gathered_info/network/{ASNs,CIDRs,CDN,whois,hosts_on_ASN}
    $touch "$project_path"/target_data/general_data/{general_description}.txt
    $touch "$project_path"/target_data/credentials/users.txt

    # Create author.txt in each report directory
    {
        print -n -- "Report author:\nPenTester:\nCVSS_vector:\n"
        print -n -- "CVSS_score:\nOWASP_Rating_Vector:\nOWASP_Rating_score:\n"
    } > "$project_path"/reports/all_reports/No.{01..$report_count}/author.txt


    if [[ $dns_resolve -eq 1 ]]; then
        # Build list of full subdomains from scope_results
        local -a full_domains=()
        for apex sub in "${(@kv)scope_results}"; do
            local -a subs=(${=sub})
            for s in "${subs[@]}"; do
                if [[ "$s" == "*" ]]; then
                    full_domains+=("*.$apex")
                elif [[ "$s" == "@" ]]; then
                    full_domains+=("$apex")
                elif [[ "$s" == *\** ]]; then
                    local wc="${s#\*.}"
                    full_domains+=("*.${wc}.${apex}")
                else
                    full_domains+=("${s}.${apex}")
                fi
            done
        done
        colorful "Running DNS resolution for ${#full_domains} targets...\n" C >&1
        dns_resolve_domains "${full_domains[*]}" "$resolver"
    fi
    # Create the per‑project JSON using the existing project ID (no new UUID)
    create_per_project_json "$project_path" "$project_name" "$project_id" "$report_count"  "${scope_inputs[@]}"
    # Update global reports_counts to match the created count
    jq --arg pid "$project_id" --argjson rc "$report_count" '
        .npp.projects |= map(
            if .project_id == $pid then
                .reports_counts = $rc
            else . end
        )
    ' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"
    colorful "Global reports count updated to $report_count.\n" G >&1


    # Fetch note system and Trilium options from global JSON
    local note_system=$(jq -r --arg name "$project_name" '.npp.projects[] | select(.project_name == $name) | .project_notes' "$NPP_GLOBAL_FILE")
    local trilium_server=$(jq -r --arg name "$project_name" '.npp.projects[] | select(.project_name == $name) | .trilium_server' "$NPP_GLOBAL_FILE")
    local trilium_api_key=$(jq -r --arg name "$project_name" '.npp.projects[] | select(.project_name == $name) | .trilium_api_key' "$NPP_GLOBAL_FILE")
    local trilium_parent=$(jq -r --arg name "$project_name" '.npp.projects[] | select(.project_name == $name) | .trilium_parent' "$NPP_GLOBAL_FILE")

    # Create Trilium notes if note system is "t"
    if [[ "$note_system" == "t" ]]; then
        colorful "Creating Trilium notes for project '$project_name'...\n" G >&1
        # Ensure required parameters are set
        if [[ -z "$trilium_server" || -z "$trilium_api_key" || -z "$trilium_parent" ]]; then
            colorful "Warning: Trilium server, API key, or parent note not set. Skipping Trilium note creation.\n" Y >&1
        else
            # Call trilium_creator with arguments: server, token, parent note name, project name
            trilium_creator "$trilium_server" "$trilium_api_key" "$trilium_parent" "$project_name"
            if [[ $? -eq 0 ]]; then
                colorful "Trilium notes created successfully.\n" G >&1
            else
                colorful "Failed to create Trilium notes.\n" R >&2
            fi
        fi
    fi

    if [[ "$note_system" == l ]]; then
        $mkdir -m 700 -p "$project_path"/notes/
        $touch "$project_path"/notes/{observations,tmp}.md
    fi

    # Optionally show directory tree
    if [[ $tree_output -eq 0 ]]; then
        colorful "Project directory created with the following structure:\n\n" G >&1
        if [[ -n $tree ]]; then
            $tree --noreport "$project_path" -L 2
        else
            colorful "note: 'tree' is not installed; skipping tree output.\n" Y >&1
            command find "$project_path" -maxdepth 2 -print 2>/dev/null || true
        fi
    else
        colorful "Project directory created!\n" G >&1
    fi
}




function add_scope_to_existing() {

    local project_path="$1"

    # Initialize mkdir command
    local mkdir=$(command -v mkdir 2>/dev/null || echo "")
    mkdir="${${mkdir## #}%% #}"

    if [[ -z "$mkdir" ]]; then
        colorful "err: mkdir command not found. This is required.\n" R >&2
        exit 1
    fi

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
            if (( ${+existing_apex_map[$apex_domain]} )); then
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
                $mkdir -m 700 -p "$project_path"/gathered_info/apex_domains/"$apex_dir"/subdomains/"$sub_dir"/{tech_stack,URLs/{waybackURLs,gathered_urls}}

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

    if [[ $dns_resolve -eq 1 ]]; then
        # Build list of full subdomains from new_apex_map
        local -a full_domains=()
        for apex sub in "${(@kv)new_apex_map}"; do
            local -a subs=(${=sub})
            for s in "${subs[@]}"; do
                if [[ "$s" == "*" ]]; then
                    full_domains+=("*.$apex")
                elif [[ "$s" == "@" ]]; then
                    full_domains+=("$apex")
                elif [[ "$s" == *\** ]]; then
                    local wc="${s#\*.}"
                    full_domains+=("*.${wc}.${apex}")
                else
                    full_domains+=("${s}.${apex}")
                fi
            done
        done
        colorful "Running DNS resolution for new scope...\n" C >&1
        dns_resolve_domains "${full_domains[*]}" "$resolver"
    fi

    update_per_project_json_add_scope "$project_path"
    colorful "Scope addition complete.\n" G >&1
}


