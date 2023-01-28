.ONESHELL:

ENVFILE := .env
include $(ENVFILE)

DOCKER_COMPOSE       = docker-compose --env-file $(ENVFILE) exec aws-vault-terraform
DOCKER_COMPOSE_NOTTY = docker-compose --env-file $(ENVFILE) exec -T aws-vault-terraform
AWS_VAULT            = $(DOCKER_COMPOSE) aws-vault exec $(AWS_USER)
AWS_CLI              = $(AWS_VAULT) -- aws
AWS_STATE_DIR       := .awsstate
AWS_PROFILES_FILE   := $(AWS_STATE_DIR)/.profiles
AWS_PROFILES         = $(shell $(DOCKER_COMPOSE) /bin/sh -c "cat $(AWS_PROFILES_FILE) | grep -v default | grep -v $(AWS_USER)")

env: # view sub-process environments
	$(AWS_VAULT) -- env

.PHONY: init .gnupg .password-store .aws
init: # generate a key, store access keys and configure aws profiles
	$(MAKE) .gnupg
	$(MAKE) .password-store
	$(MAKE) .aws

.gnupg: .gnupg/gpg-agent.conf
	chmod 700 $@
.gnupg/gpg-agent.conf: .gnupg/gpg-batch.conf
	$(DOCKER_COMPOSE) gpg --full-generate-key --batch .gnupg/gpg-batch.conf
	echo default-cache-ttl 10800 > $@
	chmod 600 $@
.gnupg/gpg-batch.conf:
	echo -n "? empty passphrase? [y/N] "
	read yn
	if [ "$$yn" = 'y' ]; then
		echo %no-protection >> $@
	fi
	cat <<- EOF >> $@
	Key-Type: RSA
	Key-Length: 3072
	Key-Usage: sign,cert
	Subkey-Type: RSA
	Subkey-Length: 3072
	Subkey-Usage: encrypt
	Name-Real: $(NAME)
	Name-Email: $(EMAIL)
	Expire-Date: 0
	%commit
	%echo done
	EOF

.password-store: .password-store/aws-vault
.password-store/aws-vault:
	$(DOCKER_COMPOSE) pass init $(EMAIL)
	$(DOCKER_COMPOSE) expect -c "
		set     timeout 10;
		spawn   aws-vault add $(AWS_USER);
		expect  \"Enter Access Key ID:\";
		send -- \"$(AWS_ACCESS_KEY)\n\";
		expect  \"Enter Secret Access Key:\";
		send -- \"$(AWS_SECRET_ACCESS_KEY)\n\";
		expect;
		exit 0;
	"

.aws: .aws/config
.aws/config: $(addprefix .aws/assume/,$(AWS_ASSUME_ROLES))
	$(DOCKER_COMPOSE) \
		aws \
		configure set region $(AWS_REGION)
	$(DOCKER_COMPOSE) \
		aws \
		--profile $(AWS_USER) \
		configure set mfa_serial arn:aws:iam::$(AWS_ACCOUNT_ID):mfa/$(AWS_USER)
.aws/assume/%:
	$(DOCKER_COMPOSE) \
		aws \
		--profile $(word 1,$(subst /, ,$*)) \
		configure set source_profile $(AWS_USER)
	$(DOCKER_COMPOSE) \
		aws \
		--profile $(word 1,$(subst /, ,$*)) \
		configure set role_arn arn:aws:iam::$(word 2,$(subst /, ,$*)):role/$(word 3,$(subst /, ,$*))

# aws
.PHONY: $(AWS_PROFILES_FILE)
profiles: $(AWS_PROFILES_FILE)
$(AWS_PROFILES_FILE):
	$(DOCKER_COMPOSE_NOTTY) /bin/sh -c "aws configure list-profiles > $@"

# ec2
.PHONY: ec2
ec2: profiles # ec2 command-line user interface
	$(MAKE) -C ec2

# docker
DOCKER_SERVICE := aws-vault-terraform

.PHONY: network build build/% run run/% up up/% exec exec/% down down/%
network: # create internal network on docker
	docker network create --subnet=192.168.0.0./16 internal

build: build/$(DOCKER_SERVICE)
build/%: # build or rebuild service
	docker-compose build $*

run: run/$(DOCKER_SERVICE)
run/%: # run a one-off command on a service
	docker-compose run --rm $* /bin/sh

up: up/$(DOCKER_SERVICE)
up/%: # create and start container
	docker-compose up -d $*

exec: exec/$(DOCKER_SERVICE)
exec/%: # run a command in a running container
	docker-compose exec -it $* /bin/sh

down: down/$(DOCKER_SERVICE)
down/%: # stop and remove container
	docker-compose rm -fsv $*

.PHONY: help clean
help: # list available targets and some
	@echo "usage: make <\033[1mtarget\033[0m>\n"
	@len=$$(awk -F':' 'BEGIN {m = 0;} /^[0-9a-zA-Z_\/%%]+:/ {l = length($$1); if(l > m) m = l;} END {print m;}' $(MAKEFILE_LIST))
	@awk -F':' '/^[0-9a-zA-Z_\/%%]+:/ {gsub(/^[^#]+/, "", $$2); gsub(/^[# ]+/, "", $$2); if ($$2) printf "\033[1m%-'$$len's\033[0m\t%s\n", $$1, $$2;}' $(MAKEFILE_LIST)

clean: # remove cache files from the working directory
	$(MAKE) -C ec2 clean
	$(DOCKER_COMPOSE) rm -rf \
		.aws/* \
		$(AWS_STATE_DIR)/* $(AWS_STATE_DIR)/.profiles \
		.gnupg/* .gnupg/.[!.]* .gnupg/..?* \
		.password-store/* .password-store/.[!.]* .password-store/..?*
