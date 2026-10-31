#!/usr/bin/env bash
#
# Despliega la API del INCES LMS en Google Cloud Run.
#
# **Por qué existe.** Render da 750 horas de instancia al mes por workspace
# (≈ un servicio siempre encendido, sin margen) y suspende los servicios free
# cuando se agotan —medido: 503 con `x-render-routing: suspend` el 2026-10-30—.
# Cloud Run tiene un free tier real (2M peticiones, 180k vCPU-s y 360k GiB-s al
# mes) y **escala a cero**: sin tráfico no consume cuota ni cobra.
#
# Lo que NO cambia: la imagen. `backend/Dockerfile` ya construye una API
# stateless que escucha en `$PORT` (3000 por defecto) y tiene healthcheck en
# `/salud`. Este script solo la sube.
#
# Uso:
#   ./devops/desplegar-cloudrun.sh              # compila, publica y despliega
#   ./devops/desplegar-cloudrun.sh --solo-env   # solo re-sube variables
#
# Requisitos: `gcloud` autenticado (`gcloud auth login`) y un proyecto con
# facturación activada. El free tier se aplica solo; **no** hay cargo si no se
# pasa de las cuotas, pero Cloud Run exige una cuenta de facturación asociada.
#
# Secretos: se leen de `backend/.env` y se suben como variables de entorno del
# servicio. Nunca se imprimen. Si prefieres Secret Manager, ver la nota al final.

set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$RAIZ/backend/.env"

SERVICIO="${CLOUD_RUN_SERVICIO:-inces-lms-api}"
REGION="${CLOUD_RUN_REGION:-us-central1}"
REPOSITORIO="${CLOUD_RUN_REPO:-inces-lms}"
IMAGEN="$REGION-docker.pkg.dev/PROYECTO/$REPOSITORIO/api"

# Variables que la API necesita. La lista es explícita y no «todas las del .env»:
# mandar de más a un servicio público es la forma más fácil de filtrar una clave.
VARIABLES=(
  NODE_ENV
  SUPABASE_URL
  SUPABASE_ANON_KEY
  SUPABASE_SERVICE_ROLE_KEY
  CORS_ORIGINS
  LOG_LEVEL
  MODULE_CACHE_TTL_MS
  SETTINGS_CACHE_TTL_MS
  RATE_LIMIT_MAX
  RATE_LIMIT_WINDOW
)

necesita() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Falta '$1'. Instálalo antes de seguir." >&2
    exit 1
  }
}

leer_env() {
  # Devuelve el valor de una clave del .env sin comillas ni espacios sobrantes.
  local clave="$1"
  grep -E "^${clave}=" "$ENV_FILE" | head -1 | cut -d= -f2- |
    sed -e 's/^["'\'']//' -e 's/["'\'']$//' -e 's/[[:space:]]*$//'
}

necesita gcloud
[ -f "$ENV_FILE" ] || { echo "No encuentro $ENV_FILE" >&2; exit 1; }

PROYECTO="$(gcloud config get-value project 2>/dev/null || true)"
if [ -z "$PROYECTO" ] || [ "$PROYECTO" = "(unset)" ]; then
  echo "No hay proyecto de gcloud configurado. Ejecuta: gcloud config set project TU_ID" >&2
  exit 1
fi
IMAGEN="${IMAGEN/PROYECTO/$PROYECTO}"

echo "Proyecto: $PROYECTO · región: $REGION · servicio: $SERVICIO"

# 1. APIs necesarias (idempotente: si ya están, no hace nada).
gcloud services enable run.googleapis.com artifactregistry.googleapis.com \
  cloudbuild.googleapis.com --project "$PROYECTO"

# 2. Repositorio de imágenes (idempotente).
gcloud artifacts repositories describe "$REPOSITORIO" \
  --location="$REGION" --project "$PROYECTO" >/dev/null 2>&1 ||
  gcloud artifacts repositories create "$REPOSITORIO" \
    --repository-format=docker --location="$REGION" --project "$PROYECTO" \
    --description="Imágenes del INCES LMS"

# 3. Compilar y publicar. Se construye desde `backend/`, que es donde vive el
#    Dockerfile; el contexto es el propio backend, no la raíz del repo.
if [ "${1:-}" != "--solo-env" ]; then
  echo "Construyendo la imagen…"
  gcloud builds submit "$RAIZ/backend" \
    --tag "$IMAGEN:latest" --project "$PROYECTO"
fi

# 4. Variables de entorno. Se pasan por `--set-env-vars` con `^@^` como
#    separador porque las URLs contienen comas y dos puntos.
ENV_ARGS=""
for clave in "${VARIABLES[@]}"; do
  valor="$(leer_env "$clave")"
  if [ -z "$valor" ]; then
    echo "  aviso: $clave está vacía en backend/.env; no se envía" >&2
    continue
  fi
  ENV_ARGS="${ENV_ARGS}${ENV_ARGS:+@}${clave}=${valor}"
done

# 5. Desplegar. `--min-instances=0` es la clave: sin tráfico, cero instancias y
#    cero coste. `--cpu-boost` acorta el arranque en frío, que es el precio de
#    escalar a cero.
echo "Desplegando…"
gcloud run deploy "$SERVICIO" \
  --image "$IMAGEN:latest" \
  --region "$REGION" \
  --project "$PROYECTO" \
  --allow-unauthenticated \
  --min-instances=0 \
  --max-instances=2 \
  --cpu=1 --memory=512Mi \
  --timeout=60 \
  --cpu-boost \
  --port=3000 \
  --set-env-vars "^@^${ENV_ARGS}"

URL="$(gcloud run services describe "$SERVICIO" --region "$REGION" \
  --project "$PROYECTO" --format='value(status.url)')"

echo
echo "Servicio desplegado en: $URL"
echo
echo "Comprueba la salud:"
echo "  curl -s $URL/salud"
echo
echo "Y cuando responda 200, recompila la web apuntando ahí:"
echo "  flutter build web --release --no-pub --no-wasm-dry-run \\"
echo "    --no-tree-shake-icons --dart-define-from-file=.env.json \\"
echo "    --dart-define=API_BASE_URL=$URL"
echo
echo "OJO: recuerda añadir el dominio de la web a CORS_ORIGINS en backend/.env"
echo "     y volver a correr este script con --solo-env."
