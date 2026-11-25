#!/usr/bin/env bash
# Give an install that predates generated app secrets its own SECRET_KEY.
#   ./adopt-secret-key.sh    Append SECRET_KEY and the decrypt-only *_OLD variables to teable-app.env
# Such an install runs on the app's built-in values, which are public. SECRET_KEY replaces them all at
# once, so on its own it would make stored data unreadable: the *_OLD variables keep reading what was
# stored under the old values until the app has re-encrypted it. Everyone signs in again afterwards.
# A later app version refuses to start without SECRET_KEY, so run this before upgrading to it.
# The whole procedure, including when the *_OLD lines can go: "App secrets" in README.md.
set -euo pipefail
cd "$(dirname "$0")"
# Assets (compose files, .env) live alongside this script; the cd-guard below also supports running it from a parent directory.
[ -f lib.sh ] || { [ -d ../docker/all-in-one ] && cd ../docker/all-in-one; }
. ./lib.sh

[ $# -eq 0 ] || { echo "Usage: ./adopt-secret-key.sh"; exit 1; }

APP_ENV=teable-app.env
if [ ! -f "$APP_ENV" ]; then
  echo "[x] No $APP_ENV here. Run ./apply.sh local|server --with-app first: it creates the file."
  exit 1
fi
if grep -qE '^SECRET_KEY=.' "$APP_ENV"; then
  echo "[ok] $APP_ENV already has a SECRET_KEY: nothing to do."
  exit 0
fi
# A blank SECRET_KEY= line or an *_OLD variable is a state this script did not leave behind: a second
# SECRET_KEY line or a second value for the same *_OLD would silently win over it, so stop instead.
if grep -qE '^(SECRET_KEY|[A-Z0-9_]+_OLD)=' "$APP_ENV"; then
  echo "[x] $APP_ENV already has a blank SECRET_KEY line or an *_OLD variable: nothing changed."
  echo "    Remove those lines if they are leftovers, then run this again."
  exit 1
fi

# The values the app has been running on with nothing set: public constants of the app, the same on
# every such install. Sign-in secrets get no *_OLD on purpose: a public value there would keep
# forged sessions valid.
{
  printf '\n'
  printf '%s\n' \
    '# Added by adopt-secret-key.sh. The *_OLD lines only read what was stored before SECRET_KEY existed;' \
    '# remove them as "App secrets" in README.md describes. Never change or remove SECRET_KEY itself.'
  printf 'SECRET_KEY=%s\n' "$(rand 32)"
  printf '%s\n' \
    'BACKEND_ENV_VARIABLE_SECRET_OLD=defaultSecretKey' \
    'BACKEND_AI_CONFIG_ENCRYPTION_SECRET_OLD=defaultSecretKey' \
    'BACKEND_THIRD_PARTY_CREDENTIAL_ENCRYPTION_SECRET_OLD=defaultSecretKey' \
    'BACKEND_INVITATION_SECRET_OLD=defaultSecretKey' \
    'BACKEND_DATA_DB_URL_ENCRYPTION_KEY_OLD=ed333d03ac334ea2' \
    'BACKEND_DATA_DB_URL_ENCRYPTION_IV_OLD=3c50b81e61cb7f52'
} >> "$APP_ENV"

echo "[ok] $APP_ENV now has a SECRET_KEY and the *_OLD variables that keep stored data readable."
echo "[next] 1. docker compose up -d   (restarts the app; everyone signs in again)"
echo "       2. In the app, open System Admin -> Key rotation: refresh app credentials under"
echo "          \"JWT credentials\", then re-encrypt under \"Stored ciphertexts\" (dry run first)."
echo "          No such page in System Admin: see \"App secrets\" in README.md."
echo "       3. Back up $APP_ENV together with .env, and remove the *_OLD lines later as"
echo "          \"App secrets\" in README.md describes."
