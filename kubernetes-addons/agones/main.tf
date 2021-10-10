/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/*  AGONES HELM CHART LOCATION
     https://github.com/googleforgames/agones/tree/main/install/helm/agones
     https://artifacthub.io/packages/helm/agones/agones
    DOCKER IMAGES
      gcr.io/agones-images/agones-controller:1.15.0-rc
      gcr.io/agones-images/agones-ping:1.15.0-rc
      gcr.io/agones-images/agones-allocator:1.15.0-rc
*/

locals {
  image_url = var.public_docker_repo ? var.agones_image_repo : "${var.private_container_repo_url}/${var.agones_image_repo}"
}

data "aws_security_group" "eks_security_group" {
  id = var.eks_sg_id
}

resource "kubernetes_namespace" "agones" {
  metadata {
    name = "agones-system"
  }
}

resource "kubernetes_namespace" "xbox" {
  metadata {
    name = "xbox-gameservers"
  }
}

resource "kubernetes_namespace" "pc" {
  metadata {
    name = "ps4-gameservers"
  }
}

resource "helm_release" "agones" {
  name       = var.agones_helm_chart_name
  repository = var.agones_helm_chart_url
  chart      = var.agones_helm_chart_name
  version    = var.agones_image_tag
  namespace  = kubernetes_namespace.agones.id
  timeout    = "1200"
  values = [templatefile("${path.module}/templates/agones-values.yaml", {
    image                 = local.image_url
    image_tag             = var.agones_image_tag
    expose_udp            = var.expose_udp
    gameserver_namespaces = "{${join(",", ["default", kubernetes_namespace.pc.id, kubernetes_namespace.xbox.id])}}"
    gameserver_minport    = var.agones_game_server_minport
    gameserver_maxport    = var.agones_game_server_maxport
  })]
}


resource "aws_security_group_rule" "agones_sg_ingress_rule" {
  type              = "ingress"
  from_port         = var.agones_game_server_minport
  to_port           = var.agones_game_server_maxport
  protocol          = "udp"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  security_group_id = data.aws_security_group.eks_security_group.id
}