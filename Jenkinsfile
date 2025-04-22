pipeline {
    agent any

    environment {
        // 1. Dynamic Namespace based on the Git branch
        NAMESPACE = "${env.BRANCH_NAME == 'main' ? 'prod' : 
                    env.BRANCH_NAME == 'dev' ? 'dev' : 
                    env.BRANCH_NAME == 'qa' ? 'qa' : 
                    'movie-app'}"

        // 2. Dynamic Image Tags
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
        
        // 3. Default Kube Context and Registry Information
        KUBE_CONTEXT = "default"  // Matches your current context
        DOCKER_HUB_REGISTRY = 'docker.io'
        DOCKER_IMAGE_NAME = 'art2025/jenkins-exam'
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
                                sh "docker build -t ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE} ."
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                sh "docker build -t ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${CAST_IMAGE} ."
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
                            docker.withRegistry('https://docker.io', 'dockerhub') {
                                sh "docker tag ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE} ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE}"
                                sh "docker push ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${MOVIE_IMAGE}"
                            }
                        }
                    }
                }
                stage('Push Cast Service') {
                    steps {
                        script {
                            docker.withRegistry('https://docker.io', 'dockerhub') {
                                sh "docker tag ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${CAST_IMAGE} ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${CAST_IMAGE}"
                                sh "docker push ${DOCKER_HUB_REGISTRY}/${DOCKER_IMAGE_NAME}:${CAST_IMAGE}"
                            }
                        }
                    }
                }
            }
        }

        // Stage 4: Deploy Pre-Prod
        stage('Deploy Pre-Prod') {
            when {
                expression { return params.DEPLOY_PREPROD }
            }
            steps {
                script {
                    withEnv(["KUBECONFIG=${KUBE_CONFIG}"]) {
                        sh '''
                            kubectl apply -f k3s/cast-db-deployment.yaml
                            kubectl apply -f k3s/cast-db-service.yaml
                            kubectl apply -f k3s/cast-deployment.yaml
                            kubectl apply -f k3s/cast-service.yaml

                            kubectl apply -f k3s/movie-db-deployment.yaml
                            kubectl apply -f k3s/movie-db-service.yaml
                            kubectl apply -f k3s/movie-deployment.yaml
                            kubectl apply -f k3s/movie-service.yaml

                            kubectl apply -f k3s/ingress.yaml
                        '''
                    }
                }
            }
        }

        // Stage 5: Deploy Prod
        stage('Deploy Prod') {
            when {
                expression { return params.DEPLOY_PROD }
            }
            steps {
                script {
                    withEnv(["KUBECONFIG=${KUBE_CONFIG}"]) {
                        sh '''
                            kubectl apply -f k3s/cast-db-deployment.yaml
                            kubectl apply -f k3s/cast-db-service.yaml
                            kubectl apply -f k3s/cast-deployment.yaml
                            kubectl apply -f k3s/cast-service.yaml

                            kubectl apply -f k3s/movie-db-deployment.yaml
                            kubectl apply -f k3s/movie-db-service.yaml
                            kubectl apply -f k3s/movie-deployment.yaml
                            kubectl apply -f k3s/movie-service.yaml

                            kubectl apply -f k3s/ingress.yaml
                        '''
                    }
                }
            }
        }
    }
}
