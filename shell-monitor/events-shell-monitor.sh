#!/usr/bin/env sh
#
# Skip all calico-node pods that have failed readiness probes or liveness
#   probes, because they fail these probes for any inter-node connectivity
#   blips.
# They can be super noisy.
jq_script='.items[] |
	select(
		.involvedObject.namespace == "kube-system"
		and (.involvedObject.name | test("^calico-node"))
		and (.message == "Readiness probe failed: " or .message == "Liveness probe failed: ") | not) |
	select(
		.involvedObject.namespace == "kube-system"
		and (.involvedObject.name | test("^calico-kube-controllers"))
		and (.message == "Readiness probe failed: ") | not) |
	select(
		.involvedObject.namespace == "metallb-system"
		and (.involvedObject.name | test("^speaker"))
		and ((.message | startswith("Readiness probe failed: ")) or (.message | startswith("Liveness probe failed: "))) | not) |
	"\(.metadata.creationTimestamp) (\(.count)) \(.source.host)/\(.involvedObject.namespace)/\(.involvedObject.name)\n  \(.message)"'

echo ""
kubectl get events \
	--sort-by='.metadata.creationTimestamp' \
	--field-selector "type!=Normal" -A -o json | jq -r "$jq_script"
