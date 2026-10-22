#!/usr/bin/env bash
# fetch, for any mediawiki: latest raw wikitext, search.

# examples:

# tools/wiki-fetch.sh
# tools/wiki-fetch.sh en.wikipedia.org 'Unix philosophy'
# tools/wiki-fetch.sh en.wikipedia.org '?unix shell'
# tools/wiki-fetch.sh https://en.wikipedia.org/wiki/Unix
# tools/wiki-fetch.sh 'https://en.wikipedia.org/w/index.php?title=Unix&oldid=1'

# ENV Knobs API (skips api.php discovery, $1 then only matters for urls)

# API=https://en.wikipedia.org/w/api.php tools/wiki-fetch.sh - Unix

# https://en.wikipedia.org /wiki/Unix
# └─ wiki (host[/path]) ─┘ └─ article path, from siteinfo ─┘

wiki="${1:-en.wikipedia.org}"
page="${2:-Unix}"

# full browser urls: the path after the host picks the page, $2 is ignored.
path=
case "$wiki" in
*://*/*)
	rest="${wiki#*://}"
	path="/${rest#*/}"
	wiki="${wiki%%://*}://${rest%%/*}" ;;
esac
case "$wiki" in
*://*)	;;
*)	wiki="https://$wiki" ;;
esac
wiki="${wiki%/}"

set -o pipefail

# wikimedia rejects default curl agents
UA="wfetch (https://www.mediawiki.org/wiki/API:Etiquette)"

get() {
	f="$1"
	shift
	curl -sSfG -A "$UA" "$API" -d format=json -d formatversion=2 "$@" |
		jq -r "if .error then error(.error.info) else . end | $f"
}

# api.php location varies per wiki, probe quietly, report once
for c in ${API:-"$wiki/w/api.php" "$wiki/api.php"}; do
	API="$c"
	ap=$(get .query.general.articlepath --no-show-error \
		-d action=query -d meta=siteinfo) && break
	ap=
done
if [ -z "$ap" ]; then
	echo "no api.php under $wiki, set API" >&2
	exit 2
fi

# "%xx" and "+" decoding, enough for titles
dec() { v="${1//+/ }"; printf '%b' "${v//%/\\x}"; }

# query urls: only title= matters, oldid/diff links give the latest content
if [ -n "$path" ]; then
	path="${path%%#*}"
	case "$path" in
	*\?*)
		q="&${path#*\?}&"
		t="${q#*&title=}"
		if [ "$t" = "$q" ]; then
			echo "unsupported url: $path" >&2
			exit 2
		fi
		page=$(dec "${t%%&*}") ;;
	"${ap%\$1}"*)
		page=$(dec "${path#"${ap%\$1}"}") ;;
	*)	echo "path outside article path ${ap%\$1}: $path" >&2
		exit 2 ;;
	esac
fi

if [ "$page" = '?' ]; then
	echo "empty search: $page" >&2
	exit 2
fi

case "$page" in
# lines are valid $2 for a follow-up fetch
\?*)	get '.query.search[].title' -d action=query -d list=search \
		-d srlimit=20 --data-urlencode "srsearch=${page#\?}" ;;
*)	get '.query.pages[0] | if .missing then error("missing: \(.title)")
		else .revisions[0].slots.main.content end' \
		-d action=query -d prop=revisions -d rvprop=content \
		-d rvslots=main -d redirects=1 --data-urlencode "titles=$page" ;;
esac
