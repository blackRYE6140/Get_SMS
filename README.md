# GET_SMS (`get_smm`)

Application Flutter Android qui capture des SMS entrants, sauvegarde en SQLite local,
et affiche automatiquement les messages qui correspondent a un filtre.

Ce README donne une configuration complete, etape par etape.

## 1) Objectif

- Garder les SMS cibles meme si le SMS est supprime rapidement dans l'app Messages.
- Supporter 2 cas:
  - app ouverte,
  - app en arriere-plan ou retiree des recents.

## 2) Prerequis

- Flutter SDK installe (`flutter --version`)
- Android SDK + ADB
- Un telephone Android reel (important pour les tests SMS)
- Carte SIM active pour envoyer/recevoir des SMS

Verification rapide:

```bash
flutter doctor -v
adb devices
```

## 3) Installation projet

1. Ouvrir le dossier du projet.
2. Installer les dependances.
3. Lancer l'app en debug.

```bash
flutter pub get
flutter run
```

## 4) Configuration du filtre SMS

Fichier: `lib/sms_service.dart`

Modifier ces constantes:

```dart
static const String targetSender = 'salama';
static const String targetKeyword = 'salama';
```

Regle de filtre:

- le SMS est conserve si `address` contient `targetSender`, OU
- le SMS est conserve si `body` contient `targetKeyword`.

## 5) Configuration Android (deja incluse dans ce repo)

### 5.1 Permissions manifeste

Fichier: `android/app/src/main/AndroidManifest.xml`

Permissions declarees:

- `android.permission.READ_SMS`
- `android.permission.RECEIVE_SMS`
- `android.permission.RECEIVE_BOOT_COMPLETED`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_DATA_SYNC`

### 5.2 Composants Android declares

Toujours dans `android/app/src/main/AndroidManifest.xml`:

- Receiver SMS: `.IncomingSmsReceiver`
- Receiver boot/update: `.BootReceiver`
- Receiver relance service: `.KeepAliveRestartReceiver`
- Service keep-alive: `.SmsKeepAliveService`

## 6) Premiere execution (obligatoire)

1. Ouvrir l'app une premiere fois.
2. Accepter la permission SMS quand Android la demande.
3. Verifier que le statut de l'app passe en ecoute active.
4. Verifier qu'une notification persistante du service keep-alive est visible.

Sans cette premiere ouverture, la capture en arriere-plan ne sera pas fiable.

## 7) Configuration telephone pour fiabilite background

Selon la marque (Xiaomi, Oppo, Huawei, etc.), activer aussi:

1. Autoriser l'app a demarrer automatiquement (auto start).
2. Exclure l'app de l'optimisation batterie.
3. Autoriser activite en arriere-plan.
4. Ne pas faire "Force stop" sauf pour test limite.

## 8) Architecture fonctionnelle

### Flutter

- `lib/main.dart`
  - demarre le keep-alive natif,
  - flush la file native,
  - synchronise inbox,
  - ecoute foreground,
  - rafraichit UI automatiquement.

- `lib/sms_service.dart`
  - permission SMS,
  - lecture inbox,
  - listener foreground,
  - filtrage metier.

- `lib/database_helper.dart`
  - DB `messages.db`,
  - table `messages`,
  - index unique anti-doublon `(address, body, date)`.

### Android natif

- `android/app/src/main/kotlin/com/example/get_smm/IncomingSmsReceiver.kt`
  - recoit `SMS_RECEIVED`,
  - met en queue de secours,
  - tente sauvegarde SQLite immediate.

- `android/app/src/main/kotlin/com/example/get_smm/PendingSmsStore.kt`
  - queue `SharedPreferences` en cas d'echec temporaire.

- `android/app/src/main/kotlin/com/example/get_smm/SmsDatabaseHelper.kt`
  - ecriture native dans `messages.db`.

- `android/app/src/main/kotlin/com/example/get_smm/SmsKeepAliveService.kt`
  - foreground service persistant,
  - relance apres suppression de tache.

- `android/app/src/main/kotlin/com/example/get_smm/KeepAliveRestartReceiver.kt`
  - redemarre le service via alarme interne.

- `android/app/src/main/kotlin/com/example/get_smm/BootReceiver.kt`
  - relance keep-alive au boot et apres update APK.

- `android/app/src/main/kotlin/com/example/get_smm/MainActivity.kt`
  - expose le `MethodChannel get_smm/background_sms`.

## 9) Flux complet de sauvegarde

### Cas A - App ouverte

1. SMS arrive.
2. Listener Flutter capte le message.
3. Sauvegarde SQLite immediate.
4. UI s'actualise automatiquement.

### Cas B - App en arriere-plan / retiree des recents

1. SMS arrive.
2. `IncomingSmsReceiver` capte le message.
3. Message mis en queue de secours.
4. Tentative de sauvegarde SQLite immediate.
5. Si echec, le message reste en queue puis sera flush au prochain lancement.

## 10) Tests fonctionnels etape par etape

### Test 1 - Foreground (doit passer)

1. Laisser l'app ouverte.
2. Envoyer un SMS qui match le filtre.
3. Verifier apparition sans redemarrage.

### Test 2 - App retiree des recents (doit passer)

1. Ouvrir app une fois (permission accordee).
2. Verifier notification keep-alive visible.
3. Retirer app des recents (pas force stop).
4. Envoyer un SMS qui match le filtre.
5. Supprimer vite le SMS depuis Messages.
6. Rouvrir app et verifier que le SMS est sauvegarde.

### Test 3 - Force stop Android (limite normale)

1. Parametres Android > Applications > `get_smm` > Forcer l'arret.
2. Envoyer un SMS qui match.
3. Resultat attendu: pas de capture tant que l'app n'est pas relancee manuellement.

## 11) Verification technique

```bash
flutter analyze
cd android
./gradlew :app:compileDebugKotlin
```

## 12) Debug rapide

### 12.1 Verifier manifeste merge

```bash
rg "IncomingSmsReceiver|SmsKeepAliveService|KeepAliveRestartReceiver|BootReceiver"   build/app/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml
```

### 12.2 Lire les logs

```bash
adb logcat -c
adb logcat | grep -E "IncomingSmsReceiver|SmsKeepAliveService|PendingSmsStore|FLUSH_PENDING_SMS_FAILED"
```

### 12.3 Rebuild propre

```bash
flutter clean
flutter pub get
flutter run
```

## 13) Probleme frequents

### Probleme: marche app ouverte mais pas app retiree

- verifier notification keep-alive visible,
- verifier options batterie/auto-start du telephone,
- verifier que ce n'est pas un force stop.

### Probleme: SMS absent apres reopen

- verifier que le SMS match bien le filtre (`targetSender`/`targetKeyword`),
- verifier que la permission SMS est toujours accordee,
- verifier logs `IncomingSmsReceiver`.

## 14) Limite Android importante

Le mode **Force stop** bloque receivers/services pour l'app jusqu'au prochain lancement manuel.
C'est une regle Android systeme, pas un bug de votre code.

## 15) Dependances

- `another_telephony`
- `permission_handler`
- `sqflite`
- `path`
