-- Sistema de Gestão de Mídias Sociais
-- Schema para Supabase (Postgres)
-- Rode este arquivo inteiro no SQL Editor do seu projeto Supabase.
--
-- Este sistema NÃO usa login individual (Supabase Auth). O acesso ao site é
-- liberado por uma senha única da equipe, verificada no próprio navegador
-- (configurada em js/config.js). Por isso as tabelas abaixo liberam leitura
-- e escrita para qualquer requisição que use a chave anônima do projeto
-- (a mesma chave que já fica em js/config.js).
--
-- IMPORTANTE: como não há login real, essa senha é só uma barreira contra
-- quem cair no link por acaso, não é segurança de verdade. Não guarde
-- neste banco nada que não possa vazar.
--
-- Este script pode ser rodado tanto num projeto novo quanto num projeto
-- que já tinha a versão anterior (com login por e-mail/senha): ele limpa
-- o que não é mais usado antes de seguir.

create extension if not exists "pgcrypto";

-- ============================================================
-- LIMPEZA da versão anterior (login individual via Supabase Auth)
-- ============================================================
drop trigger if exists on_auth_user_created on auth.users;
drop function if exists public.handle_new_user();
drop trigger if exists trg_check_validacao_semana on public.weeks;
drop function if exists public.check_validacao_semana();
drop trigger if exists trg_check_validacao_demanda on public.demandas;
drop function if exists public.check_validacao_demanda();
drop table if exists public.profiles cascade;

do $$
begin
  if to_regclass('public.clients') is not null then
    drop policy if exists "clients_select_all_autenticados" on public.clients;
    drop policy if exists "clients_insert_autenticados" on public.clients;
    drop policy if exists "clients_update_autenticados" on public.clients;
  end if;
  if to_regclass('public.weeks') is not null then
    drop policy if exists "weeks_select_all_autenticados" on public.weeks;
    drop policy if exists "weeks_insert_autenticados" on public.weeks;
    drop policy if exists "weeks_update_autenticados" on public.weeks;
    alter table public.weeks drop column if exists validada_por;
  end if;
  if to_regclass('public.demandas') is not null then
    drop policy if exists "demandas_select_all_autenticados" on public.demandas;
    drop policy if exists "demandas_insert_autenticados" on public.demandas;
    drop policy if exists "demandas_update_autenticados" on public.demandas;
    drop policy if exists "demandas_delete_autenticados" on public.demandas;
    alter table public.demandas drop column if exists validada_por;
  end if;
end $$;

-- ============================================================
-- COLABORADORES (equipe: nome + função, usado para marcar o
-- responsável de cada tarefa)
-- ============================================================
create table if not exists public.colaboradores (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  funcao text,
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.colaboradores enable row level security;

drop policy if exists "colaboradores_select_publico" on public.colaboradores;
drop policy if exists "colaboradores_insert_publico" on public.colaboradores;
drop policy if exists "colaboradores_update_publico" on public.colaboradores;
drop policy if exists "colaboradores_delete_publico" on public.colaboradores;

create policy "colaboradores_select_publico" on public.colaboradores for select to anon, authenticated using (true);
create policy "colaboradores_insert_publico" on public.colaboradores for insert to anon, authenticated with check (true);
create policy "colaboradores_update_publico" on public.colaboradores for update to anon, authenticated using (true);
create policy "colaboradores_delete_publico" on public.colaboradores for delete to anon, authenticated using (true);

-- ============================================================
-- CLIENTS
-- ============================================================
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  cor text not null default '#6250d6',
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.clients enable row level security;

drop policy if exists "clients_select_publico" on public.clients;
drop policy if exists "clients_insert_publico" on public.clients;
drop policy if exists "clients_update_publico" on public.clients;

create policy "clients_select_publico" on public.clients for select to anon, authenticated using (true);
create policy "clients_insert_publico" on public.clients for insert to anon, authenticated with check (true);
create policy "clients_update_publico" on public.clients for update to anon, authenticated using (true);

-- ============================================================
-- WEEKS (ciclo semanal de cada cliente)
-- status:
--   disponivel            -> semana seguinte liberada para adiantar o preenchimento
--   aguardando_validacao  -> semana que será apresentada/validada na sexta
--   validada              -> aprovada, vira o dia a dia do card do cliente
--   concluida             -> todos os itens já publicados, semana arquivada
-- ============================================================
create table if not exists public.weeks (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  semana_inicio date not null,
  status text not null default 'disponivel'
    check (status in ('disponivel', 'aguardando_validacao', 'validada', 'concluida')),
  validada_em timestamptz,
  created_at timestamptz not null default now(),
  unique (client_id, semana_inicio)
);

alter table public.weeks enable row level security;

drop policy if exists "weeks_select_publico" on public.weeks;
drop policy if exists "weeks_insert_publico" on public.weeks;
drop policy if exists "weeks_update_publico" on public.weeks;

create policy "weeks_select_publico" on public.weeks for select to anon, authenticated using (true);
create policy "weeks_insert_publico" on public.weeks for insert to anon, authenticated with check (true);
create policy "weeks_update_publico" on public.weeks for update to anon, authenticated using (true);

create or replace function public.carimbar_validacao_semana()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'validada' and (old.status is distinct from 'validada') then
    new.validada_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_carimbar_validacao_semana on public.weeks;
create trigger trg_carimbar_validacao_semana
  before update on public.weeks
  for each row execute procedure public.carimbar_validacao_semana();

-- ============================================================
-- DEMANDAS (itens individuais: posts, artes, vídeos...)
-- bloco: datas_comemorativas | segunda | terca | quarta | quinta | sexta
-- tipo_publicacao: agendada (vai programada) | manual (precisa subir na mão no dia)
-- status:
--   pendente              -> ainda não entrou em produção
--   em_producao           -> em produção
--   aguardando_validacao  -> pronta, esperando validação de sexta
--   validada              -> validada, pronta para agendar/publicar
--   agendada              -> já programada na ferramenta de publicação
--   manual_pendente       -> validada, mas precisa ser publicada manualmente no dia
--   publicada             -> já está no ar
-- ============================================================
create table if not exists public.demandas (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  week_id uuid references public.weeks (id) on delete cascade,
  responsavel_id uuid references public.colaboradores (id) on delete set null,
  bloco text not null
    check (bloco in ('datas_comemorativas', 'segunda', 'terca', 'quarta', 'quinta', 'sexta')),
  titulo text not null,
  descricao text,
  link text,
  tipo_publicacao text not null default 'agendada'
    check (tipo_publicacao in ('agendada', 'manual')),
  data_publicacao date,
  hora_publicacao time,
  prazo_pacote date,
  status text not null default 'pendente'
    check (status in (
      'pendente', 'em_producao', 'aguardando_validacao',
      'validada', 'agendada', 'manual_pendente', 'publicada'
    )),
  validada_em timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- se a tabela já existia (versão anterior), garante a coluna nova
alter table public.demandas add column if not exists responsavel_id uuid references public.colaboradores (id) on delete set null;

alter table public.demandas enable row level security;

drop policy if exists "demandas_select_publico" on public.demandas;
drop policy if exists "demandas_insert_publico" on public.demandas;
drop policy if exists "demandas_update_publico" on public.demandas;
drop policy if exists "demandas_delete_publico" on public.demandas;

create policy "demandas_select_publico" on public.demandas for select to anon, authenticated using (true);
create policy "demandas_insert_publico" on public.demandas for insert to anon, authenticated with check (true);
create policy "demandas_update_publico" on public.demandas for update to anon, authenticated using (true);
create policy "demandas_delete_publico" on public.demandas for delete to anon, authenticated using (true);

create or replace function public.carimbar_validacao_demanda()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  if new.status = 'validada' and (old.status is distinct from 'validada') then
    new.validada_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_carimbar_validacao_demanda on public.demandas;
create trigger trg_carimbar_validacao_demanda
  before update on public.demandas
  for each row execute procedure public.carimbar_validacao_demanda();

-- ============================================================
-- Índices úteis
-- ============================================================
create index if not exists idx_weeks_client on public.weeks (client_id, semana_inicio);
create index if not exists idx_demandas_client on public.demandas (client_id);
create index if not exists idx_demandas_week on public.demandas (week_id);
create index if not exists idx_demandas_status on public.demandas (status);
create index if not exists idx_demandas_responsavel on public.demandas (responsavel_id);
