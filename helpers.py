
COMPUTE_URL_BASE = 'https://www.googleapis.com/compute/v1/'

def concat_names(names):
    newName = names[0]
    for name in names[1:len(names)]:
        newName = newName + "-" + name
    return newName

def global_compute_url(project, collection, name):
    return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                '/global/', collection, '/', name])

def zonal_compute_url(project, zone, collection, name):
    return ''.join([COMPUTE_URL_BASE, 'projects/', project,
                '/zones/', zone, '/', collection, '/', name])