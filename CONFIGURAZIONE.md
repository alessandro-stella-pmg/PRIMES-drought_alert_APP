# PRIMES Informs — configurazione

## 1. Lingua per area pilota

La lingua non si sceglie da un menù: **discende dall'area pilota** scelta alla
registrazione, e cambia all'istante — già nella schermata di registrazione —
appena si seleziona un'area diversa nel dropdown. La mappa area → lingua sta in
[lib/config/pilot_areas.dart](lib/config/pilot_areas.dart):

| Area pilota | Sigla mostrata | Lingua |
|---|---|---|
| Italia — Marche, Emilia-Romagna | `IT` | italiano |
| Hrvatska — Međimurje, Koprivnica-Križevci | `HR` | croato |
| Bosna i Hercegovina — Gradiška | `BS` | bosniaco |
| Crna Gora — Danilovgrad | `SR` | serbo (alfabeto latino) |
| Ελλάδα — Παγγαίο (Καβάλα) | `EL` | greco |
| Srbija — Vojvodina | `SR` | serbo (alfabeto latino) |

La sigla accanto a ogni area nel selettore è derivata dal `locale` dell'area,
quindi non può disallinearsi dalla lingua realmente usata.

L'area è **legata all'account** e salvata nel profilo sul backend; il telefono
ne tiene solo una copia (`shared_preferences`) per la lingua. Non si cambia
dall'app: per passare a un'altra area si elimina l'account (in fondo a SOS) e
ci si registra di nuovo, anche con la stessa email (vedi §7).

I testi stanno in `assets/i18n/<lingua>.json`: **file JSON semplici**, uno per
lingua, che i partner possono tradurre/correggere senza toccare il codice.
Una chiave mancante in una lingua ricade automaticamente sull'inglese, quindi un
file incompleto non rompe mai l'interfaccia. Per aggiungere una lingua: si crea
il JSON, si aggiunge il `Locale` in `AppLocalizations.supportedLocales` e lo si
associa all'area in `pilot_areas.dart`.

> Danilovgrad ha dichiarato "montenegrino" nel form. L'app resta sul serbo in
> alfabeto latino perché Flutter (`GlobalMaterialLocalizations`) non ha un
> locale `me`: le differenze rispetto ai testi montenegrini sono minime e i
> contenuti dell'area sono comunque scritti in montenegrino. Se si vuole un
> `me` separato serve un `me.json` più un fallback esplicito per le
> localizzazioni di Material.

## 2. Contenuti per area pilota (FORM A)

Le etichette dell'interfaccia sono comuni a tutte le aree; **i contenuti no**.
Nomi dei quattro livelli di allerta, comportamenti e restrizioni, regole
permanenti, recapiti di emergenza e archivio documenti sono specifici dell'area
e stanno in [lib/config/area_content.dart](lib/config/area_content.dart), presi
dalle risposte al form *"Configurazione della tua Area Pilota"*.

Aree già configurate — le sei che hanno restituito il form:

| Area | Lingua dei contenuti | Documenti |
|---|---|---|
| `hr-medimurje` (REDEA) | croato, dal form | 7 |
| `hr-koprivnica-krizevci` | croato, dal form | 10 |
| `ba-gradiska` | **tradotto** dall'inglese del form | 0 |
| `me-danilovgrad` | **tradotto** dall'inglese del form | 3 |
| `rs-vojvodina` (RDA Bačka) | **tradotto** dall'inglese del form | 4 |
| `gr-paggaio` (DUTH) | greco, dal form | 6 |

> Gradiška, Danilovgrad e Vojvodina hanno compilato il form in inglese pur
> avendo scelto bosniaco/montenegrino/serbo come lingua dell'app: i testi in `area_content.dart` sono
> una traduzione e **vanno fatti validare dal partner** prima della
> pubblicazione. I punti dubbi sono segnalati da un commento nel file.

> Gradiška: nel form il nome del livello 4 mancava (il campo conteneva le
> restrizioni del livello 3). Il nome in app, «Nivo vanrednih mjera (teška
> nestašica vode)», è una proposta ricavata dagli altri tre livelli e dal
> contenuto delle restrizioni: **da far confermare al partner**. I testi
> troncati nel PDF delle risposte sono stati completati con quelli forniti a
> parte.

> Paggaio: nel form il nome del livello 2 ripete quello del livello 1
> («Level 1 = Καμία Έλλειψη Νερού»). L'app riporta il form alla lettera: i primi
> due livelli hanno lo stesso nome, le restrizioni invece sono diverse. È un
> errore di compilazione del partner e resta visibile apposta, così lo nota e
> manda la correzione. Non va «aggiustato» inventando un nome.

Un'area assente da `areaContents` non è un errore: l'app ricade sui livelli e
sui recapiti generici tradotti in `assets/i18n/`, come prima.

Il backend ragiona per **chiavi** (`none`, `level1`, `level2`, `level3`) con
etichette italiane di servizio. L'app le traduce nel nome scelto dall'area
(`areaLevelFor` in `area_content.dart`), altrimenti un'app croata scriverebbe
"Livello 2 - Allarme". Il cruscotto manda la chiave insieme al livello; per i
livelli salvati prima di questa modifica c'è un ripiego che riconosce le quattro
etichette italiane canoniche.

Dove finiscono questi contenuti:

* **Home** → il nome ufficiale dell'area nella card di allerta;
* **Livelli di allerta** (tap sulla card) → i quattro livelli con l'elenco
  puntato dei comportamenti, più il riquadro *Sempre in vigore* con le regole
  permanenti;
* **SOS** → numeri ed email dell'area, ognuno toccabile per chiamare o scrivere,
  con gli orari di reperibilità in fondo;
* **Documenti** → la sezione *Documenti ufficiali dell'area*.

Quando il cruscotto sarà pronto, questa mappa diventerà la cache locale di ciò
che arriva dal backend: la forma dei dati è già quella giusta.

## 3. Splash screen con il logo Interreg

`pubspec.yaml` → sezione `flutter_native_splash`: logo PRIMES al centro,
logo *Interreg IPA ADRION / Co-funded by the European Union* come `branding` in
fondo alla schermata. Dopo ogni modifica al logo va rigenerata:

```bash
dart run flutter_native_splash:create
```

### Icone

I loghi dentro l'app (login, Home, splash) restano quelli sopra. Dal logo
*PRIMES INFORM* derivano solo le icone:

* **icona dell'app** — `assets/icon/app_icon.png` (iOS e Android vecchi) e
  `assets/icon/app_icon_foreground.png` (icona adattiva Android, con il margine
  che il sistema ritaglia). Rigenerare con `dart run flutter_launcher_icons`;
* **icona delle notifiche** — `android/app/src/main/res/drawable-*/ic_stat_primes.png`:
  solo la sagoma bianca di goccia e foglia su fondo trasparente, perché Android
  colora di bianco tutto ciò che non è trasparente (un logo a colori
  diventerebbe un quadrato). Il backend la indica in ogni push e il manifest la
  imposta come predefinita per FCM.

## 4. Documenti

La schermata mostra due elenchi distinti:

1. **Documenti ufficiali dell'area** — file veri inclusi nell'app, sotto
   `assets/docs/<id-area>/`, elencati in `area_content.dart`. Si aprono con il
   visualizzatore di sistema (`open_filex`): l'asset viene estratto una volta
   sola nella cache del dispositivo e poi riaperto da lì. Non sono
   selezionabili né cancellabili.
2. **Scaricati dalle notifiche** — gli allegati che l'utente scarica dal
   dettaglio di una notifica ([lib/services/attachments.dart](lib/services/attachments.dart)).
   Il file viene scaricato davvero dal backend, salvato nella cartella privata
   dell'app e aperto subito con il visualizzatore di sistema; toccandolo di
   nuovo (nel dettaglio o qui) si riapre senza riscaricarlo. L'elenco resta
   salvato per utente anche chiudendo l'app. Pressione prolungata per
   selezionare, eliminazione che toglie anche il file dal telefono.
   Si scarica solo dall'indirizzo del backend PRIMES: l'URL arriva in una push
   e non deve poter far scaricare file da altri siti.

Per aggiungere un documento a un'area: si copia il file in
`assets/docs/<id-area>/` e si aggiunge un `AreaDocument` alla lista `documents`
dell'area. I nomi dei file sono volutamente ASCII e senza spazi — i diacritici
nei percorsi degli asset sono una fonte classica di build rotte; il titolo
leggibile sta nel campo `title`.

> Non è una raccomandazione di stile: un file con caratteri greci o cirillici
> nel nome fa **crashare `flutter test`** su Windows (il tool percent-codifica
> il nome e il percorso che ne esce non è valido). I file che arrivano dai
> referenti vanno rinominati prima di essere messi sotto `assets/docs/`.

**Word e fogli di calcolo vanno convertiti in PDF prima di entrare nel
bundle.** Il form di caricamento accetta *Documento*, *Foglio di lavoro*,
*PDF* e *Immagine* (max 10 file da 10 MB), quindi un `.docx` è una consegna
legittima: è l'app che non se lo può permettere, perché `open_filex` riesce
ad aprirlo solo se sul telefono c'è Word o equivalente — e su un Android
appena acceso non c'è. La conversione è un passaggio nostro, non una
richiesta da girare ai referenti:

```powershell
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$doc = $word.Documents.Open($percorsoDocx, $false, $true)
$doc.SaveAs([ref]([System.IO.Path]::ChangeExtension($percorsoDocx, '.pdf')), [ref]17)
$doc.Close([ref]0); $word.Quit()
```

Gli originali restano nel mirror locale `PRIMES_Aree_Pilota/<area>/`, fuori
dal repository dell'app: sotto `assets/docs/` ci va solo il PDF.

Il caricamento dei documenti da parte dei referenti sarà una funzionalità del
**cruscotto**: quando ci arriveremo, l'unico punto da cambiare nell'app è la
sorgente dell'elenco, mentre la schermata resta com'è.

## 5. Portale web

La card in *Articoli → Notizie* apre il portale del progetto **dentro l'app**,
in Custom Tab su Android e SFSafariViewController su iOS
(`LaunchMode.inAppBrowserView`). Non è una scelta estetica: App Store e Play
Store contestano le app che si limitano a rimbalzare l'utente sul browser
esterno. `tel:` e `mailto:` restano invece esterni, perché devono arrivare al
telefono e al client di posta veri.

La regola non si sceglie chiamata per chiamata: la decide `launchModeFor` in
[lib/services/area_links.dart](lib/services/area_links.dart) guardando lo
schema dell'URL — http(s) dentro, tutto il resto fuori. Prima la modalità era
un parametro con `externalApplication` come default, e bastava una chiamata
distratta per rimettere in gioco la pubblicazione. `test/area_links_test.dart`
tiene ferma la regola, portale compreso.

Nessuna delle due piattaforme ripiega sul browser esterno se la vista
integrata non è disponibile: su Android `url_launcher` ricade sulla propria
`WebViewActivity`, su iOS resta in `SFSafariViewController`.

L'indirizzo sta in
[lib/config/api_config.dart](lib/config/api_config.dart) (`primesPortalUrl`) e
si può cambiare senza toccare il codice:

```bash
flutter run --dart-define=PORTAL_URL=https://esempio.eu/
```

Su Android 11+ un'app vede solo le altre app che dichiara: browser, telefono e
client di posta sono elencati nel blocco `<queries>` di
`android/app/src/main/AndroidManifest.xml`, gli schemi corrispondenti in
`LSApplicationQueriesSchemes` su iOS. Se si aggiunge un nuovo tipo di link,
vanno aggiornati entrambi.

## 6. Contenuti di esempio

Non ce ne sono più. Sono stati rimossi articoli, ordinanze, notifiche e
documenti finti, insieme alle due schermate che servivano solo a mostrarli
(il visualizzatore PDF fittizio e il dettaglio ordinanza "Comune di Ancona").

Quel che l'app mostra ora viene da tre sole sorgenti: i contenuti dell'area
(§2), il backend (livello di allerta e notifiche) e ciò che l'utente scarica.
Dove non c'è ancora niente — bacheca, articoli — l'app lo dice, invece di
riempire con esempi. Prima che il backend risponda, la card in Home mostra
*Non disponibile*: il livello di allerta lo sa solo il backend, e inventarne
uno sarebbe la cosa peggiore da fare in un sistema di allerta.

## 7. Login e notifiche

**Il login è obbligatorio per ricevere qualsiasi notifica.** L'accesso usa
Firebase Authentication con email e password
([lib/services/auth_service.dart](lib/services/auth_service.dart)); nel progetto
Firebase va attivato il metodo *Email/Password* (vedi il README del backend).

* **All'apertura**: due pulsanti, *Accedi* e *Registrati*. Il menu delle aree
  pilota compare solo in *Registrati*.
* **Registrazione**: area pilota, email e password. L'area va nel profilo
  sul backend e **non si cambia più**. L'app manda subito l'email di conferma,
  nella lingua dell'area scelta, e non fa entrare finché l'indirizzo non è
  confermato. È l'email con cui gli operatori raggiungono l'utente dalle liste
  Excel/CSV, quindi deve essere davvero sua.
* **Accesso**: solo email e password (o Google). L'area si rilegge dal profilo
  ([ProfileGate](lib/main.dart)), quindi è la stessa su qualunque telefono.
  Un account che non ne ha ancora una — per esempio chi entra con Google senza
  essersi registrato — la sceglie lì, una volta sola.
* **Accedi con Google**: stesso effetto, senza password né email di conferma
  (quella di un account Google è già verificata). Su Android funziona solo se
  nel progetto Firebase c'è lo **SHA-1** della chiave con cui è firmata l'app e
  se `android/app/google-services.json` è la versione scaricata *dopo* averlo
  inserito: senza, il pulsante risponde che l'accesso con Google non è
  configurato. Ogni chiave di firma (debug, rilascio, Play App Signing) vuole il
  suo SHA-1.
* **Sessione ricordata**: Firebase conserva la sessione sul dispositivo.
  Chiudendo e riaprendo l'app si entra direttamente in Home, senza rivedere il
  form ([AuthGate](lib/main.dart)). Si esce solo con il pulsante di logout in
  alto a sinistra nella Home.
* **Elimina account** (in fondo a SOS): si conferma scrivendo la propria email
  e spuntando la casella; il motivo è facoltativo. Il backend elimina
  dispositivi, profilo e stato delle notifiche, poi l'utente da Firebase
  Authentication: la stessa email si può registrare di nuovo, anche su
  un'altra area. Del motivo resta solo una traccia anonima (area, testo, data)
  in `accountDeletions`. Sul telefono si cancellano token FCM e allegati
  scaricati.
* **Logout**: il dispositivo viene tolto dal backend e il token FCM cancellato,
  così non riceve più nulla anche se il backend in quel momento non risponde.

### Tap sulla notifica

Toccare una notifica nel pannello di sistema apre l'app **direttamente sul
dettaglio** di quella notifica, in tutti e tre i casi:

| Stato dell'app | Chi lo gestisce |
|---|---|
| chiusa | `FirebaseMessaging.getInitialMessage()` |
| in background | `FirebaseMessaging.onMessageOpenedApp` |
| in primo piano | notifica locale con il contenuto nel payload (Android); su iOS la presenta il sistema e il tap passa da `onMessageOpenedApp` |

La notifica toccata si segna come letta. Se la sessione è scaduta, il dettaglio
si apre subito dopo il login.

### Gestione delle notifiche

Nella schermata Notifiche:

* **pallino rosso** accanto al titolo per quelle da leggere; il contatore sulla
  card *Notifiche* della Home conta solo quelle e scende quando si leggono;
* **tap** apre il dettaglio e segna come letta;
* **pressione prolungata** avvia la selezione, come nei Documenti: poi
  *Seleziona tutte*, *Segna come lette*, *Elimina* (con conferma);
* **✓✓ in alto** segna tutte come lette;
* **trascinare verso il basso** ricarica dal backend.

Lette ed eliminate sono salvate **nel backend, per utente**
(`users/{uid}/inbox` in Firestore): rientrando, o da un altro telefono, restano
come le si è lasciate. Eliminare toglie la notifica solo per quell'utente, non
dallo storico dell'area. Se la rete manca, una lettura viene riprovata al
caricamento successivo; un'eliminazione non riuscita rimette la notifica in
elenco e lo dice.

## 8. Verifiche

```bash
flutter analyze   # nessun problema
flutter test      # 39 test
```

I test in `test/area_content_test.dart` controllano che ogni documento elencato
esista davvero su disco e che la sua cartella sia dichiarata in `pubspec.yaml`:
un refuso in un percorso non si vedrebbe altrimenti fino all'apertura sul
dispositivo. Un altro test verifica che nessuna lingua abbia perso chiavi
rispetto all'inglese.

`test/notifications_test.dart` copre il flag letta/non letta, la deduplica fra
push e storico, il payload che porta dal tap al dettaglio e i controlli del
form di accesso e registrazione.
