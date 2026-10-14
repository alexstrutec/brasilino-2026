# Plano de testes — ERP Brasilino + Supabase

## Preparação

- [ ] Executar as migrações `202610140001` e `202610140002` no projeto correto.
- [ ] Configurar Auth e URLs de redirecionamento.
- [ ] Criar organização e dois usuários de teste com vínculos separados.
- [ ] Configurar a URL e a chave pública Publishable no HTML.
- [ ] Confirmar que o banco está vazio antes do primeiro login e que dados locais não são importados automaticamente.

## Login e sessão

- [ ] Login com e-mail/senha válidos.
- [ ] Senha incorreta não abre o ERP.
- [ ] Usuário sem vínculo de organização recebe erro compreensível.
- [ ] Recarregar a página mantém sessão válida.
- [ ] Sair encerra a sessão e impede acesso à área empresarial.
- [ ] Recuperação de senha envia e-mail e o link retorna para a URL permitida.
- [ ] Conta desativada ou removida da organização perde acesso após nova sessão/validação.

## Dados compartilhados

- [ ] Criar cliente no navegador A e confirmar leitura no navegador B.
- [ ] Editar e excluir registro com usuário autorizado.
- [ ] Confirmar que a role `consulta` não consegue escrever, mesmo chamando API diretamente.
- [ ] Confirmar que um usuário de outra organização não lê nem altera registros.
- [ ] Desconectar a rede durante uma gravação: a interface deve indicar falha e não afirmar sucesso remoto.

## Concorrência

- [ ] Abrir o mesmo registro nos dois navegadores.
- [ ] Alterar e salvar no navegador A.
- [ ] Tentar salvar a versão antiga no navegador B.
- [ ] Confirmar que a RPC `sync_erp_records` rejeita o conflito, não sobrescreve silenciosamente e pausa novas tentativas automáticas.
- [ ] Recarregar dados depois de guardar manualmente qualquer alteração importante e confirmar o estado atualizado.
- [ ] Confirmar que múltiplas alterações numa mesma sincronização são atômicas: em caso de conflito, nenhuma alteração da transação fica aplicada.

## Documentos e anexos

- [ ] Enviar JPG/PNG, PDF, DOC/DOCX e ZIP/RAR/7Z permitidos.
- [ ] Confirmar metadados no registro e objeto no bucket privado `erp-documentos`.
- [ ] Abrir/baixar em outro navegador autenticado na mesma organização.
- [ ] Confirmar que usuário não autenticado não consegue ler o objeto.
- [ ] Confirmar que membro de outra organização não consegue gerar URL assinada nem baixar o arquivo.
- [ ] Confirmar que `consulta` não consegue excluir/alterar arquivos.
- [ ] Testar arquivo acima de 50 MB e formatos não permitidos.
- [ ] Testar exclusão de anexo e conferir remoção do objeto e do metadado após salvar o cadastro.
- [ ] Testar cancelamento do formulário após upload e limpar possíveis arquivos órfãos.

## Resultado desta entrega

A sintaxe JavaScript e a estrutura do pacote podem ser verificadas localmente. Não há credenciais de um projeto Supabase fornecidas nesta etapa, portanto login remoto, políticas RLS, upload e concorrência real precisam ser validados no projeto do usuário antes de uso em produção.
