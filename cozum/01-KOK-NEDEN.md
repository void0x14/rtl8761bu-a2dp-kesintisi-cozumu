# Kök Neden — Teknik Anatomi

## Zincir

Bluetooth A2DP sesi şu zincirden geçer:

```
Uygulama (Chromium vb.)
   │  PCM ses
   ▼
PipeWire  (1.6.9)            ← ses sunucusu, tampon/kodlama
   │  AAC kodlama (a2dp-codec-aac)
   ▼
BlueZ     (5.87)             ← profil yönetimi, AVDTP/L2CAP
   │  L2CAP kanalı (AVDTP transport)
   ▼
Çekirdek  (6.12.69)          ← hci_conn / l2cap_core, ACL linki
   │  HCI ACL paketleri
   ▼
USB (Full-Speed 12 Mbps)     ← btusb sürücüsü
   │
   ▼
Dongle firmware              ← RTL8761BU  ⚠️ 0xdfc6d922 BOZUK
   │  2,4 GHz radyo
   ▼
Kulaklık (QCY-T13)           ← kendi tamponu
```

Kopma **en altta**, dongle firmware'inde olur. Yukarıdaki üç katman
(PipeWire, BlueZ, çekirdek) bunu **görmez**, çünkü onlar veriyi USB'ye
başarıyla teslim ettiklerini sanır.

## Neden günlükte hiçbir şey yok?

| Katman | Kopmayı görür mü? | Neden? |
|---|---|---|
| PipeWire | Hayır | Transport fd'si `HUP` almadı; veri akışı "normal" |
| BlueZ | Hayır | ACL linki kopmadı, yalnızca paketler kayboldu |
| Çekirdek | Hayır | `btusb` yazma başarılı döndü |
| Dongle FW | **Evet** | Ama kendi içinde, dışarı log basmaz |
| Kulaklık | **Evet** | Ama host'a bildirmez, sadece susar |

Kesintilerin **çoğu** bu eşiği hiç geçmez. Yalnızca daha ağır olanlar
link yıkımına yol açar ve o zaman üst katmanlar uyanır.

## Ağır kesinti: link yıkımı ve üç tanık

Dongle ACL linkini tamamen düşürdüğünde, o linke bağlı **her şey** aynı
saniyede ölür. Günlükte görülen üçlü budur:

```
23:29:53 wireplumber: connection (.../sep2/fd0) terminated unexpectedly
23:29:53 bluetoothd : Hands-Free Voice gateway ... Transport endpoint is not connected (107)
23:29:53 plasmalogin: releasing fd for 13:84        ← 13:84 = QCY-T13 (AVRCP)
```

Bu üç satır **üç ayrı arıza değil**, tek link yıkımının **üç tanığıdır**:

1. **`sep2/fd0`** — kulaklığın AVDTP akış uç noktası (SEID 2). A2DP müziği
   buradan akar. PipeWire'ın soketi `HUP` alınca bu satırı basar.
2. **HFP gateway / 107 (ENOTCONN)** — Hands-Free profilinin soketi. Aynı
   ACL üzerinde çalışır; link düşünce o da ölür. BlueZ bunu raporlar.
   *Mikrofon kullanmasan bile bu soket, BlueZ'in policy eklentisi yüzünden
   açıktır* — ama **suçlu değil, kurbandır.**
3. **`13:84` = `QCY-T13 (AVRCP)`** — kulaklığın ses kumandası için
   oluşturulan sanal input cihazı. Link düşünce X sunucusu bu fd'yi bırakır.
   Bu, olayın **tam cihaz yıkımı** olduğunun kanıtıdır.

`sep2` nedir? `sepN`, uzak cihazın (kulaklığın) AVDTP **Stream End Point**
numarasıdır; `N` = SEID. `fd0` ise o uç noktaya açılan akış soketidir.
Yani `.../sep2/fd0` = "SEID 2 numaralı akış soketi".

## Ölçümün gösterdiği

`btmon` ile HCI/ACL paket zamanları (yakalama başından saniye):

```
ESKİ fw 0xdfc6d922:
  medyan aralık = 21,3 ms    (beklenen kadans)
  >50 ms boşluk = 109
  maks boşluk   = 514 ms     ← yarım saniyelik sessizlik
  patlamalar    = t≈264–272 (56 boşluk), t≈359–386 (28 boşluk)

YENİ fw 0x09a98a6b:
  medyan aralık = 21,3 ms
  >50 ms boşluk = 0
  maks boşluk   = 32 ms
```

Boşluk penceresinde **her iki yön de durur**: host `< ACL` göndermeyi
keser *ve* denetleyici `> HCI Event: Number of Completed Packets`
bildirmeyi keser. Yani dongle, host'a "paketleri aldım" demeyi bırakır.
Bu, sorunun host tarafında değil, **dongle içinde** olduğunu kanıtlar.

## Neden `0xdfc6d922` bozuk?

Realtek firmware'i dışarı kapalıdır; iç mekanizma kamuya açık değildir.
Bilinen:

- Bu sürüm, RTL8761BU'da ACL/LE linklerini düzensiz aralıklarla düşürür.
- Kopma **`reason 0`** ile ve **dmesg kaydı olmadan** gerçekleşir.
- `usb autosuspend` kapatmak **işe yaramaz** (donanım/firmware sorunu).
- `0x09a98a6b` (önceki sürüm) bu davranışı göstermez.

Kaynaklar:

- linux-bluetooth, 8 Ara 2025 — *"btrtl/rtl8761bu: latest firmware causes
  frequent disconnects"* — <https://www.spinics.net/lists/linux-bluetooth/msg124661.html>
- xpadneo `docs/BT_DONGLES.md` — *"Known bad firmware for RTL8761BU chip set
  is 0xdfc6d922. It causes frequent reconnects."* —
  <https://github.com/atar-axis/xpadneo/blob/master/docs/BT_DONGLES.md>
- Kernel Bugzilla #219234 — <https://bugzilla.kernel.org/show_bug.cgi?id=219234>

## Bu vakaya özgü kanıtlar

- Günlük dökümü: [`../kanit/journal-kayitlari.txt`](../kanit/journal-kayitlari.txt)
- Eski fw ölçümü: [`../kanit/eski-fw-olcum.txt`](../kanit/eski-fw-olcum.txt)
- Yeni fw ölçümü: [`../kanit/yeni-fw-olcum.txt`](../kanit/yeni-fw-olcum.txt)
- Ham zaman serileri: [`../veri/`](../veri/)
