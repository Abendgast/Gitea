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
        BUILD_DATE = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
        COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        BRANCH_NAME = env.BRANCH_NAME ?: 'main'
        USER_NAME = env.BUILD_USER ?: 'jenkins'
    }

    stages {
        stage('Load Environment') {
            steps {
                script {
                    sh '''
                        if [ ! -f secrets/.env ]; then
                            if [ -f .env.enc ]; then
                                echo "Decrypting environment file..."
                                make decrypt
                            else
                                echo "ERROR: No environment file found!"
                                exit 1
                            fi
                        fi

                        echo "Loading AWS credentials from secrets/.env"
                        export $(cat secrets/.env | grep -E '^AWS_' | xargs)

                        # Verify credentials are loaded
                        if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
                            echo "ERROR: AWS credentials not found in secrets/.env"
                            exit 1
                        fi

                        echo "AWS credentials loaded successfully"
                    '''
                }
            }
        }

        stage('Preparation') {
            steps {
                script {
                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        env.VERSION = "prod-${BUILD_DATE}-${COMMIT_HASH}"
                        env.IS_PRODUCTION = 'true'
                    } else {
                        env.VERSION = "dev-${USER_NAME}-${BUILD_NUMBER}-${BUILD_DATE}-${COMMIT_HASH}"
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
                        set -e

                        # Load AWS credentials from .env
                        export $(cat secrets/.env | grep -E '^AWS_' | xargs)

                        echo "Logging in to ECR..."
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

                        echo "Pushing main image..."
                        docker push $ECR_REGISTRY:$VERSION
                    '''

                    if (env.IS_PRODUCTION == 'true') {
                        sh '''
                            export $(cat secrets/.env | grep -E '^AWS_' | xargs)
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
                sh '''
                    docker system prune -f || true

                    # Clean up environment file if it was decrypted during build
                    if [ -f secrets/.env ] && [ -f .env.enc ]; then
                        echo "Cleaning up decrypted environment file..."
                        rm -f secrets/.env
                    fi
                '''
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
            script {
                sh '''
                    # Clean up environment file even on failure
                    if [ -f secrets/.env ] && [ -f .env.enc ]; then
                        rm -f secrets/.env
                    fi
                '''
            }
        }
    }
}
