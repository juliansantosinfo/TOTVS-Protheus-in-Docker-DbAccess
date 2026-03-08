# Dockerização do DBAccess para ERP TOTVS Protheus

## Overview

Este projeto contém a implementação do container Docker para o **DBAccess** da TOTVS.

A imagem é projetada para rodar sobre distribuições **Enterprise Linux** (como **Red Hat UBI** ou **Oracle Linux**), oferecendo segurança e estabilidade corporativa.

Este serviço atua como um intermediário de comunicação entre os servidores de aplicação (`appserver`) e o banco de dados, gerenciando as conexões e abstraindo os drivers ODBC.

### Diferenciais desta Imagem

*   **Setup Dinâmico:** A imagem detecta o tipo de banco de dados (`DATABASE_PROFILE`) e executa scripts de setup específicos (`mssql-setup.sh`, `postgresql-setup.sh` ou `oracle-setup.sh`) para configurar os drivers ODBC necessários em tempo de execução.
*   **Resiliência:** Mecanismos de wait-for-network nativos garantem que o DBAccess só inicie após o Banco de Dados e o License Server estarem prontos.
*   **Segurança:** Base empresarial minimalista e otimizada.

### Outros Componentes Necessários

*   **Banco de Dados**: `mssql`, `postgres` ou `oracle`.
*   **licenseserver**: Gestão de licenças.
*   **appserver**: O servidor de aplicação Protheus.

## Início Rápido

**Importante:** Este contêiner precisa estar na mesma rede Docker que o banco de dados e o License Server para funcionar corretamente.

1.  **Baixe a imagem (se disponível no Docker Hub):**
    ```bash
    docker pull juliansantosinfo/totvs_dbaccess:latest
    ```

2.  **Crie a rede Docker (caso ainda não exista):**
    ```bash
    docker network create totvs
    ```

3.  **Execute o contêiner:**
    ```bash
    docker run -d \
      --name totvs_dbaccess \
      --network totvs \
      -p 7890:7890 \
      -p 7891:7891 \
      -e "DATABASE_PROFILE=POSTGRES" \
      -e "DATABASE_SERVER=totvs_postgres" \
      -e "DATABASE_PASSWORD=ProtheusDatabasePassword1" \
      juliansantosinfo/totvs_dbaccess:latest
    ```

## Build Local

Caso queira construir a imagem localmente:

### 1. Preparar Pacotes

Baixe o binário do DbAccess e coloque nos diretório `packages/`:

```txt
packages/
├── 25-10-06-TOTVS_DBACCESS_BUILD_24.1.1.1_LINUX_X64.TAR
```

**Arquivos necessários:**
- **DbAccess Binary** - `*DBACCESS_BUILD*.TAR.GZ`

### 2. Extrair Pacotes

Execute o script `unpack.sh` para extrair os pacotes para a estrutura correta:

```bash
./unpack.sh
```

Isso criará a seguinte estrutura:

```txt
totvs/
├── dbaccess
    ├── client
    │   ├── dbapi.so
    │   └── debug
    │       └── dbapi.so
    ├── dbmonitor
    ├── library
    │   ├── dbaccess64.so
    │   └── debug
    │       └── dbaccess64.so
    ├── monitor_ru_ru.qm
    ├── multi
    │   ├── dbaccess64
    │   └── debug
    │       └── dbaccess64
    └── tools
        ├── dbaccesscfg
        ├── dbtools
        └── debug
            └── dbtools
```

### 3. Executar Build

Execute o script de build:

```bash
./build.sh
```

### Opções de Build

O script `build.sh` suporta várias opções:

```bash
./build.sh [OPTIONS]
```

**Opções disponíveis:**
- `--progress=<MODE>` - Define o modo de progresso (auto|plain|tty) [padrão: auto]
- `--no-cache` - Desabilita o cache do Docker
- `--no-extract` - Desabilita compressão de recursos no build
- `--build-arg KEY=VALUE` - Passa argumentos adicionais para o Docker build
- `--tag=<TAG>` - Define uma tag customizada para a imagem
- `-h, --help` - Exibe ajuda

**Exemplos:**
```bash
# Build padrão
./build.sh

# Build sem cache com progresso detalhado
./build.sh --progress=plain --no-cache

# Build com imagem base customizada
./build.sh --build-arg IMAGE_BASE=custom:tag

# Build com tag customizada
./build.sh --tag=myuser/appserver:1.0
```

### Build com Imagem Base Customizada

Quando usando uma imagem base customizada que já contém os recursos do Protheus (via `IMAGE_BASE` no `versions.env`), o script automaticamente pula a validação de diretórios locais:

```bash
# No GitHub Actions, IMAGE_BASE é carregado automaticamente
# Para build local com imagem customizada:
export IMAGE_BASE=juliansantosinfo/imagebase:totvs.dbaccess_24.1.1.1
./build.sh
```

## Push para Registry

Para enviar a imagem para o Docker Hub:

```bash
./push.sh [OPTIONS]
```

**Opções disponíveis:**
- `--no-latest` - Não faz push da tag 'latest'
- `--tag=<TAG>` - Define uma tag customizada para push
- `-h, --help` - Exibe ajuda

**Comportamento:**
- A tag `latest` só é enviada quando em branches `main` ou `master`
- Em outras branches, apenas a tag versionada é enviada

**Exemplos:**
```bash
# Push padrão (versão + latest se em main/master)
./push.sh

# Push apenas da versão (sem latest)
./push.sh --no-latest

# Push de tag customizada
./push.sh --tag=myuser/appserver:custom
```

## CI/CD com GitHub Actions

O projeto inclui workflow automatizado em `.github/workflows/deploy.yml` que:

1. **Detecta mudanças relevantes** - Ignora alterações em documentação e configurações
2. **Carrega imagem base customizada** - Usa `IMAGE_BASE` do `versions.env`
3. **Build automatizado** - Executa `./build.sh` com detecção de ambiente
4. **Push condicional** - Envia `latest` apenas em branches principais

**Configuração necessária:**

Adicione os secrets no repositório GitHub:
- `DOCKER_USERNAME` - Usuário do Docker Hub
- `DOCKER_TOKEN` - Token de acesso do Docker Hub

**Triggers:**
- Push em branches: `master`, `main`, `24.*`, `25.*`
- Pull requests para essas branches
- Execução manual via `workflow_dispatch`

## Variáveis de Ambiente

| Variável | Descrição | Padrão |
|---|---|---|
| `DATABASE_PROFILE` | Tipo do banco: `POSTGRES`, `MSSQL` ou `ORACLE`. | `MSSQL` |
| `DATABASE_SERVER` | Host do servidor de banco de dados. | `totvs_mssql` |
| `DATABASE_PORT` | Porta do banco. | `1433`/`5432`/`1521` |
| `DATABASE_ALIAS` | Alias da base de dados no DBAccess. | `protheus` |
| `DATABASE_NAME` | Nome da base de dados física. | `protheus` |
| `DATABASE_USERNAME` | Usuário de acesso ao banco. | `sa`/`postgres`/`system` |
| `DATABASE_PASSWORD` | Senha de acesso ao banco. | `ProtheusDatabasePassword1` |
| `DATABASE_WAIT_RETRIES` | Tentativas de conexão com o banco. | `30` |
| `DATABASE_WAIT_INTERVAL` | Intervalo em segundos entre tentativas. | `2` |
| `DBACCESS_LICENSE_SERVER`| Host do License Server. | `totvs_licenseserver` |
| `DBACCESS_LICENSE_PORT`| Porta do License Server. | `5555` |
| `DBACCESS_CONSOLEFILE` | Local do arquivo console.log | `/totvs/dbaccess/multi/dbconsole.log` |
| `LICENSE_WAIT_RETRIES` | Tentativas de conexão com o License Server. | `30` |
| `LICENSE_WAIT_INTERVAL` | Intervalo em segundos entre tentativas. | `2` |
| `DEBUG_SCRIPT` | Ativa o modo de depuração dos scripts (`true`/`false`). | `false` |
| `TZ` | Fuso horário do contêiner. | `America/Sao_Paulo` |
