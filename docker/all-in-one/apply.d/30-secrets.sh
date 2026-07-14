# Fill in secret and image defaults (values already set are never touched).
set_if_blank OPENSANDBOX_API_KEY "$(rand 32)" "$ENV_FILE"
set_if_blank SESSION_SECRET "$(rand 32)" "$ENV_FILE"
set_if_blank S3_ACCESS_KEY "teable-$(rand 6)" "$ENV_FILE"
set_if_blank S3_SECRET_KEY "$(rand 24)" "$ENV_FILE"

if [ "$WITH_APP" = 1 ]; then
  # Image default: latest works out of the box for Docker deploys (run ./pin-image.sh to pin a version)
  set_if_blank TEABLE_IMAGE "ghcr.io/teableio/teable:latest" "$ENV_FILE"
  # App secrets: all of these have hardcoded defaults in the source, so public deployments must generate them per host
  set_if_blank TEABLE_DB_PASSWORD "$(rand 16)" "$ENV_FILE"
  set_if_blank TEABLE_REDIS_PASSWORD "$(rand 16)" "$ENV_FILE"
  set_if_blank SANDBOX_JWT_SECRET "$(rand 32)" "$ENV_FILE"
  # aes-128-cbc: key/iv must each be 16 bytes (rand 8 -> 16 hex characters)
  set_if_blank BACKEND_STORAGE_ENCRYPTION_KEY "$(rand 8)" "$ENV_FILE"
  set_if_blank BACKEND_STORAGE_ENCRYPTION_IV "$(rand 8)" "$ENV_FILE"
fi
