# Relatório de correções — ERP Brasilino

Data: 14/10/2026

## Corrigido

1. **CSS inválido no editor de propostas**: as declarações órfãs foram colocadas sob `.ed-tabs .ed-tab-action`, restaurando a validade sintática da regra.
2. **Aviso de armazenamento local**: a tela de login agora informa que dados e acessos permanecem no navegador e que compartilhamento/login centralizado dependem da integração Supabase.
3. **Base de infraestrutura**: criada migração SQL com organizações, perfis, associação de usuários, registros por coleção, índices e políticas RLS iniciais.
4. **Publicação**: criado workflow GitHub Actions para GitHub Pages.

## Ainda não resolvido / precisa de trabalho adicional

1. **Persistência compartilhada**: a camada `DB` do HTML continua usando `localStorage`; o HTML não está ligado à tabela `erp_records`.
2. **Autenticação centralizada**: o login do HTML ainda usa contas locais. Supabase Auth não foi integrado nem testado.
3. **Permissões por módulo**: requer mapear permissões do ERP e aplicar políticas no banco, não apenas ocultar menus.
4. **Anexos**: o assistente atual salva arquivos em uma pasta autorizada do computador; não existe ainda vínculo com Supabase Storage.
5. **Testes funcionais**: cálculos, propostas, financeiro, medições, anexos, exportações e concorrência entre usuários permanecem pendentes.
6. **Publicação remota**: workflow criado no pacote, mas não foi enviado ao GitHub nem executado nesta sessão.

## Verificações executadas

- Sintaxe dos 2 blocos JavaScript inline: aprovada com `node --check`.
- Balanceamento de chaves no bloco CSS principal: aprovado (881 aberturas e 881 fechamentos).
- Foram encontrados nomes de `id` repetidos em trechos de HTML gerados por templates; precisam de validação em execução, pois alguns são strings de renderização condicional e não necessariamente coexistem no DOM.
- Não foi feita requisição real ao Supabase porque URL/chave não foram fornecidas e a integração ainda não está ligada.
- Nenhuma publicação remota foi declarada como concluída.


## Evolução da integração Supabase (14/10/2026)

- Adicionado carregamento do SDK Supabase JS v2 via CDN.
- Adicionado bloco de configuração para URL do projeto e chave pública Publishable.
- Login remoto por e-mail/senha, restauração de sessão, logout e recuperação de senha.
- O modo remoto exige autenticação Supabase quando as credenciais estão preenchidas; não cai silenciosamente no login local.
- Após autenticação, os registros são carregados da organização associada ao usuário; a base remota vazia não recebe os registros locais de demonstração automaticamente.
- Adicionado adaptador transitório de sincronização de registros JSONB e atualização periódica.
- Adicionado indicador visual de estado de sincronização.
- Documentada a criação administrativa da organização e dos vínculos de usuários.

**Ainda pendente:** esta sessão não tem as credenciais do projeto, portanto não foi possível testar requisições reais. A sincronização inicial não oferece controle completo de concorrência e precisa de testes com dois usuários antes de uso empresarial. O esquema JSONB é transitório; anexos continuam sem integração com Storage. Não declarar produção aprovada até passar os testes remotos e de RLS.


## Atualização Supabase — 14/10/2026

- Autenticação por e-mail/senha com restauração de sessão e recuperação de senha.
- Sincronização remota por RPC transacional `sync_erp_records`, com verificação de `updated_at` para bloquear alterações concorrentes e evitar sobrescrita silenciosa.
- Polling de atualização ajustado para 15 segundos quando o estado local está limpo.
- Bucket privado `erp-documentos`, políticas de Storage por organização e URLs assinadas temporárias.
- Upload empresarial até 50 MB por arquivo; no modo local, os limites pequenos continuam ativos.
- Migração adicional: `supabase/migrations/202610140002_concurrency_storage.sql`.

**Limitação de validação:** não foram fornecidas credenciais do projeto Supabase nesta etapa. A sintaxe local pode ser validada, mas login real, RLS, concorrência, upload e compartilhamento entre computadores ainda precisam de testes contra o projeto do usuário.
