pipeline {
    agent any

    environment {
        // 1. Credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        
        // 2. Dynamic Namespace Mapping (dev/qa/staging/prod)
        NAMESPACE = sh(script: '''
            case $(git rev-parse --abbrev-ref HEAD) in
                main)      echo "prod";;
                dev)       echo "dev";;
                qa)        echo "qa";;
                staging)   echo "staging";;
                *)         echo "default";;
            esac
        ''', returnStdout: true).trim()
        
        // 3. Image Tags
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        // Stage 1: Environment Verification
        stage('Verify Environment') {
            steps {
                script {
                    echo "========== DEPLOYMENT CONFIG =========="
                    echo "Branch:       ${env.BRANCH_NAME}"
                    echo "Namespace:    ${NAMESPACE}"
                    echo "Is Production: ${NAMESPACE == 'prod'}"
                    
                    // Verify namespace exists
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl label namespace ${NAMESPACE} env=${NAMESPACE} --overwrite
                    """
                }
            }
        }

        // Stage 2: Build Docker Images
        stage('Build Images') {
            parallel {
                stage('Build Movie') {
                    steps {
                        dir('movie-service') {
                            script {
                                docker.build(MOVIE_IMAGE)
                            }
                        }
                    }
                }
                stage('Build Cast') {
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
        stage('Push Images') {
            parallel {
                stage('Push Movie') {
                    steps {
                        script {
                            docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                docker.image(MOVIE_IMAGE).push()
                            }
                        }
                    }
                }
                stage('Push Cast') {
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
                        message: "🚨 PRODUCTION DEPLOYMENT TO ${NAMESPACE}",
                        ok: "Confirm",
                        parameters: [
                            string(
                                defaultValue: '',
                                description: 'Enter deployment reason',
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
                echo "Pipeline completed for ${env.BRANCH_NAME} → ${NAMESPACE}"
            }
        }
        success {
            script {
                echo "✅ Successfully deployed to ${NAMESPACE}"
                // Add other notifications here (email, etc.)
            }
        }
        failure {
            script {
                echo "❌ Deployment failed to ${NAMESPACE}"
                // Add failure notifications here
            }
        }
    }
}