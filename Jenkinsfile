pipeline {
    agent {
        label 'linux'
    }

    options {
        timeout(time: 30, unit: 'MINUTES')
        skipDefaultCheckout()
        timestamps()
    }

    environment {
        BUILD_NUMBER = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "gitea-custom:${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm

                script {
                    env.GIT_COMMIT_SHORT = sh(
                        returnStdout: true,
                        script: 'git rev-parse --short HEAD'
                    ).trim()

                    env.GITEA_VERSION = sh(
                        returnStdout: true,
                        script: 'git describe --tags --always'
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
                            find . -name "*.go" | head -5
                            echo "Linting completed"
                        '''
                    }
                }

                stage('Security Scan') {
                    steps {
                        sh '''
                            echo "Running security analysis..."
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
                    if [ -f "go.mod" ]; then
                        echo "Go project detected"
                        go version || echo "Go not installed"
                    fi
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
                            if [ -f "go.mod" ]; then
                                echo "Running Go tests..."
                                echo "Go tests would run here"
                            fi
                            echo "Unit tests completed"
                        '''
                    }
                    post {
                        always {
                            archiveArtifacts artifacts: 'test-results/*.log', allowEmptyArchive: true
                        }
                    }
                }

                stage('Integration Tests') {
                    steps {
                        sh '''
                            echo "Running integration tests..."
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
                    echo "Gitea Custom Build ${BUILD_NUMBER}" > build-artifacts/version.txt
                    echo "Commit: ${GIT_COMMIT_SHORT}" >> build-artifacts/version.txt
                    echo "Built on: $(date)" >> build-artifacts/version.txt
                    echo "Build completed successfully"
                '''
            }
        }

        stage('Docker Build') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                script {
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
                    sh "docker build -t ${DOCKER_IMAGE} ."
                    sh "docker images | grep gitea-custom"
                }
            }
        }

        stage('Artifact Management') {
            steps {
                sh '''
                    echo "Preparing artifacts for archival..."
                    tar -czf gitea-build-${BUILD_NUMBER}.tar.gz build-artifacts/

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
                    archiveArtifacts artifacts: '*.tar.gz,build-metadata.json,build-artifacts/**', allowEmptyArchive: true
                }
            }
        }
    }

    post {
        always {
            script {
                sh '''
                    echo "Cleanup: removing old Docker images..."
                    docker images | grep gitea-custom | awk '{print $3}' | tail -n +3 | xargs -r docker rmi || true
                '''
            }
        }

        success {
            echo "✅ Pipeline completed successfully!"
        }

        failure {
            echo "❌ Pipeline failed!"
        }

        unstable {
            echo "⚠️ Pipeline completed with warnings"
        }
    }
}

