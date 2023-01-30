.ONESHELL:

ENVFILE := .env
include $(ENVFILE)

SERVICE := aws-vault-terraform

DOCKER_COMPOSE       = docker-compose run --rm $(SERVICE)
DOCKER_COMPOSE_NOTTY = docker-compose run --rm -T $(SERVICE)
AWS_VAULT            = $(DOCKER_COMPOSE) aws-vault exec $(AWS_USER)
AWS_CLI              = $(AWS_VAULT) -- aws
AWS_STATE_DIR       := .awsstate
AWS_PROFILES_FILE   := $(AWS_STATE_DIR)/.profiles
AWS_PROFILES         = $(shell $(DOCKER_COMPOSE) /bin/sh -c "cat $(AWS_PROFILES_FILE) | grep -v default | grep -v $(AWS_USER)")

init: # generate a key, store access keys and configure aws profiles
	mkdir -p .gnupg .password-store .aws .awsstate .history
	chmod go-rwxs .gnupg .password-store .aws .awsstate .history
	$(MAKE) .gnupg
	$(MAKE) .password-store
	$(MAKE) .aws
	printf '? remove $(ENVFILE) [y/N] '
	read yn
	if [ "$$yn" = 'y' ]; then
		rm -f $(ENVFILE)
	fi

.gnupg: .gnupg/gpg-agent.conf
.gnupg/gpg-agent.conf: .gnupg/gpg-batch.conf
	echo default-cache-ttl 10800 | tee $@
	chmod 600 $@
	$(DOCKER_COMPOSE) gpg --full-generate-key --batch .gnupg/gpg-batch.conf
.gnupg/gpg-batch.conf:
	printf '? empty passphrase [y/N] ' && read yn
	[ "$$yn" = 'y' ] && echo %no-protection | tee -a $@
	cat <<- EOF | tee -a $@
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

.PHONY: init .gnupg .password-store .aws

env: # view sub-process environments
	$(AWS_VAULT) -- env

.PHONY: env

help: # list available targets and some
	@len=$$(awk -F':' 'BEGIN {m = 0;} /^[^\s]+:/ {gsub(/%/, "<service>", $$1); l = length($$1); if(l > m) m = l;} END {print m;}' $(MAKEFILE_LIST)) && \
	printf "%s%s\n\n%s\n%s\n\n%s\n%s\n" \
		"usage:" \
		"$$(printf " make <\033[1mtarget\033[0m>")" \
		"services:" \
		"$$(docker-compose config --services | awk '{ $$1 == "$(SERVICE)" ? x = "* " : x = ""; } { printf("  \033[1m%s%s\033[0m\n", x, $$1); }')" \
		"targets:" \
		"$$(awk -F':' '/^\S+:/ {gsub(/%/, "<service>", $$1); gsub(/^[^#]+/, "", $$2); gsub(/^[# ]+/, "", $$2); if ($$2) printf "  \033[1m%-'$$len's\033[0m  %s\n", $$1, $$2;}' $(MAKEFILE_LIST))"

clean: # remove cache files from the working directory
	$(MAKE) -C ec2 clean
	$(DOCKER_COMPOSE) rm -rf \
		.gnupg/* .gnupg/.[!.]* .gnupg/..?* \
		.password-store/* .password-store/.[!.]* .password-store/..?*
		.aws/* \
		$(AWS_STATE_DIR)/* $(AWS_STATE_DIR)/.profiles \

.PHONY: help clean

#
# docker
#
build: build/$(SERVICE)
build/%: # build or rebuild a image
	docker-compose build $*

run: run/$(SERVICE)
run/%: # run a one-off command on a container
	docker-compose run --rm $* /bin/sh -c "/bin/bash || /bin/sh"

exec: exec/$(SERVICE)
exec/%: # run a command in a running container
	docker-compose exec $* /bin/sh

up: # create and start containers, networks, and volumes
	docker-compose up -d
up/%: # create and start a container
	docker-compose up -d $*

down: # stop and remove containers, networks, images, and volumes
	docker-compose down
down/%: # stop and remove a container
	docker-compose rm -fsv $*

log: logs
log/%: logs/$*
logs: logs/$(SERVICE)
logs/%: # view output from containers
	docker-compose logs -f $*

.PHONY: build build/% run run/% up up/% exec exec/% down down/% log log/% logs logs/%

#
# aws
#
profiles: $(AWS_PROFILES_FILE)
$(AWS_PROFILES_FILE):
	$(DOCKER_COMPOSE_NOTTY) /bin/sh -c "aws configure list-profiles > $@"

.PHONY: $(AWS_PROFILES_FILE)

# ec2
ec2: profiles # ec2 command-line user interface
	$(MAKE) -C ec2

.PHONY: ec2
