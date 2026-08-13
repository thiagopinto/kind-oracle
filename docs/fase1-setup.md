# Fase 1: Guia de Instalação e Configuração (Kind e Kubernetes Local)

Este guia documenta o processo de setup de um ambiente local com Kubernetes usando **Kind (Kubernetes in Docker)**, a implantação de uma aplicação Hello World que responde na rota `/` e a configuração do Ingress Controller. Também contém notas sobre a implantação na VM ARM da Oracle Cloud.

---

## 🚀 Setup Local

### Requisitos Prévios

1.  **Docker Desktop** (ou Docker Engine) instalado e rodando.
2.  **Kind** (CLI) instalado.
    *   No macOS (Homebrew): `brew install kind`
    *   No Linux: `curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind` (para ARM, substitua `amd64` por `arm64`).
3.  **kubectl** (CLI de controle do Kubernetes) instalado.
    *   No macOS: `brew install kubectl`

---

### Passo 1: Subir o Cluster Local

O script [setup-local.sh](file:///Users/thiago/Projects/oracle/local/setup-local.sh) automatiza a criação do cluster com mapeamento de portas e a instalação do Nginx Ingress Controller.

Execute o script na raiz do projeto:
```bash
./local/setup-local.sh
```

**O que este script faz?**
1.  Valida se o Docker e o Kind estão disponíveis.
2.  Cria o cluster Kind denominado `webhook-local-cluster` usando as configurações de portas do [kind-config.yaml](file:///Users/thiago/Projects/oracle/local/kind-config.yaml). Ele expõe as portas `80` e `443` do host diretamente para o nó do Kubernetes.
3.  Aplica o manifesto oficial do **Nginx Ingress Controller** adaptado para Kind.
4.  Aguarda até que o Ingress Controller esteja pronto para receber requisições.

---

### Passo 2: Implantar o Frontend, Mocks de API e Ingress

Após a conclusão do script de setup, implante a infraestrutura do Frontend, os Mocks da API e as regras de roteamento do Ingress:

```bash
# Aplica Deployment, Service e ConfigMap do Frontend
kubectl apply -f k8s/frontend-deploy.yaml

# Aplica os Mocks dos microsserviços (/api/in e /api/out)
kubectl apply -f k8s/api-mocks-deploy.yaml

# Aplica o Ingress com as rotas divididas
kubectl apply -f k8s/ingress.yaml
```

---

### Passo 3: Testar localmente

Como o Ingress está configurado para aceitar requisições em `localhost` e no domínio `webhooks.codebr.dev`, podemos testar das seguintes formas:

#### A. Acesso Direto (localhost)
Abra o navegador ou use o `curl` no terminal:
```bash
curl http://localhost/
```
Deverá retornar o HTML do "Hello World! 🚀".

#### B. Simulando o Domínio de Produção (`webhooks.codebr.dev`)
Para simular o domínio real em sua máquina local de desenvolvimento:
1.  Abra o arquivo `/etc/hosts` como administrador:
    ```bash
    sudo nano /etc/hosts
    ```
2.  Adicione a seguinte linha no final do arquivo:
    ```text
    127.0.0.1 webhooks.codebr.dev
    ```
3.  Salve e saia. Agora você pode testar o domínio no navegador ou via curl:
    ```bash
    curl http://webhooks.codebr.dev/
    ```

---

## ☁️ Notas de Implantação na VM Oracle Cloud (ARM 2core / 12gb)

Para reproduzir este ambiente na VM da Oracle Cloud na próxima fase, siga estas etapas:

### 1. Preparação da VM Linux (Oracle Linux / Ubuntu)
*   **Instalação do Docker e do Kind:** O Docker e o Kind possuem binários nativos para **ARM64**. O procedimento é idêntico, apenas certificando-se de baixar o pacote de arquitetura `arm64`.
*   **Liberação de Portas na Oracle Cloud (VCN):**
    No painel da Oracle Cloud, edite a **Ingress Security List** da sua subnet para liberar conexões públicas:
    *   Porta `80` (HTTP) -> Origem `0.0.0.0/0` (TCP)
    *   Porta `443` (HTTPS) -> Origem `0.0.0.0/0` (TCP)
*   **Firewall do Sistema Operacional (Ubuntu/Debian/CentOS):**
    Se houver firewall ativo na VM, libere as portas:
    ```bash
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    ```

### 2. DNS (Domain Name System)
Para que o domínio `webhooks.codebr.dev` funcione e a internet consiga acessar o seu cluster:
*   Você precisa acessar o seu provedor de DNS (onde o domínio `codebr.dev` está registrado).
*   Crie um **Registro do tipo A**:
    *   **Nome/Host:** `webhooks`
    *   **Destino/IP:** O IP Público da VM na Oracle Cloud (ex: `152.67.x.x`).
*   _Nota:_ Uma vez propagado o DNS, qualquer requisição para `http://webhooks.codebr.dev` será encaminhada para a VM da Oracle Cloud. Como o Ingress Controller está rodando e escutando na porta 80 e 443 da VM, ele receberá a requisição.

### 3. HTTPS Automático com Cert-Manager (Apenas em Produção)
O **Cert-Manager** é a solução padrão do Kubernetes para automatizar a geração de certificados SSL do Let's Encrypt.
1.  **Instalação do Cert-Manager no cluster da nuvem:**
    ```bash
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
    ```
2.  **Criação do ClusterIssuer:**
    Um `ClusterIssuer` define qual autoridade certificadora (ACME / Let's Encrypt) gerará os certificados.
    ```yaml
    apiVersion: cert-manager.io/v1
    kind: ClusterIssuer
    metadata:
      name: letsencrypt-prod
    spec:
      acme:
        server: https://acme-v02.api.letsencrypt.org/directory
        email: seu-email@codebr.dev
        privateKeySecretRef:
          name: letsencrypt-prod
        solvers:
        - http01:
            ingress:
              class: nginx
    ```
3.  **Funcionamento do Cert-Manager:**
    Quando o `Ingress` é aplicado com as anotações do Cert-Manager e a configuração de TLS (conforme descomentado em `ingress.yaml`), o Cert-Manager intercepta a criação e:
    *   Cria um desafio HTTP (HTTP-01 Challenge). Ele cria temporariamente um pod e expõe um caminho específico (ex: `/.well-known/acme-challenge/...`).
    *   O Let's Encrypt tenta acessar esse caminho no domínio `webhooks.codebr.dev`.
    *   Como o DNS já está apontando para o IP da sua VM e o Ingress direciona o tráfego de desafio para o Cert-Manager, a validação é concluída.
    *   O Cert-Manager emite o certificado, grava-o em um Kubernetes Secret (`webhooks-codebr-tls`) e o Ingress o utiliza para criptografar a conexão (HTTPS).

---

## 🛠️ Roteamento de Múltiplos Paths no Ingress (ex: /, /in, /out)

O Ingress Controller atua como uma **porta de entrada única**. Você não precisa expor cada microsserviço/pod para a internet. Em vez disso, você gerencia as rotas dentro do Kubernetes usando regras de `path`.

Aqui está um exemplo de como configurar o Ingress para rotear caminhos diferentes para Services (Deployments) diferentes:

```yaml
spec:
  rules:
  - host: webhooks.codebr.dev
    http:
      paths:
      - path: /api/in
        pathType: Prefix
        backend:
          service:
            name: webhook-in-svc
            port:
              number: 80
      - path: /api/out
        pathType: Prefix
        backend:
          service:
            name: webhook-out-svc
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webhook-frontend-svc
            port:
              number: 80
```

*   **`pathType: Prefix`**: Garante que qualquer requisição que comece com o caminho especificado (ex: `/in/github`, `/in/stripe`) seja enviada para o respectivo serviço.
*   **Redirect 80 -> 443**: O Nginx Ingress Controller já faz o redirecionamento automático de HTTP para HTTPS por padrão assim que o TLS é habilitado no Ingress, graças à anotação `nginx.ingress.kubernetes.io/ssl-redirect: "true"`.
