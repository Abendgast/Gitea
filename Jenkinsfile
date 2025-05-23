pipeline {
    agent any

    triggers {
        githubPush()
    }

    environment {
        REPO_URL = 'https://github.com/your-username/your-repo.git'
        MAIN_BRANCH = 'main'
        DEV_BRANCH = 'dev'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    // Перевіряємо, що це коміт в dev гілку
                    if (env.BRANCH_NAME != 'dev') {
                        currentBuild.result = 'ABORTED'
                        error("Pipeline запускається тільки для dev гілки")
                    }
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    // Встановлюємо та використовуємо правильну версію Node.js через nvm
                    sh '''
                        # Встановлюємо nvm якщо його немає
                        if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
                            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
                        fi

                        # Активуємо nvm та встановлюємо Node.js 18
                        . $HOME/.nvm/nvm.sh
                        nvm install 18
                        nvm use 18

                        # Перевіряємо версії
                        node --version
                        npm --version

                        # Збірка Gitea
                        make clean
                        make deps
                        make build
                    '''
                }
            }
        }

        stage('Test') {
            steps {
                script {
                    // Запускаємо тести Gitea з правильною версією Node.js
                    sh '''
                        . $HOME/.nvm/nvm.sh
                        nvm use 18
                        make test
                        make test-sqlite
                    '''
                }
            }
        }

        stage('Merge to Main') {
            when {
                branch 'dev'
            }
            steps {
                script {
                    // Налаштовуємо git
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@yourcompany.com"
                    '''

                    // Отримуємо останні зміни з remote
                    sh 'git fetch origin'

                    // Переключаємося на main гілку
                    sh 'git checkout main'
                    sh 'git pull origin main'

                    // Мержимо dev в main
                    sh 'git merge origin/dev --no-ff -m "Auto merge from dev branch via Jenkins CI"'

                    // Пушимо зміни в main
                    withCredentials([usernamePassword(credentialsId: 'github-credentials',
                                                    usernameVariable: 'GIT_USERNAME',
                                                    passwordVariable: 'GIT_PASSWORD')]) {
                        sh '''
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/your-username/your-repo.git
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
            // Очищуємо workspace
            cleanWs()
        }
    }
}
