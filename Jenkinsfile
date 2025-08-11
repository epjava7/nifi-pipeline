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
                    sh '''
            set -eu

            aws eks update-kubeconfig --region $REGION --name nifi-eks
            kubectl apply -f namespace.yml
            kubectl apply -f service-headless.yml

            FS_ID=$(terraform -chdir=../terraform output -raw efs_id)
            SC_NAME="efs-sc-${FS_ID}"
            echo "Using EFS ${FS_ID} with StorageClass ${SC_NAME}"

            # If StatefulSet exists but PVC is bound to a DIFFERENT SC, replace it cleanly
            if kubectl -n nifi get sts nifi >/dev/null 2>&1; then
            PVC_SC=$(kubectl -n nifi get pvc nifi-data-nifi-0 -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
            if [ "${PVC_SC:-}" != "" ] && [ "${PVC_SC}" != "${SC_NAME}" ]; then
                echo "StatefulSet exists with PVC SC='${PVC_SC}', needs '${SC_NAME}'. Recreating STS + PVC…"
                kubectl -n nifi delete sts nifi --wait=true
                kubectl -n nifi delete pvc -l app=nifi --wait=true || true
            fi
            fi

            # Create StorageClass only if missing (SC params are immutable)
            if ! kubectl get sc "${SC_NAME}" >/dev/null 2>&1; then
            sed -e "s/EFS_ID/${FS_ID}/g" -e "s/SC_NAME/${SC_NAME}/g" efs.yml | kubectl apply -f -
            else
            echo "StorageClass ${SC_NAME} already exists; skipping"
            fi

            # (Re)create StatefulSet wired to SC_NAME
            sed "s/SC_NAME/${SC_NAME}/g" statefulset.yml | kubectl apply -f -

            # Public LB for access
            kubectl apply -f service.yml

            # Wait for rollout and print URL
            kubectl -n nifi rollout status sts/nifi --timeout=10m
            LB=$(kubectl -n nifi get svc nifi-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            echo "NiFi URL: http://${LB}:8080/nifi"
            '''
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
