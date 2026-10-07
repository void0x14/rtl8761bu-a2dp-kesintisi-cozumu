# AI Ajanları İçin Hızlı Teşhis Protokolü

Bu bölüm, bir AI ajanının (veya deneyimli bir kullanıcının) bu sorunu
**dakikalar içinde** teşhis edip çözmesi için yazıldı. Tahmin yok, ölçüm var.

## Karar ağacı (kopyala-çalıştır)

### Adım 1 — Adaptör RTL8761BU mu?

```bash
lsusb | grep -iE "2357:0604|0bda:8771|2b89:8761"
sudo dmesg | grep -iE "RTL: examining|RTL: fw version"
```

- Eşleşme yoksa → **bu çözüm geçerli değil**, başka dala geç.
- Eşleşme varsa ve `fw version` = **`0xdfc6d922`** → **BULDUN.** Adım 4'e git.
- Eşleşme varsa ve `fw version` = `0x09a98a6b` → firmware zaten iyi, başka
  neden ara (aşağıdaki "Farklı nedenler" bölümü).

### Adım 2 — Belirti uyuyor mu?

```bash
# Kesinti anında günlükte kayıt var mı?
journalctl -b all --no-pager | grep -iE "hci0|btusb" \
  | grep -icE "disconnect|reset|error|timeout"
```

- **0** dönerse → kesinti **sessiz**. Bu, firmware sorununun en güçlü
  işaretidir. Adım 3.
- Sıfırdan büyükse → günlükte ne yazdığına bak; farklı bir sorun olabilir.

### Adım 3 — Ölç (tahmin etme)

```bash
sudo btmon -w /tmp/tani.snoop &     # başlat
# ... 5-10 dk müzik dinle / kesintiyi bekle ...
sudo pkill -x btmon                 # durdur

sudo btmon -r /tmp/tani.snoop 2>/dev/null \
  | grep -E "^[<>] ACL:" \
  | grep -oE "\[hci0\] [0-9.]+" | awk '{print $2}' \
  | python3 -c "
import sys,statistics
ts=sorted(float(x) for x in sys.stdin)
g=[ts[i+1]-ts[i] for i in range(len(ts)-1)]
print('medyan: %.1f ms'%(statistics.median(g)*1000))
print('>50ms boşluk:', sum(1 for x in g if x>0.05))
print('maks: %.0f ms'%(max(g)*1000))
"
```

**Yorum:**

| Sonuç | Anlamı |
|---|---|
| `>50ms boşluk: 0`, `maks ~21–35 ms` | Akış sağlıklı |
| `>50ms boşluk: >0`, `maks >200 ms` | **Firmware kaynaklı kopma** |
| `>50ms boşluk: >0` ama `maks <100 ms` | Hafif; xrun/yük olabilir, host'a da bak |

### Adım 4 — Çöz (firmware değiştir)

Tam adımlar: [`02-COZUM.md`](02-COZUM.md). Özet:

```bash
curl -fsSL -o /tmp/rtl8761bu_fw.bin \
  https://raw.githubusercontent.com/void0x14/rtl8761bu-a2dp-kesintisi-cozumu/main/veri/rtl8761bu_fw.bin
echo "148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76  /tmp/rtl8761bu_fw.bin" | sha256sum -c
sudo cp /tmp/rtl8761bu_fw.bin /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin
sudo modprobe -r btusb && sleep 2 && sudo modprobe btusb
sudo dmesg | grep "RTL: fw version"   # 0x09a98a6b görmelisin
```

### Adım 5 — Doğrula (Adım 3'ü tekrarla)

`>50ms boşluk: 0` olmalı. Olmazsa firmware yüklenmemiştir.

---

## Ajanların düştüğü tuzaklar

Bu vakada ajanların yaptığı ve **yapılmaması gereken** şeyler:

1. **Ölçmeden varsayım üretmek.** "Mesafe uzaktır", "USB 3.0 parazitidir"
   gibi tahminler — hepsi yanlıştı. Önce `btmon`, sonra konuş.
2. **"Günlükte yok" deyip kapatmak.** Günlük yalnız üst katmanı görür.
   A2DP'de gerçek ölçüm `btmon`'dur.
3. **Donanımı suçlamak.** Kulaklık sağlamdı. Suçlu dongle firmware'iydi.
4. **Belirtiyi görmezden gelmek.** Kullanıcı "yıllardır, düzensiz, anlık"
   diyorsa bu firmware davranışıdır; RF zayıflaması bu deseni vermez.
5. **Yanlış nedensellik.** HFP soketinin A2DP'yi düşürdüğünü sanmak.
   Gerçek: aynı ACL linki, birlikte ölürler.

## Hızlı komut seti (hepsi bir arada)

```bash
# TEŞHİS
lsusb | grep -iE "2357:0604|0bda:8771"                       # adaptör mü?
sudo dmesg | grep "RTL: fw version"                          # hangi sürüm?
journalctl -b all --no-pager | grep -iE "hci0|btusb" \
  | grep -icE "disconnect|reset|error"                        # sessiz mi? (0=sessiz)
journalctl -b all --no-pager | grep -c "terminated unexpectedly"  # ağır kopma sayısı

# ÖLÇÜM
sudo btmon -w /tmp/tani.snoop & sleep 300; sudo pkill -x btmon
sudo btmon -r /tmp/tani.snoop 2>/dev/null | grep -E "^[<>] ACL:" \
  | grep -oE "\[hci0\] [0-9.]+" | awk '{print $2}' \
  | python3 -c "import sys,statistics;ts=sorted(float(x) for x in sys.stdin);g=[ts[i+1]-ts[i] for i in range(len(ts)-1)];print('maks %.0fms, >50ms %d'%(max(g)*1000,sum(1 for x in g if x>0.05)))"

# ÇÖZÜM
curl -fsSL -o /tmp/f.bin https://raw.githubusercontent.com/void0x14/rtl8761bu-a2dp-kesintisi-cozumu/main/veri/rtl8761bu_fw.bin
echo "148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76  /tmp/f.bin" | sha256sum -c
sudo cp /tmp/f.bin /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin
sudo modprobe -r btusb && sleep 2 && sudo modprobe btusb
sudo dmesg | grep "RTL: fw version"
```

---

## Farklı nedenler (firmware iyiyse)

Firmware `0x09a98a6b` olduğu hâlde kesinti sürüyorsa, şu sırayla bak:

1. **Gerçekten yüklendi mi?** `sudo dmesg | grep "RTL: fw version"` —
   `.zst` dosyası `.bin`'i gölgeliyor olabilir.
2. **Ağır link yıkımı var mı?** `grep "terminated unexpectedly"` — varsa
   başka bir nedenle ACL düşüyor (BlueZ #1992 sınıfı).
3. **Xrun var mı?** `pw-top` ERR sütunu; `PIPEWIRE_DEBUG=3` ile `graph xrun`
   satırları.
4. **USB gecikmesi:** dongle ile aynı USB denetleyicisinde yoğun trafik
   (harici disk, ses kartı) varsa yalnız bir porta taşımayı dene.
5. **Gerçek 2,4 GHz çakışması:** Wi-Fi 2,4 GHz'de çalışıyorsa 5 GHz'e al.
   (Bu vakada Wi-Fi yoktu, dolayısıyla elendi.)
