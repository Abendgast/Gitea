pipeline {
    agent any

    environment {
        GO111MODULE = 'on'
        NODE_ENV = 'test'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Detect Changed Go Files') {
            steps {
                script {
                    env.GO_CHANGED = sh(
                        script: 'git diff --name-only HEAD~1 HEAD | grep \\.go$ || true',
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Go: Dependencies & Tests') {
            when {
                expression { return env.GO_CHANGED }
            }
            steps {
                dir('backend') {
                    sh 'go mod tidy'
                    sh 'go vet ./...'
                    sh 'go test -v -cover ./...'
                }
            }
        }

        stage('Node.js: Install & Lint & Test') {
            steps {
                dir('frontend') {
                    sh 'npm ci'
                    sh 'npm run lint'
                    sh 'npm test -- --watchAll=false'
                }
            }
        }
    }

    post {
        always {
            echo 'Pipeline complete.'
        }
        failure {
            echo '❌ Build failed!'
        }
        success {
            echo '✅ Build succeeded!'
        }
    }
}

