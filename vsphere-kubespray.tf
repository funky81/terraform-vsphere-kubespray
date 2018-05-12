#===============================================================================
# vSphere Provider
#===============================================================================

provider "vsphere" {
  version        = "1.1.1"
  vsphere_server = "${var.vsphere_vcenter}"
  user           = "${var.vsphere_user}"
  password       = "${var.vsphere_password}"

  allow_unverified_ssl = "${var.vsphere_unverified_ssl}"
}

#===============================================================================
# vSphere Data
#===============================================================================

data "vsphere_datacenter" "dc" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_resource_pool" "pool" {
  name          = "${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vm_datastore}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vm_network}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vm_template}"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

#===============================================================================
# Templates
#===============================================================================

# Kubespray all.yml template #
data "template_file" "kubespray_all" {
  template = "${file("templates/kubespray_all.tpl")}"

  vars {
    vsphere_vcenter_ip     = "${var.vsphere_vcenter}"
    vsphere_user           = "${var.vsphere_user}"
    vsphere_password       = "${var.vsphere_password}"
    vsphere_datacenter     = "${var.vsphere_datacenter}"
    vsphere_datastore      = "${var.vm_datastore}"
    vsphere_working_dir    = "${var.vm_folder}"
    vsphere_resource_pool  = "${var.vsphere_resource_pool}"
    loadbalancer_apiserver = "${var.k8s_haproxy_ip}"
  }
}

# Kubespray k8s-cluster.yml template #
data "template_file" "kubespray_k8s_cluster" {
  template = "${file("templates/kubespray_k8s_cluster.tpl")}"
}

# Kubespray master hostname and ip list template #
data "template_file" "kubespray_hosts_master" {
  count    = "${var.k8s_master_count}"
  template = "${file("templates/kubespray_hosts.tpl")}"

  vars {
    hostname = "${var.k8s_node_prefix}-master-${count.index}"
    host_ip  = "${lookup(var.k8s_master_ips, count.index)}"
  }
}

# Kubespray worker hostname and ip list template #
data "template_file" "kubespray_hosts_worker" {
  count    = "${var.k8s_worker_count}"
  template = "${file("templates/kubespray_hosts.tpl")}"

  vars {
    hostname = "${var.k8s_node_prefix}-worker-${count.index}"
    host_ip  = "${lookup(var.k8s_worker_ips, count.index)}"
  }
}

# Kubespray master hostname list template #
data "template_file" "kubespray_hosts_master_list" {
  count    = "${var.k8s_master_count}"
  template = "${file("templates/kubespray_hosts_list.tpl")}"

  vars {
    hostname = "${var.k8s_node_prefix}-master-${count.index}"
  }
}

# Kubespray worker hostname list template #
data "template_file" "kubespray_hosts_worker_list" {
  count    = "${var.k8s_worker_count}"
  template = "${file("templates/kubespray_hosts_list.tpl")}"

  vars {
    hostname = "${var.k8s_node_prefix}-worker-${count.index}"
  }
}

# HAProxy template #
data "template_file" "haproxy" {
  template = "${file("templates/haproxy.tpl")}"

  vars {
    bind_ip = "${var.k8s_haproxy_ip}"
  }
}

# HAProxy server backend template #
data "template_file" "haproxy_backend" {
  count    = "${var.k8s_master_count}"
  template = "${file("templates/haproxy_backend.tpl")}"

  vars {
    prefix_server     = "${var.k8s_node_prefix}"
    backend_server_ip = "${lookup(var.k8s_master_ips, count.index)}"
    count             = "${count.index}"
  }
}

#===============================================================================
# Local Resources
#===============================================================================

# Create Kubespray all.yml configuration file from Terraform template #
resource "local_file" "kubespray_all" {
  content  = "${data.template_file.kubespray_all.rendered}"
  filename = "config/group_vars/all.yml"
}

# Create Kubespray k8s-cluster.yml configuration file from Terraform template #
resource "local_file" "kubespray_k8s_cluster" {
  content  = "${data.template_file.kubespray_k8s_cluster.rendered}"
  filename = "config/group_vars/k8s-cluster.yml"
}

# Create Kubespray hosts.ini configuration file from Terraform templates #
resource "local_file" "kubespray_hosts" {
  content  = "${join("", data.template_file.kubespray_hosts_master.*.rendered)}${join("", data.template_file.kubespray_hosts_worker.*.rendered)}\n[kube-master]\n${join("", data.template_file.kubespray_hosts_master_list.*.rendered)}\n[etcd]\n${join("", data.template_file.kubespray_hosts_master_list.*.rendered)}\n[kube-node]\n${join("", data.template_file.kubespray_hosts_worker_list.*.rendered)}\n[k8s-cluster:children]\nkube-master\nkube-node"
  filename = "config/hosts.ini"
}

# Create HAProxy configuration from Terraform templates #
resource "local_file" "haproxy" {
  content  = "${data.template_file.haproxy.rendered}${join("", data.template_file.haproxy_backend.*.rendered)}"
  filename = "config/haproxy.cfg"
}

#===============================================================================
# Null Resource
#===============================================================================

# Modify the permission on the config directory
resource "null_resource" "config_permission" {
  provisioner "local-exec" {
    command = "chmod -R 700 config"
  }

  depends_on = ["local_file.haproxy", "local_file.kubespray_hosts", "local_file.kubespray_k8s_cluster", "local_file.kubespray_all"]
}

# Execute Kubespray Ansible playbook #
resource "null_resource" "kubespray" {
  provisioner "local-exec" {
    command = "cd kubespray && ansible-playbook -i ../config/hosts.ini -b -u ${var.vm_user} -v cluster.yml"
  }

  depends_on = ["local_file.kubespray_all", "local_file.kubespray_k8s_cluster", "local_file.kubespray_hosts", "vsphere_virtual_machine.master", "vsphere_virtual_machine.worker", "vsphere_virtual_machine.haproxy"]
}

# Create the local admin.conf kubectl configuration file #
resource "null_resource" "kubectl_configuration" {
  provisioner "local-exec" {
    command = "ansible -i ${lookup(var.k8s_master_ips, 0)}, -b -u ${var.vm_user} -m fetch -a 'src=/etc/kubernetes/admin.conf dest=config/admin.conf flat=yes' all"
  }

  provisioner "local-exec" {
    command = "sed -i 's/lb-apiserver.kubernetes.local/${var.k8s_haproxy_ip}/g' config/admin.conf"
  }

  provisioner "local-exec" {
    command = "chmod 600 config/admin.conf"
  }

  depends_on = ["null_resource.kubespray"]
}

#===============================================================================
# vSphere Resources
#===============================================================================

# Create a virtual machine folder for the Kubernetes VMs #
resource "vsphere_folder" "folder" {
  path          = "${var.vm_folder}"
  type          = "vm"
  datacenter_id = "${data.vsphere_datacenter.dc.id}"
}

# Create the Kubernetes master VMs #
resource "vsphere_virtual_machine" "master" {
  count            = "${var.k8s_master_count}"
  name             = "${var.k8s_node_prefix}-master-${count.index}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder           = "${vsphere_folder.folder.path}"

  num_cpus = "${var.k8s_master_cpu}"
  memory   = "${var.k8s_master_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    name             = "${var.k8s_node_prefix}-master-${count.index}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.k8s_node_prefix}-${count.index}"
        domain    = "${var.k8s_domain}"
      }

      network_interface {
        ipv4_address = "${lookup(var.k8s_master_ips, count.index)}"
        ipv4_netmask = "${var.k8s_netmask}"
      }

      ipv4_gateway    = "${var.k8s_gateway}"
      dns_server_list = ["${var.k8s_dns}"]
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    inline = [
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^/#/' /etc/fstab",
    ]
  }

  depends_on = ["vsphere_virtual_machine.haproxy"]
}

# Create the Kubernetes worker VMs #
resource "vsphere_virtual_machine" "worker" {
  count            = "${var.k8s_worker_count}"
  name             = "${var.k8s_node_prefix}-worker-${count.index}"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder           = "${vsphere_folder.folder.path}"

  num_cpus = "${var.k8s_worker_cpu}"
  memory   = "${var.k8s_worker_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    name             = "${var.k8s_node_prefix}-worker-${count.index}.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.k8s_node_prefix}-worker-${count.index}"
        domain    = "${var.k8s_domain}"
      }

      network_interface {
        ipv4_address = "${lookup(var.k8s_worker_ips, count.index)}"
        ipv4_netmask = "${var.k8s_netmask}"
      }

      ipv4_gateway    = "${var.k8s_gateway}"
      dns_server_list = ["${var.k8s_dns}"]
    }
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    inline = [
      "sudo swapoff -a",
      "sudo sed -i '/ swap / s/^/#/' /etc/fstab",
    ]
  }

  depends_on = ["vsphere_virtual_machine.master"]
}

# Create the HAProxy load balancer VM #
resource "vsphere_virtual_machine" "haproxy" {
  name             = "${var.k8s_node_prefix}-haproxy"
  resource_pool_id = "${data.vsphere_resource_pool.pool.id}"
  datastore_id     = "${data.vsphere_datastore.datastore.id}"
  folder           = "${vsphere_folder.folder.path}"

  num_cpus = "${var.k8s_haproxy_cpu}"
  memory   = "${var.k8s_haproxy_ram}"
  guest_id = "${data.vsphere_virtual_machine.template.guest_id}"

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    name             = "${var.k8s_node_prefix}-haproxy.vmdk"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
    linked_clone  = "${var.vm_linked_clone}"

    customize {
      linux_options {
        host_name = "${var.k8s_node_prefix}-haproxy"
        domain    = "${var.k8s_domain}"
      }

      network_interface {
        ipv4_address = "${var.k8s_haproxy_ip}"
        ipv4_netmask = "${var.k8s_netmask}"
      }

      ipv4_gateway    = "${var.k8s_gateway}"
      dns_server_list = ["${var.k8s_dns}"]
    }
  }

  provisioner "file" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    source      = "config/haproxy.cfg"
    destination = "/tmp/haproxy.cfg"
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = "${var.vm_user}"
      password = "${var.vm_password}"
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y haproxy",
      "sudo mv /tmp/haproxy.cfg /etc/haproxy",
      "sudo systemctl restart haproxy",
    ]
  }
}
