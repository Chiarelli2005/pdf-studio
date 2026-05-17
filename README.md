# PDF Studio

App Android Flutter per **visualizzare, annotare, compilare e proteggere PDF**.

## Funzionalità

- 📖 **Visualizzazione** PDF veloce con zoom, navigazione pagine, miniature
- 👁️ **Modalità sola lettura** automatica quando apri un PDF da un'altra app ("Apri con..."), con pulsante per passare all'editor
- ✏️ **Scrittura a mano libera** con penna, evidenziatore, firma, gomma — colori, spessore e opacità regolabili
- 📝 **Testo libero** posizionabile ovunque
- 🖼️ **Inserimento immagini** da galleria o fotocamera, ridimensionabili e riposizionabili
- ☑️ **Checkbox cliccabili** per compilazione moduli
- 🔷 **Forme**: rettangoli, cerchi, linee, frecce
- 🔍 **Zoom-aware**: testo, scritte e annotazioni restano ancorati al foglio a qualsiasi livello di zoom/pan
- 🔗 **Unione PDF**: combina più PDF in un unico documento, con ordine personalizzabile
- ✂️ **Divisione PDF**: estrai intervalli di pagine o separa pagina per pagina
- 🔃 **Riordino pagine**: cambia l'ordine delle pagine trascinandole, poi salva
- 🖨️ **Stampa nativa**: rilevamento automatico stampanti (WiFi, cloud, USB) tramite il framework di stampa Android; stampa tutto, una pagina, un intervallo o più intervalli (es. `1-3, 5, 8-10`)
- 📤 **Invio/condivisione copia**: condividi il documento con qualsiasi app (email, messaggistica, cloud) tramite il foglio di condivisione nativo
- 🔄 **Conversione Word ⇄ PDF** (offline, approssimata — vedi note sotto)
- 🔒 **Cifratura AES-256 standard PDF** con password — apribile da qualsiasi lettore (Acrobat, Preview, browser)
- 📊 **Metadati**: visualizzazione completa ed editing di titolo, autore, oggetto, parole chiave, ecc.
- ↶ **Undo/Redo** fino a 50 step
- 💾 **Esportazione** e **condivisione** native Android
- 🎨 **UI dark moderna** stile pro, con splash screen animato

## Note sulla conversione Word ⇄ PDF

La conversione è **100% offline** (nessun file lasciato il dispositivo) e quindi **approssimata**:

- **Word → PDF**: estrae testo, paragrafi, grassetto/corsivo di base e intestazioni. Non replica layout multi-colonna, header/footer, caselle di testo, SmartArt/WordArt, posizionamento assoluto delle immagini o stili tipografici avanzati.
- **PDF → Word**: estrae il testo del PDF in un `.docx` modificabile. Non ricostruisce layout esatto, tabelle, immagini o font originali.

È pensata per documenti lineari (lettere, verbali, testi). Per fedeltà tipografica 1:1 servirebbe un motore lato server (es. LibreOffice), incompatibile con la filosofia offline dell'app. L'app avvisa l'utente di questi limiti prima di ogni conversione.

## Quickstart: Build APK via GitHub Actions

**Non serve installare nulla in locale.** Il workflow CI fa tutto per te.

### Step 1: Crea un nuovo repository GitHub

1. Vai su https://github.com/new
2. Crea un nuovo repo (es. `pdf-studio`) — può essere pubblico o privato
3. **Non** inizializzarlo con README/gitignore (lo abbiamo già)

### Step 2: Carica i file del progetto

Opzione A — Da terminale (consigliata):

```bash
cd pdf_studio
git init
git add .
git commit -m "Initial commit: PDF Studio Flutter project"
git branch -M main
git remote add origin https://github.com/TUO-USERNAME/pdf-studio.git
git push -u origin main
```

Opzione B — Drag & drop dalla UI di GitHub:

1. Apri il repo appena creato
2. Click su **"uploading an existing file"**
3. Trascina **tutto il contenuto** della cartella `pdf_studio` (file e sottocartelle)
4. Commit changes

### Step 3: Attendi il build automatico

Appena fai push, GitHub Actions parte automaticamente:

1. Vai sulla tab **Actions** del tuo repo
2. Vedrai il workflow **"Build Android APK"** in esecuzione (icona gialla 🟡)
3. Attendi 5–8 minuti
4. Quando diventa verde ✅, click sul workflow run
5. In fondo alla pagina trovi gli **Artifacts**:
   - `pdf-studio-debug-apk` → APK debug universale (raccomandato per installazione manuale)
   - `pdf-studio-release-apks` → APK release split per architettura (più piccoli)

### Step 4: Installa l'APK sul telefono

1. Scarica l'artifact (è uno ZIP contenente l'APK)
2. Estrai l'APK
3. Trasferiscilo sul tuo Android (USB, Google Drive, email, ecc.)
4. Sul telefono, attiva **"Installa da sorgenti sconosciute"** per il file manager
5. Tap sull'APK → Installa

## Build in locale (opzionale)

Se hai Flutter installato in locale:

```bash
flutter pub get
flutter build apk --debug    # APK debug
flutter build apk --release  # APK release (richiede keystore per Play Store)
```

L'APK risultante è in `build/app/outputs/flutter-apk/`.

## Struttura del progetto

```
pdf_studio/
├── .github/workflows/build-apk.yml   # CI GitHub Actions
├── android/                          # Configurazione Android nativa
├── lib/
│   ├── main.dart                     # Entry point + tema
│   ├── screens/
│   │   ├── home_screen.dart          # Schermata iniziale
│   │   └── editor_screen.dart        # Editor PDF
│   ├── widgets/
│   │   ├── tool_bar.dart             # Barra strumenti
│   │   ├── annotation_overlay.dart   # Overlay disegno
│   │   ├── right_panel.dart          # Pannello metadati
│   │   └── password_dialog.dart      # Dialog password
│   ├── models/
│   │   └── annotation_models.dart    # Modelli annotazioni
│   └── services/
│       ├── pdf_service.dart          # Embedding annotazioni + export
│       ├── encryption_service.dart   # Cifratura
│       └── permission_service.dart   # Permessi
└── pubspec.yaml                      # Dipendenze
```

## Stack tecnico

- **Flutter 3.24+** / Dart 3
- **Syncfusion Flutter PDF Viewer & PDF**: rendering e manipolazione (community license gratuita sotto 1M$/anno fatturato)
- **flutter_colorpicker**, **google_fonts**, **path_provider**, **file_picker**, **share_plus**, **permission_handler**

## Note sulla licenza Syncfusion

Syncfusion offre una [Community License](https://www.syncfusion.com/products/communitylicense) gratuita per:
- Aziende con fatturato annuo < 1M USD
- Sviluppatori individuali

Per la pubblicazione su Google Play in versione commerciale, valuta se la licenza si adatta o se acquistare una licenza commerciale.

In alternativa puoi sostituire `syncfusion_flutter_pdf` con `pdfrx` o `flutter_pdfview` per il rendering e usare `pdfx` o `printing` per la manipolazione (ma con meno funzionalità).

## Roadmap futura

- [ ] OCR integrato (Google ML Kit Text Recognition)
- [ ] Form fields PDF nativi (AcroForm)
- [ ] Salvataggio sessione automatico (annotazioni persistenti)
- [ ] Sincronizzazione cloud opzionale (Drive, Dropbox)
- [ ] Modalità presentazione full-screen
- [ ] Stylus S-Pen pressure-sensitivity avanzata
- [ ] Versione iOS

## Risoluzione problemi

**Build fallisce con errore Gradle**: verifica nella tab Actions il log. Il problema più comune è la versione di Flutter — aggiorna `subosito/flutter-action@v2` con `flutter-version: '3.27.0'` se serve.

**APK non si installa**: assicurati di scaricare la versione **debug** se è il tuo primo test. Le APK release richiedono firma con keystore vera per essere accettate.

**Crash all'apertura PDF**: verifica che il file non sia corrotto. Apri prima un PDF semplice di test.

## Personalizzazione icona app

L'icona si trova in `assets/icon/app_icon.png` (attualmente un placeholder generato automaticamente). Per usare la tua:

1. Sostituisci `assets/icon/app_icon.png` con la tua immagine (PNG quadrato, consigliato 1024×1024 px)
2. La GitHub Action genera automaticamente tutte le risoluzioni Android durante la build (step `Generate launcher icons`)

In locale, in alternativa: `flutter pub get` poi `dart run flutter_launcher_icons`.

## Autore

Ideato e sviluppato da **Giovanni Chiarelli**. La firma compare nello splash screen all'avvio (con effetto dissolvenza) e nella schermata Informazioni dell'app. I documenti PDF prodotti restano puliti: nessun watermark viene mai applicato ai file dell'utente.

## Licenza

MIT — usa, modifica, distribuisci liberamente.
