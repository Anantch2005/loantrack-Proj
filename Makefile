.PHONY: deploy destroy

deploy:
	./scripts/deploy.sh

destroy:
	kubectl delete namespace loantrack --ignore-not-found