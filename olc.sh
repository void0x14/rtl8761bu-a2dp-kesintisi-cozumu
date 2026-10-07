#!/usr/bin/env bash
# olc.sh — A2DP paket boşluklarını ölç (ses kesintisi = paket boşluğu)
#
# Kullanım: sudo bash olc.sh [saniye]     (varsayılan 300)
# Kulaklıkla MÜZİK ÇALIYOR olmalı.

set -eu

SURE="${1:-300}"
SNOOP="/tmp/olcum-$(date +%s).snoop"

command -v btmon >/dev/null 2>&1 || { echo "HATA: btmon yok (bluez-utils kur)"; exit 2; }
[ "$(id -u)" = 0 ] || { echo "HATA: root gerekli. 'sudo bash olc.sh'"; exit 1; }

echo "=== A2DP boşluk ölçümü ==="
echo "süre: ${SURE} sn   dosya: $SNOOP"
echo "müzik çalıyor olmalı. başlatılıyor..."
echo

btmon -w "$SNOOP" >/dev/null 2>&1 &
BTPID=$!
sleep "$SURE"
kill "$BTPID" 2>/dev/null || true
sleep 1
echo "yakalama bitti, çözümleniyor..."
echo

btmon -r "$SNOOP" 2>/dev/null \
  | grep -E "^[<>] ACL:" \
  | grep -oE "\[hci0\] [0-9.]+" | awk '{print $2}' \
  | python3 -c "
import sys, statistics
ts = sorted(float(x) for x in sys.stdin if x.strip())
if len(ts) < 100:
    print('YETERSIZ VERI: yalniz %d paket. Muzik caliyor muydu?' % len(ts))
    sys.exit(1)
g = [ts[i+1]-ts[i] for i in range(len(ts)-1)]
buyuk = [x for x in g if x > 0.05]
print('paket sayisi   :', len(ts))
print('sure           : %.1f s' % (ts[-1]-ts[0]))
print('medyan aralik  : %.1f ms' % (statistics.median(g)*1000))
print('p99 aralik     : %.1f ms' % (sorted(g)[int(len(g)*0.99)]*1000))
print('maks aralik    : %.0f ms' % (max(g)*1000))
print('>50ms bosluk   : %d' % len(buyuk))
print()
if len(buyuk) == 0 and max(g) < 0.05:
    print('SONUC: SAGLIKLI — kesinti yok.')
elif max(g) > 0.2:
    print('SONUC: BOZUK — firmware kaynakli kopma var.')
    print('Cozum: bash coz.sh')
else:
    print('SONUC: HAFIF — xrun/yuk olabilir. pw-top ERR sutununa bak.')
"
echo
echo "(snoop dosyası: $SNOOP)"
