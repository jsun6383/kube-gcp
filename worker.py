from instance import Instance


class Worker(Instance):

    def __init__(self, context, vpc, instance_name, ip, pod_cidr):
        Instance.__init__(self, context, vpc, instance_name,
                          "startup-script", "workerStartupScript")
        self.ip = ip
        self.pod_cidr = pod_cidr

    def create_worker(self, public_address):

        instance = self.create_instance()
        instance['properties']['networkInterfaces'][0]['networkIP'] = self.ip
        instance['properties']['metadata']['items'].extend(
            [
                {
                    "key": "podCIDR",
                    "value": self.pod_cidr
                },
                {
                    "key": "instanceName",
                    "value": self.instance_name
                },
                {
                    "key": "cfsslIP",
                    "value": self.context.properties["cfsslIP"]
                },
                {
                    "key": "publicIP",
                    "value": "$(ref." + public_address.name + ".address)"
                }
            ]
        )

        return instance
