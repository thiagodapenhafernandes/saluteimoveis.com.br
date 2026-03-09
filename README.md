# README

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
Após reiniciar, o Devise estará carregado e tudo funcionará! O painel admin estará acessível em:

URL: http://localhost:3000/admin
Login: admin@saluteimoveis.com.br
Senha: salute2024
123456

AUTOSSH_GATETIME=0 autossh -4 -M 0 -NT \
  -o ServerAliveInterval=30 \
  -o ServerAliveCountMax=3 \
  -o TCPKeepAlive=yes \
  -o ExitOnForwardFailure=yes \
  -R 3001:127.0.0.1:3001 \
  root@72.61.221.253