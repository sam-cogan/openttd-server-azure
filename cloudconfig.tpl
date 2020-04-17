#cloud-config
package_upgrade: true

packages:
    - docker.io
    - docker-compose

# create the docker group
groups:
    - docker

# assign a VM's default user, which is mydefaultuser, to the docker group
users:
    - default
    - name: openttdadmin
      groups: docker