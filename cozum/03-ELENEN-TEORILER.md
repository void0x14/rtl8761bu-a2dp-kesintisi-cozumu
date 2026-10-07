# Çürütülen Yanlış Teoriler

Bu vakada öne sürülen her "çözüm" burada tek tek **kanıtla** çürütülür.
Amaç: aynı yanlış yollara bir daha girilmesin.

## 1. "Mesafe uzak / sinyal zayıf" — YANLIŞ

Kopma **1 metre** mesafede de oluyordu. Dahası, boşluklar mesafeye değil,
**periyodik patlamalara** bağlıydı:

```
t≈264–272 s  → 56 boşluk  (bir arada)
t≈359–386 s  → 28 boşluk  (bir arada)
```

RF zayıflaması düzenli kadans bozar; burada ise dakikalarca **kusursuz**
akış, sonra saniyelerce bozukluk var. Bu bir firmware davranışıdır.

## 2. "USB 3.0 portuna takılısın, parazit yapıyor" — YANLIŞ

Ölçüldü: dongle `1-9` portunda, `speed=12` (Full-Speed), `power=on`.
USB 3.0 portunda değil.

```
$ cat /sys/bus/usb/devices/1-9/speed
12
```

## 3. "2,4 GHz Wi-Fi ile çakışıyor" — YANLIŞ

Sistemde **kablosuz ağ arayüzü yok**. Yalnızca kablolu ethernet var:

```
$ ip -br link
enp37s0   UP   ...        ← kablolu
$ iw dev
(boş — hiç kablosuz cihaz yok)
```

2,4 GHz'de çakışacak bir Wi-Fi yok. Teori geçersiz.

## 4. "USB autosuspend dongle'ı uyutuyor" — YANLIŞ

Zaten kapalıydı:

```
$ cat /sys/module/btusb/parameters/enable_autosuspend
N
$ cat /sys/bus/usb/devices/1-9/power/runtime_status
active
```

Ayrıca kaynak raporu da doğruluyor: *"Disabling USB autosuspend makes no
difference"* (linux-bluetooth, Ara 2025).

## 5. "HFP/mikrofon soketi A2DP'yi düşürüyor" — TERS NEDENSELLİK

Yaygın ama yanlış bir çıkarım. Gerçek: A2DP ve HFP **aynı ACL linkini**
paylaşır. Link düşünce **ikisi birden** ölür. Yani HFP soketi A2DP'yi
öldürmez — **ikisi de aynı katliamın kurbandır.**

Kanıt: üç satır (A2DP transport, HFP gateway, AVRCP input) **her seferinde
aynı saniyede** düşüyor. Birbirini tetikleyen üç ayrı olay olsaydı,
aralarında milisaniye farkı olurdu.

## 6. "PipeWire tamponu çok küçük, xrun oluyor" — YANLIŞ

- `pw-top` ERR sütunu = **0**
- `data-loop.0` iş parçacığı **SCHED_FIFO, rtprio 88** ile çalışıyor
- Host tarafında boşluk penceresinde **her iki yön de** duruyor (hem host
  gönderimi, hem denetleyicinin "Completed Packets" bildirimi)

Host düzgün çalışıyor. Sorun host'ta değil.

## 7. "CPU meşgul, ses yetişemiyor" — YANLIŞ

Yük ortalaması ~3–5 (12 çekirdek). PipeWire gerçek zamanlı öncelikli.
Ölçüm sırasında CPU sorunu görülmedi.

## 8. "Kulaklık kalitesiz" — YANLIŞ

QCY-T13 6 yıldır kullanılıyor. Kulaklık sağlam; başka sistemlerde çalışıyor.
Suçlu, dongle'ın içindeki 42 KB'lık firmware dosyasıydı.

## 9. "A2DP yüksek kaliteli kod demek" — TERİM HATASI

A2DP bir **kod değil**, Bluetooth'ta müzik taşıma tünelinin adıdır. Bu
vakada tünelin içinden **AAC** akıyordu (`api.bluez5.codec = "aac"`).
Kod değiştirmeye gerek yoktu; AAC'de kalındı ve sorun çözüldü.

## 10. "SBC'ye geç, daha kararlı" — GEREKSİZ

Sorunun kökü kod değil firmware'di. AAC'de kalındı, ses kalitesi
düşürülmedi, sorun yine de çözüldü.

---

## Özet tablo

| Teori | Durum | Çürüten kanıt |
|---|---|---|
| Mesafe / sinyal | ❌ | 1 m'de de var; boşluklar patlamalı |
| USB 3.0 paraziti | ❌ | Port `speed=12`, USB 2.0 tarafı |
| 2,4 GHz WiFi | ❌ | Sistemde kablosuz NIC yok |
| USB autosuspend | ❌ | Zaten kapalı (`enable_autosuspend=N`) |
| HFP → A2DP düşürüyor | ❌ | Aynı ACL; ikisi birlikte ölüyor |
| PipeWire xrun | ❌ | ERR=0, RT öncelikli |
| CPU yetişmiyor | ❌ | Yük düşük, RT aktif |
| Kulaklık bozuk | ❌ | 6 yıllık, sağlam |
| Kod değiştirmek | ❌ | AAC'de kalındı, çözüldü |

**Tek geçerli kök neden:** dongle firmware sürümü `0xdfc6d922`.
