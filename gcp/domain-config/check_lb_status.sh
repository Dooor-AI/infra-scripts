#!/bin/bash

# Script para verificar status do Load Balancer e certificado SSL
# 
# Uso: ./check_lb_status.sh [PROJECT_ID] [DOMAIN]

set -e

PROJECT_ID=${1:-"dooor-core"}
DOMAIN=${2:-"candor.dooor.ai"}

# Extrair nome base
LB_NAME=$(echo "$DOMAIN" | sed 's/\./-/g')

echo "🔍 Verificando status do Load Balancer para $DOMAIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Verificar IP estático
echo ""
echo "1️⃣ IP Estático:"
STATIC_IP=$(gcloud compute addresses describe "$LB_NAME-ip" \
    --global \
    --project="$PROJECT_ID" \
    --format="value(address)" 2>/dev/null || echo "Não encontrado")

if [[ "$STATIC_IP" != "Não encontrado" ]]; then
    echo "   ✅ IP: $STATIC_IP"
else
    echo "   ❌ IP não encontrado"
    exit 1
fi

# 2. Verificar certificado SSL
echo ""
echo "2️⃣ Certificado SSL:"
SSL_STATUS=$(gcloud compute ssl-certificates describe "$LB_NAME-ssl-cert" \
    --global \
    --project="$PROJECT_ID" \
    --format="value(managed.status)" 2>/dev/null || echo "Não encontrado")

case "$SSL_STATUS" in
    "ACTIVE")
        echo "   ✅ Status: ATIVO - Certificado funcionando"
        ;;
    "PROVISIONING")
        echo "   🟡 Status: PROVISIONANDO - Aguarde..."
        ;;
    "FAILED_NOT_VISIBLE")
        echo "   ❌ Status: FALHOU - DNS não configurado ou não propagado"
        ;;
    "Não encontrado")
        echo "   ❌ Certificado não encontrado"
        ;;
    *)
        echo "   🟡 Status: $SSL_STATUS"
        ;;
esac

# 3. Verificar DNS
echo ""
echo "3️⃣ Verificação DNS:"
DNS_IP=$(nslookup "$DOMAIN" 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}' || echo "Não resolvido")

if [[ "$DNS_IP" == "$STATIC_IP" ]]; then
    echo "   ✅ DNS configurado corretamente ($DNS_IP)"
elif [[ "$DNS_IP" == "Não resolvido" ]]; then
    echo "   ❌ DNS não configurado"
    echo "   💡 Configure: $DOMAIN A $STATIC_IP"
else
    echo "   ❌ DNS apontando para IP incorreto ($DNS_IP)"
    echo "   💡 Deveria apontar para: $STATIC_IP"
fi

# 4. Testar HTTPS
echo ""
echo "4️⃣ Teste HTTPS:"
HTTPS_STATUS=$(curl -I -s --connect-timeout 10 "https://$DOMAIN" 2>/dev/null | head -1 || echo "Falhou")

if [[ "$HTTPS_STATUS" == *"200"* ]]; then
    echo "   ✅ HTTPS funcionando - $HTTPS_STATUS"
elif [[ "$HTTPS_STATUS" == *"404"* ]]; then
    echo "   🟡 HTTPS funcionando mas app retornou 404"
elif [[ "$HTTPS_STATUS" == "Falhou" ]]; then
    echo "   ❌ HTTPS não funcionando"
else
    echo "   🟡 HTTPS resposta: $HTTPS_STATUS"
fi

# 5. Resumo
echo ""
echo "📋 RESUMO:"
if [[ "$SSL_STATUS" == "ACTIVE" && "$DNS_IP" == "$STATIC_IP" ]]; then
    echo "   🎉 Tudo funcionando! https://$DOMAIN está online"
elif [[ "$SSL_STATUS" == "PROVISIONING" ]]; then
    echo "   ⏳ Aguarde certificado ser provisionado (pode levar até 60 min)"
elif [[ "$DNS_IP" != "$STATIC_IP" ]]; then
    echo "   🔧 Configure DNS: $DOMAIN A $STATIC_IP"
else
    echo "   🔧 Verificar configurações"
fi

echo ""
echo "🔧 Comandos úteis:"
echo "   • Ver certificado: gcloud compute ssl-certificates describe $LB_NAME-ssl-cert --global"
echo "   • Ver load balancer: gcloud compute url-maps describe $LB_NAME-url-map --global" 
echo "   • Testar: curl -I https://$DOMAIN"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"