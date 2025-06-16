pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'PUSH_TO_ECR',
            defaultValue: false,
            description: 'Push image to ECR repository'
        )
    }

    environment {
        DOCKER_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
        IMAGE_NAME = 'gitea-app'
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Info') {
            steps {
                script {
                    def gitCommit = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    def gitBranch = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
                    def buildDate = sh(returnStdout: true, script: 'date +%Y%m%d-%H%M%S').trim()

                    if (gitBranch == 'main' || gitBranch == 'master') {
                        env.IMAGE_TAG = "prod-${buildDate}-${gitCommit}"
                        env.BUILD_TYPE = "production"
                    } else {
                        env.IMAGE_TAG = "dev-${env.BUILD_NUMBER}-${buildDate}-${gitCommit}"
                        env.BUILD_TYPE = "development"
                    }

                    echo "Building ${env.BUILD_TYPE} image with tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh """
                        cd gitea
                        docker build -t ${env.IMAGE_NAME}:${env.IMAGE_TAG} .
                        docker tag ${env.IMAGE_NAME}:${env.IMAGE_TAG} ${env.IMAGE_NAME}:latest
                    """
                }
            }
        }

        stage('Test Image') {
            steps {
                script {
                    sh "docker run --rm ${env.IMAGE_NAME}:${env.IMAGE_TAG} /app/gitea/gitea --version"
                }
            }
        }

        stage('Push to ECR') {
            when {
                params.PUSH_TO_ECR == true
            }
            steps {
                script {
                    sh """
                        # Tag for ECR
                        docker tag ${env.IMAGE_NAME}:${env.IMAGE_TAG} ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}
                        docker tag ${env.IMAGE_NAME}:latest ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:latest

                        # Login to ECR
                        aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.DOCKER_REGISTRY}

                        # Push images
                        docker push ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG}
                        docker push ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:latest
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                sh """
                    docker rmi ${env.IMAGE_NAME}:${env.IMAGE_TAG} || true
                    docker rmi ${env.DOCKER_REGISTRY}/${env.IMAGE_NAME}:${env.IMAGE_TAG} || true
                """
            }
        }
        success {
            echo "Build completed successfully! Image tag: ${env.IMAGE_TAG}"
        }
        failure {
            echo "Build failed!"
        }
    }
}
