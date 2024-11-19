//achivo 1 

//definir el provedor 
provider "digitalocean" {
    token = var.DO_TOKEN
  
}

//definir nuestras variables 
terraform {
  required_providers {
    digitalocean = {
        source = "digitalocean/digitalocean"
        version = "~> 2.0"
        
    }
  }
  backend "s3" {
    endpoints = {
      s3 = "https://sfo3.digitaloceanspaces.com"
    }
    bucket = "devdcv"
    key = "terraform.tfstate"
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_s3_checksum = true
    region = "us-east-1"
  }
}

//levantar recursos 
//crear un proyecto desde aqui

resource "digitalocean_project" "denisse_server_project" {
  name = "denisse_server_project"
  description = "un servidor para cositas personales"
  resources = [ digitalocean_droplet.denisse_server_droplet.urn]
}

//crear llaves 
resource "digitalocean_ssh_key" "denisse_server_ssh_key" {
    name = "denisse_server_key"
    public_key = file("./keys/denisse_server.pub")
  
}


//crear maquina virtual 

resource "digitalocean_droplet" "denisse_server_droplet" {
    name = "denisseserver"
    size = "s-2vcpu-4gb-120gb-intel"
    image = "ubuntu-24-04-x64"
    region = "sfo3"
    ssh_keys = [digitalocean_ssh_key.denisse_server_ssh_key.id]
    user_data = file("./docker-install.sh")



    provisioner "remote-exec" {
        inline = [ 
            "mkdir -p /projects",
            "mkdir -p /volumes/nginx/html",
            "mkdir -p /volumes/nginx/certs",
            "mkdir -p /volumes/nginx/vhostd",
            "touch /projects/.env",
            "echo \"MYSQL_DB=${var.MYSQL_DB}\" >> /projects/.env",
            "echo \"MYSQL_HOST=${var.MYSQL_HOST}\" >> /projects/.env",
            "echo \"MYSQL_PASSWORD=${var.MYSQL_PASSWORD}\" >> /projects/.env",
            "echo \"MYSQL_USER=${var.MYSQL_USER}\" >> /projects/.env",
            "echo \"DOMAIN=${var.DOMAIN}\" >> /projects/.env",
            "echo \"USER_EMAIL=${var.USER_EMAIL}\" >> /projects/.env",
        ]
        connection {
            type = "ssh"
            user ="root"
            private_key = file("./keys/denisse_server")
            host = self.ipv4_address
        }
    }

    provisioner "file" {
      source = "./container/docker-compose.yml"
      destination = "/projects/docker-compose.yml"
      connection {
        type = "ssh"
        user = "root"
        private_key = file("./keys/denisse_server")
        host = self.ipv4_address
      }
    }  
}



//instalar docker 

resource "time_sleep" "wait_docker_install" {
    depends_on = [ digitalocean_droplet.denisse_server_droplet ]
    create_duration = "130s"

}

resource "null_resource" "init_api" {
  depends_on = [ time_sleep.wait_docker_install ]
  provisioner "remote-exec" {
    inline = [ 
      "cd /projects",
      "docker-compose up -d",
     ]
     connection {
      type = "ssh"
      user = "root"
      private_key = file("./keys/denisse_server")
      host = digitalocean_droplet.denisse_server_droplet.ipv4_address
    }
  }
}

//conectarse a ssh 
# resource "null_resource" "init_nginx" {
#   depends_on = [ time_sleep.wait_docker_install ]
#   connection {
#     type = "ssh"
#     user = "root"
#     private_key = file("./keys/denisse_server")
#     host = digitalocean_droplet.denisse_server_droplet.ipv4_address
#   }
#   provisioner "remote-exec" {
#     inline = [ "docker container run --name=Adidas -dp 80:80 nginx" ]
#   }
# }

# //levantar el contenedor con nginx
# resource "null_resource" "adidas_copy_folder2" {
#   provisioner "file" {
#     source = "./adidas"
#     destination = "/adidas"
#   }
#   connection {
#     type = "ssh"
#     user = "root"
#     private_key = file("./keys/denisse_server")
#     host = digitalocean_droplet.denisse_server_droplet.ipv4_address
#   }
  
# }

# resource "null_resource" "copy_to_nginx_container" {
#   depends_on = [ null_resource.adidas_copy_folder2, null_resource.init_nginx ]
#   connection {
#     type = "ssh"
#     user = "root"
#     private_key = file("./keys/denisse_server")
#     host = digitalocean_droplet.denisse_server_droplet.ipv4_address
#   }
#   provisioner "remote-exec" {
#     inline = [ 
#       "cd /",
#       "docker cp adidas/. Adidas:/usr/share/nginx/html"
#      ]
    
#   }
  
# }


output "ip" {
  value = digitalocean_droplet.denisse_server_droplet.ipv4_address
}

