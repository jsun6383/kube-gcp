from helpers import gen_name
from firewall import Firewall

class Nlb:
    
    def __init__(self, context, name, instance_names, public_address):
        self.context = context
        self.public_address = "$(ref." + public_address + ".address)"
        self.instance_refs = []
        
        for instance_name in instance_names:
            self.instance_refs.append("$(ref." + instance_name + ".selfLink)")

        self.name = gen_name(context, name)

    def create_nlb(self):

        healthcheck = {
            "name": self.name + "-healthcheck",
            "description": "nlb health check",
            "host": "kubernetes.default.svc.cluster.local",
            "requestPath": "/healthz"
        }

        target_pool = {
            "name": self.name + "-targetpool",
            "healthChecks": [
                "$(ref." + self.name + "-healthcheck.selfLink)"
            ],
            "instances": self.instance_refs,
            "region": self.context.properties["region"]
        }

        fwd_rule = {
            "name": self.name + "-forwarding-rule",
            "IPAddress": self.public_address,
            "portRange": "6443",
            "IPProtocol": "TCP",
            "target": "$(ref." + self.name + "-targetpool.selfLink)",
            "region": self.context.properties["region"]
        }

        fw = Firewall(self.context, self.context.properties["vpcRef"])

        nlb = [
            {
                "name": self.name + "-healthcheck",
                "type": "compute.v1.httpHealthCheck",
                "properties": healthcheck,
            },
            {
                "name": self.name + "-targetpool",
                "type": "compute.v1.targetPool",
                "properties": target_pool
            },
            {
                "name": self.name + "-forwarding-rule",
                "type": "compute.v1.forwardingRule",
                "properties": fwd_rule
            },
            fw.create_ingress_allow("allow-health-check",["209.85.152.0/22","209.85.204.0/22","35.191.0.0/16"],"0-65535")
        ]

        return nlb


        
