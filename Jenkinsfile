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
                sh 'kubectl apply -f namespace.yml'
                sh '''
                FS_ID=$(terraform -chdir=../terraform output -raw efs_id)
                SC_NAME="efs-sc-${FS_ID}"
                echo "EFS_ID = ${FS_ID}"

                if ! kubectl get sc "${SC_NAME}" >/dev/null 2>&1; then
                    sed -e "s/EFS_ID/${FS_ID}/g" -e "s/SC_NAME/${SC_NAME}/g" efs.yml | kubectl apply -f -
                else
                    echo "efs ${SC_NAME} exists"
                fi
                '''
                sh 'kubectl apply -f service-headless.yml'

                sh 'sed "s/SC_NAME/${SC_NAME}/g" statefulset.yml | kubectl apply -f -'
                sh 'kubectl apply -f service.yml'

                sh 'kubectl -n nifi rollout status sts/nifi --timeout=10m'
                sh 'kubectl -n nifi get svc nifi-lb -o wide'
            }
            }
        }
    }


    stage('K8s delete') {
        steps {
            withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            input message: 'Delete K8s', ok: 'Delete'
            sh '''
            aws eks update-kubeconfig --region $REGION --name nifi-eks
            kubectl -n nifi scale sts nifi --replicas=0
            kubectl -n nifi delete svc nifi-lb --ignore-not-found

            sleep 30

            kubectl -n nifi delete statefulset nifi --ignore-not-found --wait=true || true
            kubectl -n nifi delete pvc --all --ignore-not-found || true
            kubectl -n nifi delete ns nifi --ignore-not-found --wait=true || true
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
