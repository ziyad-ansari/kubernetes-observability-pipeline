.PHONY: fmt validate json-check prereqs smoke

fmt:
	terraform -chdir=terraform fmt -recursive

validate:
	terraform -chdir=terraform init -backend=false -input=false
	terraform -chdir=terraform validate

json-check:
	jq empty dashboards/logs-dashboard.json
	jq empty dashboards/metrics-dashboard.json

prereqs:
	./scripts/check_prereqs.sh

smoke:
	./scripts/smoke_test.sh
