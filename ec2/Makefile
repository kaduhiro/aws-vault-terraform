.ONESHELL:

ENVFILE := ../.env
include $(ENVFILE)

HISTORY_FILE := .history

EC2_USER           := ec2-user
EC2_STATE_DIR      := $(AWS_STATE_DIR)/ec2
EC2_INSTANCES_FILE := $(EC2_STATE_DIR)/instances.tsv
EC2_INSTANCE_FILE  := instance.json

INPUT   = $$(tail -1 $(HISTORY_FILE))
COMMAND = $$(echo $(INPUT) | awk '{print $$1}')
TARGET  = $$(echo $(INPUT) | awk '{print $$NF}')

INSTANCE_PROFILE    = $$($(DOCKER_COMPOSE) jq -r "[.[$(TARGET)].EC2.Profile] | unique | .[0]" $(EC2_INSTANCES_JSON))
INSTANCE_NAME       = $$($(DOCKER_COMPOSE) jq -r "[.[$(TARGET)].EC2.Name] | @sh" $(EC2_INSTANCES_JSON))
INSTANCE_ID         = $$($(DOCKER_COMPOSE) jq -r "[.[$(TARGET)].EC2.InstanceId] | @tsv" $(EC2_INSTANCES_JSON))
INSTANCE_PRIVATE_IP = $$($(DOCKER_COMPOSE) jq -r ".[$(TARGET)].EC2.PrivateIp" $(EC2_INSTANCES_JSON))

default: cui

input:
	echo "? usage: [pull|start|stop|ssh|quit] [target]"
	read -p '? ' i
	echo $$i >> $(HISTORY_FILE)

cui:
	while :; do
		$(MAKE) $(EC2_INSTANCES_FILE)
		$(MAKE) input
		case "$(COMMAND)" in
		pull)
			$(MAKE) pull
			;;
		start)
			;;
		stop)
			;;
		ssh)
			ssh -A $(EC2_USER)@$(INSTANCE_PRIVATE_IP)
			;;
		exit|quit|q)
			break
			;;
		*)
			echo ! UNKNOWN COMMAND:$(COMMAND), TARGET:$(TARGET)
		esac
	done

pull:
	$(MAKE) -C .. env profiles
	$(MAKE) -B -j3 $(addprefix $(EC2_STATE_DIR)/,$(addsuffix /$(EC2_INSTANCE_FILE),$(AWS_PROFILES)))

$(EC2_STATE_DIR)/%/$(EC2_INSTANCE_FILE):
	echo "! Pull ec2 instances in $* ... "
	$(DOCKER_COMPOSE_NOTTY) /bin/sh -c "
		mkdir -p $(dir $@) &&
		aws-vault exec $* -- \
			aws ec2 describe-instances \
			--output=json \
			--query \"
				Reservations[].Instances[].{
					Profile: '$*',
					InstanceId: InstanceId,
					PrivateIp: join(', ', NetworkInterfaces[].PrivateIpAddress),
					PublicIp: join(', ', NetworkInterfaces[].Association.PublicIp),
					Platform: Platform,
					State: State.Name,
					SecurityGroupId: join(', ', SecurityGroups[].GroupId),
					Name: Tags[?Key=='Name'].Value|[0]
				}
			\" > $@
	"
	echo "✓ Complete, $*"

$(EC2_INSTANCES_FILE):
	$(DOCKER_COMPOSE) /bin/sh -c "
		jq -s add $(EC2_STATE_DIR)/*/$(EC2_INSTANCE_FILE) | \
		jq -r '
			sort_by(.Name) |
			[{\"Profile\": \"PROFILE\", \"Name\": \"NAME\", \"PrivateIp\": \"PRIVATE IP\", \"PublicIp\": \"PUBLIC IP\", \"State\": \"STATE\"}] + . |
			to_entries | map({\"Index\": .key, \"EC2\": .value}) | . [] |
			[.Index, .EC2.Profile, .EC2.Name, .EC2.PrivateIp, .EC2.PublicIp, .EC2.State] | @tsv
		' | \
		column -t -s '	'
	"

# help
.PHONY: help
help: # 
	@echo -e "usage: make <\033[1mtarget\033[0m>\n"
	@awk 'BEGIN {FS = ":"} /^[0-9a-zA-Z_/%%]+:/ {gsub(/^[^#]+/, "", $$2); gsub(/^[# ]+/, "", $$2); printf "\033[1m%s\033[0m %s\n", $$1, $$2;}' $(MAKEFILE_LIST) | column -t 

# clean
.PHONY: clean
clean: # Delete caches
	rm $(HISTORY_FILE)
	$(DOCKER_COMPOSE) rm -rf \
		$(EC2_STATE_DIR)/* \
		$(EC2_INSTANCES_JSON) \
		$(EC2_INSTANCES_TSV)
