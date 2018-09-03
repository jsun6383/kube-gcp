from instance import Instance

class ContainerVM(Instance):

    def __init__(self, context, vpc, instance_name):
        Instance.__init__(self, context, vpc, instance_name, "gce-container-declaration", "containerManifest")

