#!/bin/sh
# Basic test for https-gateway config generation logic
# Run on a development machine (not router) to validate templates

set -e

PASS=0
FAIL=0

assert_match() {
	local desc="$1" pattern="$2" text="$3"
	if echo "$text" | grep -qE "$pattern"; then
		PASS=$((PASS + 1))
		echo "  ✓ $desc"
	else
		FAIL=$((FAIL + 1))
		echo "  ✗ $desc (pattern: $pattern)"
	fi
}

echo "=== https-gateway validation tests ==="
echo ""

# Test: validate_domain
echo "[1] Domain validation regex"
DOMAIN_RE='^\*?\.?[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'

assert_match "valid domain" "$DOMAIN_RE" "example.com"
assert_match "valid subdomain" "$DOMAIN_RE" "sub.example.com"
assert_match "valid wildcard" "$DOMAIN_RE" "*.example.com"
! echo "invalid domain!" | grep -qE "$DOMAIN_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects invalid domain"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects invalid domain"; }
! echo "http://bad" | grep -qE "$DOMAIN_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects URL as domain"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects URL as domain"; }

echo ""

# Test: validate_location
echo "[2] Location validation regex"
LOC_RE='^/[a-zA-Z0-9_./-]*$'

assert_match "root path" "$LOC_RE" "/"
assert_match "subpath" "$LOC_RE" "/api/v1/"
assert_match "dotted path" "$LOC_RE" "/clash/"
! echo "no-slash" | grep -qE "$LOC_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects no leading slash"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects no leading slash"; }
! echo "/bad path" | grep -qE "$LOC_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects spaces"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects spaces"; }

echo ""

# Test: validate_upstream
echo "[3] Upstream validation regex"
UP_RE='^https?://[][a-zA-Z0-9.:-]+(/[^ ]*)?$'

assert_match "http ip:port" "$UP_RE" "http://192.168.0.1:8080"
assert_match "https domain" "$UP_RE" "https://example.com"
assert_match "with path" "$UP_RE" "http://127.0.0.1:9090/"
assert_match "ipv6" "$UP_RE" "http://[::1]:8080"
! echo "ftp://bad" | grep -qE "$UP_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects non-http"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects non-http"; }

echo ""

# Test: validate_size (client_max_body_size)
echo "[4] Body size validation regex"
SIZE_RE='^[0-9]+[kKmMgG]?$'

assert_match "megabytes" "$SIZE_RE" "50m"
assert_match "gigabytes" "$SIZE_RE" "1G"
assert_match "bare bytes" "$SIZE_RE" "1024"
assert_match "zero (unlimited)" "$SIZE_RE" "0"
! echo "50mb" | grep -qE "$SIZE_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects invalid suffix"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects invalid suffix"; }
! echo "abc" | grep -qE "$SIZE_RE" && { PASS=$((PASS+1)); echo "  ✓ rejects non-numeric"; } || { FAIL=$((FAIL+1)); echo "  ✗ rejects non-numeric"; }

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
