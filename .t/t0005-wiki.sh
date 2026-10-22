#!/usr/bin/env bash
# mediawiki fetcher: url forms, revisions, history, search, error codes.
# en.wikipedia.org so arch's wiki is not rate limited. only old revids are
# compared exactly, live page/search/hist output is checked by shape.

. ./test-lib.sh

W=en.wikipedia.org
U=https://$W
# Unix article edit, parent 1354384069
R=1354384541
P=1354384069

test_expect_success 'plain title prints wikitext' '
	wiki-fetch.sh $W Unix >out &&
	test -s out
'

test_expect_success '/wiki/Title url equals host Title' '
	wiki-fetch.sh $W Unix >expect &&
	wiki-fetch.sh "$U/wiki/Unix" >actual &&
	diff -u expect actual
'

test_expect_success 'index.php?title=X url equals host X' '
	wiki-fetch.sh $W Unix >expect &&
	wiki-fetch.sh "$U/w/index.php?title=Unix&action=edit" >actual &&
	diff -u expect actual
'

test_expect_success '?oldid=N url equals old/N' '
	wiki-fetch.sh $W old/$R >expect &&
	wiki-fetch.sh "$U/w/index.php?title=Unix&oldid=$R" >actual &&
	diff -u expect actual
'

test_expect_success '?diff=N&oldid=M url equals rev/N' '
	wiki-fetch.sh $W rev/$R >expect &&
	wiki-fetch.sh "$U/w/index.php?title=Unix&diff=$R&oldid=$P" >actual &&
	diff -u expect actual
'

test_expect_success 'old/N prints content' '
	wiki-fetch.sh $W old/$R >out &&
	test -s out
'

# diff exits 1 on changes, script maps it to 0
test_expect_success 'rev/N: unified diff against parent, rc 0' '
	wiki-fetch.sh $W rev/$R >out &&
	{ IFS= read -r a && IFS= read -r b; } <out &&
	test "$a" = "--- old/$P" &&
	test "$b" = "+++ old/$R" &&
	grep -q "^@@ " out
'

test_expect_success 'hist lines are rev/N, reusable as $2' '
	wiki-fetch.sh $W hist/Unix >hits &&
	test -s hits &&
	! grep -Ev "^rev/[0-9]+ " hits &&
	IFS=" " read -r id rest <hits &&
	wiki-fetch.sh $W "$id" >out &&
	test -s out
'

test_expect_success '?term search non-empty' '
	wiki-fetch.sh $W "?unix" >hits &&
	test -s hits
'

# id/search checks run after the api.php probe, so a real wiki is needed
test_expect_success 'empty search exits 2' '
	test_expect_code 2 wiki-fetch.sh $W "?" 2>err &&
	grep -F "empty search: ?" err
'

test_expect_success 'non-numeric id exits 2' '
	test_expect_code 2 wiki-fetch.sh $W old/abc 2>err &&
	grep -F "bad id: old/abc" err
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

test_expect_success 'API env skips discovery' '
	wiki-fetch.sh $W Unix >expect &&
	API=$U/w/api.php wiki-fetch.sh - Unix >actual &&
	diff -u expect actual
'

test_done
