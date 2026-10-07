# Çözüm — Adım Adım

Bu bölüm, bozuk firmware'i iyi sürümle değiştirmeyi anlatır. İşlem geri
alınabilir: önce yedek alınır, sonra değiştirilir.

## Ön koşul: gerçekten bu sorun mu?

Şu iki şeyi doğrula:

```bash
# 1. Adaptör RTL8761BU mu?
lsusb | grep -iE "2357:0604|0bda:8771"
sudo dmesg | grep -iE "RTL: examining|RTL: fw version"
# Beklenen: "RTL: fw version 0xdfc6d922"  ← bozuksa bu çıkar

# 2. Belirti uyuyor mu?
#    - Müzikte düzensiz, saniyelik kesintiler
#    - journalctl'de KAYIT YOK  (en belirleyici işaret)
#    - usb autosuspend kapalı olmasına rağmen devam ediyor
```

`fw version` **`0x09a98a6b`** ise bu çözüm sana göre değil — sorunun başka.

## Çözüm A — Elle (her dağıtımda çalışır)

### 1. Bozuk firmware'i yedekle

```bash
# Sıkıştırılmış (.zst) veya düz (.bin) olabilir — ikisini de dene
sudo cp -av /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin.zst /root/ 2>/dev/null
sudo cp -av /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin     /root/ 2>/dev/null
ls -la /root/rtl8761bu_fw.bin*
```

### 2. İyi firmware'i indir ve doğrula

```bash
curl -fsSL -o /tmp/rtl8761bu_fw.bin \
  https://raw.githubusercontent.com/void0x14/rtl8761bu-a2dp-kesintisi-cozumu/main/veri/rtl8761bu_fw.bin

# sha256 doğrula — MUTLAKA
echo "148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76  /tmp/rtl8761bu_fw.bin" \
  | sha256sum -c -
# Beklenen: /tmp/rtl8761bu_fw.bin: OK
```

> **Neden bu dosya güvenli?** `0x09a98a6b` sürümü, linux-firmware deposunun
> 2021-12 civarındaki sürümüdür; yani daha önce milyonlarca sistemde çalışmış,
> Realtek'in resmî olarak yayınladığı eski ikilidir. sha256 ile doğrulanır.

### 3. Yerleştir

Sıkıştırılmamış dosya, sıkıştırılmış dosyaya göre **önce** okunur.
Yani `.bin` koymak yeterlidir; `.zst`'yi silmene gerek yok.

```bash
sudo cp -av /tmp/rtl8761bu_fw.bin /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin
```

### 4. Sürücüyü yeniden yükle

```bash
sudo modprobe -r btusb btrtl && sleep 2 && sudo modprobe btusb
sleep 6
```

### 5. Doğrula

```bash
sudo dmesg | grep "RTL: fw version" | tail -1
# Beklenen: Bluetooth: hci0: RTL: fw version 0x09a98a6b
```

Kulaklığı yeniden bağla:

```bash
bluetoothctl connect 1C:52:16:D4:CC:EC     # kendi MAC adresin
bluetoothctl info 1C:52:16:D4:CC:EC | grep -iE "Connected|Battery"
```

### 6. Profil A2DP mi? (sık atlanan adım)

Firmware yeniden yüklendikten sonra kulaklık bazen **HFP/headset**
profiline düşer (ses kalitesi düşer, mono olur). Kontrol et:

```bash
pactl list cards | grep -A1 "Name: bluez_card" | grep -iE "Name:|Active"
```

`Active Profile: a2dp-sink` olmalı. Değilse zorla:

```bash
pactl set-card-profile bluez_card.1C_52_16_D4_CC_EC a2dp-sink
```

Doğrula:

```bash
pw-dump | grep -o '"api.bluez5.codec": "[a-z]*"' | sort -u
# Beklenen: "aac"  (msbc/cvsd = HFP, yani yanlış profil)
```


## Çözüm B — Arch/CachyOS: pacman hook (kalıcı)

`linux-firmware` güncellendiğinde bozuk sürüm geri gelir. Hook bunu engeller.

```bash
# İyi firmware'i kalıcı konuma al
sudo mkdir -p /usr/local/share/rtl8761bu-fw
sudo cp -av /tmp/rtl8761bu_fw.bin /usr/local/share/rtl8761bu-fw/rtl8761bu_fw.bin

# Hook yaz
sudo tee /etc/pacman.d/hooks/99-rtl8761bu-fw-restore.hook >/dev/null <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-firmware*
Target = linux-firmware-realtek

[Action]
Description = RTL8761BU: bilinen bozuk fw (0xdfc6d922) yerine 0x09a98a6b geri kuruluyor
When = PostTransaction
Exec = /usr/bin/cp -f /usr/local/share/rtl8761bu-fw/rtl8761bu_fw.bin /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin
EOF
```

## Geri alma

Her şey geri alınabilir:

```bash
# Yedeği geri koy (hangisini yedeklediysen)
sudo cp -av /root/rtl8761bu_fw.bin.zst /usr/lib/firmware/rtl_bt/
# veya
sudo cp -av /root/rtl8761bu_fw.bin     /usr/lib/firmware/rtl_bt/

# Sürücüyü yeniden yükle
sudo modprobe -r btusb && sleep 2 && sudo modprobe btusb

# (Hook kurduysan) kaldır
sudo rm -f /etc/pacman.d/hooks/99-rtl8761bu-fw-restore.hook
```

## Doğrulama — gerçekten çözüldü mü?

Çözümü **ölçerek** doğrula. Kulaklıkla müzik çalarken:

```bash
# Yakala
sudo btmon -w /tmp/kontrol.snoop &

# 5-10 dk müzik dinle, sonra durdur
sudo pkill -x btmon

# Paket boşluklarını ölç (>50 ms boşluk olmamalı)
sudo btmon -r /tmp/kontrol.snoop 2>/dev/null \
  | grep -E "^[<>] ACL:" \
  | grep -oE "\[hci0\] [0-9.]+" | awk '{print $2}' \
  | python3 -c "
import sys,statistics
ts=sorted(float(x) for x in sys.stdin)
g=[ts[i+1]-ts[i] for i in range(len(ts)-1)]
print('paket:',len(ts),'süre: %.0fs'%(ts[-1]-ts[0]))
print('medyan: %.1f ms'%(statistics.median(g)*1000))
print('>50ms boşluk:', sum(1 for x in g if x>0.05))
print('maks: %.0f ms'%(max(g)*1000))
"
```

**Beklenen sonuç:** `>50ms boşluk: 0` ve `maks` ≈ 30 ms.
`>50ms boşluk` hâlâ yüksekse firmware yüklenmemiştir — 5. adımı tekrar et.
