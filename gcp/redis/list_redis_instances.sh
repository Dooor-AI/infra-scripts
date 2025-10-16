#!/bin/bash

# Script para listar todas as VMs Redis no projeto e suas URLs de conexão

set -e

PROJECT_ID=${1:-"dooor-core"}

echo "🔍 Procurando VMs Redis no projeto $PROJECT_ID..."
echo ""

# Buscar todas as VMs com tags redis-server, redis-multi ou nome contendo "redis"
REDIS_VMS=$(gcloud compute instances list \
  --project=$PROJECT_ID \
  --filter="(tags.items:redis-server OR tags.items:redis-multi OR name~redis)" \
  --format="value(name,zone)" 2>/dev/null || echo "")

if [[ -z "$REDIS_VMS" ]]; then
    echo "❌ Nenhuma VM Redis encontrada no projeto $PROJECT_ID"
    echo ""
    echo "Para criar uma nova VM Redis:"
    echo "  ./create_redis_vm.sh"
    echo "  ./create_multi_redis_vm.sh"
    exit 0
fi

echo "📋 VMs Redis encontradas:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

counter=1

while IFS=$'\t' read -r vm_name zone_full; do
    if [[ -n "$vm_name" && -n "$zone_full" ]]; then
        # Extrair apenas o nome da zona (ex: projects/dooor-core/zones/us-central1-a -> us-central1-a)
        zone=$(echo "$zone_full" | sed 's|.*/||')
        
        echo ""
        echo "[$counter] VM: $vm_name (Zona: $zone)"
        
        # Obter status e IP da VM
        VM_INFO=$(gcloud compute instances describe "$vm_name" \
          --project=$PROJECT_ID \
          --zone="$zone" \
          --format="value(status,networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null || echo "ERROR")
        
        if [[ "$VM_INFO" == "ERROR" ]]; then
            echo "   ❌ Erro ao obter informações da VM"
        else
            read -r status external_ip <<< "$VM_INFO"
            
            if [[ "$status" == "RUNNING" && -n "$external_ip" ]]; then
                echo "   ✅ Status: $status"
                echo "   🌐 IP Externo: $external_ip"
                
                # Tentar obter credenciais do Redis
                echo "   🔄 Obtendo credenciais..."
                
                # Detectar porta do Redis (com tratamento de erro)
                REDIS_PORT=$(gcloud compute ssh "$vm_name" \
                  --project=$PROJECT_ID \
                  --zone="$zone" \
                  --command="sudo ss -tlnp | grep redis | head -1 | grep -o ':[0-9]*' | cut -d: -f2" \
                  --quiet 2>/dev/null || true)
                REDIS_PORT=${REDIS_PORT:-6379}
                
                REDIS_PASSWORD=$(gcloud compute ssh "$vm_name" \
                  --project=$PROJECT_ID \
                  --zone="$zone" \
                  --command="sudo cat /var/log/redis-credentials.log 2>/dev/null | grep REDIS_PASSWORD | cut -d'=' -f2" \
                  --quiet 2>/dev/null || true)
                
                if [[ -n "$REDIS_PASSWORD" ]]; then
                    echo "   🔗 URL de Conexão:"
                    echo "      redis://:$REDIS_PASSWORD@$external_ip:$REDIS_PORT"
                    
                    # Verificar configuração atual (com tratamento de erro)
                    STOP_WRITES=$(gcloud compute ssh "$vm_name" \
                      --project=$PROJECT_ID \
                      --zone="$zone" \
                      --command="sudo redis-cli -p $REDIS_PORT -a '$REDIS_PASSWORD' config get stop-writes-on-bgsave-error 2>/dev/null | tail -1" \
                      --quiet 2>/dev/null || true)
                    STOP_WRITES=${STOP_WRITES:-unknown}
                    
                    if [[ "$STOP_WRITES" == "no" ]]; then
                        echo "   ✅ Configuração otimizada aplicada"
                    elif [[ "$STOP_WRITES" == "yes" ]]; then
                        echo "   ⚠️  Precisa otimização (execute: ./fix_redis_disk.sh dooor-core $vm_name $zone)"
                    fi
                else
                    # Verificar se é Redis sem senha (versão antiga)
                    REDIS_TEST=$(gcloud compute ssh "$vm_name" \
                      --project=$PROJECT_ID \
                      --zone="$zone" \
                      --command="redis-cli -h 127.0.0.1 -p $REDIS_PORT ping 2>/dev/null || echo 'AUTH_REQUIRED'" \
                      --quiet 2>/dev/null || true)
                    REDIS_TEST=${REDIS_TEST:-ERROR}
                    
                    if [[ "$REDIS_TEST" == "PONG" ]]; then
                        echo "   🔗 URL de Conexão (sem senha):"
                        echo "      redis://$external_ip:$REDIS_PORT"
                    else
                        echo "   ⚠️  Não foi possível obter credenciais automaticamente"
                        echo "   💡 Execute: gcloud compute ssh $vm_name --zone=$zone --command='sudo cat /var/log/redis-credentials.log'"
                    fi
                fi
            else
                echo "   ⏸️  Status: $status"
                if [[ -n "$external_ip" ]]; then
                    echo "   🌐 IP Externo: $external_ip"
                fi
                echo "   💡 Para iniciar: gcloud compute instances start $vm_name --zone=$zone"
            fi
        fi
        
        ((counter++))
    fi
done <<< "$REDIS_VMS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Dicas:"
echo "   • Para criar nova instância: ./create_redis_vm.sh"
echo "   • Para obter credenciais manualmente: gcloud compute ssh VM_NAME --zone=ZONE --command='sudo cat /var/log/redis-credentials.log'"
echo ""