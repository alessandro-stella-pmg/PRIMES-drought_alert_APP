# Documenti delle aree pilota

Una cartella per area pilota, con lo stesso identificativo usato in
`lib/config/pilot_areas.dart`. Qui dentro vanno i documenti ufficiali che i
referenti consegnano (PDF, immagini): finiscono nel bundle dell'app e sono
consultabili anche senza rete.

| Cartella Drive (`PRIMES_Aree_Pilota`) | Cartella qui                       |
| ------------------------------------- | ---------------------------------- |
| `1_IT_Marche_VivaServizi`             | `it-marche/`                       |
| `2_IT_EmiliaRomagna_RomagnaAcque`     | `it-emilia-romagna/`               |
| `3_HR_Medimurje_REDEA`                | `hr-medimurje/`                    |
| `4_HR_KoprivnicaKrizevci`             | `hr-koprivnica-krizevci/`          |
| `5_BA_Gradiska`                       | `ba-gradiska/`                     |
| `6_ME_Danilovgrad`                    | `me-danilovgrad/`                  |
| `7_GR_Kavala/Paggaio`                 | `gr-paggaio/`                      |
| `8_RS_Vojvodina_Backa`                | `rs-vojvodina/`                    |

## Come aggiungere un documento

1. Copia il file nella cartella dell'area. Nome in minuscolo, senza spazi ne'
   accenti, con il trattino come separatore (`plan-civilne-zastite-2024.pdf`):
   il nome del file compare nel visualizzatore di sistema quando l'utente apre
   il documento.
2. Aggiungi la voce nella lista `documents` dell'area in
   `lib/config/area_content.dart`, con titolo nella lingua dell'area, percorso
   dell'asset e dimensione gia' formattata. Un file copiato qui ma non
   dichiarato la' non viene mostrato in app.
3. `flutter pub get` non serve: le cartelle sono gia' tutte dichiarate in
   `pubspec.yaml`. Basta rilanciare l'app (hot restart, non hot reload).

Il punto 1 non e' pignoleria: un nome con caratteri greci o cirillici fa
crashare `flutter test` su Windows.

Il form di caricamento accetta anche Word e fogli di calcolo, ma qui dentro
ci va solo il PDF: `open_filex` apre un `.docx` solo se sul telefono c'e'
Word o equivalente. La conversione la facciamo noi (vedi `CONFIGURAZIONE.md`,
sezione Documenti); l'originale resta in `PRIMES_Aree_Pilota/<area>/`.

Le aree senza contenuti in `area_content.dart` (`it-marche`,
`it-emilia-romagna`, `ba-gradiska`) mostrano ancora i testi generici
tradotti: per loro serve prima il FORM A compilato dal referente.

Il file `.gitkeep` nelle cartelle vuote serve solo a farle esistere in git:
cancellalo quando arriva il primo documento vero.
