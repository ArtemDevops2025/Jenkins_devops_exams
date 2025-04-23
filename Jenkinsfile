pipeline {
    agent any

    options {
        timeout(time: 30, unit: 'MINUTES')
        skipStagesAfterUnstable()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
    }

    stages {
        stage('Checkout and Initialize') {
            steps {
                script {
                    try {
                        // Get branch name reliably
                        def BRANCH_NAME = env.GIT_BRANCH ? env.GIT_BRANCH.replace('origin/', '') : sh(
                            script: 'git rev-parse --abbrev-ref HEAD', 
                            returnStdout: true
                        ).trim()

                        // Set namespace based on branch
                        env.NAMESPACE = BRANCH_NAME.toLowerCase() == 'main' ? 'prod' : 
                                       BRANCH_NAME.toLowerCase() == 'dev' ? 'dev' :
                                       BRANCH_NAME.toLowerCase() == 'qa' ? 'qa' :
                                       BRANCH_NAME.toLowerCase() == 'staging' ? 'staging' : 
                                       'default'

                        // Validate namespace
                        if (!['dev','qa','staging','prod','default'].contains(env.NAMESPACE)) {
                            error("Invalid namespace derived: ${env.NAMESPACE}")
                        }

                        // Set image tags with branch and build number
                        env.MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.NAMESPACE}-${env.BUILD_NUMBER}"
                        env.CAST_IMAGE = "art2025/jenkins-exam:cast-${env.NAMESPACE}-${env.BUILD_NUMBER}"

                        echo "========== DEPLOYMENT CONFIG =========="
                        echo "Branch:       ${BRANCH_NAME}"
                        echo "Namespace:    ${env.NAMESPACE}"
                        echo "Is Production: ${env.NAMESPACE == 'prod'}"
                        echo "Movie Image:  ${env.MOVIE_IMAGE}"
                        echo "Cast Image:   ${env.CAST_IMAGE}"

                    } catch (Exception e) {
                        error("Initialization failed: ${e.toString()}")
                    }
                }
            }
        }

        stage('Verify Environment') {
            steps {
                script {
                    try {
                        sh """
                            kubectl create namespace ${env.NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                            kubectl label namespace ${env.NAMESPACE} env=${env.NAMESPACE} --overwrite
                            kubectl config get-contexts
                        """
                    } catch (Exception e) {
                        error("Environment verification failed: ${e.toString()}")
                    }
                }
            }
        }

        stage('Build Images') {
            parallel {
                stage('Build Movie Service') {
                    steps {
                        dir('movie-service') {
                            script {
                                try {
                                    docker.build(env.MOVIE_IMAGE)
                                } catch (Exception e) {
                                    error("Movie service build failed: ${e.toString()}")
                                }
                            }
                        }
                    }
                }
                stage('Build Cast Service') {
                    steps {
                        dir('cast-service') {
                            script {
                                try {
                                    docker.build(env.CAST_IMAGE)
                                } catch (Exception e) {
                                    error("Cast service build failed: ${e.toString()}")
                                }
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
                            try {
                                docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                    docker.image(env.MOVIE_IMAGE).push()
                                }
                            } catch (Exception e) {
                                error("Movie image push failed: ${e.toString()}")
                            }
                        }
                    }
                }
                stage('Push Cast Image') {
                    steps {
                        script {
                            try {
                                docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
                                    docker.image(env.CAST_IMAGE).push()
                                }
                            } catch (Exception e) {
                                error("Cast image push failed: ${e.toString()}")
                            }
                        }
                    }
                }
            }
        }

        stage('Production Approval') {
            when { 
                expression { return env.NAMESPACE == 'prod' }
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input(
                        message: "PRODUCTION DEPLOYMENT APPROVAL REQUIRED",
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

        stage('Deploy') {
            steps {
                withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                    script {
                        try {
                            sh """
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
                        } catch (Exception e) {
                            error("Deployment failed: ${e.toString()}")
                        }
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    try {
                        sh """
                            echo "========== ${env.NAMESPACE} STATUS =========="
                            kubectl get deployments -n ${env.NAMESPACE}
                            kubectl get pods -n ${env.NAMESPACE} -o wide
                            kubectl get svc -n ${env.NAMESPACE}
                        """
                    } catch (Exception e) {
                        error("Verification failed: ${e.toString()}")
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                echo "Pipeline completed for ${env.NAMESPACE} namespace"
                cleanWs()
            }
        }
        success {
            script {
                echo "Successfully deployed to ${env.NAMESPACE} namespace"
            }
        }
        failure {
            script {
                echo " Pipeline failed in ${env.NAMESPACE} namespace"
                
            }
        }
    }
}