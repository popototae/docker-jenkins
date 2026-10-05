pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout(true)
    }

    triggers {
        // Poll SCM as fallback if webhook fails
        pollSCM('H/2 * * * *')
    }

    environment {
        // Build Information
        BUILD_TAG = "${env.BUILD_NUMBER}"
    }

    parameters {
        booleanParam(
            name: 'FORCE_BUILD_ALL',
            defaultValue: false,
            description: 'Force rebuild both API and Frontend regardless of git changes'
        )
    }

    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "Checking out code..."
                    checkout scm
                    // safe: compute commit here
                    env.GIT_COMMIT_SHORT = sh(returnStdout: true, script: 'git rev-parse --short HEAD').trim()
                    echo "Deploying to production environment"
                    echo "Build: ${BUILD_TAG}, Commit: ${env.GIT_COMMIT_SHORT}"
                }
            }
        }

        stage('Unit Test') {
            parallel {
                stage('Test API') {
                    steps {
                        echo "Running API Unit Tests (Fail-Fast)..."
                        dir('01_api') {
                            script {
                                sh '''
                                    if command -v npm >/dev/null 2>&1; then
                                        npm ci --include=dev
                                        npm test
                                    else
                                        docker run --rm -v "$(pwd):/app" -w /app node:22-alpine sh -c "npm ci --include=dev && npm test"
                                    fi
                                '''
                            }
                        }
                    }
                }

                stage('Test Frontend') {
                    steps {
                        echo "Running Frontend Unit Tests (Fail-Fast)..."
                        dir('02_frontend') {
                            script {
                                sh '''
                                    if command -v npm >/dev/null 2>&1; then
                                        npm ci --include=dev
                                        npm test
                                    else
                                        docker run --rm -v "$(pwd):/app" -w /app node:22-alpine sh -c "npm ci --include=dev && npm test"
                                    fi
                                '''
                            }
                        }
                    }
                }
            }
        }

        stage('Prepare Environment & Detect Changes') {
            steps {
                script {
                    echo "Preparing environment configuration..."

                    // Load credentials from Jenkins (masked)
                    withCredentials([
                        string(credentialsId: 'MYSQL_ROOT_PASSWORD', variable: 'MYSQL_ROOT_PASS'),
                        string(credentialsId: 'MYSQL_PASSWORD',      variable: 'MYSQL_PASS')
                    ]) {
                        // Safely write .env without using `sh` interpolation
                        writeFile file: '.env', text: """\
MYSQL_ROOT_PASSWORD=${env.MYSQL_ROOT_PASS}
MYSQL_DATABASE=attractions_db
MYSQL_USER=attractions_user
MYSQL_PASSWORD=${env.MYSQL_PASS}
MYSQL_PORT=3306
API_PORT=3001
DB_PORT=3306
FRONTEND_PORT=3000
NODE_ENV=production
API_HOST_INTERNAL=http://api:3001
""".stripIndent()

                        sh 'chmod 600 .env'
                        echo ".env file created successfully"
                    }

                    // Change Detection
                    echo "Detecting changed services..."
                    def shouldBuildApi = false
                    def shouldBuildFrontend = false

                    if (params.FORCE_BUILD_ALL) {
                        echo "FORCE_BUILD_ALL is enabled. Building both API and Frontend."
                        shouldBuildApi = true
                        shouldBuildFrontend = true
                    } else {
                        // Check if images exist locally
                        def apiImage = sh(script: 'docker compose images -q api 2>/dev/null || true', returnStdout: true).trim()
                        def frontendImage = sh(script: 'docker compose images -q frontend 2>/dev/null || true', returnStdout: true).trim()

                        if (!apiImage) {
                            echo "API Docker image not found locally. Flagging for build."
                            shouldBuildApi = true
                        }
                        if (!frontendImage) {
                            echo "Frontend Docker image not found locally. Flagging for build."
                            shouldBuildFrontend = true
                        }

                        // Check git diff
                        def hasParent = sh(script: 'git rev-parse --verify HEAD~1 >/dev/null 2>&1 && echo "yes" || echo "no"', returnStdout: true).trim()
                        if (hasParent != 'yes') {
                            echo "Initial commit or shallow clone. Flagging all for build."
                            shouldBuildApi = true
                            shouldBuildFrontend = true
                        } else {
                            def diffTarget = env.GIT_PREVIOUS_SUCCESSFUL_COMMIT
                            def changedFiles = ""
                            if (diffTarget && sh(script: "git rev-parse --verify ${diffTarget} >/dev/null 2>&1 && echo 'yes' || echo 'no'", returnStdout: true).trim() == 'yes') {
                                changedFiles = sh(script: "git diff --name-only ${diffTarget} HEAD", returnStdout: true).trim()
                            } else {
                                changedFiles = sh(script: "git diff --name-only HEAD~1 HEAD", returnStdout: true).trim()
                            }

                            echo "Changed files in commit:"
                            echo changedFiles ?: "(none detected)"

                            if (!changedFiles) {
                                if (!shouldBuildApi && !shouldBuildFrontend) {
                                    echo "No code changes detected. Rebuilding all services by default."
                                    shouldBuildApi = true
                                    shouldBuildFrontend = true
                                }
                            } else {
                                def filesList = changedFiles.split('\n')
                                def apiChanged = filesList.any { it.startsWith('01_api/') }
                                def frontendChanged = filesList.any { it.startsWith('02_frontend/') }
                                def coreChanged = filesList.any { it == 'docker-compose.yml' || it.startsWith('.env') || it == 'Jenkinsfile' }

                                if (coreChanged) {
                                    echo "Core/shared files changed. Building all services."
                                    shouldBuildApi = true
                                    shouldBuildFrontend = true
                                } else {
                                    if (apiChanged) shouldBuildApi = true
                                    if (frontendChanged) shouldBuildFrontend = true
                                }
                            }
                        }
                    }

                    env.BUILD_API = "${shouldBuildApi}"
                    env.BUILD_FRONTEND = "${shouldBuildFrontend}"

                    echo "=== Build Decision ==="
                    echo "Build API:      ${env.BUILD_API}"
                    echo "Build Frontend: ${env.BUILD_FRONTEND}"
                    echo "======================"
                }
            }
        }

        stage('Validate') {
            steps {
                echo "Validating Docker Compose configuration..."
                sh 'docker compose config --quiet'
            }
        }

        stage('Build Services') {
            parallel {
                stage('Build API') {
                    steps {
                        script {
                            if (env.BUILD_API == 'true') {
                                echo ">>> Changes detected in API. Building API service..."
                                sh 'docker compose build --pull --no-cache api'
                            } else {
                                echo ">>> No API changes detected (BUILD_API=${env.BUILD_API}). Skipping API build."
                            }
                        }
                    }
                }

                stage('Build Frontend') {
                    steps {
                        script {
                            if (env.BUILD_FRONTEND == 'true') {
                                echo ">>> Changes detected in Frontend. Building Frontend service..."
                                sh 'docker compose build --pull --no-cache frontend'
                            } else {
                                echo ">>> No Frontend changes detected (BUILD_FRONTEND=${env.BUILD_FRONTEND}). Skipping Frontend build."
                            }
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            steps {
                script {
                    echo "Deploying to production using Docker Compose..."

                    // Preserve database volumes, including when an older job still has CLEAN_VOLUMES set.
                    sh 'docker compose up -d --remove-orphans --wait --wait-timeout 180'

                    echo "Deployment completed"
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    sh 'sh scripts/check-deployment.sh'
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                script {
                    echo "Verifying all services..."

                    sh """
                        echo "=== Container Status ==="
                        docker compose ps

                        echo ""
                        echo "=== Service Logs (last 20 lines) ==="
                        docker compose logs --tail=20

                        echo ""
                        echo "=== Deployed Services ==="
                        echo "Frontend: http://localhost:3000"
                        echo "API: http://localhost:3001"
                    """
                }
            }
        }
    }

    post {
        success {
            echo "✅ Deployment completed successfully!"
            echo "Build: ${BUILD_TAG}"
            echo "Commit: ${env.GIT_COMMIT_SHORT}"
            echo ""
            echo "Access your application:"
            echo "  - Frontend: http://localhost:3000"
            echo "  - API: http://localhost:3001"
        }
        failure {
            echo "❌ Deployment failed!"
            script {
                echo "Printing container logs for debugging..."
                sh 'docker compose logs --tail=50 || true'
            }
        }
    }
}
