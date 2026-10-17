# Runtime SPI

Patches do seam interno entre o core do Flutter Engine e os backends de
runtime. Cada patch exportado registra uma mudança isolada do branch
`titan/runtime-spi`.

A série `runtime-spi` só modifica o repositório do Flutter.

| Patch | Por quê | Plataformas |
|---|---|---|
| `0001-build-engine-add-the-no-dart-dependency-checker.patch` | Adicionar o alvo GN e o checker antes de mover as fontes de `lib/ui`. | |
| `0002-feat-engine-split-the-dart-free-lib-ui-types.patch` | Separar os tipos de dados de `lib/ui` sem Dart no próprio alvo. | |
| `0003-feat-engine-route-fml-tracing-through-a-pluggable-timeline-backend.patch` | Encaminhar o tracing de FML por um backend de timeline substituível. | |
| `0004-feat-engine-drive-the-runtime-through-a-runtimebackend-interface.patch` | Conduzir o runtime por uma interface `RuntimeBackend`. | |
| `0005-feat-engine-create-the-shell-runtime-through-a-backend-factory.patch` | Criar o runtime do shell por uma fábrica de backends. | |
| `0006-fix-engine-make-the-runtime-spi-seams-compile.patch` | Restaurar includes e declarações removidos pela divisão do seam. | |
| `0007-refactor-engine-keep-dart-types-out-of-the-runtime-backend-seam.patch` | Consolidar as correções da revisão S1 para manter o seam sem tipos Dart. | |
| `0008-feat-engine-add-the-versioned-runtime-spi-c-header.patch` | Adicionar o header C11 versionado do Runtime SPI. | |
| `0009-test-engine-add-a-pure-c-runtime-for-spi-conformance.patch` | Adicionar um runtime de teste em C puro para a conformidade da ABI. | |
| `0010-feat-engine-run-spi-runtimes-behind-the-runtimebackend-seam.patch` | Executar runtimes SPI atrás do seam `RuntimeBackend`. | |
| `0011-test-engine-add-the-runtime-spi-conformance-suite.patch` | Adicionar a suíte de conformidade do Runtime SPI. | |
| `0012-fix-engine-build-the-runtime-spi-tests-only-with-unit-tests-enabled.patch` | Fazer os testes do Runtime SPI dependerem da configuração de testes. | |
| `0013-fix-engine-freeze-the-32-bit-runtime-spi-layout.patch` | Congelar o layout da ABI para ponteiros de 32 bits e campos de 64 bits. | |
| `0014-feat-engine-add-the-runtime-spi-scene-header.patch` | Adicionar os tipos C11 e a tabela de funções da API de cena, sem habilitá-la no engine S2. | |
| `0015-feat-engine-add-the-spi-handle-table.patch` | Implementar handles opacos por engine com retenção, liberação e ids que não são reutilizados. | |
| `0016-feat-engine-add-spi-paths-and-paints.patch` | Expor paths, geometria e paints básicos pela ABI de cena. | |
| `0017-feat-engine-add-the-spi-picture-recorder-and-canvas.patch` | Expor recorder, canvas, pictures e operações de desenho do `DisplayListBuilder`. | |
| `0018-feat-flow-expose-layer-properties-for-scene-tracing.patch` | Expor ao traço as propriedades necessárias das camadas de composição. | |
| `0019-feat-engine-add-the-spi-scene-builder-and-scene-trace.patch` | Montar cenas com transformações, clips, offsets, opacity e pictures, e gerar o traço canônico. | |
| `0020-test-engine-exercise-the-spi-scene-api-end-to-end.patch` | Validar a API de cena ponta a ponta e comparar o custo da ABI com o builder direto. | |
| `0021-feat-engine-add-the-runtime-spi-text-header.patch` | Adicionar a ABI C11 para estilos de texto, fontes, parágrafos, métricas e desenho. | |
| `0022-feat-engine-add-spi-text-styles-and-font-loading.patch` | Converter estilos para `txt` e carregar fontes dinâmicas pela API do Runtime SPI. | |
| `0023-feat-engine-add-spi-paragraphs.patch` | Montar, fazer layout e consultar parágrafos com paridade ao `txt` direto. | |
| `0024-feat-engine-draw-spi-paragraphs-and-exercise-text-end-to-end.patch` | Desenhar parágrafos pela cena e validar texto ponta a ponta pela suíte de conformidade. | |
| `0025-refactor-engine-separate-image-descriptor-data-from-its-dart-wrapper.patch` | Separar os dados de `ImageDescriptor` do wrapper Dart para permitir a decodificação sem Dart. | |
| `0026-feat-engine-add-the-runtime-spi-image-header.patch` | Adicionar a ABI C11 0.4 para imagens, pixels, opções de decodificação e transformações. | |
| `0027-feat-engine-draw-images-through-the-runtime-spi.patch` | Expor handles de imagem e operações de desenho de imagens pela API de cena. | |
| `0028-feat-engine-decode-images-through-the-runtime-spi.patch` | Decodificar imagens codificadas e pixels crus com callbacks assíncronos no UI runner. | |
| `0029-feat-engine-decode-spi-images-on-core-workers-and-test-them-end-to-end.patch` | Fornecer workers concorrentes ao core e validar a decodificação de imagens ponta a ponta. | |
| `0030-refactor-engine-separate-picture-snapshots-from-their-dart-wrappers.patch` | Separar a rasterização de pictures e cenas dos wrappers Dart. | |
| `0031-refactor-engine-separate-image-readback-from-its-dart-wrapper.patch` | Separar a conversão para raster e a codificação de imagens do wrapper Dart. | |
| `0032-refactor-engine-separate-animated-image-frames-from-their-dart-codec.patch` | Separar a decodificação e o avanço de quadros animados do codec Dart. | |
| `0033-feat-engine-turn-spi-pictures-and-scenes-into-images.patch` | Expor snapshots assíncronos e síncronos de pictures e cenas pela ABI 0.5. | |
| `0034-feat-engine-read-spi-image-pixels.patch` | Expor leitura de pixels e codificação PNG pela ABI do Runtime SPI. | |
| `0035-test-engine-cover-spi-image-codecs.patch` | Cobrir codecs estáticos e animados pela suíte do Runtime SPI. | |
| `0036-fix-engine-include-spi-factory-in-codec-tests.patch` | Corrigir o include da fábrica usado pelos testes de codec. | |
| `0037-fix-engine-guard-unwired-codec-test-callbacks.patch` | Evitar callbacks de teste de codec quando a costura ainda não está ligada. | |
| `0038-feat-engine-decode-spi-image-codecs-frame-by-frame.patch` | Expor criação, informações e leitura de quadros de codecs pela ABI. | |
| `0039-fix-engine-preserve-infinite-spi-codec-repetition.patch` | Preservar a repetição infinita dos codecs animados no Runtime SPI. | |
| `0040-test-engine-cover-spi-image-output-conformance.patch` | Cobrir a saída de imagens na suíte de conformidade do Runtime SPI. | |
| `0041-test-engine-exercise-spi-image-output-end-to-end.patch` | Exercitar snapshots, leitura de pixels e desenho de imagens ponta a ponta. | |
| `0042-feat-engine-add-the-runtime-spi-paint-effects-header.patch` | Adicionar a ABI 0.6 para shaders, filtros, máscara de blur e vertices. | |
| `0043-feat-engine-build-spi-shaders-and-filters.patch` | Construir shaders, filtros de cor e filtros de imagem Dart-free com handles imutáveis. | |
| `0044-feat-engine-paint-with-spi-shaders-filters-and-mask-blur.patch` | Aplicar efeitos da ABI ao paint e preservar a paridade com `dart:ui`. | |
| `0045-feat-engine-draw-spi-vertices.patch` | Expor a criação e o desenho de vertices pela API de cena. | |
| `0046-test-engine-exercise-spi-paint-effects-end-to-end.patch` | Exercitar efeitos de pintura e vertices pela suíte de conformidade ponta a ponta. | |
| `0047-fix-engine-freeze-the-32-bit-size-of-the-spi-engine-api-at-abi-0-6.patch` | Congelar o tamanho correto da tabela ABI em 32 bits depois da inclusão de `paint_effects`. | |
| `0048-feat-engine-add-the-runtime-spi-scene-layers-to-the-abi.patch` | Adicionar a ABI 0.7 para as camadas restantes do scene builder. | |
| `0049-feat-engine-resolve-dynamic-spi-blur-tile-modes-like-dart-ui.patch` | Resolver tile modes dinâmicos de blur como o `dart:ui`, incluindo bounds. | |
| `0050-feat-engine-push-spi-filter-mask-and-superellipse-layers.patch` | Expor camadas de filtro, máscara e clip de superelipse pela API de cena. | |
| `0051-feat-engine-add-spi-texture-platform-view-and-overlay-layers.patch` | Expor camadas de textura, platform view e performance overlay pela API de cena. | |
| `0052-feat-engine-retain-spi-engine-layers-across-frames.patch` | Reter camadas do engine entre quadros e reutilizá-las no scene builder. | |
| `0053-test-engine-exercise-spi-scene-layers-end-to-end.patch` | Exercitar as camadas do scene builder pela suíte de conformidade ponta a ponta. | |
| `0054-refactor-engine-separate-runtime-effect-loading-from-the-dart-fragment-program.patch` | Separar o carregamento de runtime effects do programa de fragmento Dart para permitir a reutilização sem Dart. | |
| `0055-feat-engine-add-the-runtime-spi-fragment-program-header.patch` | Adicionar a ABI C11 0.8 para fragment programs, uniforms e samplers. | |
| `0056-feat-engine-load-spi-fragment-programs-and-shaders.patch` | Carregar runtime stages de assets ou bytes e construir shaders e image filters com paridade ao `dart:ui`. | |
| `0057-test-engine-exercise-spi-fragment-programs-end-to-end.patch` | Exercitar fragment programs, uniforms, samplers, shaders e image filters pela suíte de conformidade ponta a ponta. | |
| `0058-feat-engine-add-the-runtime-spi-semantics-header.patch` | Adicionar a ABI C11 0.9 para nós de semântica, flags, textos, transformações, filhos e ações customizadas. | |
| `0059-feat-engine-build-spi-semantics-updates.patch` | Converter nós e ações customizadas pela ABI com paridade ao `SemanticsUpdateBuilder` do `dart:ui`. | |
| `0060-feat-engine-publish-spi-semantics-updates.patch` | Publicar atualizações de semântica no engine pela tabela do Runtime SPI e pela capacidade da ABI. | |
| `0061-feat-engine-add-the-runtime-spi-extensions-header.patch` | Adicionar a ABI C11 0.10 para as extensões opcionais do runtime. | |
| `0062-refactor-engine-call-dart-only-engine-features-through-the-spi-extensions-table.patch` | Chamar pelo SPI as funções do engine que só existem com Dart, preservando o core sem Dart. | |
| `0063-test-engine-exercise-the-spi-runtime-extensions-end-to-end.patch` | Exercitar as extensões do runtime pela suíte de conformidade ponta a ponta. | |
| `0064-feat-engine-add-service-handlers-to-the-runtime-spi-extensions.patch` | Adicionar handlers do service protocol à ABI C11 0.11 das extensões do runtime. | |
| `0065-refactor-engine-expose-the-shell-service-protocol-handlers-as-a-c-handler.patch` | Expor os handlers do service protocol do Shell no core, sem depender da VM do Dart. | |
| `0066-feat-engine-serve-the-core-service-handlers-through-the-dart-vm-service.patch` | Servir os handlers do core pelo transporte do VM service do Dart. | |
| `0067-refactor-engine-move-the-remaining-dart-code-out-of-the-shell.patch` | Mover os pontos restantes de Dart para fora do Shell comum. | |

O fluxo é:

1. `scripts/patch-branch.sh prepare <flutter_dir> <worktree_dir>` cria o
   worktree no commit de `flutter.lock` e aplica a série anterior.
2. Cada mudança é feita no worktree como um commit com corpo explicando o
   motivo.
3. `scripts/patch-branch.sh export <worktree_dir> runtime-spi` converte os
   commits em patches numerados para a série.

## Verificar o build

O build, os alvos de teste e a linha de base podem ser verificados por uma
única entrada, de qualquer diretório:

```bash
scripts/check-runtime-spi.sh
```

Para compilar sem executar os gtests, use `--skip-tests`. Alvos específicos
podem ser informados repetindo `--target <ninja-target>`.

O checker também executa uma segunda configuração GN sem `--unittests`, em um
diretório de saída separado, para detectar dependências indevidas de alvos de
teste antes de iniciar o ninja.

Cada diretório de saída é protegido por `<out_dir>/.titan-build.lock`. O
checker mantém as travas dos dois diretórios durante GN, Ninja e os testes; o
`build-engine.sh` chamado por ele recebe essa trava por ambiente. Uma segunda
execução no mesmo diretório termina imediatamente com o diagnóstico
`another build is running in <out_dir>`.

Com um build que tenha os testes habilitados, também é possível executar os
gtests diretamente a partir do diretório de saída:

```bash
scripts/run-engine-tests.sh <out_dir> \
  --baseline tests/runtime-spi/baseline-failures.txt
```

Os benchmarks estão listados separadamente em
`tests/runtime-spi/benchmark-targets.txt` e não são executados pelo runner de
gtests. Para medir a participação do Dart, use a biblioteca não despojada:

```bash
scripts/measure-dart-footprint.sh \
  <out_dir>/lib.unstripped/libflutter_engine.so
```
