pipeline {
    agent { label 'gitea-build-agent' }

    environment {
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
                checkout([
                    $class: 'GitSCM',
                    userRemoteConfigs: [[
                        url: 'https://github.com/Abendgast/Gitea.git',
                        credentialsId: 'github-credentials'
                    ]],
                    branches: [[name: '*/main']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [[$class: 'CleanBeforeCheckout']]
                ])
            }
        }

        stage('Detect Changes') {
            steps {
                script {
                    def changes = sh(
                        script: 'git diff --name-only HEAD~1',
                        returnStdout: true
                    ).trim().split('\n')

                    env.RUN_GO = changes.any { it.endsWith('.go') } ? 'true' : 'false'
                    env.RUN_NODE = changes.any { it.endsWith('.js') || it.endsWith('.ts') || it.startsWith('package') } ? 'true' : 'false'
                }
            }
        }

        stage('Go Test') {
            when {
                expression { env.RUN_GO == 'true' }
            }
            steps {
                sh '''
                    go mod tidy
                    go build ./...
                    go test ./... -v -coverprofile=coverage.out
                '''
            }
        }

        stage('Node Test') {
            when {
                expression { env.RUN_NODE == 'true' }
            }
            steps {
                sh '''
                    rm -rf node_modules package-lock.json
                    npm ci
                    npm run lint || true
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
            echo '❌ Build failed.'
        }
        success {
            echo '✅ Build succeeded!'
        }
    }
}

