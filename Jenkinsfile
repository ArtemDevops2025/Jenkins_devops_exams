pipeline {
    agent any

    options {
        skipDefaultCheckout true
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
    }

    stages {
        stage('Checkout and Initialize') {
            steps {
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/dev']],  // Explicitly check out the dev branch
                    extensions: [],
                    userRemoteConfigs: [[url: 'https://github.com/ArtemDevops2025/jenkins_devops_exams']]
                ])
                
                script {
                    // Get branch name reliably
                    BRANCH_NAME = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    
                    // Force namespace mapping
                    NAMESPACE = "dev"  // Hardcoded for dev branch
                    
                    // Set image tags
                    MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
                    CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
                    
                    echo "========== DEPLOYMENT CONFIG =========="
                    echo "Branch:       ${BRANCH_NAME}"
                    echo "Namespace:    ${NAMESPACE}"
                    echo "Is Production: ${NAMESPACE == 'prod'}"
                }
            }
        }

        stage('Verify Environment') {
            steps {
                script {
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl label namespace ${NAMESPACE} env=${NAMESPACE} --overwrite
                    """
                }
            }
        }

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

        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    script {
                        sh """
                            kubectl apply -f k3s/cast-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/cast-db-service.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-deployment.yaml -n ${NAMESPACE}
                            kubectl apply -f k3s/movie-db-service.yaml -n ${NAMESPACE}
                            
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
                echo "Pipeline completed for ${BRANCH_NAME} → ${NAMESPACE}"
            }
        }
        success {
            script {
                echo "✅ Successfully deployed to ${NAMESPACE} namespace"
            }
        }
        failure {
            script {
                echo "❌ Deployment failed to ${NAMESPACE} namespace"
            }
        }
    }
}