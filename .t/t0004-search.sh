#!/usr/bin/env bash
# search hits are "wi/N" / "mr/N" lines, reusable as $2

. ./test-lib.sh

P=gitlab-org/gitlab-runner

test_expect_success 'issue hit fetches as wi/N' '
	gitlab-fetch.sh $P "wi?docker" >hits &&
	test -s hits &&
	IFS=" " read -r id rest <hits &&
	case "$id" in wi/[0-9]*) ;; *) false ;; esac &&
	gitlab-fetch.sh $P "$id" >out &&
	test -s out
'

test_expect_success 'mr hits prefixed mr/' '
	gitlab-fetch.sh $P "mr?docker" >hits &&
	test -s hits &&
	! grep -v "^mr/[0-9]" hits
'

test_expect_success 'empty search exits 2 without network' '
	export BASE_URL=http://127.0.0.1:9/api/v4 &&
	test_expect_code 2 gitlab-fetch.sh $P "wi?" 2>err &&
	grep -F "empty search: wi?" err
'

test_done
