#!/usr/bin/env bash
# Publica salaomax.focodev.com.br no túnel Cloudflare "gerenciamento-estoque" (preserva os outros
# hostnames) e cria o CNAME. Roda no servidor: bash /opt/salao-max/cloudflare-hostname.sh
set -euo pipefail

HOSTNAME="${PUBLIC_HOSTNAME:-salaomax.focodev.com.br}"
ORIGIN="${ORIGIN:-http://127.0.0.1:8089}"
ZONE_NAME="${CLOUDFLARE_ZONE_NAME:-focodev.com.br}"
TUNNEL_ENV="${TUNNEL_ENV:-/opt/gerenciamento-estoque/.env}"
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

if [[ -z "$API_TOKEN" && -f /opt/app-rotas/.env ]]; then
  API_TOKEN="$(grep '^CLOUDFLARE_API_TOKEN=' /opt/app-rotas/.env | cut -d= -f2- | tr -d '\r\n' || true)"
fi
if [[ ${#API_TOKEN} -lt 20 && -f /root/.secrets/cloudflare-certbot.ini ]]; then
  API_TOKEN="$(grep 'dns_cloudflare_api_token' /root/.secrets/cloudflare-certbot.ini | sed 's/.*= *//' | tr -d '\r\n"' || true)"
fi
if [[ ${#API_TOKEN} -lt 20 ]]; then
  echo "ERRO: CLOUDFLARE_API_TOKEN ausente. No painel: túnel gerenciamento-estoque →"
  echo "Public Hostname ${HOSTNAME} → ${ORIGIN}"
  exit 1
fi

export HOSTNAME ORIGIN ZONE_NAME TUNNEL_ENV API_TOKEN CLOUDFLARE_ZONE_ID="${CLOUDFLARE_ZONE_ID:-}"
python3 - <<'PY'
import base64, json, os, urllib.parse, urllib.request

host, origin, token = os.environ["HOSTNAME"], os.environ["ORIGIN"], os.environ["API_TOKEN"]

def call(method, url, body=None):
    req = urllib.request.Request(
        "https://api.cloudflare.com/client/v4" + url,
        data=None if body is None else json.dumps(body).encode(),
        method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)

tunnel_token = next(
    line.split("=", 1)[1].strip()
    for line in open(os.environ["TUNNEL_ENV"])
    if line.startswith("CLOUDFLARED_TUNNEL_TOKEN=")
)
data = json.loads(base64.urlsafe_b64decode(tunnel_token + "=" * (-len(tunnel_token) % 4)))
account, tunnel = data["a"], data["t"]

# 1) ingress do túnel: troca/insere o hostname antes do catch-all, mantendo o resto da config.
path = f"/accounts/{account}/cfd_tunnel/{tunnel}/configurations"
config = call("GET", path)["result"]["config"]
ingress = [i for i in config["ingress"] if i.get("hostname") != host]
catch_all = ingress.pop() if ingress and "hostname" not in ingress[-1] else {"service": "http_status:404"}
config["ingress"] = ingress + [{"hostname": host, "service": origin}, catch_all]
call("PUT", path, {"config": config})
print(f"OK: túnel {host} -> {origin}")

# 2) DNS: CNAME proxied para o túnel.
# Sem permissão de Zone Read no token: passe CLOUDFLARE_ZONE_ID (aparece na URL da zona no painel).
zone_id = os.environ.get("CLOUDFLARE_ZONE_ID", "")
if not zone_id:
    zone = call("GET", "/zones?" + urllib.parse.urlencode({"name": os.environ["ZONE_NAME"]}))["result"]
    if not zone:
        raise SystemExit(f"Zona não encontrada; crie o CNAME {host} -> {tunnel}.cfargotunnel.com no painel.")
    zone_id = zone[0]["id"]
found = call("GET", f"/zones/{zone_id}/dns_records?" + urllib.parse.urlencode({"name": host}))["result"]
if found:
    print(f"OK: DNS {host} já existe ({found[0]['type']} -> {found[0]['content']})")
else:
    call("POST", f"/zones/{zone_id}/dns_records",
         {"type": "CNAME", "name": host, "content": f"{tunnel}.cfargotunnel.com", "proxied": True})
    print(f"OK: CNAME {host} criado")
PY
