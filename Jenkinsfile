pipeline {
    agent any

    environment {
        // Docker registry налаштування
        DOCKER_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
        IMAGE_NAME = 'gitea-app'
        AWS_REGION = 'us-east-1'

        // Versioning strategy
        BUILD_TIMESTAMP = sh(script: "date +%Y%m%d-%H%M%S", returnStdout: true).trim()
        GIT_SHORT_COMMIT = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
        DEVELOPER_NAME = 'jenkins'
    }

    parameters {
        booleanParam(
            name: 'PUSH_TO_ECR',
            defaultValue: false,
            description: 'Push image to AWS ECR?'
        )
        choice(
            name: 'BUILD_TYPE',
            choices: ['dev', 'staging', 'production'],
            description: 'Build type for tagging strategy'
        )
    }

    options {
        timestamps()
        skipDefaultCheckout()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
                script {
                    // Додаткові змінні для версіонування
                    env.BRANCH_NAME = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    env.BUILD_VERSION = generateBuildVersion()
                }
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    // Перевіряємо чи є зміни в коді (якщо потрібно)
                    def changedFiles = sh(
                        script: "git diff --name-only HEAD~1 2>/dev/null || echo 'all'",
                        returnStdout: true
                    ).trim()

                    env.DOCKERFILE_CHANGED = changedFiles.contains('Dockerfile') || changedFiles.contains('all')
                    echo "Changed files: ${changedFiles}"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "🏗️ Building Docker image with version: ${env.BUILD_VERSION}"

                    // Білд основного образу
                    sh """
                        docker build -t ${IMAGE_NAME}:${env.BUILD_VERSION} .
                        docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${IMAGE_NAME}:latest
                    """

                    // Додаткові теги залежно від типу білда
                    if (params.BUILD_TYPE == 'production') {
                        sh "docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${IMAGE_NAME}:production"
                        sh "docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${IMAGE_NAME}:stable"
                    } else if (params.BUILD_TYPE == 'staging') {
                        sh "docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${IMAGE_NAME}:staging"
                    }

                    // Показуємо створені образи
                    sh "docker images ${IMAGE_NAME}"
                }
            }
        }

        stage('Test Docker Image') {
            steps {
                script {
                    echo "🧪 Testing Docker image..."

                    // Базовий тест - перевіряємо чи запускається контейнер
                    sh """
                        # Запускаємо контейнер в детач режимі
                        CONTAINER_ID=\$(docker run -d --name test-${BUILD_NUMBER} ${IMAGE_NAME}:${env.BUILD_VERSION})

                        # Чекаємо 10 секунд
                        sleep 10

                        # Перевіряємо чи контейнер працює
                        if docker ps | grep \$CONTAINER_ID; then
                            echo "✅ Container is running successfully"
                        else
                            echo "❌ Container failed to start"
                            docker logs \$CONTAINER_ID
                            exit 1
                        fi

                        # Очищуємо тестовий контейнер
                        docker stop \$CONTAINER_ID || true
                        docker rm \$CONTAINER_ID || true
                    """
                }
            }
        }

        stage('Push to ECR') {
            when {
                expression { return params.PUSH_TO_ECR }
            }
            steps {
                script {
                    echo "🚀 Pushing to AWS ECR..."

                    sh """
                        # Логінимося в ECR
                        aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${DOCKER_REGISTRY}

                        # Тегуємо для ECR
                        docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BUILD_VERSION}
                        docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest

                        # Пушимо образи
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BUILD_VERSION}
                        docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:latest
                    """

                    // Додаткові теги для ECR
                    if (params.BUILD_TYPE == 'production') {
                        sh """
                            docker tag ${IMAGE_NAME}:${env.BUILD_VERSION} ${DOCKER_REGISTRY}/${IMAGE_NAME}:production
                            docker push ${DOCKER_REGISTRY}/${IMAGE_NAME}:production
                        """
                    }

                    echo "✅ Successfully pushed to ECR: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BUILD_VERSION}"
                }
            }
        }

        stage('Update Docker Compose') {
            when {
                expression { return env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master' }
            }
            steps {
                script {
                    echo "📝 Updating docker-compose with new image version..."

                    // Оновлюємо docker-compose.yml з новою версією образу
                    sh """
                        if [ -f docker-compose.yml ]; then
                            sed -i 's|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${env.BUILD_VERSION}|g' docker-compose.yml
                            echo "Updated docker-compose.yml with version ${env.BUILD_VERSION}"
                        fi
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                // Очищуємо Docker образи для економії місця
                sh """
                    docker system prune -f
                    docker images -q --filter 'dangling=true' | xargs -r docker rmi || true
                """

                // Архівуємо артефакти
                if (fileExists('docker-compose.yml')) {
                    archiveArtifacts artifacts: 'docker-compose.yml', fingerprint: true
                }

                if (fileExists('Dockerfile')) {
                    archiveArtifacts artifacts: 'Dockerfile', fingerprint: true
                }
            }
            cleanWs()
        }

        success {
            script {
                def message = "✅ Build successful!\n" +
                             "📦 Image: ${IMAGE_NAME}:${env.BUILD_VERSION}\n" +
                             "🏷️ Build type: ${params.BUILD_TYPE}\n" +
                             "🌿 Branch: ${env.BRANCH_NAME}\n" +
                             "💾 Commit: ${env.GIT_SHORT_COMMIT}"

                if (params.PUSH_TO_ECR) {
                    message += "\n🚀 Pushed to ECR: ${DOCKER_REGISTRY}/${IMAGE_NAME}:${env.BUILD_VERSION}"
                }

                echo message
            }
        }

        failure {
            echo "❌ Build failed! Check the logs above for details."
        }
    }
}

// Функція для генерації версії білда
def generateBuildVersion() {
    def buildType = params.BUILD_TYPE ?: 'dev'
    def timestamp = env.BUILD_TIMESTAMP
    def commit = env.GIT_SHORT_COMMIT
    def buildNum = env.BUILD_NUMBER
    def devName = env.DEVELOPER_NAME

    switch(buildType) {
        case 'production':
            return "v1.0.${buildNum}-${commit}"
        case 'staging':
            return "staging-${timestamp}-${commit}"
        case 'dev':
        default:
            return "${devName}-dev-${timestamp}-${commit}-${buildNum}"
    }
}
