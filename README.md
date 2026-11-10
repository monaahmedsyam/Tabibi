# طبيبي (Tabibi)
تطبيق Flutter + Firebase حسب SRS.

## Firebase setup
1. أنشئ Firebase project وأضف Android app بنفس applicationId الموجود في android/app/build.gradle.kts.
2. ضع `google-services.json` داخل `android/app/`.
3. فعّل Email/Password Authentication وFirestore وStorage وCloud Functions.
4. ثبّت Firebase CLI ثم نفّذ `firebase login` و `firebase use --add` ثم `firebase deploy --only firestore:rules,storage,functions`.
5. لإنشاء أول Admin: أنشئ مستخدمًا من Firebase Authentication ثم أنشئ document بنفس UID في `users` بالقيم: `role: admin`, `status: active`, `name`, `email`.

## Run
`flutter pub get` ثم `flutter run`.
