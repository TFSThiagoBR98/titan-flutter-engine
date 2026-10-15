# Pacotes Dart do SDK

O `flutter` tool baixa `sky_engine.zip` (o `dart:ui` e as bibliotecas do engine) e `flutter_gpu.zip` para qualquer
SDK, mas o engine só define esses arquivos no build Android. Esta pasta os define também no Linux.

| Patch | Por quê | Plataformas afetadas |
|---|---|---|
| `0001-linux-dart-package-archives` | alvos `zip_old_location` de `flutter/sky/dist` e `flutter/lib/gpu/dist` no Linux | builds Linux que pedem esses alvos (artefatos do SDK) |
