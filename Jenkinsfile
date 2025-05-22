pipeline {
    agent { label 'gitea-agent' }

    options {
        ansiColor('xterm')
        timestamps()
        skipDefaultCheckout(true)
    }

    environment {
        GO111MODULE = 'on'
        GOPATH = "${WORKSPACE}/go"
        GOCACHE = "${WORKSPACE}/.cache/go-build"
        ARTIFACTS_DIR = "artifacts"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo '✅ Репозиторій отримано.'
            }
        }

        stage('Setup Go') {
            steps {
                sh '''
                    echo "🔧 Встановлення Go-середовища..."
                    mkdir -p ${GOPATH} ${GOCACHE} ${ARTIFACTS_DIR}
                    export PATH=$PATH:/usr/local/go/bin
                    go version
                '''
            }
        }

        stage('Lint') {
            steps {
                sh '''
                    echo "🔍 Перевірка коду..."
                    if ! command -v golint &> /dev/null; then
                        echo "⏬ Встановлення golint..."
                        go install golang.org/x/lint/golint@latest
                    fi
                    golint ./... | tee ${ARTIFACTS_DIR}/golint-report.txt
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    echo "⚙️ Збірка..."
                    go build -v -o ${ARTIFACTS_DIR}/gitea-app ./...
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    echo "🧪 Тестування..."
                    go test -v -cover ./... | tee ${ARTIFACTS_DIR}/test-report.txt
                '''
            }
        }

        stage('Archive Artifacts') {
            steps {
                archiveArtifacts artifacts: '${ARTIFACTS_DIR}/*', onlyIfSuccessful: true
                echo '📦 Артефакти CI збережено.'
            }
        }
    }

    post {
        success {
            echo '✅ CI завершено успішно.'
        }
        failure {
            echo '❌ Помилка в CI.'
        }
        always {
            cleanWs()
            echo '🧹 Очистка робочої директорії.'
        }
    }
}

