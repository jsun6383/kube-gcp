from helpers import concat_names

class Vpc:

    def __init__(self, context, cidr, vpc_name):
        self.cidr = cidr
        self.vpc_name = concat_names(
            [context.env['deployment'], context.env['name'], vpc_name])
        self.vpc_ref = "$(ref." + self.vpc_name + ".selfLink)"

    def create_vpc(self):

        vpc = {
            "IPv4Range": self.cidr
        }

        resource = {
            "name": self.vpc_name,
            "type": "compute.v1.network",
            "properties": vpc
        }

        return resource
