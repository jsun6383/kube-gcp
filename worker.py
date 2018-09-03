from instance import Instance

class Worker(Instance):
    
    def __init__(self, vpc, context, instance_name):
        Instance.__init__(self, context, vpc, instance_name, "startup-script", "workerStartupScript")

        