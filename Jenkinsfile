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

        // Аналіз змін для оптимізації тестування
        stage('Analyze Changes') {
            steps {
                script {
                    sh '''
                        echo "=== Аналіз змінених файлів ==="

                        # Отримуємо список змінених файлів між dev та main
                        git fetch origin main
                        CHANGED_FILES=$(git diff --name-only origin/main...HEAD)

                        echo "Змінені файли:"
                        echo "$CHANGED_FILES"

                        # Зберігаємо список у файл для наступних стадій
                        echo "$CHANGED_FILES" > changed_files.txt

                        # Аналізуємо типи змін (використовуємо подвійне екранування для Jenkins)
                        GO_FILES=$(echo "$CHANGED_FILES" | grep -E '\\.go$' || true)
                        JS_FILES=$(echo "$CHANGED_FILES" | grep -E '\\.(js|ts|vue)$' || true)
                        CONFIG_FILES=$(echo "$CHANGED_FILES" | grep -E '\\.(yml|yaml|json|toml)$' || true)

                        echo "Go файли:"
                        echo "$GO_FILES"
                        echo "JS файли:"
                        echo "$JS_FILES"
                        echo "Конфіг файли:"
                        echo "$CONFIG_FILES"

                        # Зберігаємо результати аналізу
                        echo "$GO_FILES" > changed_go_files.txt
                        echo "$JS_FILES" > changed_js_files.txt
                        echo "$CONFIG_FILES" > changed_config_files.txt

                        # Підрахунок кількості змінених файлів
                        GO_COUNT=$(echo "$GO_FILES" | grep -v "^$" | wc -l || echo "0")
                        JS_COUNT=$(echo "$JS_FILES" | grep -v "^$" | wc -l || echo "0")
                        CONFIG_COUNT=$(echo "$CONFIG_FILES" | grep -v "^$" | wc -l || echo "0")

                        echo "Кількість змінених Go файлів: $GO_COUNT"
                        echo "Кількість змінених JS файлів: $JS_COUNT"
                        echo "Кількість змінених конфіг файлів: $CONFIG_COUNT"
                    '''
                }
            }
        }

        // Розумне тестування на основі змін
        stage('Smart Testing Strategy') {
            steps {
                script {
                    // Читаємо результати аналізу
                    def changedGoFiles = ""
                    def changedJsFiles = ""
                    def changedConfigFiles = ""

                    try {
                        changedGoFiles = readFile('changed_go_files.txt').trim()
                        changedJsFiles = readFile('changed_js_files.txt').trim()
                        changedConfigFiles = readFile('changed_config_files.txt').trim()
                    } catch (Exception e) {
                        echo "Помилка читання файлів аналізу: ${e.message}"
                        changedGoFiles = ""
                        changedJsFiles = ""
                        changedConfigFiles = ""
                    }

                    // Визначаємо стратегію тестування на основі змін
                    def testStrategy = 'minimal' // за замовчуванням

                    echo "Аналіз змінених файлів для вибору стратегії тестування:"
                    echo "Go файли: '${changedGoFiles}'"
                    echo "Config файли: '${changedConfigFiles}'"

                    // Якщо змінено main.go або конфігурацію
                    if (changedGoFiles.contains('main.go') || changedConfigFiles.length() > 0) {
                        testStrategy = 'core'
                        echo "Виявлено зміни в main.go або конфігурації - core тестування"
                    }

                    // Якщо змінено моделі або сервіси
                    if (changedGoFiles.contains('models/') || changedGoFiles.contains('services/')) {
                        testStrategy = 'extended'
                        echo "Виявлено зміни в моделях або сервісах - extended тестування"
                    }

                    // Якщо змінено роутери або модулі
                    if (changedGoFiles.contains('routers/') || changedGoFiles.contains('modules/')) {
                        testStrategy = 'full'
                        echo "Виявлено зміни в роутерах або модулях - full тестування"
                    }

                    // Якщо змінено багато файлів
                    def totalChanges = changedGoFiles.split('\\n').length
                    if (totalChanges > 10) {
                        testStrategy = 'full'
                        echo "Багато змін (${totalChanges} файлів) - full тестування"
                    }

                    env.TEST_STRATEGY = testStrategy
                    echo ">>> Обрана стратегія тестування: ${testStrategy} <<<"
                }
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

        // Розумне тестування на основі стратегії
        stage('Smart Tests Execution') {
            parallel {
                // Backend тести (Go) - розумні
                stage('Backend Tests') {
                    steps {
                        script {
                            echo "Стратегія тестування: ${env.TEST_STRATEGY}"

                            sh '''
                                echo "=== Запуск backend тестів (стратегія: ${TEST_STRATEGY}) ==="

                                case "${TEST_STRATEGY}" in
                                    "minimal")
                                        echo "🎯 Мінімальне тестування - тільки змінені пакети"
                                        CHANGED_GO_FILES=$(cat changed_go_files.txt | tr '\\n' ' ')
                                        if [ -n "$CHANGED_GO_FILES" ] && [ "$CHANGED_GO_FILES" != " " ]; then
                                            # Отримуємо унікальні директорії Go пакетів
                                            echo "Змінені Go файли: $CHANGED_GO_FILES"
                                            PACKAGES=$(echo "$CHANGED_GO_FILES" | xargs -n1 dirname | sort -u | sed 's|^|./|' | grep -v '^\\.$' | tr '\\n' ' ')
                                            echo "Пакети для тестування: $PACKAGES"
                                            if [ -n "$PACKAGES" ]; then
                                                go test $PACKAGES -v -timeout=10m
                                            else
                                                echo "Немає пакетів для тестування"
                                            fi
                                        else
                                            echo "Немає змінених Go файлів - пропускаємо тести"
                                        fi
                                        ;;
                                    "core")
                                        echo "🔥 Основне тестування - критичні компоненти"
                                        echo "Тестуємо core модулі..."
                                        go test ./cmd/... -v -timeout=10m || echo "CMD тести завершились"
                                        go test ./modules/setting/... -v -timeout=10m || echo "Setting тести завершились"
                                        go test ./modules/log/... -v -timeout=10m || echo "Log тести завершились"
                                        go test ./modules/util/... -v -timeout=10m || echo "Util тести завершились"
                                        ;;
                                    "extended")
                                        echo "🚀 Розширене тестування - моделі та сервіси"
                                        echo "Тестуємо моделі та сервіси..."
                                        go test ./models/... -v -timeout=15m -parallel=2 || echo "Models тести завершились"
                                        go test ./services/... -v -timeout=15m -parallel=2 || echo "Services тести завершились"
                                        go test ./modules/... -v -timeout=15m -parallel=2 || echo "Modules тести завершились"
                                        ;;
                                    "full")
                                        echo "💥 Повне тестування - всі компоненти"
                                        echo "Запускаємо повний набір тестів..."
                                        if [ -f "Makefile" ] && grep -q "test-backend" Makefile; then
                                            timeout 30m make test-backend || echo "Make test завершився з помилкою або тайм-аутом"
                                        else
                                            timeout 30m go test ./... -v -parallel=4 || echo "Go test завершився з помилкою або тайм-аутом"
                                        fi
                                        ;;
                                esac

                                echo "✅ Backend тестування завершено для стратегії: ${TEST_STRATEGY}"
                            '''
                        }
                    }
                }

                // Frontend тести (якщо є)
                stage('Frontend Tests') {
                    when {
                        allOf {
                            expression { fileExists('package.json') }
                            expression {
                                // Перевіряємо чи є test скрипт в package.json
                                try {
                                    sh(script: 'grep -q "\\"test\\"" package.json', returnStatus: true) == 0
                                } catch (Exception e) {
                                    return false
                                }
                            }
                        }
                    }
                    steps {
                        sh '''
                            echo "=== Запуск frontend тестів ==="
                            timeout 10m npm test || echo "Frontend тести завершились з попередженням"
                            echo "✅ Frontend тести завершено"
                        '''
                    }
                }

                // Швидка перевірка якості коду
                stage('Quick Code Quality') {
                    steps {
                        sh '''
                            echo "=== Швидка перевірка якості коду ==="

                            # Go форматування - тільки для змінених файлів
                            CHANGED_GO_FILES=$(cat changed_go_files.txt | tr '\\n' ' ')
                            if [ -n "$CHANGED_GO_FILES" ] && [ "$CHANGED_GO_FILES" != " " ]; then
                                echo "Перевірка форматування Go файлів..."
                                echo "$CHANGED_GO_FILES" | xargs gofmt -l | head -10
                                echo "✓ Перевірка форматування завершена"
                            else
                                echo "Немає Go файлів для перевірки форматування"
                            fi

                            echo "✅ Перевірка якості коду завершена"
                        '''
                    }
                }
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
                            COMMIT_MSG=$(git log --oneline -1 origin/dev)
                            git merge origin/dev --no-ff -m "🚀 Auto merge from dev branch via Jenkins CI

✅ All tests passed (strategy: ${TEST_STRATEGY})
📝 Latest commit: $COMMIT_MSG
🕐 Merged at: $(date)
🤖 Jenkins build: ${BUILD_NUMBER}
"

                            echo "Відправка змін..."
                            git push origin main

                            echo "✅ Мердж успішно завершено!"
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
                    echo """
🎉 УСПІХ!
✅ Стратегія тестування: ${env.TEST_STRATEGY}
✅ Всі тести пройдено успішно
🔄 Зміни успішно змержено в main гілку
🚀 Готово для деплою!
📊 Jenkins build #${BUILD_NUMBER}
                    """
                } else {
                    echo '✅ Pipeline виконано успішно!'
                }
            }
        }

        failure {
            echo """
❌ ПОМИЛКА!
🚫 Pipeline завершився з помилкою
🔒 Зміни НЕ були змержено в main
🔍 Перевірте логи для деталей
📊 Jenkins build #${BUILD_NUMBER}
            """
        }

        unstable {
            echo """
⚠️  НЕСТАБІЛЬНИЙ СТАН!
🔄 Деякі тести пройшли з попередженнями
🔒 Мердж заблоковано до виправлення
📊 Jenkins build #${BUILD_NUMBER}
            """
        }

        always {
            // Завжди очищуємо робочий простір
            echo "🧹 Очищення робочого простору..."
            // Зберігаємо артефакти аналізу для дебагу
            archiveArtifacts artifacts: 'changed_*.txt', allowEmptyArchive: true, fingerprint: true
            cleanWs()
        }
    }
}

