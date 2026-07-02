import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'schermata_questionario.dart';
import 'schermata_profilo.dart';
import 'componenti/grafico_mensile.dart';
import 'notification_service.dart';
import 'componenti/widget_timer_chibi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print("🚀 Firebase inizializzato con successo!");

    final notificationService = NotificationService();
    await notificationService.inizializzaNotifiche();

  } catch (e) {
    print("💥 Errore critico durante l'inizializzazione: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme = lightDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        );
        ColorScheme darkColorScheme = darkDynamic ?? ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        );

        final AuthService authService = AuthService();

        return MaterialApp(
          title: 'IdroRitmo',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          home: StreamBuilder<User?>(
            stream: authService.userStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasData) {
                final User user = snapshot.data!;

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('utenti').doc(user.uid).get(),
                  builder: (context, docSnapshot) {
                    if (docSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (docSnapshot.hasData && docSnapshot.data!.exists) {
                      var dati = docSnapshot.data!.data() as Map<String, dynamic>?;
                      if (dati != null && dati['profilo_completato'] == true) {
                        return SchermataHome(authService: authService, user: user);
                      }
                    }

                    return SchermataQuestionario(
                      user: user,
                      onCompleto: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => SchermataHome(authService: authService, user: user),
                          ),
                        );
                      },
                    );
                  },
                );
              }

              return SchermataLogin(authService: authService);
            },
          ),
        );
      },
    );
  }
}

class SchermataLogin extends StatelessWidget {
  final AuthService authService;
  const SchermataLogin({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    size: 80,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'IdroRitmo',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Prenditi cura della tua idratazione e fai crescere il tuo compagno di avventures.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 48),
                FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Accedi con Google'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () async {
                    var user = await authService.signInConGoogle();
                    if (user != null) {
                      print("✅ Login Google Riuscito!");
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SchermataHome extends StatefulWidget {
  final AuthService authService;
  final User user;
  const SchermataHome({super.key, required this.authService, required this.user});

  @override
  State<SchermataHome> createState() => _SchermataHomeState();
}

class _SchermataHomeState extends State<SchermataHome> {
  bool _menuEspandibileAperto = false;

  Future<void> _gestisciRegistrazioneSorso(int quantita, ThemeData theme) async {
    print("💧 Aggiunta sorso da ${quantita}ml...");
    String? sorsoId = await widget.authService.aggiungiSorso(quantita);

    // 🟢 Interrompe lo Spike Chain e calcola il nuovo timer diurno regolare
    final notificationService = NotificationService();
    await notificationService.pianificaProssimoPromemoria(quantita: quantita);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sorso da $quantita ml registrato! 💧'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'ANNULLA',
            textColor: theme.colorScheme.inversePrimary,
            onPressed: () async {
              if (sorsoId != null) {
                await FirebaseFirestore.instance
                    .collection('utenti')
                    .doc(widget.user.uid)
                    .collection('sorsi')
                    .doc(sorsoId)
                    .delete();

                await notificationService.annullaTutteLeNotifiche();
                print("✅ Sorso eliminato e catena notifiche resettata.");
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('utenti').doc(widget.user.uid).snapshots(),
      builder: (context, userSnapshot) {
        int objetivo = 2000;
        String nomeUtente = "Esploratore";

        if (userSnapshot.hasData && userSnapshot.data!.exists) {
          var datiUtente = userSnapshot.data!.data() as Map<String, dynamic>?;
          if (datiUtente != null) {
            objetivo = datiUtente['obiettivo_giornaliero'] ?? 2000;
            nomeUtente = datiUtente['nome'] ?? widget.user.displayName ?? "Esploratore";
            if (nomeUtente.trim().isEmpty) nomeUtente = "Esploratore";
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('IdroRitmo', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.manage_accounts_rounded),
                tooltip: 'Modifica Profilo',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SchermataProfilo(user: widget.user),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Scollegati',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        icon: const Icon(Icons.logout_rounded),
                        title: const Text('Vuoi uscire?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                          FilledButton.tonal(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await widget.authService.logout();
                            },
                            child: const Text('Esci'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_menuEspandibileAperto) ...[
                FloatingActionButton.extended(
                  heroTag: 'btn_125',
                  icon: const Icon(Icons.local_cafe_rounded, size: 18),
                  label: const Text('Sorso leggero (125 ml)'),
                  onPressed: () {
                    setState(() => _menuEspandibileAperto = false);
                    _gestisciRegistrazioneSorso(125, theme);
                  },
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'btn_250',
                  icon: const Icon(Icons.local_drink_rounded, size: 20),
                  label: const Text('Bicchiere (250 ml)'),
                  onPressed: () {
                    setState(() => _menuEspandibileAperto = false);
                    _gestisciRegistrazioneSorso(250, theme);
                  },
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'btn_500',
                  icon: const Icon(Icons.water_drop_rounded, size: 22),
                  label: const Text('Bottiglia (500 ml)'),
                  onPressed: () {
                    setState(() => _menuEspandibileAperto = false);
                    _gestisciRegistrazioneSorso(500, theme);
                  },
                ),
                const SizedBox(height: 14),
              ],
              FloatingActionButton.extended(
                heroTag: 'btn_main',
                backgroundColor: _menuEspandibileAperto ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer,
                icon: Icon(_menuEspandibileAperto ? Icons.close_rounded : Icons.add_rounded),
                label: Text(_menuEspandibileAperto ? 'Chiudi' : 'Bevi Acqua 💧'),
                onPressed: () {
                  setState(() => _menuEspandibileAperto = !_menuEspandibileAperto);
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: theme.colorScheme.primary,
                          child: ClipOval(
                            child: widget.user.photoURL != null && widget.user.photoURL!.isNotEmpty
                                ? Image.network(
                              widget.user.photoURL!,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(child: Text(nomeUtente.isNotEmpty ? nomeUtente[0].toUpperCase() : 'U'));
                              },
                            )
                                : Center(child: Text(nomeUtente.isNotEmpty ? nomeUtente[0].toUpperCase() : 'U')),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ciao, $nomeUtente!',
                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                widget.user.email ?? '',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Il tuo Compagno',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                StreamBuilder<QuerySnapshot>(
                  stream: () {
                    final oraLocale = DateTime.now();
                    final inizioOggi = DateTime(oraLocale.year, oraLocale.month, oraLocale.day);

                    return FirebaseFirestore.instance
                        .collection('utenti')
                        .doc(widget.user.uid)
                        .collection('sorsi')
                        .where('data', isGreaterThanOrEqualTo: inizioOggi)
                        .snapshots();
                  }(),
                  builder: (context, sorsiSnapshot) {
                    int totaleBevuto = 0;

                    if (sorsiSnapshot.hasData) {
                      for (var doc in sorsiSnapshot.data!.docs) {
                        totaleBevuto += (doc.data() as Map<String, dynamic>)['quantita'] as int? ?? 0;
                      }
                    }

                    double percentuale = totaleBevuto / objetivo;
                    if (percentuale > 1.0) percentuale = 1.0;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (userSnapshot.hasData)
                          WidgetTimerChibi(
                            userSnapshot: userSnapshot.data!,
                            percentualeIdratazione: percentuale,
                          )
                        else
                          const Center(child: CircularProgressIndicator()),

                        const SizedBox(height: 24),

                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHigh,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                              ),
                              title: const Text('Idratazione Odierna', style: TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Progresso: $totaleBevuto / $objetivo ml'),
                              trailing: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  value: percentuale,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  strokeWidth: 4.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                GraficoMensile(
                  userUid: widget.user.uid,
                  obiettivoGiornaliero: objetivo,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }
}