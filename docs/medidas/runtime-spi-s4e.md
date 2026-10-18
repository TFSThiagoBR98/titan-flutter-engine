# Runtime SPI S4e — Medição do portão

**Data:** 2026-10-18

**Benchmarks:** `BM_DartSceneBuildFrame`, `BM_DartCanvasRecordFrame` e
`BM_DartPathBuildFrame`, executados em `out/host_profile`. O critério da fase
é uma regressão de no máximo 5% contra a linha de base. As medições foram
feitas em A/B intercalado, com o kernel correspondente ao build de cada
binário, o host sem carga e os sysroots suspensos.

Cada rodada registra a mediana de três repetições; o resultado do portão usa
cinco rodadas.

| Medição | `BM_DartSceneBuildFrame` base × S4e | `BM_DartCanvasRecordFrame` | `BM_DartPathBuildFrame` |
|---|---|---|---|
| Depois da Task 5 (`new`) | 1000 × 1325 µs, **+32,5% ❌** | 469 × 487, +3,8% | 980 × 1007, +2,8% |
| Depois da Task 5b (`new2`) | 993 × 1059 µs, **+6,6% ❌** | 465 × 474, +1,9% | 977 × 995, +1,8% |
| Depois da Task 5c (`new3`) | 995 × 1015 µs, **+2,0% ✅** | 471 × 476, +1,1% | 974 × 971, −0,3% |

## Depois da Task 5

A primeira medição reprovou o portão: a construção de cenas ficou 32,5% acima
da base. O perfil callgrind encontrou o custo novo no caminho de cada push:
`added_layers` alocava e calculava hash para todo layer, embora a verificação
de duplicata só fosse necessária para `add_retained`; cada push também criava
uma alocação extra para embrulhar o handle de `EngineLayer`, e `FindBuilder`
e `SpiEngineLayerGet` copiavam `shared_ptr` em chamadas quentes.

## Depois da Task 5b

A Task 5b removeu o conjunto por layer, guardando apenas os layers retidos,
armazenou diretamente o `shared_ptr<Layer>` na tabela de handles e fez o
lookup do builder sem copiar o `shared_ptr`. A regressão caiu para 6,6%, mas
ainda excedeu o limite. O perfil registrou 986 M instruções na base contra
1043 M no `new2`; o custo restante era fixo por push, especialmente as
chamadas de handles de `take_last_layer`, `Insert`/`Release`, a atribuição do
layer antigo e a conversão duplicada da matriz.

## Depois da Task 5c

A Task 5c acrescentou `scene_retain_last_layer`, combinando a retenção e a
atribuição do layer antigo em uma chamada, fez o `SceneBuilder` usá-la e
preencheu a matriz do SPI diretamente a partir do `Float64List`. A medição
final foi aprovada: a construção de cenas ficou 2,0% acima da base, abaixo do
limite de 5%.

As cinco rodadas do `new3` foram: cena base 1002, 997, 989, 990, 998 µs;
S4e 1017, 1019, 996, 1031, 1010 µs. O perfil callgrind evoluiu de 986 M
instruções na base para 1203 M no `new` e 1043 M no `new2`. Os brutos estão em
`.build_flutter/bench/s4e-ab.txt`, `.build_flutter/bench/s4e-ab2.txt` e
`.build_flutter/bench/s4e-ab3.txt`.
