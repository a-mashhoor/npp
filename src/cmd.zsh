function cmd_init() {
    colorful "Initializing project '$init_name'...\n" G >&1

    # Read config file first if specified (command-line overrides later)
    if [[ -n "$init_config_file" ]]; then
        read_config "$init_config_file" || exit 1
    fi

    # --- Validation ---

    # 1. Project type must be one of the allowed values
    if [[ -n "$init_type" ]]; then
        if [[ ! "$init_type" =~ ^(pentest|bounty|ctf|redteam)$ ]]; then
            colorful "Error: --type must be one of: pentest, bounty, ctf, redteam\n" R >&2
            exit 1
        fi
    fi

    # 2. Bounty platforms only allowed for type 'bounty'
    if [[ "$init_type" != "bounty" && ${#init_bounty_platforms[@]} -gt 0 ]]; then
        colorful "Error: --bounty-program can only be used with project type 'bounty'\n" R >&2
        exit 1
    fi

    # 3. Client and pentest info only allowed for 'pentest' or 'redteam'
    if [[ "$init_type" != "pentest" && "$init_type" != "redteam" ]]; then
        if [[ -n "$init_client" ]]; then
            colorful "Error: --client can only be used with project type 'pentest' or 'redteam'\n" R >&2
            exit 1
        fi
        if [[ -n "$init_pentest_info" ]]; then
            colorful "Error: --pentest-info can only be used with project type 'pentest' or 'redteam'\n" R >&2
            exit 1
        fi
    fi

    # 4. Note system must be 'l' or 't'
    if [[ -n "$init_note_system" ]]; then
        if [[ ! "$init_note_system" =~ ^[lt]$ ]]; then
            colorful "Error: --note must be 'l' (local) or 't' (trilium)\n" R >&2
            exit 1
        fi
    fi

    # 5. Trilium options only allowed when note system is 't'
    if [[ "$init_note_system" != "t" ]]; then
        if [[ -n "$init_trilium_server" || -n "$init_trilium_api_key" || -n "$init_trilium_parent" ]]; then
            colorful "Error: Trilium options (--trilium-server, --trilium-api-key, --trilium-parent) can only be used when --note is 't'\n" R >&2
            exit 1
        fi
    fi

    # --- End validation ---

    # Check if project already exists in global
    if [[ -n "$(get_project_by_name "$init_name")" ]]; then
        colorful "Project '$init_name' already exists.\n" R >&2
        exit 1
    fi

    # Determine project path (default: current dir)
    local base_path="${init_path:-$PWD}"
    base_path="${base_path:A}"
    local proj_path="${base_path}/${init_name}"

    local proj_id=$(generate_uuid)
    local timestamp=$(date -Iseconds)

    # Build bounty_platforms object if provided
    local bp_json="{}"
    if [[ ${#init_bounty_platforms[@]} -gt 0 ]]; then
        for entry in "${init_bounty_platforms[@]}"; do
            local platform="${entry%%:*}"
            local urls="${entry#*:}"
            local url_list="["
            local IFS=','
            for u in ${=urls}; do
                url_list+="\"$u\","
            done
            url_list="${url_list%,}]"
            bp_json=$(echo "$bp_json" | jq --arg p "$platform" --argjson u "$url_list" '. + {($p): {"urls": $u}}')
        done
    fi

    # Add to global JSON with all metadata
    jq --arg id "$proj_id" \
       --arg name "$init_name" \
       --arg path "$proj_path" \
       --arg data "${proj_path}/.local.data.json" \
       --arg time "$timestamp" \
       --arg type "$init_type" \
       --argjson bp "$bp_json" \
       --arg client "$init_client" \
       --arg pi "$init_pentest_info" \
       --arg desc "$init_description" \
       --arg roe "$init_roe" \
       --arg git_email "$init_git_email" \
       --arg git_user "$init_git_user" \
       --arg notesys "$init_note_system" \
       --arg trilium_server "$init_trilium_server" \
       --arg trilium_key "$init_trilium_api_key" \
       --arg trilium_parent "$init_trilium_parent" \
       '.npp.projects += [{
           project_id: $id,
           project_name: $name,
           project_type_tags: (if $type != "" then [$type] else [] end),
           bounty_platforms: $bp,
           project_credential_file: "",
           project_notes: $notesys,
           trilium_server: $trilium_server,
           project_local_note_dir: "",
           project_findings_evidences: "",
           pentest_info: $pi,
           client: $client,
           RoE: $roe,
           reports_directory: "",
           reports_counts: 0,
           status: "active",
           project_path: $path,
           project_json_data_file: $data,
           project_description: $desc
       }]' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"

    colorful "Project '$init_name' initialized. Use 'npp new -p $init_name' to create directories.\n" G >&1
}

function cmd_new() {

    local proj_path=$(get_project_path "$project_name")
    if [[ -z "$proj_path" ]]; then
        exit 1
    fi
    local proj_id=$(get_project_id "$project_name") || exit 1
    creation "$proj_path" "$project_name" "$proj_id" "$report_count" "${scope_inputs[@]}"
}

function cmd_add() {
    local proj_path=$(get_project_path "$project_name") || exit 1

    # Check if the project directory actually exists (i.e., 'new' has been run)
    if [[ ! -d "$proj_path" ]]; then
        colorful "Project directory does not exist. Please run 'npp new' first.\n" R >&2
        exit 1
    fi


    if [[ $add_scope -eq 1 ]]; then
        add_scope_to_existing "$proj_path"
        # If DNS resolution requested, we would run tools here (placeholder)
        if [[ $dns_resolve -eq 1 ]]; then
            colorful "DNS resolution requested – not yet implemented.\n" Y >&1
        fi
        if [[ $advanced_dns -eq 1 ]]; then
            colorful "Advanced DNS resolution requested – not yet implemented.\n" Y >&1
        fi
    fi

    if [[ $add_reports -gt 0 ]]; then
        # Find highest existing report number
        local reports_dir="$proj_path/reports/all_reports"
        local existing=(${reports_dir}/No.*(N))
        local last=0
        if [[ ${#existing} -gt 0 ]]; then
            local last_report="${existing[-1]}"
            [[ "$last_report" =~ No\.([0-9]+) ]] && last="${match[1]#0}"
            last=$((10#$last))
        fi
        local start=$((last + 1))
        local end=$((last + add_reports))

        colorful "Adding $add_reports report directories (No.$start to No.$end)\n" G >&1
        for ((i=start; i<=end; i++)); do
            local num=$(printf "%02d" $i)
            mkdir -m 700 -p "$reports_dir/No.$num"/{evidences/{txt,image,video,payloads,exploits,test_files/files2u},edited_media,examples,encrypted,old_versions}
            {
                print -n -- "Report author:\nPenTester:\nCVSS_vector:\n"
                print -n -- "CVSS_score:\nOWASP_Rating_Vector:\nOWASP_Rating_score:\n"
            } > "$reports_dir/No.$num/author.txt"
        done
        increment_reports_count "$proj_path" "$add_reports"
    fi

    if [[ -n "$add_note" ]]; then
        local notes_dir="$proj_path/notes"
        mkdir -p "$notes_dir"
        touch "$notes_dir/$add_note.md"
        colorful "Note '$add_note.md' created.\n" G >&1
    fi

    if [[ -n "$add_user" ]]; then
        local creds_dir="$proj_path/target_data/credentials"
        mkdir -p "$creds_dir"
        local creds_file="$creds_dir/users.txt"

        if [[ "$add_user" == @* ]]; then
            # Read from file
            local user_file="${add_user#@}"
            if [[ ! -f "$user_file" ]]; then
                colorful "User file not found: $user_file\n" R >&2
                exit 1
            fi
            while IFS= read -r line; do
                line=$(trim_string "$line")
                [[ -z "$line" ]] && continue
                echo "$line" >> "$creds_file"
                colorful "Added user: $line\n" G >&1
            done < "$user_file"
        else
            # Single user entry (may contain password after colon)
            echo "$add_user" >> "$creds_file"
            colorful "Added user: $add_user\n" G >&1
        fi
    fi
}


function cmd_update() {
    local proj_path=$(get_project_path "$project_name") || exit 1
    local per_project="${proj_path}/.local.data.json"

    # Check that at least one update option was provided
    if [[ -z "$project_status" && -z "$update_apex" && -z "$update_subdomain" ]]; then
        colorful "update: no update options specified. Use --help for usage.\n" R >&2
        exit 1
    fi

    # Update project status if requested
    if [[ -n "$project_status" ]]; then
        update_project_status "$project_name" "$project_status"
    fi

    # Handle domain updates
    if [[ -n "$update_apex" || -n "$update_subdomain" ]]; then
        local timestamp=$(date -Iseconds)
        local tmp=$(mktemp)

        # If auto-alive is set, run DNS for the target domain(s)
        if [[ $auto_alive -eq 1 ]]; then
            local target_domains=()
            if [[ -n "$update_apex" ]]; then
                target_domains+=("$update_apex")
            fi
            if [[ -n "$update_subdomain" ]]; then
                target_domains+=("$update_subdomain")
            fi
            dns_resolve_domains "${target_domains[*]}" "$resolver"
        fi

        # Update apex domain
        if [[ -n "$update_apex" ]]; then
            # Verify apex exists
            local apex_exists=$(jq --arg domain "$update_apex" '.apex_domains[] | select(.domain == $domain)' "$per_project")
            if [[ -z "$apex_exists" ]]; then
                colorful "update: apex domain '$update_apex' not found in project.\n" R >&2
                exit 1
            fi

            # Prepare new values
            local new_is_alive=""
            local new_last_living=""
            if [[ $auto_alive -eq 1 ]]; then
                if (( ${+dns_results[$update_apex]} )); then
                    local ips=(${=dns_results[$update_apex]})
                    if [[ -n "$ips" ]]; then
                        new_is_alive="true"
                        new_last_living="$timestamp"
                    else
                        new_is_alive="false"
                        new_last_living=""
                    fi
                else
                    new_is_alive="false"
                    new_last_living=""
                fi
            else
                if [[ -n "$alive" ]]; then
                    new_is_alive="$alive"
                    if [[ "$alive" == "true" ]]; then
                        new_last_living="$timestamp"
                    else
                        new_last_living=""
                    fi
                fi
            fi
            local new_working_on="$working_on"
            local new_in_scope="$in_scope"

            # Build jq filter to update apex (using string arguments, convert in jq)
            jq --arg domain "$update_apex" \
               --arg is_alive "$new_is_alive" \
               --arg last_living "$new_last_living" \
               --arg working_on "$new_working_on" \
               --arg in_scope "$new_in_scope" \
               --arg mtime "$timestamp" \
               '
               .apex_domains |= map(
                   if .domain == $domain then
                       . + (if $is_alive != "" then {is_alive: ($is_alive == "true")} else {} end) +
                              (if $last_living != "" then {last_living_checked: $last_living} else {} end) +
                              (if $working_on != "" then {working_on: ($working_on == "true")} else {} end) +
                              (if $in_scope != "" then {in_scope: ($in_scope == "true")} else {} end)
                   else . end
               ) | .modification_time = $mtime
               ' "$per_project" > "$tmp" && mv "$tmp" "$per_project"
            colorful "Updated apex domain '$update_apex'.\n" G >&1
        fi

        # Update subdomain
        if [[ -n "$update_subdomain" ]]; then
            local subdomain_full="$update_subdomain"

            # Verify subdomain exists (any apex)
            local sub_exists=$(jq --arg sub "$subdomain_full" '.apex_domains[].subdomains[] | select(.subdomain == $sub)' "$per_project")
            if [[ -z "$sub_exists" ]]; then
                colorful "update: subdomain '$subdomain_full' not found in project.\n" R >&2
                exit 1
            fi

            # Prepare new values
            local new_is_alive=""
            local new_last_alive=""
            local new_ip_res=""
            if [[ $auto_alive -eq 1 ]]; then
                if (( ${+dns_results[$subdomain_full]} )); then
                    local ips=(${=dns_results[$subdomain_full]})
                    if [[ -n "$ips" ]]; then
                        new_is_alive="true"
                        new_last_alive="$timestamp"
                        new_ip_res=$(printf '%s\n' "${ips[@]}" | jq -R . | jq -s . | jq -c .)
                    else
                        new_is_alive="false"
                        new_last_alive=""
                    fi
                else
                    new_is_alive="false"
                    new_last_alive=""
                fi
            else
                if [[ -n "$alive" ]]; then
                    new_is_alive="$alive"
                    if [[ "$alive" == "true" ]]; then
                        new_last_alive="$timestamp"
                    else
                        new_last_alive=""
                    fi
                fi
            fi
            local new_working_on="$working_on"
            local new_in_scope="$in_scope"

            # Build jq filter to update subdomain
            jq --arg subdomain "$subdomain_full" \
               --arg is_alive "$new_is_alive" \
               --arg last_alive "$new_last_alive" \
               --arg ip_res "$new_ip_res" \
               --arg working_on "$new_working_on" \
               --arg in_scope "$new_in_scope" \
               --arg mtime "$timestamp" \
               '
               .apex_domains |= map(
                   .subdomains |= map(
                       if .subdomain == $subdomain then
                           . + (if $is_alive != "" then {is_alive: ($is_alive == "true")} else {} end) +
                                  (if $last_alive != "" then {last_alive_checked: $last_alive} else {} end) +
                                  (if $ip_res != "" then {ip_address_resolution: ($ip_res | fromjson)} else {} end) +
                                  (if $working_on != "" then {working_on: ($working_on == "true")} else {} end) +
                                  (if $in_scope != "" then {in_scope: ($in_scope == "true")} else {} end)
                       else . end
                   )
               ) | .modification_time = $mtime
               ' "$per_project" > "$tmp" && mv "$tmp" "$per_project"
            colorful "Updated subdomain '$update_subdomain'.\n" G >&1
        fi
    fi
}


function cmd_list() {
    # List all projects if -P was given
    if [[ $list_projects -eq 1 ]]; then
        jq -r '.npp.projects[].project_name' "$NPP_GLOBAL_FILE" 2>/dev/null | sort
        return
    fi

    local proj_path=$(get_project_path "$project_name") || exit 1
    local per_project="${proj_path}/.local.data.json"

    if [[ ! -f "$per_project" ]]; then
        colorful "Per‑project JSON not found. Run 'npp new' first.\n" R >&2
        exit 1
    fi

    # Build the jq filter condition based on --filter
    local filter_cond="true"
    if [[ -n "$filter" ]]; then
        case "$filter" in
            alive)   filter_cond='.is_alive == true' ;;
            inscope) filter_cond='.in_scope == true' ;;
            all)     filter_cond='true' ;;
        esac
    fi

    if [[ $list_all -eq 1 ]]; then
        # Show all domains and subdomains, with optional filter
        jq -r '
            .apex_domains[] | .domain as $d | .subdomains[]? | select( '"$filter_cond"' ) | "\($d) → \(.subdomain)"
        ' "$per_project"

    elif [[ $list_apex -eq 1 ]]; then
        # List only apex domains
        jq -r '
            .apex_domains[] | select( '"$filter_cond"' ) | .domain
        ' "$per_project"

    elif [[ $list_subdomains -eq 1 ]]; then
        # List only subdomains (without apex)
        jq -r '
            .apex_domains[].subdomains[]? | select( '"$filter_cond"' ) | .subdomain
        ' "$per_project"

    elif [[ $list_stats -eq 1 ]]; then
        # Show statistics (counts) respecting the filter
        local total_apex=$(jq '
            [.apex_domains[] | select( '"$filter_cond"' )] | length
        ' "$per_project")
        local total_sub=$(jq '
            [.apex_domains[].subdomains[]? | select( '"$filter_cond"' )] | length
        ' "$per_project")
        local alive=$(jq '
            [.apex_domains[].subdomains[]? | select( .is_alive == true and ('"$filter_cond"') )] | length
        ' "$per_project")
        colorful "Project: $project_name\n" G >&1
        colorful "  Apex domains: $total_apex\n" W >&1
        colorful "  Subdomains: $total_sub\n" W >&1
        colorful "  Alive subdomains: $alive\n" W >&1
    elif [[ $list_current -eq 1 ]]; then
        # Show items with working_on = true, filtered further
        jq -r '
            .apex_domains[] | .domain as $d |
            ( select(.working_on == true and ('"$filter_cond"') ) | "Currently working on apex: \($d)" ),
            ( .subdomains[]? | select(.working_on == true and ('"$filter_cond"') ) | "Currently working on: \($d) → \(.subdomain)" )
        ' "$per_project"
    fi
}


function cmd_rm() {
    local proj_path=$(get_project_path "$project_name")
    if [[ ! -n "$proj_path" ]]; then
        exit
    fi
    local per_project="${proj_path}/.local.data.json"

    # Determine what we're removing
    local removal_type=""
    local removal_target=""
    if [[ -n "$rm_apex" ]]; then
        removal_type="apex"
        removal_target="$rm_apex"
    elif [[ -n "$rm_subdomain" ]]; then
        removal_type="subdomain"
        removal_target="$rm_subdomain"
    elif [[ -n "$rm_user" ]]; then
        removal_type="user"
        removal_target="$rm_user"
    else
        removal_type="project"
        removal_target="$project_name"
    fi

    # Confirmation
    if [[ $rm_yes -eq 0 ]]; then
        colorful "WARNING: This will permanently delete " R >&2
        case "$removal_type" in
            project) colorful "the entire project '$project_name' and all its data.\n" R >&2 ;;
            apex)    colorful "the apex domain '$rm_apex' and all its subdomains.\n" R >&2 ;;
            subdomain) colorful "the subdomain '$rm_subdomain'.\n" R >&2 ;;
            user)    colorful "the user '$rm_user' from credentials.\n" R >&2 ;;
        esac
        read -q "response?Are you sure? [y/N] " || {
            echo
            colorful "Aborted.\n" Y >&2
            exit 0
        }
        echo
    fi

    case "$removal_type" in
        project)
            # Remove the entire project directory
            if [[ -d "$proj_path" ]]; then
                rm -rf "$proj_path"
                colorful "Removed project directory: $proj_path\n" G >&1
            else
                colorful "Project directory not found: $proj_path\n" Y >&1
            fi
            # Remove from global JSON
            jq --arg name "$project_name" '
                .npp.projects |= map(select(.project_name != $name))
            ' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
            mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"
            colorful "Removed project '$project_name' from global database.\n" G >&1
            ;;

        apex)
            # Check that per-project JSON exists
            if [[ ! -f "$per_project" ]]; then
                colorful "Per‑project JSON not found. Run 'npp new' first.\n" R >&2
                exit 1
            fi
            # Check if apex exists
            local apex_exists=$(jq --arg apex "$rm_apex" '.apex_domains[] | select(.domain == $apex)' "$per_project")
            if [[ -z "$apex_exists" ]]; then
                colorful "Apex domain '$rm_apex' not found in project.\n" R >&2
                exit 1
            fi
            # Remove directory
            local apex_dir="${rm_apex//./-}"
            local apex_path="$proj_path/gathered_info/apex_domains/$apex_dir"
            if [[ -d "$apex_path" ]]; then
                rm -rf "$apex_path"
                colorful "Removed apex directory: $apex_path\n" G >&1
            else
                colorful "Apex directory not found: $apex_path\n" Y >&1
            fi
            # Remove from JSON
            jq --arg apex "$rm_apex" '
                .apex_domains |= map(select(.domain != $apex))
            ' "$per_project" > "${per_project}.tmp" && mv "${per_project}.tmp" "$per_project"
            colorful "Removed apex domain '$rm_apex' from project JSON.\n" G >&1
            ;;

        subdomain)
            if [[ ! -f "$per_project" ]]; then
                colorful "Per‑project JSON not found. Run 'npp new' first.\n" R >&2
                exit 1
            fi
            # Find which apex contains this subdomain
            local apex=$(jq -r --arg sub "$rm_subdomain" '
                .apex_domains[] | select(.subdomains[]?.subdomain == $sub) | .domain
            ' "$per_project" | head -1)
            if [[ -z "$apex" ]]; then
                colorful "Subdomain '$rm_subdomain' not found in project.\n" R >&2
                exit 1
            fi
            local apex_dir="${apex//./-}"
            local sub_dir="${rm_subdomain//./-}"
            # Remove subdomain directory
            local sub_path="$proj_path/gathered_info/apex_domains/${apex_dir}/subdomains/${sub_dir}"
            if [[ -d "$sub_path" ]]; then
                rm -rf "$sub_path"
                colorful "Removed subdomain directory: $sub_path\n" G >&1
            else
                colorful "Subdomain directory not found: $sub_path\n" Y >&1
            fi
            # Remove from JSON
            jq --arg sub "$rm_subdomain" '
                .apex_domains |= map(
                    .subdomains |= map(select(.subdomain != $sub))
                )
            ' "$per_project" > "${per_project}.tmp" && mv "${per_project}.tmp" "$per_project"
            colorful "Removed subdomain '$rm_subdomain' from project JSON.\n" G >&1
            ;;

        user)
            # Remove a line from target_data/credentials/users.txt
            local creds_file="$proj_path/target_data/credentials/users.txt"
            if [[ ! -f "$creds_file" ]]; then
                colorful "Credentials file not found.\n" Y >&1
            else
                # Use grep -v to remove the line (exact match of the user line)
                grep -v -F -x "$rm_user" "$creds_file" > "${creds_file}.tmp" && mv "${creds_file}.tmp" "$creds_file"
                colorful "Removed user '$rm_user' from credentials.\n" G >&1
            fi
            ;;
    esac
}



function cmd_cd() {
    local proj_path=$(get_project_path "$project_name") || exit 1
    # Print the path so the user can cd in their shell
    echo "$proj_path"
}


function cmd_archive() {
    local proj_path=$(get_project_path "$project_name") || exit 1
    local parent="$(dirname "$proj_path")"
    local base="$(basename "$proj_path")"
    local archive_name="${base}.${archive_format}"
    local archive_path="${parent}/${archive_name}"

    archive_deps_check "$archive_format" || exit 1

    # If secure requested, check if format supports encryption
    if [[ $archive_secure -eq 1 ]]; then
        case "$archive_format" in
            tar|tar.gz|tgz|tar.bz2|tbz2)
                colorful "Error: format '$archive_format' does not support encryption.\n" R >&2
                colorful "Please use 7z, zip, or rar for encrypted archives.\n" Y >&2
                exit 1
                ;;
        esac
    fi

    # Ask for password if secure
    local password=""
    if [[ $archive_secure -eq 1 ]]; then
        read -s "?Enter password: " password
        echo
        read -s "?Confirm password: " password_confirm
        echo
        if [[ "$password" != "$password_confirm" ]]; then
            colorful "Passwords do not match.\n" R >&2
            exit 1
        fi
    fi

    # Perform archiving
    case "$archive_format" in
        tar)
            tar cf "$archive_path" -C "$parent" "$base"
            ;;
        tar.gz|tgz)
            tar czf "$archive_path" -C "$parent" "$base"
            ;;
        tar.bz2|tbz2)
            tar cjf "$archive_path" -C "$parent" "$base"
            ;;
        7z)
            if [[ $archive_secure -eq 1 ]]; then
                7z a -p"$password" "$archive_path" "$proj_path" >/dev/null
            else
                7z a "$archive_path" "$proj_path" >/dev/null
            fi
            ;;
        zip)
            if [[ $archive_secure -eq 1 ]]; then
                (cd "$parent" && zip -r -P "$password" "$archive_name" "$base") >/dev/null
            else
                (cd "$parent" && zip -r "$archive_name" "$base") >/dev/null
            fi
            ;;
        rar)
            if [[ $archive_secure -eq 1 ]]; then
                (cd "$parent" && rar a -p"$password" "$archive_name" "$base") >/dev/null
            else
                (cd "$parent" && rar a "$archive_name" "$base") >/dev/null
            fi
            ;;
    esac

    if [[ $? -eq 0 ]]; then
        colorful "Project archived to $archive_path\n" G >&1
        # Update global JSON to mark as archived
        update_project_archive_status "$project_name" "$archive_path"
    else
        colorful "Archiving failed.\n" R >&2
        exit 1
    fi
}
