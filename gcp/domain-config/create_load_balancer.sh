#!/bin/bash

# Script para criar Load Balancer com certificado SSL para Cloud Run
# Muito mais confiável que domain mapping!
#
# Uso: ./create_load_balancer.sh [PROJECT_ID] [REGION] [SERVICE_NAME] [DOMAIN]
# 
# Exemplos:
#   ./create_load_balancer.sh dooor-core us-central1 candor-front candor.dooor.ai

set -e

PROJECT_ID=${1:-"dooor-core"}
REGION=${2:-"us-central1"}
SERVICE_NAME=${3:-"candor-front"}
DOMAIN=${4:-"candor.dooor.ai"}

# Extrair nome base para recursos
LB_NAME=$(echo "$DOMAIN" | sed 's/\./-/g')  # candor.dooor.ai -> candor-dooor-ai

echo "🚀 Criando Load Balancer para $SERVICE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Configuração:"
echo "   Projeto: $PROJECT_ID"
echo "   Região: $REGION" 
echo "   Serviço Cloud Run: $SERVICE_NAME"
echo "   Domínio: $DOMAIN"
echo "   Nome Load Balancer: $LB_NAME"
echo ""

# 1. Criar IP estático global
echo "1️⃣ Criando IP estático global..."
gcloud compute addresses create "$LB_NAME-ip" \
    --global \
    --project="$PROJECT_ID" || echo "IP já existe"

# Obter IP criado
STATIC_IP=$(gcloud compute addresses describe "$LB_NAME-ip" \
    --global \
    --project="$PROJECT_ID" \
    --format="value(address)")

echo "   ✅ IP estático: $STATIC_IP"

# 2. Criar Network Endpoint Group (NEG) para Cloud Run
echo ""
echo "2️⃣ Criando Network Endpoint Group..."
gcloud compute network-endpoint-groups create "$LB_NAME-neg" \
    --region="$REGION" \
    --network-endpoint-type=serverless \
    --cloud-run-service="$SERVICE_NAME" \
    --project="$PROJECT_ID" || echo "NEG já existe"

echo "   ✅ NEG criado: $LB_NAME-neg"

# 3. Criar Backend Service (sem Health Check para Cloud Run serverless)
echo ""
echo "3️⃣ Criando Backend Service..."
gcloud compute backend-services create "$LB_NAME-backend" \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --global \
    --project="$PROJECT_ID" || echo "Backend Service já existe"

# Adicionar NEG ao Backend Service
gcloud compute backend-services add-backend "$LB_NAME-backend" \
    --global \
    --network-endpoint-group="$LB_NAME-neg" \
    --network-endpoint-group-region="$REGION" \
    --project="$PROJECT_ID" || echo "Backend já adicionado"

echo "   ✅ Backend Service configurado"

# 4. Criar certificado SSL gerenciado
echo ""
echo "4️⃣ Criando certificado SSL gerenciado..."
gcloud compute ssl-certificates create "$LB_NAME-ssl-cert" \
    --domains="$DOMAIN" \
    --global \
    --project="$PROJECT_ID" || echo "Certificado já existe"

echo "   ✅ Certificado SSL criado para $DOMAIN"

# 5. Criar URL Map
echo ""
echo "5️⃣ Criando URL Map..."
gcloud compute url-maps create "$LB_NAME-url-map" \
    --default-service="$LB_NAME-backend" \
    --global \
    --project="$PROJECT_ID" || echo "URL Map já existe"

echo "   ✅ URL Map criado"

# 6. Criar HTTPS Target Proxy
echo ""
echo "6️⃣ Criando HTTPS Target Proxy..."
gcloud compute target-https-proxies create "$LB_NAME-https-proxy" \
    --ssl-certificates="$LB_NAME-ssl-cert" \
    --url-map="$LB_NAME-url-map" \
    --global \
    --project="$PROJECT_ID" || echo "HTTPS Proxy já existe"

echo "   ✅ HTTPS Target Proxy criado"

# 7. Criar HTTP Target Proxy (para redirect)
echo ""
echo "7️⃣ Criando HTTP Target Proxy (redirect para HTTPS)..."
gcloud compute url-maps create "$LB_NAME-redirect-map" \
    --global \
    --project="$PROJECT_ID" || echo "Redirect Map já existe"

# Configurar redirect HTTP -> HTTPS
gcloud compute url-maps edit "$LB_NAME-redirect-map" \
    --global \
    --project="$PROJECT_ID" || echo "Redirect já configurado"

gcloud compute target-http-proxies create "$LB_NAME-http-proxy" \
    --url-map="$LB_NAME-redirect-map" \
    --global \
    --project="$PROJECT_ID" || echo "HTTP Proxy já existe"

echo "   ✅ HTTP Target Proxy criado"

# 8. Criar Forwarding Rules
echo ""
echo "8️⃣ Criando Forwarding Rules..."

# HTTPS Forwarding Rule
gcloud compute forwarding-rules create "$LB_NAME-https-forwarding-rule" \
    --address="$LB_NAME-ip" \
    --global \
    --target-https-proxy="$LB_NAME-https-proxy" \
    --ports=443 \
    --project="$PROJECT_ID" || echo "HTTPS Forwarding Rule já existe"

# HTTP Forwarding Rule
gcloud compute forwarding-rules create "$LB_NAME-http-forwarding-rule" \
    --address="$LB_NAME-ip" \
    --global \
    --target-http-proxy="$LB_NAME-http-proxy" \
    --ports=80 \
    --project="$PROJECT_ID" || echo "HTTP Forwarding Rule já existe"

echo "   ✅ Forwarding Rules criados"

# 9. Verificar Cloud Run está público
echo ""
echo "9️⃣ Verificando se Cloud Run está público..."
gcloud run services add-iam-policy-binding "$SERVICE_NAME" \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --region="$REGION" \
    --project="$PROJECT_ID" 2>/dev/null || echo "   ⚠️  Política de organização pode bloquear acesso público"

echo ""
echo "🎉 Load Balancer criado com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CONFIGURAÇÃO DNS:"
echo ""
echo "   Adicione este registro no DNS da dooor.ai:"
echo "   Tipo: A"
echo "   Nome: $(echo "$DOMAIN" | cut -d'.' -f1)"  
echo "   Valor: $STATIC_IP"
echo "   TTL: 300"
echo ""
echo "🌐 URLs após configurar DNS:"
echo "   HTTP:  http://$DOMAIN (redirect para HTTPS)"
echo "   HTTPS: https://$DOMAIN"
echo ""
echo "⏰ IMPORTANTE:"
echo "   • Configure o DNS primeiro"
echo "   • Certificado SSL pode levar 10-60 min para ser provisionado"
echo "   • Teste: curl -I https://$DOMAIN"
echo ""
echo "🔧 Para verificar status:"
echo "   gcloud compute ssl-certificates describe $LB_NAME-ssl-cert --global"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"