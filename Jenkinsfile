pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        skipStagesAfterUnstable()
        ansiColor('xterm')
    }

    environment {
        GO_VERSION = '1.21'
        NODE_VERSION = '18'
        GOPROXY = 'https://proxy.golang.org,direct'
        CGO_ENABLED = '1'
        BUILD_TAGS = 'sqlite sqlite_unlock_notify'
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
            parallel {
                stage('Go Setup') {
                    steps {
                        script {
                            echo "🐹 Налаштування Go середовища..."
                            sh '''
                                go version
                                go env GOOS GOARCH
                                mkdir -p .cache/go-build
                                export GOCACHE=$(pwd)/.cache/go-build
                            '''
                        }
                    }
                }
                stage('Node Setup') {
                    steps {
                        script {
                            echo "📦 Налаштування Node.js..."
                            sh '''
                                node --version
                                npm --version
                                npm config set cache .cache/npm --global
                            '''
                        }
                    }
                }
            }
        }

        stage('Dependencies') {
            parallel {
                stage('Go Dependencies') {
                    steps {
                        script {
                            echo "📥 Завантаження Go залежностей..."
                            sh '''
                                export GOCACHE=$(pwd)/.cache/go-build
                                go mod download
                                go mod verify
                            '''
                        }
                    }
                }
                stage('Frontend Dependencies') {
                    when {
                        expression { fileExists('package.json') }
                    }
                    steps {
                        script {
                            echo "🎨 Встановлення frontend залежностей..."
                            sh '''
                                npm ci --silent --no-progress
                            '''
                        }
                    }
                }
            }
        }

        stage('Code Quality') {
            parallel {
                stage('Lint Go') {
                    steps {
                        script {
                            echo "🔍 Перевірка Go коду..."
                            sh '''
                                if command -v golangci-lint >/dev/null 2>&1; then
                                    golangci-lint run --timeout=10m --out-format=colored-line-number
                                else
                                    echo "⚠️  golangci-lint не встановлено, пропускаємо"
                                    go vet ./...
                                    go fmt -l . | (! grep .) || (echo "❌ Код не відформатовано" && exit 1)
                                fi
                            '''
                        }
                    }
                }
                stage('Security Scan') {
                    steps {
                        script {
                            echo "🔒 Сканування безпеки..."
                            sh '''
                                if command -v gosec >/dev/null 2>&1; then
                                    gosec -quiet -fmt=colored ./...
                                else
                                    echo "⚠️  gosec не встановлено, пропускаємо scan"
                                fi
                            '''
                        }
                    }
                }
            }
        }

        stage('Tests') {
            steps {
                script {
                    echo "🧪 Запуск тестів..."
                    sh '''
                        export GOCACHE=$(pwd)/.cache/go-build
                        mkdir -p coverage

                        go test -v -race -coverprofile=coverage/coverage.out -covermode=atomic ./... | \
                        grep -E "(PASS|FAIL|===|---)" | \
                        sed 's/^/    /'

                        if [ -f coverage/coverage.out ]; then
                            COVERAGE=$(go tool cover -func=coverage/coverage.out | grep total | awk '{print $3}')
                            echo "📊 Покриття тестами: $COVERAGE"
                        fi
                    '''
                }
            }
            post {
                always {
                    script {
                        if (fileExists('coverage/coverage.out')) {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'coverage',
                                reportFiles: 'coverage.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
            }
        }

        stage('Build') {
            parallel {
                stage('Backend Build') {
                    steps {
                        script {
                            echo "🔨 Збірка backend..."
                            sh '''
                                export GOCACHE=$(pwd)/.cache/go-build
                                export LDFLAGS="-X 'main.Version=${BUILD_VERSION}' -X 'main.BuildTime=$(date -u '+%Y-%m-%d %H:%M:%S UTC')' -s -w"

                                go build -ldflags "$LDFLAGS" -tags "${BUILD_TAGS}" -o gitea ./cmd/gitea

                                echo "✅ Backend зібрано успішно"
                                ls -lh gitea
                            '''
                        }
                    }
                }
                stage('Frontend Build') {
                    when {
                        expression { fileExists('package.json') }
                    }
                    steps {
                        script {
                            echo "🎨 Збірка frontend..."
                            sh '''
                                npm run build --silent
                                echo "✅ Frontend зібрано успішно"
                            '''
                        }
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
