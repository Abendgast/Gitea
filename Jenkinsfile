pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        REPO_URL = 'https://github.com/Abendgast/Gitea.git'
        MAIN_BRANCH = 'main'
        DEV_BRANCH = 'dev'
        NODE_VERSION = '20'
    }

    tools {
        nodejs "${NODE_VERSION}"
        go 'go-1.21'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    if (env.BRANCH_NAME != 'dev') {
                        currentBuild.result = 'ABORTED'
                        error("Pipeline запускається тільки для dev гілки")
                    }
                }
            }
        }

        stage('Setup Environment') {
            steps {
                sh '''
                    echo "Node.js version:"
                    node --version
                    echo "NPM version:"
                    npm --version
                    echo "Go version:"
                    go version

                    # Очищаємо npm cache
                    npm cache clean --force
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    # Очищення
                    make clean-all || make clean

                    # Встановлення залежностей Go
                    go mod download
                    go mod tidy

                    # Встановлення npm залежностей з правильними флагами
                    npm install --legacy-peer-deps --no-audit --no-fund

                    # Генерація статичних ресурсів
                    make generate

                    # Збірка бінарного файлу
                    make build
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    # Запуск базових тестів
                    make test-backend

                    # Тест frontend (якщо є)
                    if [ -f "package.json" ] && grep -q "test" package.json; then
                        npm test || echo "Frontend tests failed but continuing..."
                    fi
                '''
            }
        }

        stage('Merge to Main') {
            when {
                branch 'dev'
            }
            steps {
                script {
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@yourcompany.com"

                        git fetch origin
                        git checkout main
                        git pull origin main
                        git merge origin/dev --no-ff -m "Auto merge from dev branch via Jenkins CI"
                    '''

                    withCredentials([usernamePassword(credentialsId: 'github-credentials',
                                                    usernameVariable: 'GIT_USERNAME',
                                                    passwordVariable: 'GIT_PASSWORD')]) {
                        sh '''
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/Abendgast/Gitea.git
                            git push origin main
                        '''
                    }
                }
            }
        }
    }

    post {
        success {
            echo 'Pipeline виконано успішно! Зміни змержено в main гілку.'
        }
        failure {
            echo 'Pipeline завершився з помилкою. Зміни не були змержено в main.'
        }
        always {
            cleanWs()
        }
    }
}
