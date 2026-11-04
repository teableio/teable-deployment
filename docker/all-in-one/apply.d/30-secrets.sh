# Fill in secret and image defaults (values already set are never touched).
set_if_blank OPENSANDBOX_API_KEY "$(rand 32)" "$ENV_FILE"
set_if_blank SESSION_SECRET "$(rand 32)" "$ENV_FILE"
set_if_blank S3_ACCESS_KEY "teable-$(rand 6)" "$ENV_FILE"
set_if_blank S3_SECRET_KEY "$(rand 24)" "$ENV_FILE"

if [ "$WITH_APP" = 1 ]; then
  # An app that already ran (its DB password exists) gets no SECRET_KEY below. Checked before the
  # DB password itself gets filled.
  EXISTING_APP=0
  grep -qE '^TEABLE_DB_PASSWORD=.+' "$ENV_FILE" && EXISTING_APP=1

  # Image default: latest works out of the box for Docker deploys (run ./pin-image.sh to pin a version)
  set_if_blank TEABLE_IMAGE "ghcr.io/teableio/teable:latest" "$ENV_FILE"
  # App secrets: all of these have hardcoded defaults in the source, so public deployments must generate them per host
  set_if_blank TEABLE_DB_PASSWORD "$(rand 16)" "$ENV_FILE"
  set_if_blank TEABLE_REDIS_PASSWORD "$(rand 16)" "$ENV_FILE"
  set_if_blank SANDBOX_JWT_SECRET "$(rand 32)" "$ENV_FILE"
  # aes-128-cbc: key/iv must each be 16 bytes (rand 8 -> 16 hex characters)
  set_if_blank BACKEND_STORAGE_ENCRYPTION_KEY "$(rand 8)" "$ENV_FILE"
  set_if_blank BACKEND_STORAGE_ENCRYPTION_IV "$(rand 8)" "$ENV_FILE"

  # teable-app.env: app variables compose.app.yaml does not set itself, one KEY=value per line.
  # Created once, never rewritten. SECRET_KEY is the root the app derives its sign-in secrets and
  # most stored-data keys from, so a fresh install needs only this one. It lives here rather than in
  # compose.app.yaml because compose would pass it blank when unset, and the app takes a blank as a
  # real key. An app that already ran without it has data encrypted under the keys it ran on; a
  # SECRET_KEY now would strand that data, so it gets none.
  if [ ! -f teable-app.env ]; then
    (
      umask 077
      printf '%s\n' \
        '# Environment for the Teable app container, one KEY=value per line (gitignored; back it up with .env).' \
        '# SECRET_KEY protects stored data: never change or remove it by hand -- see "App secrets" in README.md.' \
        > teable-app.env
      if [ "$EXISTING_APP" = 0 ]; then
        printf 'SECRET_KEY=%s\n' "$(rand 32)" >> teable-app.env
      fi
    )
    echo "[init] teable-app.env"
  fi
  if ! grep -qE '^SECRET_KEY=.' teable-app.env; then
    echo "[!] No SECRET_KEY in teable-app.env: this app predates generated app secrets. Leave it that way:"
    echo "    adding one by hand signs everyone out and makes stored data unreadable."
  fi
fi
