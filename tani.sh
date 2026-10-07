#!/usr/bin/env bash
# tani.sh — RTL8761BU A2DP kesintisi teşhisi
# Çıkış: 0 = bozuk firmware bulundu, 1 = sorun bu değil, 2 = araç eksik

set -u

echo "=== RTL8761BU A2DP kesinti teşhisi ==="
echo "tarih: $(date -Is)"
echo

# --- Araçlar ---
eksik=0
for a in dmesg lsusb; do
  command -v "$a" >/dev/null 2>&1 || { echo "[!] eksik araç: $a"; eksik=1; }
done
[ "$eksik" = 1 ] && { echo; echo "SONUÇ: araç eksik"; exit 2; }

# --- 1. Adaptör ---
echo "--- 1) Adaptör ---"
adaptor=$(lsusb 2>/dev/null | grep -iE "2357:0604|0bda:8771|2b89:8761")
if [ -z "$adaptor" ]; then
  echo "[x] RTL8761BU tabanlı USB adaptör bulunamadı."
  echo
  echo "SONUÇ: bu çözüm geçerli değil (adaptör farklı)."
  exit 1
fi
echo "[+] bulundu: $adaptor"

# --- 2. Firmware sürümü ---
echo
echo "--- 2) Firmware sürümü ---"
fw="$(dmesg 2>/dev/null | grep "RTL: fw version" | tail -1 | awk '{print $NF}')"
# dmesg yetki isterse journalctl dene
if [ -z "$fw" ] && command -v journalctl >/dev/null 2>&1; then
  fw="$(journalctl -k -b 0 --no-pager 2>/dev/null | grep "RTL: fw version" | tail -1 | awk '{print $NF}')"
fi
if [ -z "$fw" ]; then
  echo "[!] firmware sürümü okunamadı (dongle takılı değil veya yetki yok)."
  echo "    Deneyin: sudo dmesg | grep 'RTL: fw version'"
  exit 2
fi
echo "[i] yüklü firmware: $fw"

if [ "$fw" = "0xdfc6d922" ]; then
  echo "[x] >>> BİLİNEN BOZUK SÜRÜM <<<"
  bozuk=1
elif [ "$fw" = "0x09a98a6b" ]; then
  echo "[+] iyi sürüm yüklü (0x09a98a6b)."
  bozuk=0
else
  echo "[?] bilinmeyen sürüm. Bilinen bozuk: 0xdfc6d922, bilinen iyi: 0x09a98a6b"
  bozuk=0
fi

# --- 3. Sessizlik testi (günlük) ---
echo
echo "--- 3) Kesinti sessiz mi? (günlük taraması) ---"
if command -v journalctl >/dev/null 2>&1; then
  # Şimdiki oturum (firmware düzeltmesinden sonrası için anlamlı)
  sessiz_bu=$(journalctl -b 0 --no-pager 2>/dev/null | grep -iE "hci0|btusb" \
    | grep -icE "disconnect|reset|error|timeout" || true)
  agir_bu=$(journalctl -b 0 --no-pager 2>/dev/null | grep -c "terminated unexpectedly" || true)
  # Tüm geçmiş (eski firmware dönemini de kapsar)
  agir_all=$(journalctl -b all --no-pager 2>/dev/null | grep -c "terminated unexpectedly" || true)
  echo "[i] bu oturum  — hci0/btusb hata : ${sessiz_bu:-0}   (0 ise kopma SESSİZ)"
  echo "[i] bu oturum  — ağır yıkım      : ${agir_bu:-0}"
  echo "[i] tüm geçmiş — ağır yıkım      : ${agir_all:-0}   (eski fw dönemi dâhil)"
else
  echo "[!] journalctl yok, bu adım atlandı."
fi

# --- 4. Ortam ---
echo
echo "--- 4) Ortam ---"
wlan="$(iw dev 2>/dev/null | grep -c Interface || true)"; wlan="${wlan:-0}"
echo "[i] kablosuz arayüz : $wlan (0 ise 2,4 GHz WiFi yok)"
echo "[i] USB autosuspend : $(cat /sys/module/btusb/parameters/enable_autosuspend 2>/dev/null || echo '?') (N = kapalı)"
echo "[i] PipeWire        : $(pipewire --version 2>/dev/null | tail -1 || echo '?')"
echo "[i] BlueZ           : $(bluetoothctl --version 2>/dev/null || echo '?')"

# --- Sonuç ---
echo
echo "=== SONUÇ ==="
if [ "${bozuk:-0}" = 1 ]; then
  echo "RTL8761BU + BOZUK FIRMWARE (0xdfc6d922) tespit edildi."
  echo "Çözüm: bash coz.sh   (ayrıntı: cozum/02-COZUM.md)"
  exit 0
else
  echo "Bozuk firmware tespit edilmedi."
  echo "Farklı nedenler: cozum/04-AI-AJANLARI-ICIN.md"
  exit 1
fi
