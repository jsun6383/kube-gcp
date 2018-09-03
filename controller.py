from helpers import concat_names
from instance import Instance

class Controller(Instance):

    def __init__(self, context, vpc, instance_name, ip, controller_mapping):
        Instance.__init__(self, context, vpc, instance_name, "startup-script", "controllerStartupScript")
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
                self.controller_mapping = self.controller_mapping + "," + name + "=" + "https://" + ip + ":PORT"
                self.controller_ips = self.controller_ips + "," + ip


    def create_controller(self, public_address):

        instance = self.create_instance()
        instance['properties']['networkInterfaces'][0]['networkIP'] = self.ip
        instance['properties']['metadata']['items'].append(
            {
                "key": "cfsslIP",
                "value": self.context.properties["cfsslIP"]
            }
        )
        instance['properties']['metadata']['items'].append(
            {
                "key": "controllerMapping",
                "value": self.controller_mapping
            }
        )        

        instance['properties']['metadata']['items'].append(
            {
                "key": "controllerIPs",
                "value": self.controller_ips
            }
        )

        public_ip = "$(ref." + public_address.name + ".address)"

        instance['properties']['metadata']['items'].append(
            {
                "key": "publicIP",
                "value": public_ip
            }
        )

        instance['metadata'] = {
            "dependsOn": [
                public_address.name
            ]
        }
        
        return instance

