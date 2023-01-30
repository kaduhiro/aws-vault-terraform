ARG TERRAFORM_VERSION=1.1.4

FROM hashicorp/terraform:${TERRAFORM_VERSION}
LABEL maintainer="kaduhiro <github@kaduhiro.com>"

RUN apk update
RUN apk --no-cache add binutils curl expect gnupg go jq make pass tini

# AWS CLI
ARG GLIBC_VERSION=2.33-r0
RUN curl -fsSL https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub -o /etc/apk/keys/sgerrand.rsa.pub \
    && curl -fsSLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
    && curl -fsSLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}.apk \
    && apk add --no-cache glibc-${GLIBC_VERSION}.apk glibc-bin-${GLIBC_VERSION}.apk

ARG AWSCLI_VERSION=2.7.11
RUN curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m)-${AWSCLI_VERSION}.zip -o awscliv2.zip \
    && unzip -q awscliv2.zip \
    && aws/install \
    && rm -rf awscliv2.zip aws

# AWS Vault
ARG AWSVAULT_VERSION=6.6.0
RUN curl -fsSL https://github.com/99designs/aws-vault/releases/download/v${AWSVAULT_VERSION}/aws-vault-linux-$(uname -m | sed 's/x86_64/amd64/') -o /usr/local/bin/aws-vault \
    && chmod 755 /usr/local/bin/aws-vault

RUN rm -rf /var/cache/apk/*

# user
ARG USER=terraform
ARG GROUP=terraform
ARG UID=1000
ARG GID=1000
RUN addgroup -g $GID $GROUP \
    && adduser -D -h /home/$USER -u $UID -G $GROUP $USER

USER $USER
WORKDIR /home/$USER

# entrypoint
ENTRYPOINT ["/sbin/tini", "--"]
