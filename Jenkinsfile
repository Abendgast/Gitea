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
    }

    stages {
        stage('Preparation') {
            steps {
                script {
                    def buildDate = sh(script: 'date +%Y%m%d-%H%M%S', returnStdout: true).trim()
                    def commitHash = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    def branchName = env.BRANCH_NAME ?: 'main'
                    def userName = env.BUILD_USER ?: 'jenkins'

                    env.BUILD_DATE = buildDate
                    env.COMMIT_HASH = commitHash
                    env.BRANCH_NAME = branchName
                    env.USER_NAME = userName

                    if (branchName == 'main' || branchName == 'master') {
                        env.VERSION = "prod-${buildDate}-${commitHash}"
                        env.IS_PRODUCTION = 'true'
                    } else {
                        env.VERSION = "dev-${userName}-${BUILD_NUMBER}-${buildDate}-${commitHash}"
                        env.IS_PRODUCTION = 'false'
                    }

                    echo "Building version: ${env.VERSION}"
                    echo "Branch: ${branchName}"
                    echo "Push to ECR: ${params.PUSH_TO_ECR}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${IMAGE_NAME}:${VERSION} ./gitea/"
                sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest"

                script {
                    if (env.IS_PRODUCTION == 'true') {
                        sh "docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:production"
                    }
                }
            }
        }

        stage('Test Image') {
            when {
                expression { return params.RUN_TESTS }
            }
            steps {
                script {
                    try {
                        sh "docker run --rm ${IMAGE_NAME}:${VERSION} /app/gitea/gitea --version"
                        echo "Image test passed successfully"
                    } catch (err) {
                        echo "Warning: Image test failed"
                        echo "Error: ${err.getMessage()}"
                    }
                }
            }
        }

        stage('Tag for ECR') {
            when {
                expression { return params.PUSH_TO_ECR }
            }
            steps {
                sh "docker tag ${IMAGE_NAME}:${VERSION} ${ECR_REGISTRY}:${VERSION}"

                script {
                    if (env.IS_PRODUCTION == 'true') {
                        sh "docker tag ${IMAGE_NAME}:latest ${ECR_REGISTRY}:latest"
                        sh "docker tag ${IMAGE_NAME}:production ${ECR_REGISTRY}:production"
                    }
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression { return params.PUSH_TO_ECR }
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'aws-access-key-id', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
                    sh '''
                        echo "Logging into ECR..."
                        aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
                        aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
                        aws configure set region us-east-1

                        aws ecr get-login-password --region us-east-1 | \
                        docker login --username AWS --password-stdin $ECR_REGISTRY

                        echo "Pushing image..."
                        docker push $ECR_REGISTRY:$VERSION
                    '''

                    script {
                        if (env.IS_PRODUCTION == 'true') {
                            sh '''
                                echo "Pushing production tags..."
                                docker push $ECR_REGISTRY:latest
                                docker push $ECR_REGISTRY:production
                            '''
                        }
                    }
                }
            }
        }

        stage('Cleanup') {
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
            node('docker-agent') {
                sh 'docker system prune -f || true'
            }
        }
        success {
            echo "✅ Pipeline completed successfully!"
            echo "🔖 Built image: ${IMAGE_NAME}:${VERSION}"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
