from helpers import concat_names

class Firewall:

    def __init__(self, context, vpc):
        self.context = context
        self.vpc = vpc

    def get_fw_name(self, fw_name):
        return concat_names(
            [self.context.env['deployment'], self.context.env['name'], fw_name])

    def create_ingress_allow(self, fw_name, sourceCIDR, port):
        fw_name = self.get_fw_name(fw_name)

        fw = {
            "network": self.vpc,
            "name": fw_name,
            "sourceRanges": sourceCIDR,
            "allowed": [
                {
                    "IPProtocol": "tcp",
                    "ports": [
                        port
                    ]
                },
                {
                    "IPProtocol": "icmp"
                }
            ]
        }

        resource = {
            "name": fw_name,
            "type": "compute.v1.firewall",
            "properties": fw
        }

        return resource

    def create_allow_all_internal(self, fw_name, sourceCIDR):
        fw_name = self.get_fw_name(fw_name)

        fw = {
            "network": self.vpc,
            "name": fw_name,
            "sourceRanges": sourceCIDR,
            "allowed": [
                {
                    "IPProtocol": "tcp"
                },
                {
                    "IPProtocol": "icmp"
                },
                {
                    "IPProtocol": "udp"
                }
            ]
        }

        resource = {
            "name": fw_name,
            "type": "compute.v1.firewall",
            "properties": fw
        }

        return resource
