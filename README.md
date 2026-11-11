# Gestão de Mídias Sociais

Sistema para organizar as demandas semanais de cada cliente (posts, artes,
publicações manuais) e acompanhar o andamento em um painel único.

É um site estático (HTML, CSS e JS puro, sem build) que usa o
[Supabase](https://supabase.com) só como banco de dados (não usa login
individual). Dá para rodar local, hospedar no GitHub Pages ou em qualquer
outro host de arquivos estáticos.

## Acesso

Não tem cadastro nem login por e-mail. A entrada é liberada por uma única
senha de equipe, configurada em `js/config.js` (`TEAM_PASSWORD`). Quem digita
certo uma vez fica liberado naquele navegador.

**Importante:** como o site é só HTML/JS estático hospedado no GitHub Pages,
essa senha fica visível pra quem souber olhar o código da página (ela não é
criptografada nem validada num servidor). Ela serve só pra barrar quem cair
no link sem querer, não é uma proteção de verdade contra alguém
mal-intencionado. Pelo mesmo motivo as regras do banco (RLS, no
`schema.sql`) liberam leitura e escrita pra qualquer um que tenha a chave
pública do projeto, então não guarde ali nada que não possa vazar.

## Como o fluxo funciona

Cada cliente tem sempre os mesmos blocos: Datas comemorativas (entregue em
pacote único, sem ciclo semanal) e Segunda a Sexta.

A cada bloco do dia dá para adicionar quantas tarefas forem necessárias
("Subir post feed", "Responder comentários da campanha" etc), cada uma com
um título, uma descrição opcional (o que é e como deve ser feito), tipo de
publicação (agendada ou manual), um responsável (ver "Equipe" abaixo) e o
link da arte pronta (o arquivo em si fica no CRM, aqui só guardamos o link).

O sistema sempre mantém uma semana de folga: existe a semana atual
(validada, é o dia a dia do cliente), a próxima semana (aguardando
validação, a que será apresentada na sexta) e a semana seguinte a essa já
liberada para quem quiser adiantar o preenchimento. Ao validar a semana, o
sistema libera automaticamente a semana seguinte.

No painel principal fica a saudação do dia com um calendário do mês, o
"Checklist de hoje" (juntando as tarefas do dia de todos os clientes num
lugar só) e um card grande por cliente com a barra de progresso da semana e
alguns números rápidos (tarefas aguardando validação, publicações manuais do
dia).

## Equipe (colaboradores)

Na página "Equipe" (link no topo de qualquer tela) dá para cadastrar os
colaboradores da agência (nome + função, ex: "Mariana, Social Media"). Eles
aparecem como opção de **Responsável** em cada tarefa, tanto ao criar quanto
para reatribuir depois, direto no checklist do cliente.

## Estrutura do projeto

```
index.html            Tela de entrada (senha única da equipe)
dashboard.html         Painel: agenda, checklist de hoje, cards dos clientes
cliente.html           Detalhe de um cliente: semanas e checklist por dia
colaboradores.html     Cadastro da equipe (nome + função)
css/styles.css          Estilos
js/
  config.example.js     Modelo do arquivo de configuração (copiar para config.js)
  supabaseClient.js      Cria o cliente do Supabase usado em todas as páginas
  auth.js                Controle de acesso (senha única) e ações do topo
  dashboard.js            Lógica do painel
  cliente.js              Lógica da página do cliente
  colaboradores.js        Lógica do cadastro de equipe
  vendor/supabase.js      Biblioteca supabase-js (copiada localmente, sem depender de CDN externa)
sql/schema.sql          Script para criar as tabelas no Supabase
assets/logo.png          Logo usado como ícone do site
```

## 1. Criar o projeto no Supabase

1. Crie uma conta e um projeto em [supabase.com](https://supabase.com) (o
   plano gratuito atende).
2. No painel do projeto, vá em **SQL Editor**, cole o conteúdo de
   `sql/schema.sql` e rode. Isso cria as tabelas e as permissões (RLS). Se
   você já tinha rodado a versão anterior deste sistema (com login por
   e-mail/senha), pode rodar esse mesmo script de novo sem problema: ele
   limpa o que não é mais usado antes de criar o que falta.

## 2. Configurar o projeto

Copie `js/config.example.js` para `js/config.js` e preencha com a URL e a
chave anônima do seu projeto (em **Settings > API** no painel do Supabase) e
a senha de acesso da equipe:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://seu-projeto.supabase.co",
  SUPABASE_ANON_KEY: "sua-anon-key-aqui",
  TEAM_PASSWORD: "Socio26@@",
};
```

Pode subir o `config.js` junto no GitHub sem problema (ver a nota de
segurança no início deste README), é assim que o site hospedado vai saber
se conectar ao seu banco e qual senha aceitar.

## 3. Rodar local

Qualquer servidor de arquivos estáticos serve. Exemplo com Python, dentro
da pasta do projeto:

```bash
python3 -m http.server 8080
```

Depois abra `http://localhost:8080`.

## 4. Subir no GitHub e publicar no GitHub Pages

O projeto já vem com o git iniciado e o primeiro commit feito. Só falta
criar um repositório vazio no GitHub e apontar para ele:

```bash
git remote add origin https://github.com/SEU-USUARIO/SEU-REPOSITORIO.git
git push -u origin main
```

(Se você já adicionou/alterou algum arquivo, como o `js/config.js`, rode
`git add .` e `git commit -m "configura supabase"` antes do `git push`.)

Depois, no repositório no GitHub: **Settings > Pages**, em "Build and
deployment" escolha "Deploy from a branch", branch `main`, pasta `/ (root)`.
Em alguns minutos o site fica disponível em
`https://SEU-USUARIO.github.io/SEU-REPOSITORIO/`.

## Adicionando clientes

Pelo próprio painel, no botão "+ Novo cliente" (nome e uma cor para
identificar o card). Ao abrir um cliente pela primeira vez, o sistema já
cria sozinho a semana atual e a próxima, prontas para preencher.
