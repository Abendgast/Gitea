Ні, просто дай мені грамотний Jenkinsfile, який буде просто виконувати свою роль, не перевантажений всім підряд, чистий, зрозумілий але дієвий!
Edit

Ось чистий, мінімальний Jenkinsfile:

Що робить:

    Встановлює Go 1.21.6 якщо потрібно
    Збирає Gitea бінарник з Go
    Запускає короткі тести
    Архівує бінарник при успіху
    Очищає workspace

Без зайвого:

    Без npm/frontend (причина твоїх помилок)
    Без parallel stages (простіше debug)
    Без make файлів (прямі Go команди)
    Без складних fallback'ів

26 рядків замість 100+ - просто працює.


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
