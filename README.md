# titan-flutter-engine

Patches e build do Flutter Engine usado pelo TitanDM: aplica os patches sobre
um commit fixado do Flutter, compila o engine (Linux x86_64 e
cross-compilação para armv7-a hard/soft, arm64 e riscv64) e publica os
artefatos.

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
```

Não há pacotes de target, init ou imagem de rootfs nesses defconfigs; o
Buildroot é usado somente para construir a toolchain e o staging sysroot.
