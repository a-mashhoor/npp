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
#
#
#

setopt extendedglob
set -e

function main(){
	parse_args "$@"

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

	[[ -d $p ]] && colorful "err: directory with the same name: '$pname' already exists in the target dir\n" R >&2 && exit 1

	$mkdir -p "$p"/{burp_project,target_data,reports,my_evaluation,gathered_info,"$pname"_obsidian_valut,custom_codes,tmp_exploits}
  $mkdir -p "$p"/evidences/{0-vuln_evidences,2-payment_evidences,1-functionalP_evidences}
  $mkdir -p "$p"/gathered_info/access_levels/{admins/{full_admin,other_admin_levels},users/{unauth,authed}}
  $mkdir -p "$p"/gathered_info/{crawlers_results/katana_r,dns_results,urls,fuzzing_results/ffuf_r}
  $mkdir -p "$p"/gathered_info/{tech_stack,apex_domains,subdomains,network,custom_wordlists,wayback}
  $mkdir -p "$p"/reports/{templates,all_reports/No.{01..50}/{evidences/{txt,image,video,payloads,exploits,test_files/files_2_upload},edited_media,examples,encrypted,old_versions}}
	$mkdir "$p"/"$pname"_obsidian_valut/"$pname"

  $touch "$p"/gathered_info/{BPG,IP_ranges,CDN,whois,hosts_on_ASN}
	$touch "$p"/target_data/{users,general_description}.txt
	$touch "$p"/"$pname"_obsidian_valut/"$pname"/{users,general_description,observations,tmp}.md

	echo -en "Report author:\nPenTester:\nCVSS_vector:\n" > "$p"/reports/all_reports/No.{01..50}/author.txt
  echo -en "CVSS_score:\nOWASP_Rating_Vector:\nOWASP_Rating_score:\n" >> "$p"/reports/all_reports/No.{01..50}/author.txt

	if [[ $tr -eq 0 ]]; then
		colorful "Project directory is created with below tree structure:\n\n" G >&1
		$tree --noreport "$p"
	else
		colorful "Project directory is created!\n" G >&1
	fi
}

function build_path(){
	realpath=$(which realpath)
	realpath="${${realpath## #}%% #}"

	local name=$1
	local apath=$2
	local path

	if [[ -n $apath ]]; then
		apath=$($realpath "$apath")
		[[ -d $apath ]] && [[ ! $aptah =~ "^/*" ]] &&
			colorful "err: ABS path is not starting with '/' thus it's incorrect\n\n" R >&2 && return false

		path=$($realpath "${apath}/${name}")
		[[ -n $path ]] && echo $path && return ||
			colorful "err: It's likley you have entered incorrect abspath name\n\n" R >&2 && return false
	else
		path=$($realpath "./${name}")
		[[ -n $path ]] && echo $path && return ||
			colorful "err: You specified '/' in the name this is problematic\n\n" R >&2 && return false
	fi
}


function usage(){
	local script_name=${funcfiletrace[1]%:*}
	script_name=${${script_name:t}:r}
	echo
	colorful "simple zsh script to create and manage project needed dirs and files at the start\n" C >&1
	colorful "nnp stands for new pentest project\n" C >&1
	colorful "Author: Arshia Mashhoor\n\n" B >&1
	colorful "Usage: $script_name -p PROJECT_NAME [-a ABSOULTE_PATH]\n\n" R >&1

	colorful "-h, --help 	 	                  print to stdout this help message\n" W >&1
	colorful "-n, --name      PROJECT_NAME              takes a name for your new project\n" W >&1
	colorful "-p, --path      SELECTED_PATH	          takes a absolute path for project's parent dir\n" W >&1
	colorful "-t, --tree 				  prints the final tree structure of created dirs depends on tree tool\n\n" W >&1

	colorful "Warning: If in the location of project is already a directory\nwith the same name as the given project name the tool\n" Y >&1
	colorful "does nothing it does not overwirte the exiting directory and exits silently\n" Y >&1
	colorful "Warning: If neither of -p, --path args are provided\nthe project will be create in the current directory\n" Y >&1
	colorful "Note: The current directory will be interpreted as where the script is getting called\n" Y >&1
	colorful "Note: YOU SHOULD NOT add the project name to the absoulte path, 'path' should be the parrent directory" Y >&1
}


function parse_args(){
	zmodload zsh/zutil

	[[ ${#@} -eq 0 ]] && { usage; exit 1 }

	local -A opts
	# n --> project name p --> abs_path
	typeset -g n p t

	zparseopts -D -F -A opts -- \
		n:=n -name:=n \
		p:=p -path:=p \
		t=t -tree=t \
		h=help -help=help  || { usage; exit 1 }

	if (( ${+opts[-h]} )) || (( ${+opts[--help]} )); then
		usage
		exit 0
	fi

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

	typeset -g abs_path
	if (( ${+opts[-p]} )) || (( ${+opts[--path]} )); then
		abs_path=${opts[-p]:-${opts[--path]}}
		if [[ ! -d "$abs_path" ]]; then
			colorful "err: The provided absolute path does not exits\npriting help\n\n" R >&2 && usage && exit 1
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
