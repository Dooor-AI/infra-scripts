# Load Balancer para Cloud Run - Certificado SSL Automático

Alternativa **muito mais confiável** que domain mapping para configurar domínios customizados.

## 🚀 Como usar

```bash
# Dar permissões de execução
chmod +x create_load_balancer.sh check_lb_status.sh

# Criar Load Balancer com certificado SSL
./create_load_balancer.sh dooor-core us-central1 candor-front candor.dooor.ai

# Verificar status
./check_lb_status.sh dooor-core candor.dooor.ai
```

## 📋 Parâmetros

### create_load_balancer.sh
```bash
./create_load_balancer.sh [PROJECT_ID] [REGION] [SERVICE_NAME] [DOMAIN]
```

- `PROJECT_ID`: Projeto GCP (padrão: dooor-core)
- `REGION`: Região do Cloud Run (padrão: us-central1)
- `SERVICE_NAME`: Nome do serviço Cloud Run
- `DOMAIN`: Domínio para certificado (ex: api.dooor.ai)

### check_lb_status.sh
```bash
./check_lb_status.sh [PROJECT_ID] [DOMAIN]
```

## 🎯 O que o script cria

### **1. Recursos de Rede:**
- ✅ **IP Estático Global** (você configura no DNS)
- ✅ **Network Endpoint Group** (conecta ao Cloud Run)

### **2. Load Balancer:**
- ✅ **Backend Service** (EXTERNAL_MANAGED para Cloud Run serverless)
- ✅ **URL Map** (regras de roteamento)
- ✅ **Target Proxies** (HTTP + HTTPS)
- ✅ **Forwarding Rules** (portas 80 + 443)

### **3. Certificado SSL:**
- ✅ **Google-managed SSL** (renovação automática)
- ✅ **HTTPS automático** 
- ✅ **HTTP redirect** para HTTPS

## 📋 Processo completo

### **1. Execute o script:**
```bash
./create_load_balancer.sh dooor-core us-central1 candor-front candor.dooor.ai
```

### **2. Configure DNS:**
```
Tipo: A
Nome: candor
Valor: IP_MOSTRADO_NO_SCRIPT
TTL: 300
```

### **3. Aguarde propagação:**
- **DNS**: 5-15 minutos
- **Certificado SSL**: 10-60 minutos

### **4. Verifique status:**
```bash
./check_lb_status.sh dooor-core candor.dooor.ai
```

## 💰 Custos

- **Load Balancer**: ~$18/mês
- **IP Estático**: ~$1.50/mês
- **Total**: ~$20/mês

**vs Domain Mapping**: Grátis (mas instável)

## ✅ Vantagens do Load Balancer

### **vs Domain Mapping:**
- ✅ **Mais estável** (não trava em "Certificate Pending")
- ✅ **IP fixo** (fácil configurar DNS)
- ✅ **HTTP redirect** automático
- ✅ **CDN integrado** (melhor performance)
- ✅ **Suporte completo** (não beta)

### **Certificados:**
- ✅ **Renovação automática** (sem validade)
- ✅ **Google-managed** (zero manutenção)
- ✅ **Múltiplos domínios** (pode adicionar mais)

## 🔧 Comandos úteis

```bash
# Ver status do certificado
gcloud compute ssl-certificates describe candor-dooor-ai-ssl-cert --global

# Ver IP do Load Balancer  
gcloud compute addresses describe candor-dooor-ai-ip --global

# Testar HTTPS
curl -I https://candor.dooor.ai

# Ver logs do Load Balancer
gcloud logging read "resource.type=http_load_balancer" --limit=10
```

## 🚨 Troubleshooting

### **Certificado "FAILED_NOT_VISIBLE"**
- DNS não configurado ou não propagou
- Configure: `candor.dooor.ai A IP_DO_LOAD_BALANCER`
- Aguarde 15 minutos e teste novamente

### **404 Not Found**
- Load Balancer funcionando
- Problema na aplicação Cloud Run
- Verifique se serviço está público

### **Connection Timeout**
- DNS não propagado ainda
- Aguarde mais alguns minutos

## 📚 Exemplos

```bash
# API Backend
./create_load_balancer.sh dooor-core us-central1 api-backend api.dooor.ai

# Frontend 
./create_load_balancer.sh dooor-core us-central1 candor-front candor.dooor.ai

# Dashboard Admin
./create_load_balancer.sh dooor-core us-central1 admin-dash admin.dooor.ai
```

**Load Balancer é a solução profissional para domínios customizados!** 🎉