#!/bin/bash

# Script de startup para instalar Redis na VM com senha aleatória
# Este script roda automaticamente quando a VM é criada

set -e

echo "Iniciando instalação do Redis..."

# Gerar senha aleatória forte (32 caracteres)
REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Atualizar sistema
apt-get update

# Adicionar repositório oficial do Redis para versão específica
curl -fsSL https://packages.redis.io/gpg | sudo gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb focal main" | sudo tee /etc/apt/sources.list.d/redis.list

# Atualizar cache de pacotes
apt-get update

# Instalar Redis versão específica e estável (6.2.14)
apt-get install -y redis=6:6.2.14-1rl1~focal1

# Configurar Redis para aceitar conexões externas
# Redis 8.0+ usa formato diferente
sed -i 's/bind 127.0.0.1 ::1/bind 0.0.0.0/' /etc/redis/redis.conf
sed -i 's/bind 127.0.0.1 -::1/bind 0.0.0.0/' /etc/redis/redis.conf

# Desabilitar protected mode para conexões externas com senha
sed -i 's/protected-mode yes/protected-mode no/' /etc/redis/redis.conf

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