#!/bin/bash

# Script de startup para instalar Redis na VM com senha aleatória
# Este script roda automaticamente quando a VM é criada

set -e

echo "Iniciando instalação do Redis..."

# Gerar senha aleatória forte (32 caracteres)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Atualizar sistema
apt-get update

# Instalar Redis
apt-get install -y redis-server

# Configurar Redis para aceitar conexões externas
sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf

# Configurar senha
echo "requirepass $REDIS_PASSWORD" >> /etc/redis/redis.conf

# Salvar senha e informações de conexão
echo "REDIS_PASSWORD=$REDIS_PASSWORD" > /var/log/redis-credentials.log
echo "REDIS_PORT=6379" >> /var/log/redis-credentials.log

# Configurar Redis como serviço
systemctl enable redis-server

# IMPORTANTE: Restart para aplicar configurações (bind e senha)
systemctl restart redis-server

# Aguardar Redis inicializar completamente
sleep 3

# Configurar logs
echo "Redis instalado com sucesso!" > /var/log/redis-install.log
echo "Senha configurada: $REDIS_PASSWORD" >> /var/log/redis-install.log

# Verificar se está rodando corretamente
if systemctl is-active --quiet redis-server; then
    echo "Redis está rodando na porta 6379 com autenticação" >> /var/log/redis-install.log
    
    # Testar conexão local com senha
    if redis-cli -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
        echo "Teste de autenticação local: SUCESSO" >> /var/log/redis-install.log
    else
        echo "Teste de autenticação local: FALHOU" >> /var/log/redis-install.log
    fi
    
    # Testar se está aceitando conexões externas
    EXTERNAL_IP=$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/external-ip -H "Metadata-Flavor: Google")
    if redis-cli -h "$EXTERNAL_IP" -p 6379 -a "$REDIS_PASSWORD" ping > /dev/null 2>&1; then
        echo "Teste de conexão externa: SUCESSO ($EXTERNAL_IP)" >> /var/log/redis-install.log
    else
        echo "Teste de conexão externa: FALHOU ($EXTERNAL_IP)" >> /var/log/redis-install.log
    fi
else
    echo "ERRO: Redis não está rodando" >> /var/log/redis-install.log
fi

echo "Instalação do Redis concluída com senha: $REDIS_PASSWORD"