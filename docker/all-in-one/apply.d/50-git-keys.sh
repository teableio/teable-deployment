# git Ed25519 keypair -> override (generated only when missing, to avoid rotating keys behind already-issued tokens).
if [ -f "$OVERRIDE_FILE" ]; then
  echo "[skip] $OVERRIDE_FILE already exists (git keys not regenerated; to rotate, delete it and run again)"
elif PAIR="$(ed25519_pair)"; then
  write_git_override "$OVERRIDE_FILE" "${PAIR%%---SPLIT---*}" "${PAIR#*---SPLIT---}"
  echo "[ok] $OVERRIDE_FILE (git Ed25519 keys)"
else
  echo "[!] Could not generate Ed25519 keys (openssl lacks support and docker is unavailable). git-registry push/pull will not work;"
  echo "    re-run on a machine with a modern OpenSSL, or fill $OVERRIDE_FILE by hand."
fi
