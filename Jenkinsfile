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
        SLACK_COLOR_SUCCESS = '#00FF00'
        SLACK_COLOR_FAIL = '#FF0000'
        SLACK_COLOR_DEFAULT = '#439FE0'
        STAGING_CONTAINER = 'flask_app_staging'
        PROD_CONTAINER = 'flask_app_production'
        PREVIOUS_IMAGE = ''
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
                        sh "docker run --rm ${IMAGE_NAME}:${env.IMAGE_TAG} echo 'Container test successful'"
                    } else {
                        bat "docker run --rm %IMAGE_NAME%:%IMAGE_TAG% echo Container test successful"
                    }
                    slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Test* completed.")
                }
            }
        }

        stage('Deploy Container') {
            steps {
                script {
                    slackSend(color: SLACK_COLOR_DEFAULT, message: "🚀 *Deploy to ${params.DEPLOY_ENV}* started.")

                    def containerName = (params.DEPLOY_ENV == 'production') ? PROD_CONTAINER : STAGING_CONTAINER
                    def port = (params.DEPLOY_ENV == 'production') ? '5000:5000' : '5001:5000'

                    // Store the current image for rollback
                    if (isUnix()) {
                        PREVIOUS_IMAGE = sh(script: "docker inspect --format='{{.Config.Image}}' ${containerName} || echo ''", returnStdout: true).trim()
                    } else {
                        PREVIOUS_IMAGE = bat(script: "docker inspect --format='{{.Config.Image}}' %${containerName}% || echo ''", returnStdout: true).trim()
                    }

                    try {
                        if (isUnix()) {
                            sh """
                                docker stop ${containerName} || true
                                docker rm ${containerName} || true
                                docker run -d -p ${port} --name ${containerName} ${IMAGE_NAME}:${env.IMAGE_TAG}
                            """
                        } else {
                            bat """
                                docker stop %${containerName}% || exit 0
                                docker rm %${containerName}% || exit 0
                                docker run -d -p ${port} --name %${containerName}% %IMAGE_NAME%:%IMAGE_TAG%
                            """
                        }

                        // Health check
                        sleep(10) // Wait for container to start
                        if (isUnix()) {
                            sh "curl -f http://localhost:${port.split(':')[0]} || exit 1"
                        } else {
                            bat "curl -f http://localhost:${port.split(':')[0]} || exit 1"
                        }

                        slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ *Deployment to ${params.DEPLOY_ENV}* completed.")
                    } catch (Exception e) {
                        // Rollback to previous version
                        if (PREVIOUS_IMAGE) {
                            slackSend(color: SLACK_COLOR_DEFAULT, message: "🔄 *Rolling back to previous version*")
                            if (isUnix()) {
                                sh """
                                    docker stop ${containerName} || true
                                    docker rm ${containerName} || true
                                    docker run -d -p ${port} --name ${containerName} ${PREVIOUS_IMAGE}
                                """
                            } else {
                                bat """
                                    docker stop %${containerName}% || exit 0
                                    docker rm %${containerName}% || exit 0
                                    docker run -d -p ${port} --name %${containerName}% %PREVIOUS_IMAGE%
                                """
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
            slackSend(color: SLACK_COLOR_SUCCESS, message: "✅ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' succeeded on *${params.DEPLOY_ENV}*!")
        }
        failure {
            slackSend(color: SLACK_COLOR_FAIL, message: "❌ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' failed during *${params.DEPLOY_ENV}* deployment!")
        }
    }
}
