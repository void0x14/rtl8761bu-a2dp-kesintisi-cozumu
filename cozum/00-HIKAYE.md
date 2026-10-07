# Hikâye — 5 yıllık kesintinin peşinde

## Başlangıç: "sorun sende"

Yıllarca aynı şey söylendi:

- "Mesafe uzak."
- "USB 3.0 portuna takmışsın, parazit yapıyor."
- "Wi-Fi ile çakışıyor, 5 GHz'e geç."
- "Kulaklığın kalitesiz."
- "Linux'ta Bluetooth böyle, normal."

Hepsi yanlıştı. Ve hepsinin ortak özelliği: **hiçbiri ölçülmemişti.**
Hepsi masabaşı tahmindi.

## Çıkmaz: günlükte hiçbir şey yok

En çok kafa karıştıran şey şuydu: kesinti oluyor, ama `journalctl`'de
hiçbir hata görünmüyor. Bu yüzden "yazılımsal bir hata yok" sonucuna
varılıyordu. Bu çıkarım yanlıştı — çünkü **günlük, olayın gerçekleştiği
katmanı görmüyordu.**

A2DP sesi, `L2CAP → HCI → USB → radyo` zincirinden geçer. Günlükler
yalnızca BlueZ/PipeWire (yani en üst katman) seviyesinde tutulur. Sorun
alt katmanda (dongle firmware'i) olduğunda, üst katman hiçbir şey görmez.

**Kanıt:** tüm boot'larda, `hci0`/`btusb` seviyesinde
`disconnect/reset/error/timeout` eşleşme sayısı = **0**.
Kesinti sessizdir.

## Kırılma noktası: ölçmek

"Günlükte yok" demek "yok" demek değildir. Doğru soru şuydu:

> Ses paketleri gerçekten havaya çıkıyor mu, çıkıyorsa düzenli mi?

Bunu ölçmenin yolu `btmon`'dur: HCI katmanındaki **her** ACL paketini
zaman damgasıyla kaydeder. Ses kesintisi = paket akışındaki **boşluk**.

Ölçüm yapıldı. Sonuç:

```
Normal kadans:  21,3 ms'de bir paket   (taş gibi düzenli)
Bozuk an:       514 ms boyunca tek paket yok
```

Yarım saniyelik boşluk = müziğin anlık susması. Ve bu boşluklar tek tek
değil, **saniyeler süren patlamalar** hâlinde geliyordu:

```
t≈264–272 s  → 56 boşluk (60–514 ms)     ~8 saniyelik bozukluk
t≈359–386 s  → 28 boşluk (54–132 ms)     ~27 saniyelik bozukluk
```

"Yıllardır ara ara tetikliyor" tarifinin tam karşılığı buydu.

## Kök neden: bir sürüm numarası

Paketler host'tan düzgün çıkıyordu (PipeWire RT öncelikli, ERR=0, CPU boş).
Boşluk, host ile kulaklık arasındaki **dongle'ın içinde** oluşuyordu.

Dongle'ın çalıştırdığı firmware'e bakıldı:

```
Bluetooth: hci0: RTL: fw version 0xdfc6d922
```

`0xdfc6d922` — RTL8761BU için **bilinen bozuk** sürüm. Linux-bluetooth
posta listesinde (Aralık 2025) birebir aynı belirtilerle raporlanmış:

> *"…my mouse started disconnecting about every 2-3 minutes.
> There are no entries in dmesg regarding the disconnect…
> Disabling USB autosuspend makes no difference."*

Aynı belirti, aynı sürüm, aynı "günlükte yok" durumu.

## Çözüm ve doğrulama

Firmware `0x09a98a6b` (iyi sürüm) ile değiştirildi, sürücü yeniden yüklendi.
Aynı ölçüm tekrarlandı:

| | ESKİ `0xdfc6d922` | YENİ `0x09a98a6b` |
|---|---:|---:|
| >50 ms boşluk | 109 | **0** |
| Maks boşluk | 514 ms | **32 ms** |
| Süre | 846 s | 394 s |

6,5 dakika, 18.459 paket, **tek boşluk yok**, en büyük sapma 32 ms.
Kesinti bitti.

## Dersler

1. **"Günlükte yok" ≠ "sorun yok".** Yanlış katmana bakıyorsan hiçbir şey
   görmezsin. A2DP sorunlarında `btmon` günlükten daha güvenilirdir.
2. **Ölç, tahmin etme.** Mesafe, USB portu, WiFi — hepsi ölçülebilir ve
   hepsi bu vakada **çürütüldü**.
3. **Donanımı suçlamadan önce yazılımını oku.** Kulaklık 6 yıllıktı ve
   sağlamdı. Suçlu, dongle'ın içindeki 42 KB'lık bir firmware dosyasıydı.
4. **Varsayım üreten ajan işe yaramaz.** Bu vakada önceki denemeler sisteme
   bakmadan "çözüm" üretti; hiçbiri işe yaramadı. İşe yarayan tek şey
   ölçüm oldu.

Detaylı teknik anatomi: [`01-KOK-NEDEN.md`](01-KOK-NEDEN.md)
