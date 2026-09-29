#!/usr/bin/env bash
# pasted browser urls must resolve to the same thing as the short form

. ./test-lib.sh

P=gitlab-org/gitlab-runner
U="$WEB_URL/$P"

test_expect_success 'mr url with /diffs tail equals mr/N' '
	fetch $P mr/1 >expect &&
	fetch "$U/-/merge_requests/1/diffs" >actual &&
	diff -u expect actual
'

test_expect_success 'url resource wins over $2' '
	fetch $P wi/1 >expect &&
	fetch "$U/-/issues/1" README.md >actual &&
	diff -u expect actual
'

test_expect_success 'query and fragment stripped from blob url' '
	fetch $P README.md >expect &&
	fetch "$U/-/blob/HEAD/README.md?ref_type=heads#L10" >actual &&
	diff -u expect actual
'

test_expect_success 'blob url ref overrides REF env' '
	REF=HEAD fetch "$U/-/blob/v1.0.0/README.md" >actual &&
	IFS= read -r line <actual &&
	test "$line" = "## GitLab Runner"
'

test_expect_success 'subgroup project split at /-/, not first /' '
	fetch gitlab-org/api/client-go README.md >expect &&
	fetch "$WEB_URL/gitlab-org/api/client-go/-/raw/HEAD/README.md" >actual &&
	diff -u expect actual
'

# unreachable BASE_URL proves the rejection happens before any request
test_expect_success 'unsupported /-/ part exits 2 without network' '
	export BASE_URL=http://127.0.0.1:9/api/v4 &&
	test_expect_code 2 fetch "http://127.0.0.1:9/$P/-/tree/main" 2>err &&
	grep -F "unsupported url part: /-/tree/main" err
'

test_done
