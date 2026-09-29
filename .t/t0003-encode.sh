#!/usr/bin/env bash
# reserved chars in ref stay inside their path segment

. ./test-lib.sh

# unencoded, "&" appends a second ref param that gitlab honors
test_expect_success '"&" in REF does not inject extra params' '
	P=gitlab-org/gitlab-runner &&
	REF="HEAD&ref=v1.0.0" test_expect_code 22 fetch $P README.md
'

test_done
