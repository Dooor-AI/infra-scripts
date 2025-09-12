# Repositório infra-scripts

Este repositório contém scripts de infraestrutura para gerenciar recursos na cloud, principalmente no Google Cloud Platform (GCP).

## Propósito

- **Gerenciar scripts de infraestrutura** de forma centralizada
- **Automatizar provisionamento** de recursos na cloud
- **Alternativas econômicas** aos serviços gerenciados (ex: VM com Redis vs Memorystore)
- **Padronização** de configurações e deployments

## Estrutura

- `create_redis_vm.sh` - Provisiona VM com Redis no GCP (alternativa barata ao Memorystore)
- `install_redis.sh` - Script de instalação do Redis para VMs
- `install_*.sh` - Scripts de instalação de diferentes serviços
- `bootstrap_*.sh` - Scripts de inicialização de ambientes

## Configuração GCP

**IMPORTANTE**: No GCP utilizamos principalmente o projeto **`dooor-core`**.

Para debugs e ler servicos, utilize sempre o gcloud cli

Todos os scripts GCP devem usar este projeto como padrão, mas permitir override via parâmetro.

## Como usar

1. Clonar o repositório
2. Dar permissões de execução: `chmod +x *.sh`
3. Executar scripts conforme documentação específica

## Convenções

- Scripts devem ter parâmetros sensatos como padrão
- Usar `dooor-core` como projeto GCP padrão
- Documentar custos quando relevante
- Incluir verificações de erro (`set -e`)
- Logs informativos durante execução

## Exemplos de economia

- **Redis**: VM e2-micro (~$5/mês) vs Memorystore (~$45/mês) = 90% economia
- **Outros serviços**: Similar pattern pode ser aplicado