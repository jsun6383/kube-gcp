from helpers import concat_names

class Address:

    def __init__(self, context, name):
        self.context = context
        self.name = concat_names(
            [self.context.env['deployment'], self.context.env['name'], name])

    def create_public_address(self):

        region = self.context.properties['region']

        address = {
            "name": self.name,
            "region": region
        }

        resource = {
            "name": self.name,
            "type": "compute.v1.address",
            "properties": address
        }

        address_ref = "$(ref"

        return resource

