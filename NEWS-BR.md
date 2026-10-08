# Novidades deste fork do Taiga

Este repositório é um fork do [Taiga 6.8](https://taiga.io), mantido pelo Centro de Tecnologias Aplicadas da Itaipu Parquetec, um centro de tecnologia no Brasil que usa o Taiga para gerir os seus projetos de software e de IoT. O código original é da [Kaleidos e do projeto taigaio](https://github.com/taigaio), a quem agradecemos; este fork continua sob a licença AGPL-3, com os créditos preservados.

Partimos do Taiga porque ele resolve bem o dia a dia ágil. Adaptamos algumas coisas para a gestão de portfólio da instituição: 
* Divisão da tela de login para contemplar login corporativo;
* A épica passa a exibir o avanço concluído e progresso;
* Percentual de avanço nas tarefas para contemplar progresso em histórias e épicas;
* dependência entre os cards;
* Datas de inicio, previsão de termino e termino efetivo em épicas e projetos.
* Percentual de planejamento e impacto em épicas, fotografada uma vez ao mês;
* Definição de Story Points;
* T·IA: nossa agente inteligente;
* Reação com Emojis.

Este documento lista, em tópicos, o que foi acrescentado. Ele acompanha o repositório do front; o do back ([taiga-back](https://github.com/ta-iot/taiga-back)) traz um resumo e aponta para cá.

Regras que orientam tudo o que foi feito: o servidor decide (percentual, bloqueio, permissão e datas são calculados e validados no back-end; a interface só reflete); o percentual é calculado, nunca digitado; um card bloqueado por relação não conclui nem é excluído até a relação ser resolvida.

## O que este fork acrescenta

### Épicas e progresso

- **Progresso parcial por status de tarefa.** O administrador do projeto define, para cada status de tarefa, um peso de 0 a 100 (ou vazio). Status fechado vale 100; um status aberto com 100 é gravado como 99 pelo servidor, para que só o fechamento conte como concluído.
- **Percentual calculado da tarefa até a épica.** Cada tarefa, história e épica mostra dois percentuais, concluído e em progresso, calculados no servidor: a tarefa pelo seu status, a história pela média das tarefas, a épica pela média das histórias. Criar, mover ou excluir cards recalcula em cascata; nenhum percentual é editável pela API.
- **Datas na épica.** Toda épica tem data de início e data fim prevista obrigatórias; a data de conclusão aparece sozinha quando a épica é fechada. Fim anterior ao início é recusado pelo servidor. A listagem de épicas ganhou as colunas de datas e a barra de progresso com números.
- **Cronograma de épicas com fotografia mensal.** Um menu do projeto mostra a evolução mês a mês do percentual concluído, sendo épicas planejadas e não planejadas. Épicas planejadas tem um teto de 100% no somatório, já não planejadas é indefinido. O administrador marca quais épicas entram no cronograma e o impacto de cada uma. Um comando do servidor grava uma fotografia mensal de cada épica; meses passados nunca são reescritos.

### Relacionamento entre cards

- **Dependências entre atividades.** Issues, tarefas, histórias e épicas do mesmo projeto se relacionam com tipos fixos: relacionada a; bloqueia / bloqueado por; depende de / depende de mim; duplicada por / duplicado de; descoberta ao testar / levou a descobrir ao testar. Um card não se relaciona consigo mesmo, cada combinação só tem uma relação ativa, e toda criação, alteração, resolução e exclusão entra no histórico dos dois cards. A permissão é por papel; a API cobre criar, listar, resolver e excluir.
- **Bloqueio com efeito real.** Um card bloqueado por relação fica marcado nos quadros, não pode ir para um status fechado (o servidor recusa e a interface devolve o card à coluna de origem) e não pode ser excluído enquanto a relação não for marcada como resolvida. O cadeado original do Taiga não desfaz um bloqueio criado por relação.

### Comentários

- **Reações com emoji.** Membros do projeto reagem aos comentários de épicas, histórias, tarefas e issues; cada comentário mostra os emojis com a contagem e quem reagiu. Uma reação por emoji por pessoa; só quem reagiu a remove; quem não é do projeto recebe 403.

### Sprint e quadros

- **Totalizadores e percentuais no quadro de sprint.** Cada coluna mostra o total de tarefas e o percentual do status; coluna recolhida mostra o total por história; os cards exibem o progresso parcial. Vieram junto: botão para limpar filtros, coluna e filtro de sprint na listagem de issues, campo personalizado de caixa de seleção com salvamento automático, data de fechamento no gráfico de sprint e um botão para encerrar a sprint mais rápido.
- **Tarefa não troca de história por arraste.** No quadro de sprint, soltar uma tarefa na linha de outra história é bloqueado e a tarefa volta à origem, com aviso traduzido. Trocar a história continua possível pelo detalhe da tarefa, onde fica registrado.

### Projeto e identidade

- **Datas do projeto.** O projeto tem data de início, de término previsto e de término, editadas nas configurações e exibidas na timeline (com tempo decorrido e tempo restante) e na listagem de projetos. Término anterior ao início é recusado pelo servidor.
- **Listagem de projetos com status e datas** direto na tela, sem abrir cada projeto.
- **Criação de projeto restrita.** Só administradores e superusuários criam projetos; o projeto nasce privado; os ícones de editar e excluir status só aparecem para administrador do projeto. O servidor recusa quem não tem permissão.
- **Identidade própria.** Logo e favicon institucionais em todas as telas e e-mails; uma tag visual identifica os ambientes de testes e homologação e nunca aparece em produção.
- **Idioma padrão pt-BR, com EN e ES.** A interface abre em português do Brasil, todo texto novo existe nos três idiomas e os textos herdados foram revisados.

### Acesso

- **Login com dois caminhos.** A tela de login tem as abas Corporativo e Externo. Conta corporativa autentica no diretório institucional (LDAP) e a ferramenta não guarda essa credencial; conta externa autentica com credencial local. As duas abas passam pelo reCAPTCHA quando ele está ativo, e cada caminho recusa o tipo de conta do outro.
- **Conta corporativa gerida pelo diretório.** Usuário corporativo não altera e-mail nem credencial de acesso na ferramenta; o servidor recusa mesmo quem contorna a interface. Usuário externo altera os dois.

### O que a versão mais recente entregou (home, carrossel, guia e rodapé)

- **Home pública traduzida, com seletor de idioma.** A página inicial para quem não está autenticado apresenta a instância e as suas funcionalidades no idioma do navegador;
- **Carrossel de novidades administrável.** As novidades da home podem ser adicionadas pelo administrador através de uma interface presente no header (ao lado dos story-points);
- **Guia de story points.** Uma rota pública mostra a escala de pontuação da equipe (Fibonacci), com exemplos por pontuação e um atalho no cabeçalho; a tradução do guia foi completada nos três idiomas.
- **Rodapé** na home e a tela de login, contém um rodapé com as logos institucionais.

## Por que não há descoberta de projetos

A página "Descobrir" (Discover) do Taiga foi retirada da interface. Nesta instância todo projeto nasce privado e não existem projetos públicos, então a página ficaria sempre vazia. Quem instalar o fork e quiser projetos públicos pode reativar os atalhos de descoberta na barra de navegação: a rota e a API continuam no código.

## Como o carrossel funciona para quem instala

O carrossel de novidades da home nasce vazio em qualquer instalação: não há dados de exemplo nem carga inicial. Um admin cadastra os slides (imagem, título, descrição e ordem) numa tela de gestão acessível por um ícone no cabeçalho, ativa os que quer publicar e os reordena. A leitura é pública: a home mostra só os slides ativos, na ordem gravada, e, quando não há slide ativo ou o servidor não responde, o espaço fica oculto. Limites validados no servidor: título até 255 caracteres, descrição até 500, imagem até 2 MB e só formatos de imagem reconhecidos.

## Nota sobre acesso corporativo

O login pelo diretório institucional (LDAP), e o reCAPTCHA são específicos desta instalação e configuráveis em quem instala o fork. O comportamento é o descrito acima: a aba corporativa valida o usuário no diretório sem guardar a credencial na ferramenta, a aba externa usa credencial local, e ambas exigem a verificação do reCAPTCHA quando ele está ligado. Sem diretório configurado, o fork se comporta como o Taiga original para contas locais.
