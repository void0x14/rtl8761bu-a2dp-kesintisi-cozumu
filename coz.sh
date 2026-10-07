#!/usr/bin/env bash
# coz.sh — RTL8761BU bozuk firmware'i (0xdfc6d922) iyi sürümle (0x09a98a6b) değiştir
# Geri alınabilir: önce yedekler.
#
# Kullanım: sudo bash coz.sh
# Bu betik onay istemeden değişiklik yapar; önce tani.sh çalıştırın.

set -eu

BEKLENEN_SHA="148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76"
FW_DIZIN="/usr/lib/firmware/rtl_bt"
FW_AD="rtl8761bu_fw.bin"
YEDEK_DIZIN="/root/rtl8761bu-fw-yedek"
INDIRME_URL="https://raw.githubusercontent.com/void0x14/rtl8761bu-a2dp-kesintisi-cozumu/main/veri/rtl8761bu_fw.bin"

[ "$(id -u)" = 0 ] || { echo "HATA: root gerekli. 'sudo bash coz.sh'"; exit 1; }

echo "=== RTL8761BU firmware düzeltmesi ==="
echo

# --- 1. Mevcut durumu göster ---
echo "--- 1) Mevcut firmware ---"
dmesg | grep "RTL: fw version" | tail -1 || true
echo

# --- 2. Yedekle ---
echo "--- 2) Yedekleniyor ---"
mkdir -p "$YEDEK_DIZIN"
for f in "$FW_DIZIN/$FW_AD" "$FW_DIZIN/$FW_AD.zst" "$FW_DIZIN/rtl8761bu_config.bin.zst"; do
  [ -f "$f" ] && cp -av "$f" "$YEDEK_DIZIN/" || true
done
echo "yedek: $YEDEK_DIZIN"
echo

# --- 3. İndir + doğrula ---
echo "--- 3) İyi firmware indiriliyor ---"
TMP="$(mktemp /tmp/rtl8761bu_fw.XXXXXX.bin)"
curl -fsSL -o "$TMP" "$INDIRME_URL" || { echo "HATA: indirme başarısız"; exit 1; }

GERCEK_SHA="$(sha256sum "$TMP" | awk '{print $1}')"
if [ "$GERCEK_SHA" != "$BEKLENEN_SHA" ]; then
  echo "HATA: sha256 uyuşmuyor!"
  echo "  beklenen: $BEKLENEN_SHA"
  echo "  gerçek  : $GERCEK_SHA"
  rm -f "$TMP"; exit 1
fi
echo "[+] sha256 doğrulandı: $GERCEK_SHA"
echo

# --- 4. Yerleştir ---
echo "--- 4) Yerleştiriliyor ---"
cp -av "$TMP" "$FW_DIZIN/$FW_AD"
rm -f "$TMP"
ls -la "$FW_DIZIN/$FW_AD"
echo

# --- 5. Sürücüyü yeniden yükle ---
echo "--- 5) btusb yeniden yükleniyor ---"
modprobe -r btusb btrtl 2>/dev/null || true
sleep 2
modprobe btusb
sleep 6
echo

# --- 6. Doğrula ---
echo "--- 6) Doğrulama ---"
YENI="$(dmesg | grep "RTL: fw version" | tail -1 | grep -oE "0x[0-9a-f]+" || true)"
echo "yüklü firmware: $YENI"
if [ "$YENI" = "0x09a98a6b" ]; then
  echo
  echo "=== BAŞARILI ==="
  echo "Kulaklığı yeniden bağlayın, sonra: bash olc.sh 300"
else
  echo
  echo "!!! firmware beklenen sürüme yükselmedi: $YENI"
  echo "    .zst dosyası .bin'i gölgeliyor olabilir. Kontrol:"
  echo "      ls -la $FW_DIZIN/$FW_AD*"
  exit 1
fi
