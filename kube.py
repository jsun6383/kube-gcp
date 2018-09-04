from controller import Controller
from firewall import Firewall
from vpc import Vpc
from address import Address
# from netaddr import IPNetwork
from nlb import Nlb

def GenerateConfig(context):
    """Generate configuration."""

    res = []
    # resource naming convention as follows:
    # <deployment_name>-<resource_name>-<component_name>

    vpc = Vpc(context, context.properties["vpcCIDR"], "vpc")

    # vpc_ips = IPNetwork(context.properties["vpcCIDR"])

    context.properties["vpcRef"] = vpc.vpc_ref
    context.properties["region"] = context.properties["zone"][:-2]

    controller_mapping = {
        "controller0": "10.240.0.10",
        "controller1": "10.240.0.11"
    }

    controllers = []

    for name, ip in controller_mapping.iteritems():
        controllers.append(Controller(context, vpc.vpc_ref, name, ip, controller_mapping))

    fw = Firewall(context, vpc.vpc_ref)
    address = Address(context, "api-public")

    controller_names = [ controller.instance_name for controller in controllers ]
    
    nlb = Nlb(context, "nlb", controller_names, address.name)

    res.append(vpc.create_vpc())
    res.append(fw.create_ingress_allow("allow-22",["0.0.0.0/0"],"22"))
    res.append(fw.create_allow_all_internal("allow-all-internal",[vpc.cidr, "10.200.0.0/16"]))
    res.append(fw.create_ingress_allow("allow-external",["0.0.0.0/0"],"6443"))
    res.append(address.create_public_address())

    for controller in controllers:
        res.append(controller.create_controller(address, vpc.cidr))

    res.extend(nlb.create_nlb())

    # Resources to return.
    resources = {
        'resources': res,
    }

    return resources
