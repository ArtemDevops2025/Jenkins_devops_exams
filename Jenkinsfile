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
                                docker.build(MOVIE_IMAGE)
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
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
                            docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                docker.image(MOVIE_IMAGE).push()
                            }
                        }
                    }
                }
                stage('Push Cast Service') {
                    steps {
                        script {
                            docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
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
                    branch 'main'
                }
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl create namespace ${env.NAMESPACE} || true
                        kubectl apply -f k3s/cast-db-deployment.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/cast-db-service.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-db-deployment.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-db-service.yaml -n ${env.NAMESPACE}
                        
                        kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${env.NAMESPACE} || \
                        kubectl apply -f k3s/cast-deployment.yaml -n ${env.NAMESPACE}
                        
                        kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${env.NAMESPACE} || \
                        kubectl apply -f k3s/movie-deployment.yaml -n ${env.NAMESPACE}
                        
                        kubectl apply -f k3s/cast-service.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-service.yaml -n ${env.NAMESPACE}
                        
                        kubectl rollout status deployment/cast-deployment -n ${env.NAMESPACE} --timeout=2m
                        kubectl rollout status deployment/movie-deployment -n ${env.NAMESPACE} --timeout=2m
                    """
                }
            }
        }

        stage('Deploy Prod') {
            when {
                branch 'main'
                beforeAgent true
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input(
                        message: "Confirm PRODUCTION deployment to ${env.NAMESPACE}?",
                        ok: "Deploy"
                    )
                }
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl create namespace ${env.NAMESPACE} || true
                        kubectl apply -f k3s/cast-db-deployment.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/cast-db-service.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-db-deployment.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-db-service.yaml -n ${env.NAMESPACE}
                        
                        kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${env.NAMESPACE} || \
                        kubectl apply -f k3s/cast-deployment.yaml -n ${env.NAMESPACE}
                        
                        kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${env.NAMESPACE} || \
                        kubectl apply -f k3s/movie-deployment.yaml -n ${env.NAMESPACE}
                        
                        kubectl apply -f k3s/cast-service.yaml -n ${env.NAMESPACE}
                        kubectl apply -f k3s/movie-service.yaml -n ${env.NAMESPACE}
                        
                        kubectl rollout status deployment/cast-deployment -n ${env.NAMESPACE} --timeout=3m
                        kubectl rollout status deployment/movie-deployment -n ${env.NAMESPACE} --timeout=3m
                    """
                }
            }
        }
    }

    post {
        failure {
            script {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl rollout undo deployment/cast-deployment -n ${env.NAMESPACE} || true
                        kubectl rollout undo deployment/movie-deployment -n ${env.NAMESPACE} || true
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
                } else {
                    echo "✅ Pre-prod deployment complete on branch: ${env.BRANCH_NAME}"
                }
            }
        }
    }
}
