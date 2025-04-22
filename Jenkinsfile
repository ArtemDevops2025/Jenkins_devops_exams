pipeline {
    agent any

    environment {
        // Registry configuration
        DOCKER_REGISTRY = 'index.docker.io'
        DOCKER_REPO = 'art2025/jenkins-exam'
        DOCKER_CREDS = credentials('dockerhub') // Ensure this credential exists in Jenkins

        // Dynamic tags and namespace
        MOVIE_TAG = "movie-${env.BUILD_NUMBER}"
        CAST_TAG = "cast-${env.BUILD_NUMBER}"
        NAMESPACE = sh(script: '''
            git rev-parse --abbrev-ref HEAD | grep -oE "main|dev|qa" || echo "movie-app"
        ''', returnStdout: true).trim()
    }

    stages {
        stage('Login to Docker Hub') {
            steps {
                script {
                    withCredentials([usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )]) {
                        sh """
                            docker login -u $DOCKER_USER -p $DOCKER_PASS ${DOCKER_REGISTRY}
                        """
                    }
                }
            }
        }

        stage('Build and Push Images') {
            parallel {
                stage('Movie Service') {
                    steps {
                        dir('movie-service') {
                            script {
                                sh "docker build -t ${DOCKER_REPO}:${MOVIE_TAG} ."
                                sh "docker push ${DOCKER_REPO}:${MOVIE_TAG}"
                            }
                        }
                    }
                }
                stage('Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                sh "docker build -t ${DOCKER_REPO}:${CAST_TAG} ."
                                sh "docker push ${DOCKER_REPO}:${CAST_TAG}"
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                expression { 
                    return env.BRANCH_NAME == 'dev' || 
                           env.BRANCH_NAME == 'qa' || 
                           env.BRANCH_NAME == 'main' 
                }
            }
            steps {
                script {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            # Create namespace if needed
                            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Deploy databases
                            kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}
                            
                            # Deploy services
                            kubectl set image deployment/cast-deployment cast-service=${DOCKER_REPO}:${CAST_TAG} -n ${NAMESPACE} || \\
                            kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}
                            
                            kubectl set image deployment/movie-deployment movie-service=${DOCKER_REPO}:${MOVIE_TAG} -n ${NAMESPACE} || \\
                            kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}
                            
                            # Verify deployment
                            kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=3m
                            kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=3m
                        """
                    }
                }
            }
        }
    }

    post {
        failure {
            script {
                slackSend(
                    color: 'danger',
                    message: "❌ Deployment failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                )
            }
        }
        success {
            script {
                slackSend(
                    color: 'good',
                    message: "✅ Deployment succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
                )
            }
        }
    }
}