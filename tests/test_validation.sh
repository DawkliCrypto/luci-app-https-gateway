#!/bin/sh
# Unit tests: input validation functions
# Tests validate_domain, validate_location, validate_upstream

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"

# --- Source validation functions from the main script ---
# Extract just the validation functions (avoid running the whole script)

validate_domain() {
	echo "$1" | grep -qE '^\*?\.?[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' || return 1
}

validate_location() {
	echo "$1" | grep -qE '^/[a-zA-Z0-9_./-]*$' || return 1
}

validate_upstream() {
	echo "$1" | grep -qE '^https?://[][a-zA-Z0-9.:-]+(/[^ ]*)?$' || return 1
}

validate_header_value() {
	[ -n "$1" ] || return 1
	echo "$1" | grep -qE '^[^;{}[:cntrl:]]+$' || return 1
}

validate_proxy_header() {
	echo "$1" | grep -qE '^[A-Za-z0-9-]+[[:space:]]+[^;{}[:cntrl:]]+$' || return 1
}

# ============================================================
describe "validate_domain"
# ============================================================

it "accepts simple domain"
assert_exit_code 0 validate_domain "example.com"

it "accepts subdomain"
assert_exit_code 0 validate_domain "sub.example.com"

it "accepts deep subdomain"
assert_exit_code 0 validate_domain "a.b.c.example.com"

it "accepts wildcard domain"
assert_exit_code 0 validate_domain "*.example.com"

it "accepts hyphenated domain"
assert_exit_code 0 validate_domain "my-service.example.com"

it "accepts domain with numbers"
assert_exit_code 0 validate_domain "nas01.home.lan"

it "accepts single char labels"
assert_exit_code 0 validate_domain "a.b.co"

it "rejects empty string"
assert_exit_code 1 validate_domain ""

it "rejects domain with uppercase"
assert_exit_code 1 validate_domain "NAS.example.com"

it "rejects domain with spaces"
assert_exit_code 1 validate_domain "bad domain.com"

it "rejects domain with trailing dot"
assert_exit_code 1 validate_domain "example.com."

it "rejects domain starting with hyphen"
assert_exit_code 1 validate_domain "-bad.example.com"

it "rejects domain ending with hyphen"
assert_exit_code 1 validate_domain "bad-.example.com"

it "rejects domain with underscore"
assert_exit_code 1 validate_domain "bad_name.example.com"

it "rejects URL as domain"
assert_exit_code 1 validate_domain "http://example.com"

it "rejects domain with port"
assert_exit_code 1 validate_domain "example.com:443"

it "rejects double-wildcard"
assert_exit_code 1 validate_domain "**.example.com"

it "rejects single label (no TLD)"
assert_exit_code 1 validate_domain "localhost"

it "rejects domain with special chars"
assert_exit_code 1 validate_domain "bad!.example.com"

# ============================================================
describe "validate_location"
# ============================================================

it "accepts root path /"
assert_exit_code 0 validate_location "/"

it "accepts simple path"
assert_exit_code 0 validate_location "/api"

it "accepts nested path"
assert_exit_code 0 validate_location "/api/v1/users"

it "accepts path with trailing slash"
assert_exit_code 0 validate_location "/app/"

it "accepts path with dots"
assert_exit_code 0 validate_location "/static/app.js"

it "accepts path with underscore"
assert_exit_code 0 validate_location "/my_app/"

it "accepts path with hyphen"
assert_exit_code 0 validate_location "/my-app/v2"

it "rejects empty string"
assert_exit_code 1 validate_location ""

it "rejects path without leading slash"
assert_exit_code 1 validate_location "api"

it "rejects path with spaces"
assert_exit_code 1 validate_location "/bad path"

it "rejects path with query string"
assert_exit_code 1 validate_location "/api?key=val"

it "rejects path with hash"
assert_exit_code 1 validate_location "/page#section"

it "rejects path with backslash"
assert_exit_code 1 validate_location "/bad\\path"

it "rejects path with semicolon"
assert_exit_code 1 validate_location "/bad;path"

# ============================================================
describe "validate_upstream"
# ============================================================

it "accepts http with IP and port"
assert_exit_code 0 validate_upstream "http://192.168.0.1:8080"

it "accepts http with localhost"
assert_exit_code 0 validate_upstream "http://127.0.0.1:9090"

it "accepts https with domain"
assert_exit_code 0 validate_upstream "https://backend.example.com"

it "accepts http with domain and port"
assert_exit_code 0 validate_upstream "http://mynas.local:5000"

it "accepts upstream with path"
assert_exit_code 0 validate_upstream "http://192.168.0.100:8080/api"

it "accepts upstream with trailing slash"
assert_exit_code 0 validate_upstream "http://192.168.0.100:8080/"

it "accepts IPv6 upstream"
assert_exit_code 0 validate_upstream "http://[::1]:8080"

it "accepts IPv6 with zone"
assert_exit_code 0 validate_upstream "http://[fe80::1]:3000"

it "rejects empty string"
assert_exit_code 1 validate_upstream ""

it "rejects ftp protocol"
assert_exit_code 1 validate_upstream "ftp://192.168.0.1"

it "rejects missing protocol"
assert_exit_code 1 validate_upstream "192.168.0.1:8080"

it "rejects upstream with spaces"
assert_exit_code 1 validate_upstream "http://192.168.0.1:8080/bad path"

it "rejects just protocol"
assert_exit_code 1 validate_upstream "http://"

it "rejects websocket protocol"
assert_exit_code 1 validate_upstream "ws://192.168.0.1:8080"

# ============================================================
describe "validate_header_value"
# ============================================================

it "accepts literal value"
assert_exit_code 0 validate_header_value "https"

it "accepts nginx variable"
assert_exit_code 0 validate_header_value "\$scheme"

it "accepts quoted value"
assert_exit_code 0 validate_header_value "\"upgrade\""

it "rejects empty string"
assert_exit_code 1 validate_header_value ""

it "rejects semicolon"
assert_exit_code 1 validate_header_value "value;"

it "rejects braces"
assert_exit_code 1 validate_header_value "{value}"

# ============================================================
describe "validate_proxy_header"
# ============================================================

it "accepts standard literal value"
assert_exit_code 0 validate_proxy_header "X-Forwarded-Proto https"

it "accepts nginx variable value"
assert_exit_code 0 validate_proxy_header "Host \$host"

it "accepts quoted value"
assert_exit_code 0 validate_proxy_header "Connection \"upgrade\""

it "accepts multi-word value"
assert_exit_code 0 validate_proxy_header "X-Custom some value"

it "rejects empty string"
assert_exit_code 1 validate_proxy_header ""

it "rejects header without value"
assert_exit_code 1 validate_proxy_header "X-Only"

it "rejects semicolon"
assert_exit_code 1 validate_proxy_header "X-Bad value;"

it "rejects braces"
assert_exit_code 1 validate_proxy_header "X-Bad {value}"

# ============================================================
test_summary
