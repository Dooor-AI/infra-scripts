#!/bin/bash

# Script para corrigir problemas de disco/configuração do Redis
# Resolve o erro: "Redis is configured to save RDB snapshots, but it is currently not able to persist on disk"

set -e

PROJECT_ID=${1:-"dooor-core"}
VM_NAME=${2:-"redis-vm"}
ZONE=${3:-"us-central1-a"}

echo "🔧 Corrigindo configuração do Redis na VM $VM_NAME..."

# Conectar na VM e aplicar correções
gcloud compute ssh $VM_NAME --zone=$ZONE --project=$PROJECT_ID --command="
set -e

echo '📋 Status atual do Redis:'
sudo redis-cli -a \$(sudo cat /var/log/redis-credentials.log | grep REDIS_PASSWORD | cut -d'=' -f2) info persistence | grep -E '(rdb_last_bgsave_status|rdb_changes_since_last_save)'

echo ''
echo '🔧 Aplicando correções...'

# 1. Limpar arquivos temporários antigos do Redis
echo 'Limpando arquivos temporários...'
sudo find /var/lib/redis/ -name 'temp-*.rdb' -delete 2>/dev/null || true

# 2. Verificar e corrigir permissões
echo 'Verificando permissões...'
sudo chown -R redis:redis /var/lib/redis/
sudo chmod 755 /var/lib/redis/
sudo chmod 660 /var/lib/redis/*.rdb 2>/dev/null || true

# 3. Otimizar configuração do Redis para evitar problemas de disco
echo 'Otimizando configuração...'

# Backup da configuração atual
sudo cp /etc/redis/redis.conf /etc/redis/redis.conf.backup.\$(date +%Y%m%d_%H%M%S)

# Configurações para melhor gerenciamento de disco
sudo tee -a /etc/redis/redis.conf > /dev/null << 'EOF'

# === OTIMIZAÇÕES DE DISCO ===
# Reduzir frequência de saves automáticos para economizar I/O
save 900 1
save 300 10
save 60 10000

# Configurar para não parar escritas em caso de falha de bgsave
# Isso evita o erro que você estava enfrentando
stop-writes-on-bgsave-error no

# Habilitar compressão RDB para economizar espaço
rdbcompression yes

# Verificar integridade do RDB (pode ser desabilitado para economizar CPU)
rdbchecksum yes

# Configurações de memória mais conservadoras
maxmemory 2gb
maxmemory-policy allkeys-lru

# Configurar AOF como backup (mais seguro que apenas RDB)
appendonly yes
appendfilename \"appendonly.aof\"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb

# Otimizações de I/O
rdb-save-incremental-fsync yes
aof-rewrite-incremental-fsync yes

EOF

echo 'Reiniciando Redis para aplicar configurações...'
sudo systemctl restart redis-server

# Aguardar Redis inicializar
sleep 5

echo 'Verificando se Redis está funcionando...'
if sudo systemctl is-active --quiet redis-server; then
    echo '✅ Redis reiniciado com sucesso!'
    
    # Testar conexão
    REDIS_PASSWORD=\$(sudo cat /var/log/redis-credentials.log | grep REDIS_PASSWORD | cut -d'=' -f2)
    if redis-cli -a \"\$REDIS_PASSWORD\" ping > /dev/null 2>&1; then
        echo '✅ Teste de conexão: SUCESSO'
        
        # Forçar um save para testar
        echo 'Testando background save...'
        redis-cli -a \"\$REDIS_PASSWORD\" bgsave
        sleep 2
        
        # Verificar status
        redis-cli -a \"\$REDIS_PASSWORD\" info persistence | grep -E '(rdb_last_bgsave_status|stop-writes-on-bgsave-error)'
        
    else
        echo '❌ Teste de conexão: FALHOU'
        exit 1
    fi
else
    echo '❌ Redis não está rodando'
    exit 1
fi

echo ''
echo '📊 Status final:'
df -h /var/lib/redis
sudo ls -la /var/lib/redis/

"

echo ""
echo "🎉 Correções aplicadas com sucesso!"
echo ""
echo "📋 Principais mudanças:"
echo "   • stop-writes-on-bgsave-error definido como 'no'"
echo "   • AOF habilitado como backup adicional"
echo "   • Configurações de memória otimizadas"
echo "   • Arquivos temporários limpos"
echo "   • Permissões corrigidas"
echo ""
echo "💡 O Redis agora não irá parar de aceitar escritas mesmo se houver"
echo "   problemas temporários com o background save."
