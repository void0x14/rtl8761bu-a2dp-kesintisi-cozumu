# RTL8761BU Bluetooth A2DP Kesintisi — Kök Neden ve Çözüm

> **Tek cümle:** TP-Link UB500 (Realtek RTL8761BU) dongle'ının çalıştırdığı
> `0xdfc6d922` firmware sürümü bozuktur; müzik akışını **hiçbir günlük kaydı
> bırakmadan** düzenli aralıklarla keser. `0x09a98a6b` sürümüne düşürmek sorunu
> bitirir.

Bu depo, Linux'ta Bluetooth kulaklıkta yaşanan **sessiz ses kesintilerinin**
nasıl ölçüldüğünü, kök nedenin nasıl bulunduğunu ve nasıl giderildiğini
kanıtlarıyla belgeler. Sorun kulaklıkta değil, dongle firmware'inde.

---

## Sorun neydi?

- Kulaklık: **QCY-T13** (SBC + AAC destekli, A2DP/AVRCP/HFP)
- Adaptör: **TP-Link UB500** — USB `2357:0604`, çip **Realtek RTL8761BU**
- Sistem: CachyOS (Arch tabanlı), çekirdek `6.12.69`, BlueZ `5.87`,
  PipeWire `1.6.9`, WirePlumber `0.5.18`

Belirti: müzik dinlerken **saniyelik, art arda gelen kesintiler**. Yıllardır
sürüyor. En sinir bozucu kısmı: **günlükte hiçbir şey yok**. Bu yüzden herkes
"yazılımsal bir hata yok, sorun sende/mesafede/RF'te" diyip geçiyordu.

## Kök neden

Dongle'ın çalıştırdığı firmware sürümü:

```
$ sudo dmesg | grep "RTL: fw version"
Bluetooth: hci0: RTL: fw version 0xdfc6d922
```

`0xdfc6d922`, RTL8761BU için **bilinen bozuk** sürümdür. Bu sürüm ACL
bağlantısını kendi kendine düşürür; düşme anında o linke bağlı **her şey**
(A2DP + HFP + AVRCP) aynı saniyede ölür.

## Ölçüm (kanıt)

`btmon` ile HCI/ACL paketleri yakalandı, paketler arası boşluk ölçüldü.
Ses kesintisi = paket akışındaki boşluk.

| Ölçüm | ESKİ fw `0xdfc6d922` | YENİ fw `0x09a98a6b` |
|---|---:|---:|
| ACL paketi | 39.415 | 18.459 |
| Süre | 846 s | 394 s |
| Medyan aralık | 21,3 ms | 21,3 ms |
| **>50 ms boşluk** | **109** | **0** |
| **Maks boşluk** | **514 ms** | **32 ms** |
| Günlük kaydı | 0 | 0 |

Eski firmware'de boşluklar **saniyeler süren patlamalar** hâlinde geliyordu
(t≈264–272 arası 56 boşluk, t≈359–386 arası 28 boşluk). Yarım saniyelik
sessizlik, müzik deneyiminin anlık yok olmasıdır.

Ham veriler: [`veri/`](veri/) · Özet: [`kanit/`](kanit/)

## Çözüm

**Kısa yol (3 komut):**

```bash
# 1. Bozuk firmware'i yedekle
sudo cp /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin.zst /root/rtl8761bu_fw.bin.zst.yedek

# 2. İyi firmware'i indir (sha256 doğrula) ve yerleştir
curl -fsSL -o /tmp/rtl8761bu_fw.bin \
  https://raw.githubusercontent.com/void0x14/rtl8761bu-a2dp-kesintisi-cozumu/main/veri/rtl8761bu_fw.bin
echo "148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76  /tmp/rtl8761bu_fw.bin" | sha256sum -c
sudo cp /tmp/rtl8761bu_fw.bin /usr/lib/firmware/rtl_bt/rtl8761bu_fw.bin

# 3. Sürücüyü yeniden yükle
sudo modprobe -r btusb && sleep 2 && sudo modprobe btusb

# Doğrula: 0x09a98a6b görmelisin
sudo dmesg | grep "RTL: fw version"
```

**Kalıcı hâle getirme** (paket güncellemesi firmware'i ezmesin diye pacman
hook'u): [`cozum/02-COZUM.md`](cozum/02-COZUM.md)

**Geri alma:** [`cozum/02-COZUM.md`](cozum/02-COZUM.md#geri-alma)

## Dokümanlar

| Dosya | İçerik |
|---|---|
| [cozum/00-HIKAYE.md](cozum/00-HIKAYE.md) | Hikâye: 5 yıllık kesintinin peşinde ne oldu, nasıl bulundu |
| [cozum/01-KOK-NEDEN.md](cozum/01-KOK-NEDEN.md) | Kök nedenin teknik anatomisi + tüm kanıtlar |
| [cozum/02-COZUM.md](cozum/02-COZUM.md) | Adım adım çözüm, kalıcılık, geri alma |
| [cozum/03-ELENEN-TEORILER.md](cozum/03-ELENEN-TEORILER.md) | Çürütülen yanlış teoriler (mesafe, USB 3.0, WiFi…) |
| [cozum/04-AI-AJANLARI-ICIN.md](cozum/04-AI-AJANLARI-ICIN.md) | AI ajanları için hızlı teşhis protokolü |
| [kanit/](kanit/) | Günlük kayıtları, ölçüm çıktıları |
| [veri/](veri/) | Ham zaman serileri, iyi/bozuk firmware ikilileri |

## Kaynaklar (birincil, doğrulanmış)

- **linux-bluetooth posta listesi, 8 Ara 2025** —
  *"btrtl/rtl8761bu: latest firmware causes frequent disconnects"* —
  <https://www.spinics.net/lists/linux-bluetooth/msg124661.html>
  → `0xDFC6D922` kopma yapıyor, **dmesg'de kayıt yok**, autosuspend kapatmak
  işe yaramıyor, çözüm `0x09A98A6B`.
- **xpadneo `docs/BT_DONGLES.md`** —
  *"Known bad firmware for RTL8761BU chip set is 0xdfc6d922"*;
  `2357:0604` = TP-Link UB500, aynı sorun —
  <https://github.com/atar-axis/xpadneo/blob/master/docs/BT_DONGLES.md>
- **Kernel Bugzilla #219234** — aynı firmware, Xbox kolları —
  <https://bugzilla.kernel.org/show_bug.cgi?id=219234>
- **linux-firmware** (iyi sürümün kaynağı) —
  <https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git>

## Kapsam

- **Çalışır:** RTL8761BU tabanlı USB dongle'lar (TP-Link UB500/UB400,
  Ugreen CM390, Simplecom NB409…), Linux + BlueZ + PipeWire/WirePlumber.
- **Doğrulandığı ortam:** CachyOS, çekirdek 6.12.69, BlueZ 5.87,
  PipeWire 1.6.9, WirePlumber 0.5.18, TP-Link UB500, QCY-T13.
- **Not:** Bu bir *firmware* sorunudur; kernel/BlueZ/PipeWire ayarlarıyla
  çözülmez. Firmware sürümünü değiştirmek gerekir.

## Lisans

Metin ve belgeler: [CC BY 4.0](LICENSE).
`veri/` altındaki firmware ikilileri Realtek'e aittir ve
[linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git)
lisansına tabidir (yeniden dağıtıma izin verir).
