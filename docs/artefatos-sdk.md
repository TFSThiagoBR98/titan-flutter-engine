# Artefatos do SDK Flutter

O `flutter` tool não usa o `libflutter_engine.so` do TitanDM: para compilar um app, ele baixa zips do engine do
storage do Google, pelo hash do engine. Este repositório gera esses mesmos zips a partir do engine **com os nossos
patches**, no mesmo layout, e os instala no SDK pelo próprio `flutter precache`.

Estado (2026-10-17): o CI constrói cada combinação de sistema, arquitetura e perfil em uma célula própria. O macOS
usa somente arm64; os caminhos oficiais `darwin-x64*` continuam sendo usados para que o `flutter` tool os encontre
em qualquer Mac, mas os binários publicados são arm64.

## O que é gerado

Cinco builds, espelhando os builders do CI do Flutter (`engine/src/flutter/ci/builders/linux_host_engine.json` e
`linux_host_desktop_engine.json`), como variantes do `build-matrix.sh`:

| Variante | `out/` | Zips |
|---|---|---|
| `sdk-host-debug` | `sdk_host_debug` | `linux-x64/artifacts.zip`, `flutter_patched_sdk.zip`, `dart-sdk-linux-x64.zip`, `linux-x64/font-subset.zip`, `linux-x64/linux-x64-embedder.zip`, `linux-x64/impeller_sdk.zip`, `sky_engine.zip`, `flutter_gpu.zip` |
| `sdk-host-release` | `sdk_host_release` | `flutter_patched_sdk_product.zip` |
| `sdk-desktop-debug` | `sdk_desktop_debug` | `linux-x64-debug/linux-x64-flutter-gtk.zip` |
| `sdk-desktop-profile` | `sdk_desktop_profile` | `linux-x64-profile/linux-x64-flutter-gtk.zip` |
| `sdk-desktop-release` | `sdk_desktop_release` | `linux-x64-release/linux-x64-flutter-gtk.zip` |

Os builds desktop ligam o shell GTK (`--gtk-shell`, sem `--enable-minimal-linux`, que tiraria as dependências de
`pkg-config` do GTK) e o fontconfig. O `sky_engine.zip` e o `flutter_gpu.zip` só existem no build Android do
engine; a pasta de patches `sdk-dart-packages/` os define também no Linux. O Dart SDK é o *prebuilt* que o engine
usa. O bundle do TitanDM (`host_debug`, sem GTK) não muda.

```sh
scripts/build-matrix.sh --parallel 3 sdk-host-debug sdk-host-release \
  sdk-desktop-debug sdk-desktop-profile sdk-desktop-release
scripts/assemble-sdk-artifacts.sh
scripts/install-sdk-artifacts.sh <flutter-sdk>    # p. ex. .build_flutter/flutter
```

Medido no host (16 núcleos): host debug 7 min, os três desktop 13 min em paralelo, com o ccache já quente.

## Células do CI

Cada célula publica seus zips e mantém o log de cada variante no heartbeat do job. O Linux combina o bundle do
engine com os artefatos do SDK na mesma célula e no mesmo ccache:

| Job e células | Produção |
|---|---|
| `build`: 10 alvos × `debug`, `profile`, `release` | Bundle Linux do alvo, GTK do alvo e, em `x64-debug`, `x64-release` e `arm64-debug`, os SDKs host correspondentes |
| `linux_platform`: `android-<mode>-{arm,arm64,x64}` | Engine Android de cada arquitetura e perfil |
| `linux_platform`: `web-release` | SDK web de release |
| `windows`: `windows-{x64,arm64}-<mode>` | Host Windows; as células x64 de profile/release também geram os três `gen_snapshot` Android |
| `macos`: `macos-arm64-<mode>` | Host, framework e `gen_snapshot` macOS arm64; iOS device e simulador arm64; profile/release também geram os três `gen_snapshot` Android |

O `gen_snapshot` Android construído em macOS ou Windows não é um engine Android adicional: é o executável que roda
no host para compilar o AOT de um aplicativo Android. O job Android Linux fornece a mesma função para o host Linux,
por isso os hosts macOS e Windows mantêm esses snapshots dentro de suas próprias células, sem um job Android
separado.

O macOS compila somente arm64. Seus zips usam os caminhos oficiais `darwin-x64*`, que o `flutter` tool consulta em
qualquer Mac, mas contêm binários arm64; caminhos que dependem de x64 ficam fora da lista exigida em
`sdk/official-artifacts.txt`.

## Layout e hash

`assemble-sdk-artifacts.sh` monta `$TITAN_BUNDLE_DIR/sdk/flutter_infra_release/flutter/<hash>/` com os caminhos da
tabela, um `engine_stamp.json` (mesmos campos do oficial: data, revisão do Flutter, data da revisão e hash) e um
`MANIFEST` (caminho, tamanho, sha256). O `<hash>` é o que o tool pede: o *content hash* de
`bin/internal/content_aware_hash.sh`, calculado da árvore git do checkout **sem** os nossos patches (alterações
não commitadas). Por isso os nossos zips moram no **mesmo hash** dos oficiais; quem decide qual versão o SDK recebe
é a instalação abaixo.

## Instalação

`install-sdk-artifacts.sh` sobe `sdk-artifacts-server.py` em `127.0.0.1` e roda
`FLUTTER_STORAGE_BASE_URL=http://127.0.0.1:<porta> <sdk>/bin/flutter precache --linux --force` (sem Android, iOS,
web, macOS, Windows e Fuchsia). O servidor entrega o arquivo do layout quando existe e redireciona o resto para o
storage do Google, registrando cada pedido em `$TITAN_WORK_DIR/sdk-server.log` como `local` ou `upstream`. A
instalação falha se o tool pedir **qualquer** artefato do hash do engine que não esteja no layout; do storage do
Google só podem vir arquivos fora do engine (as fontes Material e o Gradle wrapper). O Dart SDK só é trocado com
`--with-dart-sdk`.

## Verificação (2026-10-15)

- **Nomes:** os 12 zips têm exatamente os mesmos arquivos que os oficiais do mesmo hash (`unzip -Z1` comparado).
- **Instalação:** o `precache` pediu 10 artefatos do engine, todos servidos pelo layout local; `upstream` só as
  fontes e o Gradle wrapper.
- **App de exemplo:** `flutter create` + `flutter build linux --debug` e `--release` compilam; o
  `libflutter_linux_gtk.so` do bundle release é byte a byte o do nosso zip, e o `libapp.so` (AOT) sai do nosso
  `gen_snapshot`. O app abre no `titan-compositor` (backend virtual, Vulkan): a janela GTK e o conteúdo Flutter
  aparecem.
- **TitanDM:** `fvm flutter build bundle`, `tools/ci.sh engine` e `tools/ci.sh vulkan` com o SDK usando estes
  artefatos.
