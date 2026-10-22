#!/usr/bin/env bash
# fetch, for any mediawiki: raw wikitext, search, history, revision diffs.

# examples:

# tools/wiki-fetch.sh
# tools/wiki-fetch.sh wiki.archlinux.org 'Pacman/Tips and tricks'
# tools/wiki-fetch.sh wiki.archlinux.org '?pacman hooks'
# tools/wiki-fetch.sh wiki.archlinux.org hist/Pacman
# tools/wiki-fetch.sh wiki.archlinux.org rev/884369
# tools/wiki-fetch.sh wiki.archlinux.org old/884369
# tools/wiki-fetch.sh en.wikipedia.org Unix
# tools/wiki-fetch.sh https://wiki.gentoo.org/wiki/Portage
# tools/wiki-fetch.sh 'https://en.wikipedia.org/w/index.php?title=Unix&diff=1&oldid=2'

# ENV Knobs API (skips api.php discovery, $1 then only matters for urls)

# API=https://wiki.archlinux.org/api.php tools/wiki-fetch.sh - Pacman

# https://wiki.archlinux.org /title/Pacman
# └── wiki (host[/path]) ──┘ └─ article path, from siteinfo ─┘

wiki="${1:-wiki.archlinux.org}"
page="${2:-Installation guide}"

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

# "%xx" and "+" decoding, enough for titles and ids
dec() { v="${1//+/ }"; printf '%b' "${v//%/\\x}"; }

# query param $1 from "?a=b&c=d", empty if absent
param() {
	q="&${path#*\?}&"
	v="${q#*&"$1"=}"
	[ "$v" != "$q" ] && dec "${v%%&*}"
}

if [ -n "$path" ]; then
	path="${path%%#*}"
	case "$path" in
	*\?*)
		if d=$(param diff) && [ "$d" != prev ]; then
			page="rev/$d"
		elif d=$(param oldid); then
			page="old/$d"
		elif d=$(param title); then
			page="$d"
		else
			echo "unsupported url: $path" >&2
			exit 2
		fi ;;
	"${ap%\$1}"*)
		page=$(dec "${path#"${ap%\$1}"}") ;;
	*)	echo "path outside article path ${ap%\$1}: $path" >&2
		exit 2 ;;
	esac
fi

case "$page" in
rev/*|old/*)
	id="${page#*/}"
	case "$id" in
	''|*[!0-9]*)	echo "bad id: $page" >&2; exit 2 ;;
	esac ;;
\?*)
	if [ "$page" = '?' ]; then
		echo "empty search: $page" >&2
		exit 2
	fi ;;
esac

revs='.query.pages[0] |
	if .missing then error("missing: \(.title)") else .revisions end'
# lines are valid $2 for a follow-up fetch
hist='.[] | "rev/\(.revid) \(.timestamp[:10]) \(.user // "?"): \(
	.comment // "")"'

# revision content, revid 0 (page creation parent) is empty
old() {
	[ "$1" = 0 ] && return
	get '(.query.pages // error("bad revision")) |
		.[0].revisions[0].slots.main.content' \
		-d action=query -d prop=revisions -d rvprop=content \
		-d rvslots=main -d "revids=$1"
}

case "$page" in
\?*)	get '.query.search[].title' -d action=query -d list=search \
		-d srlimit=20 --data-urlencode "srsearch=${page#\?}" ;;
hist/*)	get "$revs | $hist" -d action=query -d prop=revisions \
		-d 'rvprop=ids|timestamp|user|comment' -d rvlimit=20 \
		-d redirects=1 --data-urlencode "titles=${page#*/}" ;;
old/*)	old "$id" ;;
# diff exits 1 on changes, only 2+ is a failure
rev/*)	p=$(get '(.query.pages // error("bad revision")) |
		.[0].revisions[0].parentid' -d action=query \
		-d prop=revisions -d rvprop=ids -d "revids=$id") || exit
	diff -u --label "old/$p" --label "old/$id" <(old "$p") <(old "$id")
	[ $? -lt 2 ] ;;
*)	get "$revs | .[0].slots.main.content" -d action=query \
		-d prop=revisions -d rvprop=content -d rvslots=main \
		-d redirects=1 --data-urlencode "titles=$page" ;;
esac
