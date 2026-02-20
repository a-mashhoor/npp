typeset -g command_mode=""
typeset -g project_name=""
typeset -g scope_inputs=()
typeset -g dns_resolve=0
typeset -g advanced_dns=0
typeset -g report_count=20
typeset -g report_template=""
typeset -g add_reports=0
typeset -g add_user=""
typeset -g add_note=""
typeset -g add_scope=0
typeset -g project_status=""
typeset -g update_apex=""
typeset -g update_subdomain=""
typeset -g alive=""
typeset -g working_on=""
typeset -g in_scope=""
typeset -g list_all=0 list_apex=0 list_subdomains=0 list_stats=0 list_current=0
typeset -g filter=""
typeset -g archive_format="tar.gz"
typeset -g archive_secure=0
typeset -g init_name="" init_path="" init_type="" init_bounty_platforms=()
typeset -g init_client="" init_pentest_info="" init_description="" init_roe=""
typeset -g init_git_email="" init_git_user="" init_note_system="local"
typeset -g init_trilium_server="" init_trilium_api_key="" init_trilium_parent=""
typeset -g init_config_file=""
typeset -ga add_user_array
typeset -g resolver=""
typeset -ga resolver_array
typeset -gA dns_results=()
typeset -g list_all=0 list_apex=0 list_subdomains=0 list_stats=0 list_current=0 list_projects=0
typeset -g auto_alive=0
typeset -g auto_inscope=0
typeset -g rm_apex=""
typeset -g rm_subdomain=""
typeset -g rm_user=""
typeset -g rm_yes=0

function parse_args(){
    zmodload zsh/zutil

    # Global options (no command required)
    [[ ${#@} -eq 0 ]] && { usage; exit 1 }

    # Check for global flags (--help, --version, --check-config)
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --version|-v)
            echo "npp version $TOOL_VERSION"
            exit 0
            ;;
        --check-config)
            if [[ -n "$2" && "$2" != -* ]]; then
                validate_config "$2"
                exit $?
            else
                colorful "Error: --check-config requires a filename\n" R >&2
                exit 1
            fi
            ;;
    esac

    # First argument must be a command
    local cmd="$1"
    shift

    case "$cmd" in
        init)
            parse_init "$@"
            ;;
        new)
            parse_new "$@"
            ;;
        add)
            parse_add "$@"
            ;;
        update)
            parse_update "$@"
            ;;
        list)
            parse_list "$@"
            ;;
        rm)
            parse_rm "$@"
            ;;
        cd)
            parse_cd "$@"
            ;;
        archive)
            parse_archive "$@"
            ;;
        *)
            colorful "Unknown command: $cmd\n" R >&2
            usage
            exit 1
            ;;
    esac
}


function parse_init() {
    local -A opts
    # Local arrays for options that take arguments
    typeset -ga init_name_array init_path_array init_type_array init_bounty_platforms_array
    typeset -ga init_client_array init_pentest_info_array init_description_array init_roe_array
    typeset -ga init_git_email_array init_git_user_array init_note_system_array
    typeset -ga init_trilium_server_array init_trilium_api_key_array init_trilium_parent_array
    typeset -ga init_config_file_array

    {zparseopts -D -F -A opts -- \
        n:=init_name_array -name:=init_name_array \
        P:=init_path_array -path:=init_path_array \
        t:=init_type_array -type:=init_type_array \
        bp:=init_bounty_platforms_array -bounty-program:=init_bounty_platforms_array \
        cl:=init_client_array -client:=init_client_array \
        pi:=init_pentest_info_array -pentest-info:=init_pentest_info_array \
        d:=init_description_array -description:=init_description_array \
        -gitcreds \
        r:=init_roe_array -roe:=init_roe_array \
        -git-email:=init_git_email_array \
        -git-user:=init_git_user_array \
        -note:=init_note_system_array \
        -trilium-server:=init_trilium_server_array \
        -trilium-api-key:=init_trilium_api_key_array \
        -trilium-parent:=init_trilium_parent_array \
        c:=init_config_file_array -config:=init_config_file_array \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_init
        exit 1
    }



    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_init
        exit 0
    fi

    # Extract values (last occurrence wins), defaulting to empty string if not provided
    init_name="${init_name_array[-1]:-}"
    init_path="${init_path_array[-1]:-}"
    init_type="${init_type_array[-1]:-}"
    init_bounty_platforms=("${init_bounty_platforms_array[@]}")
    init_client="${init_client_array[-1]:-}"
    init_pentest_info="${init_pentest_info_array[-1]:-}"
    init_description="${init_description_array[-1]:-}"
    init_roe="${init_roe_array[-1]:-}"
    init_git_email="${init_git_email_array[-1]:-}"
    init_git_user="${init_git_user_array[-1]:-}"
    init_note_system="${init_note_system_array[-1]:-}"
    init_trilium_server="${init_trilium_server_array[-1]:-}"
    init_trilium_api_key="${init_trilium_api_key_array[-1]:-}"
    init_trilium_parent="${init_trilium_parent_array[-1]:-}"
    init_config_file="${init_config_file_array[-1]:-}"

    # Validate required
    if [[ -z "$init_name" ]]; then
        colorful "init: --name is required\n" R >&2
        usage_init
        exit 1
    fi

    # After extracting all arrays, process bounty platforms
    if (( ${#init_bounty_platforms_array} )); then
        local -a filtered_bp=()
        for item in "${init_bounty_platforms_array[@]}"; do
            # Keep only items that do NOT start with '-'
            if [[ "$item" != -* ]]; then
                filtered_bp+=("$item")
            fi
        done
        init_bounty_platforms=("${filtered_bp[@]}")
    else
        init_bounty_platforms=()
    fi

    # Interactive gitcreds
    if (( ${+opts[--gitcreds]} )) || (( ${+opts[-gitcreds]} )); then
        read "?GitHub email: " init_git_email
        read "?GitHub username: " init_git_user
    fi

    typeset -g command_mode="init"
}


function parse_scope_input() {
    local arg="$1"
    typeset -ga scope_inputs=()
    if [[ "$arg" == @- ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim_string "$line")
            [[ -n "$line" ]] && scope_inputs+=("$line")
        done
    elif [[ "$arg" == @* ]]; then
        local file="${arg#@}"
        if [[ ! -f "$file" ]]; then
            colorful "Scope file not found: $file\n" R >&2
            exit 1
        fi
        while IFS= read -r line || [[ -n "$line" ]]; do
            line=$(trim_string "$line")
            [[ -n "$line" ]] && scope_inputs+=("$line")
        done < "$file"
    else
        # Direct arguments: the user passed multiple -s options, but zparseopts collects them in an array.
        # We need to flatten them. In parse_new, we set scope_inputs as array from opts, but it's actually a list of values.
        # Better: after zparseopts, scope_inputs is an array like ( -s value1 -s value2 ... ). We need to extract values.
        # Let's handle that in parse_new: we'll use ${scope_inputs[@]} but we need to strip the -s flags.
        # Instead, we'll collect all arguments after -s that are not options. For simplicity, we'll require that -s is used only once with a list or file.
        # But if user wants multiple domains, they can quote them: -s "dom1 dom2". So we'll treat the last arg as the list.
        # For now, we'll just take the last argument as the list of space-separated domains.
        scope_inputs=(${=arg})
    fi

}

function parse_new() {
    local -A opts
    typeset -ga project_name_array scope_raw_array
    typeset -ga report_count_array report_template_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        s:=scope_raw_array -scope:=scope_raw_array \
        dr=dr -dns-resolvd=dr \
        resolver:=resolver_array -resolver:=resolver_array \
        rc:=report_count_array -report-count:=report_count_array \
        rt:=report_template_array -report-template:=report_template_array \
        t=tree -tree=tree \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_new
        exit 1
    }



    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_new
        exit 0
    fi

    # Extract values, default to empty if not provided
    project_name="${project_name_array[-1]:-}"
    local scope_arg="${scope_raw_array[-1]:-}"
    if [[ -n "$scope_arg" ]]; then
        parse_scope_input "$scope_arg"
    fi
    report_count="${report_count_array[-1]:-20}"
    report_template="${report_template_array[-1]:-}"

    typeset -g dns_resolve=$(( ${+opts[-dr]} || ${+opts[--dns-resolvd]} ))
    typeset -g tree_output=$(( ${+opts[-t]} ? 0 : 1 ))

    if (( ${#resolver_array} )) ;then
        if (( ${+opts[-dr]} )); then
            resolver="${resolver_array[-1]:-}"
        else
            colorful "resolver should only be used with -dr option\n" R >&2
            exit 1
        fi
    fi


    if [[ -z "$project_name" ]]; then
        colorful "new: --project is required\n" R >&2
        usage_new
        exit 1
    fi

    typeset -g command_mode="new"
}

function parse_add() {
    local -A opts
    typeset -ga project_name_array scope_raw_array
    typeset -ga add_reports_array add_note_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        as=as -add-scope=as \
        s:=scope_raw_array -scope:=scope_raw_array \
        dr=dr -dns-resolvd=dr \
        resolver:=resolver_array -resolver:=resolver_array \
        ar:=add_reports_array -add-reports:=add_reports_array \
        an:=add_note_array -add-note:=add_note_array \
        au:=add_user_array -add-user:=add_user_array \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_add
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_add
        exit 0
    fi

    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "add: --project is required\n" R >&2
        usage_add
        exit 1
    fi

     # Handle scope if -as given
     if (( ${+opts[-s]} )) && (( ! ${+opts[-as]} )); then
            colorful "add: --socpe in add requires --add-scope\n" R >&2
            usage_add
            exit 1
    fi

    # Handle scope if -as given
    if (( ${+opts[-as]} )); then
        add_scope=1
        local scope_arg="${scope_raw_array[-1]:-}"
        if [[ -n "$scope_arg" ]]; then
            parse_scope_input "$scope_arg"
        else
            colorful "add: --add-scope requires --scope\n" R >&2
            usage_add
            exit 1
        fi
    fi

    typeset -g dns_resolve=$(( ${+opts[-dr]} || ${+opts[--dns-resolvd]} ))
    typeset -g advanced_dns=$(( ${+opts[-adr]} || ${+opts[--advanced-dns-resolvd]} ))

    add_reports="${add_reports_array[-1]:-0}"
    if (( ${+opts[-ar]} )); then
        if [[ ! "$add_reports" =~ ^[0-9]+$ ]] || [[ $add_reports -le 0 ]]; then
            colorful "add: --add-reports must be a positive integer\n" R >&2
            exit 1
        fi
    fi

    add_note="${add_note_array[-1]:-}"

    if (( ${#add_user_array} )); then
        add_user="${add_user_array[-1]}"
    fi

    if (( ${#resolver_array} )) ;then
        if (( ${+opts[-dr]} )); then
            resolver="${resolver_array[-1]:-}"
        else
            colorful "resolver should only be used with -dr option\n" R >&2
            exit 1
        fi
    fi


    typeset -g command_mode="add"
}

function parse_update() {
    local -A opts
    typeset -ga project_name_array project_status_array
    typeset -ga update_apex_array update_subdomain_array
    typeset -ga alive_array working_on_array in_scope_array
    typeset -ga resolver_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        -status:=project_status_array \
        ux:=update_apex_array -update-apex:=update_apex_array \
        us:=update_subdomain_array -update-subdomain:=update_subdomain_array \
        -alive:=alive_array \
        -workingon:=working_on_array \
        -inscope:=in_scope_array \
        -auto-alive=auto_alive \
        -auto-inscope=auto_inscope \
        dr=dr -dns-resolvd=dr \
        resolver:=resolver_array -resolver:=resolver_array \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_update
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_update
        exit 0
    fi

    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "update: --project is required\n" R >&2
        usage_update
        exit 1
    fi

    project_status="${project_status_array[-1]:-}"
    update_apex="${update_apex_array[-1]:-}"
    update_subdomain="${update_subdomain_array[-1]:-}"
    alive="${alive_array[-1]:-}"
    working_on="${working_on_array[-1]:-}"
    in_scope="${in_scope_array[-1]:-}"
    resolver="${resolver_array[-1]:-}"

    # Set flags – these are global, already declared at top of args.zsh
    auto_alive=0
    auto_inscope=0
    if (( ${+opts[--auto-alive]} )); then
        auto_alive=1
    fi
    if (( ${+opts[--auto-inscope]} )); then
        auto_inscope=1
    fi
    dns_resolve=$(( ${+opts[-dr]} || ${+opts[--dns-resolvd]} ))

    # Validate status if provided
    if [[ -n "$project_status" ]]; then
        if [[ "$project_status" != "active" && "$project_status" != "completed" && "$project_status" != "archived" ]]; then
            colorful "update: --status must be one of: active, completed, archived\n" R >&2
            exit 1
        fi
    fi

    # For apex/subdomain updates, we need at least one attribute or auto-flag
    if [[ -n "$update_apex" || -n "$update_subdomain" ]]; then
        local has_attr=0
        [[ -n "$alive" ]] && has_attr=1
        [[ -n "$working_on" ]] && has_attr=1
        [[ -n "$in_scope" ]] && has_attr=1
        [[ $auto_alive -eq 1 ]] && has_attr=1
        [[ $auto_inscope -eq 1 ]] && has_attr=1
        if [[ $has_attr -eq 0 ]]; then
            colorful "update: when updating a domain, specify at least one of --alive, --workingon, --inscope, --auto-alive, --auto-inscope\n" R >&2
            exit 1
        fi
        # Validate boolean values for manual ones
        for attr in alive working_on in_scope; do
            local val="${(P)attr}"
            if [[ -n "$val" && "$val" != "true" && "$val" != "false" ]]; then
                colorful "update: --$attr must be true or false\n" R >&2
                exit 1
            fi
        done
        # If auto-alive given, ensure DNS resolution is requested
        if [[ $auto_alive -eq 1 && $dns_resolve -eq 0 ]]; then
            colorful "update: --auto-alive requires --dns-resolvd\n" R >&2
            exit 1
        fi
    fi

    typeset -g command_mode="update"
}


function parse_list() {
    local -A opts
    typeset -ga project_name_array filter_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        P=projects -projects=projects \
        a=all -all=all \
        ax=apex -apex=apex \
        sd=subdomains -subdomains=subdomains \
        cs=stats -current-stats=stats \
        c=current -current=current \
        f:=filter_array -filter:=filter_array \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_list
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_list
        exit 0
    fi

    # Handle -P (list all projects)
    if (( ${+opts[-P]} )); then
        if (( ${+opts[-p]} )); then
            colorful "list: -P and -p are mutually exclusive\n" R >&2
            usage_list
            exit 1
        fi
        if (( ${+opts[-a]} || ${+opts[-ax]} || ${+opts[-sd]} || ${+opts[-cs]} || ${+opts[-c]} )); then
            colorful "list: -P cannot be combined with display options\n" R >&2
            usage_list
            exit 1
        fi
        if (( ${#filter_array} )); then
            colorful "list: -P cannot be combined with --filter\n" R >&2
            usage_list
            exit 1
        fi
        typeset -g list_projects=1
        typeset -g command_mode="list"
        return
    fi

    # Otherwise, require -p
    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "list: --project is required (or use -P to list all projects)\n" R >&2
        usage_list
        exit 1
    fi

    # Count mutually exclusive display options
    local mode_count=0
    (( ${+opts[-a]} )) && mode_count=$((mode_count+1))
    (( ${+opts[-ax]} )) && mode_count=$((mode_count+1))
    (( ${+opts[-sd]} )) && mode_count=$((mode_count+1))
    (( ${+opts[-cs]} )) && mode_count=$((mode_count+1))
    (( ${+opts[-c]} )) && mode_count=$((mode_count+1))

    if [[ $mode_count -eq 0 ]]; then
        colorful "list: you must specify one of -a, -ax, -sd, -cs, -c\n" R >&2
        usage_list
        exit 1
    elif [[ $mode_count -gt 1 ]]; then
        colorful "list: cannot specify multiple display options\n" R >&2
        exit 1
    fi

    list_all=$(( ${+opts[-a]} ))
    list_apex=$(( ${+opts[-ax]} ))
    list_subdomains=$(( ${+opts[-sd]} ))
    list_stats=$(( ${+opts[-cs]} ))
    list_current=$(( ${+opts[-c]} ))
    filter="${filter_array[-1]:-}"

    if [[ -n "$filter" ]]; then
        if [[ "$filter" != "alive" && "$filter" != "inscope" && "$filter" != "all" ]]; then
            colorful "list: --filter must be one of: alive, inscope, all\n" R >&2
            exit 1
        fi
    fi

    typeset -g command_mode="list"
}

function parse_rm() {
    local -A opts
    typeset -ga project_name_array
    typeset -ga rm_apex_array rm_subdomain_array rm_user_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        ax:=rm_apex_array -apex:=rm_apex_array \
        su:=rm_subdomain_array -subdomain:=rm_subdomain_array \
        u:=rm_user_array -user:=rm_user_array \
        y=yes -yes=yes \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_rm
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_rm
        exit 0
    fi

    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "rm: --project is required\n" R >&2
        usage_rm
        exit 1
    fi

    rm_apex="${rm_apex_array[-1]:-}"
    rm_subdomain="${rm_subdomain_array[-1]:-}"
    rm_user="${rm_user_array[-1]:-}"
    rm_yes=$(( ${+opts[-y]} || ${+opts[--yes]} ))

    # Ensure that at least one of the removal targets is specified
    if [[ -z "$rm_apex" && -z "$rm_subdomain" && -z "$rm_user" ]]; then
        # No specific target: remove entire project
        # This is allowed; we'll just use the project name.
        # Nothing to set here.
        :
    elif [[ -n "$rm_apex" && ( -n "$rm_subdomain" || -n "$rm_user" ) ]]; then
        colorful "rm: cannot combine --apex with --subdomain or --user\n" R >&2
        usage_rm
        exit 1
    elif [[ -n "$rm_subdomain" && -n "$rm_user" ]]; then
        colorful "rm: cannot combine --subdomain and --user\n" R >&2
        usage_rm
        exit 1
    fi

    typeset -g command_mode="rm"
}

function parse_cd() {
    local -A opts
    typeset -ga project_name_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        h=help -help=help

    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_cd
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_cd
        exit 0
    fi

    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "cd: --project is required\n" R >&2
        usage_cd
        exit 1
    fi

    typeset -g command_mode="cd"
}

function parse_archive() {
    local -A opts
    typeset -ga project_name_array archive_format_array

    {zparseopts -D -F -A opts -- \
        p:=project_name_array -project:=project_name_array \
        f:=archive_format_array -format:=archive_format_array \
        s=secure -secured=secure \
        h=help -help=help
    } 2>/dev/null || {
        colorful "Error: invalid option or missing argument\n" R >&2
        usage_archive
        exit 1
    }

    if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
        usage_archive
        exit 0
    fi

    project_name="${project_name_array[-1]:-}"
    if [[ -z "$project_name" ]]; then
        colorful "archive: --project is required\n" R >&2
        usage_archive
        exit 1
    fi

    archive_format="${archive_format_array[-1]:-tar.gz}"
    # Validate format
    case "$archive_format" in
        tar|tar.gz|tgz|tar.bz2|tbz2|7z|zip|rar) ;;
        *)
            colorful "archive: unsupported format '$archive_format'. Use: tar, tar.gz, tar.bz2, 7z, zip, rar\n" R >&2
            exit 1
            ;;
    esac

    archive_secure=$(( ${+opts[-s]} || ${+opts[--secured]} ))
    typeset -g command_mode="archive"
}

