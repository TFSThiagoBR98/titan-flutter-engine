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
