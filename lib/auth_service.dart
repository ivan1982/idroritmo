import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get userStream => _auth.authStateChanges();

  Future<User?> signInAnonimo() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      User? user = result.user;

      if (user != null) {
        await _inizializzaNuovoUtente(user.uid);
      }
      return user;
    } catch (e) {
      print("Errore durante l'accesso anonimo: $e");
      return null;
    }
  }

  Future<User?> signInConGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      if (user != null) {
        await _inizializzaNuovoUtente(user.uid);
        await user.reload();
        user = _auth.currentUser;
      }

      return user;
    } catch (e) {
      print("Errore durante il login con Google: $e");
      return null;
    }
  }

  Future<void> _inizializzaNuovoUtente(String uid) async {
    DocumentReference userDoc = _db.collection('utenti').doc(uid);
    DocumentSnapshot doc = await userDoc.get();

    if (!doc.exists) {
      await userDoc.set({
        'obiettivo_giornaliero': 2000,
        'ore_veglia': 16,
        'ora_sveglia': "08:00",
        'ora_sonno': "23:00",
        'creato_il': FieldValue.serverTimestamp(),
        // 🟢 FIX: Inizializziamo subito l'ultimo sorso al momento della creazione
        // così il timer della Home parte immediatamente senza bloccarsi!
        'ultimo_sorso': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<String?> aggiungiSorso(int quantita) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final docRef = FirebaseFirestore.instance.collection('utenti').doc(user.uid);

    final oraLocale = DateTime.now();
    final dataFormattata = "${oraLocale.year}-${oraLocale.month.toString().padLeft(2, '0')}-${oraLocale.day.toString().padLeft(2, '0')}";

    final nuovoSorso = await docRef.collection('sorsi').add({
      'quantita': quantita,
      'data': oraLocale,
      'data_formattata': dataFormattata,
    });

    await docRef.update({
      'ultimo_sorso': FieldValue.serverTimestamp(),
    });

    return nuovoSorso.id;
  }

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}