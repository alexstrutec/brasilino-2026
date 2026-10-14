# Configuração administrativa — ERP Brasilino

## 1. Aplicar as migrações

No Supabase correto, abra **SQL Editor** e execute na ordem:

1. `migrations/202610140001_initial_schema.sql`
2. `migrations/202610140002_concurrency_storage.sql`

A segunda migração adiciona sincronização transacional com controle de concorrência e cria o bucket privado `erp-documentos` com políticas de acesso.

## 2. Configurar autenticação

1. Em **Authentication → Providers**, habilite e-mail/senha.
2. Em **Authentication → URL Configuration**, cadastre a URL publicada do ERP como Site URL e Redirect URL.
3. Para uso interno, mantenha o cadastro público desabilitado. Crie cada funcionário em **Authentication → Users**.
4. Copie o UUID de cada usuário.

## 3. Criar organização e vincular o primeiro administrador

Execute no SQL Editor como administrador do projeto. Substitua os valores antes de executar:

```sql
insert into public.organizations (name)
values ('Brasilino Produtos Metalúrgicos')
returning id;
```

Copie o `id` retornado e o UUID do usuário do Auth:

```sql
insert into public.user_profiles (user_id, full_name)
values ('UUID-DO-USUARIO', 'Administrador Brasilino')
on conflict (user_id) do update set full_name = excluded.full_name;

insert into public.organization_members (organization_id, user_id, role, active)
values ('UUID-DA-ORGANIZACAO', 'UUID-DO-USUARIO', 'admin', true)
on conflict (organization_id, user_id)
do update set role = excluded.role, active = true;
```

Repita o vínculo para cada funcionário usando `manager`, `operator` ou `consulta`. A role `consulta` deve ser somente leitura.

## 4. Configurar o HTML

No início de `index.html`, preencha apenas a URL e a chave pública Publishable:

```js
window.BRASILINO_SUPABASE_CONFIG = {
  url: 'https://SEU-PROJETO.supabase.co',
  publishableKey: 'sb_publishable_SUA_CHAVE_PUBLICA'
};
```

Nunca coloque `service_role`, `sb_secret`, senha do banco ou tokens administrativos no HTML, GitHub ou navegador. A chave Publishable é pública; a segurança depende de Auth e RLS.

## 5. Documentos

O bucket `erp-documentos` é privado. O HTML faz upload dos arquivos e salva no cadastro apenas os metadados e o caminho do objeto. Para abrir/baixar, gera URL assinada com validade curta. O limite configurado é 50 MB por arquivo e os formatos aceitos são os previstos na migração.

Arquivos anexados ainda não salvos em um cadastro podem ficar órfãos se o usuário cancelar o formulário. Faça revisão/limpeza administrativa do bucket antes de considerar o processo operacional definitivo.

## 6. Importante

- O banco deve começar vazio; o HTML não migra automaticamente dados locais.
- Não é necessário expor chaves administrativas para o navegador.
- Não considere a implantação pronta até completar `TESTES_INTEGRACAO.md` em dois usuários e dois navegadores.
