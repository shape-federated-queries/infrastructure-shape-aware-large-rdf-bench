# Deploy the LargeRDFBench QLever SPARQL endpoints, one per Virtual Wall node.
# The topology (dataset -> node) comes from INVENTORY; MODE picks the QLever
# cache mode (experiment: cache off, shapes: cache on).

INVENTORY ?= inventory.yml
MODE ?= experiment
PLAYBOOKS := deploy.yml serve.yml

.PHONY: deps ping check deploy serve health stop

deps:        # Install the Ansible collections this repo needs
	ansible-galaxy collection install -r requirements.yml

ping:        # Reachability of all machines
	ansible qlever -i $(INVENTORY) -m ping

check:       # Syntax-check every playbook
	@for pb in $(PLAYBOOKS); do ansible-playbook -i $(INVENTORY) --syntax-check $$pb; done

deploy: deps # Provision the nodes, download the data, index and serve every endpoint in MODE
	ansible-playbook -i $(INVENTORY) -e qlever_mode=$(MODE) deploy.yml

serve:       # Restart every endpoint in MODE (index reused; needs a completed deploy)
	ansible-playbook -i $(INVENTORY) -e qlever_mode=$(MODE) serve.yml

health:      # Per container: status, cache mode, restart count, OOM-killed
	ansible qlever -i $(INVENTORY) -m shell -a 'for c in $$(docker ps -aq --filter name=^qlever-); do docker inspect -f "{% raw %}{{.Name}} {{.State.Status}} mode={{index .Config.Labels \"qlever.mode\"}} restarts={{.RestartCount}} oom_killed={{.State.OOMKilled}}{% endraw %}" $$c; done'

stop:        # Remove every QLever container (indexes and data are kept)
	ansible qlever -i $(INVENTORY) -m shell -a 'docker rm -f $$(docker ps -aq --filter name=^qlever-) 2>/dev/null || true'
