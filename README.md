# Broke-No-More

A standalone, fully offline Flutter app that gamifies personal expense tracking. See
`CLAUDE.md` for architecture and dev commands, and `Docs/PRD/finance-app-prd.md` for the
product spec.

## Release build (Android)

Release builds are signed with the debug key by default, so `flutter build apk --release`
and `flutter run --release` work out of the box — but that build is **not uploadable to
Play**. To sign with a real release key:

1. Generate a keystore (skip if you already have one for this app):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (gitignored — never commit it):
   ```properties
   storePassword=<the keystore password>
   keyPassword=<the key password>
   keyAlias=upload
   storeFile=/absolute/path/to/upload-keystore.jks
   ```
3. Build as usual — `android/app/build.gradle.kts` picks up `key.properties` automatically
   and signs the `release` build type with it:
   ```bash
   flutter build appbundle --release
   ```

Losing the keystore or its password means you can never publish an update to the same Play
listing again, so back it up somewhere durable and separate from this repo.
