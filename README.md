# Deployment 

1. Clone the repository  https://anonymous.4open.science/r/DynFrs-2603/

2.  Create Application
    
``` shell
$ cartesi create DynFrs –template cpp

$ cp DynFrs.h  roc_auc.h main.cpp DynFrs/
```

4. Copy the content of main.cpp to dapp.cpp
 
5. Modify Makefile
``` shell
CXX  := g++

.PHONY: clean 3rdparty

dapp: dapp.cpp
	make -C 3rdparty
	$(CXX) -std=c++17 -O3 -o $@ $^

clean:
	@rm -rf dapp
	make -C 3rdparty clean

6. Alterar Dockerfile aumentando a RAM da cartesi machine e copiar os arquivos do dataset, além de configurar o treinamento 

FROM --platform=linux/riscv64 ubuntu:22.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends \
  autoconf \
  automake \
  build-essential \
  ca-certificates \
  curl \
  libtool \
  wget
rm -rf /var/lib/apt/lists/*
EOF

WORKDIR /opt/cartesi/dapp
COPY . .
RUN make

FROM --platform=linux/riscv64 ubuntu:22.04

ARG MACHINE_EMULATOR_TOOLS_VERSION=0.14.1
ADD https://github.com/cartesi/machine-emulator-tools/releases/download/v${MACHINE_EMULATOR_TOOLS_VERSION}/machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb /
RUN dpkg -i /machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb \
  && rm /machine-emulator-tools-v${MACHINE_EMULATOR_TOOLS_VERSION}.deb

LABEL io.cartesi.rollups.sdk_version=0.9.0
LABEL io.cartesi.rollups.ram_size=512Mi

ARG DEBIAN_FRONTEND=noninteractive
RUN <<EOF
set -e
apt-get update
apt-get install -y --no-install-recommends \
  busybox-static=1:1.30.1-7ubuntu3
rm -rf /var/lib/apt/lists/* /var/log/* /var/cache/*
useradd --create-home --user-group dapp
EOF

ENV PATH="/opt/cartesi/bin:${PATH}"

WORKDIR /opt/cartesi/dapp
RUN mkdir ./Datasets 
RUN mkdir ./Datasets/Adult ./Datasets/Bank
COPY train.txt ./Datasets/Adult/
COPY test.txt ./Datasets/Adult/
COPY DynFrs.h .
COPY roc_auc.h . 
COPY --from=builder /opt/cartesi/dapp/dapp .

ENV ROLLUP_HTTP_SERVER_URL="http://127.0.0.1:5004"

ENTRYPOINT ["rollup-init"]
CMD ["/opt/cartesi/dapp/dapp -data Adult -auto -unl_cnt 100 -acc"]
```
7. Montar e executar aplicação

$ cartesi build

$ cartesi run

8. Fazendo deploy da aplicação publicamente

$ cartesi deploy --hosting self-hosted --webapp http://sunodo.io/deploy


9. Deploy da Cartesi Machine criada  na plataforma Fly.io: 

Instalar flyctl command  curl -L https://fly.io/install.sh | sh

Após instalar o aplicativo fly deve-se usar os seguintes comandos para subir o container.

$ fly app create <app-name>
New app created: <app-name>

10. Criar base de dados Postgres

$ fly postgres create --initial-cluster-size 1 --name <app-name>-database --vm-size shared-cpu-1x --volume-size 1

11. Conectar banco de dados à aplicação

$ fly postgres attach <app-name>-database -a <app-name>

12. Download fly.toml e mova para o diretório da sua aplicação.





13. Fazer o deploy final do node.

Etiquetar a imagem que foi criada no início do processo e envie para registro no Fly.io 

$ flyctl auth docker
$ docker image tag <image-id> registry.fly.io/<app-name>
$ docker image push registry.fly.io/<app-name>
$ fly deploy -a <app-name>


