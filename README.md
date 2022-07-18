# aws-vault-terraform

## Usage

```
usage: make <target>

env             view sub-process environments
init            generate a key, store access keys and configure aws profiles
ec2             ec2 command-line user interface
network         create internal network on docker
build/%         build or rebuild service
run/%           run a one-off command on a service
up/%            create and start container
exec/%          run a command in a running container
down/%          stop and remove container
help            list available targets and some
clean           remove cache files from the working directory
```

## Initialize

1. create environment file from template

```
cp .env.template .env
```

2. set configuration

```
AWS_USER              = # admin
AWS_REGION            = # ap-northeast-1
AWS_ACCOUNT_ID        = # 000000000000
AWS_ACCESS_KEY        = # XXXXXXXXXXXXXXXXXXXX
AWS_SECRET_ACCESS_KEY = # XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

AWS_ASSUME_ROLES      = # profile1/000000000000/AdminRole profile2/000000000000/AdminRole ...
```
