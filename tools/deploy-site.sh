#!/usr/bin/env bash
# Deploys docs/ (the website) to KOOMPI Cloud as a zip-upload service served by nginx.
# Needs a KConsole API token (Settings -> API Tokens, starts with kp_):
#   KCONSOLE_API_TOKEN=kp_... tools/deploy-site.sh
# Optional: KCONSOLE_ORG=<orgId> (default: your first organization). The service id is kept in
# docs/.kconsole.json, so later runs upload a new version of the same service.
set -euo pipefail
API="${KCONSOLE_API_URL:-https://api-kconsole.koompi.cloud}"
TOKEN="${KCONSOLE_API_TOKEN:?set KCONSOLE_API_TOKEN to a KConsole API token (kp_...), from Settings -> API Tokens}"
case "$TOKEN" in kp_*) ;; *) echo "KCONSOLE_API_TOKEN must be a KConsole API token (kp_...); kpi_ keys are AI Gateway keys" >&2; exit 1;; esac
here="$(cd "$(dirname "$0")/.." && pwd)"
state="$here/docs/.kconsole.json"
name="${SITE_NAME:-ansai-shell}"

call() { curl -sS -m 60 -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" "$@"; }
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))" "$1"; }

org="${KCONSOLE_ORG:-$(call "$API/api/auth/me" | json 'd["data"]["memberships"][0]["organization"]["_id"]')}"
zip="$(mktemp --suffix=.zip)"; trap 'rm -f "$zip"' EXIT
(cd "$here/docs" && rm -f "$zip" && zip -qr "$zip" index.html Dockerfile .dockerignore showcase.mp4 screenshots wallpapers)
size=$(stat -c %s "$zip")

up=$(call -X POST "$API/api/orgs/$org/storage/upload-token" \
  -d "{\"filename\":\"$name.zip\",\"contentType\":\"application/zip\",\"visibility\":\"private\",\"size\":$size}")
url=$(echo "$up" | json 'd["data"]["uploadUrl"]'); key=$(echo "$up" | json 'd["data"]["key"]')
curl -sS -m 300 -X PUT -H "Content-Type: application/zip" --data-binary "@$zip" "$url" >/dev/null

if [ -f "$state" ]; then
  sid=$(json 'd["serviceId"]' < "$state")
  call -X POST "$API/api/services/$sid/reupload" -d "{\"r2Key\":\"$key\",\"fileName\":\"$name.zip\",\"fileSize\":$size}" | json 'd.get("data", d)'
else
  res=$(call -X POST "$API/api/orgs/$org/services/upload" -d "{\"name\":\"$name\",\"r2Key\":\"$key\",\"fileName\":\"$name.zip\",\"fileSize\":$size,\"projectPath\":\"/\",\"buildType\":\"dockerfile\",\"dockerfile\":\"Dockerfile\",\"port\":80,\"envVars\":[],\"resourceSizeId\":\"compute-micro\",\"volumes\":[]}")
  echo "$res" | json 'd.get("data", d)'
  sid=$(echo "$res" | json 'd["data"].get("_id") or d["data"].get("id")')
  echo "{\"serviceId\": \"$sid\", \"orgId\": \"$org\"}" > "$state"
fi
echo "deployed; the site comes up at https://$name.tunnel.koompi.cloud once the build finishes"
