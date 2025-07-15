pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        ECR_URL_1 = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
        ECR_URL_2 = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-application'
    }

    stages {
        stage('Login to ECR') {
            steps {
                sh 'aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_URL_1'
            }
        }

        stage('Build and Push Images') {
            steps {
                sh '''
                docker build -t gitea-app .
                docker tag gitea-app:latest $ECR_URL_1:latest
                docker push $ECR_URL_1:latest

                docker build -t gitea-application .
                docker tag gitea-application:latest $ECR_URL_2:latest
                docker push $ECR_URL_2:latest
                '''
            }
        }
    }
}
