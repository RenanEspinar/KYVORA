# Instalar y compilar Android

## APK entregada

El resultado exacto de compilación, firma e instalación está en `TEST_RESULTS.md`. La APK usa la URL de producción prevista. Puedes registrar entrenamientos localmente aunque el dominio todavía no responda.

En Android, descarga la APK y ábrela. Si Android lo solicita, permite instalar aplicaciones desde la aplicación que abrió el archivo. No es necesario root ni desbloquear el bootloader. Para actualizar una instalación, conserva el mismo identificador y certificado; cambiar la firma puede exigir desinstalación y eliminar los datos locales.

Requisito configurado: Android 7.0/API 24 o posterior. El código de la aplicación está compilado para ARM64 y x86-64. Esta entrega no admite dispositivos ARM32 ni x86 de 32 bits.

## Compilación reproducible

Toolchain usado: Flutter 3.35.6 / Dart 3.9.2, JDK 21, Android platform 36, build-tools 35.0.0, NDK 27.0.12077973. AGP 8.9.1 / Gradle 8.12 / Kotlin 2.1.0, sujetos al resultado exacto registrado.

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64,android-x64 --dart-define=APP_ENV=production --dart-define=API_BASE_URL=https://api.chuma.website/api/v1
```

El resultado se genera en `build/app/outputs/flutter-apk/app-release.apk`. Sin `android/key.properties`, se firma con la clave de depuración y se considera exclusivamente una build de pruebas. Para distribución estable configura tu keystore privado en ese archivo, fuera de Git. La clave, el alias y las contraseñas deben gestionarse localmente, nunca pegarse en el chat.

Puedes verificar un archivo con:

```bash
apksigner verify --verbose --print-certs app-release.apk
adb install -r app-release.apk
adb shell am start -n website.chuma.liftlog/.MainActivity
```

## Desarrollo local

```bash
flutter run --dart-define=APP_ENV=development --dart-define=API_BASE_URL=http://10.0.2.2:8180/api/v1
```

`10.0.2.2` representa al host desde el emulador estándar. El tráfico HTTP está permitido únicamente en la variante debug y según `debug_network.xml`. La variante release exige HTTPS. Cambiar el endpoint requiere recompilar, no editar direcciones dispersas.

Referencias oficiales: https://docs.flutter.dev/deployment/android y https://developer.android.com/tools/sdkmanager.
