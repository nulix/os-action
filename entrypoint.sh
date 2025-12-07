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

  if [ -z "$API_KEY_SECRET" ]; then
    LOG_ACT_ERR "API_KEY secret is not set!"
    exit 1
  fi

  if [ -z "$MACHINE_REG_TOKEN_SECRET" ]; then
    LOG_ACT_ERR "MACHINE_REG_TOKEN secret is not set!"
    exit 1
  fi

  source /nulix-os-venv/bin/activate
  west init -m https://github.com/nulix/nulix-os.git nulix-os
  cd nulix-os
  west update

  MACHINE=$MACHINE DISTRO=$DISTRO source tools/setup-environment
}

fetch_apps() {
  LOG_ACT_INF "Fetching compose apps"

  git clone $APPS_REPO rootfs/apps

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

LOG_ACT_DBG
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "============ Action Input Variables ============"
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "STEP_NAME:         $STEP_NAME"
LOG_ACT_DBG "MACHINE:           $MACHINE"
LOG_ACT_DBG "DISTRO:            $DISTRO"
LOG_ACT_DBG "APPS_REPO:         $APPS_REPO"
LOG_ACT_DBG "COMPOSE_FILE:      $COMPOSE_FILE"
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
  *)
    LOG_ACT_ERR "Unknown step: $STEP_NAME"
    return 1
    ;;
esac
