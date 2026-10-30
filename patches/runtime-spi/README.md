# Runtime SPI

Patches do seam interno entre o core do Flutter Engine e os backends de
runtime. Cada patch exportado registra uma mudança isolada do branch
`titan/runtime-spi`.

A série `runtime-spi` só modifica o repositório do Flutter.

Na S5.5 (2026-10-29) a série foi reorganizada: as correções, os testes
vermelhos, os ajustes de estilo e as otimizações foram juntados ao commit de
origem, mantendo a ordem das fases (270 → 153 patches). A árvore final é
idêntica à anterior. A série antiga está no worktree do engine no branch
`backup/runtime-spi-pre-rewrite` e na tag
`backup-runtime-spi-pre-rewrite-2026-10-29`.

| Patch | Por quê | Plataformas |
|---|---|---|
| `0001-build-engine-add-the-no-dart-dependency-checker.patch` | Adicionar o alvo GN e o checker antes de mover as fontes de `lib/ui`. | |
| `0002-feat-engine-split-the-dart-free-lib-ui-types.patch` | Separar os tipos de dados de `lib/ui` sem Dart no próprio alvo. | |
| `0003-feat-engine-route-fml-tracing-through-a-pluggable-timeline-backend.patch` | Encaminhar o tracing de FML por um backend de timeline substituível. | |
| `0004-feat-engine-drive-the-runtime-through-a-runtimebackend-interface.patch` | Conduzir o runtime por uma interface `RuntimeBackend`. | |
| `0005-feat-engine-create-the-shell-runtime-through-a-backend-factory.patch` | Criar o runtime do shell por uma fábrica de backends. | |
| `0006-refactor-engine-keep-dart-types-out-of-the-runtime-backend-seam.patch` | Consolidar as correções da revisão S1 para manter o seam sem tipos Dart. | |
| `0007-feat-engine-add-the-versioned-runtime-spi-c-header.patch` | Adicionar o header C11 versionado do Runtime SPI. | |
| `0008-test-engine-add-a-pure-c-runtime-for-spi-conformance.patch` | Adicionar um runtime de teste em C puro para a conformidade da ABI. | |
| `0009-feat-engine-run-spi-runtimes-behind-the-runtimebackend-seam.patch` | Executar runtimes SPI atrás do seam `RuntimeBackend`. | |
| `0010-test-engine-add-the-runtime-spi-conformance-suite.patch` | Adicionar a suíte de conformidade do Runtime SPI. | |
| `0011-feat-engine-add-the-runtime-spi-scene-header.patch` | Adicionar os tipos C11 e a tabela de funções da API de cena, sem habilitá-la no engine S2. | |
| `0012-feat-engine-add-the-spi-handle-table.patch` | Implementar handles opacos por engine com retenção, liberação e ids que não são reutilizados. | |
| `0013-feat-engine-add-spi-paths-and-paints.patch` | Expor paths, geometria e paints básicos pela ABI de cena. | |
| `0014-feat-engine-add-the-spi-picture-recorder-and-canvas.patch` | Expor recorder, canvas, pictures e operações de desenho do `DisplayListBuilder`. | |
| `0015-feat-flow-expose-layer-properties-for-scene-tracing.patch` | Expor ao traço as propriedades necessárias das camadas de composição. | |
| `0016-feat-engine-add-the-spi-scene-builder-and-scene-trace.patch` | Montar cenas com transformações, clips, offsets, opacity e pictures, e gerar o traço canônico. | |
| `0017-test-engine-exercise-the-spi-scene-api-end-to-end.patch` | Validar a API de cena ponta a ponta e comparar o custo da ABI com o builder direto. | |
| `0018-feat-engine-add-the-runtime-spi-text-header.patch` | Adicionar a ABI C11 para estilos de texto, fontes, parágrafos, métricas e desenho. | |
| `0019-feat-engine-add-spi-text-styles-and-font-loading.patch` | Converter estilos para `txt` e carregar fontes dinâmicas pela API do Runtime SPI. | |
| `0020-feat-engine-add-spi-paragraphs.patch` | Montar, fazer layout e consultar parágrafos com paridade ao `txt` direto. | |
| `0021-feat-engine-draw-spi-paragraphs-and-exercise-text-end-to-end.patch` | Desenhar parágrafos pela cena e validar texto ponta a ponta pela suíte de conformidade. | |
| `0022-refactor-engine-separate-image-descriptor-data-from-its-dart-wrapper.patch` | Separar os dados de `ImageDescriptor` do wrapper Dart para permitir a decodificação sem Dart. | |
| `0023-feat-engine-add-the-runtime-spi-image-header.patch` | Adicionar a ABI C11 0.4 para imagens, pixels, opções de decodificação e transformações. | |
| `0024-feat-engine-draw-images-through-the-runtime-spi.patch` | Expor handles de imagem e operações de desenho de imagens pela API de cena. | |
| `0025-feat-engine-decode-images-through-the-runtime-spi.patch` | Decodificar imagens codificadas e pixels crus com callbacks assíncronos no UI runner. | |
| `0026-feat-engine-decode-spi-images-on-core-workers-and-test-them-end-to-end.patch` | Fornecer workers concorrentes ao core e validar a decodificação de imagens ponta a ponta. | |
| `0027-refactor-engine-separate-picture-snapshots-from-their-dart-wrappers.patch` | Separar a rasterização de pictures e cenas dos wrappers Dart. | |
| `0028-refactor-engine-separate-image-readback-from-its-dart-wrapper.patch` | Separar a conversão para raster e a codificação de imagens do wrapper Dart. | |
| `0029-refactor-engine-separate-animated-image-frames-from-their-dart-codec.patch` | Separar a decodificação e o avanço de quadros animados do codec Dart. | |
| `0030-feat-engine-turn-spi-pictures-and-scenes-into-images.patch` | Expor snapshots assíncronos e síncronos de pictures e cenas pela ABI 0.5. | |
| `0031-feat-engine-read-spi-image-pixels.patch` | Expor leitura de pixels e codificação PNG pela ABI do Runtime SPI. | |
| `0032-test-engine-cover-spi-image-codecs.patch` | Cobrir codecs estáticos e animados pela suíte do Runtime SPI. | |
| `0033-feat-engine-decode-spi-image-codecs-frame-by-frame.patch` | Expor criação, informações e leitura de quadros de codecs pela ABI. | |
| `0034-test-engine-cover-spi-image-output-conformance.patch` | Cobrir a saída de imagens na suíte de conformidade do Runtime SPI. | |
| `0035-test-engine-exercise-spi-image-output-end-to-end.patch` | Exercitar snapshots, leitura de pixels e desenho de imagens ponta a ponta. | |
| `0036-feat-engine-add-the-runtime-spi-paint-effects-header.patch` | Adicionar a ABI 0.6 para shaders, filtros, máscara de blur e vertices. | |
| `0037-feat-engine-build-spi-shaders-and-filters.patch` | Construir shaders, filtros de cor e filtros de imagem Dart-free com handles imutáveis. | |
| `0038-feat-engine-paint-with-spi-shaders-filters-and-mask-blur.patch` | Aplicar efeitos da ABI ao paint e preservar a paridade com `dart:ui`. | |
| `0039-feat-engine-draw-spi-vertices.patch` | Expor a criação e o desenho de vertices pela API de cena. | |
| `0040-test-engine-exercise-spi-paint-effects-end-to-end.patch` | Exercitar efeitos de pintura e vertices pela suíte de conformidade ponta a ponta. | |
| `0041-fix-engine-freeze-the-32-bit-size-of-the-spi-engine-api-at-abi-0-6.patch` | Congelar o tamanho correto da tabela ABI em 32 bits depois da inclusão de `paint_effects`. | |
| `0042-feat-engine-add-the-runtime-spi-scene-layers-to-the-abi.patch` | Adicionar a ABI 0.7 para as camadas restantes do scene builder. | |
| `0043-feat-engine-resolve-dynamic-spi-blur-tile-modes-like-dart-ui.patch` | Resolver tile modes dinâmicos de blur como o `dart:ui`, incluindo bounds. | |
| `0044-feat-engine-push-spi-filter-mask-and-superellipse-layers.patch` | Expor camadas de filtro, máscara e clip de superelipse pela API de cena. | |
| `0045-feat-engine-add-spi-texture-platform-view-and-overlay-layers.patch` | Expor camadas de textura, platform view e performance overlay pela API de cena. | |
| `0046-feat-engine-retain-spi-engine-layers-across-frames.patch` | Reter camadas do engine entre quadros e reutilizá-las no scene builder. | |
| `0047-test-engine-exercise-spi-scene-layers-end-to-end.patch` | Exercitar as camadas do scene builder pela suíte de conformidade ponta a ponta. | |
| `0048-refactor-engine-separate-runtime-effect-loading-from-the-dart-fragment-program.patch` | Separar o carregamento de runtime effects do programa de fragmento Dart para permitir a reutilização sem Dart. | |
| `0049-feat-engine-add-the-runtime-spi-fragment-program-header.patch` | Adicionar a ABI C11 0.8 para fragment programs, uniforms e samplers. | |
| `0050-feat-engine-load-spi-fragment-programs-and-shaders.patch` | Carregar runtime stages de assets ou bytes e construir shaders e image filters com paridade ao `dart:ui`. | |
| `0051-test-engine-exercise-spi-fragment-programs-end-to-end.patch` | Exercitar fragment programs, uniforms, samplers, shaders e image filters pela suíte de conformidade ponta a ponta. | |
| `0052-feat-engine-add-the-runtime-spi-semantics-header.patch` | Adicionar a ABI C11 0.9 para nós de semântica, flags, textos, transformações, filhos e ações customizadas. | |
| `0053-feat-engine-build-spi-semantics-updates.patch` | Converter nós e ações customizadas pela ABI com paridade ao `SemanticsUpdateBuilder` do `dart:ui`. | |
| `0054-feat-engine-publish-spi-semantics-updates.patch` | Publicar atualizações de semântica no engine pela tabela do Runtime SPI e pela capacidade da ABI. | |
| `0055-feat-engine-add-the-runtime-spi-extensions-header.patch` | Adicionar a ABI C11 0.10 para as extensões opcionais do runtime. | |
| `0056-refactor-engine-call-dart-only-engine-features-through-the-spi-extensions-table.patch` | Chamar pelo SPI as funções do engine que só existem com Dart, preservando o core sem Dart. | |
| `0057-test-engine-exercise-the-spi-runtime-extensions-end-to-end.patch` | Exercitar as extensões do runtime pela suíte de conformidade ponta a ponta. | |
| `0058-feat-engine-add-service-handlers-to-the-runtime-spi-extensions.patch` | Adicionar handlers do service protocol à ABI C11 0.11 das extensões do runtime. | |
| `0059-refactor-engine-expose-the-shell-service-protocol-handlers-as-a-c-handler.patch` | Expor os handlers do service protocol do Shell no core, sem depender da VM do Dart. | |
| `0060-feat-engine-serve-the-core-service-handlers-through-the-dart-vm-service.patch` | Servir os handlers do core pelo transporte do VM service do Dart. | |
| `0061-refactor-engine-move-the-remaining-dart-code-out-of-the-shell.patch` | Mover os pontos restantes de Dart para fora do Shell comum. | |
| `0062-feat-engine-complete-the-runtime-spi-contract-in-both-directions.patch` | Completar a ABI C11 0.12 com o contrato entre engine e runtime nos dois sentidos. | |
| `0063-feat-engine-serve-the-full-runtime-contract-from-the-spi-backend.patch` | Servir o contrato completo pelo backend do Runtime SPI e pelo `RuntimeDelegate`. | |
| `0064-test-engine-exercise-the-full-runtime-contract-end-to-end.patch` | Exercitar o contrato completo do Runtime SPI ponta a ponta. | |
| `0065-feat-engine-add-warm-up-frames-opaque-launch-and-internal-bridges-to-the-spi.patch` | Adicionar warm-up frames, lançamento opaco do isolate e pontes internas à ABI 0.13. | |
| `0066-feat-engine-run-the-dart-runtime-behind-the-spi-table.patch` | Executar o runtime Dart atrás da tabela do Runtime SPI. | |
| `0067-refactor-engine-drive-dart-apps-through-the-spi-runtime-backend.patch` | Conduzir os apps Dart pelo backend de runtime do SPI. | |
| `0068-feat-engine-report-view-results-and-running-state-through-the-spi-table.patch` | Reportar resultados de view e o estado de execução do runtime pela tabela do SPI. | |
| `0069-test-engine-add-a-realistic-dart-ui-frame-benchmark.patch` | Adicionar o benchmark de quadro realista do `dart:ui` para o portão da S4d-1. | |
| `0070-feat-engine-add-rsuperellipse-and-canvas-queries-to-the-spi-scene-api.patch` | Adicionar superelipses e consultas de transformação e clips à API de cena. | |
| `0071-feat-engine-bridge-the-remaining-dart-ui-painting-objects-to-spi-handles.patch` | Criar pontes temporárias e handles SPI para os objetos restantes de pintura do `dart:ui`. | |
| `0072-refactor-engine-record-dart-ui-canvas-calls-through-the-spi-scene-api.patch` | Gravar as chamadas de `Canvas`, `PictureRecorder` e `Picture` pela API de cena. | |
| `0073-test-engine-cover-every-dart-ui-canvas-op-through-the-spi-recorder.patch` | Cobrir as operações de `Canvas` pela gravação do SPI. | |
| `0074-perf-engine-look-up-spi-handles-by-slot-and-generation.patch` | Remover hash e cópia de `shared_ptr` do lookup quente de handles. | |
| `0075-perf-engine-reuse-the-last-converted-paint-per-recorder.patch` | Reutilizar o último paint convertido por recorder quando os bytes e handles forem válidos. | |
| `0076-perf-engine-pass-dart-ui-paint-data-as-scalar-ffi-arguments.patch` | Passar os dados do paint como argumentos escalares FFI, sem natives leaf. | |
| `0077-test-engine-add-dart-ui-path-construction-benchmark.patch` | Estabelecer o benchmark de construção de paths do `dart:ui` para o portão da S4d-2. | |
| `0078-feat-engine-implement-s4d-2-path-spi-operations.patch` | Implementar a superfície de paths da ABI 0.16 sobre `SkPath`. | |
| `0079-feat-engine-implement-s4d-2-path-measure-spi.patch` | Expor a iteração de contornos e as operações derivadas de `PathMeasure` pela API de cena. | |
| `0080-feat-engine-move-dart-ui-paths-to-runtime-spi.patch` | Fazer `CanvasPath` e `CanvasPathMeasure` possuírem handles da API de cena. | |
| `0081-test-engine-add-dart-ui-scene-build-benchmark.patch` | Estabelecer o benchmark de construção de cenas retidas do `dart:ui` para o portão da S4e. | |
| `0082-feat-engine-build-retained-scene-roots-through-the-spi.patch` | Acrescentar a ABI 0.17 para construir raízes retidas e criar cenas dimensionadas reutilizáveis. | |
| `0083-feat-engine-render-dart-ui-scenes-through-runtime-spi.patch` | Renderizar cenas do `dart:ui` por handles retidos do Runtime SPI. | |
| `0084-refactor-engine-share-the-retained-layer-step-in-the-scene-builder.patch` | Manter cada push do `SceneBuilder` balanceado por um caminho único de retenção com erro explícito. | |
| `0085-perf-engine-track-only-retained-layers-in-spi-scene-builders.patch` | Evitar hash e alocação para cada layer empurrado quando só os retidos exigem detecção de duplicata. | |
| `0086-perf-engine-store-engine-layers-directly-in-the-handle-table.patch` | Evitar a alocação de um wrapper para cada handle de layer retido. | |
| `0087-perf-engine-look-up-spi-scene-builders-without-refcounting.patch` | Evitar copiar o `shared_ptr` do builder em cada chamada da API de cena. | |
| `0088-perf-engine-retain-the-last-spi-scene-layer-in-one-call.patch` | Combinar lookup e atribuição do layer antigo em uma operação SPI. | |
| `0089-perf-engine-retain-pushed-dart-ui-layers-in-one-spi-call.patch` | Evitar chamadas separadas de handles ao reter cada layer empurrado pelo `dart:ui`. | |
| `0090-perf-engine-convert-scene-transforms-once.patch` | Preencher a transformação do SPI diretamente dos valores da matriz Dart. | |
| `0091-test-engine-add-the-runtime-spi-s4f-text-benchmark.patch` | Estabelecer o benchmark de construção de parágrafos do `dart:ui` para o portão da S4f. | |
| `0092-feat-engine-add-masked-text-styles-and-paragraph-queries-to-the-spi.patch` | Acrescentar máscaras de estilo, herança, `decodeStrut` e consultas de parágrafo ao SPI. | |
| `0093-feat-engine-expose-the-spi-engine-to-dart-ui.patch` | Expor o engine do SPI às interfaces de runtime e ao `lib/ui`. | |
| `0094-feat-engine-move-dart-ui-text-to-runtime-spi.patch` | Mover builders, parágrafos e desenho de texto do `dart:ui` para os handles do SPI. | |
| `0095-test-engine-run-the-paragraph-benchmark-inside-a-shell.patch` | Executar o benchmark de parágrafos dentro de um Shell real. | |
| `0096-perf-engine-query-paragraph-lists-in-one-spi-call.patch` | Evitar a segunda consulta ao recalcular listas de caixas e métricas. | |
| `0097-test-engine-cover-impeller-paragraph-text-frames.patch` | Cobrir a escolha de text frames e blobs dos parágrafos com Impeller. | |
| `0098-fix-engine-build-spi-paragraphs-with-the-engine-impeller-setting.patch` | Construir parágrafos do SPI com a configuração Impeller do engine. | |
| `0099-perf-engine-add-utf-16-text-to-spi-paragraphs.patch` | Acrescentar texto UTF-16 à ABI de parágrafos do SPI. | |
| `0100-perf-engine-pass-dart-ui-text-to-the-spi-as-utf-16.patch` | Passar o texto do `dart:ui` diretamente como UTF-16 ao SPI. | |
| `0101-perf-engine-resolve-the-spi-text-table-once.patch` | Resolver uma vez a tabela de texto do SPI no caminho do `lib/ui`. | |
| `0102-perf-engine-accept-utf-16-ellipsis-in-spi-paragraph-styles.patch` | Aceitar reticência UTF-16 nos estilos de parágrafo da ABI 0.18. | |
| `0103-fix-engine-accept-the-txt-input-domain-in-spi-paragraphs.patch` | Fazer os parágrafos do SPI aceitarem o mesmo domínio de entrada que o `txt`, inclusive antes do layout e com largura infinita. | |
| `0104-fix-engine-keep-spi-handle-tables-alive-until-process-exit.patch` | Manter as tabelas de handles vivas até o fim do processo para liberar wrappers durante a destruição estática. | |
| `0105-test-engine-add-a-composite-frame-benchmark.patch` | Medir um quadro composto de cena, pintura, paths, canvas e texto para o portão integrado da S4f. | |
| `0106-fix-engine-lock-spi-handle-tables.patch` | Serializar o acesso às tabelas de handles entre engines e finalizadores, destruindo valores liberados fora da trava. | |
| `0107-test-engine-add-the-runtime-spi-s4g1-effects-benchmark.patch` | Adicionar o benchmark de efeitos do `dart:ui` para o portão da S4g-1. | |
| `0108-feat-engine-add-image-filter-equality-to-the-spi.patch` | Acrescentar igualdade de filtros de imagem à ABI 0.19 do Runtime SPI. | |
| `0109-feat-engine-create-dart-ui-effects-through-the-spi.patch` | Criar gradientes, filtros e vertices do `dart:ui` diretamente pela API de efeitos do SPI. | |
| `0110-test-engine-add-runtime-spi-s4g2-image-benchmark.patch` | Adicionar o benchmark de imagens do `dart:ui` para o portão da S4g-2. | |
| `0111-feat-engine-add-sync-pixel-images-color-space-and-snapshot-formats-to-the-spi.patch` | Acrescentar à ABI 0.20 a criação síncrona de pixels, o espaço de cor e o formato de snapshots. | |
| `0112-feat-engine-move-dart-ui-images-to-runtime-spi.patch` | Mover imagens, snapshots, readback e `ImageShader` do `dart:ui` para handles do Runtime SPI. | |
| `0113-test-engine-add-runtime-spi-s4g3-codec-benchmark.patch` | exercise the dart:ui codec path with eight PNG frames while keeping the shell benchmark on Skia. | |
| `0114-feat-engine-add-image-descriptors-asset-reads-and-shader-validation-to-the-spi.patch` | expose the S4g3 descriptor, asset, and fragment validation primitives that the Dart UI migration will consume. | |
| `0115-feat-engine-move-dart-ui-codecs-buffers-and-fragment-shaders-to-runtime-spi.patch` | move the dart:ui codec, asset, fragment shader, and picture paths onto the runtime SPI while removing obsolete internal bridges. | |
| `0116-fix-engine-build-spi-codecs-from-the-descriptor-generator.patch` | Reuse the generator and registry selected by the engine descriptor, including registered image decoders. | |
| `0117-fix-engine-create-encoded-spi-descriptors-synchronously.patch` | Preserve ImageDescriptor.encoded's synchronous invalid-data error contract and avoid posting Dart exceptions from a callback. | |
| `0118-feat-engine-carry-the-target-pixel-format-through-spi-decode-options.patch` | Preserve Dart UI target-format requests across the SPI descriptor and codec path until ImageDecoder receives its target format. | |
| `0119-perf-engine-drop-redundant-ui-hops-in-spi-image-decoding.patch` | Keep decoder and codec callbacks on the UI thread without reposting work that is already there, while preserving asynchronous delivery for cached frames. | |
| `0120-test-engine-add-a-semantics-frame-benchmark.patch` | establish the S4h-1 semantics benchmark baseline before routing dart:ui semantics through the runtime SPI. | |
| `0121-feat-engine-submit-dart-ui-semantics-through-the-spi.patch` | Preserve the runtime SPI ownership contract while forwarding dart:ui semantics into the engine boundary. | |
| `0122-feat-engine-add-a-fast-utf-8-validator-to-the-spi.patch` | Validate SPI strings with the Unicode well-formedness table and an ASCII fast path while preserving ICU's accepted domain. | |
| `0123-perf-engine-validate-spi-strings-without-icu.patch` | Reuse the SPI UTF-8 validator and measure each semantics string only once. | |
| `0124-perf-engine-move-semantics-nodes-instead-of-copying-them.patch` | let the semantics update path transfer node-owned storage into the core map. | |
| `0125-feat-engine-add-a-thread-safe-platform-message-sender-to-the-spi.patch` | let background-isolate platform messages reach the platform handler through a thread-safe SPI sender. | |
| `0126-feat-engine-send-background-isolate-platform-messages-through-the-spi.patch` | route background-isolate platform messages through the thread-safe SPI sender and retain sender ownership with the isolate group. | |
| `0127-feat-engine-give-dart-ui-one-spi-api-accessor.patch` | install one stable copy of the runtime SPI before Dart isolates start. | |
| `0128-refactor-engine-read-the-spi-through-one-accessor-in-dart-ui.patch` | make dart:ui use the runtime-installed SPI table instead of recreating engine API accessors. | |
| `0129-feat-engine-add-path-set-volatile-to-the-spi.patch` | Expose path volatility through the public SPI scene API while preserving invalid-handle semantics. | |
| `0130-refactor-engine-drop-dead-dart-ui-paths-left-after-the-spi-migration.patch` | Remove obsolete Dart UI bridges and exercise codec lifetime scenarios through the public SPI ABI. | |
| `0131-refactor-engine-use-the-public-spi-abi-in-the-remaining-dart-ui-natives.patch` | keep dart:ui on the public runtime SPI ABI while isolating the temporary flutter_gpu bridge. | |
| `0132-feat-engine-add-rsuperellipse-contains-to-the-spi.patch` | Implement the frozen scene ABI entry point with the same positive-bounds and raw-radii containment semantics as RSuperellipse. | |
| `0133-refactor-engine-move-core-code-out-of-the-dart-ui-target.patch` | keep the extracted core targets buildable and route the GPU bridge through the CanvasImage factory. | |
| `0134-refactor-engine-keep-core-types-out-of-dart-ui-signatures.patch` | expose only SPI-compatible scalar and geometry types from dart:ui while preserving the existing scene values. | |
| `0135-refactor-engine-keep-core-objects-out-of-the-dart-ui-isolate-context.patch` | keep core-owned rendering objects out of UIDartState::Context while preserving the live GPU and runtime-stage paths. | |
| `0136-refactor-engine-build-spi-colors-and-rects-without-display-list-in-dart-ui.patch` | Keep dart:ui painting conversions on the public SPI structs so the target can drop display_list implementation types without changing behavior. | |
| `0137-build-engine-cut-core-implementation-deps-from-the-dart-ui-target.patch` | Keep dart:ui on the SPI ABI while declaring direct dependencies for core-only decoder and encoder tests. | |
| `0138-fix-engine-pass-raw-image-pixel-formats-to-the-spi-by-its-own-enum.patch` | Keep dart:ui PixelFormat values aligned with the SPI enum so raw RGBA and BGRA descriptors reach the decoder without channel swaps or invalid formats. | |
| `0139-build-engine-assert-that-dart-ui-only-sees-the-spi-abi.patch` | Keep the dart:ui target free of implementation dependencies that are owned by ui_text_core, which already carries the test-font dependency for font_collection.cc. | |
| `0140-refactor-engine-keep-the-shell-service-protocol-off-the-dart-service-registry.patch` | keep the shell service protocol's parameter map owned by the shell core without including the Dart service registry. | |
| `0141-refactor-engine-make-the-run-configuration-launch-payload-opaque-to-the-core.patch` | Keep Dart-specific isolate launch configuration details behind the shell common Dart boundary while preserving the existing RunConfiguration callers and launch behavior. | |
| `0142-refactor-engine-build-dart-engines-outside-the-core-engine-class.patch` | keep worker-runner access behind RuntimeBackendFactory and retain the Dart VM include at the embedder boundary while moving Dart engine construction out of the core. | |
| `0143-refactor-engine-let-the-runtime-factory-build-kernel-launch-payloads.patch` | keep Dart-specific kernel launch construction out of the shell core. | |
| `0144-refactor-engine-spawn-runtime-backends-from-the-parent-backend.patch` | keep runtime controller access inside the Dart runtime boundary while allowing the shell core to spawn through the parent runtime backend. | |
| `0145-refactor-engine-drop-dart-timeline-calls-from-the-shell-core.patch` | keep the shell core independent from Dart timeline APIs and runtime controller headers; the monotonic FML clock provides the same deadline domain. | |
| `0146-build-engine-keep-dart-out-of-the-shell-core-target.patch` | isolate Dart shell sources and dependencies in a dedicated target while proving the common shell core cannot depend on Dart. | |
| `0147-feat-engine-add-the-core-host-api-header.patch` | Keep the reproducible runtime-spi patch series aligned with the verified engine worktree. | |
| `0148-refactor-engine-split-the-embedder-into-a-core-host-api-and-a-dart-translation.patch` | Record the verified core host API split fixes and build the host Settings before Dart run configuration inference. | |
| `0149-build-engine-keep-dart-out-of-the-embedder-core.patch` | Record the verified GN dependency boundary that keeps Dart out of the embedder core target. | |
| `0150-test-engine-run-an-spi-runtime-through-the-core-host-api.patch` | Record the verified end-to-end SPI runtime test through the core host API. | |
| `0151-build-engine-add-the-core-only-engine-library.patch` | provide the alternative core-only shared library for the Runtime SPI. | |
| `0152-build-engine-add-the-titan-flutter-runtime-dart-gn-arg.patch` | allow the Flutter embedder graph to omit Dart-backed targets while retaining the core runtime. | |
| `0153-test-engine-smoke-test-the-core-library-from-c.patch` | exercise the core runtime through a C executable and keep the smoke test linked only to the core library and its C test runtime. | |
| `0154-perf-engine-hand-decoded-images-to-spi-codecs-without-a-handle.patch` | the static codec frame wrapped, read and released a FlutterSpiImage handle between two core classes. | |
| `0155-fix-engine-build-flutter_tester-over-the-runtime-spi-split.patch` | tester_main.cc relied on runtime and tonic headers that came transitively before the Dart runtime moved out of the shell. | |
| `0156-test-engine-add-a-flutter-gpu-frame-benchmark.patch` | S7 needs a gate on a frame that exercises buffers, textures, a pipeline and a render pass. | |
| `0157-feat-engine-add-the-runtime-spi-gpu-context-table.patch` | S7a: flutter_gpu needs a C table for the default context and its capabilities (SPI ABI 0.25, `kFlutterSpiCapGpu`). | |
| `0158-feat-engine-add-runtime-spi-gpu-buffers.patch` | S7a: device buffers are created, written and flushed through the table. | |
| `0159-feat-engine-add-runtime-spi-gpu-textures.patch` | S7a: textures are created and overwritten through the table. | |
| `0160-refactor-engine-back-flutter-gpu-contexts-buffers-and-textures-with-the-spi-table.patch` | S7a: lib/gpu contexts, buffers and textures hold SPI handles; the rest reaches Impeller through internal bridges until S7c/S7d. | |
| `0161-fix-engine-check-the-runtime-spi-gpu-abi-on-32-bit-targets.patch` | S7a: the 32-bit size of FlutterSpiEngineApi was wrong and the gpu structs had no layout check on 32-bit targets. | |

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
