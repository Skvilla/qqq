# Phase 1 test yönergeleri

## Otomatik kontroller

Godot 4.6.3 Standard, Linux x86_64 üzerinde çalıştırıldı: **73 kontrol geçti, 0 başarısız**. Ayrı otomatik demo çalışması `10.000` saniye ve `601` örnekle tamamlandı. `tests/run_tests.sh` import, entegrasyon ve otomatik demo adımlarının hem çıkış kodunu hem Godot hata çıktısını denetler. Loglar Git'e alınmayan `test-results/` altına yazılır.

Entegrasyon testi gerçek `scenes/studio.tscn` sahnesini açar. Kontroller:

- Dört tekerleğin, ormanın, aktif kameranın ve Studio UI'ın oluşması; aracın zemine oturması.
- Klavye olaylarıyla dört yüz ifadesi; her anda yalnızca bir yüzün görünmesi.
- Fizik döngüsünde ileri sürüş ve direksiyon; kayıt sırasında ifade değişimleri.
- Gerçek dosya sistemine JSON yazma, aynı dosyayı yenileme ve yeniden okuma.
- Seçilen örneklerde kayıtlı konum, quaternion ve ifadenin geri elde edilmesi; ara zaman interpolasyonu.
- Bitişte durma, döngü, oynatma hızı ve 30/60/144 güncelleme hızında aynı 10 sn süre.
- Bozuk JSON, eksik dosya, sürüm, zaman damgası, ifade, quaternion, konum ve süre doğrulaması. Hatalı yükleme mevcut kaydı korumalı.
- UI sinyali/klavye ile kamera geçişi, serbest kamera hareketi, bu modda kamyonun sabit kalması.
- Dosya adı alanında yazarken sürüşün engellenmesi.
- Sentetik joypad olayları ve sol analog eşlemesi.
- Gerçek StaticBody3D engeliyle çarpışma.

Başarılı entegrasyon çıktısı: `PHASE1_TEST_RESULT checks=... failed=0`. Test başarısızsa süreç `1` döner. Sıfır test veya yalnızca sözdizimi denetimi başarı sayılmaz.

## Görsel kontrol

Gerçek bir grafik ekranında (veya OpenGL destekleyen sanal ekranda):

```bash
godot --path . --rendering-method gl_compatibility --script tests/render_preview.gd
```

`test-results/studio.png` üretir; `--headless` kullanmayın. Bu teslimde Linux Xorg dummy ekranı ve Mesa llvmpipe ile Godot'un gerçek 3B çıktısı incelendi. `docs/studio.png` uygulamadan alınmış ekran görüntüsüdür. Fiziksel GPU performansı bu ölçümden çıkarılamaz.

## Elle kabul testi

1. F5 ile ana sahneyi çalıştırın. Pastel sarı kamyon, orman, yol ve Studio UI görünmeli; konsolda script hatası olmamalı.
2. W ile hızlanın, A/D ile dönün, S ile geri gidin ve Space ile frenleyin. Tekerlekler dönmeli. Bir ağaca veya kayaya sürüldüğünde gövde engellenmeli.
3. 1, 2, 3, 4 tuşlarıyla göz, kaş ve ağzın değiştiğini gözleyin. UI seçimi ifadeyle eşleşmeli.
4. R → sürüş + ifade değişimi → R → P. Aynı hareketler ve yüzler tekrar görünmeli. Zaman çizgisini sürükleyip belirli bir ana atlayın.
5. `kabul_testi` adıyla F6'ya basın. Uygulamayı kapatıp açın, aynı adı girin, F7 ve P. Performans geri gelmeli.
6. Yanlış kayıt adıyla F7'ye basın. Anlaşılır hata mesajı görünmeli; mevcut kayıt kaybolmamalı.
7. C ile serbest kameraya geçin. WASD/Q/E kamerayı taşımalı, kamyonu hareket ettirmemeli. Sağ fareyle bakın, Esc ile fareyi serbest bırakın. C ile takibe dönün.
8. F5 ile demoyu çalıştırın. Dört ifade ve 10.0 sn bitişi gözleyin. Döngüyü açıp tekrar oynatın; her 10 saniyede başa dönmeli.
9. DualShock/DualSense bağlayın. Sol analogla sürüş, sağ analogla bakış; □/×/○/△ ile yüz, L1/R1 ile kayıt/oynat ve R3 ile kamera modunu kontrol edin.

## Doğrulama sınırları

- Fiziksel PlayStation kontrolcüsü, USB/Bluetooth bağlantısı ve titreşim test edilmedi. Titreşim bu fazın özelliği değildir.
- Windows/macOS çalıştırma ve dışa aktarılmış oyun paketi bu Linux ortamında test edilmedi.
- Görüntüsüz testler görsel estetiği kanıtlamaz; bu nedenle ayrıca gerçek OpenGL render alınmıştır.
- Kamera hareketleri ve görsel gövde salınımı JSON'a kaydedilmez. Kayıt sözleşmesi karakterin konumu, dönüşü ve ifadesidir.
