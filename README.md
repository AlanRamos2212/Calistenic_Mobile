# CalistenicTrack Mobile

A new Flutter project.

## Conectar con el backend

La app usa `POST /api/auth/login` y `POST /api/auth/register` en el backend. Ambos
endpoints devuelven un JWT que se guarda en almacenamiento seguro.

1. Inicia el backend y sus dependencias desde `Backend_Calistenic` con
   `docker compose up --build`.
2. Ejecuta la app Flutter. Para el emulador Android, la URL predeterminada es
   `http://10.0.2.2:8083/api`.
3. En un teléfono físico conectado a la misma red Wi-Fi, configura la IP local
   de la computadora:

   ```powershell
   flutter run --dart-define=API_BASE_URL=http://<IP-DE-TU-PC>:8083/api
   ```

Para iOS Simulator, usa `http://127.0.0.1:8083/api`. Las URL HTTP son para
desarrollo local; usa HTTPS para despliegues.

## Recursos de Flutter

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
