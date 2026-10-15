# Estudo futuro: dependência do Dart no engine

Este documento reserva a estrutura da meta 3 do estudo do engine. A medição
será feita depois que o pipeline de build e os alvos de distribuição estiverem
estáveis.

## Pergunta

Quanto do Flutter Engine usado pelo TitanDM depende do Dart e quais partes
precisam permanecer no bundle quando o código Dart do TitanDM migrar para Rust?

## O que medir

- símbolos e objetos da Dart VM presentes em `libflutter_engine.so`;
- caminhos de inicialização que exigem um isolate ou um snapshot Dart;
- APIs do embedder que pressupõem a existência de Dart, direta ou
  indiretamente;
- diferença entre o bundle usado pelo shell e o bundle usado pelos demais
  apps Flutter.

## Horizonte

O resultado esperado é uma separação documentada entre o suporte Dart
necessário para os apps Flutter existentes e o que poderá ser removido quando
o código Dart do TitanDM for substituído por Rust. Este é um estudo futuro;
este arquivo não altera o bundle nem o comportamento do engine.
