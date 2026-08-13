# Estratégia de Repositórios Git: Monorepo vs. Multirepo

Ao construir uma arquitetura de microserviços/nós no Kubernetes para gerenciamento de webhooks (com caminhos como `/`, `/in`, `/out`), existem duas abordagens principais para organizar seu código no Git. 

Abaixo detalhamos o passo a passo de configuração e o fluxo de deploy para ambos os cenários.

---

## 🏛️ Cenário A: Monorepo (Recomendado para início)

Neste modelo, **todo o seu projeto** (código dos serviços, manifestos Kubernetes, scripts locais e documentação) fica em **um único repositório Git**.

### Estrutura de Pastas Sugerida
```text
webhook-project/ (Repositório Único)
├── .github/workflows/
│   └── deploy.yml            # Pipeline unificado
├── docs/                     # Documentação
├── local/                    # Scripts do Kind local
├── k8s/                      # Manifestos Kubernetes globais
│   ├── ingress.yaml
│   ├── hello-world-deploy.yaml
│   ├── webhook-in-deploy.yaml
│   └── webhook-out-deploy.yaml
├── services/                 # Código-fonte das aplicações
│   ├── webhook-in/           # Código do endpoint /in (Node.js, Python, Go, etc.)
│   │   ├── Dockerfile
│   │   └── app/
│   └── webhook-out/          # Código do endpoint /out
│       ├── Dockerfile
│       └── app/
```

### Passo a Passo para Subir (Deploy no Monorepo)

1.  **Desenvolvimento Local:**
    *   Você edita o código em `services/webhook-in/`.
    *   Testa localmente usando o Docker/Kind.
2.  **Push para o Git:**
    *   Você faz `git commit` e `git push` para o repositório central.
3.  **Pipeline CI/CD (GitHub Actions):**
    *   O pipeline é disparado. Como tudo está no mesmo repositório, podemos usar filtros de caminho (`paths`) no GitHub Actions para rodar o build apenas se a pasta do serviço específico foi alterada:
        ```yaml
        on:
          push:
            paths:
              - 'services/webhook-in/**'
              - 'k8s/webhook-in-deploy.yaml'
        ```
    *   **Ação:** O GitHub Actions faz SSH na VM da Oracle Cloud, roda `git pull` na pasta de deploy e aplica os novos arquivos com `kubectl apply -f k8s/`.

### Vantagens do Monorepo
*   **Simplicidade:** Apenas um repositório para clonar, gerenciar permissões e chaves SSH.
*   **Rastreabilidade:** Você consegue ver alterações de infraestrutura e código que dependem uma da outra no mesmo commit.
*   **CI/CD Centralizado:** Menos arquivos de configuração de pipelines espalhados.

---

## 🌐 Cenário B: Multirepo (Repositórios Separados)

Neste modelo, você divide o projeto em **múltiplos repositórios Git independentes**:
1.  `webhook-infra`: Apenas arquivos do Kubernetes, Kind, docs e deploy global.
2.  `webhook-in`: Apenas o código do receptor de webhooks.
3.  `webhook-out`: Apenas o código do transmissor de webhooks.

### Estrutura de Pastas Sugerida

*   **Repositório 1: `webhook-infra`**
    ```text
    ├── local/
    ├── k8s/ (ingress.yaml, hello-world-deploy.yaml, etc.)
    └── docs/
    ```
*   **Repositório 2: `webhook-in`**
    ```text
    ├── .github/workflows/build-deploy.yml
    ├── Dockerfile
    └── app/ (código-fonte)
    ```
*   **Repositório 3: `webhook-out`**
    ```text
    ├── .github/workflows/build-deploy.yml
    ├── Dockerfile
    └── app/ (código-fonte)
    ```

### Passo a Passo para Subir (Deploy no Multirepo)

Como os repositórios são separados, o deploy exige que o repositório da aplicação avise o Kubernetes sobre a nova versão. O fluxo padrão de mercado é:

1.  **Build e Envio da Imagem (CI):**
    *   Ao fazer push no repositório `webhook-in`, o GitHub Actions faz build da imagem Docker.
    *   Envia a imagem com uma tag única (ex: baseada no hash do commit, como `webhook-in:sha-f2a89c`) para um Docker Registry (ex: GitHub Packages - GHCR ou Docker Hub).
2.  **Atualização no Kubernetes (CD):**
    *   **Opção via SSH (Mais simples para o seu caso):** O pipeline do repositório `webhook-in` acessa a VM via SSH e executa o comando para atualizar a imagem do container rodando no Kind:
        ```bash
        kubectl set image deployment/webhook-in web=seu-usuario/webhook-in:sha-f2a89c
        ```
    *   **Opção GitOps (ArgoCD/FluxCD - Padrão Corporativo):** O pipeline do `webhook-in` faz um commit automático no repositório `webhook-infra` alterando a tag da imagem no arquivo YAML. Uma ferramenta rodando dentro do Kubernetes (como o ArgoCD) detecta a mudança no repositório de infra e aplica a atualização automaticamente.

### Vantagens do Multirepo
*   **Isolamento:** Alterações em um serviço não interferem em outros.
*   **Independência de Deploy:** Cada microsserviço tem seu próprio ciclo de vida e pode ser atualizado de forma independente.
*   **Organização de Código:** O repositório do serviço fica focado apenas na sua respectiva linguagem e lógica de negócios.

---

## 💡 Recomendação para o seu Projeto

Para a **Fase 1 e início da Fase 2**, **recomendamos fortemente iniciar com a abordagem de Monorepo (Cenário A)**. 

### Motivos:
1.  Você está usando o **Kind** (Kubernetes rodando dentro de containers Docker na VM).
2.  Como o deploy na VM será via Git (`git pull` via SSH), ter um único repositório facilita muito o fluxo inicial, pois um único `git pull` na VM traz tanto as atualizações dos manifestos Kubernetes quanto os novos códigos dos serviços.
3.  Evita a necessidade de configurar e gerenciar autenticação em Docker Registries privados logo no início do projeto.
