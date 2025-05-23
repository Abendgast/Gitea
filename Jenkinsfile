pipeline {
    agent any

    environment {
        GO_ENV = "development"
        NGROK_PORT = "8080"
    }

    stages {
        stage('Checkout') {
            steps {
                cleanWs()
                checkout scm
            }
        }

        stage('Detect Changed Files') {
            steps {
                script {
                    // Отримаємо список змінених файлів
                    CHANGED_FILES = sh(
                        script: "git diff --name-only HEAD~1 HEAD",
                        returnStdout: true
                    ).trim().split("\n")
                    echo "Змінені файли: ${CHANGED_FILES}"

                    // Визначимо, які тести запускати
                    RUN_GO_TESTS = CHANGED_FILES.any { it.endsWith('.go') }
                    RUN_YAML_TESTS = CHANGED_FILES.any { it.endsWith('.yml') || it.endsWith('.yaml') }
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    if (RUN_GO_TESTS) {
                        echo "Запускаємо Go тести..."
                        sh 'go test ./...'
                    } else {
                        echo "Go тести не потрібні."
                    }

                    if (RUN_YAML_TESTS) {
                        echo "Перевірка YAML-файлів..."
                        sh 'yamllint .'
                    } else {
                        echo "YAML тести не потрібні."
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ Тести пройшли успішно'
        }
        failure {
            echo '❌ Помилка: тести не пройшли'
        }
    }
}

