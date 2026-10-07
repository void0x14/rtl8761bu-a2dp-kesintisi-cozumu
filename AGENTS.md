# AGENTS.md — Ajanlar için makine-okur giriş noktası

> Bu dosya, bu depoyu okuyan AI ajanları içindir. İnsan için özet: `README.md`.

## Bağlam

- **Sorun:** Linux'ta Bluetooth A2DP sesi düzensiz, saniyelik kesiliyor.
- **Kök neden:** Realtek **RTL8761BU** çipinin `0xdfc6d922` firmware sürümü
  bozuk. ACL linkini sessizce düşürür.
- **Çözüm:** Firmware'i `0x09a98a6b` sürümüne düşür.
- **Belirleyici işaret:** Kesinti anında **günlükte hiçbir kayıt yoktur.**

## Hızlı karar

```
RTL8761BU adaptör (2357:0604 / 0bda:8771 / 2b89:8761) var mı?
├─ HAYIR → bu çözüm geçerli değil.
└─ EVET
   └─ dmesg | grep "RTL: fw version" = 0xdfc6d922 ?
      ├─ EVET → ÇÖZÜM: firmware'i 0x09a98a6b yap  (bkz. cozum/02-COZUM.md)
      └─ HAYIR (0x09a98a6b) → başka neden ara (bkz. cozum/04-AI-AJANLARI-ICIN.md)
```

## Tek komutluk teşhis

```bash
bash tani.sh
```

Bu betik: adaptörü tanımlar, firmware sürümünü okur, günlükteki sessizlik
durumunu ölçer ve çıkış kodunu buna göre verir:

| Çıkış kodu | Anlam |
|---|---|
| `0` | RTL8761BU + bozuk firmware tespit edildi → çözüm uygulanabilir |
| `1` | RTL8761BU değil veya firmware zaten iyi |
| `2` | Gerekli araçlar eksik (`btmon`, `dmesg`) |

## Çözümü uygula

```bash
bash coz.sh          # yedekler, indirir, sha256 doğrular, yerleştirir, yeniden yükler
```

## Doğrula

```bash
bash olc.sh 300      # 300 sn yakalar, >50ms boşluk sayısını verir
```

`>50ms boşluk: 0` ve `maks ≈ 21–35 ms` = sorun çözüldü.

## Sert kurallar (bu vakada kanıtlanmış)

1. **Ölçmeden sonuca varma.** `btmon` olmadan "çözüldü" deme.
2. **"Günlükte yok" ≠ "sorun yok".** Günlük yalnız üst katmanı görür.
3. **Kulaklığı suçlama.** Bu vakada kulaklık sağlamdı; suçlu firmware'di.
4. **Şu teorileri öne sürme** — hepsi kanıtla çürütüldü:
   mesafe/sinyal, USB 3.0 paraziti, 2,4 GHz WiFi çakışması,
   USB autosuspend, HFP soketi A2DP'yi düşürüyor, PipeWire xrun,
   CPU yetersizliği, kod (AAC/SBC) sorunu.
   Ayrıntı ve kanıt: `cozum/03-ELENEN-TEORILER.md`
5. **Firmware ikilisini sha256 olmadan yükleme.**
   Beklenen: `148baa25c3db17148047e2ca970b62b0a7a75b960b4762ea20f045b7977cff76`
6. **Kullanıcı ajanı uyarmadan sistemi değiştirme.** Önce teşhis, sonra onay.

## Dosya haritası

| Yol | İçerik | Biçim |
|---|---|---|
| `README.md` | İnsan için özet | Markdown |
| `cozum/00-HIKAYE.md` | Hikâye | Markdown |
| `cozum/01-KOK-NEDEN.md` | Teknik anatomi | Markdown |
| `cozum/02-COZUM.md` | Adım adım çözüm | Markdown |
| `cozum/03-ELENEN-TEORILER.md` | Çürütülen teoriler | Markdown |
| `cozum/04-AI-AJANLARI-ICIN.md` | Teşhis protokolü | Markdown |
| `kanit/*.txt` | Günlük + ölçüm kanıtları | Düz metin |
| `veri/rtl8761bu_fw.bin` | İyi firmware | İkili (sha256 doğrulanabilir) |
| `veri/rtl8761bu_fw_BOZUK_*.bin.zst` | Bozuk firmware yedeği | İkili |
| `veri/acl_zaman_serisi_*.txt` | Ham paket zamanları | Düz metin |
| `tani.sh` `coz.sh` `olc.sh` | Betikler | Bash |

## Ortam (doğrulandığı)

CachyOS, çekirdek 6.12.69, BlueZ 5.87, PipeWire 1.6.9, WirePlumber 0.5.18,
TP-Link UB500 (`2357:0604`), QCY-T13.
