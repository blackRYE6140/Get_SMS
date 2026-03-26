# GET_SMS (`get_smm`)

Application Flutter Android qui capture des SMS entrants, les sauvegarde en
SQLite local, puis affiche les messages qui correspondent a un filtre.

## Objectif

- Capturer automatiquement les SMS entrants.
- Sauvegarder en base locale avec anti-doublon.
- Afficher automatiquement les messages filtres dans l'app.
- Tenter de conserver les SMS captures meme si l'app est fermee.

## Filtre actif

Le filtre est defini dans `lib/sms_service.dart`:

- `targetSender = 'salama'`
- `targetKeyword = 'salama'`

Un message est conserve dans la liste affichee si:

- `address` contient `targetSender`, OU
- `body` contient `targetKeyword`.

## Fonctionnalites implementees

- Permission SMS runtime (`permission_handler`).
- Lecture initiale de la boite de reception SMS (`another_telephony`).
- Ecoute SMS en app ouverte (foreground).
- Receiver Android natif pour reception en arriere-plan.
- File de secours native (`SharedPreferences`) en cas d'echec d'ecriture DB.
- Flush automatique de la file native au prochain lancement Flutter.
- Stockage SQLite avec index et index unique anti-doublon.
- Rafraichissement automatique de l'ecran (timer + resume app).

## Architecture

### Flutter

- `lib/main.dart`
  - Initialisation globale de l'ecran.
  - Flush de la file native via `MethodChannel`.
  - Synchronisation initiale des SMS existants.
  - Listener foreground + auto-refresh UI.
  - Filtrage final applique sur les messages lus en DB.

- `lib/sms_service.dart`
  - Permission SMS.
  - Lecture inbox.
  - Ecoute foreground des nouveaux SMS.
  - Regle de filtrage (`isMatchingMessage`).

- `lib/database_helper.dart`
  - Gestion SQLite `messages.db`.
  - Migration schema v2.
  - Anti-doublon par index unique `(address, body, date)`.

### Android natif (Kotlin)

- `android/app/src/main/kotlin/com/example/get_smm/IncomingSmsReceiver.kt`
  - Recoit `SMS_RECEIVED`.
  - Enqueue d'abord le SMS dans la file de secours.
  - Tente ensuite l'ecriture immediate dans `messages.db`.
  - Si succes, retire le message de la file.

- `android/app/src/main/kotlin/com/example/get_smm/PendingSmsStore.kt`
  - Stocke les SMS en attente dans `SharedPreferences`.
  - Fournit `flushToDatabase()`.

- `android/app/src/main/kotlin/com/example/get_smm/SmsDatabaseHelper.kt`
  - Ecriture SQLite native dans la meme base `messages.db`.

- `android/app/src/main/kotlin/com/example/get_smm/MainActivity.kt`
  - Expose `MethodChannel get_smm/background_sms`.
  - Methode `flushPendingSms` appelee depuis Flutter.

### Manifest Android

Fichier: `android/app/src/main/AndroidManifest.xml`

- Permissions:
  - `android.permission.READ_SMS`
  - `android.permission.RECEIVE_SMS`
- Receiver:
  - `.IncomingSmsReceiver`
  - action `android.provider.Telephony.SMS_RECEIVED`

## Base de donnees

DB: `messages.db`

Table `messages`:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `address TEXT NOT NULL`
- `body TEXT NOT NULL`
- `date TEXT NOT NULL`
- `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`

Indexes:

- `idx_address` sur `address`
- `idx_date` sur `date`
- `idx_unique_message` unique sur `(address, body, date)`

## Flux de fonctionnement

### 1) Lancement de l'app

- Flutter appelle `flushPendingSms` (MethodChannel).
- Les SMS en file native sont reinjectes dans SQLite.
- L'app charge la DB, demande permission SMS, sync inbox,
  puis demarre l'ecoute foreground.

### 2) SMS recu en app ouverte

- `another_telephony` declenche `onNewMessage`.
- Message sauvegarde en DB.
- UI rafraichie automatiquement.

### 3) SMS recu en app fermee

- `IncomingSmsReceiver` est notifie.
- Message queue + tentative d'ecriture DB immediate.
- Au prochain lancement, toute file restante est flush en DB.
- L'ecran affiche ensuite les messages qui passent le filtre.

## Prerequis

- Flutter SDK installe.
- Android SDK / device Android reel.
- Permission SMS accordee a l'app.

## Installation et execution

```bash
flutter pub get
flutter run
```

## Verification technique

```bash
flutter analyze
cd android
./gradlew :app:compileDebugKotlin
```

## Validation fonctionnelle conseillee

### Test A: foreground

1. Ouvrir l'app.
2. Envoyer un SMS qui matche le filtre.
3. Verifier apparition auto sans redemarrage.

### Test B: background

1. Ouvrir l'app une fois (permission SMS accordee).
2. Fermer l'app normalement (pas Force stop).
3. Envoyer un SMS qui matche.
4. Supprimer le SMS rapidement depuis l'app Messages.
5. Rouvrir l'app et verifier la presence du message.

## Limitations Android importantes

- Si l'utilisateur fait `Force stop`, Android bloque les receivers tant que
  l'app n'est pas relancee manuellement.
- Certains constructeurs (MIUI/ColorOS/EMUI, etc.) limitent fortement
  l'execution en arriere-plan.
- Il faut desactiver les optimisations batterie pour ameliorer la fiabilite.

## Debug rapide (si background ne marche pas)

### 1) Verifier receiver dans le manifeste merge

```bash
rg "IncomingSmsReceiver" build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml
```

### 2) Logs runtime Android

```bash
adb logcat -c
adb logcat | grep -E "IncomingSmsReceiver|Background SMS capture failed|flushPendingSms"
```

### 3) Rebuild propre

```bash
flutter clean
flutter pub get
flutter run
```

## Dependances principales

- `another_telephony`
- `permission_handler`
- `sqflite`
- `path`

## Note

Ce README decrit l'etat actuel du code dans cette branche locale.
