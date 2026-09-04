#!/bin/bash
set -Eeuo pipefail
TARGET='/root/DP18-FULL-RECOVERY.sh'
STATE='/var/lib/dp18-full-recovery'
TMP="/tmp/dp18-hotfix-v12.$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

[ -n "${DP18_SFTP_PASSWORD:-}" ] || { echo 'ERRORE: DP18_SFTP_PASSWORD non impostata' >&2; exit 1; }
[ -f "$TARGET" ] || { echo 'ERRORE: recovery v1.1 non presente' >&2; exit 1; }
grep -q 'SCRIPT_VERSION="1.1.0-github"' "$TARGET" || { echo 'ERRORE: attesa v1.1.0-github installata' >&2; grep 'SCRIPT_VERSION=' "$TARGET" | head; exit 1; }
cp -a "$TARGET" "$TARGET.before-v1.2"

cat > "$TMP/recover.func" <<'FUNC_RECOVER_EOF'
recover_serial() {
  local pad num current serial_mha attempts
  pad="$(tr -d '\r\n ' < "$TARGET_FILE")"
  num=$((10#$pad))

  wait_paypoint 300 || fatal "paypoint.service non attivo prima del recupero matricola"

  current="$(read_machine_serial || true)"
  case "$current" in
    ""|*[!0-9]*) fatal "impossibile leggere /root/machine.serial" ;;
  esac

  if [ "$current" = "$num" ]; then
    say "Matricola MH430 gia' corretta: $pad"
    return 0
  fi

  [ "$current" = "0" ] || fatal "matricola corrente non-zero ($current) diversa dalla storica ($num): non sovrascrivo"

  serial_mha="$(make_serial_mha "$num" "$pad")"

  attempts=0
  [ -r "$SERIAL_ATTEMPTS" ] && attempts="$(cat "$SERIAL_ATTEMPTS" 2>/dev/null || echo 0)"

  while [ "$attempts" -lt 3 ]; do
    current="$(read_machine_serial || true)"
    [ "$current" = "$num" ] && break

    attempts=$((attempts+1))
    echo "$attempts" > "$SERIAL_ATTEMPTS"
    rm -f "$SERIAL_PATCH_SENT" "$SERIAL_EMPTY_SENT"

    trigger_update "$serial_mha" "programmatore matricola $pad su firmware DP18 3.12"
    date +%s > "$SERIAL_PATCH_SENT"
    say "Programmatore seriale consegnato; NON riavvio ancora la MH430"
    say "Attendo fino a 180 secondi che la patch dimostri di essere attiva (machine.serial=$num)"

    if ! wait_serial "$num" 180; then
      say "La matricola non e' comparsa prima del reboot: non invio MHA vuoto; riprovo il firmware patchato"
      continue
    fi

    say "Patch seriale ATTIVA: Raspberry ha ricevuto la matricola $pad dalla MH430"
    say "Attendo altri 10 secondi prima del reboot per lasciare completare il salvataggio EEPROM"
    sleep 10

    trigger_empty_mha
    date +%s > "$SERIAL_EMPTY_SENT"
    say "Reboot MH430 richiesto solo dopo conferma della matricola in RAM"

    sleep 45

    if wait_serial "$num" 180; then
      say "Matricola $pad presente anche dopo reboot MH430: persistenza EEPROM confermata"
      break
    fi

    say "Matricola persa dopo reboot MH430: riprovo il ciclo seriale"
    rm -f "$SERIAL_PATCH_SENT" "$SERIAL_EMPTY_SENT"
  done

  current="$(read_machine_serial || true)"
  [ "$current" = "$num" ] || fatal "recupero matricola $pad fallito dopo 3 tentativi"

  say "Matricola recuperata e confermata dalla MH430: $pad"
}
FUNC_RECOVER_EOF

awk -v repl="$TMP/recover.func" '
  BEGIN { skip=0 }
  /^recover_serial\(\) \{/ {
    while ((getline line < repl) > 0) print line
    close(repl)
    skip=1
    next
  }
  skip && /^ensure_final_312\(\) \{/ { skip=0 }
  !skip { print }
' "$TARGET" > "$TMP/new.sh"

sed -i \
  -e 's/# SCRIPT_VERSION=1\.1\.0/# SCRIPT_VERSION=1.2.0/' \
  -e 's/SCRIPT_VERSION="1\.1\.0-github"/SCRIPT_VERSION="1.2.0-github"/' \
  "$TMP/new.sh"

bash -n "$TMP/new.sh"
grep -q 'SCRIPT_VERSION="1.2.0-github"' "$TMP/new.sh"
grep -q 'NON riavvio ancora la MH430' "$TMP/new.sh"
install -m 700 "$TMP/new.sh" "$TARGET"

mkdir -p "$STATE"
rm -f "$STATE/FAILED" "$STATE/serial_patch_sent" "$STATE/serial_empty_sent" "$STATE/serial_attempts" "$STATE/final312_sent" "$STATE/config_done"

echo 'Hotfix v1.2 applicato: il reboot MH430 verra eseguito solo dopo comparsa della matricola.'
echo "SHA256 recovery: $(sha256sum "$TARGET" | awk '{print $1}')"
DP18_SFTP_PASSWORD="$DP18_SFTP_PASSWORD" exec "$TARGET" --bootstrap
