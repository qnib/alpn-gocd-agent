#!/bin/bash

function assemble_build_img_name {
    # Create BUILD_IMG_NAME, which includes the git-hash and the revision of the pipeline
    export IMG_NAME=$(echo ${GO_PIPELINE_NAME} |awk -F'[\_\.]' '{print $1}')
    if [ ! -z ${GO_REVISION} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO-qnib}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO-qnib}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION_DOCKER}-rev${GO_PIPELINE_COUNTER}"
    elif [ ! -z ${GO_REVISION_DOCKER_} ];then
        export BUILD_IMG_NAME="${DOCKER_REPO-qnib}/${IMG_NAME}:${DOCKER_TAG}-${GO_REVISION_DOCKER_}-rev${GO_PIPELINE_COUNTER}"
    else
        export BUILD_IMG_NAME="${DOCKER_REPO-qnib}/${IMG_NAME}:${DOCKER_TAG}-rev${GO_PIPELINE_COUNTER}"
    fi
    echo ">> BUILD_IMG_NAME:${BUILD_IMG_NAME}"
}

function query_parent {
    # figure out information about the parent
    export PREV_PIPELINE=$(echo ${GO_DEPENDENCY_LOCATOR_PARENTTRIGGER} |awk -F/ '{print $1}')
    export QUERY_URL="${GO_SERVER_URL}/api/pipelines/${PREV_PIPELINE}/instance/${GO_DEPENDENCY_LABEL_PARENTTRIGGER}"
    export PREV_REV=$(curl -s "${QUERY_URL}" |jq ".build_cause.material_revisions[0].modifications[0].revision" |tr -d '"')
    echo ">> PREV_REV:${PREV_REV}"
}

function add_reg_to_dockerfile {
    echo ">>>> Add DOCKER_REG to Dockerfile"
    REG_IMG_NAME=$(grep ^FROM Dockerfile | awk '{print $2}')
    if [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -gt 1 ];then
        echo "Sure you wanna add the registry? Looks not right: ${REG_IMG_NAME}"
    elif [ $(echo ${REG_IMG_NAME} | grep -o "/" | wc -l) -eq 0 ];then
        echo "Image is an official one, so we skip it '${REG_IMG_NAME}'"
    else
        if [ ! -z ${DOCKER_REG} ];then
            cat Dockerfile |sed -e "s;FROM.*;FROM ${DOCKER_REG}/${REG_IMG_NAME};" > Dockerfile.new
            mv Dockerfile.new Dockerfile
            docker pull ${DOCKER_REG}/${REG_IMG_NAME}
         fi
    fi
}

function build_dockerfile {
    echo ">>>> Build Dockerfile"
    docker build -t ${BUILD_IMG_NAME} .
    if [ -f Dockerfile.bkp ];then
        echo ">>>> Restore original"
        mv Dockerfile.bkp Dockerfile
    fi
}
