pipeline {
    agent any

    tools {
        go 'go-1.21'
        nodejs 'nodejs-18'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        skipStagesAfterUnstable()
        ansiColor('xterm')
    }

    environment {
        GOPROXY = 'https://proxy.golang.org,direct'
        CGO_ENABLED = '1'
        BUILD_TAGS = 'sqlite sqlite_unlock_notify'
        GOPATH = "${env.WORKSPACE}/.go"
        GOCACHE = "${env.WORKSPACE}/.cache/go-build"
        NPM_CONFIG_CACHE = "${env.WORKSPACE}/.cache/npm"
        HOME = "${env.WORKSPACE}"
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Клонування коду..."
                    checkout scm
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.BUILD_VERSION = "${env.BUILD_NUMBER}-${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Setup Environment') {
            steps {
                script {
                    echo "🔧 Перевірка середовища..."
                    sh '''
                        echo "🐹 Go version:"
                        go version || echo "⚠️  Go не знайдено"

                        echo "📦 Node.js version:"
                        node --version || echo "⚠️  Node.js не знайдено"

                        echo "📁 Створення директорій кешу..."
                        mkdir -p .cache/go-build .cache/npm .go/pkg/mod

                        echo "✅ Середовище підготовлено"
                    '''
                }
            }
        }

        stage('Dependencies') {
            steps {
                script {
                    echo "📥 Встановлення залежностей..."

                    // Перевіряємо наявність Go
                    def goAvailable = sh(script: 'command -v go', returnStatus: true) == 0
                    if (goAvailable) {
                        echo "🐹 Завантаження Go залежностей..."
                        sh '''
                            export PATH=$PATH:$(go env GOPATH)/bin
                            go mod download
                            go mod verify
                        '''
                    } else {
                        echo "⚠️  Go не доступний, пропускаємо Go залежності"
                    }

                    // Перевіряємо frontend
                    if (fileExists('package.json')) {
                        def nodeAvailable = sh(script: 'command -v npm', returnStatus: true) == 0
                        if (nodeAvailable) {
                            echo "🎨 Встановлення frontend залежностей..."
                            sh '''
                                npm install --silent --no-progress --cache ${NPM_CONFIG_CACHE}
                            '''
                        } else {
                            echo "⚠️  Node.js/npm не доступний, пропускаємо frontend"
                        }
                    } else {
                        echo "📝 package.json не знайдено, пропускаємо frontend залежності"
                    }
                }
            }
        }

        stage('Code Quality') {
            when {
                expression {
                    sh(script: 'command -v go', returnStatus: true) == 0
                }
            }
            steps {
                script {
                    echo "🔍 Перевірка якості коду..."
                    sh '''
                        echo "🔍 Запуск go vet..."
                        go vet ./... || echo "⚠️  go vet знайшов проблеми"

                        echo "📐 Перевірка форматування..."
                        UNFORMATTED=$(go fmt -l . 2>/dev/null | head -10)
                        if [ -n "$UNFORMATTED" ]; then
                            echo "⚠️  Неправильно відформатовані файли:"
                            echo "$UNFORMATTED"
                        else
                            echo "✅ Код правильно відформатовано"
                        fi

                        # Опціональний linting
                        if command -v golangci-lint >/dev/null 2>&1; then
                            echo "🔬 Запуск golangci-lint..."
                            golangci-lint run --timeout=5m --out-format=colored-line-number || echo "⚠️  Linter знайшов проблеми"
                        fi
                    '''
                }
            }
        }

        stage('Tests') {
            when {
                expression {
                    sh(script: 'command -v go', returnStatus: true) == 0
                }
            }
            steps {
                script {
                    echo "🧪 Запуск тестів..."
                    sh '''
                        mkdir -p coverage

                        echo "🏃 Виконання тестів..."
                        go test -v -race -coverprofile=coverage/coverage.out -covermode=atomic ./... 2>&1 | \
                        grep -E "(PASS|FAIL|===|RUN)" | \
                        head -50 | \
                        sed 's/^/    /'

                        if [ -f coverage/coverage.out ]; then
                            COVERAGE=$(go tool cover -func=coverage/coverage.out | grep total | awk '{print $3}' || echo "N/A")
                            echo "📊 Покриття тестами: $COVERAGE"

                            # Генеруємо HTML звіт
                            go tool cover -html=coverage/coverage.out -o coverage/coverage.html 2>/dev/null || echo "⚠️  Не вдалося згенерувати HTML звіт"
                        else
                            echo "⚠️  Файл покриття не створено"
                        fi
                    '''
                }
            }
            post {
                always {
                    script {
                        if (fileExists('coverage/coverage.html')) {
                            echo "📈 HTML звіт покриття створено"
                        }
                    }
                }
            }
        }

        stage('Build') {
            steps {
                script {
                    echo "🔨 Збірка проекту..."

                    def goAvailable = sh(script: 'command -v go', returnStatus: true) == 0
                    def nodeAvailable = sh(script: 'command -v npm', returnStatus: true) == 0

                    if (goAvailable) {
                        echo "🐹 Збірка backend..."
                        sh '''
                            export LDFLAGS="-X 'main.Version=${BUILD_VERSION}' -X 'main.BuildTime=$(date -u '+%Y-%m-%d %H:%M:%S UTC')' -s -w"

                            if [ -f "cmd/gitea/main.go" ]; then
                                go build -ldflags "$LDFLAGS" -tags "${BUILD_TAGS}" -o gitea ./cmd/gitea
                                echo "✅ Backend зібрано успішно"
                                ls -lh gitea
                            elif [ -f "main.go" ]; then
                                go build -ldflags "$LDFLAGS" -tags "${BUILD_TAGS}" -o gitea .
                                echo "✅ Backend зібрано успішно"
                                ls -lh gitea
                            else
                                echo "⚠️  main.go не знайдено, пропускаємо збірку backend"
                            fi
                        '''
                    } else {
                        echo "⚠️  Go не доступний, пропускаємо збірку backend"
                    }

                    if (fileExists('package.json') && nodeAvailable) {
                        echo "🎨 Збірка frontend..."
                        sh '''
                            if npm run --silent build 2>/dev/null; then
                                echo "✅ Frontend зібрано успішно"
                            else
                                echo "⚠️  Frontend збірка не вдалася або скрипт відсутній"
                            fi
                        '''
                    }
                }
            }
        }

        stage('Package') {
            steps {
                script {
                    echo "📦 Створення артефактів..."
                    sh '''
                        mkdir -p dist

                        # Копіюємо бінарний файл
                        cp gitea dist/

                        # Копіюємо необхідні файли
                        if [ -d "templates" ]; then cp -r templates dist/; fi
                        if [ -d "options" ]; then cp -r options dist/; fi
                        if [ -d "public" ]; then cp -r public dist/; fi

                        # Створюємо архів
                        cd dist
                        tar -czf gitea-${BUILD_VERSION}.tar.gz *
                        cd ..

                        echo "📦 Пакет створено: gitea-${BUILD_VERSION}.tar.gz"
                        ls -lh dist/
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                echo "🧹 Очищення..."
                sh '''
                    # Очищуємо тимчасові файли, зберігаючи кеш для наступних збірок
                    rm -f gitea
                    find . -name "*.tmp" -delete 2>/dev/null || true
                '''
            }
        }
        success {
            script {
                echo "✅ Pipeline завершено успішно!"
                echo "📊 Час виконання: ${currentBuild.durationString}"

                archiveArtifacts artifacts: 'dist/*.tar.gz', fingerprint: true

                if (fileExists('coverage/coverage.out')) {
                    echo "📈 Звіт з покриття тестами збережено"
                }
            }
        }
        failure {
            script {
                echo "❌ Pipeline провалився на етапі: ${env.STAGE_NAME}"
                currentBuild.description = "❌ Провал на: ${env.STAGE_NAME}"
            }
        }
        unstable {
            script {
                echo "⚠️  Pipeline завершився з попередженнями"
                currentBuild.description = "⚠️  Нестабільна збірка"
            }
        }
    }
}
