import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SchermataQuestionario extends StatefulWidget {
  final User user;
  final VoidCallback onCompleto;

  const SchermataQuestionario({super.key, required this.user, required this.onCompleto});

  @override
  State<SchermataQuestionario> createState() => _SchermataQuestionarioState();
}

class _SchermataQuestionarioState extends State<SchermataQuestionario> {
  final PageController _pageController = PageController();
  int _paginaCorrente = 0;

  int _calcolaEta() {
    if (_dataNascitaSelezionata == null) return 30; // Fallback di base se non selezionata
    DateTime oggi = DateTime.now();
    int eta = oggi.year - _dataNascitaSelezionata!.year;
    if (oggi.month < _dataNascitaSelezionata!.month ||
        (oggi.month == _dataNascitaSelezionata!.month && oggi.day < _dataNascitaSelezionata!.day)) {
      eta--;
    }
    return eta;
  }

  // Controller per i campi di testo
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController(text: "70");
  final TextEditingController _dataNascitaController = TextEditingController();
  DateTime? _dataNascitaSelezionata;
  final TextEditingController _obiettivoController = TextEditingController();

  String _attivitaFisica = "Moderato";
  String _stileVita = "Sedentario";

  @override
  void sendInizializzaDati() {
    super.initState();

    // LOGICA DI ESTRAZIONE AUTOMATICA DEL NOME
    if (widget.user.displayName != null && widget.user.displayName!.trim().isNotEmpty) {
      _nomeController.text = widget.user.displayName!;
    } else if (widget.user.email != null && widget.user.email!.contains('@')) {
      // Estrae la parte prima della @
      String locale = widget.user.email!.split('@')[0];
      // Capitalizza la prima lettera (es: ivan.composto -> Ivan.composto)
      _nomeController.text = locale.substring(0, 1).toUpperCase() + locale.substring(1);
    } else {
      _nomeController.text = "Esploratore";
    }
  }

  @override
  void initState() {
    sendInizializzaDati();
  }

  int _calcolaObiettivo() {
  int peso = int.tryParse(_pesoController.text) ?? 70;
  int eta = _calcolaEta(); // <--- Usa la nuova funzione

    int coefficienteBase = 30;
    if (eta < 30) {
      coefficienteBase = 35;
    } else if (eta > 55) {
      coefficienteBase = 25;
    }

    int base = peso * coefficienteBase;

    int bonusAllenamento = 0;
    if (_attivitaFisica == "Moderato") bonusAllenamento = 350;
    if (_attivitaFisica == "Attivo") bonusAllenamento = 700;

    int bonusLavoro = 0;
    if (_stileVita == "Dinamico") bonusLavoro = 300;
    if (_stileVita == "Pesante") bonusLavoro = 600;

    return base + bonusAllenamento + bonusLavoro;
  }

  Future<void> _salvaDati() async {
    int obiettivoFinale = int.tryParse(_obiettivoController.text) ?? _calcolaObiettivo();
    String nomeFinale = _nomeController.text.trim();

    await FirebaseFirestore.instance.collection('utenti').doc(widget.user.uid).set({
      'nome': nomeFinale.isNotEmpty ? nomeFinale : "Esploratore",
      'peso': int.tryParse(_pesoController.text) ?? 70,
      'eta': _calcolaEta(), // <--- Salva l'età calcolata dal compleanno
      'data_nascita': _dataNascitaSelezionata?.toIso8601String(), // <--- Nuovo campo su Firestore
      'attivita_fisica': _attivitaFisica,
      'stile_vita': _stileVita,
      'obiettivo_giornaliero': BostonCalcolo(obiettivoFinale),
      'ore_veglia': 16,
      'creato_il': FieldValue.serverTimestamp(),
      'profilo_completato': true,
    }, SetOptions(merge: true));

    widget.onCompleto();
  }

  int BostonCalcolo(int valore) {
    return (valore / 50).round() * 50;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Configurazione Profilo"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: (_paginaCorrente + 1) / 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) {
                  setState(() {
                    _paginaCorrente = page;
                    if (page == 3) {
                      _obiettivoController.text = _calcolaObiettivo().toString();
                    }
                  });
                },
                children: [
                  _costruisciPaginaDatiPersonali(theme),
                  _costruisciPaginaAllenamento(theme),
                  _costruisciPaginaStileVita(theme),
                  _costruisciPaginaRiepilogo(theme),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_paginaCorrente > 0)
                    OutlinedButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text("Indietro"),
                    )
                  else
                    const SizedBox.shrink(),
                  FilledButton(
                    onPressed: () async {
                      if (_paginaCorrente < 3) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        await _salvaDati();
                      }
                    },
                    child: Text(_paginaCorrente == 3 ? "Conferma e Inizia" : "Avanti"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costruisciPaginaDatiPersonali(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Raccontaci qualcosa di te", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Controlla o modifica il tuo nome e inserisci i tuoi parametri.", style: theme.textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: _nomeController,
            keyboardType: TextInputType.name,
            decoration: const InputDecoration(
              labelText: "Nome o Nickname",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pesoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Peso corporeo (kg)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monitor_weight_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dataNascitaController,
            readOnly: true, // Impedisce la digitazione manuale della tastiera
            decoration: const InputDecoration(
              labelText: "Data di nascita",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month_rounded),
            ),
            onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(1995),
                firstDate: DateTime(1930),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                setState(() {
                  _dataNascitaSelezionata = pickedDate;
                  // Mostra la data nel formato leggibile giorno/mese/anno
                  _dataNascitaController.text = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _costruisciPaginaAllenamento(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Quanto ti alleni?", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _costruisciOpzioneSelettore(
            titolo: "Sedentario",
            sottotitolo: "Nessun allenamento specifico o attività leggera",
            valore: "Sedentario",
            gruppo: _attivitaFisica,
            onChanged: (val) => setState(() => _attivitaFisica = val!),
          ),
          _costruisciOpzioneSelettore(
            titolo: "Moderato",
            sottotitolo: "Movimento o sport 1-3 volte a settimana",
            valore: "Moderato",
            gruppo: _attivitaFisica,
            onChanged: (val) => setState(() => _attivitaFisica = val!),
          ),
          _costruisciOpzioneSelettore(
            titolo: "Attivo / Intenso",
            sottotitolo: "Allenamento costante e pesante (es. Pesi / Palestra)",
            valore: "Attivo",
            gruppo: _attivitaFisica,
            onChanged: (val) => setState(() => _attivitaFisica = val!),
          ),
        ],
      ),
    );
  }

  Widget _costruisciPaginaStileVita(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Che tipo di lavoro o routine hai?", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _costruisciOpzioneSelettore(
            titolo: "Sedentario",
            sottotitolo: "Lavoro alla scrivania o al computer, ti muovi poco",
            valore: "Sedentario",
            gruppo: _stileVita,
            onChanged: (val) => setState(() => _stileVita = val!),
          ),
          _costruisciOpzioneSelettore(
            titolo: "Dinamico",
            sottotitolo: "In piedi, cammini molto (es. Insegnante, commesso)",
            valore: "Dinamico",
            gruppo: _stileVita,
            onChanged: (val) => setState(() => _stileVita = val!),
          ),
          _costruisciOpzioneSelettore(
            titolo: "Pesante",
            sottotitolo: "Lavoro manuale ad alto dispendio o sudorazione",
            valore: "Pesante",
            gruppo: _stileVita,
            onChanged: (val) => setState(() => _stileVita = val!),
          ),
        ],
      ),
    );
  }

  Widget _costruisciPaginaRiepilogo(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_rounded, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 24),
          Text("Il tuo obiettivo idrico personalizzato",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            "Puoi confermare il calcolo suggerito dall'algoritmo o modificarlo liberamente in base alle tue preferenze.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _obiettivoController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              decoration: const InputDecoration(
                suffixText: "ml",
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _costruisciOpzioneSelettore({
    required String titolo,
    required String sottotitolo,
    required String valore,
    required String gruppo,
    required ValueChanged<String?> onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: gruppo == valore ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant),
      ),
      child: RadioListTile<String>(
        title: Text(titolo, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sottotitolo),
        value: valore,
        groupValue: gruppo,
        onChanged: onChanged,
      ),
    );
  }
}