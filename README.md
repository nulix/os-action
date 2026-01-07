# Build NULIX OS with custom apps

This GitHub Action builds NULIX OS with custom apps and uploads the image as an Actions artifact.

Debug it locally using `act`:

```bash
act --container-architecture linux/arm64 \
  -P ubuntu-24.04-arm=-self-hosted \
  --input MACHINE=rpi3 \
  --input DISTRO=alpine-none \
  --input APPS_REPO=https://github.com/nulix/apps.git \
  --input APPS_GIT_REF=1.x \
  --input S3_BUCKET=user-id-1-project-id-2 \
  --input S3_ENDPOINT=http://minio:9000 \
  --input JOB_ID=1 \
  -s UPD8_KEYS=test123 \
  -s MACHINE_REG_TOKEN=123test \
  -s AWS_ACCESS_KEY_ID=minio \
  -s AWS_SECRET_ACCESS_KEY=minio123 \
  --var SSH_PUBLIC_KEY=ssh-dummy-key \
  --var SSL_CERT=ssl-dummy-cert \
  --var UPD8_API_URL=https://api.nulix.local
```
