pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        NAMESPACE = "${env.BRANCH_NAME == 'main' ? 'prod' : env.BRANCH_NAME}"
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            parallel {
                stage('Build Movie Service') {
                    steps {
                        dir('movie-service') {
                            script {
                                echo "Building Movie Service Docker Image: ${MOVIE_IMAGE}"
                                docker.build(MOVIE_IMAGE)
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                echo "Building Cast Service Docker Image: ${CAST_IMAGE}"
                                docker.build(CAST_IMAGE)
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
                            echo "Pushing Movie Service Docker Image: ${MOVIE_IMAGE}"
                            docker.withRegistry('https://index.docker.io/v1/', DOCKERHUB_CREDENTIALS) {
                                docker.image(MOVIE_IMAGE).push()
                            }
                        }
                    }
                }
                stage('Push Cast Service') {
                    steps {
                        script {
                            echo "Pushing Cast Service Docker Image: ${CAST_IMAGE}"
                            docker.withRegistry('https://index.docker.io/v1/', DOCKERHUB_CREDENTIALS) {
                                docker.image(CAST_IMAGE).push()
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy Pre-Prod') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'qa'
                }
            }
            steps {
                script {
                    echo "Deploying to Pre-Prod: ${NAMESPACE}"
                }
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl create namespace ${NAMESPACE} || true

                        kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}

                        kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${NAMESPACE} || \
                        kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}

                        kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${NAMESPACE} || \
                        kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}

                        kubectl apply -f k3s/cast-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-service.yaml -n ${NAMESPACE}

                        kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=2m
                        kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=2m
                    """
                }
            }
        }

        stage('Deploy Prod') {
            when {
                branch 'main'
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input message: "Confirm PRODUCTION deployment to ${NAMESPACE}?", ok: "Deploy"
                }
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl create namespace ${NAMESPACE} || true

                        kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}

                        kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${NAMESPACE} || \
                        kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}

                        kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${NAMESPACE} || \
                        kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}

                        kubectl apply -f k3s/cast-service.yaml -n ${NAMESPACE}
                        kubectl apply -f k3s/movie-service.yaml -n ${NAMESPACE}

                        kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=3m
                        kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=3m
                    """
                }
            }
        }
    }

    post {
        failure {
            script {
                echo "Deployment failed. Rolling back changes."
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl rollout undo deployment/cast-deployment -n ${NAMESPACE} || true
                        kubectl rollout undo deployment/movie-deployment -n ${NAMESPACE} || true
                    """
                }
            }
        }
        success {
            script {
                if (env.BRANCH_NAME == 'main') {
                    slackSend(
                        color: 'good',
                        message: "✅ PRODUCTION Deployment Successful: ${env.BUILD_URL}"
                    )
                }
                echo "Deployment completed successfully."
            }
        }
    }
}
