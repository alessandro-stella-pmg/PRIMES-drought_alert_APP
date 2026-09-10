# PRIMES Drought-Alert — configurazione

## 1. Lingua per area pilota

La lingua non si sceglie da un menù: **discende dall'area pilota** selezionata al
primo avvio, e cambia all'istante — già nella schermata di login — appena si
seleziona un'area diversa nel dropdown. La mappa area → lingua sta in
[lib/config/pilot_areas.dart](lib/config/pilot_areas.dart):

| Area pilota | Sigla mostrata | Lingua |
|---|---|---|
| Italia — Marche, Emilia-Romagna | `IT` | italiano |
| Hrvatska — Međimurje, Koprivnica-Križevci | `HR` | croato |
| Bosna i Hercegovina — Gradiška | `BS` | bosniaco |
| Crna Gora — Danilovgrad | `SR` | serbo (alfabeto latino) |
| Ελλάδα — Λακωνία | `EL` | greco |
| Srbija — Vojvodina | `SR` | serbo (alfabeto latino) |

La sigla accanto a ogni area nel selettore è derivata dal `locale` dell'area,
quindi non può disallinearsi dalla lingua realmente usata.

La scelta viene salvata sul dispositivo (`shared_preferences`) e si può cambiare
dall'icona 🌍 in alto a destra nella Home.

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

Aree già configurate — le quattro che hanno restituito il form:

| Area | Lingua dei contenuti | Documenti |
|---|---|---|
| `hr-medimurje` (REDEA) | croato, dal form | 7 |
| `hr-koprivnica-krizevci` | croato, dal form | 10 |
| `me-danilovgrad` | **tradotto** dall'inglese del form | 3 |
| `rs-vojvodina` (RDA Bačka) | **tradotto** dall'inglese del form | 0 |

> Danilovgrad e Vojvodina hanno compilato il form in inglese pur avendo scelto
> montenegrino/serbo come lingua dell'app: i testi in `area_content.dart` sono
> una traduzione e **vanno fatti validare dal partner** prima della
> pubblicazione. I punti dubbi sono segnalati da un commento nel file.

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

## 4. Documenti

La schermata mostra due elenchi distinti:

1. **Documenti ufficiali dell'area** — file veri inclusi nell'app, sotto
   `assets/docs/<id-area>/`, elencati in `area_content.dart`. Si aprono con il
   visualizzatore di sistema (`open_filex`): l'asset viene estratto una volta
   sola nella cache del dispositivo e poi riaperto da lì. Non sono
   selezionabili né cancellabili.
2. **Scaricati dalle notifiche** — l'archivio locale `archivioDocumenti` in cima
   a [lib/main.dart](lib/main.dart), alimentato da `aggiungiDocumento`.
   Selezione multipla con pressione prolungata ed eliminazione restano
   invariate.

Per aggiungere un documento a un'area: si copia il file in
`assets/docs/<id-area>/` e si aggiunge un `AreaDocument` alla lista `documents`
dell'area. I nomi dei file sono volutamente ASCII e senza spazi — i diacritici
nei percorsi degli asset sono una fonte classica di build rotte; il titolo
leggibile sta nel campo `title`.

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

## 7. Verifiche

```bash
flutter analyze   # nessun problema
flutter test      # 15 test
```

I test in `test/area_content_test.dart` controllano che ogni documento elencato
esista davvero su disco e che la sua cartella sia dichiarata in `pubspec.yaml`:
un refuso in un percorso non si vedrebbe altrimenti fino all'apertura sul
dispositivo. Un altro test verifica che nessuna lingua abbia perso chiavi
rispetto all'inglese.
