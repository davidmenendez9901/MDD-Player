# Plan de corrección — SongTube

> Objetivo: dejar la app compilable y funcional (reproducción y descarga de audio/video desde YouTube) sobre Flutter 3.44 / Dart 3.12.
>
> Estado inicial (2026-06-09): `flutter pub get` ✅ arreglado (intl 0.19→0.20.2). El código **no compila**: 30 errores + 411 warnings. Toolchain Android con probable incompatibilidad (Java 21 vs Gradle 7.5.1 / AGP 7.3.1).
>
> **Progreso (2026-06-09):** Sprint 1.1 ✅ (deps git actualizadas: NewPipe `953603`→`1e4a54`, audio_tagger `337e53`→`f907c4`) y Sprint 1.2 ✅ (`TabBarTheme`→`TabBarThemeData`). **Resultado: 0 errores de compilación.** Pendiente: build real de APK (Sprint 1.3 / Fase 2).
>
> ---
>
> **PARTE 1 — Corrección de errores** (Fases 1–4, abajo).
> **PARTE 2 — Nuevas funcionalidades: optimización para datos limitados** (Fases 5–9, al final del documento).

---

## 📍 ESTADO ACTUAL — leer esto primero

**Última actualización: 2026-06-09**

> **Cómo retomar:** mira la columna *Estado* en la tabla de abajo, busca el ⏭️ (próximo sprint), y continúa desde ahí. Al terminar un sprint: marca sus checkboxes `[x]`, cambia su fila a ✅, mueve el ⏭️ al siguiente, actualiza la fecha y añade una línea a la **Bitácora**.

> 👉 **PRÓXIMO PASO:** Sprint 3.1 — completar verificación de reproducción: audio en background (`audio_service`), trending, canales y playlists. Búsqueda y video ya verificados en dispositivo. **Ojo:** muchos fixes viven en `~/.pub-cache` (ver bitácora) — no ejecutar `flutter pub cache clean/repair` ni cambiar refs de git deps sin antes subir los fixes upstream.

Leyenda: ✅ hecho · 🔄 en curso · ⬜ pendiente · ⏭️ próximo

| Fase | Sprint | Estado | Notas |
|------|--------|--------|-------|
| 1. Compilación | 1.1 Deps git desincronizadas | ✅ | NewPipe→`1e4a54`, audio_tagger→`f907c4`. Eliminó ~27 errores. |
| 1. Compilación | 1.2 Flutter 3.44 (`TabBarThemeData`) | ✅ | 3 archivos de tema. **0 errores totales.** |
| 1. Compilación | 1.3 Validación de build | ✅ | `analyze` 0 errores + APK debug construido. Commit `69f9cc0`. |
| 2. Build Android | 2.1 Alinear toolchain | ✅ | Gradle 8.10.2 + AGP 8.7.0 + JDK 17 + ~20 parches en pub-cache. **APK: 238 MB.** |
| 2. Build Android | 2.2 Validación en dispositivo | ✅ | Galaxy S24 Ultra vía wireless adb. Arranque OK, permisos OK. |
| 3. Verif. funcional | 3.1 Reproducción | 🔄 | ⏭️ **AQUÍ** — búsqueda ✅, video 360p ✅, audio-only ✅, comentarios ✅. Falta: audio background, trending, canales, playlists. |
| 3. Verif. funcional | 3.2 Descarga | ⬜ | |
| 4. Limpieza | 4.1 Deprecaciones | ⬜ | Opcional (411 warnings). |
| 4. Limpieza | 4.2 SDK constraint | ⬜ | Opcional. |
| **5. Fundamentos** | 5.1 Settings nuevos | ⬜ | Inicio de PARTE 2. |
| **5. Fundamentos** | 5.2 NetworkManager | ⬜ | |
| **5. Fundamentos** | 5.3 Caché miniaturas | ⬜ | `cached_network_image`. |
| **5. Fundamentos** | 5.4 Validación | ⬜ | |
| 6. Modo Offline | 6.1 Guards de red | ⬜ | |
| 6. Modo Offline | 6.2 UI del switch | ⬜ | AppBar + Ajustes. |
| 6. Modo Offline | 6.3 Comportamiento offline | ⬜ | |
| 6. Modo Offline | 6.4 Verificación | ⬜ | |
| 7. Audio-only | 7.1 Reproducción audio directa | ⬜ | Por defecto ON. |
| 7. Audio-only | 7.2 Evitar datos de video | ⬜ | |
| 7. Audio-only | 7.3 Miniaturas ligeras | ⬜ | |
| 7. Audio-only | 7.4 Verificación | ⬜ | |
| 8. Redes lentas | 8.1 Reproducir local si existe | ⬜ | |
| 8. Redes lentas | 8.2 Priorizar local en UI | ⬜ | |
| 8. Redes lentas | 8.3 Resiliencia de red | ⬜ | |
| 8. Redes lentas | 8.4 Verificación | ⬜ | |
| 9. Cierre | 9.1 Pruebas integradas | ⬜ | |
| 9. Cierre | 9.2 Documentación | ⬜ | |

**Bitácora (qué se hizo y cuándo):**
- `2026-06-09` — Arreglado `flutter pub get` (`intl` 0.19→0.20.2 en `pubspec.yaml:38`).
- `2026-06-09` — Sprint 1.1: `flutter pub upgrade newpipeextractor_dart audio_tagger`.
- `2026-06-09` — Sprint 1.2: `TabBarTheme`→`TabBarThemeData` en `dark.dart`/`light.dart`. `flutter analyze` = 0 errores.
- `2026-06-09` — Commit `69f9cc0` "Fix compilation: update git deps + Flutter 3.44 API" (Sprints 1.1+1.2 commiteados).
- `2026-06-09` — Sprint 2.1 (working tree, sin commitear): migración a Gradle 8.10.2 + AGP 8.7.0 + Kotlin 1.9.23, JDK 17 vía `org.gradle.java.home`, `app/build.gradle` al DSL declarativo, inyección de `namespace` para plugins viejos. Heap de Gradle subido a 4G.
- `2026-06-09` — **Bloqueo resuelto:** el build se colgaba indefinidamente (daemon al 100% CPU sin progreso). Causa: `force = true` (API eliminada en Gradle 8) en el `android/build.gradle` de `newpipeextractor_dart`; la excepción disparaba un bucle infinito en el conversor de errores de Gradle (`DefaultFailureFactory`). Fix local en pub-cache: `implementation ('com.github.spotbugs:spotbugs-annotations:4.8.3!!')`. ⚠️ Falta subirlo upstream a `SongTube/NewPipeExtractor_Dart`.
- `2026-06-09` — **Cadena de fixes AGP 8 / Flutter moderno** (iterando `flutter build apk --debug`, cada error caía en segundos):
  1. `package=` en AndroidManifest de librerías ya no se admite → eliminado de los **34 plugins** en pub-cache (script sed; el `namespace` lo inyecta el build.gradle raíz).
  2. "Inconsistent JVM-target (1.8 vs 17)" → inyección de `compileOptions` Java 17 vía `subprojects.afterEvaluate` + `kotlin.jvm.target.validation.mode=warning` en `gradle.properties`.
  3. `:video_player` con compileSdk < 30 no admite source Java 17 → inyección de `compileSdkVersion 34` a todos los plugins.
  4. Embedding v1 (`PluginRegistry.Registrar`, eliminado de Flutter) → limpiado de **13 plugins** en pub-cache: 9 por script (borrar `registerWith`), 4 a mano (file_picker, image_picker_android, flutter_inappwebview, permission_handler_android — campos/parámetros/ramas v1; se conservó solo el camino v2).
  5. `com.github.teamnewpipe:NewPipeExtractor:v0.24.2` no resolvía: JitPack es case-sensitive → `TeamNewPipe` (otro fix para upstream `SongTube/NewPipeExtractor_Dart`).
  6. ffmpeg-kit retirado (binarios borrados de Maven Central y GitHub) → mirror Aliyun añadido como repo de respaldo en `android/build.gradle` (conserva `com.arthenica:ffmpeg-kit-audio:6.0-2.LTS`).
  7. Errores Dart con Flutter 3.44: `IconData` ahora es `final` → reescritas ~8.800 constantes generadas en ionicons/eva_icons/material_design_icons (pub-cache); `google_fonts` 5→6.3 (pubspec); `win32` 4.1.4 parcheado (`UnmodifiableUint8ListView`→`asUnmodifiableView()`, no subir a 5.x: file_picker necesita `winrt.dart`); override `fwfh_text_style` ^2.23.8 (textScaler).
  8. `audio_session` con `-Werror` + deprecaciones SDK 34 → strip de `-Werror` vía `doFirst` en build.gradle raíz.
  9. Daños colaterales del script v1: reconstruido `init()` v2-only en ffmpeg_kit_flutter_audio; eliminado `FlutterView` (v1) de flutter_inappwebview.
  10. `sensors_plus`: nulabilidad de `getDefaultSensor` (SDK 34) → `Sensor?`.
- `2026-06-09` — ✅ **`flutter build apk --debug` EXITOSO** → `build/app/outputs/flutter-apk/app-debug.apk` (238 MB). Sprints 1.3 y 2.1 cerrados.
  - ⚠️ **Todos los parches en `~/.pub-cache` se pierden si se re-fetchean los paquetes** (`flutter pub cache clean/repair` o cambio de ref). Mitigación pendiente: subir fixes upstream (git deps propios: NewPipeExtractor_Dart, apk_installer) y/o fork+pin o vendorizar los plugins de pub.dev abandonados.
- `2026-06-09` — **Sprint 2.2 ✅:** `flutter run` por wireless adb en Galaxy S24 Ultra (SM-S928U1). Instalación 47s, arranque sin crashes, intro completado, `READ_MEDIA_AUDIO` + foreground services concedidos.
- `2026-06-09` — Fix: `setState() after dispose()` en `finish_page.dart:30` (timer de 10s del intro) → check de `mounted`.
- `2026-06-09` — **Fix crash de reproducción** (`NullPointerException: uriString` en el fork de video_player): YouTube ahora devuelve 1 solo stream muxed (360p); `lastVideoQuality` por defecto es '720' y el `orElse` de `loadVideo` caía en "Audio Only" (`videoUrl=null`), que el lado nativo no tolera (`Uri.parse(null)` en `VideoPlayer.java:94`). Doble fix en `player_widget.dart`: (1) el fallback elige la mejor calidad con `videoUrl != null`; (2) si la calidad es audio-only, se pasa el audio como `videoDataSource`. **Verificado en dispositivo:** video 360p ✅ y "Audio Only" explícito ✅, sin excepciones.
- `2026-06-09` — Sprint 3.1 parcial: búsqueda ✅, fetch de video ✅ (16 videoOnly + 5 audio + 1 muxed), comentarios ✅.
- `2026-06-09` — Fix: "VideoPlayerController was used after being disposed" al cerrar el reproductor (`player_widget.dart:80`): el setter `youtubeVideo=null` disponía el controller pero solo lo anulaba en el `.then()` asíncrono → doble dispose en llamadas re-entrantes. Ahora se anula la referencia sincrónicamente antes de disponer (protege también el `dispose()` del widget). Bonus: `loadVideo()` ahora libera el controller anterior (códec nativo) al cambiar de video/calidad — antes se fugaba.
- `2026-06-09` — **Adelanto de Fase 7 (decisión del usuario):** "Audio Only" es ahora la calidad por defecto al abrir cualquier video (`player_widget.dart` `loadVideo`). El stream de video solo se carga si el usuario elige una calidad explícitamente en el selector. Objetivo: mínimo consumo de datos desde ya, sin esperar a la infraestructura de Fase 5.
- `2026-06-09` — **Fix descarga estancada (Sprint 3.2):** las descargas se quedaban congeladas a los pocos cientos de KB y nunca llegaban a `/storage/emulated/0/Music`. Causa: en `httpClient.dart` de NewPipeExtractor_Dart, `onError: (_) => null` tragaba los errores de stream (cortes de googlevideo) y el `StreamController` nunca cerraba → `await for` colgado para siempre. Fix en pub-cache (⚠️ subir upstream): forwarding directo de chunks con timeout de inactividad de 30 s, lo que activa el retry-con-resume que ya existía. Además `download_item.dart` ahora captura el fallo definitivo (5 retries agotados) y marca la descarga como error en vez de dejarla colgada.
- `2026-06-09` — **Fix crash al abrir canal (Sprint 3.1):** `NoSuchMethodError: '[]' on null` en `ChannelExtractor.channelInfo`. Causa raíz: race condition en `YoutubeChannelExtractorImpl.java` — el extractor se guardaba en un campo compartido de la clase y llamadas concurrentes (`getChannel` + `getChannelUploads` desde el pool de hilos del plugin) lo reasignaban a mitad de uso → "Page is not fetched". Triple fix (⚠️ los 2 primeros en pub-cache, subir upstream): extractor local en Java, excepción limpia en `channels.dart` si el mapa trae `error`, y try/catch con 1 retry en `channel.dart` de la app.
- `2026-06-09` — **Fix 403 en reproducción (Sprint 3.1):** algunos videos daban `InvalidResponseCodeException: 403` en ExoPlayer (otros funcionaban). Causa: las URLs de googlevideo pueden quedar ligadas al User-Agent que las generó; el extractor usa Firefox 78 (`DownloaderImpl.USER_AGENT`) pero el fork de video_player mandaba `setUserAgent("ExoPlayer")`. Fix en pub-cache (⚠️ subir upstream a `SongTube/video_player`): UA igualado en `VideoPlayer.java buildFactory`.
- `2026-06-09` — Anotación: videos con restricción de edad fallan con `AgeRestrictedContentException` ("cannot be watched anonymously") — limitación de YouTube sin login, la app lo captura sin crash. Mejora futura posible: mostrar mensaje claro al usuario.
- `2026-06-09` — **Diagnóstico definitivo del 403 (PoToken):** probada la URL del stream audio-only desde el propio móvil con curl (misma IP, UAs Firefox e iOS): 403 siempre → **la URL nace muerta**. Los streams del cliente iOS (`c=IOS`, `rqh=1`) requieren PoToken (botguard) que el extractor no genera. Patrón confirmado por el usuario: si el video reproduce, también descarga; si no, nada. El UA-matching del fix anterior no era suficiente (se mantiene de todas formas, es correcto).
- `2026-06-09` — Mitigaciones: (1) extractor actualizado a **v0.26.3** (release de hoy mismo); (2) **fallback automático en el reproductor**: si el stream audio-only da error de fuente, cambia solo al stream muxed 360p (viene de otro cliente y sí funciona) — `player_widget.dart`, flag `audioOnlyFallbackTried`. ⚠️ Pendiente: las **descargas** de esos videos siguen fallando (usan el mismo stream muerto); mitigación posible: descargar muxed + extraer audio con ffmpeg (infra ya existe en `FFmpegConverter.extractAudio`). **Fix de fondo (futuro): implementar `PoTokenProvider` en el plugin con WebView oculto, como hace la app oficial de NewPipe.** Nota: tras actualizar a v0.26.3 los 4 videos probados reprodujeron sin 403 — el fallback queda como red de seguridad.
- `2026-06-09` — **Reproductor de música (reporte del usuario: sin controles + "suena como llamada" al acabar). Diagnóstico en dispositivo con dumpsys media_session + instrumentación temporal:**
  1. **"Sonido de llamada"** = la biblioteca incluía las grabaciones de llamada/buzón de Samsung (`/Recordings/Call/...m4a`); al acabar la canción, el auto-avance reproducía una grabación. Esos m4a malformados además **mataban el decodificador AAC** (`MediaCodecAudioRenderer error` sin manejar) dejando el player sin responder. → Fix: filtro de `/Recordings/` y `/Notifications/` en `media_provider.songs`.
  2. **Player irrecuperable tras error de decoder** → `onError` en `playbackEventStream` (`audio_service.dart` de la app): detiene el player y publica estado de error manteniendo los controles.
  3. **Limbo al acabar la cola** (estado PLAYING al final del archivo) → al completar sin siguiente: rewind a 0 + pausa.
  4. **Metadata null en la MediaSession** (notificación "SongDebug is running" sin título ni info): cazado con traza Dart+Java — **bug de just_audio 0.9.31**: `AudioSource.file(path, tag: item)` acepta `tag` pero lo descarta → `mediaItem.add(null)` → `setMediaItem` nunca se envía. → Fix en `_createAudioSource`: `AudioSource.uri(Uri.file(id), tag: item)`.
  5. `AudioSession` configurada como música (`AudioSessionConfiguration.music()`) + `audio_session` como dependencia directa.
  - Verificado en dispositivo: sesión `active=true`, pausa/reanudar por notificación y media keys ✓, grabaciones fuera de la biblioteca ✓.
- `2026-06-09` — **Modo "Solo música" (petición del usuario, adelanto de Fase 7):** nuevo ajuste `musicOnlySearch` (default ON) en `AppSettings` + toggle en Ajustes generales. Cuando está activo, la búsqueda usa el filtro `music_songs` de NewPipe (catálogo de YouTube Music) → solo canciones, sin videos/canales no musicales. Verificado en dispositivo: búsqueda "shakira" devuelve solo canciones con carátula de álbum. Con el toggle OFF se respetan los filtros manuales de siempre. Además (petición del usuario): con "Solo música" activo la pestaña **Trending se oculta** (`home_default.dart`, contador de tabs dinámico) y su **fetch se omite** al iniciar (`refreshTrendingPage` con early-return → ahorra datos); al desactivar el toggle en Ajustes la pestaña reaparece y el trending se recarga. Verificado en dispositivo: home muestra solo Subscriptions/Playlists/Favorites, 0 excepciones.
- `2026-06-09` — **Garantía "nunca video sin permiso explícito" (petición del usuario):** auditadas todas las rutas — las listas de calidades solo construyen URLs desde metadata ya descargada; el único camino que auto-cargaba video era el fallback a muxed 360p introducido para los 403 de PoToken. Reemplazado: ante un stream de audio muerto ahora se prueban los **demás streams de audio** del video (hay ~5 itags), uno a uno, y si todos fallan el reproductor queda en error — **jamás carga un stream de video automáticamente**. El video solo se carga si el usuario elige una calidad de video en el selector. Commit `11a6c7b` + este cambio.

---

## Diagnóstico (causa raíz)

| # | Grupo de error | Origen | Nº errores |
|---|----------------|--------|-----------|
| A | API de librerías git desincronizada | El commit `582aca4` refactorizó el código para una API nueva de `newpipeextractor_dart` y `audio_tagger`, pero `pubspec.lock` apunta a versiones viejas (NewPipe `953603a`, mayo 2023; master está 5 commits adelante). | ~25 |
| B | Rupturas de API de Flutter 3.44 | `TabBarTheme` → `TabBarThemeData`. | 3 |
| C | Deuda técnica / deprecaciones | `withOpacity` → `withValues`, imports/variables sin usar. | 411 (info/warn) |
| D | Toolchain Android | Java 21 incompatible con Gradle 7.5.1 / AGP 7.3.1. | (build) |

---

## FASE 1 — Compilación (hacer que el proyecto compile)

Meta: `flutter analyze` sin errores y `flutter build apk --debug` exitoso.

### Sprint 1.1 — Actualizar dependencias git desincronizadas ✅
- [x] Ejecutar `flutter pub upgrade newpipeextractor_dart audio_tagger`.
- [x] Verificar nuevos `resolved-ref` en `pubspec.lock`. → NewPipe `953603`→`1e4a54`, audio_tagger `337e53`→`f907c4`.
- [x] Re-ejecutar `flutter analyze`. → De 30 errores quedaron 3 (todos del grupo B).
- [x] **Riesgo descartado:** la actualización de la librería cubrió todos los getters (`thumbnails`, `uploaderAvatars`, `avatars`/`banners`, `toList()`). No hizo falta tocar el código de la app.

**Archivos afectados (grupo A):**
- `lib/internal/media_utils.dart:224`
- `lib/internal/models/channel_subscription.dart:28`
- `lib/providers/content_provider.dart:310,322,330`
- `lib/providers/download_provider.dart:149`
- `lib/screens/channel.dart:123`
- `lib/screens/home/home_default/pages/subscriptions_page.dart:92`
- `lib/screens/home/home_default/pages/trending_page.dart:73`
- `lib/screens/id3_editor.dart:716`
- `lib/services/audio_service.dart:270`
- `lib/services/content_service.dart:83`
- `lib/ui/menus/download_menu/video.dart:109`
- `lib/ui/players/video_player/comments.dart:110,246`
- `lib/ui/players/video_player/player_widget.dart:465,790`
- `lib/ui/players/video_player/video_content.dart:260,296`
- `lib/ui/sheets/info_item_options.dart:70`
- `lib/ui/tiles/stream_playlist_tile.dart:59,62,199`
- `lib/ui/tiles/stream_tile.dart:224,228`

### Sprint 1.2 — Rupturas de Flutter 3.44 (grupo B) ✅
- [x] `lib/ui/themes/dark.dart:24,55` — `TabBarTheme` → `TabBarThemeData`.
- [x] `lib/ui/themes/light.dart:16` — `TabBarTheme` → `TabBarThemeData`.
- [x] Verificado: `analyze` no reveló más errores tras 1.1.

### Sprint 1.3 — Validación de compilación 🔄 ⏭️ PRÓXIMO
- [x] `flutter analyze` → 0 errores. (411 info + 5 warning no bloqueantes).
- [ ] `flutter build apk --debug` exitoso. ← **siguiente acción**
- [ ] Commit: "Fix compilation: update git deps + Flutter 3.44 API".

---

## FASE 2 — Build de Android funcional

Meta: generar APK/instalable en dispositivo real.

### Sprint 2.1 — Alinear toolchain
- [ ] Confirmar el fallo real con `flutter build apk` (no asumido).
- [ ] Opción A (mínima): apuntar a JDK 17 vía `flutter config --jdk-dir` u `org.gradle.java.home` en `android/gradle.properties`.
- [ ] Opción B (modernizar): subir Gradle (8.x) y AGP (8.x) para compatibilidad con Java 21 y Flutter 3.44. Mayor riesgo, evaluar después.
- [ ] Revisar `android/app/build.gradle`: `compileSdk 34`/`targetSdk 34` — evaluar subir a 35 si Flutter 3.44 lo exige.

### Sprint 2.2 — Validación en dispositivo ✅
- [x] Instalar APK en dispositivo Android real. → Galaxy S24 Ultra vía `flutter run` + wireless adb.
- [x] Verificar permisos en runtime (almacenamiento, media, foreground service). → `READ_MEDIA_AUDIO` y `FOREGROUND_SERVICE_MEDIA_PLAYBACK` concedidos.
- [x] Confirmar arranque sin crashes. → OK (un `setState` after dispose en el intro, arreglado).

---

## FASE 3 — Verificación funcional (YouTube)

Meta: confirmar que la extracción sigue operativa con el YouTube actual.

### Sprint 3.1 — Reproducción 🔄
- [x] Búsqueda de videos (`SearchExtractor`). → Verificado en dispositivo.
- [ ] Reproducción de audio en background (`just_audio` + `audio_service`).
- [x] Reproducción de video (`video_player`, streams muxed). → 360p + "Audio Only" OK tras fix del fallback de calidad.
- [ ] Trending, canales y playlists.

### Sprint 3.2 — Descarga
- [ ] Descarga de audio (selección de stream + conversión ffmpeg + tagging ID3).
- [ ] Descarga de video (mux audio+video con ffmpeg).
- [ ] Descarga por segmentos/capítulos.
- [ ] **Riesgo crítico:** si la extracción falla por cambios de YouTube, escalar issue al repo `SongTube/NewPipeExtractor_Dart`.

---

## FASE 4 — Limpieza y modernización (opcional, no bloqueante)

### Sprint 4.1 — Deprecaciones (grupo C)
- [ ] Reemplazar `withOpacity` → `withValues` (~ docenas de ocurrencias en `lib/ui/`).
- [ ] Eliminar imports y variables sin usar (`stream_playlist_tile.dart:1`, `download_tile.dart:137`, etc.).

### Sprint 4.2 — Constraints del SDK
- [ ] Actualizar `environment: sdk` de `>=2.17.6 <3.0.0` a un rango Dart 3 (`>=3.0.0 <4.0.0`).
- [ ] Revisar paquetes con warnings de plugins desktop (file_picker, wakelock) — irrelevante para Android pero conviene anotar.

---

## Orden de ejecución recomendado

1. **Fase 1** (bloqueante — sin esto nada compila). Empezar por Sprint 1.1 (bajo riesgo, alto impacto).
2. **Fase 2** (bloqueante para probar en dispositivo).
3. **Fase 3** (verificación real — define si el proyecto es viable).
4. **Fase 4** (calidad, cuando ya funcione).

## Criterios de aceptación global
- `flutter analyze` → 0 errores.
- APK debug compila e instala.
- Reproducción y descarga de audio/video funcionan en dispositivo real.

---
---

# PARTE 2 — Optimización para datos limitados

> Objetivo: minimizar el consumo de datos móviles. Tres funcionalidades:
> 1. **Modo Offline** — switch global que impide que la app se conecte a internet de forma no deseada. El usuario lo desactiva para buscar/descargar y lo reactiva cuando termina.
> 2. **Búsqueda/reproducción enfocada en audio** — no cargar streams ni miniaturas pesadas de video; al reproducir, ir directo al audio.
> 3. **Optimización para redes lentas** — priorizar contenido ya descargado, cachear miniaturas, reproducir el archivo local en vez de hacer streaming cuando exista.
>
> **Prerrequisito:** completar PARTE 1 (Fase 1 mínimo — el proyecto debe compilar).
>
> **Nota de licencia (GPLv3):** todos estos cambios son para uso personal/modificación. Mientras no se distribuya el binario, no hay obligación alguna. Si en el futuro se distribuye, basta con publicar el código fuente modificado bajo GPLv3 (ver `LICENSE`).

## Mapa de arquitectura relevante (referencia)

| Componente | Archivo | Rol |
|------------|---------|-----|
| Settings | `lib/providers/app_settings.dart` | Getters/setters estáticos sobre `shared_preferences` (patrón en líneas 113–116). |
| UI de ajustes | `lib/screens/settings/general_settings.dart` | Usa `SettingTileCheckbox` (`lib/ui/tiles/setting_tile.dart`). |
| Búsqueda/Trending | `lib/providers/content_provider.dart` (búsqueda L56–81, trending L88–93) · `lib/services/content_service.dart` | `SearchExtractor`, `TrendingExtractor`, etc. |
| Descargas | `lib/providers/download_provider.dart` · `lib/internal/models/download/` | Cola y canciones descargadas (`downloadedSongs` L33). |
| Música local | `lib/providers/media_provider.dart` | `songs` del dispositivo + caché. |
| Reproducción audio | `lib/services/audio_service.dart` | Local (`AudioSource.file` L103) y remoto (`audioUrl` L260–277). |
| Reproducción video | `lib/ui/players/video_player/player_widget.dart` | `VideoPlayerController.network()` L281–284. |
| Update checker | `lib/internal/models/update/update_manger.dart` | `http.get` a GitHub API L90. |
| Miniaturas de red | `NetworkImage(...)` disperso (media_utils L224, artist_card_tile L67, channel L123, player_widget L465, comments L110/246, id3_editor, music_brainz). |

---

## FASE 5 — Fundamentos compartidos (infraestructura)

Meta: crear la base que las tres funcionalidades necesitan: settings nuevos, una capa central de red y caché de imágenes. **Esta fase no cambia comportamiento visible todavía**, solo prepara el terreno.

### Sprint 5.1 — Nuevos settings en `AppSettings`
- [ ] En `lib/providers/app_settings.dart`, añadir las **keys** junto a las existentes (zona L8–68):
  ```dart
  static const String offlineModeKey = 'offlineMode';
  static const String dataSaverModeKey = 'dataSaverMode';
  static const String audioOnlyModeKey = 'audioOnlyMode';
  static const String preferDownloadedPlaybackKey = 'preferDownloadedPlayback';
  ```
- [ ] Añadir los **getters/setters** siguiendo el patrón de `enableWatchHistory` (L113–116):
  ```dart
  static bool get offlineMode => sharedPreferences.getBool(offlineModeKey) ?? false;
  static set offlineMode(bool v) => sharedPreferences.setBool(offlineModeKey, v);

  static bool get dataSaverMode => sharedPreferences.getBool(dataSaverModeKey) ?? false;
  static set dataSaverMode(bool v) => sharedPreferences.setBool(dataSaverModeKey, v);

  static bool get audioOnlyMode => sharedPreferences.getBool(audioOnlyModeKey) ?? true;   // ON por defecto
  static set audioOnlyMode(bool v) => sharedPreferences.setBool(audioOnlyModeKey, v);

  static bool get preferDownloadedPlayback => sharedPreferences.getBool(preferDownloadedPlaybackKey) ?? true;
  static set preferDownloadedPlayback(bool v) => sharedPreferences.setBool(preferDownloadedPlaybackKey, v);
  ```
- [ ] No requiere init explícito (los `?? default` cubren el primer arranque). Verificar que `sharedPreferences` ya está inicializado antes de leerse (`app_settings.dart:73–86`).

### Sprint 5.2 — Capa central de red (`NetworkManager`)
> **Decisión fijada:** solo manual, **sin `connectivity_plus`**.
- [ ] Crear `lib/internal/network/network_manager.dart`:
  ```dart
  import 'package:songtube/providers/app_settings.dart';

  class OfflineModeException implements Exception {
    final String message;
    OfflineModeException([this.message = 'La app está en modo offline']);
    @override String toString() => 'OfflineModeException: $message';
  }

  class NetworkManager {
    NetworkManager._();
    /// true si el usuario activó el modo offline.
    static bool get isOffline => AppSettings.offlineMode;
    /// true si se permite salir a la red.
    static bool get canConnect => !AppSettings.offlineMode;
    /// Lanza si está offline. Usar al inicio de cualquier llamada de red.
    static void ensureOnline() {
      if (isOffline) throw OfflineModeException();
    }
  }
  ```
- [ ] **Contrato:** toda ruta de red de la Fase 6 llama a `NetworkManager.canConnect`/`ensureOnline()` antes de salir. Aquí solo se crea el helper; los guards se aplican en Sprint 6.1.

### Sprint 5.3 — Caché de miniaturas en disco (`cached_network_image`)
> **Decisión fijada:** usar `cached_network_image`.
- [ ] Añadir `cached_network_image: ^3.3.x` a `pubspec.yaml` (sección Tools) y `flutter pub get`.
- [ ] Crear wrapper `lib/ui/components/st_network_image.dart` que:
  - Use `CachedNetworkImage` (caché en disco automática → no re-descarga).
  - Si `AppSettings.offlineMode`: **no** intentar red; mostrar solo si está en caché, si no un placeholder (sin petición saliente → usar `cacheManager` y `errorWidget`, o comprobar caché antes).
  - Exponer helper `lowRes(url)` que degrada la URL de miniatura de YouTube a `mqdefault`/`sddefault` cuando `dataSaverMode` o `audioOnlyMode` (ver Sprint 7.3).
- [ ] Migrar los puntos de `NetworkImage(...)` del mapa al wrapper único:
  `artist_card_tile.dart:67`, `channel.dart:123`, `player_widget.dart:465`, `comments.dart:110/246`, `id3_editor.dart`, `music_brainz_search.dart`.
- [ ] **Riesgo:** `PaletteGenerator.fromImageProvider(NetworkImage(...))` en `media_utils.dart:224` también descarga. → enrutar por el `cacheManager` del wrapper, o **saltar** el cálculo de paleta cuando `dataSaverMode`/`offlineMode` y usar un color por defecto.

### Sprint 5.4 — Validación
- [ ] `flutter analyze` → 0 errores nuevos.
- [ ] App arranca igual que antes (los flags por defecto no cambian comportamiento salvo `audioOnlyMode`/`preferDownloadedPlayback`, que se prueban en sus fases).

---

## FASE 6 — Modo Offline (switch global)

Meta: un interruptor que, al activarse, **impide toda conexión saliente**; al desactivarse, la app funciona normal.

### Sprint 6.1 — Guards en los puntos de red
Patrón a aplicar al inicio de cada método de red (early-return o excepción controlada):
```dart
if (NetworkManager.isOffline) return; // o: return []; o: throw OfflineModeException();
```
Puntos exactos donde insertarlo:
- [ ] Búsqueda — `content_provider.dart:56–81` → `return` temprano y dejar la UI mostrar el aviso (Sprint 6.3).
- [ ] Trending/home remoto — `content_provider.dart:88–93`, `content_service.dart:15–18` → devolver lista vacía/caché.
- [ ] Fetch de info de video/playlist/canal — `content_service.dart:20–84`.
- [ ] Descargas — `download_provider.dart` + `download_info.dart:38–48` → bloquear encolar y notificar "no disponible offline".
- [ ] Reproducción remota (audio) — `audio_service.dart:260–277` → si offline, solo permitir `AudioSource.file` (L103); si la pista no es local, abortar con mensaje.
- [ ] Reproducción remota (video) — `player_widget.dart:281–284`.
- [ ] Update checker — `update_manger.dart:90` → saltar si offline (además del `enableInAppUpdates` existente).
- [ ] Miniaturas de red — automático vía el wrapper `STNetworkImage` (Sprint 5.3): no sale a red en offline.

### Sprint 6.2 — UI del switch (AppBar + Ajustes) — *decisión fijada*
- [ ] **Ajustes:** `SettingTileCheckbox` en `general_settings.dart` (copiar el patrón de "Dynamic Colors" en L89–98):
  ```dart
  SettingTileCheckbox(
    leadingIcon: Ionicons.cloud_offline_outline,
    title: 'Modo offline',
    subtitle: 'Impide que la app se conecte a internet',
    value: AppSettings.offlineMode,
    onChange: (_) {
      AppSettings.offlineMode = !AppSettings.offlineMode;
      uiProvider.notifyListeners(); // refresca AppBar e indicadores
    },
  ),
  ```
- [ ] **Acceso rápido en AppBar:** `IconButton` en el home (icono avión/nube) que togglea `AppSettings.offlineMode`. Localizar el `AppBar`/header del home (`home_default.dart` y sus páginas) y añadir el botón.
- [ ] **Indicador visual** cuando offline está activo: cambiar el color/icono del botón (p. ej. relleno cuando ON) y opcional banner discreto.
- [ ] Estado reactivo: exponer `offlineMode` vía `ui_provider.dart` o un `ChangeNotifier` para que AppBar + ajustes se mantengan sincronizados. Persistencia ya la da `shared_preferences`.

### Sprint 6.3 — Comportamiento de la app en offline
- [ ] Al activar offline: redirigir/priorizar las pestañas de contenido local (Música/Descargas) y deshabilitar la búsqueda con mensaje "Activa la conexión para buscar".
- [ ] Cancelar de forma segura cualquier carga de red en curso.
- [ ] Asegurar que reproducción de archivos locales, biblioteca, playlists y ajustes funcionan 100% sin red.
- [ ] **Caso clave (el del usuario):** desactivar offline → buscar y descargar → reactivar offline; verificar que tras reactivar no hay ninguna petición saliente.

### Sprint 6.4 — Verificación
- [ ] Prueba con captura de tráfico / modo avión: con offline activo, **cero** peticiones salientes.
- [ ] Prueba del ciclo activar/desactivar/reactivar sin reiniciar la app.

---

## FASE 7 — Búsqueda y reproducción enfocadas en audio

Meta: al buscar y reproducir desde YouTube, no descargar datos de video; ir directo al audio.

### Sprint 7.1 — Reproducción directa de audio desde resultados de búsqueda
- [ ] Cuando `audioOnlyMode` está activo, al tocar un resultado de búsqueda reproducir el **stream de audio** (flujo `audio_service` background, usando `audioWithBestAacQuality ?? audioWithHighestQuality`) en lugar de abrir el reproductor de video (`player_widget.dart`).
- [ ] Evitar `VideoPlaybackQuality.fetchAllVideoQuality()` / streams `videoOnly` en este modo (`playback_quality.dart:22–44`).

### Sprint 7.2 — Evitar carga de datos pesados de video
- [ ] No cargar comentarios/avatares ni metadatos de video pesados al reproducir audio (`comments.dart`, `video_content.dart`) salvo petición explícita del usuario.
- [ ] Revisar que la búsqueda (`SearchExtractor`) no traiga más de lo necesario; ya devuelve solo metadatos básicos — confirmar que no se disparan fetches de stream en la lista.

### Sprint 7.3 — Miniaturas ligeras
- [ ] En `audioOnlyMode`/`dataSaverMode`, pedir miniatura de baja resolución (`mqdefault`/`sddefault` en lugar de `maxres`). El thumbnail de YouTube ya se construye en `download_item.dart:314` (`mqdefault.jpg`) — reutilizar ese criterio en toda la UI.
- [ ] Saltar el cálculo de `PaletteGenerator` desde red en estos modos.

### Sprint 7.4 — Verificación
- [ ] Medir datos consumidos en una sesión de búsqueda+reproducción de audio vs el flujo actual (debe bajar notablemente).
- [ ] Confirmar que sigue existiendo una vía para ver el video si el usuario lo pide explícitamente.

---

## FASE 8 — Optimización para redes lentas / priorizar lo descargado

Meta: que la app sea usable con conexión limitada y prefiera siempre lo que ya está en el dispositivo.

### Sprint 8.1 — Reproducir el archivo local si ya está descargado
- [ ] Al reproducir un resultado/historial, comprobar si existe en `download_provider.downloadedSongs` (o `media_provider.songs`) y reproducir el archivo local (`AudioSource.file`) en vez de hacer streaming. Controlado por `preferDownloadedPlayback`.
- [ ] Definir el criterio de match (videoId guardado en metadatos / nombre / id). Verificar qué identificador persiste el tagger (`download_provider.dart:39–69`).

### Sprint 8.2 — Priorizar contenido local en la UI
- [ ] En resultados de búsqueda, marcar con un icono los que ya están descargados (cruce contra `downloadedSongs`).
- [ ] En home, cuando `dataSaverMode`/`offlineMode`, abrir por defecto en la pestaña de Música/Descargas locales.

### Sprint 8.3 — Resiliencia de red
- [ ] Aumentar timeouts y añadir reintentos con backoff en descargas para conexiones inestables (ya hay reintentos parciales en `download_item.dart:229` — extender).
- [ ] Descargas reanudables si la librería lo permite (evaluar; puede quedar fuera de alcance).
- [ ] ~~Aviso antes de descargas grandes en datos móviles~~ → **descartado** (decisión: sin `connectivity_plus`, no se detecta tipo de red).

### Sprint 8.4 — Verificación
- [ ] Prueba con red limitada/lenta (throttling): reproducción de descargados instantánea, sin tocar la red.
- [ ] Confirmar que el cruce "ya descargado" funciona y evita streaming redundante.

---

## FASE 9 — Integración, pruebas y documentación

### Sprint 9.1 — Pruebas integradas
- [ ] Recorrer el flujo completo del usuario: offline OFF → buscar (audio) → descargar → offline ON → reproducir local sin red.
- [ ] Regresión: asegurar que usuarios que no tocan los nuevos ajustes mantienen la experiencia previa (salvo mejoras de datos).

### Sprint 9.2 — Documentación
- [ ] Documentar los nuevos ajustes en el README/about de la app.
- [ ] Anotar en el código los cambios y la fecha (buena práctica GPLv3 §5a si se distribuye).

---

## Decisiones tomadas (2026-06-09)

1. **Detección de red: solo manual.** No se añade `connectivity_plus`. El usuario controla todo con los switches. → Simplifica Sprint 5.2 (sin dependencia) y elimina el aviso automático de datos móviles del Sprint 8.3.
2. **Caché de miniaturas: `cached_network_image`** (nueva dependencia). → Sprint 5.3 opción A confirmada; crear wrapper `STNetworkImage` sobre `CachedNetworkImage`.
3. **Control de modo offline: AppBar + Ajustes.** Toggle rápido en la barra superior del home Y en ajustes. → Sprint 6.2 incluye ambos.
4. **Audio-only: activo por defecto** (`audioOnlyMode` default `true`, ya reflejado en 5.1). El video solo se carga si el usuario lo pide explícitamente.

## Orden de ejecución recomendado (PARTE 2)
1. **Fase 5** (fundamentos — todo lo demás depende de esto).
2. **Fase 6** (modo offline — la petición principal del usuario).
3. **Fase 7** (audio-only — mayor ahorro de datos).
4. **Fase 8** (priorizar descargado / red lenta).
5. **Fase 9** (integración y docs).

## Criterios de aceptación (PARTE 2)
- Con **modo offline activo**: cero peticiones salientes verificadas (modo avión / captura de tráfico).
- Ciclo activar→buscar/descargar→reactivar funciona sin reiniciar.
- En **audio-only**: consumo de datos por sesión notablemente menor; nunca se descargan streams de video sin pedirlo.
- Contenido **ya descargado** se reproduce desde el archivo local sin tocar la red.
- Sin regresiones para el usuario que no cambia los ajustes nuevos.
