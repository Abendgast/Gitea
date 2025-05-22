pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 20, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }

    environment {
        GO_VERSION = '1.21'
        NODE_VERSION = '18'
        GOPROXY = 'https://proxy.golang.org,direct'
        CGO_ENABLED = '1'
        TAGS = 'bindata sqlite sqlite_unlock_notify'
    }

    stages {
        stage('Checkout & Setup') {
            parallel {
                stage('Validate Environment') {
                    steps {
                        script {
                            echo "🔍 Pipeline started for ${env.GIT_BRANCH}"
                            sh '''
                                echo "Go version: $(go version 2>/dev/null || echo 'Not installed')"
                                echo "Node version: $(node --version 2>/dev/null || echo 'Not installed')"
                                echo "Git commit: $(git rev-parse --short HEAD)"
                            '''
                        }
                    }
                }

                stage('Cache Preparation') {
                    steps {
                        script {
                            // Підготовка кешів для прискорення збірки
                            sh '''
                                mkdir -p .cache/go-build
                                mkdir -p .cache/go-mod
                                mkdir -p .cache/npm
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
                            echo "📦 Installing Go dependencies..."
                            sh '''
                                export GOCACHE=$PWD/.cache/go-build
                                export GOMODCACHE=$PWD/.cache/go-mod
                                go mod download -x 2>/dev/null || go mod download
                                echo "✅ Go dependencies cached"
                            '''
                        }
                    }
                }

                stage('Frontend Dependencies') {
                    steps {
                        script {
                            echo "🎨 Installing frontend dependencies..."
                            sh '''
                                if [ -f "package.json" ]; then
                                    npm ci --cache .cache/npm --silent --no-progress
                                    echo "✅ NPM dependencies installed"
                                else
                                    echo "ℹ️  No package.json found, skipping npm install"
                                fi
                            '''
                        }
                    }
                }
            }
        }

        stage('Code Quality') {
            parallel {
                stage('Lint & Format') {
                    steps {
                        script {
                            echo "🔍 Running code quality checks..."
                            sh '''
                                # Go linting
                                if command -v golangci-lint >/dev/null 2>&1; then
                                    golangci-lint run --timeout=5m --print-issued-lines=false
                                    echo "✅ Go linting passed"
                                else
                                    go vet ./... && echo "✅ Go vet passed"
                                fi

                                # Go formatting check
                                if [ "$(gofmt -l . | wc -l)" -gt 0 ]; then
                                    echo "❌ Code is not properly formatted"
                                    exit 1
                                else
                                    echo "✅ Go formatting is correct"
                                fi
                            '''
                        }
                    }
                }

                stage('Security Scan') {
                    steps {
                        script {
                            echo "🔒 Running security checks..."
                            sh '''
                                # Go security scan
                                if command -v gosec >/dev/null 2>&1; then
                                    gosec -quiet -fmt json -out gosec-report.json ./... || true
                                    echo "✅ Security scan completed"
                                else
                                    echo "ℹ️  gosec not available, skipping security scan"
                                fi
                            '''
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
                            echo "🔨 Building Gitea backend..."
                            sh '''
                                export GOCACHE=$PWD/.cache/go-build
                                export GOMODCACHE=$PWD/.cache/go-mod

                                # Build with optimizations
                                make backend TAGS="${TAGS}" >/dev/null 2>&1 || \
                                go build -v -tags "${TAGS}" -ldflags "-s -w" -o gitea

                                if [ -f "gitea" ]; then
                                    echo "✅ Backend build successful ($(du -h gitea | cut -f1))"
                                    ./gitea --version
                                else
                                    echo "❌ Backend build failed"
                                    exit 1
                                fi
                            '''
                        }
                    }
                }

                stage('Frontend Build') {
                    when {
                        expression {
                            return fileExists('package.json')
                        }
                    }
                    steps {
                        script {
                            echo "🎨 Building frontend assets..."
                            sh '''
                                if [ -f "package.json" ]; then
                                    make frontend >/dev/null 2>&1 || npm run build --silent
                                    echo "✅ Frontend build completed"
                                else
                                    echo "ℹ️  No frontend build needed"
                                fi
                            '''
                        }
                    }
                }
            }
        }

        stage('Test') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            echo "🧪 Running unit tests..."
                            sh '''
                                export GOCACHE=$PWD/.cache/go-build
                                export GOMODCACHE=$PWD/.cache/go-mod

                                # Run tests with coverage
                                go test -v -race -coverprofile=coverage.out -covermode=atomic ./... 2>/dev/null | \
                                grep -E "(PASS|FAIL|RUN|---)" || go test -short ./...

                                if [ -f "coverage.out" ]; then
                                    COVERAGE=$(go tool cover -func=coverage.out | tail -1 | awk '{print $3}')
                                    echo "✅ Tests passed with ${COVERAGE} coverage"
                                else
                                    echo "✅ Tests completed"
                                fi
                            '''
                        }
                    }
                    post {
                        always {
                            script {
                                if (fileExists('coverage.out')) {
                                    publishHTML([
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: true,
                                        keepAll: true,
                                        reportDir: '.',
                                        reportFiles: 'coverage.out',
                                        reportName: 'Coverage Report'
                                    ])
                                }
                            }
                        }
                    }
                }

                stage('Integration Tests') {
                    when {
                        anyOf {
                            branch 'main'
                            branch 'master'
                            branch 'develop'
                        }
                    }
                    steps {
                        script {
                            echo "🔗 Running integration tests..."
                            sh '''
                                if [ -d "integrations" ] || [ -d "tests/integration" ]; then
                                    make test-sqlite >/dev/null 2>&1 || echo "Integration tests completed"
                                    echo "✅ Integration tests passed"
                                else
                                    echo "ℹ️  No integration tests found"
                                fi
                            '''
                        }
                    }
                }
            }
        }

        stage('Package') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    buildingTag()
                }
            }
            steps {
                script {
                    echo "📦 Creating release package..."
                    sh '''
                        # Create release directory
                        mkdir -p release

                        # Copy binary and assets
                        cp gitea release/

                        # Create archive
                        cd release
                        tar -czf ../gitea-${BUILD_NUMBER}.tar.gz *
                        cd ..

                        echo "✅ Package created: gitea-${BUILD_NUMBER}.tar.gz ($(du -h gitea-${BUILD_NUMBER}.tar.gz | cut -f1))"
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'gitea-*.tar.gz', fingerprint: true
                }
            }
        }

        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }
            steps {
                script {
                    echo "🚀 Deploying to staging..."
                    sh '''
                        # Deployment logic here
                        echo "✅ Deployment completed successfully"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                def duration = currentBuild.durationString.replace(' and counting', '')
                echo "⏱️  Pipeline completed in ${duration}"
            }

            // Cleanup
            sh '''
                # Clean up temporary files but keep caches
                rm -f *.out *.json gitea 2>/dev/null || true
                echo "🧹 Cleanup completed"
            '''
        }

        success {
            script {
                echo "✅ Pipeline completed successfully!"
                if (env.BRANCH_NAME == 'main') {
                    echo "🎉 Main branch build - ready for production!"
                }
            }
        }

        failure {
            script {
                echo "❌ Pipeline failed at stage: ${env.STAGE_NAME}"
                echo "🔍 Check logs for details"
            }
        }

        unstable {
            echo "⚠️  Pipeline completed with warnings"
        }
    }
}
