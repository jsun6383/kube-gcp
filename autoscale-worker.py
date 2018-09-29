from helpers import gen_name, zonal_compute_url, global_compute_url

class Worker:
    
    def __init__(self, context, name, min_size, max_size):
        self.min_size = min_size
        self.max_size = max_size
        self.context = context
        self.name = gen_name(context, name)


    def create_autoscaler(self):
        
        instance_group = self.create_instance_group()
        instance_group_manager = self.create_instance_group_manager()
        instance_template = self.create_instance_template()

        autoscaler = {
            "target": "$(ref." + self.name + "-instance-group-manager.selfLink)",
            "zone": self.context.properties["zone"],
            "region": self.context.properties["region"],
            "autoscalingPolicy": {
                "minNumReplicas": self.min_size,
                "maxNumReplicas": self.max_size,
                "coolDownPeriodSec": 60,
                "cpuUtilization": {
                    "utilizationTarget": 0.65
                }
            }
        }

        resources =[
            {
                "name": self.name + "-autoscaler",
                "type": "compute.v1.autoscaler",
                "properties": autoscaler
            },
            instance_group,
            instance_group_manager,
            instance_template
        ]

        return resources

    def create_instance_group_manager(self):

        instance_group_manager = {
            "zone": self.context.properties["zone"],
            "instanceGroup": "$(ref." + self.name + "-instance-group.selfLink)",
            "region": self.context.properties["region"],
            "instanceTemplate": "$(ref." + self.name + "-instance-template.selfLink)",
            "baseInstanceName": self.name,
            "targetSize": 2
        }

        return {
            "name": self.name + "-instance-group-manager",
            "type": "compute.v1.instanceGroupManager",
            "properties": instance_group_manager
        }

    def create_instance_group(self):

        instance_group = {
            "network": self.context.properties["vpcRef"],
            "zone": self.context.properties["zone"]
        }

        return {
            "name": self.name + "-instance-group",
            "type": "compute.v1.instanceGroup",
            "properties": instance_group
        }

    def create_instance_template(self):

        instance_template = {
            "machineType": self.context.properties['instanceType'],
            "networkInterfaces": [
                {
                    "network": self.context.properties["vpcRef"],
                    "accessConfigs": [{
                        "name": "external-nat",
                        "type": "ONE_TO_ONE_NAT"
                }],
                }
            ],
            "disks": [{
                "deviceName": "boot",
                "type": "PERSISTENT",
                "autoDelete": True,
                "boot": True,
                "initializeParams": {
                    "diskSizeGb": self.context.properties['diskSize'],
                    "sourceImage": global_compute_url(self.context.properties["instanceProject"],
                                                      "images",
                                                      self.context.properties["instanceImage"])
                },
            }],
            "metadata": {
                "items": [{
                    "key": "startup-script",
                    "value": self.context.imports[
                        self.context.properties["workerStartupScript"]],
                }]
            },
            "serviceAccounts": [{
                "email": "default",
                "scopes": [
                    "https://www.googleapis.com/auth/logging.write",
                    "https://www.googleapis.com/auth/monitoring.write",
                    "https://www.googleapis.com/auth/devstorage.full_control"
                ]
            }]
        }

        resource = {
            "name": self.name + "-instance-template",
            "type": "compute.v1.instanceTemplate",
            "properties": {
                "properties": instance_template
            }
        }

        return resource


    