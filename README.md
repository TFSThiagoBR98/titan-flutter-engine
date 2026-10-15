# titan-flutter-engine

Patches e build do Flutter Engine usado pelo TitanDM: aplica os patches sobre
um commit fixado do Flutter, compila o engine (Linux x86_64 e
cross-compilação para armv7-a hard/soft, arm64, riscv32 e riscv64) e publica os
artefatos.

O build x64 debug é o bundle usado pelo TitanDM. Cada alvo é CPU × ABI de
ponto flutuante (ARM) × libc (`glibc` ou `musl`); a matriz oficial, com o
estado de cada alvo, está em [docs/plataformas.md](docs/plataformas.md), e o
como compilar em [docs/cross-compilacao.md](docs/cross-compilacao.md). A CI
roda nos runners Linux x86_64 hospedados do GitHub (`ubuntu-24.04`), com uma
variante por job. O checkout novo do Flutter é raso e cada job usa o orçamento
completo de CPU do runner.

## Requisitos

- Linux x86_64 com `git`, `python3`, `curl`, `readelf`/`objdump` (binutils) e `ccache`. O script baixa sozinho o
  `depot_tools`, o checkout do Flutter no commit de `flutter.lock` e as dependências (`gclient sync`); o toolchain
  (Clang, `gn`, `ninja`) vem do próprio checkout.
- Espaço em disco: o checkout com dependências ocupa dezenas de GB; reserve ~40 GB para o primeiro build e o cache.
- Sysroots ARM: as dependências de host do Buildroot (`make`, `gcc`, `g++`, `patch`, `bzip2`, `perl`, `rsync`,
  `cpio`, `unzip`, `bc`, `file`, `wget`) e o Buildroot 2026.02.3 clonado em `.build_flutter/buildroot`.
- Validação dos alvos: `qemu-x86_64-static`, `qemu-aarch64-static`, `qemu-arm-static`,
  `qemu-riscv32-static` e `qemu-riscv64-static` (QEMU em modo usuário).

## Compilar

O script usa `.build_flutter/` ao lado do checkout que o chama como espaço de
trabalho, `ccache` e os caches do depot_tools. No superprojeto TitanDM, os
artefatos locais aparecem em `third_party/flutter-engine/`.

```sh
# x86_64, o bundle consumido pelo TitanDM
scripts/build-engine.sh --mode debug

# ARMv7-A hard-float e soft-float com sysroots Buildroot
scripts/make-buildroot-sysroot.sh --config titan_armv7a_hf_glibc_defconfig
scripts/build-engine.sh --mode debug --cpu arm --arm-float-abi hard \
  --target-sysroot .build_flutter/sysroots/titan_armv7a_hf
scripts/make-buildroot-sysroot.sh --config titan_armv7a_softfp_glibc_defconfig
scripts/build-engine.sh --mode debug --cpu arm --arm-float-abi softfp \
  --target-sysroot .build_flutter/sysroots/titan_armv7a_softfp

# ARMv7-A soft-float com musl, para o Kindle e sistemas de nicho
scripts/make-buildroot-sysroot.sh --config titan_armv7a_softfp_musl_defconfig
scripts/build-engine.sh --mode debug --cpu arm --arm-float-abi softfp --libc musl \
  --target-sysroot .build_flutter/sysroots/titan_armv7a_softfp_musl

# Matriz completa dos 12 alvos debug, quando os sysroots estão prontos
scripts/build-matrix.sh --parallel 4
```

Use `--zip` para publicar `artifacts/dist/flutter-engine-<variante>.zip` e
`--out <dir>` para escolher outro diretório de bundles. Em profile/release o
script também inclui o `gen_snapshot` do host.

## Artefatos do SDK Flutter

Os zips que o `flutter` tool baixa (para `flutter build`) também saem daqui, do engine com os nossos patches, no
mesmo layout do storage do Google, e se instalam no SDK pelo próprio `flutter precache`:

```sh
scripts/build-matrix.sh --parallel 3 sdk-host-debug sdk-host-release sdk-desktop-debug sdk-desktop-profile sdk-desktop-release
scripts/assemble-sdk-artifacts.sh
scripts/install-sdk-artifacts.sh <flutter-sdk>
```

Detalhes em [docs/artefatos-sdk.md](docs/artefatos-sdk.md).

## Organização dos patches

`patches/series` lista as pastas **por assunto** (`impeller-vulkan`,
`linux-embedder-only`, `linux-target-matrix`, `linux-compiler-runtime`,
`linux-musl`, `sdk-dart-packages`), na ordem de aplicação. A série não usa condições: o
`build-engine.sh` sempre aplica todas as pastas e todos os `.patch`, em ordem
lexicográfica, e cada patch se limita ao alvo certo por condições no próprio
GN. Assim, builds de alvos diferentes compartilham o mesmo checkout. Cada pasta
tem um README com a tabela patch → por quê → plataformas afetadas. O parser
continua aceitando condições `chave=valor` para séries antigas.

Um patch que modifica uma dependência do gclient começa com `# Repo: <caminho>`; os caminhos
do diff são relativos a esse repositório. Sem essa linha, o patch pertence ao repositório do
Flutter. Isso é necessário porque as dependências do gclient, como o SwiftShader, são
repositórios Git próprios dentro do checkout do Flutter.

## Vários alvos em paralelo

```sh
scripts/build-matrix.sh --parallel 4
```

Cada alvo compila num diretório próprio em `engine/src/out/`; a fase de patch
roda sob `flock` e é pulada quando o checkout já está com a mesma série. Os
logs ficam em `.build_flutter/matrix/`. Debug e profile compilam sem LTO.

O hash usado pelo lockfile do TitanDM é calculado sobre os bytes de
`patches/series` e de todos os patches de todas as pastas listadas, nessa
ordem. READMEs de funcionalidade não entram no hash.

Para atualizar o Flutter, altere `flutter_commit` e `flutter` em
`flutter.lock`, confira o novo checkout com o script e reaplique cada patch
com `git apply --check` antes de atualizar o número e o conteúdo dos patches.
O commit do Flutter deve ser fixado novamente antes de publicar um bundle.
Quando a série muda, o script restaura os arquivos tocados pelos patches a
partir desse commit antes de reaplicar, para que uma execução não herde
alterações de outra.

## Sysroots ARM

Os sysroots são gerados sem root pelo Buildroot 2026.02.3 usando a árvore
externa em `buildroot/`. A execução do Buildroot precisa ocorrer no host; ela
falhou no sandbox ao compilar o pacote de host `acl`, por isso os sysroots
prontos devem ser reutilizados no ambiente que tem as ferramentas do
Buildroot. Ambos usam a toolchain interna GCC 14.3.0 + glibc 2.42 e os
headers de kernel 5.10.257, a versão mais antiga oferecida por essa versão do
Buildroot.

A configuração efetiva do glibc foi conferida em `config.status`: o
Buildroot passou `--enable-kernel=5.10`, que gerou `__LINUX_KERNEL_VERSION_STR`
como `5.10.0`. Isso significa que esses binários podem recusar kernels mais
antigos, como os kernels 2.6/3.x de firmwares antigos do Kindle; para esses
dispositivos seria necessário um glibc mais antigo ou musl. O C++ da toolchain
está habilitado porque o engine é um artefato C++ e precisa dos headers e da
`libstdc++` de desenvolvimento no link.

```sh
scripts/make-buildroot-sysroot.sh --config titan_armv7a_hf_glibc_defconfig
scripts/make-buildroot-sysroot.sh --config titan_armv7a_softfp_glibc_defconfig
scripts/make-buildroot-sysroot.sh --config titan_armv7a_softfp_musl_defconfig
```

Não há pacotes de target, init ou imagem de rootfs nesses defconfigs; o
Buildroot é usado somente para construir a toolchain e o staging sysroot.

## CI e release

O repositório principal do engine fica no GitHub. `.github/workflows/build.yml`
usa runners hospedados `ubuntu-24.04` e uma matriz com uma variante por job.
O checkout do Flutter feito pelo `build-engine.sh` usa clone raso; o checkout
do repositório não usa cache porque é grande.

| Estágio | O que faz |
|---|---|
| `free-disk` | remove as ferramentas pré-instaladas listadas no workflow e libera espaço no runner |
| `deps` | instala as dependências do build com `sudo` no runner hospedado |
| `sysroot` | recupera o sysroot da release `sysroots-cache` ou gera e publica o defconfig da variante |
| `build` | `build-matrix.sh` com uma variante e `TITAN_PARALLEL=1` |
| `probe` | compila o app de `tests/qemu/app`, roda `TITAN_VARIANTS` no x64 nativo/QEMU e exige o **mesmo hash** de quadro em todos |
| `package` | empacota somente o zip da variante em `dist/` com `SHA256SUMS` |
| `release` | só em tags `v*`: junta os artefatos, gera `SHA256SUMS` e cria a release via `gh` |

Os mesmos estágios rodam localmente. Os caminhos vêm de `scripts/lib/paths.sh`:
`TITAN_WORK_DIR` (checkout do Flutter, depot_tools, ccache, Buildroot,
sysroots) e `TITAN_BUNDLE_DIR` (bundles e `dist/`). No CI, eles apontam para
`/mnt/titan/work` e `/mnt/titan/bundles`; o ccache fica em
`/mnt/titan/work/ccache` e é salvo por `actions/cache`. Sem as variáveis, dentro
do TitanDM valem `.build_flutter/` e `third_party/flutter-engine/` do
superprojeto; num clone isolado, `.build_flutter/` e `artifacts/` do próprio
repositório.

## CI GitHub Actions

O workflow roda automaticamente em pushes para `main`/`develop` e em tags
`v*`. Para cada variante, ele prepara `/mnt/titan`, libera espaço, instala
dependências, recupera o ccache, recupera ou publica o sysroot quando
necessário, compila, executa o probe e envia o bundle como artefato.

Não há cap de CPU no CI: `ci.sh` usa `nproc` e desativa o scope de CPU do
systemd. Localmente, o padrão continua sendo metade dos núcleos.

## Cache dos sysroots

Cada sysroot recebe uma chave SHA-256 calculada do defconfig, da árvore
`buildroot/`, do lock do Buildroot e de
`scripts/make-buildroot-sysroot.sh`. O stamp
`.titan-sysroot-key` só é gravado depois do runtime GCC, portanto identifica um
sysroot pronto. O tarball determinístico
`sysroot-<nome>-<chave16>.tar.zst` fica em
`$TITAN_WORK_DIR/sysroot-cache/` e também na release prerelease GitHub
`sysroots-cache`.

`make-buildroot-sysroot.sh` tenta primeiro o stamp, depois `fetch` local/remoto
e só então compila; no CI, `ci.sh sysroots` usa `--publish`. Para forçar uma
reconstrução, use:

```sh
scripts/make-buildroot-sysroot.sh --config titan_arm64_glibc_defconfig --force
scripts/sysroot-cache.sh fetch titan_arm64_glibc_defconfig
scripts/sysroot-cache.sh publish titan_arm64_glibc_defconfig
```

## Validação no QEMU (modo usuário)

`scripts/qemu-probe.sh` compila `tests/qemu/probe_engine.c` para a variante pedida, carrega o `libflutter_engine.so`,
inicia o engine com o renderer por software e espera o primeiro quadro de um app. Use `--target` com os nomes da
matriz; `--abi x64|hf|softfp|softfp-musl` permanece como apelido para os quatro alvos históricos. O x64 glibc roda
nativamente; os demais usam o QEMU e a CPU padrão do alvo. O app padrão é o de `tests/qemu/app` (gerado por
`scripts/build-probe-app.sh`); dentro do TitanDM, o app spike do superprojeto; `--assets <dir>` escolhe outro.

```sh
scripts/qemu-probe.sh --target x64-debug
scripts/qemu-probe.sh --target arm64-debug
scripts/qemu-probe.sh --target arm-hard-debug
scripts/qemu-probe.sh --target riscv32-glibc-debug
scripts/qemu-probe.sh --target riscv64-musl-debug
```

Saída esperada: `frame 320x240 hash=…` e `ok`, com o **mesmo hash** em todos os alvos para o mesmo app (o
`ci.sh probe` confere isso). Resultados e o caso armv6j em `docs/cross-compilacao.md`.

## Licença

Os scripts, a árvore do Buildroot, os testes e os patches deste repositório estão sob a licença Apache 2.0
([LICENSE](LICENSE)). O código do Flutter que os patches modificam continua sob a licença dele (BSD-3-Clause, no
repositório do Flutter), assim como os componentes de terceiros que o build baixa.
