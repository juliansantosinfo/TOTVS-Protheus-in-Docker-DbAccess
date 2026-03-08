#!/bin/bash
#
# ==============================================================================
# SCRIPT: setup-dbaccess.sh
# DESCRIÇÃO: Inicializa e configura o serviço TOTVS DBAccess. Realiza validações
#            de variáveis de ambiente, verificação de rede (License Server) e
#            configuração do arquivo INI.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-18
# USO: ./setup-dbaccess.sh
# ==============================================================================

# Ativa modo de depuração se a variável DEBUG_SCRIPT estiver como true/1/yes
if [[ "${DEBUG_SCRIPT:-}" =~ ^(true|1|yes|y)$ ]]; then
    set -x
fi

title="TOTVS DBAccess 23.1.1.7"
prog="dbaccess64"
pathbin="/totvs/dbaccess/multi"
progbin="${pathbin}/${prog}"
inifile="${pathbin}/dbaccess.ini"
export LD_LIBRARY_PATH="${pathbin}:${LD_LIBRARY_PATH}"

#---------------------------------------------------------------------

## 🚀 FUNÇOES AUXILIARES

    # Define a função de tratamento de erro para variáveis de ambiente
    check_env_vars() {
        local var_name=$1
        if [[ -z "${!var_name}" ]]; then
            echo "❌ ERRO: A variável de ambiente **${var_name}** não está definida. O script será encerrado."
            exit 1
        fi
    }

#---------------------------------------------------------------------

## 🚀 INÍCIO DA VERIFICAÇÃO DE VARIÁVEIS DE AMBIENTE

    echo ""
    echo "------------------------------------------------------"
    echo "🚀 INÍCIO DA VERIFICAÇÃO DE VÁRIAVEIS DE AMBIENTE"
    echo "------------------------------------------------------"

    # Aplica padrões para License Server se estiverem vazios
    export DBACCESS_LICENSE_SERVER="${DBACCESS_LICENSE_SERVER:-totvs_licenseserver}"
    export DBACCESS_LICENSE_PORT="${DBACCESS_LICENSE_PORT:-5555}"

    echo "🔎 Verificando variáveis de ambiente requeridas..."

    check_env_vars "DATABASE_PROFILE"
    echo "🔎 DATABASE_PROFILE... ✅"

    check_env_vars "DATABASE_SERVER"
    echo "🔎 DATABASE_SERVER... ✅"

    check_env_vars "DATABASE_PORT"
    echo "🔎 DATABASE_PORT... ✅"

    check_env_vars "DATABASE_ALIAS"
    echo "🔎 DATABASE_ALIAS... ✅"

    check_env_vars "DATABASE_NAME"
    echo "🔎 DATABASE_NAME... ✅"

    check_env_vars "DATABASE_USERNAME"
    echo "🔎 DATABASE_USERNAME... ✅"

    check_env_vars "DATABASE_PASSWORD"
    echo "🔎 DATABASE_PASSWORD... ✅"

    echo "✅ Todas as variáveis de ambiente requeridas verificadas com sucesso."

#---------------------------------------------------------------------

## 🚀 AGUARDANDO DISPONIBILIDADE DO LICENSE SERVER (NETWORK CHECK)

    echo ""
    echo "------------------------------------------------------"
    echo "⏳ AGUARDANDO DISPONIBILIDADE DO LICENSE SERVER (TCP CHECK)"
    echo "------------------------------------------------------"

    RETRIES=0
    MAX_RETRIES="${LICENSE_WAIT_RETRIES:-30}"
    INTERVAL="${LICENSE_WAIT_INTERVAL:-2}"

    echo "🔍 Verificando conectividade com $DBACCESS_LICENSE_SERVER:$DBACCESS_LICENSE_PORT..."

    until timeout 1 bash -c "echo > /dev/tcp/$DBACCESS_LICENSE_SERVER/$DBACCESS_LICENSE_PORT" > /dev/null 2>&1; do
        RETRIES=$((RETRIES + 1))
        if [ $RETRIES -ge "$MAX_RETRIES" ]; then
            echo "❌ ERRO: O License Server em $DBACCESS_LICENSE_SERVER:$DBACCESS_LICENSE_PORT não ficou disponível após $MAX_RETRIES tentativas."
            echo "🛑 Abortando inicialização."
            exit 1
        fi
        echo "  - [$RETRIES/$MAX_RETRIES] License Server ainda não responde. Aguardando ${INTERVAL}s..."
        sleep "$INTERVAL"
    done

    echo "✅ Conexão TCP estabelecida com o License Server!"

#---------------------------------------------------------------------

## 🚀 INÍCIO DA CONFIGURAÇÃO DO DBACCESS.INI

    echo ""
    echo "------------------------------------------------------"
    echo "🚀 INÍCIO DA CONFIGURAÇÃO DO DBACCESS.INI"
    echo "------------------------------------------------------"
    echo "⚙️ Iniciando configuração do arquivo .ini..."

    if [[ ! -f "/totvs/resources/settings/dbaccess.ini" ]]; then
        echo "❌ ERRO: Arquivo de configuração **dbaccess.ini** não encontrado em /totvs/resources/settings. O script será encerrado."
        exit 1
    fi

    cp -f /totvs/resources/settings/dbaccess.ini "$inifile"
    echo "✅ Arquivo base copiado para **$inifile**."

    echo "⚙️ Aplicando substituições de variáveis..."
    sed -i "s,DBACCESS_LICENSE_SERVER,${DBACCESS_LICENSE_SERVER},g" "$inifile"
    sed -i "s,DBACCESS_LICENSE_PORT,${DBACCESS_LICENSE_PORT},g" "$inifile"
    sed -i "s,DBACCESS_CONSOLEFILE,${DBACCESS_CONSOLEFILE},g" "$inifile"
    sed -i "s,DATABASE_CLIENT_LIBRARY_MSSQL,${DATABASE_CLIENT_LIBRARY_MSSQL},g" "$inifile"
    sed -i "s,DATABASE_CLIENT_LIBRARY_POSTGRES,${DATABASE_CLIENT_LIBRARY_POSTGRES},g" "$inifile"
    sed -i "s,DATABASE_CLIENT_LIBRARY_ORACLE,${DATABASE_CLIENT_LIBRARY_ORACLE},g" "$inifile"
    
    echo "✅ Variáveis substituídas no $inifile."

#---------------------------------------------------------------------

## 🚀 INÍCIO DA CONFIGURAÇÃO DO DBACCESS

    echo ""
    echo "------------------------------------------------------"
    echo "🚀 INÍCIO DA CONFIGURAÇÃO DO DBACCESS"
    echo "------------------------------------------------------"

    if [[ ! -x "/totvs/dbaccess/tools/dbaccesscfg" ]]; then
        echo "❌ ERRO: Ferramenta **dbaccesscfg** não encontrada ou sem permissão de execução. O script será encerrado."
        exit 1
    fi

    echo "⚙️ Configurando alias do DBAccess usando dbaccesscfg..."
    cd /totvs/dbaccess/multi/

    case "${DATABASE_PROFILE}" in
        MSSQL)
            echo "⚙️ Executando dbaccesscfg para MSSQL..."
            /totvs/dbaccess/tools/dbaccesscfg -u "${DATABASE_USERNAME}" -p "${DATABASE_PASSWORD}" -d mssql -a "${DATABASE_ALIAS}"
            if [ $? -eq 0 ]; then
                echo "✅ Configuração MSSQL do DBAccess concluída para o alias **${DATABASE_ALIAS}**."
            else
                echo "❌ ERRO ao configurar MSSQL com dbaccesscfg. O script será encerrado."
                exit 1
            fi
            ;;
        POSTGRES)
            echo "⚙️ Executando dbaccesscfg para POSTGRES..."
            /totvs/dbaccess/tools/dbaccesscfg -u "${DATABASE_USERNAME}" -p "${DATABASE_PASSWORD}" -d postgres -a "${DATABASE_ALIAS}"
            if [ $? -eq 0 ]; then
                echo "✅ Configuração PostgreSQL do DBAccess concluída para o alias **${DATABASE_ALIAS}**."
            else
                echo "❌ ERRO ao configurar PostgreSQL com dbaccesscfg. O script será encerrado."
                exit 1
            fi
            ;;
        ORACLE)
            echo "⚙️ Executando dbaccesscfg para ORACLE..."
            /totvs/dbaccess/tools/dbaccesscfg -u "${DATABASE_USERNAME}" -p "${DATABASE_PASSWORD}" -d oracle -a "${DATABASE_ALIAS}"
            if [ $? -eq 0 ]; then
                echo "✅ Configuração ORACLE do DBAccess concluída para o alias **${DATABASE_ALIAS}**."
            else
                echo "❌ ERRO ao configurar ORACLE com dbaccesscfg. O script será encerrado."
                exit 1
            fi
            ;;
        *)
            echo "❌ ERRO: Profile de banco de dados inválido (**${DATABASE_PROFILE}**) ou não suportado (apenas MSSQL ou POSTGRES). O script será encerrado."
            exit 1
            ;;
    esac

    cd /totvs
    echo "✅ Fim da configuração do DBAccess."

#---------------------------------------------------------------------

## 🚀 CONFIGURAÇÃO DE LIMITES (ULIMIT)

    echo ""
    echo "------------------------------------------------------"
    echo "🚀 INÍCIO DA CONFIGURAÇÃO DE LIMITES (ULIMIT)"
    echo "------------------------------------------------------"

    echo "⚙️ Aplicando limites de recursos (ulimit)..."

    ulimit -n 65536            # open files
    ulimit -s 1024             # stack size
    ulimit -c unlimited        # core file size
    ulimit -f unlimited        # file size
    ulimit -t unlimited        # cpu time
    ulimit -v unlimited        # virtual memory

    echo "✅ Limites aplicados com sucesso."

#---------------------------------------------------------------------

## 🚀 INÍCIO DA INICIALIZAÇÃO DO SERVIÇO

    echo ""
    echo "------------------------------------------------------"
    echo "🚀 INÍCIO DA INICIALIZAÇÃO DO SERVIÇO"
    echo "------------------------------------------------------"

    echo "🚀 Iniciando **${title}**..."
    # A linha 'exec' substitui o processo shell atual pelo DBAccess, mantendo o PID 1 no container.
    exec "${progbin}"