#!/bin/bash
#
# ==============================================================================
# SCRIPT: run.sh
# DESCRIÇÃO: Executa o container do AppServer TOTVS para testes locais.
# AUTOR: Julian de Almeida Santos
# DATA: 2025-10-12
# USO: ./run.sh
# ==============================================================================

# Carregar versões centralizadas
if [ -f "versions.env" ]; then
    source "versions.env"
elif [ -f "../versions.env" ]; then
    source "../versions.env"
fi

readonly DOCKER_TAG="${DOCKER_USER}/${DBACCESS_IMAGE_NAME}:${DBACCESS_VERSION}"

docker run --rm \
    --name "${DBACCESS_IMAGE_NAME}" \
    -p 1234:1234 \
    -p 1235:1235 \
    -p 8080:8080 \
    "${DOCKER_TAG}"
