pipeline {
    agent any

    triggers {
        githubPush()  // автоматично тригерить при пуші
    }

    environment {
        GO111MODULE = 'on'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                echo "🏗️ Building..."
                sh 'go build -v ./...'
            }
        }

        stage('Test') {
            steps {
                echo "🧪 Running tests..."
                sh 'go test -v ./...'
            }
        }
    }

    post {
        success {
            echo "✅ Pipeline finished successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}

