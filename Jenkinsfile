pipeline {
  agent any
  environment {
    ECR_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com'
    IMAGE_NAME = 'gitea-app'
  }
  stages {
    stage('Login to ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
        '''
      }
    }
    stage('Build Docker Image') {
      steps {
        sh '''
          docker build -t $IMAGE_NAME:latest .
          docker tag $IMAGE_NAME:latest $ECR_REGISTRY/$IMAGE_NAME:latest
        '''
      }
    }
    stage('Push to ECR') {
      steps {
        sh '''
          docker push $ECR_REGISTRY/$IMAGE_NAME:latest
        '''
      }
    }
  }
}
