# Configuração Detalhada de SSL/TLS com Cert-Manager (Let's Encrypt)

O **Cert-Manager** é um controlador do Kubernetes que automatiza o ciclo de vida dos certificados SSL/TLS (emissão, validação e renovação automática). Nesta arquitetura, ele se comunica com o **Let's Encrypt** para obter certificados válidos e gratuitos para o domínio `webhooks.codebr.dev`.

---

## 🛠️ Como funciona o Desafio HTTP-01

Para emitir um certificado, o Let's Encrypt precisa garantir que você realmente é dono do domínio. O Cert-Manager faz isso usando o desafio **HTTP-01**:

1.  Você aplica um Ingress configurado com TLS e anotações do Cert-Manager.
2.  O Cert-Manager cria temporariamente um pod de validação e uma rota Ingress específica em `http://webhooks.codebr.dev/.well-known/acme-challenge/<TOKEN>`.
3.  O Let's Encrypt faz uma requisição HTTP para essa URL.
4.  Se a requisição retornar o token correto, o Let's Encrypt valida o domínio.
5.  O Cert-Manager gera o certificado SSL, salva-o em um **Secret do Kubernetes** e exclui o pod de validação.
6.  O Ingress Nginx carrega esse Secret e passa a servir o tráfego via **HTTPS (porta 443)**.

> [!IMPORTANT]
> Para o desafio HTTP-01 funcionar, o domínio `webhooks.codebr.dev` já deve estar apontando para o IP público da sua VM Oracle no DNS, e as portas 80 e 443 da VM devem estar abertas para a internet.

---

## 🚀 Passo a Passo de Configuração na Nuvem

### Passo 1: Instalar o Cert-Manager
Aplique o manifesto oficial do Cert-Manager para implantar todos os recursos necessários (CRDs, controllers, webhook):

```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
```

Aguarde todos os pods na namespace `cert-manager` estarem prontos:
```bash
kubectl get pods -n cert-manager
```

---

### Passo 2: Criar os Issuers (Emissores)
Um `ClusterIssuer` define qual autoridade certificadora vai assinar nossos certificados. Criaremos dois emissores:
1.  **Staging:** Usado para testar se a infraestrutura de DNS e portas está correta (evita atingir o limite de requisições do Let's Encrypt).
2.  **Production:** Emite o certificado real e confiável para os navegadores.

Crie um arquivo em seu repositório ou aplique diretamente no cluster:
`k8s/cert-manager/cluster-issuers.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: seu-email@codebr.dev # Substitua pelo seu e-mail
    privateKeySecretRef:
      name: letsencrypt-staging-key
    solvers:
    - http01:
        ingress:
          class: nginx
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: seu-email@codebr.dev # Substitua pelo seu e-mail
    privateKeySecretRef:
      name: letsencrypt-production-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Aplique no cluster:
```bash
kubectl apply -f k8s/cert-manager/cluster-issuers.yaml
```

---

### Passo 3: Atualizar o Ingress para HTTPS (Produção)
No arquivo `k8s/ingress.yaml`, ative as anotações do Cert-Manager e adicione a seção `tls`.

Exemplo de configuração ativa para produção:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webhook-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # Vincula o Ingress ao nosso ClusterIssuer de Produção
    cert-manager.io/cluster-issuer: "letsencrypt-production"
spec:
  tls:
  - hosts:
    - webhooks.codebr.dev
    # O Cert-Manager salvará o certificado SSL neste Secret automaticamente
    secretName: webhooks-codebr-tls
  rules:
  - host: webhooks.codebr.dev
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webhook-hello-world-svc
            port:
              number: 80
```

Aplique o Ingress atualizado:
```bash
kubectl apply -f k8s/ingress.yaml
```

---

## 🔍 Comandos Úteis para Diagnóstico (Troubleshooting)

Se o seu domínio não carregar via HTTPS, use estes comandos para rastrear o progresso da emissão do certificado:

1.  **Verificar se o certificado foi emitido:**
    ```bash
    kubectl get certificate
    ```
    *A coluna `READY` deve exibir `True`.*

2.  **Verificar detalhes e erros de geração do certificado:**
    ```bash
    kubectl describe certificate webhooks-codebr-tls
    ```

3.  **Verificar se o desafio de domínio foi gerado:**
    ```bash
    kubectl get challenges
    ```

4.  **Verificar logs do Cert-Manager:**
    Se houver falha de rede ou DNS, os logs do controller do Cert-Manager mostrarão o erro detalhado:
    ```bash
    kubectl logs -n cert-manager -l app.kubernetes.io/component=controller --tail=100
    ```
