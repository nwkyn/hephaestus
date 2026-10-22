#!/usr/bin/env bash
# mediawiki fetcher: url forms, search, error codes.
# en.wikipedia.org so arch's wiki is not rate limited. live content, so
# every form is compared against one fetch, search checked by shape.

. ./test-lib.sh

W=en.wikipedia.org
U=https://$W

# one baseline keeps request count low, empty would make every diff pass
wiki-fetch.sh $W Unix >base

test_expect_success 'plain title prints wikitext' '
	test -s base
'

test_expect_success '/wiki/Title url equals host Title' '
	wiki-fetch.sh "$U/wiki/Unix" >actual &&
	diff -u base actual
'

test_expect_success 'index.php title= wins, oldid/diff ignored' '
	wiki-fetch.sh "$U/w/index.php?diff=1&title=Unix&oldid=2" >actual &&
	diff -u base actual
'

test_expect_success 'API env skips discovery' '
	API=$U/w/api.php wiki-fetch.sh - Unix >actual &&
	diff -u base actual
'

test_expect_success '?term search non-empty' '
	wiki-fetch.sh $W "?unix" >hits &&
	test -s hits
'

# checks below run after the api.php probe, so a real wiki is needed
test_expect_success 'empty search exits 2' '
	test_expect_code 2 wiki-fetch.sh $W "?" 2>err &&
	grep -F "empty search: ?" err
'

test_expect_success 'query url without title= exits 2' '
	test_expect_code 2 wiki-fetch.sh "$U/w/index.php?curid=1" 2>err &&
	grep -F "unsupported url:" err
'

# jq error() exits 5
test_expect_success 'missing page exits 5' '
	test_expect_code 5 wiki-fetch.sh $W "Zzzq nonexistent page xyz" 2>err &&
	grep -F "missing:" err
'

test_expect_success 'url outside article path exits 2' '
	test_expect_code 2 wiki-fetch.sh "$U/foo/Unix" 2>err &&
	grep -F "path outside article path" err
'

test_expect_success 'unreachable host exits 2 without network' '
	test_expect_code 2 wiki-fetch.sh http://127.0.0.1:9 Unix 2>err &&
	grep -F "no api.php under" err
'

test_done
