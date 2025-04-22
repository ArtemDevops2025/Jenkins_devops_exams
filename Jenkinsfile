pipeline {
  agent any

  parameters {
    booleanParam(name: 'DEPLOY_PREPROD', defaultValue: false, description: 'Deploy to Pre-Prod?')
    booleanParam(name: 'DEPLOY_PROD', defaultValue: false, description: 'Deploy to Prod?')
  }

  environment {
    DOCKER_IMAGE_NAME = 'art2025/jenkins-exam'
    MOVIE_IMAGE_TAG = 'movie-24'
    CAST_IMAGE_TAG = 'cast-24'
    NAMESPACE = 'movie-app'
    KUBE_CONTEXT = 'default'
  }

  stages {
    stage('Verify Setup') {
      steps {
        script {
          def branchName = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
          echo "GIT BRANCH: ${branchName}"
          echo "NAMESPACE: ${env.NAMESPACE}"
          echo "KUBE_CONTEXT: ${env.KUBE_CONTEXT}"
          sh 'kubectl config get-contexts'
        }
      }
    }

    stage('Build') {
      parallel {
        stage('Build Movie Service') {
          steps {
            dir('movie-service') {
              script {
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE_TAG} ."
              }
            }
          }
        }
        stage('Build Cast Service') {
          steps {
            dir('cast-service') {
              script {
                sh "docker build -t ${DOCKER_IMAGE_NAME}:${CAST_IMAGE_TAG} ."
              }
            }
          }
        }
      }
    }

    stage('Push') {
      parallel {
        stage('Push Movie Service') {
          steps {
            script {
              docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                sh "docker tag ${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE_TAG} index.docker.io/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE_TAG}"
                sh "docker push index.docker.io/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE_TAG}"
              }
            }
          }
        }

        stage('Push Cast Service') {
          steps {
            script {
              docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                sh "docker tag ${DOCKER_IMAGE_NAME}:${CAST_IMAGE_TAG} index.docker.io/${DOCKER_IMAGE_NAME}:${CAST_IMAGE_TAG}"
                sh "docker push index.docker.io/${DOCKER_IMAGE_NAME}:${CAST_IMAGE_TAG}"
              }
            }
          }
        }
      }
    }

    stage('Deploy Pre-Prod') {
      when {
        expression { return params.DEPLOY_PREPROD }
      }
      steps {
        sh 'kubectl apply -f k8s/preprod.yaml'
      }
    }

    stage('Deploy Prod') {
      when {
        expression { return params.DEPLOY_PROD }
      }
      steps {
        sh 'kubectl apply -f k8s/prod.yaml'
      }
    }
  }
}
