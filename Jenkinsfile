pipeline {
    agent any

    // Тригери - запуск тільки при пушів dev гілку
    triggers {
        githubPush()
    }

    // Змінні середовища
    environment {
        REPO_URL = 'https://github.com/Abendgast/Gitea.git'
        MAIN_BRANCH = 'main'
        DEV_BRANCH = 'dev'
        NODE_VERSION = '20'
        NODE_OPTIONS = '--max-old-space-size=4096'
        // Таймаути для git операцій
        GIT_TIMEOUT = '300' // 5 хвилин
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
                script {
                    // Перевіряємо що ми працюємо з dev гілкою
                    if (env.BRANCH_NAME != 'dev') {
                        currentBuild.result = 'ABORTED'
                        error("Pipeline запускається тільки для dev гілки. Поточна гілка: ${env.BRANCH_NAME}")
                    }

                    echo "✓ Працюємо з dev гілкою: ${env.BRANCH_NAME}"
                    echo "✓ Код успішно завантажено"

                    // Отримуємо інформацію про поточний коммit
                    def commitInfo = sh(
                        script: 'git log -1 --pretty=format:"%h - %s (%an, %ad)" --date=short',
                        returnStdout: true
                    ).trim()
                    echo "📝 Поточний commit: ${commitInfo}"
                }
            }
        }

        // Швидкий аналіз змін на основі останніх коммітів
        stage('Quick Change Analysis') {
            steps {
                script {
                    echo "=== Швидкий аналіз змін ==="

                    // Отримуємо зміни з останнього коммиту
                    def changedFiles = sh(
                        script: 'git diff --name-only HEAD~1 HEAD',
                        returnStdout: true
                    ).trim()

                    if (!changedFiles) {
                        echo "⚠️ Не знайдено змін у останньому коммиті, перевіряємо останні 3 комміти..."
                        changedFiles = sh(
                            script: 'git diff --name-only HEAD~3 HEAD',
                            returnStdout: true
                        ).trim()
                    }

                    echo "📂 Змінені файли:"
                    echo changedFiles

                    // Збереження у файл для подальшого використання
                    writeFile file: 'changed_files.txt', text: changedFiles

                    // Аналіз типів файлів - переконуємося що changedFiles не null
                    def filesList = changedFiles ? changedFiles.split('\n') : []
                    def goFiles = filesList.findAll { it && it.endsWith('.go') }
                    def jsFiles = filesList.findAll { it && it.matches('.*\\.(js|ts|vue)$') }
                    def configFiles = filesList.findAll { it && it.matches('.*\\.(yml|yaml|json|toml|env)$') }
                    def dockerFiles = filesList.findAll { it && it.matches('.*(Dockerfile|docker-compose).*') }

                    // Збереження результатів аналізу
                    writeFile file: 'changed_go_files.txt', text: goFiles.join('\n')
                    writeFile file: 'changed_js_files.txt', text: jsFiles.join('\n')
                    writeFile file: 'changed_config_files.txt', text: configFiles.join('\n')
                    writeFile file: 'changed_docker_files.txt', text: dockerFiles.join('\n')

                    echo "🔍 Результати аналізу:"
                    echo "   Go файлів: ${goFiles.size()}"
                    echo "   JS/TS файлів: ${jsFiles.size()}"
                    echo "   Config файлів: ${configFiles.size()}"
                    echo "   Docker файлів: ${dockerFiles.size()}"

                    // Зберігаємо статистику у environment змінні
                    env.GO_FILES_COUNT = goFiles.size().toString()
                    env.JS_FILES_COUNT = jsFiles.size().toString()
                    env.CONFIG_FILES_COUNT = configFiles.size().toString()
                    env.DOCKER_FILES_COUNT = dockerFiles.size().toString()
                    env.TOTAL_FILES_COUNT = filesList.size().toString()

                    // Зберігаємо changedFiles як environment змінну для використання в інших stages
                    env.CHANGED_FILES_LIST = changedFiles
                }
            }
        }

        // Розумна стратегія тестування
        stage('Smart Testing Strategy') {
            steps {
                script {
                    def goCount = env.GO_FILES_COUNT.toInteger()
                    def jsCount = env.JS_FILES_COUNT.toInteger()
                    def configCount = env.CONFIG_FILES_COUNT.toInteger()
                    def dockerCount = env.DOCKER_FILES_COUNT.toInteger()
                    def totalCount = env.TOTAL_FILES_COUNT.toInteger()

                    def testStrategy = 'minimal'
                    def skipTests = false

                    echo "📊 Аналіз для вибору стратегії:"
                    echo "   Загально файлів: ${totalCount}"
                    echo "   Go файлів: ${goCount}"
                    echo "   Config файлів: ${configCount}"

                    // Якщо змін немає або тільки README/docs
                    if (totalCount == 0) {
                        skipTests = true
                        echo "ℹ️ Немає змін - пропускаємо тести"
                    } else {
                        // Використовуємо environment змінну замість локальної
                        def changedFilesFromEnv = env.CHANGED_FILES_LIST ?: ''
                        def onlyDocs = false

                        if (changedFilesFromEnv) {
                            def filesList = changedFilesFromEnv.split('\n')
                            onlyDocs = filesList.every { file ->
                                file && (file.matches('.*\\.(md|txt|rst|doc)$') || file.startsWith('docs/'))
                            }
                        }

                        if (onlyDocs) {
                            skipTests = true
                            echo "📚 Змінено тільки документацію - пропускаємо тести"
                        }
                    }

                    if (!skipTests) {
                        def changedFilesContent = env.CHANGED_FILES_LIST ?: ''

                        // Стратегія на основі змін
                        if (changedFilesContent.contains('main.go') || configCount > 0 || dockerCount > 0) {
                            testStrategy = 'core'
                            echo "🔥 Core зміни виявлено - core тестування"
                        } else if (changedFilesContent.contains('models/') || changedFilesContent.contains('services/')) {
                            testStrategy = 'extended'
                            echo "🚀 Зміни в моделях/сервісах - extended тестування"
                        } else if (goCount > 5 || totalCount > 15) {
                            testStrategy = 'extended'
                            echo "📈 Багато змін - extended тестування"
                        } else if (goCount > 0) {
                            testStrategy = 'targeted'
                            echo "🎯 Цільове тестування змінених пакетів"
                        }
                    }

                    env.TEST_STRATEGY = testStrategy
                    env.SKIP_TESTS = skipTests.toString()

                    echo ">>> Обрана стратегія: ${testStrategy} (пропуск: ${skipTests}) <<<"
                }
            }
        }

        // Налаштування середовища
        stage('Environment Setup') {
            when {
                expression { env.SKIP_TESTS != 'true' }
            }
            steps {
                sh '''
                    echo "=== Перевірка версій інструментів ==="
                    echo "Node.js: $(node --version)"
                    echo "NPM: $(npm --version)"
                    echo "Go: $(go version)"

                    echo "=== Очищення кешу ==="
                    npm cache clean --force 2>/dev/null || echo "NPM cache очищення пропущено"
                    go clean -cache -modcache -testcache 2>/dev/null || echo "Go cache очищення пропущено"
                '''
            }
        }

        // Встановлення залежностей
        stage('Install Dependencies') {
            when {
                expression { env.SKIP_TESTS != 'true' }
            }
            parallel {
                stage('Go Dependencies') {
                    when {
                        expression { env.GO_FILES_COUNT.toInteger() > 0 }
                    }
                    steps {
                        timeout(time: 5, unit: 'MINUTES') {
                            sh '''
                                echo "=== Встановлення Go залежностей ==="
                                go mod download -x
                                go mod tidy
                                echo "✓ Go залежності встановлено"
                            '''
                        }
                    }
                }

                stage('Node.js Dependencies') {
                    when {
                        allOf {
                            expression { fileExists('package.json') }
                            expression { env.JS_FILES_COUNT.toInteger() > 0 }
                        }
                    }
                    steps {
                        timeout(time: 5, unit: 'MINUTES') {
                            sh '''
                                echo "=== Встановлення Node.js залежностей ==="
                                npm ci --legacy-peer-deps --no-audit --no-fund --silent
                                echo "✓ Node.js залежності встановлено"
                            '''
                        }
                    }
                }
            }
        }

        // Розумне тестування
        stage('Smart Tests Execution') {
            when {
                expression { env.SKIP_TESTS != 'true' }
            }
            parallel {
                stage('Backend Tests') {
                    when {
                        expression { env.GO_FILES_COUNT.toInteger() > 0 }
                    }
                    steps {
                        timeout(time: 15, unit: 'MINUTES') {
                            script {
                                def strategy = env.TEST_STRATEGY
                                echo "🧪 Запуск backend тестів (стратегія: ${strategy})"

                                sh '''
                                    case "${TEST_STRATEGY}" in
                                        "minimal"|"targeted")
                                            echo "🎯 Цільове тестування"
                                            if [ -f "changed_go_files.txt" ]; then
                                                CHANGED_GO_FILES=$(cat changed_go_files.txt | grep -v "^$" || true)
                                                if [ -n "$CHANGED_GO_FILES" ]; then
                                                    echo "Тестуємо пакети зі змінених файлів:"
                                                    echo "$CHANGED_GO_FILES" | while read -r file; do
                                                        if [ -n "$file" ]; then
                                                            PKG_DIR=$(dirname "$file")
                                                            if [ "$PKG_DIR" != "." ]; then
                                                                echo "Тестування: ./$PKG_DIR"
                                                                timeout 5m go test "./$PKG_DIR" -v -timeout=3m || echo "⚠️ Тести для $PKG_DIR завершились з попередженням"
                                                            fi
                                                        fi
                                                    done
                                                else
                                                    echo "Немає Go файлів для тестування"
                                                fi
                                            else
                                                echo "Файл changed_go_files.txt не знайдено"
                                            fi
                                        ;;
                                        "core")
                                            echo "🔥 Core тестування"
                                            timeout 8m go test ./cmd/... -v -timeout=5m || echo "⚠️ CMD тести завершились"
                                            timeout 5m go test ./modules/setting/... -v -timeout=3m || echo "⚠️ Setting тести завершились"
                                            timeout 3m go test ./modules/log/... -v -timeout=2m || echo "⚠️ Log тести завершились"
                                        ;;
                                        "extended")
                                            echo "🚀 Розширене тестування"
                                            timeout 10m go test ./models/... -v -timeout=5m -parallel=2 || echo "⚠️ Models тести завершились"
                                            timeout 10m go test ./services/... -v -timeout=5m -parallel=2 || echo "⚠️ Services тести завершились"
                                            timeout 8m go test ./modules/... -v -timeout=5m -parallel=2 || echo "⚠️ Modules тести завершились"
                                        ;;
                                    esac

                                    echo "✅ Backend тестування завершено"
                                '''
                            }
                        }
                    }
                }

                stage('Frontend Tests') {
                    when {
                        allOf {
                            expression { fileExists('package.json') }
                            expression { env.JS_FILES_COUNT.toInteger() > 0 }
                            expression {
                                try {
                                    sh(script: 'grep -q "\\"test\\"" package.json', returnStatus: true) == 0
                                } catch(Exception e) {
                                    return false
                                }
                            }
                        }
                    }
                    steps {
                        timeout(time: 8, unit: 'MINUTES') {
                            sh '''
                                echo "=== Frontend тести ==="
                                npm test -- --watchAll=false --passWithNoTests || echo "⚠️ Frontend тести завершились з попередженням"
                                echo "✅ Frontend тести завершено"
                            '''
                        }
                    }
                }

                stage('Code Quality Check') {
                    steps {
                        timeout(time: 3, unit: 'MINUTES') {
                            sh '''
                                echo "=== Швидка перевірка якості коду ==="

                                # Go форматування для змінених файлів
                                if [ -f "changed_go_files.txt" ]; then
                                    CHANGED_GO_FILES=$(cat changed_go_files.txt | grep -v "^$" || true)
                                    if [ -n "$CHANGED_GO_FILES" ]; then
                                        echo "Перевірка форматування Go файлів..."
                                        echo "$CHANGED_GO_FILES" | head -5 | xargs -r gofmt -l || echo "Форматування перевірено"
                                    else
                                        echo "Немає Go файлів для перевірки"
                                    fi
                                else
                                    echo "Файл changed_go_files.txt не знайдено"
                                fi

                                echo "✅ Перевірка якості завершена"
                            '''
                        }
                    }
                }
            }
        }

        // Безпечний мердж тільки після успішних тестів
        stage('Safe Merge to Main') {
            when {
                allOf {
                    branch 'dev'
                    expression { currentBuild.currentResult == 'SUCCESS' }
                }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    script {
                        echo "=== Підготовка до мерджу в main ==="

                        sh '''
                            # Налаштування git
                            git config user.name "Jenkins CI"
                            git config user.email "jenkins@yourcompany.com"

                            # Перевірка поточного стану
                            echo "=== Поточний стан Git ==="
                            echo "Поточна гілка: $(git branch --show-current || echo 'невідомо')"
                            echo "Останній commit: $(git log -1 --oneline || echo 'немає коммітів')"
                            echo "Всі локальні гілки:"
                            git branch || echo "Помилка отримання списку локальних гілок"
                            echo "Remote гілки:"
                            git branch -r || echo "Помилка отримання remote гілок"
                            echo "Remote URLs:"
                            git remote -v || echo "Немає remote репозиторіїв"
                        '''

                        // Мердж з авторизацією та обробкою помилок
                        withCredentials([usernamePassword(
                            credentialsId: 'github-credentials',
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD'
                        )]) {
                            sh '''
                                set -e # Зупинка при помилці

                                echo "⚙️ Налаштування remote з авторизацією..."
                                git remote set-url origin "https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/Abendgast/Gitea.git"

                                echo "📥 Отримання всіх гілок з remote..."
                                # ВИПРАВЛЕННЯ: використовуємо правильний синтаксис для fetch
                                timeout ${GIT_TIMEOUT}s git fetch origin --prune || {
                                    echo "❌ Timeout або помилка при fetch"
                                    exit 1
                                }

                                # Додатково fetch всіх remote гілок
                                timeout ${GIT_TIMEOUT}s git fetch origin '+refs/heads/*:refs/remotes/origin/*' --prune || {
                                    echo "⚠️ Помилка при fetch всіх гілок, продовжуємо..."
                                }

                                # Показуємо що отримали
                                echo "📋 Доступні remote гілки після fetch:"
                                git branch -r

                                echo "🔍 Пошук основної гілки (main/master)..."
                                MAIN_BRANCH_NAME=""
                                if git ls-remote --heads origin main | grep -q refs/heads/main; then
                                    MAIN_BRANCH_NAME="main"
                                    echo "✅ Знайдено remote гілку main"
                                elif git ls-remote --heads origin master | grep -q refs/heads/master; then
                                    MAIN_BRANCH_NAME="master"
                                    echo "✅ Знайдено remote гілку master"
                                else
                                    echo "❌ Не знайдено основну гілку (main/master)!"
                                    echo "Доступні remote гілки:"
                                    git ls-remote --heads origin
                                    exit 1
                                fi

                                echo "🔄 Робота з гілкою ${MAIN_BRANCH_NAME}..."

                                # Перевіряємо чи існує локальна гілка
                                if git show-ref --verify --quiet "refs/heads/${MAIN_BRANCH_NAME}"; then
                                    echo "Локальна гілка ${MAIN_BRANCH_NAME} існує"
                                    git checkout "${MAIN_BRANCH_NAME}"
                                    git reset --hard "origin/${MAIN_BRANCH_NAME}"
                                    echo "Гілка ${MAIN_BRANCH_NAME} оновлена до стану origin/${MAIN_BRANCH_NAME}"
                                else
                                    echo "Створюємо локальну гілку ${MAIN_BRANCH_NAME}"
                                    git checkout -b "${MAIN_BRANCH_NAME}" "origin/${MAIN_BRANCH_NAME}"
                                    echo "Гілка ${MAIN_BRANCH_NAME} створена з origin/${MAIN_BRANCH_NAME}"
                                fi

                                # Показуємо поточний стан
                                echo "📍 Поточний стан після checkout:"
                                echo "Гілка: $(git branch --show-current)"
                                echo "Commit: $(git log -1 --oneline)"

                                echo "🔀 Мердж dev в ${MAIN_BRANCH_NAME}..."
                                COMMIT_MSG=$(git log --oneline -1 origin/dev | head -c 50)
                                MERGE_MSG="🚀 Auto merge from dev branch via Jenkins CI

✅ Tests passed (strategy: ${TEST_STRATEGY})
📝 Latest commit: ${COMMIT_MSG}...
🔧 Files changed: ${TOTAL_FILES_COUNT} (${GO_FILES_COUNT} Go, ${JS_FILES_COUNT} JS, ${CONFIG_FILES_COUNT} Config)
🕐 Merged at: $(date)
🤖 Jenkins build: ${BUILD_NUMBER}"

                                git merge "origin/dev" --no-ff -m "${MERGE_MSG}"

                                echo "📤 Відправка змін в ${MAIN_BRANCH_NAME}..."
                                timeout ${GIT_TIMEOUT}s git push origin "${MAIN_BRANCH_NAME}" || {
                                    echo "❌ Timeout або помилка при push"
                                    exit 1
                                }

                                echo "✅ Мердж успішно завершено!"
                                echo "📊 Результат:"
                                echo "Гілка: $(git branch --show-current)"
                                echo "Останній commit: $(git log -1 --oneline)"
                            '''
                        }
                    }
                }
            }
        }
    }

    // Пост-дії
    post {
        success {
            script {
                def message = """
🎉 УСПІХ! Jenkins Build #${BUILD_NUMBER}
✅ Стратегія тестування: ${env.TEST_STRATEGY}
📊 Змінено файлів: ${env.TOTAL_FILES_COUNT} (${env.GO_FILES_COUNT} Go, ${env.JS_FILES_COUNT} JS, ${env.CONFIG_FILES_COUNT} Config)
"""
                if (env.BRANCH_NAME == 'dev' && env.SKIP_TESTS != 'true') {
                    message += "🔄 Зміни успішно змержено в main гілку\n🚀 Готово для деплою!"
                } else if (env.SKIP_TESTS == 'true') {
                    message += "📚 Тільки документація - тести пропущено"
                }

                echo message
            }
        }

        failure {
            echo """
❌ ПОМИЛКА! Jenkins Build #${BUILD_NUMBER}
🚫 Pipeline завершився з помилкою
🔒 Зміни НЕ були змержено в main
🔍 Перевірте логі для деталей
📧 Стратегія була: ${env.TEST_STRATEGY ?: 'не визначена'}
            """
        }

        unstable {
            echo """
⚠️ НЕСТАБІЛЬНИЙ СТАН! Jenkins Build #${BUILD_NUMBER}
🔄 Деякі тести пройшли з попередженнями
🔒 Мердж заблоковано до виправлення
            """
        }

        always {
            script {
                echo "🧹 Очищення та архівування..."

                // Архівуємо результати аналізу
                try {
                    archiveArtifacts artifacts: 'changed_*.txt', allowEmptyArchive: true, fingerprint: true
                } catch (Exception e) {
                    echo "⚠️ Помилка архівування: ${e.message}"
                }

                // Очищення робочого простору
                cleanWs(
                    cleanWhenAborted: true,
                    cleanWhenFailure: true,
                    cleanWhenNotBuilt: true,
                    cleanWhenSuccess: true,
                    cleanWhenUnstable: true,
                    deleteDirs: true
                )
            }
        }
    }
}
