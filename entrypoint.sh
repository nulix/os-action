#!/usr/bin/env sh
set -e
set -o errexit

RED="\\e[31m"
YELLOW="\\e[33m"
BLUE="\\e[34m"
WHITE="\\e[37m"
NC="\\e[0m"

STEP_NAME="$INPUT_STEP_NAME"
MACHINE="$INPUT_MACHINE"
DISTRO="$INPUT_DISTRO"
APPS_REPO="$INPUT_APPS_REPO"
COMPOSE_FILE="$INPUT_COMPOSE_FILE"
S3_BUCKET="$INPUT_S3_BUCKET"
S3_ENDPOINT="$INPUT_S3_ENDPOINT"
JOB_ID="$INPUT_JOB_ID"

LOG_ACT_ERR() {
  echo -e "${RED}[nulix/os-action]:${NC} ${@}"
}

LOG_ACT_WRN() {
  echo -e "${YELLOW}[nulix/os-action]:${NC} ${@}"
}

LOG_ACT_INF() {
  echo -e "${BLUE}[nulix/os-action]:${NC} ${@}"
}

LOG_ACT_DBG() {
  echo -e "${WHITE}[nulix/os-action]:${NC} ${@}"
}

init_nulix_build_env() {
  LOG_ACT_INF "Initializing NULIX OS build environment"

  if [ -z "$MACHINE_REG_TOKEN" ]; then
    LOG_ACT_ERR "MACHINE_REG_TOKEN secret is not set!"
    exit 1
  fi

  if [ -z "$UPD8_KEYS" ]; then
    LOG_ACT_WRN "UPD8_KEYS secret is not set!"
  fi

  source /nulix-os-venv/bin/activate
  west init -m https://github.com/nulix/nulix-os.git nulix-os
  cd nulix-os
  west update

  MACHINE=$MACHINE DISTRO=$DISTRO source tools/setup-environment
}

fetch_apps() {
  LOG_ACT_INF "Fetching compose apps"

  git clone $APPS_REPO rootfs/apps/apps

  if [ "$VIRT_BACKEND" = "docker" ]; then
    cp rootfs/apps/$COMPOSE_FILE rootfs/apps/docker-compose.yml || true
  fi
}

build_bsp() {
  LOG_ACT_INF "Building BSP for $MACHINE"
  nulix build bsp
}

build_rootfs() {
  LOG_ACT_INF "Building rootfs for $MACHINE"
  nulix build rootfs
}

build_ostree_repo() {
  LOG_ACT_INF "Building ostree-repo for $MACHINE"
  nulix build ostree-repo
}

build_image() {
  LOG_ACT_INF "Building bootable disk image for $MACHINE"
  nulix build image
}

build_os() {
  LOG_ACT_INF "Building NULIX OS for $MACHINE"
  nulix build os
}

upload_os() {
  LOG_ACT_INF "Uploading OS image to MinIO for $MACHINE"

  source /nulix-os-venv/bin/activate

  FILES=$(ls nulix-os/build/deploy/${MACHINE}/nulix-os-*.img.bz2 2>/dev/null || true)
  if [ -z "$FILES" ]; then
    LOG_ACT_ERR "No OS image found to upload!"
    exit 1
  fi

  for f in $FILES; do
    LOG_ACT_DBG "Uploading $f..."
    aws --endpoint-url ${S3_ENDPOINT} s3 cp "$f" s3://${S3_BUCKET}/job-${JOB_ID}/
  done
}

LOG_ACT_DBG
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "============ Action Input Variables ============"
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "STEP_NAME:      $STEP_NAME"
LOG_ACT_DBG "MACHINE:        $MACHINE"
LOG_ACT_DBG "DISTRO:         $DISTRO"
LOG_ACT_DBG "APPS_REPO:      $APPS_REPO"
LOG_ACT_DBG "COMPOSE_FILE:   $COMPOSE_FILE"
LOG_ACT_DBG "SSH_PUBLIC_KEY: $SSH_PUBLIC_KEY"
LOG_ACT_DBG "SSL_CERT:       $SSL_CERT"
LOG_ACT_DBG "UPD8_API_URL:   $UPD8_API_URL"
LOG_ACT_DBG "S3_BUCKET:      $S3_BUCKET"
LOG_ACT_DBG "S3_ENDPOINT:    $S3_ENDPOINT"
LOG_ACT_DBG "JOB_ID:         $JOB_ID"
LOG_ACT_DBG "================================================"
LOG_ACT_DBG

case "$STEP_NAME" in
  build-os)
    LOG_ACT_INF "Building NULIX OS"
    # OSTREE_COMMIT_MSG="Added custom compose apps"
    init_nulix_build_env
    fetch_apps
    build_os
    ;;
  upload-os)
    LOG_ACT_INF "Uploading OS image to MinIO"
    upload_os
    ;;
  *)
    LOG_ACT_ERR "Unknown step: $STEP_NAME"
    return 1
    ;;
esac
