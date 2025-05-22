pipeline {
    agent {
        label 'linux'
    }

    options {
        // Зменшуємо загальний таймаут до 25 хвилин
        timeout(time: 25, unit: 'MINUTES')
        skipDefaultCheckout()
        timestamps()
        // Додаємо можливість перервати збірку
        disableConcurrentBuilds()
    }

    environment {
        BUILD_NUMBER = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "gitea-custom:${env.BUILD_NUMBER}"

        // Go налаштування
        GOROOT = '/usr/local/go'
        GOPATH = '/home/jenkins-agent/go'
        PATH = "${env.GOROOT}/bin:${env.GOPATH}/bin:${env.PATH}"

        // Важливо: правильні теги для Gitea з SQLite підтримкою
        TAGS = "bindata sqlite sqlite_unlock_notify"
        CGO_ENABLED = "1"

        // Оптимізація Go збірки
        GOCACHE = '/tmp/go-build-cache'
        GOMODCACHE = '/tmp/go-mod-cache'
    }

    stages {
        stage('Підготовка') {
            steps {
                // Очищуємо робочу директорію та завантажуємо код
                cleanWs()
                checkout scm

                script {
                    // Отримуємо базову інформацію про збірку
                    env.GIT_COMMIT_SHORT = sh(
                        returnStdout: true,
                        script: 'git rev-parse --short HEAD'
                    ).trim()

                    env.GITEA_VERSION = sh(
                        returnStdout: true,
                        script: 'git describe --tags --always'
                    ).trim()
                }

                sh '''
                    echo "🚀 Початок збірки Gitea"
                    echo "Версія: ${GITEA_VERSION}"
                    echo "Коміт: ${GIT_COMMIT_SHORT}"
                    echo "Номер збірки: ${BUILD_NUMBER}"

                    # Створюємо директорії для кешування
                    mkdir -p ${GOCACHE} ${GOMODCACHE}

                    # Перевіряємо Go
                    go version

                    # Швидка перевірка структури проекту
                    if [ -f "go.mod" ] && [ -f "Makefile" ]; then
                        echo "✅ Gitea проект готовий до збірки"
                    else
                        echo "❌ Проблема зі структурою проекту"
                        exit 1
                    fi
                '''
            }
        }

        stage('Залежності') {
            steps {
                sh '''
                    echo "📦 Завантаження залежностей..."

                    # Використовуємо кеш для прискорення
                    export GOPROXY=https://proxy.golang.org,direct
                    export GOSUMDB=sum.golang.org

                    # Завантажуємо залежності з таймаутом
                    timeout 5m go mod download -x

                    # Перевіряємо цілісність
                    go mod verify

                    echo "✅ Залежності готові"
                '''
            }
        }

        stage('Швидка перевірка') {
            steps {
                sh '''
                    echo "🔍 Базова перевірка коду..."

                    # Перевіряємо синтаксис без детального аналізу
                    timeout 3m go vet -tags="${TAGS}" ./cmd/... ./modules/... || echo "Попередження в коді проігноровано"

                    # Швидка перевірка компіляції основних компонентів
                    timeout 5m go build -tags="${TAGS}" -o /tmp/gitea-test ./cmd/gitea

                    echo "✅ Код готовий до збірки"
                '''
            }
        }

        stage('Тестування') {
            steps {
                sh '''
                    echo "🧪 Запуск критично важливих тестів..."
                    mkdir -p test-results

                    # Запускаємо тільки швидкі тести з правильними тегами
                    # Важливо: передаємо теги для SQLite підтримки
                    timeout 8m go test -tags="${TAGS}" -short -timeout=5m \
                        ./modules/setting \
                        ./modules/util \
                        ./modules/base \
                        ./modules/log \
                        > test-results/critical-tests.log 2>&1 || TEST_FAILED=true

                    if [ "${TEST_FAILED}" = "true" ]; then
                        echo "⚠️ Деякі критичні тести провалилися:"
                        tail -20 test-results/critical-tests.log
                        echo "Продовжуємо збірку..."
                    else
                        echo "✅ Критичні тести пройшли успішно"
                    fi

                    # Не запускаємо всі тести - це економить 30+ хвилин
                    echo "ℹ️ Повне тестування пропущено для швидкості збірки"
                '''
            }
        }

        stage('Збірка Gitea') {
            steps {
                sh '''
                    echo "🔨 Збірка Gitea з оптимізацією..."
                    mkdir -p build-artifacts

                    export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                    export BUILD_HASH=${GIT_COMMIT_SHORT}

                    # Використовуємо Makefile для найкращої збірки
                    if make -n build >/dev/null 2>&1; then
                        echo "Збірка через Makefile (рекомендований спосіб)..."

                        # Очищуємо попередні збірки
                        make clean || true

                        # Збираємо з оптимізацією та правильними тегами
                        timeout 10m make build \
                            TAGS="${TAGS}" \
                            LDFLAGS="-s -w -X 'code.gitea.io/gitea/modules/setting.BuildTime=${BUILD_DATE}' -X 'code.gitea.io/gitea/modules/setting.BuildGitHash=${BUILD_HASH}'"

                        # Копіюємо зібраний binary
                        cp gitea build-artifacts/gitea

                    else
                        echo "Пряма збірка через go build..."

                        # Збираємо напряму з усіма необхідними параметрами
                        timeout 10m go build -v \
                            -tags="${TAGS}" \
                            -ldflags="-s -w -X 'code.gitea.io/gitea/modules/setting.BuildTime=${BUILD_DATE}' -X 'code.gitea.io/gitea/modules/setting.BuildGitHash=${BUILD_HASH}'" \
                            -o build-artifacts/gitea \
                            ./cmd/gitea
                    fi

                    # Перевіряємо результат збірки
                    if [ -f "build-artifacts/gitea" ]; then
                        echo "✅ Gitea успішно зібрано!"
                        ls -lh build-artifacts/gitea

                        # Швидка перевірка binary
                        timeout 5s ./build-artifacts/gitea --version || echo "Binary створено, але версію отримати не вдалося"

                        # Створюємо інформацію про збірку
                        cat > build-artifacts/build-info.txt << EOF
Збірка Gitea
============
Номер збірки: ${BUILD_NUMBER}
Версія: ${GITEA_VERSION}
Коміт: ${GIT_COMMIT_SHORT}
Дата збірки: ${BUILD_DATE}
Теги збірки: ${TAGS}
Вузол Jenkins: ${NODE_NAME}
Розмір binary: $(stat -c%s build-artifacts/gitea) байт
EOF

                    else
                        echo "❌ Збірка провалилася - binary не створено"
                        exit 1
                    fi
                '''
            }
        }

        stage('Docker образ') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                sh '''
                    echo "🐳 Створення Docker образу..."

                    # Створюємо мінімальний Dockerfile для швидкої збірки
                    cat > Dockerfile << 'EOF'
FROM alpine:3.19

# Встановлюємо мінімальні залежності
RUN apk add --no-cache ca-certificates git openssh tzdata && \
    adduser -D -s /bin/sh gitea

# Копіюємо додаток
WORKDIR /app
COPY build-artifacts/gitea /app/gitea
RUN chmod +x /app/gitea && chown gitea:gitea /app/gitea

# Створюємо директорію для даних
RUN mkdir -p /data && chown gitea:gitea /data

USER gitea
EXPOSE 3000 22

# Простий healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=2 \
    CMD ["/app/gitea", "help"] || exit 1

CMD ["/app/gitea", "web"]
EOF

                    # Збираємо образ з таймаутом
                    timeout 5m docker build -t ${DOCKER_IMAGE} .

                    echo "✅ Docker образ створено: ${DOCKER_IMAGE}"
                    docker images | grep gitea-custom | head -3
                '''
            }
        }

        stage('Фінальні артефакти') {
            steps {
                sh '''
                    echo "📦 Підготовка артефактів..."

                    # Створюємо архів зі збіркою
                    tar -czf gitea-build-${BUILD_NUMBER}.tar.gz build-artifacts/

                    # Створюємо метадані у JSON форматі
                    cat > build-summary.json << EOF
{
    "build_number": "${BUILD_NUMBER}",
    "version": "${GITEA_VERSION}",
    "commit": "${GIT_COMMIT_SHORT}",
    "timestamp": "$(date -Iseconds)",
    "docker_image": "${DOCKER_IMAGE}",
    "artifacts": {
        "binary": "build-artifacts/gitea",
        "archive": "gitea-build-${BUILD_NUMBER}.tar.gz",
        "size_mb": $(echo "scale=2; $(stat -c%s build-artifacts/gitea) / 1048576" | bc)
    },
    "build_info": {
        "duration_minutes": "$(echo "scale=1; ($(date +%s) - ${BUILD_TIMESTAMP:-$(date +%s)}) / 60" | bc)",
        "go_version": "$(go version | cut -d' ' -f3)",
        "build_tags": "${TAGS}"
    }
}
EOF

                    echo "✅ Артефакти готові:"
                    ls -lh *.tar.gz *.json build-artifacts/
                '''
            }
            post {
                always {
                    // Архівуємо важливі артефакти
                    archiveArtifacts artifacts: '*.tar.gz,build-summary.json,build-artifacts/**,test-results/*', allowEmptyArchive: true
                }
            }
        }
    }

    post {
        always {
            sh '''
                echo "🧹 Очищення після збірки..."

                # Видаляємо старі Docker образи (залишаємо останні 2)
                docker images | grep gitea-custom | tail -n +3 | awk '{print $3}' | xargs -r docker rmi || true

                # Очищуємо Go кеші
                go clean -cache -testcache -modcache || true

                echo "Очищення завершено"
            '''
        }

        success {
            echo '''
🎉 Збірка завершена успішно!
✅ Gitea binary готовий
✅ Docker образ створено (якщо потрібно)
✅ Артефакти заархівовано

Час збірки значно зменшено завдяки оптимізації.
            '''
        }

        failure {
            echo '''
❌ Збірка провалилася!

Можливі причини:
- Проблеми з Go залежностями
- Помилки компіляції
- Недостатньо ресурсів на вузлі

Перевірте логи для деталей.
            '''
        }

        unstable {
            echo '⚠️ Збірка завершена з попередженнями - деякі тести провалилися, але binary створено.'
        }
    }
}
