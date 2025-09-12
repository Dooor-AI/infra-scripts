#!/bin/bash

# Script para listar todas as VMs Redis no projeto e suas URLs de conexão

set -e

PROJECT_ID=${1:-"dooor-core"}

echo "🔍 Procurando VMs Redis no projeto $PROJECT_ID..."
echo ""

# Buscar todas as VMs com tags redis-server ou redis-multi
REDIS_VMS=$(gcloud compute instances list \
  --project=$PROJECT_ID \
  --filter="tags.items:redis-server OR tags.items:redis-multi" \
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
                
                REDIS_PASSWORD=$(gcloud compute ssh "$vm_name" \
                  --project=$PROJECT_ID \
                  --zone="$zone" \
                  --command="sudo cat /var/log/redis-credentials.log 2>/dev/null | grep REDIS_PASSWORD | cut -d'=' -f2" \
                  --quiet 2>/dev/null || echo "")
                
                if [[ -n "$REDIS_PASSWORD" ]]; then
                    echo "   🔗 URL de Conexão:"
                    echo "      redis://:$REDIS_PASSWORD@$external_ip:6379"
                else
                    # Verificar se é Redis sem senha (versão antiga)
                    REDIS_TEST=$(gcloud compute ssh "$vm_name" \
                      --project=$PROJECT_ID \
                      --zone="$zone" \
                      --command="redis-cli -h 127.0.0.1 ping 2>/dev/null || echo 'AUTH_REQUIRED'" \
                      --quiet 2>/dev/null || echo "ERROR")
                    
                    if [[ "$REDIS_TEST" == "PONG" ]]; then
                        echo "   🔗 URL de Conexão (sem senha):"
                        echo "      redis://$external_ip:6379"
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