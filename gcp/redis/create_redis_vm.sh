#!/bin/bash

# Script para criar VM com Redis no GCP
# Muito mais barato que o Memorystore!
#
# Uso: ./create_redis_vm.sh [PROJECT_ID] [ZONE] [APP_NAME] [MACHINE_TYPE] [NETWORK]
# 
# Exemplos:
#   ./create_redis_vm.sh                           # Cria redis-vm
#   ./create_redis_vm.sh dooor-core us-central1-a myapp  # Cria redis-vm-myapp

set -e

PROJECT_ID=${1:-"dooor-core"}
ZONE=${2:-"us-central1-a"}
APP_NAME=${3:-""}  # Nome do app (ex: myapp -> redis-vm-myapp)
MACHINE_TYPE=${4:-"e2-medium"}  # 4 GB RAM, 2 vCPUs
NETWORK=${5:-"default"}

# Definir nome da VM baseado no app
if [[ -n "$APP_NAME" ]]; then
    VM_NAME="redis-vm-$APP_NAME"
else
    VM_NAME="redis-vm"
fi

echo "Criando VM $VM_NAME no projeto $PROJECT_ID..."

# Criar a VM com startup script para instalar Redis
gcloud compute instances create $VM_NAME \
  --project=$PROJECT_ID \
  --zone=$ZONE \
  --machine-type=$MACHINE_TYPE \
  --network-interface=network-tier=PREMIUM,stack-type=IPV4_ONLY,subnet=$NETWORK \
  --maintenance-policy=MIGRATE \
  --provisioning-model=STANDARD \
  --service-account="360001879951-compute@developer.gserviceaccount.com" \
  --scopes=https://www.googleapis.com/auth/cloud-platform \
  --tags=redis-server,http-server \
  --create-disk=auto-delete=yes,boot=yes,device-name=$VM_NAME,image=projects/ubuntu-os-cloud/global/images/ubuntu-2004-focal-v20231101,mode=rw,size=10,type=projects/$PROJECT_ID/zones/$ZONE/diskTypes/pd-standard \
  --no-shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring \
  --labels=environment=redis \
  --reservation-affinity=any \
  --metadata-from-file startup-script=install_redis.sh

echo "VM criada! Aguarde alguns minutos para o Redis ser instalado."

# Criar regra de firewall para Redis (porta 6379)
echo "Criando regra de firewall para Redis..."
gcloud compute firewall-rules create allow-redis \
  --project=$PROJECT_ID \
  --allow tcp:6379 \
  --source-ranges 0.0.0.0/0 \
  --target-tags redis-server \
  --description="Permitir acesso ao Redis na porta 6379" || echo "Regra de firewall já existe"

echo "Setup completo!"
echo "Aguardando 2 minutos para Redis inicializar e configurar senha..."
sleep 120

# Obter IP externo da VM
EXTERNAL_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --quiet)

echo ""
echo "Obtendo credenciais do Redis..."

# Obter senha do Redis via SSH (aguardar até arquivo existir)
for i in {1..30}; do
    REDIS_PASSWORD=$(gcloud compute ssh $VM_NAME --zone=$ZONE --command="sudo cat /var/log/redis-credentials.log 2>/dev/null | grep REDIS_PASSWORD | cut -d'=' -f2" --quiet 2>/dev/null || echo "")
    
    if [[ -n "$REDIS_PASSWORD" ]]; then
        break
    fi
    
    echo "Aguardando instalação do Redis... ($i/30)"
    sleep 10
done

if [[ -n "$REDIS_PASSWORD" && -n "$EXTERNAL_IP" ]]; then
    echo ""
    echo "🎉 Redis criado com sucesso!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📋 INFORMAÇÕES DE CONEXÃO:"
    echo "   IP: $EXTERNAL_IP"
    echo "   Porta: 6379" 
    echo "   Senha: $REDIS_PASSWORD"
    echo ""
    echo "🔗 URL DE CONEXÃO (copie para seu app):"
    echo "   redis://:$REDIS_PASSWORD@$EXTERNAL_IP:6379"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
else
    echo "⚠️  Não foi possível obter as credenciais automaticamente."
    echo "Execute: gcloud compute ssh $VM_NAME --zone=$ZONE --command='sudo cat /var/log/redis-credentials.log'"
    echo "IP externo: $EXTERNAL_IP"
fi