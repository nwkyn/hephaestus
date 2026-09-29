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

test_expect_success 'empty or non-numeric id exits 2 without network' '
	export BASE_URL=http://127.0.0.1:9/api/v4 &&
	test_expect_code 2 fetch $P wi/ 2>err &&
	grep -F "bad id: wi/" err &&
	test_expect_code 2 fetch $P mr/abc &&
	test_expect_code 2 fetch $P mr/1x
'

test_expect_success 'range without dots or empty side exits 2' '
	export BASE_URL=http://127.0.0.1:9/api/v4 &&
	test_expect_code 2 fetch $P cmp/main 2>err &&
	grep -F "bad range: cmp/main" err &&
	test_expect_code 2 fetch $P cmp/...v1.0.1 &&
	test_expect_code 2 fetch $P cmp/v1.0.0... &&
	test_expect_code 2 fetch $P cmp/..v1.0.1 &&
	test_expect_code 2 fetch $P cmp/v1.0.0..
'

# reversed linear pair: merge base is TO itself, only ".." has a diff
test_expect_success '"..." diffs from merge base, ".." straight' '
	fetch $P cmp/v1.0.1...v1.0.0 >three &&
	test "$(grep -c "^--- a/" three)" -eq 0 &&
	fetch $P cmp/v1.0.1..v1.0.0 >two &&
	test "$(grep -c "^--- a/" two)" -eq 17
'

test_expect_success 'compare url equals cmp/FROM...TO' '
	fetch $P cmp/v1.0.0...v1.0.1 >expect &&
	fetch "$U/-/compare/v1.0.0...v1.0.1?from_project_id=1" >actual &&
	diff -u expect actual &&
	IFS= read -r line <actual &&
	test "$line" = "# v1.0.0...v1.0.1 [10 commits]"
'

test_expect_success 'trailing slash on short id tolerated' '
	fetch $P mr/1 >expect &&
	fetch $P mr/1/ >actual &&
	diff -u expect actual
'

test_done
