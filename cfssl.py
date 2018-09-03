from container_vm import ContainerVM
from firewall import Firewall
from helpers import global_compute_url

"""Creates a Container VM with the provided Container manifest."""

def GenerateConfig(context):

    default_vpc_ref = global_compute_url(context.env['project'], "networks", "default")

    instance = ContainerVM(context, default_vpc_ref, "cfssl")
    fw = Firewall(context, default_vpc_ref)

    res = [
        instance.create_instance(),
        fw.create_ingress_allow("allow-22","0.0.0.0/0","22"),
        fw.create_ingress_allow("allow-8888","0.0.0.0/0","8888")
    ]

    out = [
        {
            "name": "address",
            "value": "$(ref." + instance.instance_name + ".networkInterfaces[0].accessConfigs[0].natIP)"
        }
    ]

        # Resources to return.
    resources = {
        'resources': res,
        'outputs': out
    }

    return resources
