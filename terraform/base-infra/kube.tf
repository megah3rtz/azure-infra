provider "helm" {
  kubernetes {
    host = azurerm_kubernetes_cluster.kube.kube_config.0.host
    client_certificate = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host = azurerm_kubernetes_cluster.kube.kube_config.0.host
  client_certificate = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.kube.kube_config.0.cluster_ca_certificate)
}

module "naming_kube" {
  source  = "Azure/naming/azurerm"
  suffix = [ "prod-kube" ]
}

resource "azurerm_subnet" "kubesubnet" {
  name                 = module.naming_kube.subnet.name
  resource_group_name  = azurerm_resource_group.baserg.name
  virtual_network_name = azurerm_virtual_network.basevnet.name
  address_prefixes     = ["192.168.130.0/23"]
}

resource "azurerm_kubernetes_cluster" "kube" {
  name                = module.naming_kube.kubernetes_cluster.name
  location            = azurerm_resource_group.baserg.location
  resource_group_name = azurerm_resource_group.baserg.name
  dns_prefix          = "kube"
  api_server_authorized_ip_ranges = [ "217.155.15.224/32" ]
  node_resource_group = "${azurerm_resource_group.baserg.name}-nodes"
  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_B2s"
    vnet_subnet_id = azurerm_subnet.kubesubnet.id
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "internal" {
  name                  = "internal"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.kube.id
  vm_size               = "Standard_D2as_v5"
  node_count            = 1
  eviction_policy = "Delete"
  spot_max_price = "0.012"
  priority = "Spot"
  vnet_subnet_id = azurerm_subnet.kubesubnet.id
}

resource "azurerm_public_ip" "kube_ingress" {
  name                = module.naming_kube.public_ip.name
  resource_group_name = "rg-prod-nodes"
  location            = azurerm_resource_group.baserg.location
  allocation_method   = "Static"
  sku = "Standard"
  tags = {
    environment = "prod"
  }
}

resource "azurerm_dns_a_record" "kube" {
  name                = "kube"
  zone_name           = "megah3rtz.net"
  resource_group_name = "dns-zones"
  ttl                 = 60
  records = [ azurerm_public_ip.kube_ingress.ip_address ]
}

resource "helm_release" "certmanager" {
  depends_on = [helm_release.nginx_ingress]
  name = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  namespace = "ingress-basic"
  create_namespace = true
  set {
    name = "installCRDs"
    value = "true"
  }
}

resource "helm_release" "nginx_ingress" {
  depends_on = [azurerm_kubernetes_cluster.kube]
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  values = [
    "${file("${path.root}/../../helm/ingress/values.yaml")}"
  ]
  set {
    name = "controller.service.loadBalancerIP"
    value = azurerm_public_ip.kube_ingress.ip_address
  }
  namespace = "ingress-basic"
  create_namespace = true
}

resource "kubernetes_manifest" "cluster_issuer" {
  depends_on = [azurerm_kubernetes_cluster.kube]
  manifest = yamldecode(file("${path.root}/../../kubernetes/cluster-issuer.yaml"))
}

resource "azurerm_dns_a_record" "code-server" {
  name                = "code-server.azure"
  zone_name           = "megah3rtz.net"
  resource_group_name = "dns-zones"
  ttl                 = 60
  records = [ azurerm_public_ip.kube_ingress.ip_address ]
}

# resource "helm_release" "oauth2_proxy" {
#   name = "oauth2-proxy"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart = "oauth2-proxy"
#   values = [
#     "${file("${path.root}/../../helm/oauth2/values.yaml")}"
#   ]
# }

resource "helm_release" "code_server" {
  depends_on = [helm_release.certmanager]
  name       = "code-server"
  chart      = "../../helm/code-server"
  values = [
    "${file("${path.root}/../../helm/code-server/values.yaml")}"
  ]
  namespace = "code-server"
  create_namespace = true
}