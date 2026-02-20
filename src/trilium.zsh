function trilium_creator() {

	typeset -g TRILIUM_SERVER=${1:-"http://localhost:8080"}
	typeset -g API_TOKEN=${2:-"not-going-to-push-my-key-to-github-bruh"}
	typeset -g AUTH_H="authorization: $API_TOKEN"
	typeset -g PARENT_NOTE_NAME=${3:-"null-team-projects"}

	# Child notes to create under each target project note
	typeset -ga CHILD_TITLES=(
		"notes_tmp"
		"observations"
	)

	TARGET_NAME="$4"

	if [[ -z "$TARGET_NAME" ]]; then
		echo "Err: no target name is specifed <target-name>"
		exit 1
	fi

	isup

	echo "Searching for parent note '$PARENT_NOTE_NAME'..."
	pni=$(get_note_id_by_title "$PARENT_NOTE_NAME" 0 "" "single")

	if [[ -z "$pni" || "$pni" == "null" ]]; then
		echo "Error: Parent note not found."
		exit 1
	fi
	echo "Parent note ID: $pni"

	ex "$pni"

}

function ex() {
	pid="$1"

	nid=$(get_note_id_by_title "$TARGET_NAME" 1 "$pid" "single")
	# if nid note title is the exact match with the target name continue
	# if not get all of the notes in the parrent note that the search returns to us
	# check in them that if we have an exact match between the titles if yes continute if not create
	#
	local prjnote=""
	getnidURL="$TRILIUM_SERVER/etapi/notes/$nid"
	prjnote=$(curl -s --url "$getnidURL" -H "$AUTH_H")
	local var=""
	if [[ $(echo "$prjnote" | jq -r '."title"') == "$TARGET_NAME" ]]; then
		var=$(echo "$prjnote" | jq -r '."parentNoteIds"[0]')
	else
		allnids=$(get_note_id_by_title "$TARGET_NAME" 2 "$pid" "list")
		nid=$(echo "$allnids" | jq -r --arg target "$TARGET_NAME" '.results[] | select(.title == $target) | .noteId')
		if [[ -n "$nid" ]]; then
			prjnote=$(curl -s --url "$getnidURL" -H "$AUTH_H")
			var=$(echo "$prjnote" | jq -r '."parentNoteIds"[0]')
		fi
	fi

	if [[ -n $nid ]] && [[ -n $var ]] && [[ $var == "$pid" ]]; then
		if $(echo "$prjnote" | jq --arg t "$TARGET_NAME" '."title"==$t and ."childNoteIds"? and (."childNoteIds"  | type == "array" and length > 0)'); then
			echo "exists with notes in it"
			exit 1
		elif $(echo "$prjnote" | jq --arg t "$TARGET_NAME" '."title"==$t and ."childNoteIds"? and (."childNoteIds"  | type == "array" and length == 0 )'); then
			echo "project exists and it is empty using it"
			create_notes "$nid"
			exit
		fi
	else
		echo "target does not exists proceeding"
		prjnid=$(create_note "$pid" "$TARGET_NAME" "book" 1)
		create_notes "$prjnid"
		exit
	fi
}

function create_notes() {
	prid="$1"
	for cn in "${CHILD_TITLES[@]}"; do
		create_note "$prid" "$cn" "text" 0 >/dev/null
	done
}

function isup() {
	local hs=$(curl --get -s -o /dev/null -w "%{http_code}" \
		-H "Authorization: $API_TOKEN" \
		--url "$TRILIUM_SERVER/etapi/app-info")
	[[ $hs -ne 200 ]] && {echo "trilium is down"
	exit 1}
}

function urlencode() {
	local string="$1"
	local strlen=${#string}
	local encoded=""
	for ((pos = 0; pos < strlen; pos++)); do
		c=${string:$pos:1}
		case "$c" in
		[-_.~a-zA-Z0-9]) encoded+="$c" ;;
		*) printf -v encoded '%s%%%02X' "$encoded" "'$c" ;;
		esac
	done
	echo "$encoded"
}

function get_note_id_by_title() {
	local title="$1"
	mode="$2"
	anc="$3"
	opt="$4"
	local encoded_title=$(urlencode "$title")
	local URL=""

	if [[ $mode -eq 0 ]]; then
		URL="$TRILIUM_SERVER/etapi/notes?search=\"$encoded_title\""
	elif [[ $mode -eq 1 ]]; then
		URL="$TRILIUM_SERVER/etapi/notes?search=\"$encoded_title\"&fastSearch=true&ancestorNoteId=$anc&ancestorDepth=eq1&orderBy=title&orderDirection=asc&limit=1"
	elif [[ "$mode" -eq 2 ]]; then
		URL="$TRILIUM_SERVER/etapi/notes?search=\"$encoded_title\"&fastSearch=true&ancestorNoteId=$anc&ancestorDepth=eq1&orderBy=title&orderDirection=asc"
	fi

	local res=$(curl -s --request GET --url "$URL" -H "$AUTH_H")

	if [[ "$opt" == "single" ]]; then
		echo $res | jq -r '."results".[0]."noteId"' 2>/dev/null
	elif [[ "$opt" == "list" ]]; then
		echo -n "$res"
	else
		echo "err"
	fi
}

# allowed types are: text, code, render, file, image, search, relationMap, book,
# noteMap, mermaid, canvas, webView, launcher, doc, contentWidget, mindMap, aiChat
# Create a new note under a parent
function create_note() {
	local ismain=$4
	local pid="$1"
	local tt="$2"
	local ty="${3:-book}"

	local AURL="$TRILIUM_SERVER/etapi/attributes"
	local CURL="$TRILIUM_SERVER/etapi/create-note"

	local resp=$(curl -s --variable tt="$tt" --variable pid="$pid" --variable ty="$ty" --url "$CURL" \
		-H "$AUTH_H" \
		--expand-json '{"parentNoteId": "{{pid}}", "title": "{{tt}}", "type": "{{ty}}", "notePosition":0, "content":"", "mime":"text/html", "prefix": "" }' 2>/dev/null)

	local id=$(echo $resp | jq -r '."note"."noteId"')

	[[ $ismain -eq 1 ]] && curl -s --variable id="$id" \
		--url "$AURL" -H "$AUTH_H" \
		--expand-json '{"noteId": "{{id}}", "type": "label", "name": "viewType", "value": "list", "position": 0, "isInheritable": false}' >/dev/null

	echo "$id"
}
