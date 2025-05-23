pipeline {
    agent {
        label 'gitea-build-agent'
    }

    environment {
        GOPATH = "${WORKSPACE}/go"
        NODE_ENV = 'ci'
        PATH = "${WORKSPACE}/node_modules/.bin:${env.PATH}"
    }

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    stages {

        stage('Checkout') {
            steps {
                cleanWs()
                git url: 'https://github.com/Abendgast/Gitea.git', credentialsId: 'github-credentials', branch: 'main'
            }
        }

        stage('Prepare Go') {
            steps {
                sh '''
                    mkdir -p $GOPATH
                    go mod tidy
                '''
            }
        }

        stage('Build & Test Go') {
            steps {
                sh '''
                    go build ./...
                    go test ./... -v -coverprofile=coverage.out
                '''
            }
        }

        stage('Setup Node') {
            steps {
                sh '''
                    rm -rf node_modules package-lock.json
                    npm ci
                '''
            }
        }

        stage('Lint & Test Node') {
            steps {
                sh '''
                    npm run lint || true  # не падаємо на warning
                    npm test
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/coverage.out', allowEmptyArchive: true
            junit '**/test-results/**/*.xml'
            cleanWs()
        }
        failure {
            echo '❌ Build failed.'
        }
        success {
            echo '✅ Build succeeded!'
        }
    }
}

