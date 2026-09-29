# minimal git/git style test lib, ./tests-run from repo root runs all.
# single file: cd .t && ./t0001-url.sh
# gitlab.com by default so arch's instance is not rate limited.
# fixtures are closed/merged items and tags, content should not move.

TEST_NAME="${0##*/}"
TRASH="$PWD/trash directory.${TEST_NAME%.sh}"

export BASE_URL="${TEST_BASE_URL:-https://gitlab.com/api/v4}"
WEB_URL="${BASE_URL%/api/v4}"
unset REF
PATH="$PWD/..:$PATH"

test_count=0
test_fail=0

rm -rf "$TRASH" && mkdir "$TRASH" && cd "$TRASH" || exit 1

# body eval'd in a subshell so exports and failures do not leak
test_expect_success() {
	test_count=$((test_count + 1))
	if (set -e; eval "$2") >out.log 2>&1; then
		echo "ok $test_count - $1"
		return
	fi
	test_fail=$((test_fail + 1))
	echo "not ok $test_count - $1"
	sed 's/^/#	/' out.log
}

# exact exit code, i.e curl's 22 must survive the jq pipe.
# "|| rc=" keeps set -e of the body from exiting on expected failure.
test_expect_code() {
	want=$1
	shift
	rc=0
	"$@" || rc=$?
	test $rc -eq "$want" && return
	echo "'$*' exited $rc, want $want" >&2
	return 1
}

# trash dir kept on failure for inspection
test_done() {
	echo "# ${TEST_NAME%.sh}: $((test_count - test_fail))/$test_count passed"
	test $test_fail -eq 0 || exit 1
	rm -rf "$TRASH"
}
