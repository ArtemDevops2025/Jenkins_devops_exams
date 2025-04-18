pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        NAMESPACE = "${env.BRANCH_NAME == 'master' ? 'prod' : env.BRANCH_NAME}"
    }

    stages {
        stage('Build') {
            parallel {
                stage('Build Movie Service') {
                    steps {
                        dir('movie-service') {
                            script {
                                docker.build("art2025/jenkins-exam-movie:${env.BUILD_NUMBER}")
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                docker.build("art2025/jenkins-exam-cast:${env.BUILD_NUMBER}")
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
                                docker.image("art2025/jenkins-exam-movie:${env.BUILD_NUMBER}").push()
                            }
                        }
                    }
                }
                stage('Push Cast Service') {
                    steps {
                        script {
                            docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                docker.image("art2025/jenkins-exam-cast:${env.BUILD_NUMBER}").push()
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                anyOf {
                    branch 'dev'
                    branch 'qa'
                    branch 'master'
                }
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    // Create namespace if not exists
                    sh "kubectl create namespace ${env.NAMESPACE} || true"
                    
                    // Deploy databases
                    sh "kubectl apply -f k3s/cast-db-deployment.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/cast-db-service.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/movie-db-deployment.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/movie-db-service.yaml -n ${env.NAMESPACE}"
                    
                    // Update image tags in deployment
                    sh "sed -i 's|\\${IMAGE_TAG}|${env.BUILD_NUMBER}|g' k3s/cast-deployment.yaml"
                    sh "sed -i 's|\\${IMAGE_TAG}|${env.BUILD_NUMBER}|g' k3s/movie-deployment.yaml"
                    
                    // Deploy services
                    sh "kubectl apply -f k3s/cast-deployment.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/cast-service.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/movie-deployment.yaml -n ${env.NAMESPACE}"
                    sh "kubectl apply -f k3s/movie-service.yaml -n ${env.NAMESPACE}"
                }
            }
        }
    }
}