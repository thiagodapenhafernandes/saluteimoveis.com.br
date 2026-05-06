# Instruções do Projeto

## Deploy

- O deploy de produção deste projeto é feito com Mina pela task padrão:
  `rvm 3.2.3 do bundle exec mina deploy`
- Não usar `mina production deploy`: este projeto não define uma task/stage `production`.
- O ambiente de produção já está configurado em `config/deploy.rb`:
  branch `master`, servidor `143.110.138.67`, path `/home/salute/deploy`.
- Para o fluxo `$fazer-deploy`, quando estiver em `develop`, seguir:
  `develop -> master -> mina deploy`.
