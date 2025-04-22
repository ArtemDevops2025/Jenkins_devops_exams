pipeline {
    agent any

    environment {
        // 1. Credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        
        // 2. Dynamic namespace detection
        NAMESPACE = sh(script: '''
            git rev-parse --abbrev-ref HEAD | grep -oE "dev|qa|main" || echo "movie-app"
        ''', returnStdout: true).trim()
        
        // 3. Image tags
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
        
        // 4. Kubernetes config
        KUBE_CONTEXT = "default"
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
                    echo "KUBE_CONTEXT: ${KUBE_CONTEXT}"
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

        // Stage 3: Push Images
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

        // Stage 4: Deploy to Environment
        stage('Deploy') {
            steps {
                script {
                    // Create namespace if needed
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            kubectl config use-context ${KUBE_CONTEXT}
                            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            kubectl label namespace ${NAMESPACE} \
                                environment=${NAMESPACE == 'prod' ? 'production' : 'development'} \
                                branch=${env.BRANCH_NAME} \
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

        // Stage 5: Verify Deployment
        stage('Verify') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh """
                        kubectl config use-context ${KUBE_CONTEXT}
                        echo "========== DEPLOYMENT STATUS =========="
                        kubectl get deployments -n ${NAMESPACE}
                        echo "\n========== PODS =========="
                        kubectl get pods -n ${NAMESPACE}
                        echo "\n========== SERVICES =========="
                        kubectl get svc -n ${NAMESPACE}
                    """
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
            kubectl config use-context ${KUBE_CONTEXT}
            
            # Deploy databases
            kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
            kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
            kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
            kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}
            
            # Deploy services
            kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${NAMESPACE} || \\
            kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}
            
            kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${NAMESPACE} || \\
            kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}
            
            # Verify rollout
            kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=3m
            kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=3m
        """
    }
}