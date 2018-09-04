stack_name := kube
config_file := kube-cluster.yaml

preview:
	gcloud deployment-manager deployments create $(stack_name) --config $(config_file) --preview

create:
	gcloud deployment-manager deployments create $(stack_name) --config $(config_file)

delete:
	gcloud deployment-manager deployments delete $(stack_name) -q

update: 
	gcloud deployment-manager deployments update $(stack_name) --config $(config_file)

update-preview: 
	gcloud deployment-manager deployments update $(stack_name) --config $(config_file) --preview
