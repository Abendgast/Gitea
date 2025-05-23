pipeline {
    agent any

    environment {
        GO111MODULE = 'on'
        NODE_ENV = 'test'
    }

    options {
        timestamps()
        skipDefaultCheckout()
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    def changedFiles = sh(script: "git diff --name-only origin/main", returnStdout: true).trim().split("\n")
                    env.GO_CHANGED = changedFiles.any { it.endsWith(".go") || it.startsWith("go/") }.toString()
                    env.NODE_CHANGED = changedFiles.any { it.endsWith(".js") || it.endsWith(".ts") || it.startsWith("frontend/") }.toString()
                }
            }
        }

        stage('Go Tests') {
            when {
                expression { return env.GO_CHANGED == 'true' }
            }
            steps {
                sh '''
                    echo "[Go Test Stage]"
                    go mod tidy
                    go test ./... -v -coverprofile=coverage.out
                '''
            }
        }

        stage('Node Tests') {
            when {
                expression { return env.NODE_CHANGED == 'true' }
            }
            steps {
                sh '''
                    echo "[Node Test Stage]"
                    npm ci
                    npm test
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: '**/coverage.out', allowEmptyArchive: true
            cleanWs()
        }
        failure {
            echo "❌ CI Failed — please fix the code before merging."
        }
        success {
            echo "✅ All tests passed!"
        }
    }
}


