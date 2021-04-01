# > CONSTANTS
PATTERN_BEGIN=»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»»
PATTERN_END=«««««««««««««««««««««««««««««««««««««««««««««

BUILDPACK_BUILDER=heroku/buildpacks:18

SIMULATOR_NETWORK_NAME=net_energysim

MODEL_PACK_NAME=pack_energysim_model_travel_duration
MODEL_CONTAINER_NAME=cont_energysim_model_travel_duration
MODEL_BACKDOOR=3000
MODEL_PORTS=8007:8000

RABBIT_CONTAINER_NAME=cont_energysim_rabbitmq
RABBIT_USER=guest
RABBIT_PASSWORD=guest
RABBIT_PORT=5672
RABBIT_MANAGEMENT_PORT=15672
# < CONSTANTS

main: stop-docker-model run-docker-model

check-dependencies:
	@echo '$(PATTERN_BEGIN) CHECKING DEPENDENCIES...'

	@if ( pip3 list | grep -F pipreqs > /dev/null 2>&1 ) ; then \
		echo "pipreqs already installed!" ; \
	else \
		echo "pipreqs not installed! installing..." && pip3 install pipreqs; \
	fi	

	@if ( dpkg -l pack-cli > /dev/null 2>&1 ) ; then \
		echo "pack already installed!" ; \
	else \
		echo "pack not installed! please install..."; \
		exit 1; \
	fi			

	@bash -c 'source ~/.profile'		

	@echo '$(PATTERN_END) DEPENDENCIES CHECKED!'	

# > MODEL
run-docker-model: build-docker-model start-docker-model

build-docker-model:
	@echo '$(PATTERN_BEGIN) BUILDING `$(MODEL_CONTAINER_NAME)` PACK...'

	@pipreqs --force --savepath requirements.txt.tmp
	@sed -i 's/tensorflow/tensorflow-cpu/g' requirements.txt.tmp
	@sort -r requirements.txt.tmp > requirements.txt.tmp.sorted
	@if cmp -s requirements.txt.tmp.sorted requirements.txt; then :;\
	else cp -f requirements.txt.tmp.sorted requirements.txt; fi
	@rm -f requirements.txt.tmp
	@rm -f requirements.txt.tmp.sorted
	
	@pack build $(MODEL_PACK_NAME) \
	--builder $(BUILDPACK_BUILDER) \
	--pull-policy if-not-present \
	--verbose

	@echo '$(PATTERN_END) `$(MODEL_CONTAINER_NAME)` PACK BUILT!'

start-docker-model:
	@echo '$(PATTERN_BEGIN) STARTING `$(MODEL_CONTAINER_NAME)` PACK...'

	@docker run -d \
	--name $(MODEL_CONTAINER_NAME) \
	--network $(SIMULATOR_NETWORK_NAME) \
	-e RABBIT_USER=$(RABBIT_USER) \
	-e RABBIT_PASSWORD=$(RABBIT_PASSWORD) \
	-e RABBIT_HOST=$(RABBIT_CONTAINER_NAME) \
	-e RABBIT_MANAGEMENT_PORT=$(RABBIT_MANAGEMENT_PORT) \
	-e RABBIT_PORT=$(RABBIT_PORT) \
	-p $(MODEL_PORTS) \
	$(MODEL_PACK_NAME)
	
	@echo '$(PATTERN_END) `$(MODEL_CONTAINER_NAME)` PACK STARTED!'

stop-docker-model:
	@echo '$(PATTERN_BEGIN) STOPPING `$(MODEL_CONTAINER_NAME)` PACK...'

	@( docker rm -f $(MODEL_CONTAINER_NAME) ) || true

	@echo '$(PATTERN_END) `$(MODEL_CONTAINER_NAME)` PACK STOPPED!'	
# < MODEL

# > NAMEKO
run-nameko-model: prep-nameko-model start-nameko-model

prep-nameko-model:
	@until nc -z $(RABBIT_CONTAINER_NAME) $(RABBIT_PORT); do \
	echo "$$(date) - waiting for rabbitmq..."; \
	sleep 2; \
	done

start-nameko-model:
	@nameko run model.service \
	--config nameko-config.yml  \
	--backdoor $(MODEL_BACKDOOR)
# < NAMEKO