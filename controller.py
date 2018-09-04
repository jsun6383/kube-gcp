from helpers import concat_names
from instance import Instance


class Controller(Instance):

    def __init__(self, context, vpc, instance_name, ip, controller_mapping):
        Instance.__init__(self, context, vpc, instance_name,
                          "startup-script", "controllerStartupScript")
        self.ip = ip

        self.controller_mapping = ""
        self.controller_ips = ""
        # converting a python list to a comma delimited list so it can be passed to shell script
        for name, ip in controller_mapping.iteritems():
            # adding base_name to name
            name = concat_names(
                [context.env['deployment'], context.env['name'], name])
            if self.controller_mapping == "":
                self.controller_mapping = name + "=" + "https://" + ip + ":PORT"
                self.controller_ips = ip
            else:
                self.controller_mapping = self.controller_mapping + \
                    "," + name + "=" + "https://" + ip + ":PORT"
                self.controller_ips = self.controller_ips + "," + ip

    def create_controller(self, public_address, vpc_cidr):

        instance = self.create_instance()
        instance['properties']['networkInterfaces'][0]['networkIP'] = self.ip
        instance['properties']['metadata']['items'].extend(
            [
                {
                    "key": "cfsslIP",
                    "value": self.context.properties["cfsslIP"]
                },
                {
                    "key": "controllerMapping",
                    "value": self.controller_mapping
                },
                {
                    "key": "controllerIPs",
                    "value": self.controller_ips
                },
                {
                    "key": "publicIP",
                    "value": "$(ref." + public_address.name + ".address)"
                },
                {
                    "key": "vpcCIDR",
                    "value": vpc_cidr
                },
                {
                    "key": "clusterCIDR",
                    "value": self.context.properties['kubeClusterCIDR']
                },
                {
                    "key": "serviceClusterCIDR",
                    "value": self.context.properties['kubeServiceClusterCIDR']
                }
            ]
        )

        instance['metadata'] = {
            "dependsOn": [
                public_address.name
            ]
        }

        return instance
