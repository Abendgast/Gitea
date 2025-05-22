pipeline {
    agent any

    environment {
        GO_VERSION = '1.21'
        GOPROXY = 'https://proxy.golang.org,direct'
        GOSUMDB = 'sum.golang.org'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git clean -fdx'
            }
        }

        stage('Setup') {
            steps {
                script {
                    // Перевіряємо наявність Makefile та основних файлів
                    sh 'ls -la'
                    sh 'test -f Makefile || (echo "Makefile not found" && exit 1)'
                }
            }
        }

        stage('Build & Test') {
            parallel {
                stage('Build') {
                    steps {
                        script {
                            docker.image("golang:${GO_VERSION}").inside('-v /var/run/docker.sock:/var/run/docker.sock') {
                                sh '''
                                    echo "Building Gitea..."
                                    make clean
                                    make build
                                '''
                            }
                        }
                    }
                }

                stage('Test') {
                    steps {
                        script {
                            docker.image("golang:${GO_VERSION}").inside('-v /var/run/docker.sock:/var/run/docker.sock') {
                                sh '''
                                    echo "Running tests..."
                                    make test-backend
                                '''
                            }
                        }
                    }
                    post {
                        always {
                            // Збираємо тестові звіти якщо є
                            publishTestResults testResultsPattern: '**/test-results.xml', allowEmptyResults: true
                        }
                    }
                }

                stage('Lint') {
                    steps {
                        script {
                            docker.image("golang:${GO_VERSION}").inside() {
                                sh '''
                                    echo "Running linter..."
                                    make lint-backend || echo "Lint warnings found but continuing..."
                                '''
                            }
                        }
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
