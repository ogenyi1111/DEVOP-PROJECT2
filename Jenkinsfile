    pipeline {
        agent any

        parameters {
            choice(name: 'DEPLOY_ENV', choices: ['staging', 'production'], description: 'Choose deployment environment')
            choice(name: 'VERSION_BUMP', choices: ['none', 'patch', 'minor', 'major'], description: 'Choose version bump type')
        }

        environment {
            DOCKER_IMAGE = 'flask-app'
            DOCKER_TAG = readFile('VERSION').trim()
            SONAR_HOST_URL = 'http://localhost:9000'
            // Ensure you have a 'sonar-token' credential of type 'Secret text' in Jenkins
            SONAR_TOKEN = credentials('sonar-token')
            SLACK_COLOR_SUCCESS = 'good'
            SLACK_COLOR_FAIL = 'danger'
            SLACK_COLOR_DEFAULT = '#FFFF00'
            // Add DOCKER_USERNAME here if it's dynamic, otherwise, it comes from credentials
            // PREVIOUS_IMAGE will be set in the Deploy stage
            PREVIOUS_IMAGE = '' // Initialize as empty string
        }

        stages {
            stage('Checkout') {
                steps {
                    checkout scm
                }
            }

            stage('Version Management') {
                steps {
                    script {
                        def currentVersion = readFile('VERSION').trim()
                        echo "Current version: ${currentVersion}"
                        def versionParts = currentVersion.split('\\.')
                        def major = versionParts[0].toInteger()
                        def minor = versionParts[1].toInteger()
                        def patch = versionParts[2].toInteger()

                        switch ("${params.VERSION_BUMP}") {
                            case 'patch':
                                patch += 1
                                break
                            case 'minor':
                                minor += 1
                                patch = 0
                                break
                            case 'major':
                                major += 1
                                minor = 0
                                patch = 0
                                break
                            case 'none':
                                break
                        }
                        def newVersion = "${major}.${minor}.${patch}"
                        writeFile file: 'VERSION', text: newVersion
                        env.DOCKER_TAG = newVersion
                        echo "New version: ${newVersion}"
                        slackSend(color: env.SLACK_COLOR_DEFAULT, message: "🟢 Version bumped to ${newVersion}")
                    }
                }
            }

            stage('Load Environment Config') {
                steps {
                    script {
                        // This will now correctly use params.DEPLOY_ENV to load config/staging.yml or config/production.yml
                        def config = readYaml file: "config/${params.DEPLOY_ENV}.yml"
                        env.FLASK_ENV = config.flask_env
                        env.FLASK_DEBUG = config.flask_debug
                        slackSend(color: env.SLACK_COLOR_SUCCESS, message: "🌍 Environment config loaded for ${params.DEPLOY_ENV}")
                    }
                }
            }

            stage('SonarQube Analysis') {
                steps {
                    withSonarQubeEnv('SonarQube') {
                        // Use bat for Windows and full path to sonar-scanner.bat
                        bat '\"C:\\\\SonarQube\\\\sonar-scanner\\\\bin\\\\sonar-scanner.bat\" -Dsonar.projectKey=flask-app -Dsonar.sources=. -Dsonar.host.url=${SONAR_HOST_URL} -Dsonar.login=${SONAR_TOKEN} -Dsonar.python.version=3 -Dsonar.python.coverage.reportPaths=coverage.xml -Dsonar.python.xunit.reportPath=test-results.xml'
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
                        slackSend(color: env.SLACK_COLOR_DEFAULT, message: "🏗️ *Build* started.")
                        // Use bat for Windows
                        bat "docker build -t ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} ."
                        slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ *Build* completed.")
                    }
                }
            }

            stage('Push to DockerHub') {
                steps {
                    script {
                        slackSend(color: env.SLACK_COLOR_DEFAULT, message: "📤 *Push* started.")
                        withCredentials([usernamePassword(credentialsId: 'dockerhub-credentials', passwordVariable: 'DOCKER_PASSWORD', usernameVariable: 'DOCKER_USERNAME')]) {
                            // Use bat for Windows
                            bat "docker login -u %DOCKER_USERNAME% -p %DOCKER_PASSWORD%"
                            bat "docker tag ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} ${env.DOCKER_USERNAME}/${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
                            bat "docker push ${env.DOCKER_USERNAME}/${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
                        }
                        slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ *Push* completed.")
                    }
                }
            }

            stage('Test Container') {
                steps {
                    script {
                        slackSend(color: env.SLACK_COLOR_DEFAULT, message: "🧪 *Test* started.")
                        // Use bat for Windows
                        bat "docker run --rm ${env.DOCKER_IMAGE}:${env.DOCKER_TAG} python -m pytest --junitxml=test-results.xml --cov=. --cov-report=xml:coverage.xml"
                        slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ *Test* completed.")
                    }
                }
            }

            stage('Deploy Container') {
                steps {
                    script {
                        slackSend(color: env.SLACK_COLOR_DEFAULT, message: "🚀 *Deploy* started.")
                        try {
                            // Use bat for Windows
                            bat "docker stop flask-app || true"
                            bat "docker rm flask-app || true"
                            bat "docker run -d -p 5000:5000 --name flask-app ${env.DOCKER_IMAGE}:${env.DOCKER_TAG}"
                            slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ *Deployment* successful to *${params.DEPLOY_ENV}*!")
                        } catch (Exception e) {
                            echo "Deployment failed, attempting rollback to previous image..."
                            slackSend(color: env.SLACK_COLOR_FAIL, message: "❌ Deployment to *${params.DEPLOY_ENV}* failed. Attempting rollback...")
                            // Use bat for Windows
                            bat "docker stop flask-app || true"
                            bat "docker rm flask-app || true"
                            bat "docker run -d -p 5000:5000 --name flask-app ${env.DOCKER_IMAGE}:${env.PREVIOUS_IMAGE}"
                            error "Deployment failed and rolled back."
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
                // Correctly referencing environment variables with env.
                slackSend(color: env.SLACK_COLOR_SUCCESS, message: "✅ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' succeeded on *${params.DEPLOY_ENV}*!")
            }
            failure {
                // Correctly referencing environment variables with env.
                slackSend(color: env.SLACK_COLOR_FAIL, message: "❌ Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' failed during *${params.DEPLOY_ENV}* deployment!")
            }
        }
    }