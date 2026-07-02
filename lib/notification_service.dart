import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:async';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    print("⏰ [IDRO_DEBUG] Workmanager avviato in background per il task: $taskName");

    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {}

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Future.value(true);

    final oraLocale = DateTime.now();
    final minutiAttuali = (oraLocale.hour * 60) + oraLocale.minute;

    final docUtente = await FirebaseFirestore.instance.collection('utenti').doc(user.uid).get();
    if (docUtente.exists) {
      var dati = docUtente.data();
      if (dati != null) {
        String oraSvegliaString = dati['ora_sveglia'] ?? "08:00";
        String oraSonnoString = dati['ora_sonno'] ?? "23:00";

        List<String> pSveglia = oraSvegliaString.split(":");
        List<String> pSonno = oraSonnoString.split(":");
        int minutiSveglia = (int.parse(pSveglia[0]) * 60) + int.parse(pSveglia[1]);
        int minutiSonno = (int.parse(pSonno[0]) * 60) + int.parse(pSonno[1]);

        bool staDormendo = false;
        if (minutiSveglia < minutiSonno) {
          staDormendo = minutiAttuali < minutiSveglia || minutiAttuali >= minutiSonno;
        } else {
          staDormendo = minutiAttuali >= minutiSonno && minutiAttuali < minutiSveglia;
        }

        if (staDormendo) {
          print("⏰ [IDRO_DEBUG] L'utente dorme. Interrompo le notifiche.");
          return Future.value(true);
        }

        // 1. 🟢 CONTROLLO TARGET GIORNALIERO IN BACKGROUND
        final oraInizioOggi = DateTime(oraLocale.year, oraLocale.month, oraLocale.day);
        final sorsiOggi = await FirebaseFirestore.instance
            .collection('utenti')
            .doc(user.uid)
            .collection('sorsi')
            .where('data', isGreaterThanOrEqualTo: oraInizioOggi)
            .get();

        int totaleBevutoOggi = 0;
        for (var doc in sorsiOggi.docs) {
          totaleBevutoOggi += (doc.data())['quantita'] as int? ?? 0;
        }

        int obiettivoGiornaliero = dati['obiettivo_giornaliero'] ?? 2000;

        if (totaleBevutoOggi >= obiettivoGiornaliero) {
          print("⏰ [IDRO_DEBUG] Obiettivo giornaliero completato ($totaleBevutoOggi ml). Interrompo Spike Chain e notifiche.");
          return Future.value(true); // Esce senza ri-pianificare solleciti o mostrare notifiche
        }
      }
    }

    // 2. Inizializzazione Plugin Notifiche
    final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@android:drawable/sym_def_app_icon');
    await notificationsPlugin.initialize(const InitializationSettings(android: initializationSettingsAndroid));

    // 3. Configurazione del Canale ad alta priorità
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'idro_ritmo_workmanager_channel_v3',
      'Promemoria Rigido Idratazione',
      channelDescription: 'Canale ad alta precisione gestito da Workmanager',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@android:drawable/sym_def_app_icon',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'azione_bevi',
          'Ho bevuto (250ml) 💧',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final int idNotifica = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    String titolo = 'Il tuo Chibi ha sete! 💧';
    String descrizione = 'È ora di idratarsi. Registra un sorso per ricaricare il timer!';

    if (taskName == "promemoria_sollecito_task") {
      titolo = '⚠️ Il tuo Chibi sta soffrendo!';
      descrizione = 'La disidratazione aumenta. Offrigli dell\'acqua adesso!';
    }

    try {
      await notificationsPlugin.show(idNotifica, titolo, descrizione, platformDetails);
      print("⏰ [IDRO_DEBUG] Notifica inviata visivamente.");
    } catch (e) {
      print("❌ Errore nello show della notifica: $e");
    }

    // 4. Ripianificazione dello Spike Chain (solo se il target non è completo)
    print("⏰ [IDRO_DEBUG] Pianifico prossimo sollecito sussidiario tra 5 minutes.");
    await Workmanager().registerOneOffTask(
      "idro_ritmo_sollecito_task",
      "promemoria_sollecito_task",
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    return Future.value(true);
  });
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  print("⏰ [IDRO_DEBUG] Background Click! ActionId: ${notificationResponse.actionId}");

  if (notificationResponse.actionId == 'azione_bevi') {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final user = FirebaseAuth.instance.currentUser;
    final oraLocale = DateTime.now();

    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('utenti').doc(user.uid);
      String dataFormattata = "${oraLocale.year}-${oraLocale.month.toString().padLeft(2, '0')}-${oraLocale.day.toString().padLeft(2, '0')}";

      await docRef.collection('sorsi').add({
        'quantita': 250,
        'data': DateTime.now(),
        'data_formattata': dataFormattata,
      });

      await docRef.update({
        'ultimo_sorso': FieldValue.serverTimestamp(),
      });

      final ns = NotificationService();
      await ns.pianificaProssimoPromemoria(quantita: 250);
    }
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> inizializzaNotifiche() async {
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {}

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@android:drawable/sym_def_app_icon');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  }

  Future<void> pianificaProssimoPromemoria({required int quantita}) async {
    await Workmanager().cancelAll();

    int minutiCalcolati = ((quantita / 250) * 15).round();
    if (minutiCalcolati < 1) minutiCalcolati = 1;

    print("⏰ [IDRO_DEBUG] Resettati solleciti. Nuovo timer principale impostato a $minutiCalcolati minuti.");

    await Workmanager().registerOneOffTask(
      "idro_ritmo_timer_task",
      "promemoria_idratazione_task",
      initialDelay: Duration(minutes: minutiCalcolati),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  Future<void> annullaTutteLeNotifiche() async {
    await Workmanager().cancelAll();
    await _notificationsPlugin.cancelAll();
  }
}