# Tennis Club App

[![Deploy Flutter Web to Firebase Hosting](https://github.com/trpa04-bot/tennis/actions/workflows/deploy.yml/badge.svg)](https://github.com/trpa04-bot/tennis/actions/workflows/deploy.yml)

Flutter aplikacija za vođenje teniskog kluba, igrača, mečeva i tablice.

## CI/CD

- Push na main pokreće testove i live deploy na Firebase Hosting.
- Pull request prema main pokreće testove i preview deploy.
- Manual deploy je dostupan kroz Actions > Run workflow.

## Local run

- flutter pub get
- flutter run -d chrome

## Rollback

Ako novi deploy napravi problem:

1. Otvori Firebase Console > Hosting > Releases.
2. Pronađi prethodni stabilni release.
3. Promoviraj taj release kao live.

Alternativno, možeš napraviti revert problematičnog commita i push na main, što će pokrenuti novi automatski deploy.
