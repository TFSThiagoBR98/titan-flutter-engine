# titan-flutter-engine

Patches e build do Flutter Engine usado pelo TitanDM: aplica os patches sobre
um commit fixado do Flutter, compila o engine (Linux x86_64 e
cross-compilação para armv7-a hard/soft, arm64 e riscv64) e publica os
artefatos.

O build x64 debug é o bundle usado pelo TitanDM. Cada alvo é CPU × ABI de
ponto flutuante (ARM) × libc (`glibc` ou `musl`); a matriz oficial, com o
estado de cada alvo, está em [docs/plataformas.md](docs/plataformas.md), e o
como compilar em [docs/cross-compilacao.md](docs/cross-compilacao.md). A CI
roda num runner Linux x86_64 próprio, porque o checkout do Flutter e os
builds do engine são grandes.

## Requisitos

- Linux x86_64 com `git`, `python3`, `curl`, `readelf`/`objdump` (binutils) e `ccache`. O script baixa sozinho o
  `depot_tools`, o checkout do Flutter no commit de `flutter.lock` e as dependências (`gclient sync`); o toolchain
  (Clang, `gn`, `ninja`) vem do próprio checkout.
- Espaço em disco: o checkout com dependências ocupa dezenas de GB; reserve ~40 GB para o primeiro build e o cache.
- Sysroots ARM: as dependências de host do Buildroot (`make`, `gcc`, `g++`, `patch`, `bzip2`, `perl`, `rsync`,
  `cpio`, `unzip`, `bc`, `file`, `wget`) e o Buildroot 2026.02.3 clonado em `.build_flutter/buildroot`.
- Validação ARM: `qemu-arm-static` (QEMU em modo usuário).

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

# Alvos de melhor esforço
scripts/build-engine.sh --mode debug --cpu arm64
scripts/build-engine.sh --mode debug --cpu riscv64
```

Use `--zip` para publicar `artifacts/dist/flutter-engine-<variante>.zip` e
`--out <dir>` para escolher outro diretório de bundles. Em profile/release o
script também inclui o `gen_snapshot` do host.

## Organização dos patches

`patches/series` lista as pastas **por assunto** (`impeller-vulkan`,
`linux-embedder-only`, `linux-target-matrix`, `linux-compiler-runtime`,
`linux-musl`), na ordem de aplicação. A série não usa condições: o
`build-engine.sh` sempre aplica todas as pastas e todos os `.patch`, em ordem
lexicográfica, e cada patch se limita ao alvo certo por condições no próprio
GN. Assim, builds de alvos diferentes compartilham o mesmo checkout. Cada pasta
tem um README com a tabela patch → por quê → plataformas afetadas. O parser
continua aceitando condições `chave=valor` para séries antigas.

## Vários alvos em paralelo

```sh
scripts/build-matrix.sh --parallel 4 x64-debug arm-hard-debug arm-softfp-debug arm-softfp-musl-debug
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

O repositório principal fica no Forgejo
(`forgejo.apps.dev.br/TFS_Tecnologia/titan-flutter-engine`), espelhado no
GitHub. `.github/workflows/build.yml` roda um único job num container
(`node:24-trixie`) do runner Forgejo com o label `docker`, e só chama
`scripts/ci.sh`, um estágio por passo:

| Estágio | O que faz |
|---|---|
| `deps` | instala as dependências do build no container (`apt-get`) |
| `sysroots` | gera os sysroots Buildroot das variantes (o Buildroot é clonado na versão de `buildroot/buildroot.lock`) |
| `build` | `build-matrix.sh` com `--zip` (`TITAN_VARIANTS`, `TITAN_PARALLEL`) |
| `probe` | compila o app de `tests/qemu/app`, roda o probe nativo no x64 e no QEMU nos alvos ARM e exige o **mesmo hash** de quadro em todos |
| `package` | junta os zips em `dist/` com `SHA256SUMS` |
| `release` | só em tags `v*`: cria a release pela API do Forgejo e envia os arquivos |

Os mesmos estágios rodam no host. Os caminhos vêm de `scripts/lib/paths.sh`:
`TITAN_WORK_DIR` (checkout do Flutter, depot_tools, ccache, Buildroot,
sysroots) e `TITAN_BUNDLE_DIR` (bundles e `dist/`). Sem as variáveis, dentro
do TitanDM valem `.build_flutter/` e `third_party/flutter-engine/` do
superprojeto; num clone isolado, `.build_flutter/` e `artifacts/` do próprio
repositório. No CI, as duas apontam para o volume persistente.

## Runner Forgejo

O workflow usa um runner Forgejo com o label `docker`. No host do runner, crie
o volume persistente:

```sh
sudo mkdir -p /srv/titan-flutter-engine
```

No `config.yml` do `forgejo-runner`, permita esse volume e mantenha uma tarefa
por vez:

```yaml
runner:
  capacity: 1
container:
  valid_volumes: ['/srv/titan-flutter-engine']
```

Reserve pelo menos 120 GB no volume. A primeira execução faz o `gclient sync`
e compila os sysroots, o que pode levar horas; as seguintes reaproveitam o
volume persistente.

## Validação no QEMU (modo usuário)

`scripts/qemu-probe.sh` compila `tests/qemu/probe_engine.c` para a ABI pedida, carrega o `libflutter_engine.so`,
inicia o engine com o renderer por software e espera o primeiro quadro de um app. No x64 o probe roda nativo; nos
alvos ARM, com `qemu-arm-static` (ou `qemu-arm`) `-cpu <cpu> -L <sysroot>`. O app padrão é o de `tests/qemu/app`
(gerado por `scripts/build-probe-app.sh`); dentro do TitanDM, o app spike do superprojeto; `--assets <dir>` escolhe
outro.

```sh
scripts/qemu-probe.sh --abi x64
scripts/qemu-probe.sh --abi hf --cpu cortex-a8
scripts/qemu-probe.sh --abi softfp --cpu cortex-a8
scripts/qemu-probe.sh --abi softfp-musl --cpu cortex-a8
```

Saída esperada: `frame 320x240 hash=…` e `ok`, com o **mesmo hash** em todos os alvos para o mesmo app (o
`ci.sh probe` confere isso). Resultados e o caso armv6j em `docs/cross-compilacao.md`.

## Licença

Os scripts, a árvore do Buildroot, os testes e os patches deste repositório estão sob a licença Apache 2.0
([LICENSE](LICENSE)). O código do Flutter que os patches modificam continua sob a licença dele (BSD-3-Clause, no
repositório do Flutter), assim como os componentes de terceiros que o build baixa.
