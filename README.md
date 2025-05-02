## 1. Clone the repository

  https://anonymous.4open.science/r/DynFrs-2603/

## 2.  Create Application
    
``` shell
$ cartesi create DynFrs –template cpp

$ cp DynFrs.h  roc_auc.h main.cpp DynFrs/
```

 Copy the content of main.cpp to dapp.cpp
 
 Modify Makefile
``` shell
CXX  := g++

.PHONY: clean 3rdparty

dapp: dapp.cpp
	make -C 3rdparty
	$(CXX) -std=c++17 -O3 -o $@ $^

clean:
	@rm -rf dapp
	make -C 3rdparty clean

 Alterar Dockerfile aumentando a RAM da cartesi machine e copiar os arquivos do dataset, além de configurar o treinamento 

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
 Build the Application
``` shell
$ cartesi build

```
## 3 - Deploying the Cartesi DApp
For this step you need to build your Cartesi DApp using [cartesi-cli](https://www.npmjs.com/package/@cartesi/cli) then you can deploy it using the script we provide. The script is going to output an env file with setup informations for the Cartesi Node. This env file is used on step 3 and use <machine_hash>.env pattern as its name.

``` shell
./deploy_dapp.sh <path_to_your_cartesi_dapp>
```


## 4 - Running the Cartesi Rollup Node

Start by running a POSTGRES database that will be used by the node using the command below. The command runs a Postgres database of password "mysecretpassword", and user "postgres". We are also exposing port 5432 through port 15432.
``` shell
docker run --name cartesi-node-postgres -e POSTGRES_PASSWORD=mysecretpassword -d -p 15432:5432 postgres
```

Now, add the Postgres URL to the <machine_hash>.env generated previously. The URL changes according to the values chosen when running the database, but considering our example, you should use the following value:

```
CARTESI_POSTGRES_ENDPOINT=postgres://postgres:mysecretpassword@host.docker.internal:15432/postgres
```

Build the node Docker Image.
``` shell
cartesi deploy build --platform linux/amd64
```

Finally, run the Cartesi Node
``` shell
docker run --env-file <.node.env> -p 10000:10000 --add-host host.docker.internal=host-gateway <cartesi-machine-image-id>
```

## 5 - Interacting with the Cartesi Rollup Application
After deploying the application and running the Cartesi Node, you can normally interact with it using the [cartesi-cli](https://www.npmjs.com/package/@cartesi/cli). Use the `cartesi send` command to send an input to your dapp.

> [!TIP]
> You can get your DApp address in the <machine_hash>.env file

``` shell
cartesi send generic --dapp <dapp_address> --input <payload>
```

