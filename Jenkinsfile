pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'art2025/jenkins-exam'
        KUBECONFIG = '/etc/rancher/k3s/k3s.yaml'
    }

    stages {
        stage('Build and Push Movie Image') {
            steps {
                script {
                    def movieImage = docker.build("${DOCKER_REGISTRY}:movie-${BUILD_NUMBER}", "movie-service")
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        movieImage.push()
                    }
                }
            }
        }

        stage('Build and Push Cast Image') {
            steps {
                script {
                    def castImage = docker.build("${DOCKER_REGISTRY}:cast-${BUILD_NUMBER}", "cast-service")
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub-credentials') {
                        castImage.push()
                    }
                }
            }
        }

        stage('Deploy to K3s') {
            steps {
                script {
                    withEnv(["KUBECONFIG=${KUBECONFIG}"]) {
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
