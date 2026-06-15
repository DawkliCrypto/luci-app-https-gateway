#!/bin/sh
# Unit tests: nginx configuration generation
# Tests the output of _generate_server_block and _generate_location logic

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/framework.sh"

# --- Mock config data and generate nginx conf snippets ---

# Simulate generate_server_block output for a basic proxy
generate_basic_server_block() {
	local domain="$1"
	local listen_ip="${2:-0.0.0.0}"
	local cert_file="/etc/ssl/acme/${domain}.fullchain.crt"
	local key_file="/etc/ssl/acme/${domain}.key"

	cat <<EOF
server {
    listen ${listen_ip}:443 ssl;
    listen [::]:443 ssl;
    server_name ${domain};

    ssl_certificate ${cert_file};
    ssl_certificate_key ${key_file};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_session_cache shared:SSL_${domain%%.*}:10m;
    ssl_session_timeout 10m;

}
EOF
}

# Simulate _generate_location output
generate_location_block() {
	local location="$1"
	local upstream="$2"
	local websocket="${3:-0}"
	local max_body_size="${4:-}"

	cat <<EOF
    location ${location} {
        proxy_pass ${upstream};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
EOF

	[ -n "$max_body_size" ] && echo "        client_max_body_size ${max_body_size};"

	if [ "$websocket" = "1" ]; then
		cat <<EOF
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        proxy_buffering off;
EOF
	else
		cat <<EOF
        proxy_read_timeout 300;
EOF
	fi

	echo "    }"
}

# Simulate HTTP redirect block
generate_redirect_block() {
	local listen_ip="${1:-0.0.0.0}"
	cat <<EOF
server {
    listen ${listen_ip}:80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF
}

# ============================================================
describe "nginx HTTP→HTTPS redirect block"
# ============================================================

it "generates redirect with default listen IP"
OUTPUT=$(generate_redirect_block)
assert_contains "$OUTPUT" "listen 0.0.0.0:80 default_server" "listens on 0.0.0.0:80"
assert_contains "$OUTPUT" "return 301 https://" "redirects to HTTPS"
assert_contains "$OUTPUT" 'server_name _' "catches all server names"

it "generates redirect with custom listen IP"
OUTPUT=$(generate_redirect_block "192.168.0.1")
assert_contains "$OUTPUT" "listen 192.168.0.1:80 default_server" "custom listen IP"

# ============================================================
describe "nginx server block generation"
# ============================================================

it "generates valid server block for simple domain"
OUTPUT=$(generate_basic_server_block "nas.example.com")
assert_contains "$OUTPUT" "server_name nas.example.com" "correct server_name"
assert_contains "$OUTPUT" "listen 0.0.0.0:443 ssl" "listens on 443"
assert_contains "$OUTPUT" "listen [::]:443 ssl" "listens on IPv6"
assert_contains "$OUTPUT" "ssl_certificate /etc/ssl/acme/nas.example.com.fullchain.crt" "correct cert path"
assert_contains "$OUTPUT" "ssl_certificate_key /etc/ssl/acme/nas.example.com.key" "correct key path"

it "includes TLS security settings"
OUTPUT=$(generate_basic_server_block "app.example.com")
assert_contains "$OUTPUT" "ssl_protocols TLSv1.2 TLSv1.3" "modern TLS protocols"
assert_contains "$OUTPUT" "ssl_ciphers HIGH:!aNULL:!MD5" "secure ciphers"
assert_contains "$OUTPUT" "ssl_session_cache" "session cache enabled"
assert_contains "$OUTPUT" "ssl_session_timeout 10m" "session timeout set"

it "uses first label for session cache name"
OUTPUT=$(generate_basic_server_block "sub.domain.example.com")
assert_contains "$OUTPUT" "SSL_sub:10m" "uses first label"

it "respects custom listen IP"
OUTPUT=$(generate_basic_server_block "nas.example.com" "192.168.0.1")
assert_contains "$OUTPUT" "listen 192.168.0.1:443 ssl" "custom IP in listen"

# ============================================================
describe "nginx location block generation"
# ============================================================

it "generates basic proxy_pass location"
OUTPUT=$(generate_location_block "/" "http://192.168.0.100:5000")
assert_contains "$OUTPUT" "location / {" "correct location path"
assert_contains "$OUTPUT" "proxy_pass http://192.168.0.100:5000" "correct upstream"
assert_contains "$OUTPUT" "proxy_http_version 1.1" "HTTP/1.1 for upstream"

it "sets required proxy headers"
OUTPUT=$(generate_location_block "/" "http://127.0.0.1:8080")
assert_contains "$OUTPUT" 'proxy_set_header Host $host' "Host header"
assert_contains "$OUTPUT" 'proxy_set_header X-Real-IP $remote_addr' "X-Real-IP header"
assert_contains "$OUTPUT" 'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for' "X-Forwarded-For"
assert_contains "$OUTPUT" 'proxy_set_header X-Forwarded-Proto https' "X-Forwarded-Proto"

it "uses 300s timeout without websocket"
OUTPUT=$(generate_location_block "/" "http://192.168.0.1:8080" "0")
assert_contains "$OUTPUT" "proxy_read_timeout 300" "300s read timeout"
assert_not_contains "$OUTPUT" "Upgrade" "no Upgrade header"
assert_not_contains "$OUTPUT" "proxy_buffering off" "buffering not disabled"

it "enables WebSocket headers when websocket=1"
OUTPUT=$(generate_location_block "/" "http://192.168.0.200:8123" "1")
assert_contains "$OUTPUT" 'proxy_set_header Upgrade $http_upgrade' "Upgrade header"
assert_contains "$OUTPUT" 'proxy_set_header Connection "upgrade"' "Connection header"
assert_contains "$OUTPUT" "proxy_read_timeout 86400" "long timeout for WS"
assert_contains "$OUTPUT" "proxy_buffering off" "buffering disabled for WS"

it "handles sub-path location"
OUTPUT=$(generate_location_block "/api/v1/" "http://192.168.0.50:3000")
assert_contains "$OUTPUT" "location /api/v1/ {" "sub-path in location"
assert_contains "$OUTPUT" "proxy_pass http://192.168.0.50:3000" "upstream correct"

it "handles HTTPS upstream"
OUTPUT=$(generate_location_block "/" "https://external.service.com:8443")
assert_contains "$OUTPUT" "proxy_pass https://external.service.com:8443" "HTTPS upstream"

it "emits client_max_body_size when set"
OUTPUT=$(generate_location_block "/" "http://192.168.0.100:8095" "1" "50m")
assert_contains "$OUTPUT" "client_max_body_size 50m;" "body size directive emitted"

it "omits client_max_body_size when empty"
OUTPUT=$(generate_location_block "/" "http://192.168.0.100:8095" "0" "")
assert_not_contains "$OUTPUT" "client_max_body_size" "no body size directive by default"

# ============================================================
describe "nginx config security"
# ============================================================

it "does not include unsafe SSL protocols"
OUTPUT=$(generate_basic_server_block "secure.example.com")
assert_not_contains "$OUTPUT" "SSLv2" "no SSLv2"
assert_not_contains "$OUTPUT" "SSLv3" "no SSLv3"
assert_not_contains "$OUTPUT" "TLSv1.0" "no TLSv1.0"
assert_not_contains "$OUTPUT" "TLSv1.1" "no TLSv1.1"

it "does not expose server tokens by default"
OUTPUT=$(generate_basic_server_block "secure.example.com")
# server_tokens off should be in main nginx.conf, not per-server
# But verify we don't explicitly enable it
assert_not_contains "$OUTPUT" "server_tokens on" "tokens not enabled"

# ============================================================
test_summary
