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
            docker system prune -af
            docker builder prune -af
            '''
        }
    }

    stage('Terraform apply') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            sh '''
            terraform init -input=false -migrate-state -force-copy
            terraform apply -auto-approve
            '''
          }
        }
      }
    }

    stage('Build & push image') {
      steps {
        withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
          sh '''
            REPO=${IMAGE_URI%:*}
            aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REPO"
            docker build -t "$REPO:latest" -t "$IMAGE_URI" .
            docker push "$REPO:latest"
            docker push "$IMAGE_URI"
            '''
        }
      }
    }

    stage('Deploy to EKS') {
        steps {
            input message: 'Deploy to EKS? (finished setting up kubectl on first run)', ok: 'Yes'

            sh '''
            kubectl apply -f k8s/namespace.yml
            kubectl apply -f k8s/efs.yml || true
            kubectl apply -f k8s/service-headless.yml
            kubectl apply -f k8s/service.yml
            kubectl apply -f k8s/statefulset.yml
            kubectl -n nifi rollout status statefulset/nifi --timeout=5m

            LB=$(kubectl -n nifi get svc nifi-lb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            echo "nifi URL: http://${LB}:8080/nifi"
            '''
        }
    }

    stage('K8s delete') {
      steps {
        withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
          input message: 'Delete K8s', ok: 'Delete'
          sh '''
            kubectl -n nifi scale sts nifi --replicas=0 --timeout=120s 
            kubectl -n nifi delete sts nifi --cascade=orphan --wait=true
            kubectl -n nifi delete svc nifi-lb nifi-headless 
            '''
        }
      }
    }

    stage('Terraform destroy') {
      steps {
        dir('terraform') {
          withCredentials([[$class:'AmazonWebServicesCredentialsBinding', credentialsId:'aws-devops']]) {
            input message: 'terraform destroy?', ok: 'Destroy'
            sh '''
            terraform destroy -auto-approve
            '''
          }
        }
      }
    }
  }
}
