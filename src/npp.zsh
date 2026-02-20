#!/usr/bin/env zsh

#
# Simple zsh script to reduce the amount of time the pentester should spend
# to create related directory and files for each new project!
#
#
# npp – new pentest project
# Author: Arshia Mashhoor
# Version: 2.0.0
# Creation: 2025-08-15
# Last Update: 2026-02-20
#
# TODO:
#   - openGPG encryption/decryption for evidences and reports
#   - backup existing project
#   - migrate old project to new structure
#   - update project names
#

# Configuration & Global Variables
NPP_GLOBAL_DIR="${HOME}/.local/share/npp"
NPP_GLOBAL_FILE="${NPP_GLOBAL_DIR}/global.json"
TOOL_VERSION="2.0.0"
SCHEMA_VERSION="0.1.0"
DATA_VERSION="0.1.0"
TOOL_AUTHOR="https://github.com/a-mashhoor"

# Results from process_scope (used by JSON creation)
typeset -g scope_results=()
typeset -gA dns_results=()

# this shit is getting to goddamn large for a simple script
# we need to dived it so i can freaking manage it
SCRIPT_DIR=${0:A:h}
source "${SCRIPT_DIR}/utils.zsh"
source "${SCRIPT_DIR}/domain-funcs.zsh"
source "${SCRIPT_DIR}/usage.zsh"
source "${SCRIPT_DIR}/scope-funcs.zsh"
source "${SCRIPT_DIR}/args.zsh"
source "${SCRIPT_DIR}/trilium.zsh"
source "${SCRIPT_DIR}/cmd.zsh"
source "${SCRIPT_DIR}/config.zsh"
source "${SCRIPT_DIR}/project-json.zsh"
source "${SCRIPT_DIR}/creation.zsh"

setopt extendedglob
set -euo pipefail

function main() {
	parse_args "$@"
	dep_check || exit 1

	init_global_json

	case "$command_mode" in
	init)
		cmd_init
		;;
	new)
		cmd_new
		;;
	add)
		cmd_add
		;;
	update)
		cmd_update
		;;
	list)
		cmd_list
		;;
	rm)
		cmd_rm
		;;
	cd)
		cmd_cd
		;;
	archive)
		cmd_archive
		;;
	*)
		colorful "Internal error: unknown command mode\n" R >&2
		exit 1
		;;
	esac
	exit 0
}

main "${@}"
