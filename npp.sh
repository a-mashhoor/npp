#!/usr/bin/env zsh

#
#
#
# Simple zsh script to reduce the amount of time the pentester should spend
# to create related directory and files for each new project!
# Author: Arshia Mashhoor
# Version: 0.1.1
# creation data: 2025 aug 15
# Last Update: 2025 aug 24
#
#
# in the next version I will add support for openGPG encryption + decryption
# Also Option to determine the number of report directories to create
# Also the abalitiy to backup an existing project
# the ability to move all of existing directories and files of old project to new project and
# adding a number of new report directories (to expand)
# Adding a way to set the number of created apex domains or giving a list of scope
# detect the apex domains based on the scope list and each corealed subdomains
#
#

setopt extendedglob
#set -x
set -e

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
  $mkdir -m 700 -p "$p"/gathered_info/apex_domains/apex-domain-{A..C}.tld/subdomains/sub-{1..3}.apex.tld/{tech_stack,URLs/{waybackURLs,gathered_urls}}
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

    if [[ $add_reports -gt 0 ]]; then
        local start_num=$((last_report_num + 1))
        local end_num=$((last_report_num + add_reports))

        colorful "Adding $add_reports new report directories (No.$start_num to No.$end_num)\n" G >&1

        mkdir=$(which mkdir)
        mkdir="${${mkdir## #}%% #}"

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

  realpath=$(which realpath)
  realpath="${${realpath## #}%% #}"
  uname=$(which uname)
  uname="${${uname## $}%% #}"

  local name=$1
  local apath=$2
  local path

  if [[ "$($uname)" == "Darwin" ]] || command -v sw_vers >/dev/null 2>&1; then
    if [[ -n $apath ]]; then
      base=$(cd "$apath" && pwd -P) || return 1
    else
      base=$PWD
    fi
    print -r -- "${base%/}/$name"
  fi

  if [[ "$name" =~ "/" ]]; then
    colorful "err: Project name contains '/' which is problematic\n\n" R >&2
    return 1
  fi

  if [[ -n $apath ]]; then
    if [[ ! -d "$apath" ]]; then
      colorful "err: The provided path does not exist or is not a directory\n\n" R >&2
      return 1
    fi

    if command -v $realpath >/dev/null 2>&1; then
      if $realpath --help 2>/dev/null | grep -q -- "--canonicalize-missing"; then
        apath=$($realpath --canonicalize-missing "$apath" 2>/dev/null)
      elif $realpath --help 2>/dev/null | grep -q -- "-m"; then
        apath=$($realpath -m "$apath" 2>/dev/null)
      else
        apath=$($realpath "$apath" 2>/dev/null)
      fi
    fi

    if [[ -z "$apath" ]] || [[ ! "$apath" =~ "^/" ]]; then
      apath="${apath:A}"
    fi

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
  colorful "    $script_name -n PROJECT_NAME [-p ABSOLUTE_PATH] [-rc REPORT_COUNT] [-t]\n\n" W >&1
  colorful "  Update existing project:\n" W >&1
  colorful "    $script_name -up PROJECT_PATH [-ar ADD_REPORTS]\n" W >&1
  colorful "    $script_name -dn PROJECT_NAME [-ar ADD_REPORTS]\n\n" W >&1

  colorful "Options:\n" W >&1
  colorful "  -h, --help                         print to stdout this help message\n" W >&1
  colorful "  -n, --name      PROJECT_NAME       takes a name for your new project\n" W >&1
  colorful "  -p, --path      SELECTED_PATH      takes an absolute path for project's parent dir\n" W >&1
  colorful "  -rc, --report-count REPORT_COUNT   number of report directories to create (default: 20)\n" W >&1
  colorful "  -t, --tree                         prints the final tree structure of created dirs\n" W >&1
  colorful "  -up, --update-project PROJECT_PATH update an existing project at given path\n" W >&1
  colorful "  -dn, --directory-name PROJECT_NAME update an existing project by name in current dir\n" W >&1
  colorful "  -ar, --add-reports ADD_REPORTS     number of additional report directories to add\n\n" W >&1

  colorful "Examples:\n" Y >&1
  colorful "  Create new project with 30 reports:\n" Y >&1
  colorful "    $script_name -n myproject -rc 30\n\n" Y >&1
  colorful "  Update existing project by path, add 10 more reports:\n" Y >&1
  colorful "    $script_name -up /path/to/project -ar 10\n\n" Y >&1
  colorful "  Update existing project by name in current directory, add 5 more reports:\n" Y >&1
  colorful "    $script_name -dn myproject -ar 5\n\n" Y >&1

  colorful "Notes:\n" Y >&1
  colorful "  - For new projects, -p must be an absolute path\n" Y >&1
  colorful "  - For updating, -up accepts both absolute and relative paths\n" Y >&1
  colorful "  - -dn looks for the project in the current directory\n" Y >&1
  colorful "  - When updating, the script will find the highest existing report number\n" Y >&1
  colorful "    and add new ones sequentially\n" Y >&1

}


function parse_args(){
  zmodload zsh/zutil

  [[ ${#@} -eq 0 ]] && { usage; exit 1 }

  local -A opts
  # n --> project name p --> abs_path
  typeset -g n p t rc up dn ar

  zparseopts -D -F -A opts -- \
    n:=n -name:=n \
    p:=p -path:=p \
    t=t -tree=t \
    rc:=rc -report-count:=rc \
    up:=up -update-project:=up \
    dn:=dn -directory-name:=dn \
    ar:=ar -add-reports:=ar \
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
  if [[ -n $up ]] || [[ -n $dn ]]; then
      update_mode=1
  fi


  if [[ $update_mode -eq 1 ]]; then

    #typeset -g existing_project_path="$up"
    #typeset -g existing_project_name="$dn"
    #
    typeset -g existing_project_path="${up[-1]}"
    typeset -g existing_project_name="${dn[-1]}"

    typeset -g add_reports=0
    if [[ ${#ar} -gt 0 ]]; then
        # Use unquoted regex pattern
        if [[ ${ar[-1]} =~ ^[0-9]+$ ]]; then
            add_reports=${ar[-1]}
        else
            colorful "err: -ar/--add-reports must be a positive integer\n" R >&2
            exit 1
        fi
    fi

    typeset -g tr=1
    if (( ${+opts[-t]} )) || (( ${+opts[--tree]} )); then
        tr=0
    fi

    # We need either -up or -dn
    if [[ -z $up ]] && [[ -z $dn ]]; then
        colorful "err: Update mode requires either -up or -dn option\n" R >&2
        usage
        exit 1
    fi
  else

    typeset -g tr=1
    if (( ${+opts[-t]} )) || (( ${+opts[--tree]} )); then
      tr=0
    fi

    typeset -g pname="${opts[-n]:-${opts[--name]}}"
    if [[ -z "$pname" ]]; then
      colorful "Project name is required!" R >&2
      vared -p "enter project name: " -c pname
      [[ -z $pname ]] && colorful "err: no project name provided exiting\nprinting help\n\n" R >&2 && usage && exit 3
    fi

    if [[ "$pname" == */* ]]; then
      colorful "err: project name must not contain '/'\n" R >&2
      exit 2
    fi


    typeset -g report_count=11
    if [[ ${#rc} -gt 0 ]]; then
        if [[ ${rc[-1]} =~ ^[0-9]+$ ]] && [[ ${rc[-1]} -gt 0 ]]; then
            report_count=${rc[-1]}
        else
            colorful "err: -rc/--report-count must be a positive integer\n" R >&2
            exit 1
        fi
    fi

    typeset -g abs_path
    if (( ${+opts[-p]} )) || (( ${+opts[--path]} )); then
      abs_path=${opts[-p]:-${opts[--path]}}
      if [[ "$abs_path" != /* ]]; then
        colorful "err: The provided path must be absolute (start with '/')\n\n" R >&2
        usage
        exit 1
      fi
      if [[ ! -d "$abs_path" ]]; then
        colorful "err: The provided absolute path does not exits\npriting help\n\n" R >&2 && usage && exit 1
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
