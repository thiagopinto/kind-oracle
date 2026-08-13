#!/bin/bash

# Cores para logs
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sem cor

echo -e "${GREEN}=== Iniciando Configuração do Cluster Kind Local ===${NC}"

# 1. Verificar Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}[Erro] Docker não está instalado. Por favor, instale o Docker antes de continuar.${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}[Erro] O Docker não está em execução. Por favor, inicie o Docker Desktop ou serviço.${NC}"
    exit 1
fi

# 2. Verificar Kind
if ! command -v kind &> /dev/null; then
    echo -e "${RED}[Erro] Kind não está instalado. Por favor, instale-o (ex: 'brew install kind' ou 'go install sigs.k8s.io/kind@v0.20.0').${NC}"
    exit 1
fi

# 3. Verificar kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}[Aviso] kubectl não está instalado. É altamente recomendável instalá-lo para interagir com o cluster.${NC}"
fi

CLUSTER_NAME="webhook-local-cluster"

# 4. Verificar se o cluster já existe
if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    echo -e "${YELLOW}[Aviso] O cluster '${CLUSTER_NAME}' já existe.${NC}"
    read -p "Deseja recriar o cluster? (Isso deletará o cluster atual) [y/N]: " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Deletando cluster existente...${NC}"
        kind delete cluster --name "${CLUSTER_NAME}"
    else
        echo -e "${GREEN}Usando o cluster existente.${NC}"
        exit 0
    fi
fi

# 5. Criar o cluster Kind
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_PATH="${SCRIPT_DIR}/kind-config.yaml"

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}[Erro] Arquivo de configuração do Kind não encontrado em: $CONFIG_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}Criando cluster Kind '${CLUSTER_NAME}'...${NC}"
kind create cluster --name "${CLUSTER_NAME}" --config "$CONFIG_PATH"

# 6. Instalar o Ingress Controller (Nginx) para Kind
echo -e "${GREEN}Instalando Ingress Controller (Nginx)...${NC}"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# 7. Aguardar o Ingress Controller estar pronto
echo -e "${GREEN}Aguardando o Ingress Controller ficar pronto (pode levar alguns minutos)...${NC}"
# Usamos rollout status para evitar erros se os pods ainda não tiverem sido agendados
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx --timeout=150s

echo -e "${GREEN}=== Cluster Kind configurado com sucesso! ===${NC}"
echo -e "Portas mapeadas no host local: 80 e 443"
echo -e "Para testar, aplique os manifestos do Kubernetes na pasta k8s/"
