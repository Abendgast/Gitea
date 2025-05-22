pipeline {
    agent any

    environment {
        GO_VERSION = '1.21.6'
        GOROOT = "${WORKSPACE}/go"
        PATH = "${WORKSPACE}/go/bin:${env.PATH}"
    }

    stages {
        stage('Setup') {
            steps {
                checkout scm
                sh '''
                    # Встановлюємо Go якщо потрібно
                    if [ ! -f go/bin/go ]; then
                        wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
                        tar -xzf go${GO_VERSION}.linux-amd64.tar.gz
                        rm go${GO_VERSION}.linux-amd64.tar.gz
                    fi
                    go version
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    export CGO_ENABLED=1
                    go build -o gitea ./cmd/gitea
                '''
            }
        }

        stage('Test') {
            steps {
                sh 'go test -short ./...'
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'gitea', fingerprint: true
        }
        always {
            cleanWs()
        }
    }
}
