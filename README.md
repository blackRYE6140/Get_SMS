# GET_SMS (`get_smm`)

Application Flutter Android qui récupère automatiquement les SMS correspondant
au filtre:
- `address` contient `Airtel` OU
- `body` contient `1go`

Les SMS trouvés sont sauvegardés en local (SQLite) avec anti-doublon.

## Bref fonctionnement

- Au démarrage: demande permission SMS, puis scan des SMS existants.
- Ensuite: écoute automatique des nouveaux SMS (foreground + background).
- Affichage dans l'application de la liste des SMS sauvegardés.

## Dépendances utilisées

### Runtime (`pubspec.yaml`)

- `another_telephony: ^0.4.1`
  - Lecture SMS + écoute SMS entrants.
- `permission_handler: ^12.0.1`
  - Demande permission SMS au runtime.
- `sqflite: ^2.4.2`
  - Stockage local SQLite.
- `path: ^1.9.1`
  - Construction du chemin DB.
- `cupertino_icons: ^1.0.8`
  - Icônes UI.

### Dev/Test

- `flutter_test`
- `sqflite_common_ffi: ^2.3.6`
  - Permet les tests SQLite hors Android.

## Configuration Android requise (succès)

### 1) Manifest

Dans `android/app/src/main/AndroidManifest.xml`:

- Permissions:
  - `android.permission.READ_SMS`
  - `android.permission.RECEIVE_SMS`
- Receiver SMS:
  - `com.shounakmulay.telephony.sms.IncomingSmsReceiver`
  - action `android.provider.Telephony.SMS_RECEIVED`

### 2) Runtime permission

La permission SMS est demandée dans l'app via `permission_handler`.
Sans permission accordée, aucune récupération n'est possible.

### 3) Handler background

Le handler top-level `backgroundSmsHandler` est déclaré dans `lib/main.dart`
avec `@pragma('vm:entry-point')` pour traiter les SMS quand l'app n'est pas
au premier plan.

### 4) Base locale

Les SMS filtrés sont stockés dans:
- DB: `messages.db`
- table: `messages`

## Lancer le projet

```bash
flutter pub get
flutter run
```

## Vérification

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Notes Android importantes

- Lancer l'app au moins une fois pour accorder les permissions.
- Si l'app est en `Force Stop`, la réception background peut être bloquée.
