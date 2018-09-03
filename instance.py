from helpers import concat_names, global_compute_url, zonal_compute_url

class Instance:

    def __init__(self, context, vpc, instance_name, meta_key, meta_value):
        self.vpc = vpc
        self.context = context
        self.meta_key = meta_key
        self.meta_value = meta_value
        self.instance_name = concat_names(
            [context.env['deployment'], context.env['name'], instance_name])

    def create_instance(self):

        instance = {
            "zone": self.context.properties["zone"],
            "machineType": zonal_compute_url(self.context.env["project"],
                                             self.context.properties["zone"],
                                             "machineTypes",
                                             self.context.properties['instanceType']),
            "metadata": {
                "items": [{
                    "key": self.meta_key,
                    "value": self.context.imports[
                        self.context.properties[self.meta_value]],
                }]
            },
            "disks": [{
                "deviceName": "boot",
                "type": "PERSISTENT",
                "autoDelete": True,
                "boot": True,
                "initializeParams": {
                    "diskName": self.instance_name + "-disk",
                    "diskSizeGb": self.context.properties['diskSize'],
                    "sourceImage": global_compute_url(self.context.properties["instanceProject"],
                                                      "images",
                                                      self.context.properties["instanceImage"])
                },
            }],
            "networkInterfaces": [{
                "accessConfigs": [{
                    "name": "external-nat",
                    "type": "ONE_TO_ONE_NAT"
                }],
                "network": self.vpc
            }],
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
            "name": self.instance_name,
            "type": "compute.v1.instance",
            "properties": instance
        }

        return resource
