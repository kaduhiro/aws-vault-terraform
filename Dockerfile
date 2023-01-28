ARG UBUNTU_VERSION=22.10

FROM ubuntu:${UBUNTU_VERSION}
LABEL maintainer="kaduhiro <kaduhiro@github.com>"

ARG AWSVAULT_VERSION=6.6.0
ARG AWSCLI_VERSION=2.7.11

RUN apt update && apt upgrade -y
RUN apt install -y tzdata

RUN apt install -y \
    bsdmainutils \
    curl \
    expect \
    gnupg \
    jq \
    pass \
    unzip


RUN curl -fsSL \
    -o awscliv2.zip \
    https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m)-${AWSCLI_VERSION}.zip \
    && unzip awscliv2.zip \
    && aws/install

RUN curl -fsSL \
    -o /usr/local/bin/aws-vault \
    https://github.com/99designs/aws-vault/releases/download/v${AWSVAULT_VERSION}/aws-vault-linux-$(uname -m | sed 's/x86_64/amd64/') \
    && chmod 755 /usr/local/bin/aws-vault

RUN apt clean \
    && rm -rf \
    awscliv2.zip \
    aws
