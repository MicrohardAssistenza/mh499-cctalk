#!/bin/bash
set -Eeuo pipefail

BASE_URL='https://raw.githubusercontent.com/MicrohardAssistenza/mh499-cctalk/main/dp18-recovery/DP18-FULL-RECOVERY-GITHUB.sh'
BASE_SHA='0e60ff118aaf36b6e51dceca4b94e1a183a4db759caa67527202ac52a48c4ade'
OUT='/root/DP18-FULL-RECOVERY.sh'
TMP="/tmp/dp18-full-v11.$$"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP"

[ -n "${DP18_SFTP_PASSWORD:-}" ] || { echo 'ERRORE: DP18_SFTP_PASSWORD non impostata' >&2; exit 1; }

curl -k -fL --connect-timeout 15 "$BASE_URL" -o "$TMP/base.sh"
echo "$BASE_SHA  $TMP/base.sh" | sha256sum -c -

START="$(grep -n '^make_serial_mha() {' "$TMP/base.sh" | head -1 | cut -d: -f1)"
END="$(grep -n '^wait_serial() {' "$TMP/base.sh" | head -1 | cut -d: -f1)"
[ -n "$START" ] && [ -n "$END" ] && [ "$END" -gt "$START" ] || { echo 'ERRORE: funzione make_serial_mha non individuata' >&2; exit 1; }

head -n $((START-1)) "$TMP/base.sh" > "$TMP/new.sh"
cat >> "$TMP/new.sh" <<'PATCHFUNC'
make_serial_mha() {
  local target_num="$1" target_pad="$2"
  local out="$PAYLOADS/UsbUpdate_DP18_3.12_SERIAL_${target_pad}.mha"
  local hook_off=$((0x2174))
  local shell_off=$((0x4110c))
  local cfg_lit_off=$((0x41134))

  if [ -f "$out" ]; then
    local rb hk cfg
    rb="$(od -An -tu4 -N4 -j "$SERIAL_OFFSET" "$out" 2>/dev/null | tr -d ' \n')"
    hk="$(od -An -tx1 -N4 -j "$hook_off" "$out" 2>/dev/null | tr -d ' \n')"
    cfg="$(od -An -tx1 -N4 -j "$cfg_lit_off" "$out" 2>/dev/null | tr -d ' \n')"
    if [ "$rb" = "$target_num" ] && [ "$hk" = "3ef0cabf" ] && [ "$cfg" = "4c6e0010" ]; then
      echo "$out"
      return 0
    fi
  fi

  [ "$(sha256sum "$OFFICIAL312" | awk '{print $1}')" = "$OFFICIAL312_SHA" ] \
    || fatal "firmware ufficiale DP18 3.12 non integro prima del patch seriale"

  cp "$OFFICIAL312" "$out"

  local original_hook
  original_hook="$(od -An -tx1 -N4 -j "$hook_off" "$out" | tr -d ' \n')"
  [ "$original_hook" = "90b5d9b0" ] \
    || fatal "hook DP18 3.12 inatteso a 0x2174: $original_hook"

  # Hook seriale nativo DP18 3.12. La routine di salvataggio EEPROM e il punto
  # di hook sono invariati; la struttura config RAM e' 0x10006E4C sulla 3.12.
  printf '\076\360\312\277' \
    | dd of="$out" bs=1 seek="$hook_off" conv=notrunc 2>/dev/null

  printf '%s' 'kLXZsAKvCEsISpxolEII0JpgGEZO9j084EcAKAHRAkucYELyLxMYR0xuABDvvq3eAAAAAAAAAAA=' \
    | base64 -d \
    | dd of="$out" bs=1 seek="$shell_off" conv=notrunc 2>/dev/null

  local b0 b1 b2 b3
  b0=$(( target_num & 255 ))
  b1=$(( (target_num >> 8) & 255 ))
  b2=$(( (target_num >> 16) & 255 ))
  b3=$(( (target_num >> 24) & 255 ))

  printf "\\$(printf '%03o' "$b0")\\$(printf '%03o' "$b1")\\$(printf '%03o' "$b2")\\$(printf '%03o' "$b3")" \
    | dd of="$out" bs=1 seek="$SERIAL_OFFSET" conv=notrunc 2>/dev/null
  sync

  local readback hook_read cfg_read size
  readback="$(od -An -tu4 -N4 -j "$SERIAL_OFFSET" "$out" | tr -d ' \n')"
  hook_read="$(od -An -tx1 -N4 -j "$hook_off" "$out" | tr -d ' \n')"
  cfg_read="$(od -An -tx1 -N4 -j "$cfg_lit_off" "$out" | tr -d ' \n')"
  size="$(wc -c < "$out" | tr -d ' ')"

  [ "$readback" = "$target_num" ] || fatal "readback patch matricola 3.12 fallito"
  [ "$hook_read" = "3ef0cabf" ] || fatal "hook seriale 3.12 non applicato"
  [ "$cfg_read" = "4c6e0010" ] || fatal "literal config RAM 3.12 errato"
  [ "$size" = "267520" ] || fatal "dimensione MHA 3.12 patchato inattesa: $size"

  echo "$out"
}

PATCHFUNC
tail -n +"$END" "$TMP/base.sh" >> "$TMP/new.sh"

sed -i '0,/# SCRIPT_VERSION=1.0.0/s//# SCRIPT_VERSION=1.1.0/' "$TMP/new.sh"
sed -i '0,/SCRIPT_VERSION="1.0.1-github"/s//SCRIPT_VERSION="1.1.0-github"/' "$TMP/new.sh"
sed -i '0,/recupera la matricola MH430 via patch EEPROM validata su 3.10/s//recupera la matricola MH430 via patch EEPROM nativa DP18 3.12/' "$TMP/new.sh"
sed -i 's/programmatore matricola \$pad su firmware temporaneo 3.10/programmatore matricola \$pad su firmware DP18 3.12/' "$TMP/new.sh"
sed -i '/^[[:space:]]*rm -f "\$FAILED_FILE"$/a\  rm -f "$SERIAL_PATCH_SENT" "$SERIAL_EMPTY_SENT" "$SERIAL_ATTEMPTS" "$FINAL312_SENT" "$CONFIG_DONE"' "$TMP/new.sh"

bash -n "$TMP/new.sh"
grep -q 'SCRIPT_VERSION="1.1.0-github"' "$TMP/new.sh"
grep -q 'cfg_lit_off=\$((0x41134))' "$TMP/new.sh"

install -m 700 "$TMP/new.sh" "$OUT"
echo "Installata DP18 FULL RECOVERY v1.1.0-github"
echo "SHA256: $(sha256sum "$OUT" | awk '{print $1}')"
exec env DP18_SFTP_PASSWORD="$DP18_SFTP_PASSWORD" "$OUT" --bootstrap
