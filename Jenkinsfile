pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = "${env.AWS_DEFAULT_REGION ?: 'us-east-1'}"
        ECR_REGISTRY = "${env.ECR_REPOSITORY_URL ? env.ECR_REPOSITORY_URL.split('/')[0] : '680833125636.dkr.ecr.us-east-1.amazonaws.com'}"
        ECR_REPOSITORY = 'gitea-app'
        IMAGE_TAG = "${BUILD_NUMBER}-${GIT_COMMIT.substring(0,7)}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image with tag: ${IMAGE_TAG}"
                    sh """
                        docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .
                        docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        
        stage('Login to ECR') {
            steps {
                script {
                    sh """
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    """
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    sh """
                        docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
                        docker tag ${ECR_REPOSITORY}:latest ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                        
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                    """
                }
            }
        }
        
        stage('Clean up') {
            steps {
                script {
                    sh """
                        docker rmi ${ECR_REPOSITORY}:${IMAGE_TAG} || true
                        docker rmi ${ECR_REPOSITORY}:latest || true
                        docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG} || true
                        docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest || true
                    """
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        success {
            echo "Successfully pushed image to ECR: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed. Please check the logs."
        }
    }
}
