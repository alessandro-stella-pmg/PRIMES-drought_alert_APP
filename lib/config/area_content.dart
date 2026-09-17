import 'package:flutter/material.dart';

/// Contenuti compilati dai referenti di ogni area pilota nel form
/// "PRIMES Drought-alert — Configurazione della tua Area Pilota" (FORM A).
///
/// A differenza delle etichette dell'interfaccia (che stanno in
/// `assets/i18n/<lingua>.json` e sono comuni a tutte le aree), questi testi
/// sono **specifici dell'area**: nomi dei quattro livelli di allerta,
/// comportamenti e restrizioni, regole permanenti, recapiti e archivio
/// documenti. Un'area senza contenuti qui ricade sui testi generici.
///
/// Quando il cruscotto sara' pronto questa mappa diventera' la cache locale di
/// cio' che arriva dal backend: la forma dei dati e' gia' quella giusta.

/// Un livello del sistema di allerta graduato (dal 1 al 4).
@immutable
class AlertLevelInfo {
  /// Nome del livello come lo ha scritto il referente dell'area.
  final String name;

  /// Comportamenti raccomandati e restrizioni attive a questo livello.
  final List<String> rules;

  /// Colore del livello: verde, giallo, arancione, rosso.
  final Color color;

  const AlertLevelInfo({
    required this.name,
    required this.rules,
    required this.color,
  });
}

/// Un recapito utile: numero di telefono oppure indirizzo email.
@immutable
class AreaContact {
  final String label;
  final String value;
  final bool isEmail;

  const AreaContact(this.label, this.value) : isEmail = false;
  const AreaContact.email(this.label, this.value) : isEmail = true;
}

/// Un documento ufficiale dell'area, incluso nel bundle dell'app.
@immutable
class AreaDocument {
  /// Titolo mostrato in lista, nella lingua dell'area.
  final String title;

  /// Percorso dell'asset (dichiarato in `pubspec.yaml`).
  final String asset;

  /// Dimensione gia' formattata: e' un'etichetta, non serve calcolarla.
  final String size;

  const AreaDocument({
    required this.title,
    required this.asset,
    required this.size,
  });

  String get fileName => asset.split('/').last;

  bool get isPdf => asset.toLowerCase().endsWith('.pdf');

  /// Vero per foto e immagini. Il resto — documenti Word, fogli di calcolo —
  /// non e' ne' l'uno ne' l'altro e prende l'icona generica.
  bool get isImage {
    final name = asset.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }
}

/// Tutto cio' che il referente ha dichiarato per la sua area.
@immutable
class AreaContent {
  /// Nome ufficiale dell'area come deve comparire nell'app.
  final String officialName;

  /// I quattro livelli, dal meno al piu' grave.
  final List<AlertLevelInfo> levels;

  /// Restrizioni o regole valide sempre, a prescindere dal livello.
  final List<String> permanentRules;

  /// Numeri di emergenza e indirizzi email.
  final List<AreaContact> contacts;

  /// Orari di reperibilita' dei contatti.
  final String? contactHours;

  /// Documenti ufficiali forniti dall'area.
  final List<AreaDocument> documents;

  const AreaContent({
    required this.officialName,
    required this.levels,
    this.permanentRules = const [],
    this.contacts = const [],
    this.contactHours,
    this.documents = const [],
  });
}

const Color _green = Color(0xFF2E7D32);
const Color _yellow = Color(0xFFF9A825);
const Color _orange = Color(0xFFEF6C00);
const Color _red = Color(0xFFD32F2F);

/// Le aree che hanno restituito il form. Le altre non compaiono: per loro
/// l'app continua a mostrare i testi generici tradotti.
const Map<String, AreaContent> areaContents = {
  'hr-medimurje': _medimurje,
  'hr-koprivnica-krizevci': _koprivnicaKrizevci,
  'ba-gradiska': _gradiska,
  'me-danilovgrad': _danilovgrad,
  'rs-vojvodina': _vojvodina,
  'gr-paggaio': _paggaio,
};

AreaContent? areaContentFor(String? areaId) =>
    areaId == null ? null : areaContents[areaId];

/// Chiavi dei livelli usate dal backend, dal meno al piu' grave: e' l'ordine
/// in cui stanno anche i quattro livelli di ogni area.
const List<String> backendLevelKeys = ['none', 'level1', 'level2', 'level3'];

/// Etichette italiane di servizio del backend.
///
/// Servono da ripiego: il cruscotto attuale manda `level` e `colorHex` ma non
/// la `key`, quindi senza questa tabella il livello non si potrebbe ricondurre
/// a quello dell'area. Quando il cruscotto mandera' la chiave, questa mappa
/// diventera' inutile e si potra' togliere.
const Map<String, String> _backendLevelLabels = {
  'Nessuna carenza': 'none',
  'Livello 1 - Monitoraggio': 'level1',
  'Livello 2 - Allarme': 'level2',
  'Livello 3 - Avviso di carenza': 'level3',
};

/// La chiave canonica del livello annunciato dal backend, `null` se non si
/// riconosce.
///
/// Serve anche alle aree che non hanno restituito il form: senza `AreaContent`
/// il nome del livello va preso dalle traduzioni generiche di
/// `assets/i18n/`, e per pescarlo li' dentro serve comunque la chiave.
String? backendLevelKeyFor({String? key, String? backendLabel}) {
  final resolved = (key != null && key.isNotEmpty)
      ? key
      : _backendLevelLabels[backendLabel?.trim()];
  return backendLevelKeys.contains(resolved) ? resolved : null;
}

/// Il livello dell'area corrispondente a quello annunciato dal backend.
///
/// Restituisce `null` se l'area non e' configurata o se il livello non si
/// riconosce: in quel caso chi chiama ripiega sul nome generico tradotto.
AlertLevelInfo? areaLevelFor({
  required String? areaId,
  String? key,
  String? backendLabel,
}) {
  final content = areaContentFor(areaId);
  if (content == null) return null;

  final resolved = backendLevelKeyFor(key: key, backendLabel: backendLabel);
  final index = backendLevelKeys.indexOf(resolved ?? '');
  if (index < 0 || index >= content.levels.length) return null;
  return content.levels[index];
}

// ---------------------------------------------------------------------------
// Hrvatska - Medimurska zupanija (REDEA)
// Form compilato il 30/07/2026 da sanja.pintaric@redea.hr, in croato.
// ---------------------------------------------------------------------------
const AreaContent _medimurje = AreaContent(
  officialName: 'Međimurska županija',
  levels: [
    AlertLevelInfo(
      name: 'Nema nestašice – redovno stanje',
      color: _green,
      rules: [
        'Koristite vodu za ljudsku potrošnju odgovorno i izbjegavajte nepotrebnu potrošnju.',
        'Bez odgode popravite ili prijavite uočena curenja vode.',
        'Vrtove zalijevajte rano ujutro ili navečer.',
        'Za zalijevanje koristite prikupljenu kišnicu kad god je to moguće.',
        'Koristite uređaje i opremu koji štede vodu.',
        'Pratite službene obavijesti Međimurskih voda i nadležnih tijela.',
        'Na ovoj razini nema aktivnih ograničenja.',
      ],
    ),
    AlertLevelInfo(
      name: 'Rano upozorenje – smanjena raspoloživost vode',
      color: _yellow,
      rules: [
        'Smanjite sve oblike nepotrebne potrošnje vode.',
        'Izbjegavajte zalijevanje travnjaka i ukrasnog bilja tijekom dana.',
        'Vrtove zalijevajte samo rano ujutro ili navečer.',
        'Za zalijevanje koristite kišnicu ili druge dopuštene izvore vode kad god je to moguće.',
        'Odgodite punjenje i nadopunjavanje privatnih bazena.',
        'Izbjegavajte pranje vozila, dvorišta, prilaza i drugih površina vodom za ljudsku potrošnju.',
        'Provjerite postoje li curenja u kućnim, poslovnim i sustavima za navodnjavanje.',
        'Poljoprivrednici i poslovni korisnici trebaju pripremiti mjere za smanjenje potrošnje vode.',
        'Pratite službene obavijesti Međimurskih voda i nadležnih tijela.',
        'Mjere na ovoj razini imaju karakter preporuke, osim ako službenom odlukom nije određeno drukčije.',
      ],
    ),
    AlertLevelInfo(
      name: 'Upozorenje – značajna nestašica vode',
      color: _orange,
      rules: [
        'Vodu za ljudsku potrošnju koristite prvenstveno za piće, pripremu hrane, osobnu higijenu i osnovne potrebe kućanstva.',
        'Ne koristite vodu za ljudsku potrošnju za zalijevanje travnjaka i ukrasnih zelenih površina.',
        'Ne punite i ne nadopunjavajte privatne bazene vodom za ljudsku potrošnju.',
        'Ne koristite vodu za ljudsku potrošnju za pranje vozila, ulica, dvorišta, prilaza, zgrada i drugih površina.',
        'Zalijevanje vrtova smanjite na najmanju potrebnu mjeru te koristite kišnicu ili druge dopuštene izvore.',
        'Javne ustanove, poslovni subjekti i poljoprivredni korisnici trebaju primijeniti vlastite mjere štednje vode.',
        'Odmah prijavite veća curenja ili oštećenja na vodoopskrbnoj mreži.',
        'Poštujte sva ograničenja i upute koje službeno objave Međimurske vode ili druga nadležna tijela.',
        'Ograničenja su obvezna kada su uvedena službenom odlukom nadležnog tijela.',
      ],
    ),
    AlertLevelInfo(
      name: 'Teška nestašica – izvanredne mjere',
      color: _red,
      rules: [
        'Vodu za ljudsku potrošnju koristite samo za piće, pripremu hrane, osobnu higijenu, zdravstvene potrebe i druge nužne potrebe.',
        'Obvezno poštujte sva ograničenja koja službeno uvedu Međimurske vode ili druga nadležna tijela.',
        'Zabranjeno je zalijevanje vrtova, travnjaka i ukrasnih zelenih površina vodom za ljudsku potrošnju ako je tako određeno službenom odlukom.',
        'Zabranjeno je punjenje i nadopunjavanje bazena vodom za ljudsku potrošnju ako je tako određeno službenom odlukom.',
        'Zabranjeno je pranje vozila, ulica, dvorišta, prilaza, zgrada i drugih površina vodom za ljudsku potrošnju ako je tako određeno službenom odlukom.',
        'Može se privremeno obustaviti rad ukrasnih fontana, vodoskoka i drugih objekata koji nisu nužni za osnovnu opskrbu.',
        'Opskrba vodom, tlak u mreži, dopuštene količine ili vrijeme isporuke mogu biti ograničeni prema službenim uputama.',
        'Pratite informacije o alternativnim mjestima opskrbe vodom u slučaju duljih prekida.',
        'Prednost imaju potrebe stanovništva za pićem, zdravstvena zaštita, higijena, vatrogastvo i druge osnovne javne službe.',
        'Odmah prijavite veća curenja, oštećenja mreže i hitne probleme u opskrbi vodom.',
      ],
    ),
  ],
  permanentRules: [
    'Koristite vodu za ljudsku potrošnju odgovorno i izbjegavajte nepotrebnu potrošnju.',
    'Neovlašteno korištenje hidranata i drugih objekata javne vodoopskrbe nije dopušteno.',
    'Ne oštećujte i ne mijenjajte vodomjere, priključke i drugu infrastrukturu javne vodoopskrbe.',
    'Prijavite uočena curenja i oštećenja na javnoj vodoopskrbnoj mreži.',
    'Pratite službene obavijesti i upute Međimurskih voda i drugih nadležnih tijela.',
    'Ograničenja prikazana u aplikaciji obvezna su kada su uvedena službenom odlukom nadležnog tijela.',
  ],
  contacts: [
    AreaContact('Jedinstveni europski broj za hitne službe', '112'),
    AreaContact(
      'Međimurske vode – dežurna služba za prijavu kvarova',
      '0800 313 111',
    ),
    AreaContact(
      'Međimurske vode – dežurna služba (alternativni broj)',
      '+385 40 370 730',
    ),
    AreaContact.email(
      'Međimurske vode – prijava kvarova',
      'prijava.kvarova@medjimurske-vode.hr',
    ),
    AreaContact.email(
      'Međimurske vode – opći upiti',
      'voda@medjimurske-vode.hr',
    ),
  ],
  contactHours:
      'Međimurske vode – dežurna služba za prijavu kvarova: 24/7\n'
      'Jedinstveni europski broj za hitne službe 112: 24/7\n'
      'Međimurske vode – opći upiti: ponedjeljak–petak 7:00–15:00',
  documents: [
    AreaDocument(
      title: 'Godišnji plan zaštite od prirodnih nepogoda',
      asset: 'assets/docs/hr-medimurje/godisnji-plan-prirodne-nepogode.pdf',
      size: '129 KB',
    ),
    AreaDocument(
      title: 'Plan djelovanja civilne zaštite Međimurske županije (2024.)',
      asset: 'assets/docs/hr-medimurje/plan-civilne-zastite-2024.pdf',
      size: '2.9 MB',
    ),
    AreaDocument(
      title: 'Program klimatskih promjena Međimurske županije',
      asset: 'assets/docs/hr-medimurje/program-klimatske-promjene.pdf',
      size: '4.1 MB',
    ),
    AreaDocument(
      title: 'Program zaštite okoliša 2022. – 2025.',
      asset: 'assets/docs/hr-medimurje/program-zastite-okolisa-2022-2025.pdf',
      size: '2.9 MB',
    ),
    AreaDocument(
      title: 'Proglašena prirodna nepogoda suše',
      asset: 'assets/docs/hr-medimurje/proglasena-nepogoda-susa.pdf',
      size: '243 KB',
    ),
    AreaDocument(
      title: 'Župan proglasio prirodnu nepogodu od suše',
      asset: 'assets/docs/hr-medimurje/zupan-proglasio-nepogodu-susa.pdf',
      size: '231 KB',
    ),
    AreaDocument(
      title: 'Zahtjev za utvrđivanje štete od suše',
      asset: 'assets/docs/hr-medimurje/zahtjev-utvrdivanje-stete-susa.pdf',
      size: '219 KB',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Hrvatska - Koprivnicko-krizevacka zupanija
// Form compilato il 24/07/2026 da eu.kckz@gmail.com, in croato.
// ---------------------------------------------------------------------------
const AreaContent _koprivnicaKrizevci = AreaContent(
  officialName: 'Koprivničko-križevačka županija',
  levels: [
    AlertLevelInfo(
      name: 'Razina 1 – Nema nestašice vode',
      color: _green,
      rules: [
        'Nema ograničenja korištenja vode.',
        'Odgovorno koristiti vodu u svakodnevnim aktivnostima.',
      ],
    ),
    AlertLevelInfo(
      name: 'Razina 2 – Upozorenje / Moguća nestašica vode',
      color: _yellow,
      rules: [
        'Smanjiti nepotrebnu potrošnju vode u kućanstvu.',
        'Za nepitke namjene koristiti alternativne izvore vode gdje je moguće.',
      ],
    ),
    AlertLevelInfo(
      name: 'Razina 3 – Upozorenje / Ograničeno korištenje vode',
      color: _orange,
      rules: [
        'Ograničiti korištenje pitke vode za neesencijalne svrhe.',
        'Ograničiti korištenje pitke vode za aktivnosti koje nisu nužne.',
      ],
    ),
    AlertLevelInfo(
      name: 'Razina 4 – Izražena nestašica vode',
      color: _red,
      rules: [
        'Ograničiti korištenje pitke vode na osnovne potrebe.',
        'Ne koristiti pitku vodu za neesencijalne potrebe.',
        'Smanjiti potrošnju pitke vode na najmanju moguću mjeru.',
      ],
    ),
  ],
  permanentRules: [
    'Odgovorno koristiti pitku vodu.',
    'Ne onečišćavati izvore vode i vodne površine.',
  ],
  contacts: [
    AreaContact('Jedinstveni broj za hitne službe', '112'),
    AreaContact('Hitna medicinska služba', '194'),
    AreaContact('Policija', '192'),
    AreaContact('Vatrogasci', '193'),
    AreaContact('Stožer civilne zaštite KKŽ', '+385 48 658 204'),
  ],
  contactHours:
      'Hitne službe: 24/7\n'
      'Stožer civilne zaštite KKŽ: pon–pet 7:00–15:00',
  documents: [
    AreaDocument(
      title: 'Proglašena prirodna nepogoda – suša 2022.',
      asset:
          'assets/docs/hr-koprivnica-krizevci/natural-disaster-drought-2022.pdf',
      size: '372 KB',
    ),
    AreaDocument(
      title: 'Proglašena prirodna nepogoda – suša 2024.',
      asset:
          'assets/docs/hr-koprivnica-krizevci/natural-disaster-drought-2024.pdf',
      size: '379 KB',
    ),
    AreaDocument(
      title: 'Proglašena prirodna nepogoda – suša 2025.',
      asset:
          'assets/docs/hr-koprivnica-krizevci/natural-disaster-drought-2025.pdf',
      size: '369 KB',
    ),
    AreaDocument(
      title: 'Obavijest – upute i mjere 2023.',
      asset:
          'assets/docs/hr-koprivnica-krizevci/notice-instructions-measures-2023.pdf',
      size: '928 KB',
    ),
    AreaDocument(
      title: 'Obrana od poplava na Dravi 2023.',
      asset: 'assets/docs/hr-koprivnica-krizevci/drava-floods-2023.pdf',
      size: '4.8 MB',
    ),
    AreaDocument(
      title: 'Rizik od visokih temperatura',
      asset: 'assets/docs/hr-koprivnica-krizevci/high-temperature-risk.png',
      size: '191 KB',
    ),
    AreaDocument(
      title: 'Suho poljoprivredno tlo (1)',
      asset: 'assets/docs/hr-koprivnica-krizevci/dry-agricultural-soil-1.jpg',
      size: '3.4 MB',
    ),
    AreaDocument(
      title: 'Suho poljoprivredno tlo (2)',
      asset: 'assets/docs/hr-koprivnica-krizevci/dry-agricultural-soil-2.jpg',
      size: '3.9 MB',
    ),
    AreaDocument(
      title: 'Suho tlo',
      asset: 'assets/docs/hr-koprivnica-krizevci/dry-soil.jpg',
      size: '5.0 MB',
    ),
    AreaDocument(
      title: 'Presušeni vodotok',
      asset: 'assets/docs/hr-koprivnica-krizevci/dry-stream.jpg',
      size: '3.9 MB',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Bosna i Hercegovina - Gradiska
// Form compilato il 14/09/2026 da ivana.mirjanic1@gmail.com.
// ATTENZIONE: form compilato in inglese con il bosniaco come lingua dell'app.
// I testi qui sotto sono la traduzione dei suoi contenuti: vanno fatti
// validare dal partner prima della pubblicazione.
// Il PDF delle risposte aveva celle troncate: i testi completi sono stati
// forniti a parte il 14/09/2026. Il nome del livello 4 nel form mancava (il
// campo conteneva le restrizioni del livello 3): quello qui sotto e' una
// proposta ricavata dagli altri tre nomi, da far confermare al partner.
// Nessun documento consegnato: la cartella PRIMES_Aree_Pilota/5_BA_Gradiska
// e' vuota.
// ---------------------------------------------------------------------------
const AreaContent _gradiska = AreaContent(
  officialName: 'Grad Gradiška',
  levels: [
    AlertLevelInfo(
      name: 'Nema nestašice – redovno stanje',
      color: _green,
      rules: [
        'Voda se može koristiti bez posebnih ograničenja, uz poticanje racionalne potrošnje.',
        'Zalijevanje bašta, travnjaka i zelenih površina dozvoljeno je bez vremenskih ograničenja.',
        'Pranje vozila, dvorišta i terasa je dozvoljeno.',
        'Punjenje privatnih bazena i baštenskih ribnjaka je dozvoljeno.',
        'Građani se pozivaju da uočene kvarove i curenja na javnoj vodovodnoj mreži prijave nadležnom javnom komunalnom preduzeću.',
      ],
    ),
    AlertLevelInfo(
      name: 'Nivo pripravnosti (blaga nestašica vode)',
      color: _yellow,
      rules: [
        'Građani se pozivaju da svjesno smanje potrošnju vode na neophodne potrebe.',
        'Zalijevanje bašta i travnjaka treba izbjegavati između 10:00 i 18:00.',
        'Preporučuje se zalijevanje kantom umjesto crijevom, najbolje u ranim jutarnjim ili večernjim satima.',
        'Pranje vozila kod kuće treba svesti na najmanju mjeru; umjesto toga koristite autopraonice sa sistemom recirkulacije vode.',
        'Punjenje privatnih bazena treba odgoditi.',
        'Treba provjeriti i popraviti kućne vodovodne instalacije i slavine koje cure.',
      ],
    ),
    AlertLevelInfo(
      name: 'Nivo ograničenja (umjerena nestašica vode)',
      color: _orange,
      rules: [
        'Zabranjeno je zalijevanje bašta, travnjaka i zelenih površina vodom iz gradske vodovodne mreže.',
        'Zabranjeno je pranje vozila, dvorišta, terasa i fasada vodom iz javne vodovodne mreže.',
        'Zabranjeno je punjenje i dopunjavanje bazena i baštenskih ribnjaka.',
        'Vodu iz javne vodovodne mreže treba prvenstveno koristiti za piće, pripremu hrane i higijenu.',
        'Pravna lica i ugostiteljski objekti dužni su smanjiti potrošnju vode koja nije neophodna za njihovu osnovnu djelatnost.',
        'U pojedinim DMA zonama mogu se uvesti noćna smanjenja pritiska ili snabdijevanja vodom, o čemu će građani biti obaviješteni putem aplikacije.',
      ],
    ),
    AlertLevelInfo(
      // Proposta: nel form il nome mancava. Segue lo schema degli altri tre
      // ("Preparedness Level", "Restriction Level" -> "Emergency Measures
      // Level") e il contenuto: uso solo per bere, igiene e cibo, autobotti,
      // riduzioni programmate. Da far confermare al partner.
      name: 'Nivo vanrednih mjera (teška nestašica vode)',
      color: _red,
      rules: [
        'Voda iz javne vodovodne mreže smije se koristiti isključivo za piće, osnovnu higijenu i pripremu hrane.',
        'Zalijevanje, pranje vozila i površina te punjenje bazena potpuno su zabranjeni.',
        'Planirana smanjenja u snabdijevanju vodom uvodit će se po zonama, prema rasporedu koji objavljuje javno komunalno preduzeće.',
        'Voda će se dopremati autocisternama na unaprijed određena mjesta distribucije u pogođenim područjima.',
        'Prednost u snabdijevanju vodom imaju bolnice, domovi zdravlja, škole, vrtići i druge ustanove od javnog značaja.',
        'Građanima se preporučuje da drže manje kućne zalihe pitke vode i prate službena obavještenja putem aplikacije.',
      ],
    ),
  ],
  permanentRules: [
    'Zabranjeni su neovlašteni priključci na javnu vodovodnu mrežu i neovlašteno korištenje hidranata.',
    'Svako uočeno curenje ili kvar na javnoj vodovodnoj mreži treba prijaviti nadležnom javnom komunalnom preduzeću.',
    'Zabranjeno je ispuštanje pitke vode iz javne vodovodne mreže u tehničke svrhe kada je dostupan alternativni izvor, poput bunara ili kišnice.',
    'Tokom cijele godine preporučuje se prikupljanje i korištenje kišnice za zalijevanje i druge namjene za koje nije potrebna pitka voda.',
  ],
  // I numeri locali del form (051, 065, 063) sono in formato internazionale,
  // cosi' la chiamata parte anche da una SIM straniera. Una parte dei telefoni
  // era nel campo delle email del form: qui stanno tutti tra i numeri.
  contacts: [
    AreaContact('Civilna zaštita – dežurni broj', '121'),
    // Il form da' lo stesso numero a Odjeljenje e al centro operativo.
    AreaContact(
      'Odjeljenje civilne zaštite Grada Gradiške / Operativno-komunikacijski centar',
      '+387 51 814 753',
    ),
    AreaContact(
      'Načelnik Odjeljenja civilne zaštite, Slobodan Knežević',
      '+387 65 238 905',
    ),
    AreaContact('Vatrogasci – hitni broj', '123'),
    AreaContact(
      'Profesionalna vatrogasno-spasilačka jedinica Gradiška',
      '+387 51 814 754',
    ),
    AreaContact(
      'Profesionalna vatrogasno-spasilačka jedinica Gradiška – dežurna služba',
      '+387 51 814 724',
    ),
    AreaContact('Vodovod Gradiška – dežurni telefon', '+387 51 815 199'),
    AreaContact('Vodovod Gradiška – dežurni telefon', '+387 65 090 909'),
    AreaContact('Vodovod Gradiška – dežurni telefon', '+387 63 394 815'),
    AreaContact('Vodovod Gradiška – centrala', '+387 51 813 733'),
    AreaContact.email(
      'Odjeljenje civilne zaštite Grada Gradiške',
      'czgradiska@yahoo.com',
    ),
    AreaContact.email(
      'Profesionalna vatrogasno-spasilačka jedinica Gradiška',
      'pvjgradiska@gmail.com',
    ),
    AreaContact.email('Vodovod Gradiška', 'info@vodovodgradiska.com'),
  ],
  contactHours:
      'Hitni brojevi 121 (civilna zaštita) i 123 (vatrogasci) dostupni su 24/7, svakog dana u sedmici.\n'
      'Dežurna služba vatrogasno-spasilačke jedinice i dežurni telefoni Vodovoda dostupni su 24/7, uključujući vikende i praznike.\n'
      'Kancelarija Odjeljenja civilne zaštite i centrala Vodovoda dostupni su radnim danima od 07:00 do 15:00.',
);

// ---------------------------------------------------------------------------
// Crna Gora - Danilovgrad
// Form compilato il 28/07/2026 da glorija.scepanovic@danilovgrad.me.
// ATTENZIONE: il referente ha compilato il form in inglese, ma ha indicato il
// montenegrino come lingua dell'app. I testi qui sotto sono la traduzione dei
// suoi contenuti: vanno fatti validare dal partner prima della pubblicazione.
// ---------------------------------------------------------------------------
const AreaContent _danilovgrad = AreaContent(
  officialName: 'Danilovgrad',
  levels: [
    AlertLevelInfo(
      name: 'Nema nestašice',
      color: _green,
      // Il form riporta "No garden watering" gia' al livello 1: da confermare.
      rules: ['Bez zalijevanja bašta.'],
    ),
    AlertLevelInfo(
      name: 'Umjerena suša',
      color: _yellow,
      rules: ['Smanjite nepotrebnu potrošnju vode u domaćinstvu.'],
    ),
    AlertLevelInfo(
      name: 'Izražena nestašica',
      color: _orange,
      rules: [
        'Smanjite potrošnju vode u domaćinstvu na najmanju moguću mjeru.',
        'Izbjegavajte nepotrebnu upotrebu vode u svim aktivnostima.',
        'Zabranjeno je loženje vatre na otvorenom tokom ljetnjih mjeseci.',
      ],
    ),
    AlertLevelInfo(
      name: 'Kritična suša',
      color: _red,
      rules: [
        'Stroga zabrana upotrebe vode za nebitne namjene.',
        'Zabranjeno zalijevanje bašta, osim za neophodne poljoprivredne potrebe.',
        'Zabranjeno punjenje bazena.',
        'Zabranjeno pranje vozila i spoljnih površina vodom za piće.',
        'Obavezno smanjenje potrošnje vode u domaćinstvu.',
        'Prioritetno korišćenje raspoloživih vodnih resursa za piće i osnovne potrebe.',
        'Zabranjeno loženje vatre na otvorenom tokom ljetnjih mjeseci.',
      ],
    ),
  ],
  permanentRules: [
    'Loženje vatre na otvorenom zabranjeno je tokom ljetnjih mjeseci zbog rizika od požara.',
    'Građani se pozivaju da vodu koriste odgovorno tokom cijele godine.',
    'Izbjegavajte nepotrebnu potrošnju vode.',
    'Prijavite curenja vode i nekontrolisanu potrošnju.',
  ],
  contacts: [
    AreaContact('Jedinstveni broj za hitne slučajeve', '112'),
    AreaContact('Hitne službe', '123'),
    AreaContact.email(
      'Služba zaštite i spašavanja',
      'sluzba.zastite@danilovgrad.me',
    ),
  ],
  contactHours: '24/7',
  documents: [
    AreaDocument(
      title: 'LEAP 2026–2030 – Opština Danilovgrad',
      asset: 'assets/docs/me-danilovgrad/leap-2026-2030.pdf',
      size: '2.4 MB',
    ),
    AreaDocument(
      title: 'Strateški plan razvoja opštine Danilovgrad 2024–2029',
      asset: 'assets/docs/me-danilovgrad/strateski-plan-2024-2029.pdf',
      size: '9.0 MB',
    ),
    AreaDocument(
      title: 'Danilovgrad – fotografija terena',
      asset: 'assets/docs/me-danilovgrad/danilovgrad-teren.jpg',
      size: '4.0 MB',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Srbija - Vojvodina (RDA Backa)
// Form compilato il 01/09/2026 da andrea.stijepic@rda-backa.rs.
// Anche qui il form e' arrivato in inglese con il serbo come lingua dell'app:
// traduzione da far validare al partner. I documenti sono arrivati in .docx
// (il form lo consente) e sono stati convertiti in PDF: gli originali stanno
// nel mirror locale PRIMES_Aree_Pilota/8_RS_Vojvodina_Backa.
// ---------------------------------------------------------------------------
const AreaContent _vojvodina = AreaContent(
  officialName: 'Vojvodina',
  levels: [
    AlertLevelInfo(
      name: 'Nivo 1 – Nema nestašice',
      color: _green,
      rules: ['Nema ograničenja.'],
    ),
    AlertLevelInfo(
      name: 'Nivo 2 – Umerena nestašica vode',
      color: _yellow,
      rules: [
        'Građani se pozivaju da vodu koriste odgovorno i izbegavaju nepotrebnu potrošnju.',
        'Zabranjeno zalivanje bašta od 8:00 do 20:00.',
        'Izbegavajte pranje vozila i punjenje privatnih bazena.',
        'Vodu za piće koristite odgovorno.',
      ],
    ),
    AlertLevelInfo(
      name: 'Nivo 3 – Visoka nestašica vode',
      color: _orange,
      rules: [
        'Zabranjena je upotreba vode na otvorenom.',
        'Bez zalivanja bašta, pranja vozila i punjenja bazena.',
        'Smanjite potrošnju vode u domaćinstvu isključivo na osnovne potrebe.',
      ],
    ),
    AlertLevelInfo(
      name: 'Nivo 4 – Ozbiljna nestašica vode',
      color: _red,
      rules: [
        'Upotreba vode ograničena je isključivo na osnovne potrebe domaćinstva.',
        'Zabranjena je upotreba vode na otvorenom.',
        'Lokalno vodovodno preduzeće može uvesti dodatna ograničenja i privremene prekide u snabdevanju.',
      ],
    ),
  ],
  permanentRules: [
    'Građani se pozivaju da vodu koriste odgovorno i izbegavaju nepotrebnu potrošnju.',
    'Vodu za piće koristite odgovorno u svakom trenutku.',
    'Izbegavajte nepotrebnu potrošnju vode, popravite slavine koje cure i koristite uređaje koji štede vodu gde god je to moguće.',
    'Prijavite curenja na javnoj vodovodnoj mreži lokalnom vodovodnom preduzeću.',
  ],
  contacts: [
    AreaContact('JVP „Vode Vojvodine" – korisnički servis', '0800 21 21 21'),
    AreaContact('JVP „Vode Vojvodine" – centrala', '+381 21 4881 888'),
    AreaContact(
      'Pokrajinski sekretarijat za poljoprivredu, vodoprivredu i šumarstvo',
      '+381 21 487 4411',
    ),
    AreaContact.email('JVP „Vode Vojvodine"', 'office@vodevojvodine.rs'),
    AreaContact.email(
      'Pokrajinski sekretarijat za poljoprivredu, vodoprivredu i šumarstvo',
      'psp@vojvodina.gov.rs',
    ),
  ],
  contactHours:
      'JVP „Vode Vojvodine" – korisnički servis: pon–pet 08:00–14:00\n'
      'Pokrajinski sekretarijat za poljoprivredu, vodoprivredu i šumarstvo: pon–pet 08:00–16:00',
  documents: [
    AreaDocument(
      title: 'Suše u Vojvodini – edukativni vodič kroz osnovne pojmove',
      asset: 'assets/docs/rs-vojvodina/suse-u-vojvodini-edukativni-vodic.pdf',
      size: '560 KB',
    ),
    AreaDocument(
      title: 'Uputstvo za štednju vode',
      asset: 'assets/docs/rs-vojvodina/uputstvo-za-stednju-vode.pdf',
      size: '147 KB',
    ),
    AreaDocument(
      title:
          'Edukativni kutak – podkasti i video-sadržaji o suši i klimatskim promenama',
      asset: 'assets/docs/rs-vojvodina/edukativni-kutak-podkasti-video.pdf',
      size: '1021 KB',
    ),
    AreaDocument(
      title: 'Preporučeni domaći članci o suši 2011–2026 (srpski i engleski)',
      asset: 'assets/docs/rs-vojvodina/preporuceni-clanci-o-susi-2011-2026.pdf',
      size: '421 KB',
    ),
  ],
);

// ---------------------------------------------------------------------------
// Ellada - Perifereiaki Enotita Kavalas, Dimos Paggaiou
// Form compilato il 13/09/2026 da gsylaios@env.duth.gr, in greco.
// ATTENZIONE: nel form il campo "nome del livello 2" ripete quello del livello
// 1 ("Level 1 = Kamia Elleipsi Nerou"). E' un errore di chi ha compilato, non
// nostro: i due livelli qui portano lo stesso nome perche' il form dice cosi'.
// Non "aggiustarlo" inventando un nome - deve restare visibile finche' il
// partner greco non manda la correzione. Le restrizioni dei due livelli, quelle
// sono diverse gia' nel form.
// ---------------------------------------------------------------------------
const AreaContent _paggaio = AreaContent(
  // Il form indica "Paggaio Municipality" (in inglese) con il greco come
  // lingua dell'app: qui sta il nome greco, da far validare.
  officialName: 'Δήμος Παγγαίου',
  levels: [
    AlertLevelInfo(
      name: 'Καμία Έλλειψη Νερού',
      color: _green,
      rules: [
        'Μην σπαταλάτε το νερό, ενημερωθείτε για δράσεις εξοικονόμησης νερού.',
      ],
    ),
    AlertLevelInfo(
      // Si', uguale al livello 1: e' quello che ha scritto il referente.
      name: 'Καμία Έλλειψη Νερού',
      color: _yellow,
      rules: ['Μην ποτίζετε τους κήπους σας μεταξύ 8:00 και 20:00.'],
    ),
    AlertLevelInfo(
      name: 'Σημαντική Έλλειψη Νερού',
      color: _orange,
      rules: [
        'Αποφυγή πλυσίματος πεζοδρομίων, αυλών και αυτοκινήτων με λάστιχο.',
      ],
    ),
    AlertLevelInfo(
      name: 'Έντονη Έλλειψη Νερού',
      color: _red,
      rules: ['Περιορίστε τη χρήση νερού στις απολύτως απαραίτητες.'],
    ),
  ],
  permanentRules: ['Συλλογή, εξοικονόμηση και επαναχρησιμοποίηση νερού.'],
  contacts: [
    // Il form riporta il numero in formato internazionale "0030 25920 41000".
    AreaContact('ΔΕΥΑ Παγγαίου', '+30 25920 41000'),
    AreaContact.email('ΔΕΥΑ Παγγαίου', 'grammateia@deyapaggaiou.gr'),
  ],
  contactHours: 'Δευ–Παρ 8:00–20:00, Σαβ 8:00–13:00',
  documents: [
    AreaDocument(
      title: 'Ξηρασία',
      asset: 'assets/docs/gr-paggaio/drought.pdf',
      size: '207 KB',
    ),
    AreaDocument(
      title: 'Κλιματική Αλλαγή',
      asset: 'assets/docs/gr-paggaio/climate-change.pdf',
      size: '99 KB',
    ),
    AreaDocument(
      title:
          'Πώς η σταδιακή αλλαγή του κλίματος επηρεάζει τα μοτίβα βροχόπτωσης στην Καβάλα',
      asset: 'assets/docs/gr-paggaio/rainfall-patterns-kavala.pdf',
      size: '127 KB',
    ),
    AreaDocument(
      title: 'Η συστηματική παρακολούθηση παράκτιας ζώνης του Δήμου Παγγαίου',
      asset: 'assets/docs/gr-paggaio/coastal-zone-monitoring.pdf',
      size: '162 KB',
    ),
    AreaDocument(
      title:
          'Τεχνολογίες βασισμένες στη Φύση για την επεξεργασία λυμάτων στη Μουσθένη και Μεσορρόπη',
      asset: 'assets/docs/gr-paggaio/nature-based-wastewater-treatment.pdf',
      size: '125 KB',
    ),
    AreaDocument(
      title: 'Χρονοσειρά του δείκτη ξηρασίας SPEI',
      asset: 'assets/docs/gr-paggaio/spei-timeseries.png',
      size: '43 KB',
    ),
  ],
);
