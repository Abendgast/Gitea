pipeline {
    agent {
        label 'docker-agent'
    }

    parameters {
        booleanParam(
            name: 'PUSH_TO_ECR',
            defaultValue: false,
            description: 'Push Docker image to ECR registry'
        )
        booleanParam(
            name: 'RUN_TESTS',
            defaultValue: true,
            description: 'Run tests after building image'
        )
    }

    environment {
        IMAGE_NAME = 'gitea-app'
        ECR_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
        AWS_DEFAULT_REGION = 'us-east-1'
        BUILD_DATE = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
        COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    stages {
        stage('Preparation') {
            steps {
                script {
                    env.BRANCH_NAME = env.BRANCH_NAME ?: 'main'
                    env.USER_NAME = env.BUILD_USER ?: 'jenkins'

                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        env.VERSION = "prod-${BUILD_DATE}-${COMMIT_HASH}"
                        env.IS_PRODUCTION = 'true'
                    } else {
                        env.VERSION = "dev-${env.USER_NAME}-${BUILD_NUMBER}-${BUILD_DATE}-${COMMIT_HASH}"
                        env.IS_PRODUCTION = 'false'
                    }

                    echo "Building version: ${VERSION}"
                    echo "Branch: ${BRANCH_NAME}"
                    echo "Is Production: ${IS_PRODUCTION}"
                    echo "Push to ECR: ${params.PUSH_TO_ECR}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    sh "docker build -t ${IMAGE_NAME}:${VERSION} ./gitea/"
                    sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest"

                    if (env.IS_PRODUCTION == 'true') {
                        sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:production"
                    }

                    echo "Successfully built: ${IMAGE_NAME}:${VERSION}"
                }
            }
        }

        stage('Test Image') {
            when {
                expression { params.RUN_TESTS }
            }
            steps {
                script {
                    try {
                        sh "docker run --rm ${IMAGE_NAME}:${VERSION} /app/gitea/gitea --version"
                        echo "Image test passed successfully"
                    } catch (Exception e) {
                        echo "Warning: Image test failed, but continuing build"
                        echo "Error: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Tag for ECR') {
            when {
                expression { params.PUSH_TO_ECR }
            }
            steps {
                script {
                    sh "docker tag ${IMAGE_NAME}:${VERSION} ${ECR_REGISTRY}:${VERSION}"

                    if (env.IS_PRODUCTION == 'true') {
                        sh "docker tag ${IMAGE_NAME}:latest ${ECR_REGISTRY}:latest"
                        sh "docker tag ${IMAGE_NAME}:production ${ECR_REGISTRY}:production"
                        echo "Tagged production images for ECR"
                    }

                    echo "Tagged for ECR: ${ECR_REGISTRY}:${VERSION}"
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression { params.PUSH_TO_ECR }
            }
            steps {
                script {
                    sh '''
                        echo "Logging in to ECR..."
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

                        echo "Pushing main image..."
                        docker push $ECR_REGISTRY:$VERSION
                    '''

                    if (env.IS_PRODUCTION == 'true') {
                        sh '''
                            echo "Pushing production tags..."
                            docker push $ECR_REGISTRY:latest
                            docker push $ECR_REGISTRY:production
                        '''
                        echo "Pushed production tags to ECR"
                    }

                    echo "Successfully pushed to ECR: ${ECR_REGISTRY}:${VERSION}"
                }
            }
        }

        stage('Cleanup Local Images') {
            steps {
                script {
                    sh """
                        docker rmi ${IMAGE_NAME}:${VERSION} || true
                        docker rmi ${IMAGE_NAME}:latest || true
                        docker rmi ${ECR_REGISTRY}:${VERSION} || true
                    """

                    if (env.IS_PRODUCTION == 'true') {
                        sh """
                            docker rmi ${IMAGE_NAME}:production || true
                            docker rmi ${ECR_REGISTRY}:latest || true
                            docker rmi ${ECR_REGISTRY}:production || true
                        """
                    }

                    echo "Cleaned up local images"
                }
            }
        }
    }

    post {
        always {
            script {
                sh 'docker system prune -f || true'
            }
        }
        success {
            echo "Pipeline completed successfully!"
            echo "Built image: ${IMAGE_NAME}:${VERSION}"
            script {
                if (params.PUSH_TO_ECR) {
                    echo "Image available in ECR: ${ECR_REGISTRY}:${VERSION}"
                }
            }
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
