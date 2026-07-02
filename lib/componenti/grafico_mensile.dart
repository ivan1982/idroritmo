import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GraficoMensile extends StatelessWidget {
  final String userUid;
  final int obiettivoGiornaliero;

  const GraficoMensile({super.key, required this.userUid, required this.obiettivoGiornaliero});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ora = DateTime.now();
    final trentaGiorniFa = ora.subtract(const Duration(days: 30));

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Andamento Ultimi 30 Giorni",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Visualizza la costanza della tua idratazione",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 180,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('utenti')
                    .doc(userUid)
                    .collection('sorsi')
                // 🔴 CORRETTO: Cambiato da 'timestamp' a 'data' per allinearsi al DB
                    .where('data', isGreaterThanOrEqualTo: trentaGiorniFa)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  Map<String, int> datiRaggruppati = {};

                  for (int i = 6; i >= 0; i--) {
                    final d = ora.subtract(Duration(days: i));
                    datiRaggruppati["${d.day}/${d.month}"] = 0;
                  }

                  if (snapshot.hasData) {
                    for (var doc in snapshot.data!.docs) {
                      var datiSorso = doc.data() as Map<String, dynamic>;
                      // 🔴 CORRETTO: Cambiato da 'timestamp' a 'data'
                      Timestamp? ts = datiSorso['data'] as Timestamp?;
                      int quantita = datiSorso['quantita'] as int? ?? 0;

                      if (ts != null) {
                        DateTime dataSorso = ts.toDate();
                        String chiave = "${dataSorso.day}/${dataSorso.month}";
                        if (datiRaggruppati.containsKey(chiave)) {
                          datiRaggruppati[chiave] = datiRaggruppati[chiave]! + quantita;
                        } else {
                          datiRaggruppati[chiave] = quantita;
                        }
                      }
                    }
                  }

                  List<String> giorniChiave = datiRaggruppati.keys.toList();
                  if (giorniChiave.length > 7) {
                    giorniChiave = giorniChiave.sublist(giorniChiave.length - 7);
                  }

                  List<BarChartGroupData> gruppiBarre = [];
                  for (int i = 0; i < giorniChiave.length; i++) {
                    String giorno = giorniChiave[i];
                    double totaleBevuto = (datiRaggruppati[giorno] ?? 0).toDouble();

                    gruppiBarre.add(
                      BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: totaleBevuto,
                            color: totaleBevuto >= obiettivoGiornaliero
                                ? Colors.blueAccent
                                : theme.colorScheme.primary.withOpacity(0.6),
                            width: 14,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      ),
                    );
                  }

                  return BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: obiettivoGiornaliero * 1.2,
                      barTouchData: BarTouchData(
                        touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            return BarTooltipItem(
                              "${rod.toY.toInt()} ml",
                              TextStyle(color: theme.colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < giorniChiave.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    giorniChiave[index],
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: gruppiBarre,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}