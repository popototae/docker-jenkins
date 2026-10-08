pipeline {
    agent any

    tools {
        nodejs 'Node22'
    }

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    environment {
        BUILD_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code...'
                deleteDir()
                checkout scm
                echo "Build: ${BUILD_TAG}, Commit: ${env.GIT_COMMIT}"
            }
        }

        stage('Prepare Environment') {
            steps {
                script {
                    echo 'Preparing environment configuration...'
                    withCredentials([
                        string(credentialsId: 'MYSQL_ROOT_PASSWORD', variable: 'MYSQL_ROOT_PASS'),
                        string(credentialsId: 'MYSQL_PASSWORD', variable: 'MYSQL_PASS')
                    ]) {
                        writeFile file: '.env', text: """MYSQL_ROOT_PASSWORD=${env.MYSQL_ROOT_PASS}
MYSQL_DATABASE=attractions_db
MYSQL_USER=attractions_user
MYSQL_PASSWORD=${env.MYSQL_PASS}
MYSQL_PORT=3306
API_PORT=3001
DB_PORT=3306
FRONTEND_PORT=3000
NODE_ENV=production
API_HOST_INTERNAL=http://api:3001
"""
                        sh 'chmod 600 .env'
                        echo '.env file created successfully'
                    }
                }
            }
        }

        stage('Validate') {
            steps {
                echo 'Validating Docker Compose configuration...'
                sh 'docker compose config --quiet'
            }
        }

        stage('Unit Test') {
            steps {
                echo 'Running API unit tests...'
                dir('01_api') {
                    sh 'npm ci --include=dev'
                    sh 'npm test'
                }
            }
        }

        stage('Build') {
            steps {
                echo 'Building API...'
                sh 'docker compose build --no-cache api'
            }
        }

        stage('Deploy') {
            steps {
                echo 'Deploying API using Docker Compose...'
                sh 'docker compose up -d --wait --wait-timeout 180 mysql'
                sh 'docker compose up -d --no-deps --wait --wait-timeout 180 api'
            }
        }

        stage('Health Check') {
            steps {
                echo 'Performing health check...'
                sh 'curl -4 -fsS --connect-timeout 3 --max-time 5 http://127.0.0.1:3001/health'
                sh 'curl -4 -fsS --connect-timeout 3 --max-time 5 http://127.0.0.1:3001/attractions'
            }
        }

        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployed services...'
                sh 'docker compose ps'
                sh 'docker compose logs --tail=20 api'
            }
        }
    }

    post {
        success {
            echo 'API deployment completed successfully!'
            echo "Build: ${BUILD_TAG}, Commit: ${env.GIT_COMMIT}"
        }
        failure {
            echo 'Deployment failed. Printing container logs...'
            sh 'docker compose logs --tail=50 api'
        }
    }
}
