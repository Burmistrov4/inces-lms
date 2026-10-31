#!/usr/bin/env bash
#
# Despliega la API del INCES LMS en Fly.io.
#
# **Cuándo usarlo.** Cuando Render agote sus 750 horas (medido: 503 con
# `x-render-routing: suspend`) y no quieras arranque en frío como en Cloud Run.
# Fly no tiene free tier para cuentas nuevas, pero `shared-cpu-1x` con 512 MB son
# **3,69 $/mes** encendida 24/7, sin techo de horas.
#
# El `fly.toml` ya lleva `auto_stop_machines = "off"` y `min_machines_running = 1`:
# la máquina no se duerme. Eso es lo que se paga y lo que evita el arranque en frío.
#
# Uso:
#   ./devops/desplegar-fly.sh              # crea la app si hace falta y despliega
#   ./devops/desplegar-fly.sh --solo-secretos   # sólo re-sube variables
#
# Requisitos: `flyctl` instalado y `fly auth login` hecho. Tarjeta asociada (Fly
# no tiene capa gratuita). Las claves se leen de backend/.env y **no se imprimen**.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$RAIZ/backend/.env"
APP="${FLY_APP:-inces-lms-api}"

# Las mismas que usa el despliegue de Cloud Run, y por la misma razón: lista
# explícita. Mandar de más a un servicio público es la forma más fácil de
# filtrar una clave.
VARIABLES=(
  SUPABASE_URL
  SUPABASE_ANON_KEY
  SUPABASE_SERVICE_ROLE_KEY
  CORS_ORIGINS
)

necesita() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Falta '$1'. Instálalo antes de seguir." >&2
    exit 1
  }
}

leer_env() {
  local clave="$1"
  grep -E "^${clave}=" "$ENV_FILE" | head -1 | cut -d= -f2- |
    sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/[[:space:]]*$//'
}

necesita flyctl
[ -f "$ENV_FILE" ] || { echo "No encuentro $ENV_FILE" >&2; exit 1; }

cd "$RAIZ/backend"

# 1. La app, solo la primera vez. `fly apps list` no falla si no existe.
if ! flyctl apps list 2>/dev/null | grep -q "^${APP}\b"; then
  echo "Creando la app $APP…"
  flyctl apps create "$APP"
fi

# 2. Secretos. `fly secrets set` los cifra y los inyecta como entorno; el
#    fly.toml se versiona y no puede llevar claves.
SECRETOS=()
for clave in "${VARIABLES[@]}"; do
  valor="$(leer_env "$clave")"
  if [ -z "$valor" ]; then
    echo "  aviso: $clave está vacía en backend/.env; no se envía" >&2
    continue
  fi
  SECRETOS+=("${clave}=${valor}")
done

if [ ${#SECRETOS[@]} -gt 0 ]; then
  echo "Subiendo ${#SECRETOS[@]} secretos…"
  flyctl secrets set --app "$APP" "${SECRETOS[@]}" >/dev/null
fi

if [ "${1:-}" != "--solo-secretos" ]; then
  echo "Desplegando…"
  flyctl deploy --app "$APP" --ha=false
fi

HOST="$(flyctl status --app "$APP" --json 2>/dev/null |
  grep -o '"Hostname":"[^"]*"' | head -1 | cut -d'"' -f4 || true)"

echo
echo "Desplegado. Comprueba la salud:"
if [ -n "$HOST" ]; then
  echo "  curl -s https://$HOST/salud"
  echo
  echo "Y recompila la web apuntando ahí:"
  echo "  flutter build web --release --no-pub --no-wasm-dry-run \\"
  echo "    --no-tree-shake-icons --dart-define-from-file=.env.json \\"
  echo "    --dart-define=API_BASE_URL=https://$HOST"
else
  echo "  flyctl status --app $APP"
fi
echo
echo "OJO: añade el dominio de la web a CORS_ORIGINS y corre --solo-secretos."
