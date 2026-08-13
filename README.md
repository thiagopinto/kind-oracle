# Plataforma de Testes de Webhooks (Monorepo)

Este repositório contém a infraestrutura e o código da plataforma geral de testes de webhooks. O projeto está estruturado em formato **Monorepo** e utiliza **Kubernetes** para orquestração (localmente através de **Kind** e em produção na **Oracle Cloud VM ARM**).

---

## 📂 Estrutura do Repositório

*   [.github/workflows/](file:///Users/thiago/Projects/oracle/.github/workflows) — Workflow do GitHub Actions para deploy automático via Git/SSH na VM.
*   [docs/](file:///Users/thiago/Projects/oracle/docs) — Documentação técnica do projeto:
    *   [Fase 1: Manual de Instalação e Setup Local](file:///Users/thiago/Projects/oracle/docs/fase1-setup.md)
    *   [Configuração Detalhada de SSL/TLS com Cert-Manager](file:///Users/thiago/Projects/oracle/docs/cert-manager-ssl.md)
    *   [Decisão de Arquitetura Git (Monorepo vs. Multirepo)](file:///Users/thiago/Projects/oracle/docs/git-repository-strategies.md)
*   [k8s/](file:///Users/thiago/Projects/oracle/k8s) — Manifestos Kubernetes (Deployments, Services, Ingress e Cert-Manager).
*   [local/](file:///Users/thiago/Projects/oracle/local) — Scripts e configurações para o ambiente de testes/desenvolvimento local.
*   [services/](file:///Users/thiago/Projects/oracle/services) — Código-fonte dos serviços e nós da plataforma (Frontend e APIs de Webhooks).

---

## 🚀 Como Iniciar (Fase 1 - Local)

### 1. Inicializar o Cluster Local:
Execute o script utilitário para criar o cluster Kind e configurar o Ingress Controller (garanta que o Docker esteja rodando):
```bash
./local/setup-local.sh
```

### 2. Aplicar os Manifestos:
Implante o Frontend, os Mocks da API e as regras do Ingress:
```bash
kubectl apply -f k8s/frontend-deploy.yaml
kubectl apply -f k8s/api-mocks-deploy.yaml
kubectl apply -f k8s/ingress.yaml
```

### 3. Testar os Endpoints:
*   **Interface Web (Frontend):** `http://localhost/`
*   **Webhook IN (Mock):** `http://localhost/api/in` (Método `POST` simulado)
*   **Webhook OUT (Mock):** `http://localhost/api/out` (Método `GET` simulado)

Para simular o domínio real (`webhooks.codebr.dev`) localmente, edite seu arquivo `/etc/hosts` conforme explicado na [documentação de setup](file:///Users/thiago/Projects/oracle/docs/fase1-setup.md).
# kind-oracle
