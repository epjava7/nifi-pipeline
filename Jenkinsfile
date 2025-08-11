pipeline {
  agent any
  environment {
    REGION = 'us-west-1'
    IMAGE_URI  = '549103799643.dkr.ecr.us-west-1.amazonaws.com/nifi-1-26-0:latest'
  }

  stages {

    stage('clean workspace') {
        steps {
            cleanWs()
        }
    }

    stage('git checkout') {       
        steps {
            checkout scm               
        }
    }

    stage('Terraform apply') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh 'terraform init -input=false -migrate-state -force-copy'
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
                sh '''
                if ! kubectl get storageclass efs-sc >/dev/null 2>&1; then
                    FS_ID=$(terraform -chdir=../terraform output -raw efs_id)
                    sed "s/EFS_ID/${FS_ID}/g" efs.yml | kubectl apply -f -
                else
                    echo "StorageClass efs-sc already exists, skipping"
                fi
                '''
                sh 'kubectl apply -f namespace.yml'
                sh 'kubectl apply -f statefulset.yml'
                sh 'kubectl apply -f service.yml'
            }
            }
        }
    }

    stage('K8s teardown') {
        steps {
            withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh '''
                set -e
                aws eks update-kubeconfig --region $REGION --name nifi-eks
                LB_DNS=$(kubectl get svc nifi-lb -n nifi -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)
                kubectl delete svc nifi-lb -n nifi --ignore-not-found
                kubectl delete statefulset nifi -n nifi --ignore-not-found
                kubectl delete pvc -n nifi --all --ignore-not-found
                kubectl delete ns nifi --ignore-not-found --wait=true
                sleep 60
            '''
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
