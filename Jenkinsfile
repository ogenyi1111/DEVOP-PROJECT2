pipeline {
    agent any

    parameters {
        choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Choose deployment environment')
        choice(name: 'VERSION_BUMP', choices: ['none', 'patch', 'minor', 'major'], description: 'Choose version bump type')
    }

    environment {
        IMAGE_NAME = 'ikenna2025/flask-app'
        VERSION_FILE = 'VERSION'
        IMAGE_TAG = "build-${env.BUILD_NUMBER}"
        SLACK_COLOR_SUCCESS = 'good'
        SLACK_COLOR_FAIL = 'danger'
        SLACK_COLOR_DEFAULT = '#FFFF00'
        CONFIG_DIR = 'config'
        PREVIOUS_IMAGE = ''
        DOCKER_IMAGE = 'flask-app'
        DOCKER_TAG = readFile('VERSION').trim()
        SONAR_HOST_URL = 'http://localhost:9000'
        SONAR_TOKEN = credentials('sonar-token')
    }

    stages {
        stage('Version Management') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "📝 *Version Management* started.")
                    
                    // Read current version
                    def currentVersion = readFile(VERSION_FILE).trim()
                    def (major, minor, patch) = currentVersion.tokenize('.')
                    
                    // Bump version based on parameter
                    switch(params.VERSION_BUMP) {
                        case 'major':
                            major = (major.toInteger() + 1).toString()
                            minor = '0'
                            patch = '0'
                            break
                        case 'minor':
                            minor = (minor.toInteger() + 1).toString()
                            patch = '0'
                            break
                        case 'patch':
                            patch = (patch.toInteger() + 1).toString()
                            break
                    }
                    
                    // Create new version
                    def newVersion = "${major}.${minor}.${patch}"
                    
                    // Update version file
                    writeFile file: VERSION_FILE, text: newVersion
                    
                    // Set version for this build
                    env.IMAGE_TAG = newVersion
                    
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Version bumped* from ${currentVersion} to ${newVersion}")
                }
            }
        }

        stage('Load Environment Config') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "🔧 *Loading ${params.DEPLOY_ENV} configuration*")
                    
                    // Load environment-specific configuration
                    def envFile = "${CONFIG_DIR}/${params.DEPLOY_ENV}.env"
                    def envConfig = readFile(envFile).trim()
                    
                    // Parse environment variables
                    envConfig.split('\n').each { line ->
                        if (line && !line.startsWith('#')) {
                            def (key, value) = line.split('=')
                            env[key.trim()] = value.trim()
                        }
                    }
                    
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Configuration loaded* for ${params.DEPLOY_ENV}")
                }
            }
        }

        stage('Checkout') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "📦 *Checkout* started.")
                }
                git branch: 'main', url: 'https://github.com/ogenyi1111/DEVOP-PROJECT2.git'
                script {
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Checkout* completed.")
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') {
                    sh '''
                        sonar-scanner \
                        -Dsonar.projectKey=flask-app \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=${SONAR_HOST_URL} \
                        -Dsonar.login=${SONAR_TOKEN} \
                        -Dsonar.python.version=3 \
                        -Dsonar.python.coverage.reportPaths=coverage.xml \
                        -Dsonar.python.xunit.reportPath=test-results.xml
                    '''
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "🏗️ *Build* started.")
                    if (isUnix()) {
                        sh "docker build -t ${IMAGE_NAME}:${env.IMAGE_TAG} ."
                    } else {
                        bat "docker build -t %IMAGE_NAME%:%IMAGE_TAG% ."
                    }
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Build* completed.")
                }
            }
        }

        stage('Push to DockerHub') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "📤 *Push to DockerHub* started.")
                    withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        if (isUnix()) {
                            sh """
                                echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                                docker push ${IMAGE_NAME}:${env.IMAGE_TAG}
                                docker logout
                            """
                        } else {
                            bat """
                                echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                                docker push %IMAGE_NAME%:%IMAGE_TAG%
                                docker logout
                            """
                        }
                    }
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Image pushed to DockerHub* as `${IMAGE_NAME}:${env.IMAGE_TAG}`.")
                }
            }
        }

        stage('Test Container') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "🧪 *Test* started.")
                    if (isUnix()) {
                        sh "docker run --rm ${IMAGE_NAME}:${env.IMAGE_TAG} python -m pytest --junitxml=test-results.xml --cov=. --cov-report=xml:coverage.xml"
                    } else {
                        bat "docker run --rm %IMAGE_NAME%:%IMAGE_TAG% python -m pytest --junitxml=test-results.xml --cov=. --cov-report=xml:coverage.xml"
                    }
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Test* completed.")
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "🚀 *Deploy to ${params.DEPLOY_ENV}* started.")

                    // Store the current image for rollback
                    if (isUnix()) {
                        PREVIOUS_IMAGE = sh(script: "docker inspect --format='{{.Config.Image}}' ${env.CONTAINER_NAME} || echo ''", returnStdout: true).trim()
                    } else {
                        PREVIOUS_IMAGE = bat(script: "docker inspect --format='{{.Config.Image}}' %${env.CONTAINER_NAME}% || echo ''", returnStdout: true).trim()
                    }

                    try {
                        // Deploy multiple replicas based on environment config
                        for (int i = 0; i < env.REPLICAS.toInteger(); i++) {
                            def containerName = "${env.CONTAINER_NAME}-${i}"
                            def port = "${env.PORT.toInteger() + i}:5000"
                            
                            if (isUnix()) {
                                sh """
                                    docker stop ${containerName} || true
                                    docker rm ${containerName} || true
                                    docker run -d \
                                        --name ${containerName} \
                                        -p ${port} \
                                        --cpus=${env.RESOURCES_CPU} \
                                        --memory=${env.RESOURCES_MEMORY} \
                                        ${IMAGE_NAME}:${env.IMAGE_TAG}
                                """
                            } else {
                                bat """
                                    docker stop %${containerName}% || exit 0
                                    docker rm %${containerName}% || exit 0
                                    docker run -d ^
                                        --name %${containerName}% ^
                                        -p ${port} ^
                                        --cpus=%${env.RESOURCES_CPU}% ^
                                        --memory=%${env.RESOURCES_MEMORY}% ^
                                        %IMAGE_NAME%:%IMAGE_TAG%
                                """
                            }
                        }

                        // Health check for all replicas
                        sleep(10) // Wait for containers to start
                        for (int i = 0; i < env.REPLICAS.toInteger(); i++) {
                            def port = env.PORT.toInteger() + i
                            if (isUnix()) {
                                sh "curl -f http://localhost:${port} || exit 1"
                            } else {
                                bat "curl -f http://localhost:${port} || exit 1"
                            }
                        }

                        slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Deployment to ${params.DEPLOY_ENV}* completed with ${env.REPLICAS} replicas.")
                    } catch (Exception e) {
                        // Rollback to previous version
                        if (PREVIOUS_IMAGE) {
                            slackSend(color: SLACK_COLOR_DEFAULT, message: "🔄 *Rolling back to previous version*")
                            
                            // Rollback all replicas
                            for (int i = 0; i < env.REPLICAS.toInteger(); i++) {
                                def containerName = "${env.CONTAINER_NAME}-${i}"
                                def port = "${env.PORT.toInteger() + i}:5000"
                                
                                if (isUnix()) {
                                    sh """
                                        docker stop ${containerName} || true
                                        docker rm ${containerName} || true
                                        docker run -d \
                                            --name ${containerName} \
                                            -p ${port} \
                                            --cpus=${env.RESOURCES_CPU} \
                                            --memory=${env.RESOURCES_MEMORY} \
                                            ${PREVIOUS_IMAGE}
                                    """
                                } else {
                                    bat """
                                        docker stop %${containerName}% || exit 0
                                        docker rm %${containerName}% || exit 0
                                        docker run -d ^
                                            --name %${containerName}% ^
                                            -p ${port} ^
                                            --cpus=%${env.RESOURCES_CPU}% ^
                                            --memory=%${env.RESOURCES_MEMORY}% ^
                                            %PREVIOUS_IMAGE%
                                    """
                                }
                            }
                            slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Rollback completed* to previous version.")
                        }
                        throw e
                    }
                }
            }
        }
    }

    post {
        always {
            slackSend(color: '#FFFF00', message: "🟡 Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' finished. Check: ${env.BUILD_URL}")
        }
        success {
            slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' succeeded on *${params.DEPLOY_ENV}*!")
        }
        failure {
            slackSend(color: env.SLACK_COLOR_FAIL, message: "❌ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' failed during *${params.DEPLOY_ENV}* deployment!")
        }
    }
}
