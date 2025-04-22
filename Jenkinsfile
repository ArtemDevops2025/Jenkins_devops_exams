pipeline {
    agent any

    environment {
        DOCKERHUB_CREDENTIALS = credentials('dockerhub')
        KUBECONFIG_CREDENTIALS = credentials('kubeconfig')
        
        // Fixed namespace detection
        NAMESPACE = sh(script: '''
            BRANCH=$(git rev-parse --abbrev-ref HEAD)
            case $BRANCH in
                main)      echo "prod";;
                dev)       echo "dev";;
                qa)        echo "qa";;
                staging)   echo "staging";;
                *)         echo "default";;
            esac
        ''', returnStdout: true).trim()
        
        MOVIE_IMAGE = "art2025/jenkins-exam:movie-${env.BUILD_NUMBER}"
        CAST_IMAGE = "art2025/jenkins-exam:cast-${env.BUILD_NUMBER}"
    }

    stages {
        stage('Verify Environment') {
            steps {
                script {
                    echo "========== DEPLOYMENT CONFIG =========="
                    echo "Branch:       ${env.BRANCH_NAME}"
                    echo "Namespace:    ${NAMESPACE}"
                    echo "Is Production: ${NAMESPACE == 'prod'}"
                    
                    sh """
                        kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
                        kubectl label namespace ${NAMESPACE} env=${NAMESPACE} --overwrite
                    """
                }
            }
        }

        // Rest of your pipeline stages remain the same...
        stage('Build Images') { ... }
        stage('Push Images') { ... }
        
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

        stage('Deploy') { ... }
        stage('Verify Deployment') { ... }
    }

    post {
        always {
            echo "Pipeline completed for ${env.BRANCH_NAME} → ${NAMESPACE}"
        }
        success {
            echo "✅ Successfully deployed to ${NAMESPACE}"
        }
        failure {
            echo "❌ Deployment failed to ${NAMESPACE}"
        }
    }
}