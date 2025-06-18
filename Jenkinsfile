pipeline {
    agent {
        label 'docker-agent'
    }

    parameters {
        booleanParam(
            name: 'PUSH_TO_ECR',
            defaultValue: false,
            description: 'Push image to ECR repository'
        )
        string(
            name: 'USER_NAME',
            defaultValue: 'jenkins',
            description: 'User name to include in dev tags'
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
                    def userName = params.USER_NAME ?: 'jenkins'

                    if (gitBranch == 'main' || gitBranch == 'master') {
                        env.IMAGE_TAG = "prod-${buildDate}-${gitCommit}"
                        env.BUILD_TYPE = "production"
                    } else {
                        env.IMAGE_TAG = "dev-${userName}-${env.BUILD_NUMBER}-${buildDate}-${gitCommit}"
                        env.BUILD_TYPE = "development"
                    }

                    echo "Building ${env.BUILD_TYPE} image with tag: ${env.IMAGE_TAG}"
                    echo "Branch: ${gitBranch}"
                    echo "Commit: ${gitCommit}"
                    echo "Build Date: ${buildDate}"
                    echo "User: ${userName}"
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
                    sh """
                        echo "Testing Gitea version..."
                        docker run --rm ${env.IMAGE_NAME}:${env.IMAGE_TAG} /app/gitea/gitea --version
                        echo "Image test completed successfully"
                    """
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression {
                    return params.PUSH_TO_ECR
                }
            }
            steps {
                script {
                    sh """
                        echo "Preparing to push to ECR..."

                        # Tag for ECR
                        docker tag ${env.IMAGE_NAME}:${env.IMAGE_TAG} ${env.DOCKER_REGISTRY}:${env.IMAGE_TAG}

                        # Only tag latest for production builds
                        if [ "${env.BUILD_TYPE}" = "production" ]; then
                            docker tag ${env.IMAGE_NAME}:latest ${env.DOCKER_REGISTRY}:latest
                        fi

                        # Login to ECR
                        aws ecr get-login-password --region ${env.AWS_REGION} | docker login --username AWS --password-stdin ${env.DOCKER_REGISTRY}

                        # Push images
                        docker push ${env.DOCKER_REGISTRY}:${env.IMAGE_TAG}

                        if [ "${env.BUILD_TYPE}" = "production" ]; then
                            docker push ${env.DOCKER_REGISTRY}:latest
                            echo "Pushed production image with latest tag"
                        else
                            echo "Development image pushed without latest tag"
                        fi
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                sh """
                    # Clean up local images
                    docker rmi ${env.IMAGE_NAME}:${env.IMAGE_TAG} || true
                    docker rmi ${env.IMAGE_NAME}:latest || true
                    docker rmi ${env.DOCKER_REGISTRY}:${env.IMAGE_TAG} || true
                    if [ "${env.BUILD_TYPE}" = "production" ]; then
                        docker rmi ${env.DOCKER_REGISTRY}:latest || true
                    fi
                """
            }
        }
        success {
            script {
                if (params.PUSH_TO_ECR) {
                    echo "Build and push completed successfully!"
                    echo "Image: ${env.DOCKER_REGISTRY}:${env.IMAGE_TAG}"
                    echo "Tag: ${env.IMAGE_TAG}"
                    echo "Build Type: ${env.BUILD_TYPE}"
                } else {
                    echo "Build completed successfully!"
                    echo "Image tag: ${env.IMAGE_TAG}"
                    echo "Image not pushed to ECR (PUSH_TO_ECR=false)"
                }
            }
        }
        failure {
            echo "Build failed! Check logs for details."
        }
    }
}
