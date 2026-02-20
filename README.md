# GET_SMS (`get_smm`)

Application Flutter Android pour récupération automatique de SMS ciblés.

Critères de récupération:
- Expéditeur (`address`) contient `Airtel` OU
- Contenu (`body`) contient `NetMlay`

## Fonctionnement

- Au démarrage, l'application demande la permission SMS.
- Si permission accordée, elle scanne les SMS existants et sauvegarde ceux qui
  correspondent au filtre.
- Ensuite elle écoute automatiquement les nouveaux SMS entrants et sauvegarde
  ceux qui correspondent (foreground + background).
- Les messages sont stockés localement via SQLite (anti-doublon).

## Prérequis

- Flutter SDK compatible Dart `3.10.3`
- Android uniquement
- Permissions Android:
  - `READ_SMS`
  - `RECEIVE_SMS`

## Démarrage

```bash
flutter pub get
flutter run
```

## Vérification locale

```bash
flutter analyze
flutter test
flutter build apk --debug
```
