pipeline {
    environment { // Declaration of environment variables
    DOCKER_ID = "ykadi" // replace this with your docker-id
    DOCKER_IMAGE_CAST = "cast-service"
    DOCKER_IMAGE_MOVIE = "movie-service"
    DOCKER_TAG = "v.${BUILD_ID}.0" // we will tag our images with the current build in order to increment the value by 1 with each new build
    KUBECONFIG = credentials("config") // we retrieve  kubeconfig from secret file called config saved on jenkins
    DOCKER_PASS = credentials("DOCKER_HUB_PASS")
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
    AWS_DEFAULT_REGION = "eu-west-3"
}

agent any 
    stages { 
        stage('Cleanup docker containers and images') {
            steps {
                script {   
                 
                        sh'''    
                         echo $(docker ps -q)
                         if [[ $(docker ps -q) ]]; then
                            echo "Running containers found. Cleaning up..."
                            docker stop $(docker ps -aq)
                            docker rm $(docker ps -aq)
                            docker rmi -f $(docker images -q)
                        else
                            echo "No running containers found."
                        fi  
                        '''
                }
            }
        }

        // Build docker image
        stage('Docker image build') {
            steps {
                script {
                     
                        // sh 'cd local-test'
                        sh 'pwd'
                        sh 'docker compose build'
                        sh 'sleep 6'
                    
                }
            }
        }
        // Run the docker image
        stage('Docker image up') {
                steps {
                script {
                        sh 'docker compose up -d'
                        // sh ' cd .. '
                        sh 'sleep 10'
                        
                }
            }
        }
        
      stage('Image test') {
            steps {
                script {

                    sh 'curl  http://localhost:8082/api/v1/movies/docs'
                    sh 'curl  http://localhost:8082/api/v1/casts/docs'
                }                           
            }
        } 

        stage('Build and tag docker image for dockerhub') {
            steps {
                script {
                sh '''
                docker build -t $DOCKER_ID/$DOCKER_IMAGE_CAST:$DOCKER_TAG cast-service/
                sleep 5
                docker build -t $DOCKER_ID/$DOCKER_IMAGE_MOVIE:$DOCKER_TAG movie-service/
                sleep 5
                '''
                }
            }
        }
        
        // Push the docker image built on dockerhub
        stage('Docker Push') { 
            steps {
                script {
                sh '''
                docker login -u $DOCKER_ID -p $DOCKER_PASS
                docker push $DOCKER_ID/$DOCKER_IMAGE_CAST:$DOCKER_TAG
                docker push $DOCKER_ID/$DOCKER_IMAGE_MOVIE:$DOCKER_TAG

                '''
                }
            }
        }

        stage('Deployement test') {
            steps {
                script {
                    sh '''
                    echo "Installation Projet Jenkins 2023"
                    sed -i "s+tag.*+tag: ${DOCKER_TAG}+g" my_app/values.yaml
                    helm upgrade --install my-app-v1 my_app/ --values my_app/values.yaml -n movie-app --create-namespace   
                    sleep 10
                    '''
                }                           
            }
        } 



    //     stage('Dev deployment') {
    //         steps {
    //             script {
    //                 sh '''
    //                 echo "Installation Ingress-controller Nginx"
    //                 helm upgrade --install ingress-nginx ingress-nginx \
    //                 --repo https://kubernetes.github.io/ingress-nginx \
    //                 --namespace ingress-nginx --create-namespace     
    //                 sleep 10

    //                 echo "Installation Cert-Manager"
    //                 helm upgrade --install cert-manager cert-manager \
    //                 --repo https://charts.jetstack.io \
    //                 --create-namespace --namespace cert-manager \
    //                 --set installCRDs=true
    //                 sleep 10
                    
    //                 echo "Installation stack Prometheus-Grafana"
    //                 helm upgrade --install kube-prometheus-stack kube-prometheus-stack \
    //                 --namespace kube-prometheus-stack --create-namespace \
    //                 --repo https://prometheus-community.github.io/helm-charts


    //                 echo "Installation Projet Devops 2023"
    //                 sed -i "s+tag.*+tag: ${DOCKER_TAG}+g" myapp1/values.yaml
    //                 helm upgrade --install myapp-release-dev myapp1/ --values myapp1/values.yaml -f myapp1/values-dev.yaml -n dev --create-namespace
    //                 kubectl apply -f myapp1/clusterissuer-prod.yaml    
    //                 sleep 10
    //                 '''
    //             }
    //         }           
    //     }

    //     stage('Staging deployment') {
    //         steps {
    //             script {
    //                 sh '''
    //                 curl -k -i -X  'POST' -H 'Content-Type: application/json' -d '{"id": 1, "name": "toto", "email": "toto@email.com","password": "passwordtoto"}' https://www.devops-youss.cloudns.ph
    //                 if curl -k -i -H 'accept: application/json' https://www.devops-youss.cloudns.ph/users | grep -qF "toto"; then
    //                     echo "La chaîne 'toto' a été trouvée dans la réponse."
    //                 else
    //                     echo "La chaîne 'toto' n'a pas été trouvée dans la réponse."
    //                 fi'''
                    
    //             }
    //         }
    //     }
        
    //     stage('Production deployment') {
    //         steps {
    //             // Create an Approval Button with a timeout of 15minutes.
    //             // this require a manuel validation in order to deploy on production environment
    //             timeout(time: 15, unit: "MINUTES") {
    //                 input message: 'Do you want to deploy in production ?', ok: 'Yes'
    //             }
    //             script {
    //                 sh '''
    //                 sed -i "s+tag.*+tag: ${DOCKER_TAG}+g" myapp1/values.yaml     
    //                 helm upgrade --install myapp-release-prod myapp1/ --values myapp1/values.yaml -f myapp1/values-prod.yaml -n prod --create-namespace
    //                 kubectl apply -f myapp1/ingress-grafana.yaml
    //                 kubectl apply -f myapp1/clusterissuer-prod.yaml
    //                 '''
    //             }
    //         }
    //     }

        
    // }
    
    //  post {
    //      success {
    //          script {
    //              slackSend botUser: true, color: 'good', message: "Successful :jenkins-${JOB_NAME}-${BUILD_ID}", teamDomain: 'DEVOPS TEAM', tokenCredentialId: 'slack-bot-token'
    //          }
    //      }
        
    //     failure {
    //          script {
    //              slackSend botUser: true, color: 'danger', message: "Failure :jenkins-${JOB_NAME}-${BUILD_ID}", teamDomain: 'DEVOPS TEAM', tokenCredentialId: 'slack-bot-token'
    //        }
    //     }
    //     // ..
        
    //     failure {
    //         echo "This will run if the job failed"
    //         mail to: "youssef.kadi@gmail.com",
    //             subject: "${env.JOB_NAME} - Build # ${env.BUILD_ID} has failed",
    //             body: "For more info on the pipeline failure, check out the console output at ${env.BUILD_URL}"
    //     }
        
    //     // ..
    // }
}
}
