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
COMPOSE_APPS_REPO="$INPUT_COMPOSE_APPS_REPO"
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

  git clone $COMPOSE_APPS_REPO rootfs/apps
  cp rootfs/apps/$COMPOSE_FILE rootfs/apps/docker-compose.yml || true
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

fetch_os() {
  cd build/deploy/$MACHINE

  if [ "$1" = "base" ]; then
    NULIX_OS_VER="${BASE_NULIX_OS_VER}"
    LOG_ACT_INF "Fetching base NULIX OS v$NULIX_OS_VER for $MACHINE"

    if [ "$STEP_NAME" = "build-os" ]; then
      wget https://files.nulix.io/$MACHINE/boot-artifacts-v2025.01.tar.gz
      wget https://files.nulix.io/$MACHINE/kernel-artifacts-rpi-6.6.y.tar.gz
    fi
    wget https://files.nulix.io/$MACHINE/$OSTREE_ROOTFS-$NULIX_OS_VER.tar.gz
    wget https://files.nulix.io/$MACHINE/$OSTREE_REPO.tar.gz
  elif [ "$1" = "user" ]; then
    NULIX_OS_VER="${USER_NULIX_OS_VER}"
    LOG_ACT_INF "Fetching user's NULIX OS v$NULIX_OS_VER for $MACHINE"

    curl -f "https://api.nulix.io/ota/download?filename=$OSTREE_ROOTFS-$NULIX_OS_VER.tar.gz" \
      -H "Authorization: Bearer $API_KEY_SECRET" \
      -o $OSTREE_ROOTFS-$NULIX_OS_VER.tar.gz
    curl -f "https://api.nulix.io/ota/download?filename=$OSTREE_REPO.tar.gz" \
      -H "Authorization: Bearer $API_KEY_SECRET" \
      -o $OSTREE_REPO.tar.gz
  fi

  echo "NULIX_OS_VER=${NULIX_OS_VER}" >> $GITHUB_ENV

  tar xzf $OSTREE_REPO.tar.gz
  mv -v $OSTREE_REPO ../../../rootfs
  cp -v $OSTREE_ROOTFS-*.tar.gz ../../../rootfs
  rm $OSTREE_REPO.tar.gz

  cd ../../cache
  curl -s -f "https://api.nulix.io/ota/download?filename=$UPD8_KEYS" \
    -H "Authorization: Bearer $API_KEY_SECRET" \
    -o $UPD8_KEYS || true
  cd ../..
}

deploy_ota_update() {
  LOG_ACT_INF "Deploying OTA update"

  cd build/cache
  curl -X POST "https://api.nulix.io/ota/upload?filename=$UPD8_KEYS" \
    -H "Authorization: Bearer $API_KEY_SECRET" \
    -F "file=@$UPD8_KEYS"

  cd ../deploy/$MACHINE
  curl -X POST "https://api.nulix.io/ota/upload?filename=$OSTREE_ROOTFS-$NULIX_OS_VER.tar.gz" \
    -H "Authorization: Bearer $API_KEY_SECRET" \
    -F "file=@$OSTREE_ROOTFS-$NULIX_OS_VER.tar.gz"
  curl -X POST "https://api.nulix.io/ota/upload?filename=$OSTREE_REPO.tar.gz" \
    -H "Authorization: Bearer $API_KEY_SECRET" \
    -F "file=@$OSTREE_REPO.tar.gz"
}

LOG_ACT_DBG
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "============ Action Input Variables ============"
LOG_ACT_DBG "================================================"
LOG_ACT_DBG "STEP_NAME:         $STEP_NAME"
LOG_ACT_DBG "MACHINE:           $MACHINE"
LOG_ACT_DBG "DISTRO:            $DISTRO"
LOG_ACT_DBG "COMPOSE_APPS_REPO: $COMPOSE_APPS_REPO"
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
    # deploy_os
    ;;
  # update-apps)
  #   LOG_ACT_INF "Updating custom apps"
  #   OSTREE_COMMIT_MSG="Updated custom compose apps"
  #   init_nulix_build_env
  #   fetch_os user
  #   inject_apps
  #   deploy_ota_update
  #   ;;
  # update-os)
  #   LOG_ACT_INF "Updating NULIX OS"
  #   OSTREE_COMMIT_MSG="Updated base NULIX OS and added custom compose apps"
  #   init_nulix_build_env
  #   fetch_os base
  #   inject_apps
  #   deploy_ota_update
  #   ;;
  *)
    LOG_ACT_ERR "Unknown step: $STEP_NAME"
    return 1
    ;;
esac
