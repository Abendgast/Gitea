pipeline {
    agent {
        label 'docker-agent'
    }

    parameters {
        booleanParam(name: 'PUSH_TO_ECR', defaultValue: false, description: 'Push Docker image to ECR registry')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run tests after building image')
    }

    environment {
        IMAGE_NAME = 'gitea-app'
        ECR_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_ACCESS_KEY_ID = credentials('aws-access-key-id')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
    }

    stages {
        stage('Preparation') {
            steps {
                script {
                    def BUILD_DATE = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def COMMIT_HASH = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    def BRANCH = env.BRANCH_NAME ?: 'main'
                    def USER = env.BUILD_USER ?: 'jenkins'

                    env.BUILD_DATE = BUILD_DATE
                    env.COMMIT_HASH = COMMIT_HASH
                    env.BRANCH_NAME = BRANCH
                    env.USER_NAME = USER

                    if (BRANCH == 'main' || BRANCH == 'master') {
                        env.VERSION = "prod-${BUILD_DATE}-${COMMIT_HASH}"
                        env.IS_PRODUCTION = 'true'
                    } else {
                        env.VERSION = "dev-${USER}-${BUILD_NUMBER}-${BUILD_DATE}-${COMMIT_HASH}"
                        env.IS_PRODUCTION = 'false'
                    }

                    echo "Branch: ${BRANCH}, Version: ${env.VERSION}, Production: ${env.IS_PRODUCTION}"
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
                }
            }
        }

        stage('Test Image') {
            when { expression { params.RUN_TESTS } }
            steps {
                script {
                    try {
                        sh "docker run --rm ${IMAGE_NAME}:${VERSION} /app/gitea/gitea --version"
                    } catch (e) {
                        echo "Image test failed, but continuing. Error: ${e.getMessage()}"
                    }
                }
            }
        }

        stage('Tag for ECR') {
            when { expression { params.PUSH_TO_ECR } }
            steps {
                script {
                    sh "docker tag ${IMAGE_NAME}:${VERSION} ${ECR_REGISTRY}:${VERSION}"
                    if (env.IS_PRODUCTION == 'true') {
                        sh "docker tag ${IMAGE_NAME}:latest ${ECR_REGISTRY}:latest"
                        sh "docker tag ${IMAGE_NAME}:production ${ECR_REGISTRY}:production"
                    }
                }
            }
        }

        stage('Push to ECR') {
            when { expression { params.PUSH_TO_ECR } }
            steps {
                script {
                    sh '''
                        echo "Logging in to ECR..."
                        aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                        docker push $ECR_REGISTRY:$VERSION
                    '''
                    if (env.IS_PRODUCTION == 'true') {
                        sh '''
                            docker push $ECR_REGISTRY:latest
                            docker push $ECR_REGISTRY:production
                        '''
                    }
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
                }
            }
        }
    }

    post {
        always {
            node {
                sh 'docker system prune -f || true'
            }
        }
        success {
            echo "Pipeline completed successfully!"
        }
        failure {
            echo "Pipeline failed!"
        }
    }
}
