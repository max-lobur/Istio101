#	Copyright 2018, Google, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

JAEGER_POD_NAME=$( kubectl -n istio-system get pod -l app=jaeger -o jsonpath='{.items[0].metadata.name}')
JAEGER_PORT=16686

SERVICEGRAPH_POD_NAME=$( kubectl -n istio-system get pod -l app=servicegraph -o jsonpath='{.items[0].metadata.name}')
SERVICEGRAPH_PORT=8088

GRAFANA_POD_NAME=$( kubectl -n istio-system get pod -l app=grafana -o jsonpath='{.items[0].metadata.name}')
GRAFANA_PORT=3000

PROMETHEUS_POD_NAME=$( kubectl -n istio-system get pod -l app=prometheus -o jsonpath='{.items[0].metadata.name}')
PROMETHEUS_PORT=9090

CONTAINER_NAME=istiotest

build:
	docker build -t lobur/istiotest:1.0 ./code/code-only-istio
	docker build -t lobur/istio-opencensus-simple:1.0 ./code/code-opencensus-simple
	docker build -t lobur/istio-opencensus-full:1.0 ./code/code-opencensus-full

push:
	docker push lobur/istiotest:1.0
	docker push lobur/istio-opencensus-simple:1.0
	docker push lobur/istio-opencensus-full:1.0

deploy-istio:
	kubectl create namespace istio-system
	kubectl apply -f istio.yaml
	kubectl label namespace default istio-injection=enabled --overwrite

start-monitoring-services:
	$( kubectl -n istio-system port-forward $(JAEGER_POD_NAME) $(JAEGER_PORT):$(JAEGER_PORT) & kubectl -n istio-system port-forward $(SERVICEGRAPH_POD_NAME) $(SERVICEGRAPH_PORT):$(SERVICEGRAPH_PORT) & kubectl -n istio-system port-forward $(GRAFANA_POD_NAME) $(GRAFANA_PORT):$(GRAFANA_PORT) & kubectl -n istio-system port-forward $(PROMETHEUS_POD_NAME) $(PROMETHEUS_PORT):$(PROMETHEUS_PORT))
    $( echo "Jaeger: http://localhost:$JAEGER_PORT")
    $( echo "Grafana: http://localhost:$GRAFANA_PORT")
    $( echo "Prometheus: http://localhost:PROMETHEUS_PORT")
    $( echo "ServiceGraph: http://localhost:SERVICEGRAPH_PORT")

deploy-stuff:
	kubectl apply -f ./configs/kube/services.yaml
	kubectl apply -f ./configs/kube/deployments.yaml

get-stuff:
	kubectl get pods && kubectl get svc && kubectl get svc istio-ingressgateway -n istio-system

ingress:
	kubectl apply -f ./configs/istio/ingress.yaml

egress:
	kubectl apply -f ./configs/istio/egress.yaml

prod:
	kubectl apply -f ./configs/istio/destinationrules.yaml
	kubectl apply -f ./configs/istio/routing-1.yaml

retry:
	kubectl apply -f ./configs/istio/routing-2.yaml

canary:
	kubectl apply -f ./configs/istio/routing-3.yaml

cleanup:
	kubectl delete ns istio101 istio-system

start-opencensus-demo: deploy-stuff ingress egress prod

deploy-opencensus-code:
	kubectl apply -f ./configs/opencensus/config.yaml
	-sed -e 's~<PROJECT_ID>~$(PROJECT_ID)~g' ./configs/opencensus/deployment.yaml | kubectl apply -f -

update-opencensus-deployment:
	kubectl apply -f ./configs/kube/services2.yaml
	-sed -e 's~<PROJECT_ID>~$(PROJECT_ID)~g' ./configs/opencensus/deployment2.yaml | kubectl apply -f -