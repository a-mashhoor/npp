
# Get project entry by name from global JSON
function get_project_by_name() {
    local name="$1"
    jq --arg name "$name" '.npp.projects[] | select(.project_name == $name)' "$NPP_GLOBAL_FILE" 2>/dev/null
}

function get_project_id() {
    local name="$1"
    jq -r --arg name "$name" '.npp.projects[] | select(.project_name == $name) | .project_id' "$NPP_GLOBAL_FILE" 2>/dev/null
}

# Get project path by name
function get_project_path() {
    local name="$1"
    local path=$(jq -r --arg name "$name" '.npp.projects[] | select(.project_name == $name) | .project_path' "$NPP_GLOBAL_FILE" 2>/dev/null)
    if [[ -z "$path" || "$path" == "null" ]]; then
        colorful "Project '$name' not found in global database. Run npp init -n '$name' to initialize it \n" R >&2
        return 1
    fi
    echo "$path"
}


# --- handling projects databases (json files)
function init_global_json() {
    if [[ ! -f "$NPP_GLOBAL_FILE" ]]; then
        mkdir -p "$NPP_GLOBAL_DIR"
        jq -n \
            --arg tv "$TOOL_VERSION" \
            --arg sv "$SCHEMA_VERSION" \
            --arg dv "$DATA_VERSION" \
            --arg ta "$TOOL_AUTHOR" \
            --arg su "$(whoami)" \
            --arg gu "$(git config user.name)" \
            --arg ge "$(git config user.email)" \
            '{
                npp: {
                    tool_version: $tv,
                    schema_version: $sv,
                    data_version: $dv,
                    tool_author: $ta,
                    system_username: $su,
                    github_username: $gu,
                    github_email: $ge,
                    file: "global.json",
                    projects: []
                }
            }' > "$NPP_GLOBAL_FILE"
        colorful "Initialized global JSON at $NPP_GLOBAL_FILE\n" G >&1
    fi
}

# Add new project entry to global JSON
function add_project_to_global() {
    local id="$1" name="$2" path="$3" data_file="$4"
    local timestamp=$(date -Iseconds)

    jq --arg id "$id" \
       --arg name "$name" \
       --arg path "$path" \
       --arg data "$data_file" \
       --arg time "$timestamp" \
       '.npp.projects += [{
           project_id: $id,
           project_name: $name,
           project_type_tags: [],
           bounty_platforms: {},
           project_credential_file: "",
           project_notes: "",
           trilium_server: "",
           project_local_note_dir: "",
           project_findings_evidences: "",
           pentest_info: "",
           client: "",
           RoE: "",
           reports_directory: "",
           reports_counts: 0,
           status: "active",
           project_path: $path,
           project_json_data_file: $data,
           project_description: ""
       }]' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"

    colorful "Global JSON updated with project '$name'\n" G >&1
}


# Update project status in global JSON
function update_project_status() {
    local name="$1" status="$2"
    jq --arg name "$name" --arg status "$status" '
        .npp.projects |= map(
            if .project_name == $name then
                .status = $status
            else . end
        )
    ' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"
    colorful "Project '$name' status updated to '$status'\n" G >&1
}

function update_project_archive_status() {
    local name="$1"
    local archive_path="$2"
    local timestamp=$(date -Iseconds)
    jq --arg name "$name" \
       --arg path "$archive_path" \
       --arg time "$timestamp" '
        .npp.projects |= map(
            if .project_name == $name then
                . + { archived: true, archive_path: $path, archived_at: $time }
            else . end
        )
    ' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"
    colorful "Project '$name' marked as archived.\n" G >&1
}

function create_per_project_json() {
    local project_path="$1"
    local project_name="$2"
    local project_id="$3"
    local report_count="$4"
    shift 4
    local -a scope_inputs=("$@")
    # Ensure dns_results is an associative array
    if [[ ${(t)dns_results} != "association" ]]; then
        typeset -gA dns_results=()
    fi

    # Build apex_map from scope_results (populated by process_scope)
    local -A apex_map
    for key value in "${(@)scope_results}"; do
        apex_map[$key]="$value"
    done

    local per_project_file="${project_path}/.local.data.json"
    local timestamp=$(date -Iseconds)

    local apex_json='[]'
    local apex_domain subdomains
    for apex_domain subdomains in "${(@kv)apex_map}"; do
        local domain_id=$(generate_uuid)
        local apex_dir="${apex_domain//./-}"
        local domain_file="project_data/${apex_dir}_subs.json"

        # Build subdomains array
        local sub_json='[]'
        local -a sub_array=(${=subdomains})
        for sub in "${sub_array[@]}"; do
            local subdomain_full=""
            local is_wildcard=0
            if [[ "$sub" == *\** ]]; then
                is_wildcard=1
                sub="${sub#\*.}"
                subdomain_full="*.${sub}.${apex_domain}"
            elif [[ "$sub" == "@" ]]; then
                subdomain_full="$apex_domain"
            else
                subdomain_full="${sub}.${apex_domain}"
            fi

            # --- DNS results for this subdomain ---
            local is_alive=false
            local ip_res='[]'
            local last_alive=""
            if (( ${+dns_results[$subdomain_full]} )); then
                local ips=(${=dns_results[$subdomain_full]})
                if [[ -n "$ips" ]]; then
                    is_alive=true
                    last_alive="$timestamp"
                    ip_res=$(printf '%s\n' "${ips[@]}" | jq -R . | jq -s .)
                fi
            fi

            local sub_id=$(generate_uuid)
            local sub_dir="${sub//./-}"
            local sub_path="gathered_info/apex_domains/${apex_dir}/subdomains/${sub_dir}"
            local tech_file="${sub_path}/tech_stack/technologies.json"

            sub_json=$(echo "$sub_json" | jq \
                --arg sid "$sub_id" \
                --arg subdomain "$subdomain_full" \
                --arg source "scope" \
                --arg added "$timestamp" \
                --arg last_checked "" \
                --argjson is_alive "$is_alive" \
                --arg last_alive "$last_alive" \
                --argjson working_on false \
                --argjson in_scope true \
                --argjson ip_res "$ip_res" \
                --argjson dns '{}' \
                --arg path "$sub_path" \
                --arg tech "$tech_file" \
                '. + [{
                    subdomain_id: $sid,
                    subdomain: $subdomain,
                    source: $source,
                    added_timestamp: $added,
                    last_checked_timestamp: $last_checked,
                    is_alive: $is_alive,
                    last_alive_checked: $last_alive,
                    working_on: $working_on,
                    in_scope: $in_scope,
                    ip_address_resolution: $ip_res,
                    dnsr_resolv_data: $dns,
                    path_to_sub_dir: $path,
                    technologies_file: $tech
                }]')
        done

        # --- DNS results for the apex domain itself ---
        local apex_is_alive=false
        local apex_last_living=""
        if (( ${+dns_results[$apex_domain]} )); then
            local apex_ips=(${=dns_results[$apex_domain]})
            if [[ -n "$apex_ips" ]]; then
                apex_is_alive=true
                apex_last_living="$timestamp"
            fi
        fi
        # ------------------------------------------------

        # Build apex object
        apex_json=$(echo "$apex_json" | jq \
            --arg did "$domain_id" \
            --arg domain "$apex_domain" \
            --argjson is_alive "$apex_is_alive" \
            --arg last_living "$apex_last_living" \
            --arg added "$timestamp" \
            --arg source "scope" \
            --argjson working_on false \
            --argjson in_scope true \
            --argjson is_wildcard "$is_wildcard" \
            --arg domain_file "$domain_file" \
            --argjson subs "$sub_json" \
            '. + [{
                domain_id: $did,
                domain: $domain,
                is_alive: $is_alive,
                last_living_checked: $last_living,
                added_timestamp: $added,
                source: $source,
                working_on: $working_on,
                in_scope: $in_scope,
                is_wild_card: $is_wildcard,
                domain_and_subdomains_file: $domain_file,
                subdomains: $subs
            }]')
    done

    # Write final JSON (add reports_counts field)
    jq -n \
        --arg pid "$project_id" \
        --arg ctime "$timestamp" \
        --arg mtime "$timestamp" \
        --arg scope_file "target_data/scope.txt" \
        --arg all_domains "project_data/all_domains_and_their_subs.json" \
        --argjson apex "$apex_json" \
        --argjson rc "$report_count" \
        '{
            project_id: $pid,
            creation_time: $ctime,
            modification_time: $mtime,
            scope_file_path: $scope_file,
            all_domains_and_their_subs: $all_domains,
            reports_counts: $rc,
            apex_domains: $apex
        }' > "$per_project_file"

    colorful "Per‑project JSON created: $per_project_file\n" G >&1
}

function update_per_project_json_add_scope() {

    local project_path="$1"
    local per_project_file="${project_path}/.local.data.json"
    local timestamp=$(date -Iseconds)

    # Ensure dns_results is an associative array
    if [[ ${(t)dns_results} != "association" ]]; then
        typeset -gA dns_results=()
    fi

    local -A new_apex_map
    for key value in "${(@)scope_results}"; do
        new_apex_map[$key]="$value"
    done

    local current_json=$(<"$per_project_file")

    for apex_domain subdomains in "${(@kv)new_apex_map}"; do
        local apex_dir="${apex_domain//./-}"
        local -a sub_array=(${=subdomains})

        local apex_exists=$(echo "$current_json" | jq --arg apex "$apex_domain" '.apex_domains | any(.domain == $apex)')

        if [[ "$apex_exists" == "true" ]]; then
            # Add subdomains to existing apex
            for sub in "${sub_array[@]}"; do
                local subdomain_full=""
                local is_wildcard=0
                if [[ "$sub" == *\** ]]; then
                    is_wildcard=1
                    sub="${sub#\*.}"
                    subdomain_full="*.${sub}.${apex_domain}"
                elif [[ "$sub" == "@" ]]; then
                    subdomain_full="$apex_domain"
                else
                    subdomain_full="${sub}.${apex_domain}"
                fi

                # Check if subdomain already exists
                local exists=$(echo "$current_json" | jq --arg apex "$apex_domain" --arg sub "$subdomain_full" '
                    .apex_domains[] | select(.domain == $apex) |
                    .subdomains[] | select(.subdomain == $sub) | length
                ' 2>/dev/null)

                if [[ -z "$exists" || "$exists" == "0" ]]; then
                    # --- DNS results for this new subdomain ---
                    local is_alive=false
                    local ip_res='[]'
                    local last_alive=""
                    # Safely check if key exists
                    if (( ${+dns_results[$subdomain_full]} )); then
                        local ips=(${=dns_results[$subdomain_full]})
                        if [[ -n "$ips" ]]; then
                            is_alive=true
                            last_alive="$timestamp"
                            ip_res=$(printf '%s\n' "${ips[@]}" | jq -R . | jq -s .)
                        fi
                    fi

                    local sub_id=$(generate_uuid)
                    local sub_dir="${sub//./-}"
                    local sub_path="gathered_info/apex_domains/${apex_dir}/subdomains/${sub_dir}"
                    local tech_file="${sub_path}/tech_stack/technologies.json"

                    current_json=$(echo "$current_json" | jq \
                        --arg apex "$apex_domain" \
                        --arg sid "$sub_id" \
                        --arg subdomain "$subdomain_full" \
                        --arg source "scope" \
                        --arg added "$timestamp" \
                        --arg last_checked "" \
                        --argjson is_alive "$is_alive" \
                        --arg last_alive "$last_alive" \
                        --argjson working_on false \
                        --argjson in_scope true \
                        --argjson ip_res "$ip_res" \
                        --argjson dns '{}' \
                        --arg path "$sub_path" \
                        --arg tech "$tech_file" \
                        '
                        .apex_domains |= map(
                            if .domain == $apex then
                                .subdomains += [{
                                    subdomain_id: $sid,
                                    subdomain: $subdomain,
                                    source: $source,
                                    added_timestamp: $added,
                                    last_checked_timestamp: $last_checked,
                                    is_alive: $is_alive,
                                    last_alive_checked: $last_alive,
                                    working_on: $working_on,
                                    in_scope: $in_scope,
                                    ip_address_resolution: $ip_res,
                                    dnsr_resolv_data: $dns,
                                    path_to_sub_dir: $path,
                                    technologies_file: $tech
                                }]
                            else . end
                        )
                        ')
                    colorful "      Added subdomain $subdomain_full to JSON\n" G >&1
                else
                    colorful "      Subdomain $subdomain_full already exists in JSON – skipping\n" Y >&1
                fi
            done
        else
            # Create new apex object with all subdomains
            local domain_id=$(generate_uuid)
            local domain_file="project_data/${apex_dir}_subs.json"

            local sub_json='[]'
            for sub in "${sub_array[@]}"; do
                local subdomain_full=""
                local is_wildcard=0
                if [[ "$sub" == *\** ]]; then
                    is_wildcard=1
                    sub="${sub#\*.}"
                    subdomain_full="*.${sub}.${apex_domain}"
                elif [[ "$sub" == "@" ]]; then
                    subdomain_full="$apex_domain"
                else
                    subdomain_full="${sub}.${apex_domain}"
                fi

                # --- DNS results for this new subdomain ---
                local is_alive=false
                local ip_res='[]'
                local last_alive=""
                # Safely check if key exists
                if (( ${+dns_results[$subdomain_full]} )); then
                    local ips=(${=dns_results[$subdomain_full]})
                    if [[ -n "$ips" ]]; then
                        is_alive=true
                        last_alive="$timestamp"
                        ip_res=$(printf '%s\n' "${ips[@]}" | jq -R . | jq -s .)
                    fi
                fi
                # --------------------------------------------

                local sub_id=$(generate_uuid)
                local sub_dir="${sub//./-}"
                local sub_path="gathered_info/apex_domains/${apex_dir}/subdomains/${sub_dir}"
                local tech_file="${sub_path}/tech_stack/technologies.json"

                sub_json=$(echo "$sub_json" | jq \
                    --arg sid "$sub_id" \
                    --arg subdomain "$subdomain_full" \
                    --arg source "scope" \
                    --arg added "$timestamp" \
                    --arg last_checked "" \
                    --argjson is_alive "$is_alive" \
                    --arg last_alive "$last_alive" \
                    --argjson working_on false \
                    --argjson in_scope true \
                    --argjson ip_res "$ip_res" \
                    --argjson dns '{}' \
                    --arg path "$sub_path" \
                    --arg tech "$tech_file" \
                    '. + [{
                        subdomain_id: $sid,
                        subdomain: $subdomain,
                        source: $source,
                        added_timestamp: $added,
                        last_checked_timestamp: $last_checked,
                        is_alive: $is_alive,
                        last_alive_checked: $last_alive,
                        working_on: $working_on,
                        in_scope: $in_scope,
                        ip_address_resolution: $ip_res,
                        dnsr_resolv_data: $dns,
                        path_to_sub_dir: $path,
                        technologies_file: $tech
                    }]')
            done

            # --- DNS results for the new apex domain ---
            local apex_is_alive=false
            local apex_last_living=""
            if (( ${+dns_results[$apex_domain]} )); then
                local apex_ips=(${=dns_results[$apex_domain]})
                if [[ -n "$apex_ips" ]]; then
                    apex_is_alive=true
                    apex_last_living="$timestamp"
                fi
            fi
            # --------------------------------------------

            # Add new apex object
            current_json=$(echo "$current_json" | jq \
                --arg did "$domain_id" \
                --arg domain "$apex_domain" \
                --argjson is_alive "$apex_is_alive" \
                --arg last_living "$apex_last_living" \
                --arg added "$timestamp" \
                --arg source "scope" \
                --argjson working_on false \
                --argjson in_scope true \
                --argjson is_wildcard "$is_wildcard" \
                --arg domain_file "$domain_file" \
                --argjson subs "$sub_json" \
                '.apex_domains += [{
                    domain_id: $did,
                    domain: $domain,
                    is_alive: $is_alive,
                    last_living_checked: $last_living,
                    added_timestamp: $added,
                    source: $source,
                    working_on: $working_on,
                    in_scope: $in_scope,
                    is_wild_card: $is_wildcard,
                    domain_and_subdomains_file: $domain_file,
                    subdomains: $subs
                }]')
            colorful "      Created new apex domain $apex_domain in JSON\n" G >&1
        fi
    done

    # Update modification time
    current_json=$(echo "$current_json" | jq --arg mtime "$timestamp" '.modification_time = $mtime')
    echo "$current_json" > "$per_project_file"
}


# Increment reports count in per‑project and global JSON
function increment_reports_count() {
    local project_path="$1"
    local add_count="$2"
    local per_project_file="${project_path}/.local.data.json"
    local timestamp=$(date -Iseconds)

    local project_id=$(jq -r '.project_id' "$per_project_file")

    # Update per‑project
    jq --argjson add "$add_count" --arg mtime "$timestamp" '
        .reports_counts += $add | .modification_time = $mtime
    ' "$per_project_file" > "${per_project_file}.tmp" && \
    mv "${per_project_file}.tmp" "$per_project_file"

    # Update global
    jq --arg pid "$project_id" --argjson add "$add_count" '
        .npp.projects |= map(
            if .project_id == $pid then
                .reports_counts += $add
            else . end
        )
    ' "$NPP_GLOBAL_FILE" > "${NPP_GLOBAL_FILE}.tmp" && \
    mv "${NPP_GLOBAL_FILE}.tmp" "$NPP_GLOBAL_FILE"

    colorful "Reports count increased by $add_count\n" G >&1
}


