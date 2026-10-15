# titan-flutter-engine

Patches e build do Flutter Engine usado pelo TitanDM: aplica os patches sobre
um commit fixado do Flutter, compila o engine (Linux x86_64 e
cross-compilação para armv7-a hard/soft, arm64 e riscv64) e publica os
artefatos.

O build x64 debug é o bundle usado pelo TitanDM. Os builds ARM usam `glibc`
ou `musl` conforme o sysroot; `musl` está disponível, por enquanto, somente
para ARM soft-float. A CI roda em um runner Linux x86_64 self-hosted, porque
o checkout do Flutter e os builds do engine são grandes.

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

`patches/series` lista as pastas de funcionalidade na ordem em que devem ser
aplicadas. Cada linha tem o nome de uma pasta e pode ter condições no formato
`chave=valor`, como `cpu=arm` ou `libc=musl`; uma linha sem condições vale para
todos os alvos. Dentro de cada pasta, os arquivos `.patch` são aplicados em
ordem lexicográfica e começam em `0001`. O script ignora uma pasta quando uma
das condições não corresponde ao alvo atual e aceita patches já aplicados para
permitir reexecução.

O hash usado pelo lockfile do TitanDM é calculado sobre os bytes de
`patches/series` e dos patches aplicáveis ao alvo x64, nessa ordem. READMEs de
funcionalidade não entram no hash.

Para atualizar o Flutter, altere `flutter_commit` e `flutter` em
`flutter.lock`, confira o novo checkout com o script e reaplique cada patch
com `git apply --check` antes de atualizar o número e o conteúdo dos patches.
O commit do Flutter deve ser fixado novamente antes de publicar um bundle; o
script sempre restaura os arquivos tocados pelos patches a partir desse
commit para que uma execução não herde alterações de outra.

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

`.github/workflows/build.yml` roda a matriz x64 debug, ARM hard-float,
ARM soft-float glibc e ARM soft-float musl no runner self-hosted
`[self-hosted, linux, x64]`. Para cada alvo ARM, o workflow gera ou restaura o
sysroot Buildroot, compila com `--zip` e executa o probe em QEMU user-mode.
Pushes de tags `v*` juntam os zips e um `SHA256SUMS` em uma release do GitHub.
