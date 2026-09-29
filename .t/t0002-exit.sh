#!/usr/bin/env bash
# curl failures must reach the caller, jq exits 0 on empty input

. ./test-lib.sh

P=gitlab-org/gitlab-runner

# && between header and diffs: one curl error means diffs never requested
test_expect_success 'missing mr: rc 22, no stdout, diffs not requested' '
	test_expect_code 22 fetch $P mr/999999999 >out 2>err &&
	test ! -s out &&
	test "$(wc -l <err)" -eq 1
'

test_expect_success 'unreachable host: curl rc 7 passes through' '
	export BASE_URL=http://127.0.0.1:9/api/v4 &&
	test_expect_code 7 fetch $P wi/1
'

# BASE_URL prefix does not match, url is taken as a literal project path
test_expect_success 'url from another instance fails, no silent fetch' '
	test_expect_code 22 fetch https://gitlab.archlinux.org/pacman/pacman wi/1
'

test_done
