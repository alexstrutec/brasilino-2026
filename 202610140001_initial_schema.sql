-- ERP Brasilino — estrutura inicial multiempresa/multiusuário.
-- Execute no SQL Editor do Supabase após revisar as políticas.
-- Não contém credenciais e não importa dados locais do navegador.

create extension if not exists pgcrypto;

create table if not exists public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 160),
  created_at timestamptz not null default now()
);

create table if not exists public.user_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','manager','operator','consulta')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);

-- Camada transitória de persistência por registro para permitir migração gradual
-- do ERP atual sem substituir todos os módulos de uma só vez.
create table if not exists public.erp_records (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  collection_name text not null check (collection_name ~ '^[a-zA-Z][a-zA-Z0-9_]{0,79}$'),
  record_id text not null check (length(record_id) between 1 and 180),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  updated_by uuid not null default auth.uid() references auth.users(id),
  updated_at timestamptz not null default now(),
  primary key (organization_id, collection_name, record_id)
);

create index if not exists erp_records_collection_idx
  on public.erp_records (organization_id, collection_name);
create index if not exists erp_records_updated_idx
  on public.erp_records (organization_id, updated_at desc);

create or replace function public.is_org_member(target_org uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = target_org
      and m.user_id = auth.uid()
      and m.active = true
  );
$$;

create or replace function public.can_write_org(target_org uuid)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.organization_members m
    where m.organization_id = target_org
      and m.user_id = auth.uid()
      and m.active = true
      and m.role in ('admin','manager','operator')
  );
$$;

revoke all on function public.is_org_member(uuid) from public;
revoke all on function public.can_write_org(uuid) from public;
grant execute on function public.is_org_member(uuid) to authenticated;
grant execute on function public.can_write_org(uuid) to authenticated;

grant select on public.organizations to authenticated;
grant select on public.user_profiles to authenticated;
grant select on public.organization_members to authenticated;
grant select, insert, update, delete on public.erp_records to authenticated;

alter table public.organizations enable row level security;
alter table public.user_profiles enable row level security;
alter table public.organization_members enable row level security;
alter table public.erp_records enable row level security;

drop policy if exists organizations_read_member on public.organizations;
create policy organizations_read_member on public.organizations
  for select to authenticated using (public.is_org_member(id));

drop policy if exists profiles_read_self on public.user_profiles;
create policy profiles_read_self on public.user_profiles
  for select to authenticated using (user_id = auth.uid());

-- Membros só podem consultar a própria associação. A criação de associações
-- administrativas deve ser feita por procedimento administrativo confiável.
drop policy if exists memberships_read_self on public.organization_members;
create policy memberships_read_self on public.organization_members
  for select to authenticated using (user_id = auth.uid());

drop policy if exists records_read_member on public.erp_records;
create policy records_read_member on public.erp_records
  for select to authenticated using (public.is_org_member(organization_id));

drop policy if exists records_insert_writer on public.erp_records;
create policy records_insert_writer on public.erp_records
  for insert to authenticated with check (
    public.can_write_org(organization_id) and updated_by = auth.uid()
  );

drop policy if exists records_update_writer on public.erp_records;
create policy records_update_writer on public.erp_records
  for update to authenticated using (public.can_write_org(organization_id))
  with check (public.can_write_org(organization_id) and updated_by = auth.uid());

drop policy if exists records_delete_writer on public.erp_records;
create policy records_delete_writer on public.erp_records
  for delete to authenticated using (public.can_write_org(organization_id));

-- Atenção: a integração do HTML com estas tabelas ainda precisa ser implementada
-- e validada. Não crie usuários administradores no cliente/browser.
