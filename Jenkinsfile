pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
    }

    stages {
        stage('Build') {
            steps {
                script {
                    docker.build("art2025/jenkins-exam:${env.BRANCH_NAME}")
                }
            }
        }

        stage('Push') {
            steps {
                script {
                    docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                        docker.image("art2025/jenkins-exam:${env.BRANCH_NAME}").push()
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'master'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh 'kubectl apply -f manifests/movie-service/deployment.yaml'
                    sh 'kubectl apply -f manifests/movie-service/service.yaml'
                    sh 'kubectl apply -f manifests/cast-service/deployment.yaml'
                    sh 'kubectl apply -f manifests/cast-service/service.yaml'
                }
            }
        }
    }
}
