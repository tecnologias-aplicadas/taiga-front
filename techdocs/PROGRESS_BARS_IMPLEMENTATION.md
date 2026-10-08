# Implementação das Duas Barras de Progresso para User Stories

## Visão Geral

Esta implementação adiciona duas barras de progresso diferenciadas para cada User Story na tela `/epics`, conforme solicitado:

- **Barra Azul**: Representa tarefas concluídas (`completion_percent_done`)
- **Barra Laranja**: Representa tarefas em progresso (`completion_percent_progress - completion_percent_done`)

## Arquivos Modificados

### 1. Controller (`story-row.controller.coffee`)

**Principais mudanças:**
- Método `_calculateProgressBar()` modificado para calcular duas barras separadas
- Novo método `_createDualProgressSegments()` para criar os segmentos das barras
- Suporte aos campos `completion_percent_done` e `completion_percent_progress` do backend
- Garantia de que a soma nunca ultrapasse 100%

**Campos utilizados:**
```coffeescript
completionDone = @.story.get('completion_percent_done') || 0
completionProgress = @.story.get('completion_percent_progress') || 0
```

### 2. Template (`story-row.jade`)

**Principais mudanças:**
- Remoção do texto de porcentagem centralizado
- Adição de texto individual para cada segmento da barra
- Cada barra exibe sua própria porcentagem

### 3. Estilos (`story-row.scss`)

**Principais mudanças:**
- Estilização dos textos individuais de cada barra (`progress-segment-text`)
- Ajuste do layout para acomodar as duas barras
- Cores definidas: azul (#007ACC) para concluídas, laranja (#FF8C00) para em progresso

### 4. Testes (`story-row.controller.spec.coffee`)

**Principais mudanças:**
- Testes atualizados para verificar `donePercentage` e `progressPercentage` separadamente
- Novos testes para validar o comportamento com os campos do backend
- Teste para garantir que o total não ultrapasse 100%

## Como Funciona

### Cálculo das Barras

1. **User Story Fechada**: Exibe 100% na barra azul
2. **User Story Aberta**: 
   - Usa `completion_percent_done` para a barra azul
   - Calcula a barra laranja como `completion_percent_progress - completion_percent_done`
   - Se os campos específicos não existirem, usa `completion_percent` como fallback para a barra azul

### Validações

- A soma das duas barras nunca ultrapassa 100%
- Valores negativos são convertidos para 0
- Se `completion_percent_progress` for menor que `completion_percent_done`, ajusta automaticamente

### Cores

- **Azul (#007ACC)**: Tarefas concluídas
- **Laranja (#FF8C00)**: Tarefas em progresso
- **Verde (#A8E440)**: User Story completamente fechada

## Exemplo de Uso

Para uma User Story com:
- 4 tarefas totais
- 2 tarefas concluídas (50%)
- 1 tarefa em progresso (25%)

O backend deve retornar:
```json
{
  "completion_percent_done": 50,
  "completion_percent_progress": 75
}
```

Resultado visual:
- Barra azul: 50% (2 tarefas concluídas)
- Barra laranja: 25% (1 tarefa em progresso)
- Total: 75% de progresso

## Compatibilidade

A implementação mantém compatibilidade com:
- User Stories sem os novos campos (usa fallback)
- User Stories fechadas (exibe 100% em verde)
- User Stories sem tarefas (exibe 0%)

## Testes

Execute os testes com:
```bash
npm test -- --grep "StoryRowCtrl"
```

Os testes verificam:
- Cálculo correto das duas barras
- Comportamento com campos do backend
- Validação de limites (não ultrapassar 100%)
- Informações sobre tarefas