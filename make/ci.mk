.PHONY: ci-presubmit
ci-presubmit: verify-imports verify-chart

.PHONY: verify-imports
verify-imports: bin/tools/goimports
	./hack/verify-goimports.sh $<

.PHONY: verify-crds
verify-crds: | bin/tools/controller-gen bin/tools/yq
	./hack/verify-crds.sh ./hack/update-crds.sh $(GOBINPATH) $(CONTROLLER_GEN) $(YQ)

.PHONY: verify-chart
verify-chart: bin/cert-manager-$(RELEASE_VERSION).tgz
	./hack/verify-chart-version.sh $<
