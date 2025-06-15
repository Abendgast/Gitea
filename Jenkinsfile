pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = '123456789012.dkr.ecr.us-east-1.amazonaws.com' // Замініть на ваш ECR URI
        IMAGE_NAME = 'gitea-app'
        AWS_REGION = 'us-east-1'
        AWS_CREDENTIALS = 'aws-ecr-credentials'
    }

    parameters {
        booleanParam(
            name: 'PUSH_TO_ECR',
            defaultValue: false,
            description: 'Push Docker image to ECR?'
        )
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
                    env.BUILD_VERSION = sh(
                        script: "echo '${env.BRANCH_NAME}-${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(8)}'",
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = env.BRANCH_NAME == 'main' ? 'latest' : env.BUILD_VERSION

                    echo "Building version: ${env.BUILD_VERSION}"
                    echo "Image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    // Білд основного Gitea образу
                    sh """
                        docker build -t ${IMAGE_NAME}:${BUILD_VERSION} ./gitea/
                        docker tag ${IMAGE_NAME}:${BUILD_VERSION} ${IMAGE_NAME}:${IMAGE_TAG}
                    """

                    echo "Built image: ${IMAGE_NAME}:${BUILD_VERSION}"
                    echo "Tagged as: ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }

        stage('Test Local Build') {
            steps {
                script {
                    // Тестуємо білд локально
                    sh """
                        # Перевіряємо чи образ створився
                        docker images | grep ${IMAGE_NAME}

                        # Можемо запустити базові тести
                        docker run --rm ${IMAGE_NAME}:${BUILD_VERSION} /app/gitea/gitea --version || true
                    """
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression { params.PUSH_TO_ECR == true }
            }
            steps {
                script {
                    withAWS(credentials: AWS_CREDENTIALS, region: AWS_REGION) {
                        // Логінимось в ECR
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}
                        """

                        // Тегуємо для ECR
                        sh """
                            docker tag ${IMAGE_NAME}:${BUILD_VERSION} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_VERSION}
                            docker tag ${IMAGE_NAME}:${BUILD_VERSION} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        """

                        // Пушимо в ECR
                        sh """
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_VERSION}
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}
                        """

                        echo "Pushed to ECR: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_VERSION}"
                        echo "Pushed to ECR: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Cleanup') {
            steps {
                script {
                    // Очищуємо локальні образи щоб не засмічувати диск
                    sh """
                        docker rmi ${IMAGE_NAME}:${BUILD_VERSION} || true
                        docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true
                        docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${BUILD_VERSION} || true
                        docker rmi ${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG} || true
                    """
                }
            }
        }
    }

    post {
        always {
            // Очищуємо workspace
            cleanWs()
        }
        success {
            echo "Pipeline completed successfully!"
            echo "Image version: ${env.BUILD_VERSION}"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
