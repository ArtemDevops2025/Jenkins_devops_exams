pipeline {
    agent any

    environment {
        // 1. Credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        
        // 2. Kubernetes Configuration
        KUBE_CONTEXT = "default"  // Matches your current context
        IS_PROD = "${env.BRANCH_NAME == 'main'}"
        
        // 3. Dynamic Namespace (matches your existing namespaces)
        NAMESPACE = "${env.BRANCH_NAME == 'main' ? 'prod' : 
                    env.BRANCH_NAME == 'dev' ? 'dev' : 
                    env.BRANCH_NAME == 'qa' ? 'qa' : 
                    'movie-app'}"
        
        // 4. Image Tags
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        // Stage 1: Verify Environment
        stage('Verify Setup') {
            steps {
                script {
                    echo "========== ENVIRONMENT =========="
                    echo "BRANCH: ${env.BRANCH_NAME}"
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

        // Stage 4: Production Approval
        stage('Production Approval') {
            when { 
                branch 'main' 
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input(
                        message: "🚀 PRODUCTION DEPLOYMENT APPROVAL\n" +
                                "Build: #${env.BUILD_NUMBER}\n" +
                                "Images: ${MOVIE_IMAGE}, ${CAST_IMAGE}",
                        ok: "Deploy",
                        submitter: "admin"
                    )
                }
            }
        }

        // Stage 5: Deploy
        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    script {
                        sh """
                            kubectl config use-context ${KUBE_CONTEXT}
                            
                            # Create namespace if not exists
                            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            
                            # Label namespace
                            kubectl label namespace ${NAMESPACE} \
                                environment=${IS_PROD ? 'production' : 'development'} \
                                branch=${env.BRANCH_NAME} \
                                --overwrite
                            
                            # Deploy databases
                            kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}
                            
                            # Deploy services
                            kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${NAMESPACE} || \
                            kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}
                            
                            kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${NAMESPACE} || \
                            kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}
                            
                            # Verify
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
            slackSend(
                color: 'danger',
                message: "❌ DEPLOYMENT FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                         "Branch: ${env.BRANCH_NAME}\n" +
                         "More: ${env.BUILD_URL}"
            )
        }
        success {
            slackSend(
                color: 'good',
                message: "✅ DEPLOYMENT SUCCESS: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                         "Namespace: ${NAMESPACE}\n" +
                         "Images: ${MOVIE_IMAGE}, ${CAST_IMAGE}\n" +
                         "Details: ${env.BUILD_URL}"
            )
        }
    }
}