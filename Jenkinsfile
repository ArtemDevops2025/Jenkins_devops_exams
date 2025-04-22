pipeline {
    agent any

    environment {
        // 1. Docker Hub credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        // 2. Kubernetes config
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        
        // 3. Dynamic namespace mapping
        NAMESPACE = sh(script: '''
            BRANCH=$(git rev-parse --abbrev-ref HEAD)
            case "$BRANCH" in
                "main")     echo "prod"    ;;
                "dev")      echo "dev"     ;;
                "qa")       echo "qa"      ;;
                "staging")  echo "staging" ;;
                *)          echo "default" ;;
            esac
        ''', returnStdout: true).trim()
        
        // 4. Image tags with build numbers
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        // Stage 1: Environment Verification
        stage('Verify Environment') {
            steps {
                script {
                    // Get actual branch name for logging
                    ACTUAL_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    
                    echo "========== DEPLOYMENT CONFIG =========="
                    echo "Branch:       ${ACTUAL_BRANCH}"
                    echo "Namespace:    ${NAMESPACE}"
                    echo "Is Production: ${NAMESPACE == 'prod'}"
                    
                    // Create namespace if it doesn't exist
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl label namespace ${NAMESPACE} env=${NAMESPACE} --overwrite
                    """
                }
            }
        }

        // Stage 2: Build Docker Images (parallel)
        stage('Build Images') {
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

        // Stage 3: Push Images (parallel)
        stage('Push Images') {
            parallel {
                stage('Push Movie Image') {
                    steps {
                        script {
                            docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                docker.image(MOVIE_IMAGE).push()
                            }
                        }
                    }
                }
                stage('Push Cast Image') {
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

        // Stage 4: Production Approval Gate
        stage('Production Approval') {
            when { 
                expression { return env.NAMESPACE == 'prod' }
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input(
                        message: "🚨 PRODUCTION DEPLOYMENT APPROVAL REQUIRED",
                        ok: "Deploy to Production",
                        parameters: [
                            string(
                                defaultValue: '',
                                description: 'Enter reason for production deployment',
                                name: 'DEPLOY_REASON'
                            )
                        ],
                        submitter: "admin"
                    )
                }
            }
        }

        // Stage 5: Deploy to Kubernetes
        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    script {
                        // Deploy databases
                        sh """
                            kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}
                        """
                        
                        // Deploy applications with rollout strategy
                        sh """
                            kubectl set image deployment/cast-deployment cast-service=${CAST_IMAGE} -n ${NAMESPACE} || \\
                            kubectl apply -f k3s/cast-deployment.yaml -n ${NAMESPACE}
                            
                            kubectl set image deployment/movie-deployment movie-service=${MOVIE_IMAGE} -n ${NAMESPACE} || \\
                            kubectl apply -f k3s/movie-deployment.yaml -n ${NAMESPACE}
                            
                            kubectl rollout status deployment/cast-deployment -n ${NAMESPACE} --timeout=3m
                            kubectl rollout status deployment/movie-deployment -n ${NAMESPACE} --timeout=3m
                        """
                    }
                }
            }
        }

        // Stage 6: Verification
        stage('Verify Deployment') {
            steps {
                script {
                    sh """
                        echo "========== ${NAMESPACE} STATUS =========="
                        kubectl get deployments -n ${NAMESPACE}
                        kubectl get pods -n ${NAMESPACE} -o wide
                        kubectl get svc -n ${NAMESPACE}
                    """
                }
            }
        }
    }

    post {
        always {
            script {
                ACTUAL_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                echo "Pipeline completed for ${ACTUAL_BRANCH} → ${NAMESPACE}"
            }
        }
        success {
            script {
                echo "✅ Successfully deployed to ${NAMESPACE} namespace"
                // Add other notifications here (Slack, email, etc.)
            }
        }
        failure {
            script {
                echo "❌ Deployment failed to ${NAMESPACE} namespace"
                // Add failure notifications here
            }
        }
    }
}