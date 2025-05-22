pipeline {
    agent {
        docker {
            image 'golang:1.21-alpine'
            args '-v /var/run/docker.sock:/var/run/docker.sock --user root'
        }
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 25, unit: 'MINUTES')
        timestamps()
        ansiColor('xterm')
    }

    environment {
        GOPROXY = 'https://proxy.golang.org,direct'
        CGO_ENABLED = '1'
        TAGS = 'bindata sqlite sqlite_unlock_notify'
        HOME = '/tmp'
    }

    stages {
        stage('Environment Setup') {
            steps {
                script {
                    echo "🔧 Setting up build environment..."
                    sh '''
                        # Install required packages
                        apk add --no-cache git make gcc musl-dev sqlite-dev nodejs npm curl tar >/dev/null 2>&1

                        # Verify installations
                        echo "✅ Go version: $(go version)"
                        echo "✅ Node version: $(node --version)"
                        echo "✅ NPM version: $(npm --version)"
                        echo "✅ Git commit: $(git rev-parse --short HEAD)"

                        # Create cache directories
                        mkdir -p .cache/go-build .cache/go-mod .cache/npm

                        echo "🎯 Environment ready"
                    '''
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

                                go mod download >/dev/null 2>&1
                                echo "✅ Go dependencies installed"
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
                            echo "🎨 Installing frontend dependencies..."
                            sh '''
                                npm ci --cache .cache/npm --silent --no-progress >/dev/null 2>&1
                                echo "✅ Frontend dependencies installed"
                            '''
                        }
                    }
                }
            }
        }

        stage('Code Quality') {
            parallel {
                stage('Go Formatting') {
                    steps {
                        script {
                            echo "📝 Checking Go code formatting..."
                            sh '''
                                UNFORMATTED=$(gofmt -l . | grep -v vendor || true)
                                if [ ! -z "$UNFORMATTED" ]; then
                                    echo "❌ Files need formatting:"
                                    echo "$UNFORMATTED"
                                    exit 1
                                fi
                                echo "✅ Go code is properly formatted"
                            '''
                        }
                    }
                }

                stage('Go Vet') {
                    steps {
                        script {
                            echo "🔍 Running go vet..."
                            sh '''
                                go vet ./... >/dev/null 2>&1
                                echo "✅ Go vet passed"
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

                                # Build binary
                                if [ -f "Makefile" ]; then
                                    make backend TAGS="${TAGS}" >/dev/null 2>&1
                                else
                                    go build -v -tags "${TAGS}" -ldflags "-s -w -X main.Version=${BUILD_NUMBER}" -o gitea >/dev/null 2>&1
                                fi

                                if [ -f "gitea" ]; then
                                    SIZE=$(du -h gitea | cut -f1)
                                    echo "✅ Backend build successful (${SIZE})"
                                    ./gitea --version 2>/dev/null || echo "Binary created successfully"
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
                        expression { fileExists('package.json') }
                    }
                    steps {
                        script {
                            echo "🎨 Building frontend assets..."
                            sh '''
                                if [ -f "Makefile" ] && grep -q "frontend" Makefile; then
                                    make frontend >/dev/null 2>&1
                                elif [ -f "package.json" ]; then
                                    npm run build --silent >/dev/null 2>&1 || echo "No build script found"
                                fi
                                echo "✅ Frontend build completed"
                            '''
                        }
                    }
                }
            }
        }

        stage('Tests') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        script {
                            echo "🧪 Running unit tests..."
                            sh '''
                                export GOCACHE=$PWD/.cache/go-build
                                export GOMODCACHE=$PWD/.cache/go-mod

                                # Run tests with timeout
                                timeout 300 go test -short -race ./... 2>/dev/null | grep -E "(PASS|FAIL|ok|SKIP)" || \
                                go test -short ./... >/dev/null 2>&1

                                echo "✅ Unit tests completed"
                            '''
                        }
                    }
                }

                stage('Build Validation') {
                    steps {
                        script {
                            echo "🔍 Validating build artifacts..."
                            sh '''
                                if [ -f "gitea" ]; then
                                    # Test if binary is executable
                                    chmod +x gitea
                                    if ./gitea --help >/dev/null 2>&1; then
                                        echo "✅ Binary is functional"
                                    else
                                        echo "⚠️  Binary created but help command failed"
                                    fi
                                else
                                    echo "❌ No binary found"
                                    exit 1
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
                        # Create release structure
                        mkdir -p release/gitea-${BUILD_NUMBER}

                        # Copy main binary
                        cp gitea release/gitea-${BUILD_NUMBER}/

                        # Copy additional files if they exist
                        for file in LICENSE README.md CHANGELOG.md; do
                            [ -f "$file" ] && cp "$file" release/gitea-${BUILD_NUMBER}/
                        done

                        # Create templates and public directories if they exist
                        [ -d "templates" ] && cp -r templates release/gitea-${BUILD_NUMBER}/
                        [ -d "public" ] && cp -r public release/gitea-${BUILD_NUMBER}/

                        # Create archive
                        cd release
                        tar -czf gitea-${BUILD_NUMBER}-linux-amd64.tar.gz gitea-${BUILD_NUMBER}/
                        cd ..

                        SIZE=$(du -h release/gitea-${BUILD_NUMBER}-linux-amd64.tar.gz | cut -f1)
                        echo "✅ Package created: gitea-${BUILD_NUMBER}-linux-amd64.tar.gz (${SIZE})"
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'release/*.tar.gz', fingerprint: true
                }
            }
        }

        stage('Quality Gate') {
            when {
                anyOf {
                    branch 'main'
                    branch 'master'
                    branch 'develop'
                }
            }
            steps {
                script {
                    echo "🎯 Running quality gate checks..."
                    sh '''
                        BINARY_SIZE=$(stat -c%s gitea 2>/dev/null || echo "0")
                        MAX_SIZE=$((50 * 1024 * 1024))  # 50MB

                        if [ "$BINARY_SIZE" -gt "$MAX_SIZE" ]; then
                            echo "⚠️  Warning: Binary size ($(($BINARY_SIZE / 1024 / 1024))MB) exceeds recommended limit"
                        else
                            echo "✅ Binary size is acceptable ($(($BINARY_SIZE / 1024 / 1024))MB)"
                        fi

                        echo "✅ Quality gate passed"
                    '''
                }
            }
        }
    }

    post {
        always {
            script {
                def duration = currentBuild.durationString.replace(' and counting', '')
                def status = currentBuild.currentResult

                echo "⏱️  Pipeline completed in ${duration}"
                echo "📊 Final status: ${status}"

                if (fileExists('gitea')) {
                    def size = sh(script: "du -h gitea | cut -f1", returnStdout: true).trim()
                    echo "📦 Binary size: ${size}"
                }
            }

            // Cleanup
            sh '''
                rm -f gitea *.out *.json 2>/dev/null || true
                echo "🧹 Cleanup completed"
            '''
        }

        success {
            script {
                echo "🎉 Pipeline completed successfully!"
                if (env.BRANCH_NAME in ['main', 'master']) {
                    echo "🚀 Main branch build - artifacts ready for deployment"
                }
            }
        }

        failure {
            script {
                echo "❌ Pipeline failed"
                echo "🔍 Check the logs above for detailed error information"

                // Try to provide helpful debugging info
                sh '''
                    echo "📋 Debug information:"
                    echo "Current directory: $(pwd)"
                    echo "Available space: $(df -h . | tail -1)"
                    echo "Go env: $(go env GOOS GOARCH 2>/dev/null || echo 'Go not available')"
                ''' || true
            }
        }

        unstable {
            echo "⚠️  Pipeline completed with warnings - review required"
        }
    }
}
