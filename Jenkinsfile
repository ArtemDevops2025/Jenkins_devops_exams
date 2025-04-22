Here's the optimized Jenkinsfile incorporating all your requirements:

```groovy
pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        CURRENT_BRANCH = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
        NAMESPACE = sh(script: '''
            git rev-parse --abbrev-ref HEAD | grep -oE "master|dev|qa" || echo "default"
        ''', returnStdout: true).trim()
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        stage('Verify Environment') {
            steps {
                script {
                    echo "Building branch: ${CURRENT_BRANCH}"
                    echo "Deploying to namespace: ${NAMESPACE}"
                    sh 'kubectl config get-contexts'
                }
            }
        }

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

        stage('Deploy') {
            steps {
                script {
                    if (CURRENT_BRANCH == 'master') {
                        timeout(time: 5, unit: 'MINUTES') {
                            input(
                                message: "🚨 PRODUCTION Deployment to ${NAMESPACE}?",
                                ok: "Confirm",
                                submitter: "admin"
                            )
                        }
                    }

                    deployToKubernetes()
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                        sh """
                            kubectl get deployments -n ${NAMESPACE}
                            kubectl get pods -n ${NAMESPACE} -o wide
                            kubectl get svc -n ${NAMESPACE}
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo "Pipeline completed for ${CURRENT_BRANCH} → ${NAMESPACE}"
            }
        }
        success {
            script {
                slackSend(
                    color: CURRENT_BRANCH == 'master' ? 'good' : '#439FE0',
                    message: """${CURRENT_BRANCH == 'master' ? '✅ PRODUCTION' : '🚀 Development'} Deployment Success
                    *Branch*: ${CURRENT_BRANCH}
                    *Namespace*: ${NAMESPACE}
                    *Build*: ${env.BUILD_NUMBER}
                    *Details*: ${env.BUILD_URL}"""
                )
            }
        }
        failure {
            script {
                slackSend(
                    color: 'danger',
                    message: """❌ Deployment Failed
                    *Branch*: ${CURRENT_BRANCH}
                    *Namespace*: ${NAMESPACE}
                    *Build*: ${env.BUILD_NUMBER}
                    *Logs*: ${env.BUILD_URL}"""
                )
                rollbackDeployment()
            }
        }
    }
}

def deployToKubernetes() {
    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
        sh """
            kubectl create namespace ${env.NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            kubectl label namespace ${env.NAMESPACE} env=${env.NAMESPACE} --overwrite
            
            kubectl apply -f k3s/cast-db-deployment.yaml -n ${env.NAMESPACE}
            kubectl apply -f k3s/cast-db-service.yaml -n ${env.NAMESPACE}
            kubectl apply -f k3s/movie-db-deployment.yaml -n ${env.NAMESPACE}
            kubectl apply -f k3s/movie-db-service.yaml -n ${env.NAMESPACE}
            
            kubectl set image deployment/cast-deployment cast-service=${env.CAST_IMAGE} -n ${env.NAMESPACE} || \\
            kubectl apply -f k3s/cast-deployment.yaml -n ${env.NAMESPACE}
            
            kubectl set image deployment/movie-deployment movie-service=${env.MOVIE_IMAGE} -n ${env.NAMESPACE} || \\
            kubectl apply -f k3s/movie-deployment.yaml -n ${env.NAMESPACE}
            
            kubectl rollout status deployment/cast-deployment -n ${env.NAMESPACE} --timeout=3m
            kubectl rollout status deployment/movie-deployment -n ${env.NAMESPACE} --timeout=3m
        """
    }
}

def rollbackDeployment() {
    withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
        sh """
            kubectl rollout undo deployment/cast-deployment -n ${env.NAMESPACE} || true
            kubectl rollout undo deployment/movie-deployment -n ${env.NAMESPACE} || true
        """
    }
}
```