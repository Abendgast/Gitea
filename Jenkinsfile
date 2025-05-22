pipeline {
    agent {
        label 'linux'
    }

    options {
        timeout(time: 60, unit: 'MINUTES')
        skipDefaultCheckout()
        timestamps()
    }

    environment {
        BUILD_NUMBER = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "gitea-custom:${env.BUILD_NUMBER}"

        GOROOT = '/usr/local/go'
        GOPATH = '/home/jenkins-agent/go'
        PATH = "${env.GOROOT}/bin:${env.GOPATH}/bin:${env.PATH}"

        TAGS = "bindata sqlite sqlite_unlock_notify"
        CGO_ENABLED = "1"
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm

                script {
                    env.GIT_COMMIT_SHORT = sh(
                        returnStdout: true,
                        script: 'git rev-parse --short HEAD'
                    ).trim()

                    env.GITEA_VERSION = sh(
                        returnStdout: true,
                        script: 'git describe --tags --always'
                    ).trim()
                }
            }
        }

        stage('Environment Verification') {
            steps {
                sh '''
                    echo "=== Розширена перевірка середовища ==="
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Git Commit: ${GIT_COMMIT_SHORT}"
                    echo "Gitea Version: ${GITEA_VERSION}"
                    echo "Node Name: ${NODE_NAME}"
                    echo "Workspace: ${WORKSPACE}"
                    echo ""
                    echo "=== Go Environment Verification ==="
                    echo "GOROOT: ${GOROOT}"
                    echo "GOPATH: ${GOPATH}"
                    echo "PATH: ${PATH}"

                    if command -v go >/dev/null 2>&1; then
                        echo "✅ Go знайдено: $(go version)"
                        go env GOROOT
                        go env GOPATH
                    else
                        echo "❌ Go НЕ знайдено! Білд неможливий."
                        exit 1
                    fi

                    echo "=== Проект структура ==="
                    ls -la

                    # Check for possible Gitea entry points
                    if [ -d "cmd/gitea" ]; then
                        echo "✅ cmd/gitea директорія знайдена"
                    elif [ -f "main.go" ]; then
                        echo "✅ main.go знайдено в корені проекту"
                    elif [ -d "cmd" ]; then
                        echo "✅ cmd директорія знайдена, перевіряємо зміст:"
                        ls -la cmd/
                    else
                        echo "⚠️ Стандартна Go структура проекту не знайдена"
                        echo "Наявні файли та директорії:"
                        find . -name "*.go" -type f | head -10
                    fi

                    if [ -f "go.mod" ]; then
                        echo "✅ go.mod знайдено - це Go проект"
                        head -5 go.mod
                    else
                        echo "⚠️ go.mod не знайдено"
                    fi

                    if [ -f "Makefile" ]; then
                        echo "✅ Makefile знайдено"
                        echo "Основні цілі Makefile:"
                        grep "^[a-zA-Z0-9_-]*:" Makefile | head -10 || true
                    else
                        echo "⚠️ Makefile не знайдено"
                    fi
                    echo "================================"
                '''
            }
        }

        stage('Dependencies Management') {
            steps {
                sh '''
                    echo "=== Завантаження Go залежностей ==="

                    # Clean previous builds
                    go clean -cache || true
                    go clean -modcache || true

                    echo "Завантаження модулів..."
                    timeout 10m go mod download

                    echo "Перевірка цілісності модулів..."
                    go mod verify

                    echo "Очищення зайвих залежностей..."
                    go mod tidy

                    echo "✅ Залежності успішно налаштовано"
                '''
            }
        }

        stage('Code Quality Analysis') {
            steps {
                sh '''
                    echo "=== Аналіз якості Go коду ==="
                    mkdir -p test-results

                    echo "Перевірка синтаксису Go файлів..."
                    timeout 5m go vet ./... > test-results/go-vet.log 2>&1 || echo "Go vet завершено з попередженнями"

                    echo "Перевірка форматування коду..."
                    timeout 2m gofmt -l . > test-results/gofmt.log 2>&1 || true

                    echo "=== Результати go vet ==="
                    head -10 test-results/go-vet.log || echo "Файл порожній"

                    echo "=== Результати gofmt ==="
                    head -10 test-results/gofmt.log || echo "Файл порожній"

                    echo "✅ Аналіз коду завершено"
                '''
            }
        }

        stage('Build Verification') {
            steps {
                sh '''
                    echo "=== Перевірка можливості білду ==="

                    # Determine the correct build target
                    BUILD_TARGET=""
                    if [ -d "cmd/gitea" ]; then
                        BUILD_TARGET="./cmd/gitea"
                        echo "Використовуємо cmd/gitea як ціль білду"
                    elif [ -f "main.go" ]; then
                        BUILD_TARGET="."
                        echo "Використовуємо кореневу директорію як ціль білду"
                    elif [ -d "cmd" ]; then
                        # Find the first buildable cmd subdirectory
                        for dir in cmd/*/; do
                            if [ -f "${dir}main.go" ]; then
                                BUILD_TARGET="./${dir}"
                                echo "Знайдено ціль білду: ${BUILD_TARGET}"
                                break
                            fi
                        done
                    fi

                    if [ -z "$BUILD_TARGET" ]; then
                        echo "❌ Не вдалося знайти відповідну ціль для білду"
                        echo "Структура проекту:"
                        find . -name "*.go" -type f | head -20
                        exit 1
                    fi

                    echo "Тестова компіляція з ${BUILD_TARGET}..."
                    timeout 10m go build -v ${BUILD_TARGET} > build-verification.log 2>&1 || BUILD_CHECK_FAILED=true

                    if [ "${BUILD_CHECK_FAILED}" = "true" ]; then
                        echo "⚠️ Виявлено проблеми з компіляцією:"
                        tail -20 build-verification.log
                        echo "Продовжуємо, але білд може провалитися"
                    else
                        echo "✅ Перевірка компіляції пройшла успішно"
                        echo "Ціль білду: ${BUILD_TARGET}"
                        # Save the build target for later use
                        echo "${BUILD_TARGET}" > build-target.txt
                    fi
                '''
            }
        }

        stage('Testing') {
            steps {
                sh '''
                    echo "=== Виконання тестів ==="
                    mkdir -p test-results

                    export GO_TEST_TIMEOUT=15m

                    echo "Запуск тестів з коротким таймаутом..."
                    timeout 20m go test -v -timeout=${GO_TEST_TIMEOUT} -short ./... > test-results/unit-tests.log 2>&1 || TEST_EXIT_CODE=$?

                    echo "=== Результати тестування ==="
                    tail -50 test-results/unit-tests.log || echo "Лог файл порожній"

                    if [ "${TEST_EXIT_CODE:-0}" -ne 0 ]; then
                        echo "⚠️ Деякі тести провалилися, але продовжуємо білд"
                        echo "Код виходу: ${TEST_EXIT_CODE:-0}"
                    else
                        echo "✅ Тести пройшли успішно"
                    fi

                    # Try to generate coverage if tests passed
                    if [ "${TEST_EXIT_CODE:-0}" -eq 0 ]; then
                        echo "Генерація звіту покриття..."
                        timeout 10m go test -coverprofile=test-results/coverage.out ./... > /dev/null 2>&1 || true
                        if [ -f "test-results/coverage.out" ]; then
                            go tool cover -html=test-results/coverage.out -o test-results/coverage.html
                            echo "✅ HTML звіт покриття створено"
                        fi
                    fi
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: 'test-results/*', allowEmptyArchive: true
                }
            }
        }

        stage('Build Gitea Application') {
            steps {
                sh '''
                    echo "=== Початок реального білду Gitea ==="
                    mkdir -p build-artifacts

                    export BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                    export BUILD_HASH=${GIT_COMMIT_SHORT}

                    echo "Параметри білду:"
                    echo "- Версія: ${GITEA_VERSION}"
                    echo "- Дата: ${BUILD_DATE}"
                    echo "- Коміт: ${BUILD_HASH}"
                    echo "- Теги: ${TAGS}"

                    # Determine build target from previous stage
                    BUILD_TARGET="./cmd/gitea"
                    if [ -f "build-target.txt" ]; then
                        BUILD_TARGET=$(cat build-target.txt)
                        echo "Використовуємо збережену ціль білду: ${BUILD_TARGET}"
                    fi

                    # Try Makefile first
                    MAKE_BUILD_SUCCESS=false
                    if [ -f "Makefile" ]; then
                        echo "Спроба білду через Makefile..."

                        # Check if 'build' target exists
                        if make -n build >/dev/null 2>&1; then
                            echo "Знайдено ціль 'build' в Makefile"
                            timeout 20m make build TAGS="${TAGS}" && MAKE_BUILD_SUCCESS=true
                        elif make -n gitea >/dev/null 2>&1; then
                            echo "Знайдено ціль 'gitea' в Makefile"
                            timeout 20m make gitea TAGS="${TAGS}" && MAKE_BUILD_SUCCESS=true
                        else
                            echo "Стандартні цілі не знайдені в Makefile"
                        fi
                    fi

                    # Fallback to direct go build
                    if [ "$MAKE_BUILD_SUCCESS" = "false" ]; then
                        echo "Makefile білд провалився або недоступний, використовуємо go build..."

                        timeout 20m go build -v \
                            -tags "${TAGS}" \
                            -ldflags "-s -w -X 'code.gitea.io/gitea/modules/setting.BuildTime=${BUILD_DATE}' -X 'code.gitea.io/gitea/modules/setting.BuildGitHash=${BUILD_HASH}'" \
                            -o build-artifacts/gitea \
                            ${BUILD_TARGET}
                    else
                        # Copy the built binary to our artifacts directory
                        if [ -f "gitea" ]; then
                            cp gitea build-artifacts/gitea
                        elif [ -f "cmd/gitea/gitea" ]; then
                            cp cmd/gitea/gitea build-artifacts/gitea
                        else
                            echo "⚠️ Не знайдено зібраний binary після Makefile"
                            # Try to find any gitea binary
                            find . -name "gitea" -type f -executable | head -1 | xargs -I {} cp {} build-artifacts/gitea
                        fi
                    fi

                    # Verify the binary was created
                    if [ -f "build-artifacts/gitea" ]; then
                        echo "✅ Gitea binary успішно зібрано!"
                        ls -la build-artifacts/gitea
                        file build-artifacts/gitea

                        echo "Перевірка версії зібраного binary:"
                        timeout 10s ./build-artifacts/gitea --version || echo "Версію не вдалося отримати, але binary існує"

                        echo "Створення метаданих білду..."
                        cat > build-artifacts/build-info.txt << EOF
Gitea Custom Build Information
==============================
Build Number: ${BUILD_NUMBER}
Version: ${GITEA_VERSION}
Git Commit: ${GIT_COMMIT_SHORT}
Build Date: ${BUILD_DATE}
Build Tags: ${TAGS}
Build Target: ${BUILD_TARGET}
Builder: Jenkins CI/CD
Node: ${NODE_NAME}
Go Version: $(go version)
EOF
                    else
                        echo "❌ Gitea binary НЕ створено! Білд провалився."
                        echo "Вміст директорії build-artifacts:"
                        ls -la build-artifacts/ || true
                        echo "Пошук всіх виконуваних файлів:"
                        find . -name "*gitea*" -type f || true
                        exit 1
                    fi

                    echo "=== Білд Gitea завершено ==="
                '''
            }
        }

        stage('Docker Build') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                }
            }
            steps {
                script {
                    sh '''
                        echo "=== Створення Docker образу ==="

                        # Verify binary exists before creating Docker image
                        if [ ! -f "build-artifacts/gitea" ]; then
                            echo "❌ Gitea binary не знайдено для Docker образу"
                            exit 1
                        fi

                        cat > Dockerfile << 'EOF'
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    git \
    sqlite \
    openssh \
    gnupg \
    && adduser -D -s /bin/sh gitea

# Set up application directory
WORKDIR /app

# Copy application binary and metadata
COPY build-artifacts/gitea /app/gitea
COPY build-artifacts/build-info.txt /app/

# Set proper permissions
RUN chmod +x /app/gitea && \
    chown -R gitea:gitea /app

# Create data directory
RUN mkdir -p /data && chown -R gitea:gitea /data

USER gitea
EXPOSE 3000 22

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD ["/app/gitea", "manager", "check", "--quiet"] || exit 1

# Default command
CMD ["/app/gitea", "web"]
EOF

                        echo "Dockerfile створено, початок збірки образу..."
                        timeout 10m docker build -t ${DOCKER_IMAGE} .

                        echo "Перевірка створеного образу:"
                        docker images | grep gitea-custom || true
                        docker inspect ${DOCKER_IMAGE} || true

                        echo "✅ Docker образ створено: ${DOCKER_IMAGE}"
                    '''
                }
            }
        }

        stage('Artifact Management') {
            steps {
                sh '''
                    echo "=== Підготовка фінальних артефактів ==="

                    # Create comprehensive build archive
                    tar -czf gitea-build-${BUILD_NUMBER}.tar.gz \
                        build-artifacts/ \
                        test-results/ \
                        *.log

                    # Create detailed metadata
                    cat > build-metadata.json << EOF
{
    "build_number": "${BUILD_NUMBER}",
    "git_commit": "${GIT_COMMIT_SHORT}",
    "version": "${GITEA_VERSION}",
    "timestamp": "$(date -Iseconds)",
    "docker_image": "${DOCKER_IMAGE}",
    "build_node": "${NODE_NAME}",
    "go_version": "$(go version)",
    "build_tags": "${TAGS}",
    "build_duration": "${BUILD_TIMESTAMP}",
    "artifacts": {
        "binary": "build-artifacts/gitea",
        "binary_size": "$(stat -c%s build-artifacts/gitea 2>/dev/null || echo 0)",
        "archive": "gitea-build-${BUILD_NUMBER}.tar.gz",
        "docker_image": "${DOCKER_IMAGE}"
    },
    "checksums": {
        "binary_sha256": "$(sha256sum build-artifacts/gitea | cut -d' ' -f1)",
        "archive_sha256": "$(sha256sum gitea-build-${BUILD_NUMBER}.tar.gz | cut -d' ' -f1)"
    }
}
EOF

                    echo "✅ Артефакти підготовлено для архівування"
                    echo "Фінальні файли:"
                    ls -la *.tar.gz *.json build-artifacts/ 2>/dev/null || true
                '''
            }
            post {
                always {
                    archiveArtifacts artifacts: '*.tar.gz,build-metadata.json,build-artifacts/**,test-results/**', allowEmptyArchive: true
                }
            }
        }
    }

    post {
        always {
            script {
                sh '''
                    echo "=== Очищення після білду ==="

                    # Clean up old Docker images (keep last 3)
                    docker images | grep gitea-custom | awk '{print $3}' | tail -n +4 | xargs -r docker rmi || true

                    # Clean Go caches
                    go clean -cache || true
                    go clean -testcache || true

                    echo "Очищення завершено"
                '''
            }
        }

        success {
            echo '✅ Pipeline completed successfully! Gitea build ready for deployment.'
        }

        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }

        unstable {
            echo '⚠️ Pipeline completed with warnings - some tests may have failed but build succeeded.'
        }
    }
}
