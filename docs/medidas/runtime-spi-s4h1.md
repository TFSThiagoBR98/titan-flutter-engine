# Runtime SPI S4h-1 — Medição do portão de semântica

**Data:** 2026-10-28

**Benchmark:** `BM_DartSemanticsFrame` foi o portão, com 200 nós contendo 11
strings e um atributo por nó, 10 ações customizadas e `build` mais
`updateSemantics` em cada iteração. A implementação e a base da Task 1 foram
comparadas em A/B intercalado em dez rodadas. Os valores abaixo são as
medianas das rodadas. Os brutos estão em
`.build_flutter/bench/s4h1-semantics-ab.txt`,
`.build_flutter/bench/s4h1-semantics-ab2.txt`,
`.build_flutter/bench/s4h1-semantics-ab3.txt` e
`.build_flutter/bench/s4h1-ab.txt`.

| Rodada | antes | implementação | Δ |
|---|---:|---:|---:|
| Implementação inicial | 512 µs | 630 µs | +23% |
| Validador UTF-8 próprio, no lugar de `u_strFromUTF8` do ICU | 522 µs | 611 µs | +17% |
| Operações de move em `SemanticsNode` | 513 µs | 584 µs | **+13,8% ✅ aceito pelo usuário** |

Na primeira rodada, o validador UTF-8 próprio substituiu `u_strFromUTF8` do
ICU. Na segunda rodada, as operações de move foram implementadas em
`SemanticsNode`. O portão foi aceito com +13,8%, e a otimização restante fica
para a S5.5.

Os indicadores foram comparados com o branch `develop` em cinco rodadas, com
o build da implementação:

| Benchmark | `develop` | S4h-1 | Δ |
|---|---:|---:|---:|
| `BM_DartCompositeFrame` | 615 µs | 610 µs | −0,8% |
| `BM_DartParagraphFrame` | 3996 µs | 4015 µs | +0,5% |

## Diagnóstico

A thread de UI fica aproximadamente 97% ocupada nas duas variantes, conforme
a CPU por thread em `/proc`. A amostragem por `gdb` não serve neste benchmark:
o desenrolar de pilha falha no código JIT do Dart. O `valgrind --tool=callgrind`
com `--toggle-collect` funciona em um único native; dois padrões aninhados
desligam a coleta.

O callgrind mostrou que `SemanticsNode` não tinha operações de move: o
construtor de cópia e o destrutor eram declarados, então todo `std::move`
acabava copiando. O restante do custo é a cópia das strings exigida pela ABI C:
cada `const char*` é medido, validado e copiado, em contraste com o move das
`std::string` no caminho antigo, além da recriação dos atributos.

## Decisão

O restante fica para a S5.5: strings com tamanho explícito, menos validação e
menos cópias por nó, junto com as otimizações estruturais da S4f e da S4g-3.
