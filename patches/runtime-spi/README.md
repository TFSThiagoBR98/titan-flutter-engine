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
| `0068-feat-engine-complete-the-runtime-spi-contract-in-both-directions.patch` | Completar a ABI C11 0.12 com o contrato entre engine e runtime nos dois sentidos. | |
| `0069-feat-engine-serve-the-full-runtime-contract-from-the-spi-backend.patch` | Servir o contrato completo pelo backend do Runtime SPI e pelo `RuntimeDelegate`. | |
| `0070-test-engine-exercise-the-full-runtime-contract-end-to-end.patch` | Exercitar o contrato completo do Runtime SPI ponta a ponta. | |
| `0071-feat-engine-add-warm-up-frames-opaque-launch-and-internal-bridges-to-the-spi.patch` | Adicionar warm-up frames, lançamento opaco do isolate e pontes internas à ABI 0.13. | |
| `0072-feat-engine-run-the-dart-runtime-behind-the-spi-table.patch` | Executar o runtime Dart atrás da tabela do Runtime SPI. | |
| `0073-refactor-engine-drive-dart-apps-through-the-spi-runtime-backend.patch` | Conduzir os apps Dart pelo backend de runtime do SPI. | |
| `0074-feat-engine-report-view-results-and-running-state-through-the-spi-table.patch` | Reportar resultados de view e o estado de execução do runtime pela tabela do SPI. | |
| `0075-fix-engine-give-the-dart-runtime-the-shell-s-platform-message-handler.patch` | Fornecer ao runtime Dart o `PlatformMessageHandler` do Shell. | |
| `0076-fix-engine-carry-the-full-view-metrics-and-consume-submitted-scenes-through-the-spi.patch` | Transportar as métricas completas de view e consumir cenas submetidas pelo SPI. | |
| `0077-test-engine-add-a-realistic-dart-ui-frame-benchmark.patch` | Adicionar o benchmark de quadro realista do `dart:ui` para o portão da S4d-1. | |
| `0078-feat-engine-add-rsuperellipse-and-canvas-queries-to-the-spi-scene-api.patch` | Adicionar superelipses e consultas de transformação e clips à API de cena. | |
| `0079-feat-engine-bridge-the-remaining-dart-ui-painting-objects-to-spi-handles.patch` | Criar pontes temporárias e handles SPI para os objetos restantes de pintura do `dart:ui`. | |
| `0080-refactor-engine-record-dart-ui-canvas-calls-through-the-spi-scene-api.patch` | Gravar as chamadas de `Canvas`, `PictureRecorder` e `Picture` pela API de cena. | |
| `0081-test-engine-cover-every-dart-ui-canvas-op-through-the-spi-recorder.patch` | Cobrir as operações de `Canvas` pela gravação do SPI. | |
| `0082-test-engine-cover-generation-aware-spi-handles.patch` | Cobrir handles SPI com slot e geração. | |
| `0083-perf-engine-look-up-spi-handles-by-slot-and-generation.patch` | Remover hash e cópia de `shared_ptr` do lookup quente de handles. | |
| `0084-test-engine-cover-converted-paint-cache-invalidation.patch` | Cobrir a invalidação do cache de paint convertido. | |
| `0085-perf-engine-reuse-the-last-converted-paint-per-recorder.patch` | Reutilizar o último paint convertido por recorder quando os bytes e handles forem válidos. | |
| `0086-test-engine-observe-converted-paint-changes-on-cache-misses.patch` | Verificar alterações observáveis do paint nos misses do cache. | |
| `0087-perf-engine-pass-dart-ui-paint-data-as-scalar-ffi-arguments.patch` | Passar os dados do paint como argumentos escalares FFI, sem natives leaf. | |
| `0088-test-engine-add-dart-ui-path-construction-benchmark.patch` | Estabelecer o benchmark de construção de paths do `dart:ui` para o portão da S4d-2. | |
| `0089-test-engine-add-s4d-2-path-spi-parity-red-tests.patch` | Fixar os testes RED de paridade da superfície de `Path` da ABI 0.16. | |
| `0090-feat-engine-implement-s4d-2-path-spi-operations.patch` | Implementar a superfície de paths da ABI 0.16 sobre `SkPath`. | |
| `0091-fix-engine-preserve-existing-spi-path-builders.patch` | Preservar os métodos existentes de construção de paths no SPI. | |
| `0092-fix-engine-match-vendored-path-apis.patch` | Usar os símbolos exatos de Skia e DisplayList do checkout fixado. | |
| `0093-test-engine-add-s4d-2-path-measure-spi-parity-red-tests.patch` | Fixar os testes RED de paridade de `PathMeasure` da ABI 0.16. | |
| `0094-feat-engine-implement-s4d-2-path-measure-spi.patch` | Expor a iteração de contornos e as operações derivadas de `PathMeasure` pela API de cena. | |
| `0095-fix-engine-include-the-path-type-in-measure-tests.patch` | Incluir a definição completa de `DlPath` no helper de paridade de medidas. | |
| `0096-feat-engine-move-dart-ui-paths-to-runtime-spi.patch` | Fazer `CanvasPath` e `CanvasPathMeasure` possuírem handles da API de cena. | |
| `0097-perf-engine-mutate-spi-paths-through-a-path-builder.patch` | Evitar reconstruir um `SkPathBuilder` completo a cada mutação de path. | |
| `0098-test-engine-add-dart-ui-scene-build-benchmark.patch` | Estabelecer o benchmark de construção de cenas retidas do `dart:ui` para o portão da S4e. | |
| `0099-test-engine-add-retained-scene-root-parity-tests.patch` | Fixar os testes RED de raiz retida reutilizável, ciclo de vida do builder e argumentos inválidos. | |
| `0100-feat-engine-build-retained-scene-roots-through-the-spi.patch` | Acrescentar a ABI 0.17 para construir raízes retidas e criar cenas dimensionadas reutilizáveis. | |
| `0101-fix-engine-avoid-rtti-in-retained-scene-root-creation.patch` | Manter a criação de raízes retidas compatível com as flags de build e nomear a ponte do SPI. | |
| `0102-test-engine-expect-the-retained-root-nested-in-the-new-scene.patch` | Ajustar o teste ao container novo que envolve a raiz retida. | |
| `0103-feat-engine-render-dart-ui-scenes-through-runtime-spi.patch` | Renderizar cenas do `dart:ui` por handles retidos do Runtime SPI. | |
| `0104-fix-engine-finish-the-frame-when-a-view-renders-an-empty-scene.patch` | Preservar a conclusão do quadro sem submeter cenas SPI de tamanho zero. | |
| `0105-test-engine-skip-empty-frames-before-creating-spi-scenes.patch` | Alinhar o helper de teste do Shell ao descarte de quadros vazios do Engine. | |
| `0106-fix-engine-accept-null-filters-in-spi-filter-layers.patch` | Preservar camadas de passagem quando `dart:ui` fornece um filtro nulo. | |
| `0107-refactor-engine-share-the-retained-layer-step-in-the-scene-builder.patch` | Manter cada push do `SceneBuilder` balanceado por um caminho único de retenção com erro explícito. | |
| `0108-fix-engine-preserve-the-scene-builder-test-bridge.patch` | Manter os testes C++ do compositor compilando enquanto o SPI possui as camadas. | |
| `0109-perf-engine-track-only-retained-layers-in-spi-scene-builders.patch` | Evitar hash e alocação para cada layer empurrado quando só os retidos exigem detecção de duplicata. | |
| `0110-perf-engine-store-engine-layers-directly-in-the-handle-table.patch` | Evitar a alocação de um wrapper para cada handle de layer retido. | |
| `0111-perf-engine-look-up-spi-scene-builders-without-refcounting.patch` | Evitar copiar o `shared_ptr` do builder em cada chamada da API de cena. | |
| `0112-perf-engine-retain-the-last-spi-scene-layer-in-one-call.patch` | Combinar lookup e atribuição do layer antigo em uma operação SPI. | |
| `0113-perf-engine-retain-pushed-dart-ui-layers-in-one-spi-call.patch` | Evitar chamadas separadas de handles ao reter cada layer empurrado pelo `dart:ui`. | |
| `0114-perf-engine-convert-scene-transforms-once.patch` | Preencher a transformação do SPI diretamente dos valores da matriz Dart. | |
| `0115-test-engine-add-the-runtime-spi-s4f-text-benchmark.patch` | Estabelecer o benchmark de construção de parágrafos do `dart:ui` para o portão da S4f. | |
| `0116-fix-engine-remove-unsupported-const-text-fixture-constructors.patch` | Ajustar os fixtures de texto aos construtores não-const do checkout fixado. | |
| `0117-test-engine-add-masked-text-style-and-paragraph-query-tests.patch` | Fixar os testes RED das máscaras de estilo e das consultas de parágrafo da ABI 0.18. | |
| `0118-feat-engine-add-masked-text-styles-and-paragraph-queries-to-the-spi.patch` | Acrescentar máscaras de estilo, herança, `decodeStrut` e consultas de parágrafo ao SPI. | |
| `0119-fix-engine-gate-text-style-masks-behind-an-explicit-flag.patch` | Fazer a máscara de estilo valer somente quando o bit de ativação estiver presente. | |
| `0120-fix-engine-use-a-typed-text-style-mask-flag.patch` | Nomear e tipar o bit que ativa as máscaras de estilo da ABI. | |
| `0121-fix-engine-carry-decoded-strut-fields-through-the-spi.patch` | Transportar os campos decodificados de `strut` até a construção do estilo do SPI. | |
| `0122-feat-engine-expose-the-spi-engine-to-dart-ui.patch` | Expor o engine do SPI às interfaces de runtime e ao `lib/ui`. | |
| `0123-fix-engine-route-dart-ui-font-loading-through-spi-table.patch` | Fazer o carregamento de fontes do `dart:ui` passar pela tabela do SPI. | |
| `0124-fix-engine-update-spi-runtime-test-delegates.patch` | Atualizar os delegates de teste para a interface de engine do SPI. | |
| `0125-fix-engine-keep-the-legacy-font-bridge-in-the-shell.patch` | Preservar a ponte de fontes legada somente no Shell durante a migração. | |
| `0126-feat-engine-move-dart-ui-text-to-runtime-spi.patch` | Mover builders, parágrafos e desenho de texto do `dart:ui` para os handles do SPI. | |
| `0127-fix-engine-make-spi-text-narrowing-explicit.patch` | Tornar explícitas as conversões estreitas dos valores de texto no SPI. | |
| `0128-test-engine-run-the-paragraph-benchmark-inside-a-shell.patch` | Executar o benchmark de parágrafos dentro de um Shell real. | |
| `0129-fix-engine-reuse-the-text-benchmark-icu-helper.patch` | Reutilizar o helper de ICU no fixture do benchmark de texto. | |
| `0130-fix-engine-run-the-paragraph-benchmark-through-a-concrete-shell-test.patch` | Encaminhar o benchmark de parágrafos pelo teste concreto de Shell. | |
| `0131-fix-engine-link-shell-test-fixtures-without-the-gtest-main.patch` | Ligar os fixtures do teste de Shell sem adicionar outro `gtest_main`. | |
| `0132-fix-engine-name-test-threads-outside-of-a-running-gtest.patch` | Nomear threads de teste também fora de um gtest em execução. | |
| `0133-perf-engine-query-paragraph-lists-in-one-spi-call.patch` | Evitar a segunda consulta ao recalcular listas de caixas e métricas. | |
| `0134-test-engine-cover-impeller-paragraph-text-frames.patch` | Cobrir a escolha de text frames e blobs dos parágrafos com Impeller. | |
| `0135-fix-engine-construct-parity-test-engine-explicitly.patch` | Construir explicitamente o engine usado pelo teste de paridade. | |
| `0136-fix-engine-include-runtime-controller-for-parity-test.patch` | Incluir o controlador de runtime necessário ao teste de paridade. | |
| `0137-fix-engine-type-runtime-backend-test-defaults.patch` | Corrigir os tipos dos defaults do backend de runtime nos testes. | |
| `0138-fix-engine-build-spi-paragraphs-with-the-engine-impeller-setting.patch` | Construir parágrafos do SPI com a configuração Impeller do engine. | |
| `0139-test-engine-add-utf-16-text-parity-coverage.patch` | Cobrir a paridade de texto UTF-16 entre o SPI e o `dart:ui`. | |
| `0140-perf-engine-add-utf-16-text-to-spi-paragraphs.patch` | Acrescentar texto UTF-16 à ABI de parágrafos do SPI. | |
| `0141-perf-engine-pass-dart-ui-text-to-the-spi-as-utf-16.patch` | Passar o texto do `dart:ui` diretamente como UTF-16 ao SPI. | |
| `0142-perf-engine-resolve-the-spi-text-table-once.patch` | Resolver uma vez a tabela de texto do SPI no caminho do `lib/ui`. | |
| `0143-test-engine-cover-utf-16-paragraph-ellipsis.patch` | Cobrir a paridade da reticência UTF-16 nos estilos de parágrafo. | |
| `0144-perf-engine-accept-utf-16-ellipsis-in-spi-paragraph-styles.patch` | Aceitar reticência UTF-16 nos estilos de parágrafo da ABI 0.18. | |
| `0145-test-engine-cover-the-txt-paragraph-input-domain.patch` | Fixar a paridade do domínio de entrada do `txt` em layout, consultas, métricas, glifos e placeholders. | |
| `0146-fix-engine-accept-the-txt-input-domain-in-spi-paragraphs.patch` | Fazer os parágrafos do SPI aceitarem o mesmo domínio de entrada que o `txt`, inclusive antes do layout e com largura infinita. | |
| `0147-fix-engine-keep-spi-handle-tables-alive-until-process-exit.patch` | Manter as tabelas de handles vivas até o fim do processo para liberar wrappers durante a destruição estática. | |
| `0148-test-engine-add-a-composite-frame-benchmark.patch` | Medir um quadro composto de cena, pintura, paths, canvas e texto para o portão integrado da S4f. | |
| `0149-test-engine-stress-spi-handle-tables-across-threads.patch` | Fixar a corrida entre inserção, busca, liberação e destruição reentrante nas tabelas de handles do SPI. | |
| `0150-fix-engine-lock-spi-handle-tables.patch` | Serializar o acesso às tabelas de handles entre engines e finalizadores, destruindo valores liberados fora da trava. | |
| `0151-test-engine-add-the-runtime-spi-s4g1-effects-benchmark.patch` | Adicionar o benchmark de efeitos do `dart:ui` para o portão da S4g-1. | |
| `0152-test-engine-add-s4g1-effects-parity-red-tests.patch` | Fixar os testes RED de paridade dos efeitos de pintura da S4g-1. | |
| `0153-feat-engine-add-image-filter-equality-to-the-spi.patch` | Acrescentar igualdade de filtros de imagem à ABI 0.19 do Runtime SPI. | |
| `0154-test-engine-cover-invalid-image-filter-equality-handles.patch` | Cobrir handles inválidos na igualdade de filtros de imagem. | |
| `0155-fix-engine-reject-invalid-image-filter-equality-handles.patch` | Rejeitar handles inválidos na operação de igualdade de filtros de imagem. | |
| `0156-feat-engine-create-dart-ui-effects-through-the-spi.patch` | Criar gradientes, filtros e vertices do `dart:ui` diretamente pela API de efeitos do SPI. | |
| `0157-fix-engine-expose-paint-effects-api-to-dart-ui.patch` | Expor a API de efeitos de pintura ao `lib/ui` por uma ponte interna permitida. | |
| `0158-fix-engine-update-effects-bridge-consumers.patch` | Atualizar os consumidores das pontes de efeitos removidas para manter os testes compilando. | |
| `0159-test-engine-add-runtime-spi-s4g2-image-benchmark.patch` | Adicionar o benchmark de imagens do `dart:ui` para o portão da S4g-2. | |
| `0160-test-engine-add-runtime-spi-image-parity-red-tests.patch` | Fixar os testes RED de paridade das imagens e snapshots da S4g-2. | |
| `0161-feat-engine-add-sync-pixel-images-color-space-and-snapshot-formats-to-the-spi.patch` | Acrescentar à ABI 0.20 a criação síncrona de pixels, o espaço de cor e o formato de snapshots. | |
| `0162-fix-engine-encode-gpu-and-deferred-spi-images-like-dart-ui.patch` | Codificar imagens de GPU e diferidas pela mesma rasterização e readback do `dart:ui`. | |
| `0163-test-engine-check-sync-pixel-images-by-size-and-drawing.patch` | Conferir imagens síncronas por tamanho e desenho no backend Skia e comparar bytes somente com Impeller. | |
| `0164-feat-engine-move-dart-ui-images-to-runtime-spi.patch` | Mover imagens, snapshots, readback e `ImageShader` do `dart:ui` para handles do Runtime SPI. | |
| `0165-fix-engine-route-ui-image-tests-through-spi-bridge.patch` | Atualizar os consumidores de teste da ponte de imagens do SPI. | |
| `0166-fix-engine-adapt-gpu-image-consumers-to-spi-handles.patch` | Adaptar consumidores de imagens de GPU aos handles do SPI. | |
| `0167-fix-engine-keep-gpu-image-bridge-within-ui-target.patch` | Manter a ponte de imagens de GPU no alvo de UI que a utiliza. | |
| `0168-fix-engine-update-embedder-image-test-consumer.patch` | Atualizar o consumidor de imagens do teste do embedder. | |
| `0169-fix-engine-fix-image-migration-compile-errors.patch` | Corrigir erros mecânicos de compilação restantes da migração de imagens. | |
| `0170-fix-engine-fix-remaining-image-migration-compile-errors.patch` | Corrigir os diagnósticos mecânicos finais da migração de imagens. | |
| `0171-test-engine-build-the-image-benchmark-images-with-toimagesync.patch` | Produzir as imagens do benchmark com `Picture.toImageSync`, compatível com o Shell Skia. | |

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
