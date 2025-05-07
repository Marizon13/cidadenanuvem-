# Definição do provedor AWS
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAYTNFWT7AK4JEGRV4"
  secret_key = "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"
}

# Prefeitura (IAM) - Controle e Permissões
resource "aws_iam_user" "usuario_cidade" {
  name = "usuario-cidade"
}

# Casas (EC2) - Instâncias de Máquinas Virtuais
resource "aws_instance" "cidade-servidor" {
  ami           = "ami-00a929b66ed6e0de6"  # Amazon Linux 2
  instance_type = "t2.micro"
  tags = {
    Name = "ServidorPrincipal"
  }
}

resource "aws_instance" "casa1" {
  ami           = "ami-00a929b66ed6e0de6"
  instance_type = "t2.micro"
  tags = {
    Name = "Casa 1"
  }
}

# Estradas (VPC e Subnets) - Comunicação entre os Recursos
resource "aws_vpc" "cidade_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "CidadeVPC"
  }
}

resource "aws_subnet" "bairro_subnet" {
  vpc_id            = aws_vpc.cidade_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "BairroSubnet"
  }
}

# Cartório (S3) - Armazenamento de Documentos
resource "aws_s3_bucket" "cartorio_cidade" {
  bucket = "cidade-na-nuvem-cartorio"
  tags = {
    Name        = "CartorioDaCidade"
    Environment = "Dev"
  }
}

# Firewall da Cidade (Security Group) - Proteção e Segurança
resource "aws_security_group" "firewall_cidade" {
  name        = "FirewallCidade"
  description = "Firewall para proteger a cidade"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ============================
# BANCO DA CIDADE (S3)
# ============================
resource "aws_s3_bucket" "banco_cidade" {
  bucket = "cidade-na-nuvem-banco"

  # Criptografia ativada para proteger os dados guardados no cofre
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Name        = "BancoDaCidade"
    Environment = "Dev"
  }
}
 # Política de Acesso ao Banco

resource "aws_iam_policy" "acesso_banco" {
  name        = "AcessoBancoPolicy"
  description = "Permissões para o cliente acessar o banco da cidade"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",     # Ver saldo
          "s3:PutObject",     # Depositar
          "s3:DeleteObject"   # Sacar
        ]
        Resource = "arn:aws:s3:::cidade-na-nuvem-banco/*"
      }
    ]
  })
}

# Criando o Cliente do Banco (usuário IAM)

resource "aws_iam_user" "usuario_banco" {
  name = "clienteBanco"
}

#Ligando o Cliente às Permissões

resource "aws_iam_user_policy_attachment" "usuario_banco_policy" {
  user       = aws_iam_user.usuario_banco.name
  policy_arn = aws_iam_policy.acesso_banco.arn
}

#Gerando as Chaves de Acesso do Cliente
# Isso representa o cartão do banco que permite o cliente movimentar o dinheiro.
resource "aws_iam_access_key" "usuario_banco_key" {
  user = aws_iam_user.usuario_banco.name
}

# Sa´ida das credenciais 

output "cliente_banco_access_key_id" {
  value     = aws_iam_access_key.usuario_banco_key.id
  sensitive = true
}

output "cliente_banco_secret_access_key" {
  value     = aws_iam_access_key.usuario_banco_key.secret
  sensitive = true
}


# CORREIOS DA CIDADE   SNS + CloudWatch


# Caixa Postal dos Correios (SNS Topic)
resource "aws_sns_topic" "caixa_postal_cidade" {
  name = "caixa-postal-cidade"
}

# Endereço de entrega da carta (Assinatura de email)
resource "aws_sns_topic_subscription" "endereco_entrega_email" {
  topic_arn = aws_sns_topic.caixa_postal_cidade.arn
  protocol  = "email"
  endpoint  = "seuemail@exemplo.com"  # Altere para seu e-mail real
}

# Funcionário dos Correios observando o Servidor Principal (Alarme de CPU)
resource "aws_cloudwatch_metric_alarm" "correios_olheiro_servidor" {
  alarm_name          = "CorreioAvisoCPUAlta-ServidorPrincipal"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "70"
  alarm_description   = "O funcionário dos Correios vai enviar uma carta se a CPU do servidor passar de 70%."
  alarm_actions       = [aws_sns_topic.caixa_postal_cidade.arn]
  dimensions = {
    InstanceId = aws_instance.cidade-servidor.id
  }
}

# FÁBRICA DE CONTÊINERES (EC2 + Docker)

# Criando a Fábrica de Contêineres (Instância EC2)
resource "aws_instance" "fabrica_conteineres" {
  ami           = "ami-00a929b66ed6e0de6"  # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.bairro_subnet.id  # Conectar à rede (bairro)

  # Script para instalar Docker e rodar o contêiner
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              docker run -d -p 80:80 my_custom_app:latest  # Rodando o contêiner
              EOF

  tags = {
    Name = "FabricaDeConteineres"
  }
}

# Exibindo o IP da Fábrica (Instância EC2)
output "fabrica_conteineres_ip" {
  value = aws_instance.fabrica_conteineres.public_ip
}
