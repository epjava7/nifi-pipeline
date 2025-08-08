pipeline {
  agent any
  environment {
    REGION = 'us-west-1'
    IMAGE_URI  = '549103799643.dkr.ecr.us-west-1.amazonaws.com/nifi-1-26-0:latest'
  }

  stages {

    stage('Terraform apply') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh 'terraform init -input=false -force-copy'
            sh 'terraform apply -auto-approve'
          }
        }
      }
    }

    stage('Build & push image') {
        steps {
            withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh 'aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin ${IMAGE_URI%:*}'
            sh 'docker build -t $IMAGE_URI .'
            sh 'docker push $IMAGE_URI'
            }
        }
    }

    stage('Deploy to EKS') {
        steps {
            withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
                dir('k8s') {
                    sh 'aws eks update-kubeconfig --region $REGION --name nifi-eks'
                    sh 'FS_ID=$(terraform -chdir=../terraform output -raw efs_id) && sed "s/EFS_ID/${FS_ID}/g" efs.yml | kubectl apply -f -'
                    sh 'kubectl apply -f namespace.yml'
                    sh 'kubectl apply -f statefulset.yml'
                    sh 'kubectl apply -f service.yml'
                }
            }
        }
    }

    stage('Terraform destroy') {
        steps {
            dir('terraform') {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-devops']]) {
                    input message: 'terraform destroy?', ok: 'Destroy'
                    sh 'terraform destroy -auto-approve'
                }
            }
        }
    }

  }
}
