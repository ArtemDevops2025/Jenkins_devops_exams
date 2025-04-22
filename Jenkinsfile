pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        NAMESPACE = sh(script: 'git rev-parse --abbrev-ref HEAD | grep -oE "dev|qa|main" || echo "movie-app"', returnStdout: true).trim()
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
        KUBE_CONTEXT = "default"
    }

    stages {
        stage('Verify Setup') {
            steps {
                script {
                    echo "BRANCH: ${env.BRANCH_NAME}"
                    echo "GIT BRANCH: ${sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()}"
                    echo "NAMESPACE: ${NAMESPACE}"
                    echo "KUBE_CONTEXT: ${KUBE_CONTEXT}"
                    sh 'kubectl config get-contexts'
                }
            }
        }

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

        stage('Deploy Pre-Prod') {
            when {
                branch 'dev'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh "kubectl --context=${KUBE_CONTEXT} apply -n ${NAMESPACE} -f k8s/"
                }
            }
        }

        stage('Deploy Prod') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    sh "kubectl --context=${KUBE_CONTEXT} apply -n ${NAMESPACE} -f k8s/"
                }
            }
        }
    }
}
