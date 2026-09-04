#!/bin/bash
set -Eeuo pipefail

# DP18 Recovery installer stabile
# Costruisce e avvia la v1.2.0 validata sul campo senza salvare credenziali su GitHub.

PINNED_COMMIT='81e5e45e7fa1941e60e04403816b39283ec74b6b'
RAW_BASE="https://raw.githubusercontent.com/MicrohardAssistenza/mh499-cctalk/${PINNED_COMMIT}/dp18-recovery"
TMP="/tmp/dp18-final-installer.$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

[ -n "${DP18_SFTP_PASSWORD:-}" ] || {
  echo 'ERRORE: DP18_SFTP_PASSWORD non impostata' >&2
  exit 1
}

# Scarica gli helper già validati dal commit immutabile.
curl -k -fL --connect-timeout 15 "$RAW_BASE/install-v1.1.sh" -o "$TMP/install-v1.1.sh"
curl -k -fL --connect-timeout 15 "$RAW_BASE/hotfix-v1.2.sh" -o "$TMP/hotfix-v1.2.sh"

# L'installer v1.1 verifica già lo SHA256 della base completa. Gli imponiamo
# però di prendere anche la base dallo stesso commit immutabile e gli togliamo
# soltanto l'exec finale: il bootstrap deve partire solo DOPO l'hotfix v1.2.
sed -i \
  -e "s#^BASE_URL=.*#BASE_URL='${RAW_BASE}/DP18-FULL-RECOVERY-GITHUB.sh'#" \
  -e '/^exec env DP18_SFTP_PASSWORD=.*--bootstrap$/d' \
  "$TMP/install-v1.1.sh"

chmod 700 "$TMP/install-v1.1.sh" "$TMP/hotfix-v1.2.sh"

DP18_SFTP_PASSWORD="$DP18_SFTP_PASSWORD" "$TMP/install-v1.1.sh"

grep -q 'SCRIPT_VERSION="1.1.0-github"' /root/DP18-FULL-RECOVERY.sh || {
  echo 'ERRORE: costruzione v1.1 fallita' >&2
  exit 1
}

# Applica la correzione validata: il reboot MH430 viene eseguito SOLO dopo
# che il Raspberry ha realmente ricevuto la matricola dalla patch 3.12.
DP18_SFTP_PASSWORD="$DP18_SFTP_PASSWORD" exec "$TMP/hotfix-v1.2.sh"
