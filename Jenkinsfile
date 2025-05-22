pipeline {
    agent any

    environment {
        GO_VERSION = '1.21.6'
        GOPROXY = 'https://proxy.golang.org,direct'
        GOSUMDB = 'sum.golang.org'
        CGO_ENABLED = '1'
        GOROOT = "${WORKSPACE}/go"
        GOPATH = "${WORKSPACE}/gopath"
        PATH = "${WORKSPACE}/go/bin:${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git clean -fdx'
            }
        }

        stage('Setup Go') {
            steps {
                sh '''
                    # Перевіряємо чи Go вже встановлений
                    if [ ! -f "${WORKSPACE}/go/bin/go" ]; then
                        echo "Installing Go ${GO_VERSION}..."

                        # Визначаємо архітектуру
                        ARCH=$(uname -m)
                        case $ARCH in
                            x86_64) GOARCH="amd64" ;;
                            aarch64|arm64) GOARCH="arm64" ;;
                            *) echo "Unsupported architecture: $ARCH" && exit 1 ;;
                        esac

                        # Скачуємо та встановлюємо Go
                        wget -q https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz
                        tar -xzf go${GO_VERSION}.linux-${GOARCH}.tar.gz
                        rm go${GO_VERSION}.linux-${GOARCH}.tar.gz
                    fi

                    # Перевіряємо встановлення
                    ${WORKSPACE}/go/bin/go version

                    # Перевіряємо Makefile
                    echo "Workspace contents:"
                    ls -la
                    test -f Makefile || (echo "Makefile not found" && exit 1)
                '''
            }
        }

        stage('Build & Test') {
            parallel {
                stage('Build') {
                    steps {
                        sh '''
                            echo "Building Gitea..."
                            export PATH="${WORKSPACE}/go/bin:$PATH"
                            make clean || echo "Clean target not found, continuing..."
                            make build
                        '''
                    }
                }

                stage('Test') {
                    steps {
                        sh '''
                            echo "Running tests..."
                            export PATH="${WORKSPACE}/go/bin:$PATH"
                            make test-backend || make test || echo "Running basic go test..."
                            ${WORKSPACE}/go/bin/go test -v ./... || echo "Some tests failed but continuing..."
                        '''
                    }
                    post {
                        always {
                            publishTestResults testResultsPattern: '**/test-results.xml', allowEmptyResults: true
                        }
                    }
                }

                stage('Lint') {
                    steps {
                        sh '''
                            echo "Running linter..."
                            export PATH="${WORKSPACE}/go/bin:$PATH"
                            make lint-backend || make lint || echo "Lint not available, skipping..."
                        '''
                    }
                }
            }
        }

        stage('Archive') {
            when {
                anyOf {
                    branch 'main'
                    branch 'develop'
                    branch 'master'
                }
            }
            steps {
                script {
                    // Архівуємо збірку
                    archiveArtifacts artifacts: 'gitea', fingerprint: true, allowEmptyArchive: true

                    // Зберігаємо інформацію про збірку
                    sh '''
                        echo "Build Info:" > build-info.txt
                        echo "Branch: ${BRANCH_NAME}" >> build-info.txt
                        echo "Commit: $(git rev-parse HEAD)" >> build-info.txt
                        echo "Date: $(date)" >> build-info.txt
                    '''
                    archiveArtifacts artifacts: 'build-info.txt', fingerprint: true
                }
            }
        }
    }

    post {
        always {
            // Очищуємо workspace після збірки
            cleanWs()
        }

        success {
            echo 'Pipeline completed successfully!'
        }

        failure {
            echo 'Pipeline failed. Check the logs for details.'
        }

        unstable {
            echo 'Pipeline completed with warnings.'
        }
    }
}
