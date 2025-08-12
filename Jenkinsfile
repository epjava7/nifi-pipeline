pipeline {
  agent any
  environment {
    REGION    = 'us-west-1'
    IMAGE_URI = '549103799643.dkr.ecr.us-west-1.amazonaws.com/nifi-1-26-0:latest'
  }

  stages {

    stage('clean workspace') {
      steps { cleanWs() }
    }

    stage('git checkout') {
      steps { checkout scm }
    }

    stage('docker prune') {
        steps {
            sh '''
            docker system prune -af || true
            docker builder prune -af || true
            '''
        }
    }


    stage('Terraform apply') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh '''#!/usr/bin/env bash
            set -euo pipefail
            terraform init -input=false -migrate-state -force-copy
            terraform apply -auto-approve
            '''
          }
        }
      }
    }

//     stage('Build & push image') {
//       steps {
//         withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
//           sh '''#!/usr/bin/env bash
// set -euo pipefail
// REPO=${IMAGE_URI%:*}
// COMMIT=$(git rev-parse --short HEAD)

// aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPO"

// docker build -t "$REPO:$COMMIT" -t "$IMAGE_URI" .
// docker push "$REPO:$COMMIT"
// docker push "$IMAGE_URI"
// '''
//         }
//       }
//     }

    stage('Deploy to EKS') {
        steps {
            sh '''
            # kubectl apply -f k8s/efs.yml || true
            kubectl apply -f k8s/namespace.yml
            kubectl apply -f k8s/service.yml
            kubectl apply -f k8s/statefulset.yml
            kubectl -n nifi rollout status statefulset/nifi --timeout=5m

            LB=$(kubectl -n nifi get svc nifi-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            echo "NiFi URL: http://${LB}:8080/nifi"
            '''
        }
    }

//     stage('Deploy to EKS') {
//       steps {
//         withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
//           dir('k8s') {
//             sh '''#!/usr/bin/env bash
// set -euo pipefail

// # Read outputs from Terraform
// CLUSTER=$(terraform -chdir=../terraform output -raw cluster_name)
// FS_ID=$(terraform -chdir=../terraform output -raw efs_id)
// SC_NAME="efs-sc-${FS_ID}"

// echo "Cluster=${CLUSTER}"
// echo "Using EFS ${FS_ID} with StorageClass ${SC_NAME}"

// # Kube context
// aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER"

// # Namespace + headless service
// kubectl apply -f namespace.yml
// kubectl apply -f service-headless.yml

// # If StatefulSet exists but PVC is bound to a DIFFERENT SC, replace cleanly
// if kubectl -n nifi get sts nifi >/dev/null 2>&1; then
//   PVC_SC=$(kubectl -n nifi get pvc nifi-data-nifi-0 -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
//   if [ "${PVC_SC:-}" != "" ] && [ "${PVC_SC}" != "${SC_NAME}" ]; then
//     echo "StatefulSet exists with PVC SC='${PVC_SC}', needs '${SC_NAME}'. Recreating STS + PVC…"
//     kubectl -n nifi delete sts nifi --wait=true
//     kubectl -n nifi delete pvc -l app=nifi --wait=true || true
//   fi
// fi

// # Create StorageClass only if missing (SC params are immutable)
// if ! kubectl get sc "${SC_NAME}" >/dev/null 2>&1; then
//   sed -e "s/EFS_ID/${FS_ID}/g" -e "s/SC_NAME/${SC_NAME}/g" efs.yml | kubectl apply -f -
// else
//   echo "StorageClass ${SC_NAME} already exists; skipping"
// fi

// # Function to (re)apply StatefulSet; on immutable change, delete and re-apply
// apply_sts() {
//   sed "s/SC_NAME/${SC_NAME}/g" statefulset.yml | kubectl apply -f -
// }

// if ! apply_sts 2>err.log; then
//   if grep -q "updates to statefulset spec" err.log; then
//     echo "Immutable StatefulSet field changed. Recreating StatefulSet…"
//     kubectl -n nifi delete sts nifi --wait=true
//     apply_sts
//   else
//     cat err.log
//     exit 1
//   fi
// fi

// # Public LB for access
// kubectl apply -f service.yml

// # Wait for rollout and print URL
// kubectl -n nifi rollout status sts/nifi --timeout=10m
// LB=$(kubectl -n nifi get svc nifi-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
// echo "NiFi URL: http://${LB}:8080/nifi"
// '''
//           }
//         }
//       }
//     }

    stage('K8s delete') {
      steps {
        withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
          input message: 'Delete K8s', ok: 'Delete'
          sh '''
            kubectl -n nifi scale sts nifi --replicas=0 --timeout=120s || true
            kubectl -n nifi delete sts nifi --cascade=orphan --wait=true || true
            kubectl -n nifi delete svc nifi-lb nifi-headless || true
            '''
        }
      }
    }

    stage('Terraform destroy') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            input message: 'terraform destroy?', ok: 'Destroy'
            sh '''#!/usr/bin/env bash
            set -euo pipefail
            terraform destroy -auto-approve
            '''
          }
        }
      }
    }
  }

  post {
    always {
        sh '''
        kubectl -n nifi scale sts nifi --replicas=0 --timeout=120s || true
        kubectl -n nifi delete sts nifi --cascade=orphan --wait=true || true
        kubectl -n nifi delete svc nifi-lb nifi-headless || true
        '''
    }
  }
}
