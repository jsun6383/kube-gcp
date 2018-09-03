from controller import Controller
from firewall import Firewall
from vpc import Vpc
from address import Address

def GenerateConfig(context):
    """Generate configuration."""

    # resource naming convention as follows:
    # <deployment_name>-<resource_name>-<component_name>

    vpc = Vpc(context, "10.0.0.0/24", "vpc")

    controller_mapping = {
        "controller0": "10.0.0.10",
        "controller1": "10.0.0.11",
    }

    controllers = []

    for name, ip in controller_mapping.iteritems():
        controllers.append(Controller(context, vpc.vpc_ref, name, ip, controller_mapping))

    fw = Firewall(context, vpc.vpc_ref)
    address = Address(context, "api-public")

    res = [
        vpc.create_vpc(),
        fw.create_ingress_allow("allow-22","0.0.0.0/0","22"),
        fw.create_allow_all_internal("allow-all-internal",vpc.cidr),
        address.create_public_address()
    ]

    for controller in controllers:
        res.append(controller.create_controller(address))

    # Resources to return.
    resources = {
        'resources': res,
    }

    return resources
