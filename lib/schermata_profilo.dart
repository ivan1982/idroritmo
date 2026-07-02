import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SchermataProfilo extends StatefulWidget {
  final User user;
  const SchermataProfilo({super.key, required this.user});

  @override
  State<SchermataProfilo> createState() => _SchermataProfiloState();
}

class _SchermataProfiloState extends State<SchermataProfilo> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _pesoController;
  late TextEditingController _dataNascitaController;
  // 🟢 Controller per le fasce orarie
  late TextEditingController _oraSvegliaController;
  late TextEditingController _oraSonnoController;

  DateTime? _dataNascitaSelezionata;
  String _attivitaFisica = "Moderato";
  String _stileVita = "Sedentario";
  bool _caricamento = true;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController();
    _pesoController = TextEditingController();
    _dataNascitaController = TextEditingController();
    _oraSvegliaController = TextEditingController();
    _oraSonnoController = TextEditingController();
    _caricaDatiUtente();
  }

  Future<void> _caricaDatiUtente() async {
    var doc = await FirebaseFirestore.instance.collection('utenti').doc(widget.user.uid).get();
    if (doc.exists) {
      var dati = doc.data()!;
      setState(() {
        _nomeController.text = dati['nome'] ?? "";
        _pesoController.text = (dati['peso'] ?? 70).toString();
        _attivitaFisica = dati['attivita_fisica'] ?? "Moderato";
        _stileVita = dati['stile_vita'] ?? "Sedentario";

        // 🟢 Lettura orari con fallback costanti se non presenti
        _oraSvegliaController.text = dati['ora_sveglia'] ?? "08:00";
        _oraSonnoController.text = dati['ora_sonno'] ?? "23:00";

        if (dati['data_nascita'] != null) {
          _dataNascitaSelezionata = DateTime.parse(dati['data_nascita']);
          _dataNascitaController.text =
          "${_dataNascitaSelezionata!.day}/${_dataNascitaSelezionata!.month}/${_dataNascitaSelezionata!.year}";
        }
        _caricamento = false;
      });
    }
  }

  int _calcolaEta() {
    if (_dataNascitaSelezionata == null) return 30;
    DateTime oggi = DateTime.now();
    int eta = oggi.year - _dataNascitaSelezionata!.year;
    if (oggi.month < _dataNascitaSelezionata!.month ||
        (oggi.month == _dataNascitaSelezionata!.month && oggi.day < _dataNascitaSelezionata!.day)) {
      eta--;
    }
    return eta;
  }

  int _ricalcolaObiettivo() {
    int peso = int.tryParse(_pesoController.text) ?? 70;
    int eta = _calcolaEta();

    int coefficienteBase = 30;
    if (eta < 30) coefficienteBase = 35;
    else if (eta > 55) coefficienteBase = 25;

    int base = peso * coefficienteBase;
    int bonusAllenamento = _attivitaFisica == "Moderato" ? 350 : (_attivitaFisica == "Attivo" ? 700 : 0);
    int bonusLavoro = _stileVita == "Dinamico" ? 300 : (_stileVita == "Pesante" ? 600 : 0);

    int totale = base + bonusAllenamento + bonusLavoro;
    return (totale / 50).round() * 50;
  }

  Future<void> _aggiornaProfilo() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Aggiornamento in corso..."),
          ],
        ),
      ),
    );

    int nuovoObiettivo = _ricalcolaObiettivo();

    await FirebaseFirestore.instance.collection('utenti').doc(widget.user.uid).update({
      'nome': _nomeController.text.trim(),
      'peso': int.tryParse(_pesoController.text) ?? 70,
      'eta': _calcolaEta(),
      'data_nascita': _dataNascitaSelezionata?.toIso8601String(),
      'attivita_fisica': _attivitaFisica,
      'stile_vita': _stileVita,
      'obiettivo_giornaliero': nuovoObiettivo,
      // 🟢 Salvataggio delle stringhe orarie su Firestore
      'ora_sveglia': _oraSvegliaController.text,
      'ora_sonno': _oraSonnoController.text,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      Navigator.of(context).pop();
    }
  }

  // Funzione helper per aprire il TimePicker grafico nativo
  Future<void> _selezionaOra(BuildContext context, TextEditingController controller) async {
    List<String> parti = controller.text.split(":");
    int oraIniziale = int.tryParse(parti[0]) ?? 8;
    int minutoIniziale = int.tryParse(parti[1]) ?? 0;

    TimeOfDay? t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: oraIniziale, minute: minutoIniziale),
    );

    if (t != null) {
      setState(() {
        String oraFormattata = t.hour.toString().padLeft(2, '0');
        String minutoFormattato = t.minute.toString().padLeft(2, '0');
        controller.text = "$oraFormattata:$minutoFormattato";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifica Profilo"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded),
            onPressed: _aggiornaProfilo,
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            TextFormField(
              controller: _nomeController,
              decoration: const InputDecoration(labelText: "Nome", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.isEmpty ? "Inserisci il nome" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pesoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Peso (kg)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.monitor_weight)),
              validator: (v) => v == null || int.tryParse(v) == null ? "Inserisci un peso valido" : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dataNascitaController,
              readOnly: true,
              decoration: const InputDecoration(labelText: "Data di Nascita", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_month)),
              onTap: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _dataNascitaSelezionata ?? DateTime(1995),
                  firstDate: DateTime(1930),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _dataNascitaSelezionata = picked;
                    _dataNascitaController.text = "${picked.day}/${picked.month}/${picked.year}";
                  });
                }
              },
            ),

            // 🟢 SEZIONE DELLE FASCE ORARIE DI COMFORT
            const SizedBox(height: 24),
            Text("Fascia Oraria di Attività", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _oraSvegliaController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Ora Sveglia", border: OutlineInputBorder(), prefixIcon: Icon(Icons.wb_sunny_rounded)),
                    onTap: () => _selezionaOra(context, _oraSvegliaController),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _oraSonnoController,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: "Ora Sonno", border: OutlineInputBorder(), prefixIcon: Icon(Icons.nights_stay_rounded)),
                    onTap: () => _selezionaOra(context, _oraSonnoController),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text("Attività Fisica", style: theme.textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _attivitaFisica,
              items: ["Sedentario", "Moderato", "Attivo"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _attivitaFisica = v!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            Text("Stile di Vita", style: theme.textTheme.titleMedium),
            DropdownButtonFormField<String>(
              value: _stileVita,
              items: ["Sedentario", "Dinamico", "Pesante"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _stileVita = v!),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              icon: const Icon(Icons.save_rounded),
              label: const Text("Salva Modifiche"),
              onPressed: _aggiornaProfilo,
            )
          ],
        ),
      ),
    );
  }
}