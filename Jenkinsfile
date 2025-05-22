pipeline {
    agent {
        label 'linux'
    }

    options {
        // Таймаут для всього пайплайну
        timeout(time: 30, unit: 'MINUTES')
        // Очищення workspace перед кожним білдом
        skipDefaultCheckout()
        // Додавання timestamp до логів
        timestamps()
    }

    environment {
        // Змінні середовища для білду
        GITEA_VERSION = sh(returnStdout: true, script: 'git describe --tags --always').trim()
        BUILD_NUMBER = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "gitea-custom:${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                // Очищення та checkout коду
                cleanWs()
                checkout scm

                script {
                    // Отримання інформації про коміт
                    env.GIT_COMMIT_SHORT = sh(
                        returnStdout: true,
                        script: 'git rev-parse --short HEAD'
                    ).trim()
                }
            }
        }

        stage('Environment Info') {
            steps {
                sh '''
                    echo "=== Environment Information ==="
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Commit: ${GIT_COMMIT_SHORT}"
                    echo "Gitea Version: ${GITEA_VERSION}"
                    echo "Node Name: ${NODE_NAME}"
                    echo "Workspace: ${WORKSPACE}"
                    echo "================================"
                '''
            }
        }

        stage('Code Analysis') {
            parallel {
                stage('Lint Check') {
                    steps {
                        sh '''
                            echo "Running code linting..."
                            # Тут можна додати golint, eslint тощо
                            find . -name "*.go" | head -5
                            echo "Linting completed"
                        '''
                    }
                }

                stage('Security Scan') {
                    steps {
                        sh '''
                            echo "Running security analysis..."
                            # Тут можна додати gosec, npm audit тощо
                            echo "Security scan completed"
                        '''
                    }
                }
            }
        }

        stage('Build Dependencies') {
            steps {
                sh '''
                    echo "Installing build dependencies..."
                    # Для Go проекту
                    if [ -f "go.mod" ]; then
                        echo "Go project detected"
                        go version || echo "Go not installed"
                    fi

                    # Для Node.js компонентів
                    if [ -f "package.json" ]; then
                        echo "Node.js project detected"
                        npm --version || echo "Node.js not installed"
                    fi

                    echo "Dependencies check completed"
                '''
            }
        }

        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                            echo "Running unit tests..."
                            mkdir -p test-results

                            # Приклад тестування для Go
                            if [ -f "go.mod" ]; then
                                echo "Running Go tests..."
                                # go test -v ./... > test-results/go-tests.log 2>&1 || true
                                echo "Go tests would run here"
                            fi

                            echo "Unit tests completed"
                        '''
                    }
                    post {
                        always {
                            // Збереження результатів тестів
                            archiveArtifacts artifacts: 'test-results/*.log', allowEmptyArchive: true
                        }
                    }
                }

                stage('Integration Tests') {
                    steps {
                        sh '''
                            echo "Running integration tests..."
                            # Тут можуть бути тести БД, API тощо
                            echo "Integration tests completed"
                        '''
                    }
                }
            }
        }

        stage('Build Application') {
            steps {
                sh '''
                    echo "Building Gitea application..."
                    mkdir -p build-artifacts

                    # Створення mock артефакту для демонстрації
                    echo "Gitea Custom Build ${BUILD_NUMBER}" > build-artifacts/version.txt
                    echo "Commit: ${GIT_COMMIT_SHORT}" >> build-artifacts/version.txt
                    echo "Built on: $(date)" >> build-artifacts/version.txt

                    # Тут би був реальний білд Gitea
                    # make build або go build

                    echo "Build completed successfully"
                '''
            }
        }

        stage('Docker Build') {
            when {
                // Виконується тільки для main/master гілки
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                script {
                    // Створення Dockerfile якщо його немає
                    sh '''
                        if [ ! -f "Dockerfile" ]; then
                            echo "Creating sample Dockerfile..."
                            cat > Dockerfile << 'EOF'
FROM alpine:latest
RUN apk add --no-cache ca-certificates
WORKDIR /app
COPY build-artifacts/ /app/
CMD ["cat", "/app/version.txt"]
EOF
                        fi
                    '''

                    // Білд Docker образу
                    sh "docker build -t ${DOCKER_IMAGE} ."
                    sh "docker images | grep gitea-custom"
                }
            }
        }

        stage('Artifact Management') {
            steps {
                sh '''
                    echo "Preparing artifacts for archival..."

                    # Створення архіву з артефактами
                    tar -czf gitea-build-${BUILD_NUMBER}.tar.gz build-artifacts/

                    # Створення метаданих
                    cat > build-metadata.json << EOF
{
    "build_number": "${BUILD_NUMBER}",
    "git_commit": "${GIT_COMMIT_SHORT}",
    "version": "${GITEA_VERSION}",
    "timestamp": "$(date -Iseconds)",
    "docker_image": "${DOCKER_IMAGE}"
}
EOF
                '''
            }
            post {
                always {
                    // Архівування артефактів
                    archiveArtifacts artifacts: '*.tar.gz,build-metadata.json,build-artifacts/**', allowEmptyArchive: true
                }
            }
        }
    }

    post {
        always {
            // Очищення Docker образів для економії місця
            sh '''
                echo "Cleanup: removing old Docker images..."
                docker images | grep gitea-custom | awk '{print $3}' | tail -n +3 | xargs -r docker rmi || true
            '''
        }

        success {
            echo "✅ Pipeline completed successfully!"
            // Тут можна додати нотифікації
        }

        failure {
            echo "❌ Pipeline failed!"
            // Тут можна додати нотифікації про помилку
        }

        unstable {
            echo "⚠️ Pipeline completed with warnings"
        }
    }
}
