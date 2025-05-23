pipeline {
    agent any

    triggers {
        githubPush()
    }

    tools {
        go 'go-1.21'
    }

    environment {
        BUILD_TAGS = 'sqlite,sqlite_unlock_notify'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_DIFF = sh(
                        script: "git diff --name-only HEAD~1 HEAD | grep '\\.go$' || true",
                        returnStdout: true
                    ).trim()
                }
            }
        }

        stage('Go Vet & Test Changed') {
            when {
                expression { return env.GIT_DIFF?.trim() }
            }
            steps {
                script {
                    echo "🧪 Змінені файли:"
                    echo "${env.GIT_DIFF}"

                    def changedPackages = sh(
                        script: """
                            echo "${env.GIT_DIFF}" | xargs -n1 dirname | sort | uniq
                        """,
                        returnStdout: true
                    ).trim().split('\n').findAll { it }

                    for (pkg in changedPackages) {
                        echo "🔍 Перевірка пакету: ${pkg}"
                        sh "go vet -tags='${BUILD_TAGS}' ${pkg} || echo '⚠️ go vet виявив проблеми'"
                        sh "go test -tags='${BUILD_TAGS}' -short -timeout=60s ${pkg} || echo '❌ go test не пройшов'"
                    }
                }
            }
        }
    }
}

