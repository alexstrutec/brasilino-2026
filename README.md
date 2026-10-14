# ERP Brasilino — pacote de correções iniciais

## O que foi corrigido nesta entrega

- Corrigida uma regra CSS sem seletor no editor de propostas.
- Adicionado aviso explícito na tela de login de que a versão atual opera em modo local e não compartilha dados entre computadores.
- Preservado o HTML original como base; nenhum módulo foi removido.
- Incluída uma migração SQL inicial para organizações, perfis, associação de usuários, registros por coleção e políticas RLS.
- Incluído workflow de publicação no GitHub Pages para a branch `main`.

## Limitação importante

**A integração do HTML inclui login Supabase, sincronização via RPC com controle otimista de concorrência e upload para bucket privado. Ela ainda não foi validada contra um projeto real nesta entrega.** O modo local continua disponível quando URL/chave não estão preenchidas; ao configurar as duas, o login remoto é obrigatório. A camada remota usa a tabela JSONB `erp_records` como ponte temporária. Não use como produção até concluir os testes de autenticação, RLS, concorrência e sincronização descritos em `TESTES_INTEGRACAO.md`.

O banco deve começar vazio. Não importe automaticamente dados de `localStorage`.

## Publicar no repositório

Repositório pretendido: <https://github.com/alexstrutec/brasilino-df>

1. Faça backup do repositório e do HTML atual.
2. Copie `index.html`, `.github/workflows/pages.yml` e a pasta `supabase/` para a raiz do repositório.
3. Faça commit e push para a branch `main`.
4. No GitHub, abra **Settings → Pages** e selecione publicação por **GitHub Actions**, se ainda não estiver selecionado.
5. Abra **Actions** e confirme que o workflow terminou com sucesso.
6. Acesse a URL publicada exibida pelo GitHub e teste em janela anônima e celular.

A publicação é apenas de arquivos estáticos; não cria a conexão com Supabase.

## Ativar a integração Supabase no HTML

No começo do `index.html`, localize `window.BRASILINO_SUPABASE_CONFIG` e preencha somente estes dois campos com os valores do seu projeto:

```js
window.BRASILINO_SUPABASE_CONFIG = {
  url: 'https://SEU-PROJETO.supabase.co',
  publishableKey: 'sb_publishable_SUA_CHAVE_PUBLICA'
};
```

Use a URL real do projeto e a chave pública Publishable. Não coloque `service_role`, `sb_secret`, senha do banco nem token administrativo no HTML ou no GitHub. Quando as credenciais forem preenchidas, o sistema passa a exigir login pelo Supabase Auth; não usa o login local como alternativa silenciosa.

## Configurar a base Supabase

1. Abra o projeto Supabase correto.
2. Entre em **SQL Editor**.
3. Revise e execute `supabase/migrations/202610140001_initial_schema.sql` e `supabase/migrations/202610140002_concurrency_storage.sql`.
4. Configure o provedor de autenticação por e-mail/senha em **Authentication**.
5. Crie usuários pelo painel administrativo do Supabase; não permita que o navegador conceda privilégios administrativos.
6. Crie a organização e as associações de membros por um procedimento administrativo confiável. Não exponha a chave `service_role` no HTML.

A migração cria uma camada inicial `erp_records` com isolamento por organização. O HTML usa a tabela transitória `erp_records` para sincronizar os módulos atuais. O funcionamento real depende de aplicar as duas migrações, configurar a URL/chave pública e concluir os testes multiusuário.

## Testes desta entrega

- [ ] Validar login remoto, carregamento e gravação com credenciais reais.
- [ ] Validar RPC transacional e rejeição de conflito com dois usuários simultâneos.
- [ ] Validar RLS para usuário de consulta e usuário de outra organização.
- [ ] Validar upload/download/exclusão no bucket privado em dois navegadores.
- [ ] Exportações PDF/Word, cálculos e fluxos operacionais — não fazem parte do teste estático desta etapa.

## Segurança

- Nunca coloque senha do banco, `service_role`, `sb_secret` ou tokens administrativos em HTML, JavaScript ou GitHub.
- A chave pública do Supabase pode aparecer no frontend, mas somente com RLS corretamente configurada.
- Não considere `localStorage` nem o controle visual dos menus uma fronteira de segurança.
- Antes de uso real, revise o esquema com os campos relacionais definitivos dos módulos e faça testes negativos de RLS.


## Criar a primeira organização e vincular usuários

1. Crie os usuários em **Supabase → Authentication → Users** (desative cadastro público se a plataforma for exclusiva da empresa).
2. Copie o UUID do usuário administrador.
3. No **SQL Editor**, execute o modelo abaixo substituindo o nome da organização e o UUID. Execute como administrador do projeto, nunca no navegador:

```sql
insert into public.organizations (name)
values ('Brasilino Produtos Metalúrgicos')
returning id;
```

Copie o `id` retornado e use-o e o UUID do usuário no comando abaixo:

```sql
insert into public.user_profiles (user_id, full_name)
values ('UUID-DO-USUARIO', 'Administrador Brasilino')
on conflict (user_id) do update set full_name = excluded.full_name;

insert into public.organization_members (organization_id, user_id, role, active)
values ('UUID-DA-ORGANIZACAO', 'UUID-DO-USUARIO', 'admin', true)
on conflict (organization_id, user_id)
do update set role = excluded.role, active = true;
```

Para outros funcionários, crie a conta no Auth e associe o UUID à mesma organização com o papel `manager`, `operator` ou `consulta`. A política RLS autoriza leitura a membros ativos e escrita a `admin`, `manager` e `operator`; `consulta` deve ser testado com tentativas de escrita negadas.

## Limites que precisam ser validados antes de produção

- A sincronização usa uma tabela JSONB transitória (`erp_records`) para conectar os repositórios atuais. Ela não substitui uma modelagem relacional definitiva por módulo.
- O app tenta sincronizar alterações após cada gravação e consulta mudanças remotas a cada 15 segundos quando não há alterações locais pendentes. A RPC verifica a versão-base e rejeita conflitos; nesses casos a sincronização pausa para evitar sobrescrita silenciosa.
- A UI pode atualizar antes da confirmação remota. Em caso de falha, aparece um aviso; confira o status antes de considerar a operação concluída.
- Recuperação de senha exige configurar a URL de redirecionamento em Supabase Auth → URL Configuration.
- O acesso remoto e a segurança não são considerados aprovados até testar login, logout, RLS positiva/negativa, dois usuários simultâneos, anexos e persistência após recarregar.
