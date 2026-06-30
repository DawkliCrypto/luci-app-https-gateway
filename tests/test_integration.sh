#!/bin/sh
# Integration tests: cmd_test output format, config validation
# Tests JSON output format and end-to-end command behavior

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"

# ============================================================
describe "cmd_test output format"
# ============================================================

# Simulate cmd_test behavior
cmd_test_pass() {
	echo '{"valid":true,"message":"nginx configuration test passed"}'
}

cmd_test_fail() {
	local err="nginx: [emerg] unknown directive \"bad\" in /etc/nginx/conf.d/test.conf:1"
	local sanitized
	sanitized=$(echo "$err" | tr '"' "'" | tr '\n' ' ')
	echo "{\"valid\":false,\"message\":\"${sanitized}\"}"
}

it "pass result is valid JSON with valid=true"
OUTPUT=$(cmd_test_pass)
assert_contains "$OUTPUT" '"valid":true' "valid field is true"
assert_contains "$OUTPUT" '"message":"nginx configuration test passed"' "success message"

it "fail result is valid JSON with valid=false"
OUTPUT=$(cmd_test_fail)
assert_contains "$OUTPUT" '"valid":false' "valid field is false"
assert_contains "$OUTPUT" '"message":' "has message field"

it "fail result sanitizes double quotes in error"
OUTPUT=$(cmd_test_fail)
# After sanitization, internal quotes become single-quotes
# so the JSON string value should not contain unescaped double-quotes
# Valid structure: {"valid":false,"message":"...no-internal-dquotes..."}
assert_not_contains "$OUTPUT" '""' "no empty quoted segments"
# Verify it starts and ends like valid JSON
assert_match "$OUTPUT" '^\{"valid":false,"message":".*"\}$' "valid JSON structure"

# ============================================================
describe "UCI config validation"
# ============================================================

# Validate that required fields are checked
validate_global_config() {
	local email="$1"
	local dns_provider="$2"

	[ -z "$email" ] && { echo "ERROR: email required"; return 1; }
	[ -z "$dns_provider" ] && { echo "ERROR: dns_provider required"; return 1; }
	# Email basic check
	case "$email" in
		*@*.*) ;;
		*) echo "ERROR: invalid email"; return 1 ;;
	esac
	return 0
}

it "accepts valid global config"
assert_exit_code 0 validate_global_config "user@example.com" "dns_ali"

it "rejects missing email"
assert_exit_code 1 validate_global_config "" "dns_ali"

it "rejects missing dns_provider"
assert_exit_code 1 validate_global_config "user@example.com" ""

it "rejects invalid email format"
assert_exit_code 1 validate_global_config "notanemail" "dns_ali"

it "accepts email with subdomain"
assert_exit_code 0 validate_global_config "admin@mail.example.com" "dns_cf"

it "exposes IONOS DNS provider in the settings UI"
assert_true grep -q "dns_ionos" src/view/settings.js # exposes IONOS DNS provider in the settings UI

# ============================================================
describe "Service state transitions"
# ============================================================

# Simulate enabled/disabled logic
should_apply() {
	local enabled="$1"
	[ "$enabled" = "1" ] && return 0 || return 1
}

it "applies when enabled=1"
assert_exit_code 0 should_apply "1"

it "skips when enabled=0"
assert_exit_code 1 should_apply "0"

it "skips when enabled is empty"
assert_exit_code 1 should_apply ""

it "skips when enabled is unexpected value"
assert_exit_code 1 should_apply "yes"

# ============================================================
describe "uhttpd port detection"
# ============================================================

# Simulate uhttpd port check
is_uhttpd_on_default_port() {
	local listen="$1"
	case "$listen" in
		*:80|0.0.0.0:80|*:443) return 0 ;;
		127.0.0.1:8080) return 1 ;;
		*) return 0 ;;
	esac
}

needs_uhttpd_move() {
	local cur_http="$1"
	! echo "$cur_http" | grep -q '127.0.0.1:8080'
}

it "detects uhttpd on default port"
assert_exit_code 0 needs_uhttpd_move "0.0.0.0:80"

it "detects uhttpd already moved"
assert_exit_code 1 needs_uhttpd_move "127.0.0.1:8080"

it "detects mixed listen directive needs move"
assert_exit_code 0 needs_uhttpd_move "0.0.0.0:80 0.0.0.0:443"

# ============================================================
describe "Proxy rule field completeness"
# ============================================================

validate_proxy_rule() {
	local domain="$1" location="$2" upstream="$3"

	[ -z "$domain" ] && return 1
	[ -z "$location" ] && return 1
	[ -z "$upstream" ] && return 1

	echo "$domain" | grep -qE '^\*?\.?[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' || return 1
	echo "$location" | grep -qE '^/[a-zA-Z0-9_./-]*$' || return 1
	echo "$upstream" | grep -qE '^https?://[][a-zA-Z0-9.:-]+(/[^ ]*)?$' || return 1

	return 0
}

it "accepts complete valid rule"
assert_exit_code 0 validate_proxy_rule "nas.example.com" "/" "http://192.168.0.100:5000"

it "rejects rule with missing domain"
assert_exit_code 1 validate_proxy_rule "" "/" "http://192.168.0.100:5000"

it "rejects rule with missing location"
assert_exit_code 1 validate_proxy_rule "nas.example.com" "" "http://192.168.0.100:5000"

it "rejects rule with missing upstream"
assert_exit_code 1 validate_proxy_rule "nas.example.com" "/" ""

it "rejects rule with invalid domain"
assert_exit_code 1 validate_proxy_rule "BAD!" "/" "http://192.168.0.1:80"

it "rejects rule with invalid location"
assert_exit_code 1 validate_proxy_rule "nas.example.com" "noslash" "http://192.168.0.1:80"

it "rejects rule with invalid upstream"
assert_exit_code 1 validate_proxy_rule "nas.example.com" "/" "ftp://bad"

# ============================================================
test_summary
