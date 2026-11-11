-- Sistema de Gestão de Mídias Sociais
-- Schema para Supabase (Postgres + Auth + RLS)
-- Rode este arquivo inteiro no SQL Editor do seu projeto Supabase.

-- ============================================================
-- EXTENSÕES
-- ============================================================
create extension if not exists "pgcrypto";

-- ============================================================
-- PROFILES (papéis de acesso: editor ou validador)
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nome text not null,
  role text not null default 'editor' check (role in ('editor', 'validador')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_all_autenticados"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_update_proprio"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id);

-- cria automaticamente um profile (papel "editor") quando um usuário se cadastra
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, nome, role)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nome', new.email), 'editor');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- CLIENTS
-- ============================================================
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  cor text not null default '#2a78d6', -- cor de identidade do card no dashboard
  ativo boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.clients enable row level security;

create policy "clients_select_all_autenticados"
  on public.clients for select
  to authenticated
  using (true);

create policy "clients_insert_autenticados"
  on public.clients for insert
  to authenticated
  with check (true);

create policy "clients_update_autenticados"
  on public.clients for update
  to authenticated
  using (true);

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
  semana_inicio date not null, -- sempre uma segunda-feira
  status text not null default 'disponivel'
    check (status in ('disponivel', 'aguardando_validacao', 'validada', 'concluida')),
  validada_por uuid references public.profiles (id),
  validada_em timestamptz,
  created_at timestamptz not null default now(),
  unique (client_id, semana_inicio)
);

alter table public.weeks enable row level security;

create policy "weeks_select_all_autenticados"
  on public.weeks for select
  to authenticated
  using (true);

create policy "weeks_insert_autenticados"
  on public.weeks for insert
  to authenticated
  with check (true);

create policy "weeks_update_autenticados"
  on public.weeks for update
  to authenticated
  using (true);

-- trava: só quem tem role "validador" pode mudar o status da semana para "validada"
create or replace function public.check_validacao_semana()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  papel text;
begin
  if new.status = 'validada' and (old.status is distinct from 'validada') then
    select role into papel from public.profiles where id = auth.uid();
    if papel is distinct from 'validador' then
      raise exception 'Somente usuários com papel "validador" podem validar uma semana.';
    end if;
    new.validada_por := auth.uid();
    new.validada_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_validacao_semana on public.weeks;
create trigger trg_check_validacao_semana
  before update on public.weeks
  for each row execute procedure public.check_validacao_semana();

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
  week_id uuid references public.weeks (id) on delete cascade, -- nulo quando bloco = datas_comemorativas
  bloco text not null
    check (bloco in ('datas_comemorativas', 'segunda', 'terca', 'quarta', 'quinta', 'sexta')),
  titulo text not null,
  descricao text,
  link text, -- link da arte/post pronto no CRM (não guardamos arquivo aqui)
  tipo_publicacao text not null default 'agendada'
    check (tipo_publicacao in ('agendada', 'manual')),
  data_publicacao date,
  hora_publicacao time,
  prazo_pacote date, -- usado só pelo bloco datas_comemorativas (entrega em pacote único)
  status text not null default 'pendente'
    check (status in (
      'pendente', 'em_producao', 'aguardando_validacao',
      'validada', 'agendada', 'manual_pendente', 'publicada'
    )),
  validada_por uuid references public.profiles (id),
  validada_em timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.demandas enable row level security;

create policy "demandas_select_all_autenticados"
  on public.demandas for select
  to authenticated
  using (true);

create policy "demandas_insert_autenticados"
  on public.demandas for insert
  to authenticated
  with check (true);

create policy "demandas_update_autenticados"
  on public.demandas for update
  to authenticated
  using (true);

create policy "demandas_delete_autenticados"
  on public.demandas for delete
  to authenticated
  using (true);

-- trava: só "validador" pode mover uma demanda para o status "validada"
create or replace function public.check_validacao_demanda()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  papel text;
begin
  new.updated_at := now();
  if new.status = 'validada' and (old.status is distinct from 'validada') then
    select role into papel from public.profiles where id = auth.uid();
    if papel is distinct from 'validador' then
      raise exception 'Somente usuários com papel "validador" podem validar uma demanda.';
    end if;
    new.validada_por := auth.uid();
    new.validada_em := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_check_validacao_demanda on public.demandas;
create trigger trg_check_validacao_demanda
  before update on public.demandas
  for each row execute procedure public.check_validacao_demanda();

-- ============================================================
-- Índices úteis
-- ============================================================
create index if not exists idx_weeks_client on public.weeks (client_id, semana_inicio);
create index if not exists idx_demandas_client on public.demandas (client_id);
create index if not exists idx_demandas_week on public.demandas (week_id);
create index if not exists idx_demandas_status on public.demandas (status);
