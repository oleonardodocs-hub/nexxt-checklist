# Gestão de Mídias Sociais

Sistema para organizar as demandas semanais de cada cliente (posts, artes,
publicações manuais) e acompanhar o andamento em um painel único.

É um site estático (HTML, CSS e JS puro, sem build) que usa o
[Supabase](https://supabase.com) como banco de dados e login. Dá para rodar
local, hospedar no GitHub Pages ou em qualquer outro host de arquivos
estáticos.

## Como o fluxo funciona

Cada cliente tem sempre os mesmos blocos: Datas comemorativas (entregue em
pacote único, sem ciclo semanal) e Segunda a Sexta.

A cada bloco do dia dá para adicionar quantas tarefas forem necessárias
("Subir post feed", "Responder comentários da campanha" etc), cada uma com
um título, uma descrição opcional (o que é e como deve ser feito), tipo de
publicação (agendada ou manual) e o link da arte pronta (o arquivo em si
fica no CRM, aqui só guardamos o link).

O sistema sempre mantém uma semana de folga: existe a semana atual
(validada, é o dia a dia do cliente), a próxima semana (aguardando
validação, a que será apresentada na sexta) e a semana seguinte a essa já
liberada para quem quiser adiantar o preenchimento. Só quem tem o papel de
**validador** pode validar uma semana ou uma tarefa; ao validar a semana, o
sistema libera automaticamente a semana seguinte.

No painel principal fica um "Checklist de hoje", juntando as tarefas do dia
da semana atual de todos os clientes num lugar só, mais um card grande por
cliente com a barra de progresso da semana e alguns números rápidos
(tarefas aguardando validação, publicações manuais do dia).

## Estrutura do projeto

```
index.html          Tela de login
dashboard.html       Painel: checklist de hoje + cards dos clientes
cliente.html         Detalhe de um cliente: semanas e checklist por dia
css/styles.css        Estilos
js/
  config.example.js   Modelo do arquivo de configuração (copiar para config.js)
  supabaseClient.js    Cria o cliente do Supabase usado em todas as páginas
  auth.js              Login, sessão e papel do usuário
  dashboard.js          Lógica do painel
  cliente.js            Lógica da página do cliente
  vendor/supabase.js    Biblioteca supabase-js (copiada localmente, sem depender de CDN externa)
sql/schema.sql        Script para criar as tabelas no Supabase
assets/logo.png        Logo usado como ícone do site
```

## 1. Criar o projeto no Supabase

1. Crie uma conta e um projeto em [supabase.com](https://supabase.com) (o
   plano gratuito atende).
2. No painel do projeto, vá em **SQL Editor**, cole o conteúdo de
   `sql/schema.sql` e rode. Isso cria as tabelas, as permissões (RLS) e as
   travas de validação.
3. Em **Authentication > Providers**, deixe habilitado o login por
   e-mail/senha (é o padrão).
4. Crie os usuários da equipe em **Authentication > Users > Add user**. Ao
   criar, o sistema dá automaticamente o papel "editor" para cada um.
5. Para transformar algum usuário em **validador**, rode no SQL Editor
   (trocando o e-mail):

   ```sql
   update public.profiles
   set role = 'validador'
   where id = (select id from auth.users where email = 'seu-email@exemplo.com');
   ```

## 2. Configurar o projeto

Copie `js/config.example.js` para `js/config.js` e preencha com a URL e a
chave anônima do seu projeto (em **Settings > API** no painel do
Supabase):

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://seu-projeto.supabase.co",
  SUPABASE_ANON_KEY: "sua-anon-key-aqui",
};
```

A chave anônima (anon key) é pública por natureza, ela só funciona dentro
das regras de RLS que já estão no `schema.sql`. Pode subir o `config.js`
junto no GitHub sem problema, é assim que o site hospedado vai saber se
conectar ao seu banco.

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
