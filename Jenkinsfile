pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    triggers {
        pollSCM('H/2 * * * *')
    }

    parameters {
        booleanParam(
            name: 'FORCE_BUILD_ALL',
            defaultValue: false,
            description: 'Force rebuild both API and Frontend regardless of changes'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Deploying commit ${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Unit Test') {
            parallel {
                stage('Test API') {
                    steps {
                        sh 'sh scripts/test-service.sh 01_api'
                    }
                }
                stage('Test Frontend') {
                    steps {
                        sh 'sh scripts/test-service.sh 02_frontend'
                    }
                }
            }
        }

        stage('Prepare Environment & Detect Changes') {
            steps {
                withCredentials([
                    string(credentialsId: 'MYSQL_ROOT_PASSWORD', variable: 'MYSQL_ROOT_PASS'),
                    string(credentialsId: 'MYSQL_PASSWORD', variable: 'MYSQL_PASS')
                ]) {
                    sh 'sh scripts/prepare-environment.sh'
                }
                sh 'docker compose config --quiet'
                script {
                    def selected = sh(
                        returnStdout: true,
                        script: "sh scripts/select-builds.sh ${params.FORCE_BUILD_ALL ? 'true' : 'false'}"
                    ).trim().split('\n').collectEntries { line ->
                        def pair = line.split('=', 2)
                        [(pair[0]): pair[1]]
                    }
                    env.BUILD_API = selected.BUILD_API
                    env.BUILD_FRONTEND = selected.BUILD_FRONTEND
                    echo "Build API: ${env.BUILD_API}; Build Frontend: ${env.BUILD_FRONTEND}"
                }
            }
        }

        stage('Build Services') {
            steps {
                sh 'sh scripts/build-services.sh "$BUILD_API" "$BUILD_FRONTEND"'
            }
        }

        stage('Deploy & Health Check') {
            steps {
                sh 'sh scripts/deploy-stack.sh'
            }
        }
    }

    post {
        success {
            echo "Deployment checks passed for commit ${env.GIT_COMMIT_SHORT}"
            echo 'Frontend: http://localhost:3000; API: http://localhost:3001'
        }
        failure {
            sh 'docker compose logs --tail=50 frontend api || true'
        }
    }
}
