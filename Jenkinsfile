pipeline {
  agent {
    label 'docker-agent'
  }
////
  parameters {
    booleanParam(
      name: 'PUSH_TO_ECR',
      defaultValue: false,
      description: 'Push image to AWS ECR repository'
    )
  }

  environment {
    DOCKER_REGISTRY = '680833125636.dkr.ecr.us-east-1.amazonaws.com/gitea-app'
    IMAGE_NAME = 'gitea-app'
    AWS_REGION = 'us-east-1'
  }

  options {
    timestamps()
    skipDefaultCheckout()
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Preparation') {
      steps {
        script {
          def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          def timestamp = sh(script: "date '+%Y%m%d-%H%M%S'", returnStdout: true).trim()
          env.VERSION_TAG = "${params.PUSH_TO_ECR ? 'prod' : 'dev'}-jenkins-${timestamp}-${shortCommit}"
          echo "Building version: ${VERSION_TAG}"
          echo "Branch: ${env.BRANCH_NAME}"
          echo "Push to ECR: ${params.PUSH_TO_ECR}"
        }
      }
    }

    stage('Build Docker Image') {
      steps {
        sh "cp /host-infra/gitea/Dockerfile ."
        sh "docker build -t ${IMAGE_NAME}:${VERSION_TAG} ."
      }
    }

    stage('Test Image') {
      steps {
        sh "docker run --rm ${IMAGE_NAME}:${VERSION_TAG} --version"
      }
    }

    stage('Tag for ECR') {
      when {
        expression { return params.PUSH_TO_ECR }
      }
      steps {
        sh "docker tag ${IMAGE_NAME}:${VERSION_TAG} ${DOCKER_REGISTRY}:${VERSION_TAG}"
      }
    }

    stage('Push to ECR') {
      when {
        expression { return params.PUSH_TO_ECR }
      }
      steps {
        withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
          sh '''
            aws ecr get-login-password --region $AWS_REGION | \
              docker login --username AWS --password-stdin $DOCKER_REGISTRY
            docker push $DOCKER_REGISTRY:$VERSION_TAG
          '''
        }
      }
    }

    stage('Cleanup') {
      steps {
        sh "docker rmi ${IMAGE_NAME}:${VERSION_TAG} || true"
        sh "docker rmi ${DOCKER_REGISTRY}:${VERSION_TAG} || true"
      }
    }
  }

  post {
    always {
      echo 'Pipeline finished.'
    }
  }
}
