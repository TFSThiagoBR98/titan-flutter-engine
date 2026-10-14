# Linux embedder only

O patch remove o shell GTK do grafo Linux e suas dependências `pkg-config`
quando o engine é compilado apenas para o embedder Titan. O argumento
`build_linux_gtk_shell` continua `true` por padrão; o script do repositório
passa `false` e também ativa o modo Linux mínimo.

Aplica-se aos builds Linux do embedder, incluindo x64 e ARM.
