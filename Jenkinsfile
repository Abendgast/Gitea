pipeline {
    agent any

    // Тригери - запуск тільки при пуші в dev гілку
    triggers {
        githubPush()
    }

    // Змінні середовища
    environment {
        REPO_URL = 'https://github.com/Abendgast/Gitea.git'
        MAIN_BRANCH = 'main'
        DEV_BRANCH = 'dev'
        NODE_VERSION = '20'
        // Налаштування для Node.js щоб уникнути проблем з пам'яттю
        NODE_OPTIONS = '--max-old-space-size=4096'
    }

    // Інструменти які нам потрібні
    tools {
        nodejs "${NODE_VERSION}"
        go 'go-1.21'
    }

    stages {
        // Перевірка гілки та checkout коду
        stage('Checkout and Validate') {
            steps {
                // Checkout коду з репозиторію
                checkout scm

                script {
                    // Перевіряємо що ми працюємо з dev гілкою
                    if (env.BRANCH_NAME != 'dev') {
                        currentBuild.result = 'ABORTED'
                        error("Pipeline запускається тільки для dev гілки. Поточна гілка: ${env.BRANCH_NAME}")
                    }

                    echo "✓ Працюємо з dev гілкою"
                    echo "✓ Код успішно завантажено"
                }
            }
        }

        // Налаштування середовища та перевірка інструментів
        stage('Environment Setup') {
            steps {
                sh '''
                    echo "=== Перевірка версій інструментів ==="
                    echo "Node.js версія:"
                    node --version
                    echo "NPM версія:"
                    npm --version
                    echo "Go версія:"
                    go version

                    echo "=== Очищення кешу ==="
                    npm cache clean --force || echo "Не вдалося очистити npm cache, продовжуємо..."
                '''
            }
        }

        // Встановлення залежностей
        stage('Install Dependencies') {
            parallel {
                // Go залежності
                stage('Go Dependencies') {
                    steps {
                        sh '''
                            echo "=== Встановлення Go залежностей ==="
                            go mod download
                            go mod tidy
                            echo "✓ Go залежності встановлено"
                        '''
                    }
                }

                // Node.js залежності (якщо є)
                stage('Node.js Dependencies') {
                    when {
                        // Встановлюємо тільки якщо є package.json
                        expression { fileExists('package.json') }
                    }
                    steps {
                        sh '''
                            echo "=== Встановлення Node.js залежностей ==="
                            npm install --legacy-peer-deps --no-audit --no-fund
                            echo "✓ Node.js залежності встановлено"
                        '''
                    }
                }
            }
        }

        // Основна стадія тестування
        stage('Run Tests') {
            parallel {
                // Backend тести (Go)
                stage('Backend Tests') {
                    steps {
                        sh '''
                            echo "=== Запуск backend тестів ==="

                            # Перевіряємо чи є Makefile та make test-backend
                            if [ -f "Makefile" ] && grep -q "test-backend" Makefile; then
                                make test-backend
                            else
                                # Якщо немає Makefile, запускаємо стандартні Go тести
                                go test ./... -v
                            fi

                            echo "✓ Backend тести пройдено успішно"
                        '''
                    }
                }

                // Frontend тести (якщо є)
                stage('Frontend Tests') {
                    when {
                        allOf {
                            expression { fileExists('package.json') }
                            expression {
                                // Перевіряємо чи є test скрипт в package.json
                                sh(script: 'grep -q "\\"test\\"" package.json', returnStatus: true) == 0
                            }
                        }
                    }
                    steps {
                        sh '''
                            echo "=== Запуск frontend тестів ==="
                            npm test
                            echo "✓ Frontend тести пройдено успішно"
                        '''
                    }
                }

                // Статичний аналіз коду (додатково)
                stage('Code Quality Check') {
                    steps {
                        sh '''
                            echo "=== Перевірка якості коду ==="

                            # Go форматування
                            echo "Перевірка Go форматування..."
                            if ! gofmt -l . | grep -v vendor | grep .; then
                                echo "✓ Go код правильно відформатовано"
                            else
                                echo "❌ Знайдено проблеми з форматуванням Go коду"
                                exit 1
                            fi

                            # Go vet для пошуку потенційних проблем
                            echo "Запуск go vet..."
                            go vet ./...
                            echo "✓ Go vet перевірку пройдено"
                        '''
                    }
                }
            }
        }

        // Збірка проекту для фінальної перевірки
        stage('Build Verification') {
            steps {
                sh '''
                    echo "=== Перевірочна збірка ==="

                    # Очищення попередніх збірок
                    if [ -f "Makefile" ]; then
                        make clean-all || make clean || echo "Не вдалося очистити, продовжуємо..."
                    fi

                    # Збірка проекту
                    if [ -f "Makefile" ] && grep -q "build" Makefile; then
                        # Використовуємо Makefile якщо він є
                        TAGS="bindata" make build
                    else
                        # Інакше стандартна Go збірка
                        go build ./...
                    fi

                    echo "✓ Проект успішно збирається"
                '''
            }
        }

        // Мердж в main гілку тільки якщо всі тести пройшли
        stage('Merge to Main') {
            when {
                // Виконуємо тільки для dev гілки і тільки якщо всі попередні стадії успішні
                allOf {
                    branch 'dev'
                    expression { currentBuild.currentResult == 'SUCCESS' }
                }
            }
            steps {
                script {
                    echo "=== Початок мерджу в main гілку ==="

                    // Налаштування git користувача
                    sh '''
                        git config user.name "Jenkins CI"
                        git config user.email "jenkins@yourcompany.com"
                        git config --global user.name "Jenkins CI"
                        git config --global user.email "jenkins@yourcompany.com"
                    '''

                    // Мердж з авторизацією
                    withCredentials([usernamePassword(
                        credentialsId: 'github-credentials',
                        usernameVariable: 'GIT_USERNAME',
                        passwordVariable: 'GIT_PASSWORD'
                    )]) {
                        sh '''
                            echo "Налаштування remote URL з авторизацією..."
                            git remote set-url origin https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/Abendgast/Gitea.git

                            echo "Отримання останніх змін..."
                            git fetch origin

                            echo "Перехід на main гілку..."
                            git checkout main
                            git pull origin main

                            echo "Мердж dev в main..."
                            git merge origin/dev --no-ff -m "🚀 Auto merge from dev branch via Jenkins CI

                            ✅ All tests passed
                            📝 Commit: $(git log --oneline -1 origin/dev)
                            🕐 Merged at: $(date)
                            "

                            echo "Відправка змін..."
                            git push origin main

                            echo "✓ Мердж успішно завершено!"
                        '''
                    }
                }
            }
        }
    }

    // Пост-дії залежно від результату
    post {
        success {
            script {
                if (env.BRANCH_NAME == 'dev') {
                    echo '''
                    🎉 УСПІХ!
                    ✅ Всі тести пройдено
                    🔄 Зміни успішно змержено в main гілку
                    🚀 Деплой готовий до запуску
                    '''
                } else {
                    echo '✅ Pipeline виконано успішно!'
                }
            }
        }

        failure {
            echo '''
            ❌ ПОМИЛКА!
            🚫 Pipeline завершився з помилкою
            🔒 Зміни НЕ були змержено в main
            🔍 Перевірте логи для деталей
            '''
        }

        unstable {
            echo '''
            ⚠️  НЕСТАБІЛЬНИЙ СТАН!
            🔄 Деякі тести пройшли з попередженнями
            🔒 Мердж заблоковано до виправлення
            '''
        }

        always {
            // Завжди очищуємо робочий простір
            echo "🧹 Очищення робочого простору..."
            cleanWs()
        }
    }
}
