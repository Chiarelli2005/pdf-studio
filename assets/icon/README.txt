ICONA APP

File presenti:
- app_icon.png            -> icona principale (512x512, PNG)
- app_icon_foreground.png -> foreground per icona adattiva Android
                             (icona scalata al 70% nella safe zone)

L'icona fornita dall'utente (PDF arancione su sfondo nero) e' gia'
integrata. La GitHub Action genera automaticamente tutte le risoluzioni
Android ad ogni build (step "Generate launcher icons").

Per cambiarla di nuovo:
1. Sostituisci app_icon.png con la nuova immagine (PNG quadrato,
   consigliato 1024x1024 px per la massima nitidezza)
2. Rigenera anche app_icon_foreground.png centrando l'icona al ~70%
   su tela trasparente, oppure usa la stessa immagine come foreground
   accettando un possibile ritaglio dei bordi
3. flutter pub get
4. dart run flutter_launcher_icons
5. Ricompila (push su GitHub -> la Action fa tutto)

NOTA: l'immagine originale era 512x512. Per la massima qualita' sulle
densita' Android piu' alte, fornire un originale 1024x1024.
