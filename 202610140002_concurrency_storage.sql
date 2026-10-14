-- ERP Brasilino: controle otimista de concorrência e documentos privados.
-- Execute depois de 202610140001_initial_schema.sql no SQL Editor do Supabase.

alter table public.erp_records
  add column if not exists version bigint not null default 1;

create index if not exists erp_records_org_updated_idx
  on public.erp_records (organization_id, updated_at desc);

-- Sincronização atômica: ou todos os registros são aplicados, ou nenhum.
-- Cada escrita/exclusão envia o updated_at que o cliente leu. Se alguém já
-- alterou o registro, a função levanta erro e impede sobrescrita silenciosa.
create or replace function public.sync_erp_records(
  p_org uuid,
  p_writes jsonb default '[]'::jsonb,
  p_deletes jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  item jsonb;
  current_stamp timestamptz;
  expected_stamp timestamptz;
  cname text;
  rid text;
  changed integer;
  write_count integer := 0;
  delete_count integer := 0;
begin
  if auth.uid() is null then
    raise exception 'AUTH_REQUIRED: sessão não autenticada';
  end if;
  if not public.can_write_org(p_org) then
    raise exception 'PERMISSION_DENIED: usuário sem permissão de edição nesta organização';
  end if;
  if jsonb_typeof(coalesce(p_writes, '[]'::jsonb)) <> 'array'
     or jsonb_typeof(coalesce(p_deletes, '[]'::jsonb)) <> 'array' then
    raise exception 'INVALID_PAYLOAD: escritas e exclusões devem ser listas';
  end if;

  -- Escritas primeiro. Atualizações com baseline exigem a versão exata.
  for item in select value from jsonb_array_elements(coalesce(p_writes, '[]'::jsonb)) loop
    cname := item->>'collection_name';
    rid := item->>'record_id';
    if cname is null or cname !~ '^[a-zA-Z][a-zA-Z0-9_]{0,79}$'
       or rid is null or length(rid) < 1 or length(rid) > 180
       or jsonb_typeof(item->'payload') is distinct from 'object' then
      raise exception 'INVALID_RECORD: registro inválido';
    end if;

    if nullif(item->>'expected_updated_at', '') is null then
      insert into public.erp_records (organization_id, collection_name, record_id, payload, updated_by, updated_at, version)
      values (p_org, cname, rid, item->'payload', auth.uid(), clock_timestamp(), 1)
      on conflict (organization_id, collection_name, record_id) do nothing;
      get diagnostics changed = row_count;
      if changed = 0 then
        raise exception 'CONFLICT: registro %/% foi criado ou alterado por outro usuário. Recarregue antes de continuar.', cname, rid;
      end if;
    else
      expected_stamp := (item->>'expected_updated_at')::timestamptz;
      update public.erp_records
         set payload = item->'payload', updated_by = auth.uid(), updated_at = clock_timestamp(), version = version + 1
       where organization_id = p_org and collection_name = cname and record_id = rid
         and updated_at = expected_stamp;
      get diagnostics changed = row_count;
      if changed = 0 then
        raise exception 'CONFLICT: registro %/% foi alterado ou removido por outro usuário. Recarregue antes de continuar.', cname, rid;
      end if;
    end if;
    write_count := write_count + 1;
  end loop;

  -- Exclusões também são condicionais à versão lida originalmente.
  for item in select value from jsonb_array_elements(coalesce(p_deletes, '[]'::jsonb)) loop
    cname := item->>'collection_name';
    rid := item->>'record_id';
    if cname is null or rid is null then raise exception 'INVALID_RECORD: exclusão inválida'; end if;
    if nullif(item->>'expected_updated_at', '') is null then
      -- O registro nunca existiu na nuvem; não há exclusão a fazer.
      continue;
    end if;
    expected_stamp := (item->>'expected_updated_at')::timestamptz;
    delete from public.erp_records
     where organization_id = p_org and collection_name = cname and record_id = rid
       and updated_at = expected_stamp;
    get diagnostics changed = row_count;
    if changed = 0 then
      raise exception 'CONFLICT: registro %/% foi alterado ou removido por outro usuário. Recarregue antes de continuar.', cname, rid;
    end if;
    delete_count := delete_count + 1;
  end loop;

  return jsonb_build_object('ok', true, 'writes', write_count, 'deletes', delete_count);
end;
$$;

revoke all on function public.sync_erp_records(uuid, jsonb, jsonb) from public, anon;
grant execute on function public.sync_erp_records(uuid, jsonb, jsonb) to authenticated;

-- Bucket privado: documentos nunca usam URL pública. O cliente recebe links
-- assinados de curta duração depois de passar pelas políticas de Storage.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'erp-documentos', 'erp-documentos', false, 52428800,
  array[
    'image/jpeg','image/png','image/webp','application/pdf',
    'application/msword','application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/zip','application/x-zip-compressed','application/vnd.rar',
    'application/x-rar-compressed','application/x-7z-compressed','application/octet-stream'
  ]
)
on conflict (id) do update set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- O caminho tem o formato: <organization_uuid>/<user_uuid>/<id>_<nome>.
drop policy if exists brasilino_docs_read_member on storage.objects;
create policy brasilino_docs_read_member on storage.objects
  for select to authenticated
  using (
    bucket_id = 'erp-documentos'
    and (storage.foldername(name))[1] is not null
    and public.is_org_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists brasilino_docs_insert_writer on storage.objects;
create policy brasilino_docs_insert_writer on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'erp-documentos'
    and (storage.foldername(name))[1] is not null
    and (storage.foldername(name))[2] = auth.uid()::text
    and public.can_write_org(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists brasilino_docs_update_writer on storage.objects;
create policy brasilino_docs_update_writer on storage.objects
  for update to authenticated
  using (
    bucket_id = 'erp-documentos'
    and (storage.foldername(name))[1] is not null
    and public.can_write_org(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'erp-documentos'
    and (storage.foldername(name))[1] is not null
    and public.can_write_org(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists brasilino_docs_delete_writer on storage.objects;
create policy brasilino_docs_delete_writer on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'erp-documentos'
    and (storage.foldername(name))[1] is not null
    and public.can_write_org(((storage.foldername(name))[1])::uuid)
  );

-- Não use service_role nem senhas administrativas no navegador.
