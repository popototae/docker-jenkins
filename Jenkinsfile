pipeline {
    agent any

    tools {
        nodejs 'Node22'
    }

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    environment {
        COMPOSE_PROJECT_NAME = 'docker-jenkins-pipeline'
        DEPLOY_ENV_FILE = '/var/lib/jenkins/docker-jenkins.env'
        API_URL = 'http://127.0.0.1:3001'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Clean this job workspace and checkout code'
                deleteDir()
                checkout scm
            }
        }

        stage('Prepare Environment') {
            steps {
                echo 'Validate Compose using the shared environment file'
                sh 'docker compose --env-file "$DEPLOY_ENV_FILE" config --quiet'
            }
        }

        stage('Install API Dependencies') {
            steps {
                dir('01_api') {
                    sh 'npm ci --include=dev'
                }
            }
        }

        stage('Test API') {
            steps {
                dir('01_api') {
                    sh 'npm test'
                }
            }
        }

        stage('Build API') {
            steps {
                echo 'Build the API Docker image'
                sh 'docker compose --env-file "$DEPLOY_ENV_FILE" build api'
            }
        }

        stage('Start MySQL') {
            steps {
                echo 'Start MySQL and wait for it to become healthy'
                sh 'docker compose --env-file "$DEPLOY_ENV_FILE" up -d --wait --wait-timeout 180 mysql'
            }
        }

        stage('Deploy API') {
            steps {
                echo 'Update only the API container'
                sh 'docker compose --env-file "$DEPLOY_ENV_FILE" up -d --no-deps --wait --wait-timeout 180 api'
            }
        }

        stage('Check API') {
            steps {
                echo 'Check API health and attractions endpoints'
                sh 'curl -4 -fsS --connect-timeout 3 --max-time 5 "$API_URL/health"'
                sh 'curl -4 -fsS --connect-timeout 3 --max-time 5 "$API_URL/attractions"'
            }
        }
    }

    post {
        success {
            echo 'API deployment passed'
        }
        failure {
            echo 'Show MySQL and API logs'
            sh 'docker compose --env-file "$DEPLOY_ENV_FILE" logs --tail=50 mysql api'
        }
    }
}
