import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class WidgetTimerChibi extends StatefulWidget {
  final DocumentSnapshot userSnapshot;
  final double percentualeIdratazione;

  const WidgetTimerChibi({
    super.key,
    required this.userSnapshot,
    required this.percentualeIdratazione
  });

  @override
  State<WidgetTimerChibi> createState() => _WidgetTimerChibiState();
}

class _WidgetTimerChibiState extends State<WidgetTimerChibi> {
  Timer? _tickerLocale;

  @override
  void initState() {
    super.initState();
    _tickerLocale = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tickerLocale?.cancel();
    super.dispose();
  }

  int _convertiInMinuti(String orario) {
    try {
      List<String> parti = orario.split(":");
      return (int.parse(parti[0]) * 60) + int.parse(parti[1]);
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final oraAttuale = DateTime.now();
    final minutiAttuali = (oraAttuale.hour * 60) + oraAttuale.minute;

    // Configurazione di fallback iniziale
    String percorsoImmagine = "assets/images/personaggio/normale.png";
    String statoAnimo = "In attesa...";
    String tempoRimanente = "15:00";
    double progressoTimer = 1.0;
    Color boxColor = theme.colorScheme.primaryContainer.withOpacity(0.2);

    if (widget.userSnapshot.exists) {
      var datiUtente = widget.userSnapshot.data() as Map<String, dynamic>?;

      if (datiUtente != null) {
        String oraSvegliaString = datiUtente['ora_sveglia'] ?? "08:00";
        String oraSonnoString = datiUtente['ora_sonno'] ?? "23:00";

        int minutiSveglia = _convertiInMinuti(oraSvegliaString);
        int minutiSonno = _convertiInMinuti(oraSonnoString);

        bool staDormendo = false;
        if (minutiSveglia < minutiSonno) {
          staDormendo = minutiAttuali < minutiSveglia || minutiAttuali >= minutiSonno;
        } else {
          staDormendo = minutiAttuali >= minutiSonno && minutiAttuali < minutiSveglia;
        }

        if (staDormendo) {
          percorsoImmagine = "assets/images/personaggio/dorme.png";
          statoAnimo = "Shhh... Il tuo Chibi sta dormendo! 🌙";
          return _costruisciCardSonno(theme, percorsoImmagine, statoAnimo);
        }

        // 🟢 TRAGUARDO RAGGIUNTO DIURNO: Se ha bevuto tutto il target quotidiano, festeggia e blocca la sete!
        if (widget.percentualeIdratazione >= 1.0) {
          percorsoImmagine = "assets/images/personaggio/sorpreso.png";
          statoAnimo = "Grandioso! Obiettivo giornaliero centrato! ✨";
          boxColor = theme.colorScheme.tertiaryContainer.withOpacity(0.4);
          tempoRimanente = "Completato!";
          progressoTimer = 1.0;
          return _costruisciCardTimer(theme, boxColor, percorsoImmagine, statoAnimo, progressoTimer, tempoRimanente);
        }

        Timestamp? ultimoSorsoTs = datiUtente['ultimo_sorso'] as Timestamp?;

        if (ultimoSorsoTs != null) {
          DateTime ultimoSorso = ultimoSorsoTs.toDate();

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('utenti')
                .doc(widget.userSnapshot.id)
                .collection('sorsi')
                .orderBy('data', descending: true)
                .limit(1)
                .snapshots(),
            builder: (context, snapshotSorsi) {
              int quantitaUltimoSorso = 250;

              if (snapshotSorsi.hasData && snapshotSorsi.data!.docs.isNotEmpty) {
                var datiSorso = snapshotSorsi.data!.docs.first.data() as Map<String, dynamic>?;
                if (datiSorso != null) {
                  quantitaUltimoSorso = datiSorso['quantita'] as int? ?? 250;
                }
              }

              int minutiCalcolati = ((quantitaUltimoSorso / 250) * 15).round();
              if (minutiCalcolati < 1) minutiCalcolati = 1;

              int secondiTotaliMax = minutiCalcolati * 60;
              DateTime scadenza = ultimoSorso.add(Duration(minutes: minutiCalcolati));
              Duration diferencia = scadenza.difference(DateTime.now());

              if (diferencia.isNegative) {
                // 🔴 SCADUTO (Solo se l'obiettivo globale non è stato raggiunto)
                Duration ritardo = DateTime.now().difference(scadenza);
                int minutiRitardo = ritardo.inMinutes;

                tempoRimanente = "00:00 (Tempo Scaduto!)";
                progressoTimer = 0.0;
                boxColor = theme.colorScheme.errorContainer.withOpacity(0.4);

                if (minutiRitardo < 5) {
                  percorsoImmagine = "assets/images/personaggio/dis1.png";
                  statoAnimo = "Il tuo Chibi inizia ad avere sete...";
                } else if (minutiRitardo < 12) {
                  percorsoImmagine = "assets/images/personaggio/dis2.png";
                  statoAnimo = "La sete aumenta! Offrigli dell'acqua!";
                } else if (minutiRitardo < 20) {
                  percorsoImmagine = "assets/images/personaggio/dis3.png";
                  statoAnimo = "Il tuo Chibi sta soffrendo la sete! Bevi!";
                } else {
                  percorsoImmagine = "assets/images/personaggio/abbandonato.png";
                  statoAnimo = "Disidratazione critica! Il tuo Chibi si sente abbandonato!";
                  boxColor = theme.colorScheme.errorContainer.withOpacity(0.7);
                }

              } else {
                // 🟢 TEMPO IN CORSO
                String minuti = diferencia.inMinutes.toString().padLeft(2, '0');
                String secondi = (diferencia.inSeconds % 60).toString().padLeft(2, '0');
                tempoRimanente = "$minuti:$secondi";
                progressoTimer = diferencia.inSeconds / secondiTotaliMax.toDouble();

                if (widget.percentualeIdratazione >= 0.40) {
                  percorsoImmagine = "assets/images/personaggio/felice2.png";
                  statoAnimo = "Ottimo ritmo, il tuo Chibi è super idratato! 😊";
                } else if (widget.percentualeIdratazione >= 0.15) {
                  percorsoImmagine = "assets/images/personaggio/normale.png";
                  statoAnimo = "Tutto tranquillo, mantieni questo passo.";
                } else if (widget.percentualeIdratazione >= 0.05) {
                  percorsoImmagine = "assets/images/personaggio/triste.png";
                  statoAnimo = "Idratazione un po' bassa, bevi un po' d'acqua.";
                } else {
                  percorsoImmagine = "assets/images/personaggio/arrabbiato.png";
                  statoAnimo = "Idratazione giornaliera a secco! Muoviti!";
                  boxColor = theme.colorScheme.secondaryContainer.withOpacity(0.4);
                }
              }

              return _costruisciCardTimer(theme, boxColor, percorsoImmagine, statoAnimo, progressoTimer, tempoRimanente);
            },
          );
        }
      }
    }

    return _costruisciCardTimer(theme, boxColor, percorsoImmagine, statoAnimo, progressoTimer, tempoRimanente);
  }

  Widget _costruisciCardTimer(ThemeData theme, Color boxColor, String percorsoImmagine, String statoAnimo, double progressoTimer, String tempoRimanente) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: boxColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.primary.withOpacity(0.1)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              percorsoImmagine,
              width: 240,
              height: 240,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.smart_toy_rounded, size: 80);
              },
            ),
            const SizedBox(height: 14),
            Text(
              statoAnimo,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressoTimer,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: progressoTimer == 0.0 ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    tempoRimanente == "Completato!" ? "Target Raggiunto!" : "Prossimo sorso: $tempoRimanente",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _costruisciCardSonno(ThemeData theme, String percorsoImmagine, String statoAnimo) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.1)),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              percorsoImmagine,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text("😴", style: TextStyle(fontSize: 80));
              },
            ),
            const SizedBox(height: 16),
            Text(
              statoAnimo,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "I promemoria e il timer riprenderanno in base alla tua ora di sveglia.",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}