# Redis no GCP - Alternativa Barata ao Memorystore

## 🚀 Como usar

```bash
# Dar permissão de execução
chmod +x create_redis_vm.sh install_redis.sh list_redis_instances.sh

# Criar VM com Redis padrão
./create_redis_vm.sh
# Cria: redis-vm

# Criar VM para um app específico
./create_redis_vm.sh dooor-core us-central1-a myapp
# Cria: redis-vm-myapp

# Listar todas as VMs Redis
./list_redis_instances.sh
```

## 📋 Parâmetros do create_redis_vm.sh

```bash
./create_redis_vm.sh [PROJECT_ID] [ZONE] [APP_NAME] [MACHINE_TYPE] [NETWORK]
```

- `PROJECT_ID`: ID do projeto GCP (padrão: dooor-core)
- `ZONE`: Zona onde criar a VM (padrão: us-central1-a) 
- `APP_NAME`: Nome do app - cria redis-vm-{APP_NAME} (opcional)
- `MACHINE_TYPE`: Tipo da máquina (padrão: e2-medium - 4GB RAM)
- `NETWORK`: Rede da VM (padrão: default)

**Exemplos:**
- `./create_redis_vm.sh` → redis-vm
- `./create_redis_vm.sh dooor-core us-central1-a backend` → redis-vm-backend  
- `./create_redis_vm.sh dooor-core us-central1-a frontend` → redis-vm-frontend

## 🔐 Autenticação Automática

**O script agora configura senha aleatória automaticamente!**

- ✅ Senha forte de 32 caracteres gerada automaticamente
- ✅ URL de conexão mostrada no final (formato Railway)
- ✅ Credenciais salvas na VM para futuras consultas

**Exemplo de output:**
```
🎉 Redis criado com sucesso!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 INFORMAÇÕES DE CONEXÃO:
   IP: 34.30.16.232
   Porta: 6379
   Senha: aQL4utSwOLKT11BTizQSTvOmzyD4Uoug

🔗 URL DE CONEXÃO (copie para seu app):
   redis://:aQL4utSwOLKT11BTizQSTvOmzyD4Uoug@34.30.16.232:6379
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## 📖 Listar todas as instâncias

```bash
./list_redis_instances.sh
```

**Mostra:**
- Status de cada VM Redis
- IP externo
- URL de conexão completa
- Detecção automática de senha

## 💰 Custos

- **e2-medium (4GB)**: ~$24/mês 


## 🔌 Conectar na aplicação

```javascript
// .env
REDIS_URL=redis://:senha@ip:6379

// Node.js
const redis = require('redis');
const client = redis.createClient(process.env.REDIS_URL);
```

## 🛠️ Comandos úteis

```bash
# Ver credenciais manualmente
gcloud compute ssh redis-vm --zone=us-central1-a --command="sudo cat /var/log/redis-credentials.log"

# Testar conexão
redis-cli -h IP_DA_VM -p 6379 -a SENHA ping

# Ver logs do Redis  
gcloud compute ssh redis-vm --zone=us-central1-a --command="sudo journalctl -u redis-server -f"

# Listar todas VMs Redis
./list_redis_instances.sh
```

## 🔒 Segurança

**Já configurado automaticamente:**
- ✅ Senha forte aleatória
- ✅ Acesso externo configurado 
- ✅ Firewall para porta 6379

**Para produção adicional:**
- Usar VPC privada
- Configurar SSL/TLS
- Restringir firewall para IPs específicos