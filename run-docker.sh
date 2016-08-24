#!/bin/sh

VMQ_TBAC_DIR='/opt/manifest/vmq_tbac'

read -r DOCKER_RUN_COMMAND <<-EOF
	vernemq start \
	&& vmq-admin plugin disable --name vmq_passwd \
	&& vmq-admin plugin disable --name vmq_acl \
	&& cd ${VMQ_TBAC_DIR} \
	&& /bin/bash
EOF

docker build -t manifest/vmq_tbac .
docker run -ti --rm \
	-v $(pwd):${VMQ_TBAC_DIR} \
	-p 1883:1883 \
	-p 8888:8888 \
	manifest/vmq_tbac \
	/bin/bash -c "${DOCKER_RUN_COMMAND}"
