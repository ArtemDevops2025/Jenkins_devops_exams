pipeline {
    agent any

    environment {
        // 1. Dynamic Namespace based on the Git branch
        NAMESPACE = sh(script: '''
            git rev-parse --abbrev-ref HEAD | grep -oE "main|dev|qa" || echo "movie-app"
        ''', returnStdout: true).trim()

        // 2. Dynamic Image Tags
        MOVIE_TAG = "movie-${env.BUILD_NUMBER}"
        CAST_TAG = "cast-${env.BUILD_NUMBER}"
        
        // 3. Registry Information
        DOCKER_REGISTRY = 'index.docker.io'
        DOCKER_REPO = 'art2025/jenkins-exam'
    }

    parameters {
        booleanParam(name: 'DEPLOY_PREPROD', defaultValue: false, description: 'Deploy to pre-production environment')
        booleanParam(name: 'DEPLOY_PROD', defaultValue: false, description: 'Deploy to production environment')
    }

    stages {
        // Stage 1: Verify Environment
        stage('Verify Setup') {
            steps {
                script {
                    echo "========== ENVIRONMENT =========="
                    echo "BRANCH: ${env.BRANCH_NAME}"
                    echo "GIT BRANCH: ${sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()}"
                    echo "NAMESPACE: ${NAMESPACE}"
                    sh 'kubectl config get-contexts'
                }
            }
        }

        // Stage 2: Build Docker Images
        stage('Build') {
            parallel {
                stage('Build Movie Service') {
                    steps {
                        dir('movie-service') {
                            script {
                                docker.build("${DOCKER_REPO}:${MOVIE_TAG}")
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                docker.build("${DOCKER_REPO}:${CAST_TAG}")
                            }
                        }
                    }
                }
            }
        }

        // Stage 3: Push Images
        stage('Push') {
            parallel {
                stage('Push Movie Service') {
                    steps {
                        script {
                            docker.withRegistry("https://${DOCKER_REGISTRY}", 'dockerhub') {
                                docker.image("${DOCKER_REPO}:${MOVIE_TAG}").push()
                            }
                        }
                    }
                }
                stage('Push Cast Service') {
                    steps {
                        script {
                            docker.withRegistry("https://${DOCKER_REGISTRY}", 'dockerhub') {
                                docker.image("${DOCKER_REPO}:${CAST_TAG}").push()
                            }
                        }
                    }
                }
            }
        }

        // Stage 4: Deploy to Environment
        stage('Deploy') {
            steps {
                script {
                    // Create namespace if needed
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            kubectl label namespace ${NAMESPACE} \
                                environment=${NAMESPACE == 'prod' ? 'production' : 'development'} \
                                --overwrite
                        """
                    }

                    // Handle production approval
                    if (NAMESPACE == 'prod') {
                        timeout(time: 5, unit: 'MINUTES') {
                            input(
                                message: "🚀 PRODUCTION DEPLOYMENT APPROVAL\n" +
                                        "Build: #${env.BUILD_NUMBER}\n" +
                                        "Namespace: ${NAMESPACE}",
                                ok: "Deploy",
                                submitter: "admin"
                            )
                        }
                    }

                    // Execute deployment
                    deployToNamespace()
                }
            }
        }
    }

    post {
        always {
            script {
                echo "========== BUILD FINISHED =========="
                echo "Status: ${currentBuild.currentResult}"
                echo "Namespace: ${NAMESPACE}"
                echo "Build URL: ${env.BUILD_URL}"
            }
        }
        success {
            script {
                slackSend(
                    color: 'good',
                    message: """✅ ${NAMESPACE == 'prod' ? 'PRODUCTION' : 'Development'} DEPLOYMENT SUCCESS
                    *Application*: ${env.JOB_NAME}
                    *Environment*: ${NAMESPACE}
                    *Version*: #${env.BUILD_NUMBER}
                    *Details*: ${env.BUILD_URL}"""
                )
            }
        }
        failure {
            script {
                slackSend(
                    color: 'danger',
                    message: """❌ DEPLOYMENT FAILED
                    *Pipeline*: ${env.JOB_NAME}
                    *Environment*: ${NAMESPACE}
                    *Build*: #${env.BUILD_NUMBER}
                    *Logs*: ${env.BUILD_URL}"""
                )
                
                // Automatic rollback
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl rollout undo deployment/cast-deployment -n ${NAMESPACE} || true
                        kubectl rollout undo deployment/movie-deployment -n ${NAMESPACE} || true
                    """
                }
            }
        }
    }
}

// Deployment helper method
def deployToNamespace() {
    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
        sh """
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
            
            # Apply services and ingress
            kubectl apply -f k3s/cast-service.yaml -n ${NAMESPACE}
            kubectl apply -f k3s/movie-service.yaml -n ${NAMESPACE}
            kubectl apply -f k3s/ingress.yaml -n ${NAMESPACE}
            
            # Verify rollout
            kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=3m
            kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=3m
        """
    }
}