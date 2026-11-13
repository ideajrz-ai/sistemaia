# SistemaIA para Android

Aplicación Flutter conectada a la API Express y Supabase del monorepo. Incluye registro e inicio de sesión, recuperación por correo, perfil editable, encuesta con diagnóstico e historial, sesiones, citas con recordatorios del servidor, carga y apertura de archivos, QR diario, OCR por cámara/galería y administración de permisos de clientes.

Las geocercas circulares se crean tocando el mapa y se guardan por cuenta en el dispositivo. No se sincronizan con las geocercas del navegador ni ejecutan vigilancia de ubicación en segundo plano. Los mapas usan OpenStreetMap y requieren internet.

## Configuración

1. Configura Supabase y la API según el README raíz. Ejecuta el esquema SQL y habilita el bucket `archivos-consultoria` con sus políticas.
2. Publica la API con HTTPS. La URL debe ser la raíz del servicio, sin `/api`. Un teléfono no puede acceder al `localhost` de tu computadora.
3. Copia `config/example.json` a `config/local.json`. Rellena `SUPABASE_URL`, `SUPABASE_ANON_KEY` (anon o publishable) y `API_URL`. Este archivo está excluido de Git.
4. La configuración pública existente de Supabase se guardó en `config/local.json`; falta indicar la URL HTTPS de la API.
5. También puedes abrir una compilación sin configuración y capturar estos tres valores en la primera pantalla; se conservarán en el dispositivo.

Nunca incluyas la clave `service_role`, contraseñas SMTP ni secretos del backend en una APK. Los archivos `.env` del servidor no se empaquetan. Las conexiones móviles requieren HTTPS y las copias de seguridad de Android están desactivadas.

## Verificar y ejecutar

Requiere Flutter 3.50/Dart 3.14, JDK 17 y Android SDK 36 (plataforma, platform-tools y build-tools). Android mínimo: API 23 o el mínimo superior que requiera Flutter.

```sh
flutter pub get
flutter analyze
flutter test
flutter run --dart-define-from-file=config/local.json
```

## Generar APK

```sh
flutter build apk --release --dart-define-from-file=config/local.json
```

Salida: `build/app/outputs/flutter-apk/app-release.apk`. Sin el argumento de configuración, la app solicita los datos al abrirse.

Se generó una firma local de distribución en `android/sistemaia-release.jks` y su configuración en `android/key.properties`, ambos excluidos de Git. Conserva una copia segura de ambos archivos para futuras actualizaciones.

En una instalación nueva, para configurar una firma propia crea `android/key.properties`:

```properties
storeFile=sistemaia-release.jks
storePassword=TU_CONTRASENA
keyPassword=TU_CONTRASENA
keyAlias=sistemaia
```

Guarda el keystore en `android/sistemaia-release.jks`. Ambos archivos están excluidos de Git. Conserva una copia segura: se requiere la misma firma para instalar actualizaciones. Si no existe `key.properties`, la compilación usa la firma de desarrollo para pruebas y no es una entrega firmada para Google Play.

## Comprobación en teléfono

- Registrar un usuario, confirmar el correo si Supabase lo solicita e iniciar sesión.
- Editar perfil y verificarlo en la web.
- Contestar una encuesta y consultar diagnóstico e historial.
- Crear y eliminar una sesión y una cita; cambiar estado de la sesión.
- Subir un archivo de hasta 20 MB y abrir su URL temporal.
- Generar QR y validarlo una sola vez desde recepción.
- Reconocer texto de una foto y copiarlo.
- Crear una geocerca, cerrar y reabrir para comprobar persistencia.
- Cerrar sesión y comprobar que se pide acceso de nuevo.

Los recordatorios reales requieren SMTP/WhatsApp y ejecución del procesador del backend. La recuperación de contraseña usa el flujo por correo configurado en Supabase. La app móvil no despliega ni configura esos servicios automáticamente.
