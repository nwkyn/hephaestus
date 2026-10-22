#!/usr/bin/env bash
# because you live in your terminal.

# examples:

# tools/gitlab-fetch.sh gitlab-org/gitlab-runner README.md
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner wi/1
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner mr/1
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner cmp/v1.0.0...v1.0.1
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner cmp/v1.0.0..v1.0.1
# tools/gitlab-fetch.sh gitlab-org/api/client-go README.md
# tools/gitlab-fetch.sh https://gitlab.com/gitlab-org/gitlab-runner/-/merge_requests/1
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner 'wi?docker'
# tools/gitlab-fetch.sh gitlab-org/gitlab-runner 'mr?docker runner'

# ENV Knobs BASE_URL, REF

# BASE_URL=https://gitlab.example.org/api/v4 tools/gitlab-fetch.sh group/project wi/1
# REF=v1.0.0 tools/gitlab-fetch.sh gitlab-org/gitlab-runner README.md

# you can pipe this to "glow" for md formatting for instance
# or whatever people do with markdown in terminals/editors

# https://gitlab.com / gitlab-org/gitlab-runner/
# └── url server ──┘   └── project path ───────┘

# project path can consist of top level groups and several subgroups.

# here instead we query json, but the path guide above still applies
BASE_URL="${BASE_URL:-https://gitlab.com/api/v4}"
# you could change this to any gitlab instance.

# default to the runner readme or specify a project and file path to consult.
# plain paths: "/" is escaped to "%2F" below. the api skips web-ui bot checks.

project="${1:-gitlab-org/gitlab-runner}"
file="${2:-README.md}"
ref="${REF:-HEAD}"

# accept pasted browser urls and trailing slashes
project="${project#"${BASE_URL%/api/v4}"/}"
project="${project%%[?#]*}"
project="${project%/}"

# full browser urls: the part after "/-/" picks the resource, $2 is ignored.
# blob refs containing "/" are ambiguous (gitlab ui has the same problem).
case "$project" in
*/-/*)
	tail="${project#*/-/}"
	project="${project%%/-/*}"
	id="${tail#*/}"
	case "$tail" in
	merge_requests/*)	file="mr/${id%%/*}" ;;
	issues/*)		file="wi/${id%%/*}" ;;
	compare/*)		file="cmp/$id" ;;
	blob/*|raw/*)		ref="${id%%/*}" file="${id#*/}" ;;
	*)	echo "unsupported url part: /-/$tail" >&2; exit 2 ;;
	esac ;;
esac

# empty/non-numeric id hits the list endpoint, jq then fails on the array
case "$file" in
mr/*|wi/*)
	id="${file#*/}"
	id="${id%/}"
	case "$id" in
	''|*[!0-9]*)	echo "bad id: $file" >&2; exit 2 ;;
	esac
	file="${file%%/*}/$id" ;;
# search title/description, all states, newest first
mr\?*|wi\?*)
	term="${file#*\?}"
	if [ -z "$term" ]; then
		echo "empty search: $file" >&2
		exit 2
	fi ;;
# branch names may hold "/", only dots separate the two refs.
# git semantics: "..." diffs from merge base, ".." diffs FROM against TO.
# "a..." would otherwise match ".." with TO=".", reject it first.
cmp/*)
	r="${file#*/}"
	straight=
	case "$r" in
	*...|...*)	;;
	?*...?*)	from="${r%%...*}" to="${r#*...}" straight=false ;;
	?*..?*)		from="${r%%..*}" to="${r#*..}" straight=true ;;
	esac
	if [ -z "$straight" ]; then
		echo "bad range: $file, want cmp/FROM...TO or FROM..TO" >&2
		exit 2
	fi ;;
esac

# needed so that any curl error flows through, i.e 22 for 404
set -o pipefail

# full percent-encoding, "/" included, so any path/ref is a single segment
enc() { jq -rn --arg s "$1" '$s|@uri'; }

get() { curl -sSf "$BASE_URL/projects/$(enc "$project")/$1"; }

header='"# \(.title) [\(.state)] by \(.author.username)\n\n\(.description // "")"'
# gitlab blanks .diff past its size limits, say so instead of printing nothing.
# empty .diff otherwise means binary, pure rename or mode change.
diffs='.[] | "\n--- a/\(.old_path)\n+++ b/\(.new_path)\n\(
	if .too_large then "(diff too large, see web ui)"
	elif .diff == "" then "(no text diff)"
	else .diff end)"'
# lines are valid $2 for a follow-up fetch
hits='.[] | "\($k)/\(.iid) [\(.state)] \(.title) by \(.author.username)"'
cmp='"# \($r) [\(.commits | length) commits]\(
	if .compare_timeout then " (timed out, partial)" else "" end)\n",
	(.commits[] | "\(.short_id) \(.title)"),
	(.diffs | '"$diffs"')'

case "$file" in
mr\?*|wi\?*)
	k="${file%%\?*}"
	q="search=$(enc "$term")&state=all&per_page=20"
	[ "$k" = mr ] && ep=merge_requests || ep=issues
	get "$ep?$q" | jq -r --arg k "$k" "$hits" ;;
mr/*)	get "merge_requests/${file#*/}" | jq -r "$header" &&
	get "merge_requests/${file#*/}/diffs?per_page=100" | jq -r "$diffs" ;;
wi/*)	get "issues/${file#*/}" | jq -r "$header" ;;
cmp/*)	q="from=$(enc "$from")&to=$(enc "$to")&straight=$straight"
	get "repository/compare?$q" | jq -r --arg r "$r" "$cmp" ;;
*)	get "repository/files/$(enc "$file")/raw?ref=$(enc "$ref")" ;;
esac

# mr diffs cap at 100 files (single page), rest is not fetched
