#====================#
# vCenter connection #
#====================#

variable "vsphere_user" {
  description = "vSphere user name"
}

variable "vsphere_password" {
  description = "vSphere password"
}

variable "vsphere_vcenter" {
  description = "vCenter server FQDN or IP"
}

variable "vsphere_unverified_ssl" {
  description = "Is the vCenter using a self signed certificate (true/false)"
}

variable "vsphere_datacenter" {
  description = "vSphere datacenter"
}

variable "vsphere_drs_cluster" {
  description = "vSphere cluster"
  default     = ""
}

variable "vsphere_resource_pool" {
  description = "vSphere resource pool"
}

variable "vsphere_enable_anti_affinity" {
  description = "Enable anti affinity between master VMs and between worker VMs (DRS need to be enable on the cluster)"
  default     = "false"
}

variable "vsphere_vcp_user" {
  description = "vSphere user name for the Kubernetes vSphere Cloud Provider plugin"
}

variable "vsphere_vcp_password" {
  description = "vSphere password for the Kubernetes vSphere Cloud Provider plugin"
}

variable "vsphere_vcp_datastore" {
  description = "vSphere default datastore for the Kubernetes vSphere Cloud Provider plugin"
}

#===========================#
# Kubernetes infrastructure #
#===========================#

variable "action" {
  description = "Which action have to be done on the cluster (create, add_worker, remove_worker, or upgrade)"
  default     = "create"
}

variable "worker" {
  type        = "list"
  description = "List of worker IPs to remove"

  default = [""]
}

variable "vm_user" {
  description = "SSH user for the vSphere virtual machines"
}

variable "vm_password" {
  description = "SSH password for the vSphere virtual machines"
}

variable "vm_datastore" {
  description = "Datastore used for the vSphere virtual machines"
}

variable "vm_network" {
  description = "Network used for the vSphere virtual machines"
}

variable "vm_template" {
  description = "Template used to create the vSphere virtual machines (linked clone)"
}

variable "vm_folder" {
  description = "vSphere Virtual machines folder"
}

variable "vm_linked_clone" {
  description = "Use linked clone to create the vSphere virtual machines from the template (true/false). If you would like to use the linked clone feature, your template need to have one and only one snapshot"
}

variable "k8s_kubespray_url" {
  description = "Kubespray git repository"
  default     = "https://github.com/kubernetes-incubator/kubespray.git"
}

variable "k8s_kubespray_version" {
  description = "Kubespray version"
  default     = "2.6.0"
}

variable "k8s_version" {
  description = "Version of Kubernetes that will be deployed"
  default     = "1.10.8"
}

variable "k8s_master_ips" {
  type        = "map"
  description = "IPs used for the Kubernetes master nodes"
}

variable "k8s_worker_ips" {
  type        = "map"
  description = "IPs used for the Kubernetes worker nodes"
}

variable "k8s_haproxy_ip" {
  description = "IP used for HAProxy"
}

variable "k8s_netmask" {
  description = "Netmask used for the Kubernetes nodes and HAProxy (example: 24)"
}

variable "k8s_gateway" {
  description = "Gateway for the Kubernetes nodes"
}

variable "k8s_dns" {
  description = "DNS for the Kubernetes nodes"
}

variable "k8s_domain" {
  description = "Domain for the Kubernetes nodes"
}

variable "k8s_network_plugin" {
  description = "Kubernetes network plugin (example: weave, flannel, cilium, etc.)"
}

variable "k8s_weave_encryption_password" {
  description = "Weave network encyption password "
  default     = ""
}

variable "k8s_cluster_name" {
  description = "Name for this cluster"
  default     = "cluster.local"
}

variable "k8s_dns_mode" {
  description = "Which DNS to use for the internal Kubernetes cluster name resolution (example: kubedns, coredns, etc.)"
  default     = "kubedns"
}

variable "k8s_kubeproxy_mode" {
  description = "which kubeproxy mode that are using. (example: ipvs/iptables)"
  default = "iptables"
}

variable "k8s_kubeproxy_masquerade_all" {
  description = "which whether masquerade all activate or note. (example: true/false)"
  default = "false"
}

variable "k8s_master_cpu" {
  description = "Number of vCPU for the Kubernetes master virtual machines"
}

variable "k8s_master_ram" {
  description = "Amount of RAM for the Kubernetes master virtual machines (example: 2048)"
}

variable "k8s_worker_cpu" {
  description = "Number of vCPU for the Kubernetes worker virtual machines"
}

variable "k8s_worker_ram" {
  description = "Amount of RAM for the Kubernetes worker virtual machines (example: 2048)"
}

variable "k8s_haproxy_cpu" {
  description = "Number of vCPU for the HAProxy virtual machine"
}

variable "k8s_haproxy_ram" {
  description = "Amount of RAM for the HAProxy virtual machine (example: 1024)"
}

variable "k8s_node_prefix" {
  description = "Prefix for the name of the virtual machines and the hostname of the Kubernetes nodes"
}

variable "metallb_ver" {
  description = "Version of MetalLB that will be used",
  default = "0.7.3"
}

variable "metallb_address_range" {
  description = "Layer 2 address range. Should be no spaces between dashes. Source: https://metallb.universe.tf/configuration/"
}

variable "install_haproxy_ingress" {
  description = "Should install haproxy ingress after the installation (example: yes/no)"
  default = "yes"
}
